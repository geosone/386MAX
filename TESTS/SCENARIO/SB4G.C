/* SB4G.C - Sound Blaster playback from a DOS/4GW program (A220 I5 D1):
   3 x 1 s 444 Hz square wave, 8-bit single cycle DMA, IRQ counted in a
   protected mode handler.  The DOS/4GW counterpart of SBPM, for VSBHDA
   with protected-mode games (most of them use DOS/4GW).
   Build (OpenWatcom):  wcl386 -bt=dos -l=dos4g SB4G.C
   Needs DOS4GW.EXE (OpenWatcom binw) next to it; not part of the repo
   and not built by the GNUmakefile. */
#include <stdio.h>
#include <dos.h>
#include <conio.h>
#include <i86.h>
#include <string.h>

#define BASE 0x220
#define LEN  11111

static volatile int irqs = 0;
static void (__interrupt __far *oldisr)(void);

static void __interrupt __far isr(void)
{
    inp(BASE + 0x0E);
    irqs++;
    outp(0x20, 0x20);
}

static unsigned long ticks(void) { return *(volatile unsigned long *)0x46C; }

static int dspw(int v)
{
    long n = 65535;
    while ((inp(BASE + 0x0C) & 0x80) && --n) ;
    outp(BASE + 0x0C, v);
    return 0;
}

static int dspreset(void)
{
    long n;
    int i;
    outp(BASE + 6, 1);
    for (i = 0; i < 200; i++) inp(BASE + 6);
    outp(BASE + 6, 0);
    for (n = 65535; n && !(inp(BASE + 0x0E) & 0x80); n--) ;
    return inp(BASE + 0x0A);
}

int main(void)
{
    union REGS r;
    unsigned seg, sel;
    unsigned char *buf;
    unsigned long phys;
    int i, loop, oldmask, ok = 0;

    printf("SB4G: 3 x 1 s square wave, A220 I5 D1, DOS/4GW\n");
    memset(&r, 0, sizeof r);
    r.w.ax = 0x0100;                        /* DOS memory, 2 x LEN */
    r.w.bx = (2 * LEN + 15) / 16 + 1;
    int386(0x31, &r, &r);
    if (r.w.cflag) { printf("no DOS memory\n"); return 1; }
    seg = r.w.ax; sel = r.w.dx;
    if (dspreset() != 0xAA) { printf("no DSP at 220h\n"); return 1; }
    buf = (unsigned char *)((unsigned long)seg << 4);
    for (i = 0; i < 2 * LEN; i++) buf[i] = (i % 25) < 12 ? 0xC0 : 0x40;
    oldisr = _dos_getvect(0x0D);
    _dos_setvect(0x0D, isr);
    oldmask = inp(0x21);
    outp(0x21, oldmask & 0xDF);
    _enable();
    dspw(0xD1); dspw(0x40); dspw(166);
    for (loop = 0; loop < 3; loop++) {
        int before = irqs;
        unsigned long t0;
        phys = (unsigned long)seg << 4;
        if (((phys & 0xFFFF) + LEN) > 0x10000) phys += LEN;
        _disable();
        outp(0x0A, 5); outp(0x0C, 0); outp(0x0B, 0x49);
        outp(0x02, phys & 0xFF); outp(0x02, (phys >> 8) & 0xFF);
        outp(0x83, (phys >> 16) & 0xFF);
        outp(0x03, (LEN - 1) & 0xFF); outp(0x03, (LEN - 1) >> 8);
        outp(0x0A, 1);
        _enable();
        dspw(0x14); dspw((LEN - 1) & 0xFF); dspw((LEN - 1) >> 8);
        t0 = ticks();
        while (irqs == before && ticks() - t0 < 55) ;
        if (irqs == before) printf("no IRQ within 3 s\n");
        else printf("IRQ after ticks: %02lX\n", ticks() - t0);
    }
    dspw(0xD3);
    _disable();
    outp(0x21, oldmask);
    _enable();
    _dos_setvect(0x0D, oldisr);
    printf("IRQs total: %02X\n", irqs);
    return irqs == 3 ? 0 : 1;
}
