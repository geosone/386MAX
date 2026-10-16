/* WAVPLAY.C - play a 16-bit PCM WAVE file on a Sound Blaster 16 (or an
   emulation of it):  8-bit stereo, auto-init DMA with two half buffers
   refilled after each IRQ.  More than two channels are mixed down
   (left = even channels, right = odd channels).  One source, two builds:

     real mode   wcl -q -cc -bt=dos -ml -fe=WAVRM.EXE WAVPLAY.C
     DOS/4GW     wcl386 -q -cc -bt=dos -l=dos4g -fe=WAV4G.EXE WAVPLAY.C
                 (needs DOS4GW.EXE, OpenWatcom binw, next to it)

   TESTS/SCENARIO/WAVPM.ASM is the same for a plain 32-bit DPMI client.
   BLASTER gives A, I and D (8-bit DMA).  Usage:  WAVxx file.wav
   Output:  format, blocks played, IRQs; errorlevel 0 if every block
   raised its IRQ. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dos.h>
#include <conio.h>
#include <i86.h>

#define HALF 8192U                      /* bytes per half buffer */
#ifdef __386__
#define FARP                            /* flat:  near pointers */
#else
#define FARP __far
#endif

static unsigned base = 0x220, irq = 5, dma = 1;
static volatile unsigned irqs;
static void (__interrupt __far *oldisr)(void);

static void __interrupt __far isr(void)
{
    inp(base + 0x0E);                   /* acknowledge 8-bit DMA IRQ */
    irqs++;
    if (irq >= 8) outp(0xA0, 0x20);
    outp(0x20, 0x20);
}

static unsigned long ticks(void)
{
#ifdef __386__
    return *(volatile unsigned long *)0x46C;
#else
    return *(volatile unsigned long __far *)MK_FP(0x40, 0x6C);
#endif
}

static void dspw(int v)
{
    unsigned n = 65535;
    while ((inp(base + 0x0C) & 0x80) && --n) ;
    outp(base + 0x0C, v);
}

static int dspr(void)
{
    unsigned n = 65535;
    while (!(inp(base + 0x0E) & 0x80) && --n) ;
    return inp(base + 0x0A);
}

static int dspreset(void)
{
    int i;
    outp(base + 6, 1);
    for (i = 0; i < 200; i++) inp(base + 6);
    outp(base + 6, 0);
    return dspr();
}

static void blaster(void)
{
    char *p = getenv("BLASTER");
    for (; p && *p; p++) {
        if (*p == 'A' || *p == 'a') base = (unsigned)strtoul(p + 1, NULL, 16);
        if (*p == 'I' || *p == 'i') irq = (unsigned)strtoul(p + 1, NULL, 10);
        if (*p == 'D' || *p == 'd') dma = (unsigned)strtoul(p + 1, NULL, 10);
    }
}

/* the DMA buffer:  2 halves in conventional memory, not crossing 64 KB */
static unsigned char FARP *buf;
static unsigned long phys;

static int dmabuf(void)
{
#ifdef __386__
    union REGS r;
    memset(&r, 0, sizeof r);
    r.w.ax = 0x0100;                    /* DPMI:  DOS memory */
    r.w.bx = (unsigned short)((4UL * HALF) >> 4);
    int386(0x31, &r, &r);
    if (r.w.cflag) return 0;
    phys = (unsigned long)r.w.ax << 4;
#else
    unsigned seg;
    if (_dos_allocmem((unsigned)((4UL * HALF) >> 4), &seg)) return 0;
    phys = (unsigned long)seg << 4;
#endif
    if ((phys & 0xFFFF) + 2UL * HALF > 0x10000UL)
        phys = (phys + 0xFFFF) & ~0xFFFFUL;  /* next 64 KB */
#ifdef __386__
    buf = (unsigned char *)phys;
#else
    buf = MK_FP((unsigned)(phys >> 4), 0);
#endif
    return 1;
}

static FILE *f;
static unsigned ch, bits;
static unsigned long left;              /* data bytes not yet read */
static short *in;                       /* one half's worth of frames */

/* fill half h with the next frames, silence after the end:  1 if any data */
static int fill(int h)
{
    unsigned char FARP *o = buf + (unsigned)h * HALF;
    unsigned frames = HALF / 2, i, c, got = 0;
    unsigned long want = (unsigned long)frames * ch * 2;
    if (want > left) want = left;
    if (want) got = (unsigned)(fread(in, 1, (size_t)want, f) / (ch * 2));
    left -= want;
    for (i = 0; i < frames; i++) {
        long l = 0, r = 0;
        unsigned nl = 0, nr = 0;
        if (i < got) {
            for (c = 0; c < ch; c++) {
                if (c & 1) { r += in[i * ch + c]; nr++; }
                else       { l += in[i * ch + c]; nl++; }
            }
            if (!nr) { r = l; nr = nl; }
            l /= (long)nl; r /= (long)nr;
            o[2 * i] = (unsigned char)((l >> 8) + 128);
            o[2 * i + 1] = (unsigned char)((r >> 8) + 128);
        } else
            o[2 * i] = o[2 * i + 1] = 128;
    }
    return got != 0;
}

static int wavopen(char *name, unsigned long *rate)
{
    unsigned char h[12], ck[8], fmt[40];
    unsigned long n;
    unsigned tag;
    f = fopen(name, "rb");
    if (!f || fread(h, 1, 12, f) != 12 || memcmp(h, "RIFF", 4) || memcmp(h + 8, "WAVE", 4))
        return 0;
    for (;;) {
        if (fread(ck, 1, 8, f) != 8) return 0;
        n = *(unsigned long *)(ck + 4);
        if (!memcmp(ck, "fmt ", 4)) {
            if (n < 16 || n > sizeof fmt) return 0;
            fread(fmt, 1, (size_t)n, f);
            tag = *(unsigned short *)fmt;
            ch = *(unsigned short *)(fmt + 2);
            *rate = *(unsigned long *)(fmt + 4);
            bits = *(unsigned short *)(fmt + 14);
            if (tag == 0xFFFE && n >= 26) tag = *(unsigned short *)(fmt + 24);
            if (tag != 1 || bits != 16 || !ch || ch > 8) return 0;
        } else if (!memcmp(ck, "data", 4)) {
            left = n;
            return ch != 0;
        } else
            fseek(f, (long)((n + 1) & ~1UL), SEEK_CUR);
    }
}

int main(int argc, char **argv)
{
    unsigned long rate, t0, frames;
    unsigned blocks = 0, played, vec, ver, mask, pic, expect;
    int more;

    printf("WAVPLAY (%s):  SB16 8-bit stereo, auto-init DMA\n",
#ifdef __386__
           "DOS/4GW"
#else
           "real mode"
#endif
    );
    if (argc < 2) { printf("usage:  %s file.wav\n", argv[0]); return 2; }
    blaster();
    if (!wavopen(argv[1], &rate)) { printf("%s:  no 16-bit PCM WAVE file\n", argv[1]); return 2; }
    printf("%s:  %u channels, %lu Hz, %lu bytes\n", argv[1], ch, rate, left);
    frames = left / (ch * 2);
    expect = (unsigned)((frames + HALF / 2 - 1) / (HALF / 2));
    in = malloc((size_t)(HALF / 2) * ch * 2);
    if (!in || !dmabuf()) { printf("no memory\n"); return 2; }
    if (dspreset() != 0xAA) { printf("no DSP at %Xh\n", base); return 2; }
    dspw(0xE1);
    ver = dspr() << 8;
    ver |= dspr();
    if (ver < 0x400) { printf("DSP %u.%02u:  not a Sound Blaster 16\n", ver >> 8, ver & 0xFF); return 2; }

    fill(0);
    fill(1);
    vec = irq < 8 ? 8 + irq : 0x70 + irq - 8;
    oldisr = _dos_getvect(vec);
    _dos_setvect(vec, isr);
    pic = irq < 8 ? 0x21 : 0xA1;
    mask = inp(pic);
    outp(pic, mask & ~(1 << (irq & 7)));

    outp(0x0A, 4 | dma);                    /* mask the channel */
    outp(0x0C, 0);
    outp(0x0B, 0x58 | dma);                 /* single, auto-init, read */
    outp(dma * 2, (int)(phys & 0xFF));
    outp(dma * 2, (int)((phys >> 8) & 0xFF));
    outp(dma == 0 ? 0x87 : dma == 1 ? 0x83 : dma == 2 ? 0x81 : 0x82, (int)((phys >> 16) & 0xFF));
    outp(dma * 2 + 1, (2 * HALF - 1) & 0xFF);
    outp(dma * 2 + 1, (2 * HALF - 1) >> 8);
    outp(0x0A, dma);                        /* unmask */

    dspw(0x41);                             /* output rate */
    dspw((int)(rate >> 8));
    dspw((int)(rate & 0xFF));
    _enable();
    dspw(0xC6);                             /* 8-bit, auto-init, FIFO */
    dspw(0x20);                             /* stereo, unsigned */
    dspw((HALF - 1) & 0xFF);
    dspw((HALF - 1) >> 8);

    /* after IRQ n the half (n-1)&1 is played:  refill it */
    played = 0;
    more = 1;
    for (;;) {
        t0 = ticks();
        while (irqs == played && ticks() - t0 < 18) ;
        if (irqs == played) { printf("no IRQ within 1 s\n"); break; }
        played++;
        blocks++;
        if (!more) break;                   /* the last data half is out */
        more = fill((played - 1) & 1);
    }
    dspw(0xDA);                             /* exit 8-bit auto-init */
    dspw(0xD0);
    outp(0x0A, 4 | dma);
    outp(pic, mask);
    _dos_setvect(vec, oldisr);
    printf("blocks played:  %u of %u, IRQs:  %u\n", blocks, expect, irqs);
    return blocks == expect ? 0 : 1;
}
