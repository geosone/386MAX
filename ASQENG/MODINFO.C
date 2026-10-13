/*
 * MODINFO.C - collect information about newer hardware for ASQ
 *
 * Open 386MAX - GNU General Public License version 3.
 *
 * BIOS memory map (INT 15h E820h/E801h), CPUID, PCI functions (PCI BIOS)
 * with the option ROMs in C0000-EFFFF that belong to them, ACPI tables
 * (RSDP, RSDT/XSDT) and SMBIOS (BIOS, system, board, processor, memory
 * devices).  Tables above 1 MB are read with INT 15h AH=87h.  Everything
 * goes into SysInfo->Modern (modinfo.h).  Only reads: no PCI configuration
 * register is written.
 */

#include <stdio.h>
#include <string.h>
#include <dos.h>

#include <commfunc.h>		/* Utility functions */
#include <myalloc.h>		/* malloc() and free() cover functions */
#include "sysinfo.h"            /* System info structures */

#define MOD	(SysInfo->Modern)

static BYTE far *phys_buf;	/* Copy buffer for tables above 1 MB */
#define PHYSBUF 32768u		/* ... its size */

/* Copy n bytes (<= PHYSBUF) from physical address a to phys_buf */
static int read_phys(DWORD a, WORD n)
{
	if (a < 0x100000UL) {	/* Below 1 MB: directly */
		_fmemcpy(phys_buf, MK_FP((WORD)(a >> 4), (WORD)(a & 15)), n);
		return 1;
	}
	if (MOD.flags & MOD_XMOVE) return 0;
	if (!MODHW_XMOVE(a, phys_buf, (n + 1) & ~1)) {
		MOD.flags |= MOD_XMOVE;
		return 0;
	}
	return 1;
}

static BYTE checksum(BYTE far *p, WORD n)
{
	BYTE s = 0;

	while (n--) s += *p++;
	return s;
}

/* E820 and E801 */
static void get_memmap(void)
{
	E820ENT list[MAXE820];
	DWORD cont = 0;
	WORD n = 0;

	while (n < MAXE820 && MODHW_E820(&cont, &list[n])) {
		if (list[n].lenlo || list[n].lenhi) n++;
		if (!cont) break;
	}
	if (n) {
		MOD.flags |= MOD_E820;
		MOD.nE820 = n;
		sysbuf_store(&MOD.hE820, list, n * sizeof(E820ENT));
	}
	if (MODHW_E801(MOD.wE801)) MOD.flags |= MOD_E801;
}

/* CPUID */
static void get_cpuid(void)
{
	DWORD r[4];
	int i;

	if (!MODHW_HASCPUID()) return;
	MOD.flags |= MOD_CPUID;
	MODHW_CPUID(0, r);
	MOD.dwMaxLeaf = r[0];
	_fmemcpy(MOD.szVendor, &r[1], 4);	/* EBX, EDX, ECX */
	_fmemcpy(MOD.szVendor + 4, &r[3], 4);
	_fmemcpy(MOD.szVendor + 8, &r[2], 4);
	MOD.szVendor[12] = '\0';
	if (MOD.dwMaxLeaf >= 1) {
		MODHW_CPUID(1, r);
		MOD.dwSig = r[0];
		MOD.dwFeat[0] = r[3];
		MOD.dwFeat[1] = r[2];
	}
	MODHW_CPUID(0x80000000UL, r);
	if ((r[0] & 0xFFFF0000UL) == 0x80000000UL) {
		MOD.dwMaxExt = r[0];
		if (MOD.dwMaxExt >= 0x80000001UL) {
			MODHW_CPUID(0x80000001UL, r);
			MOD.dwFeat[2] = r[3];
			MOD.dwFeat[3] = r[2];
		}
		if (MOD.dwMaxExt >= 0x80000004UL) {
			char brand[49], *p;

			for (i = 0; i < 3; i++) {
				MODHW_CPUID(0x80000002UL + i, r);
				_fmemcpy(brand + 16 * i, r, 16);
			}
			brand[48] = '\0';
			for (p = brand; *p == ' '; p++) ;
			strncpy(MOD.szBrand, p, sizeof(MOD.szBrand) - 1);
		}
	}
}

/* PCI functions and option ROMs */
static void get_pci(void)
{
	PCIDEV list[MAXPCI];
	WORD info[3];
	WORD bus, dev, fn, n = 0;

	if (!MODHW_PCIBIOS(info)) return;
	MOD.flags |= MOD_PCI;
	MOD.wPciVer = info[0];
	MOD.wPciLastBus = info[1];

	for (bus = 0; bus <= MOD.wPciLastBus && n < MAXPCI; bus++) {
	    for (dev = 0; dev < 32 && n < MAXPCI; dev++) {
		for (fn = 0; fn < 8 && n < MAXPCI; fn++) {
			WORD bdf = (bus << 8) | (dev << 3) | fn;
			DWORD id = MODHW_PCIREAD(bdf, 0);
			DWORD x;
			PCIDEV *p = &list[n];
			int i;

			if ((WORD)id == 0xFFFF || (WORD)id == 0) {
				if (fn == 0) break;	/* No device */
				continue;
			}
			memset(p, 0, sizeof(*p));
			p->bus = (BYTE)bus;
			p->devfn = (BYTE)(bdf & 0xFF);
			p->ven = (WORD)id;
			p->dev = (WORD)(id >> 16);
			x = MODHW_PCIREAD(bdf, 8);
			p->rev = (BYTE)x;
			p->prog = (BYTE)(x >> 8);
			p->sub = (BYTE)(x >> 16);
			p->cls = (BYTE)(x >> 24);
			p->hdr = (BYTE)(MODHW_PCIREAD(bdf, 0x0C) >> 16);
			p->irq = (BYTE)MODHW_PCIREAD(bdf, 0x3C);
			switch (p->hdr & 0x7F) {
			case 0: 	/* Device */
				for (i = 0; i < 6; i++)
					p->bar[i] = MODHW_PCIREAD(bdf, 0x10 + 4 * i);
				x = MODHW_PCIREAD(bdf, 0x2C);
				p->subven = (WORD)x;
				p->subdev = (WORD)(x >> 16);
				p->rom = MODHW_PCIREAD(bdf, 0x30);
				break;
			case 1: 	/* PCI-PCI bridge */
				p->bar[0] = MODHW_PCIREAD(bdf, 0x10);
				p->bar[1] = MODHW_PCIREAD(bdf, 0x14);
				p->rom = MODHW_PCIREAD(bdf, 0x38);
				break;
			}
			n++;
			if (fn == 0 && !(p->hdr & 0x80)) break; /* Single function */
		}
	    }
	}
	if (n) {
		MOD.nPci = n;
		sysbuf_store(&MOD.hPci, list, n * sizeof(PCIDEV));
	}
}

static void get_optroms(void)
{
	OPTROM list[MAXOPTROM];
	WORD seg, n = 0;

	for (seg = 0xC000; seg < 0xF000 && n < MAXOPTROM; ) {
		BYTE far *p = MK_FP(seg, 0);
		WORD size, pcir;

		if (p[0] != 0x55 || p[1] != 0xAA || !p[2]) {
			seg += 0x80;		/* 2 KB steps */
			continue;
		}
		size = p[2];
		memset(&list[n], 0, sizeof(OPTROM));
		list[n].seg = seg;
		list[n].size = size;
		pcir = *(WORD far *)(p + 0x18);
		if (pcir && pcir < size * 512u - 16 &&
		    !_fmemcmp(p + pcir, "PCIR", 4)) {
			list[n].ven = *(WORD far *)(p + pcir + 4);
			list[n].dev = *(WORD far *)(p + pcir + 6);
			list[n].sub = p[pcir + 0x0E];
			list[n].cls = p[pcir + 0x0F];
		}
		n++;
		seg += ((size * 512u + 2047) / 2048) * 0x80;
		if (seg < 0xC000) break;	/* Wrapped */
	}
	if (n) {
		MOD.nOptRom = n;
		sysbuf_store(&MOD.hOptRom, list, n * sizeof(OPTROM));
	}
}

/* ACPI: RSDP in the first KB of the EBDA or in E0000-FFFFF */
static BYTE far *find_rsdp(WORD seg, WORD paras)
{
	WORD i;

	for (i = 0; i < paras; i++) {
		BYTE far *p = MK_FP(seg + i, 0);

		if (!_fmemcmp(p, "RSD PTR ", 8) && !checksum(p, 20))
			return p;
	}
	return NULL;
}

static void get_acpi(void)
{
	ACPITAB list[MAXACPI];
	BYTE far *r;
	WORD ebda = *(WORD far *)MK_FP(0x40, 0x0E);
	DWORD root, ents[MAXACPI];
	WORD n = 0, nent, esize, i;

	r = ebda ? find_rsdp(ebda, 64) : NULL;
	if (!r) r = find_rsdp(0xE000, 0x2000);
	if (!r) return;
	MOD.flags |= MOD_ACPI;
	MOD.dwRsdp = ((DWORD)FP_SEG(r) << 4) + FP_OFF(r);
	MOD.bAcpiRev = r[15];
	_fmemcpy(MOD.szAcpiOem, r + 9, 6);
	MOD.szAcpiOem[6] = '\0';
	MOD.dwRsdt = *(DWORD far *)(r + 16);
	if (MOD.bAcpiRev >= 2) {
		MOD.dwXsdt[0] = *(DWORD far *)(r + 24);
		MOD.dwXsdt[1] = *(DWORD far *)(r + 28);
	}

	/* Root table: XSDT if below 4 GB, else RSDT */
	if (MOD.dwXsdt[0] && !MOD.dwXsdt[1]) {
		root = MOD.dwXsdt[0];
		esize = 8;
	} else {
		root = MOD.dwRsdt;
		esize = 4;
	}
	if (!root || !read_phys(root, 36)) return;
	nent = (WORD)((*(DWORD far *)(phys_buf + 4) - 36) / esize);
	if (nent > MAXACPI - 1) nent = MAXACPI - 1;

	/* The root table itself first */
	_fmemcpy(list[0].sig, phys_buf, 4);
	list[0].len = *(DWORD far *)(phys_buf + 4);
	list[0].rev = phys_buf[8];
	_fmemcpy(list[0].oem, phys_buf + 10, 6);
	_fmemcpy(list[0].oemtab, phys_buf + 16, 8);
	list[0].addr = root;
	n = 1;

	if (!read_phys(root + 36, nent * esize)) nent = 0;
	for (i = 0; i < nent; i++) {
		ents[i] = *(DWORD far *)(phys_buf + i * esize);
		if (esize == 8 && *(DWORD far *)(phys_buf + i * esize + 4))
			ents[i] = 0;		/* Above 4 GB */
	}
	for (i = 0; i < nent; i++) {
		ACPITAB *t = &list[n];

		if (!ents[i] || !read_phys(ents[i], 36)) continue;
		_fmemcpy(t->sig, phys_buf, 4);
		t->len = *(DWORD far *)(phys_buf + 4);
		t->rev = phys_buf[8];
		_fmemcpy(t->oem, phys_buf + 10, 6);
		_fmemcpy(t->oemtab, phys_buf + 16, 8);
		t->addr = ents[i];
		n++;

		/* The FADT points to the DSDT and FACS */
		if (!_fmemcmp(t->sig, "FACP", 4) && n < MAXACPI) {
			DWORD dsdt;

			if (read_phys(ents[i], 44)) {
				dsdt = *(DWORD far *)(phys_buf + 40);
				if (dsdt && read_phys(dsdt, 36) &&
				    !_fmemcmp(phys_buf, "DSDT", 4)) {
					t = &list[n++];
					_fmemcpy(t->sig, phys_buf, 4);
					t->len = *(DWORD far *)(phys_buf + 4);
					t->rev = phys_buf[8];
					_fmemcpy(t->oem, phys_buf + 10, 6);
					_fmemcpy(t->oemtab, phys_buf + 16, 8);
					t->addr = dsdt;
				}
			}
		}
	}
	MOD.nAcpi = n;
	sysbuf_store(&MOD.hAcpi, list, n * sizeof(ACPITAB));
}

/* SMBIOS */
static char far SmbBuf[700];	/* Items and strings (not in DGROUP) */
static WORD SmbLen;

static void smb_add(int item, BYTE far *s)
{
	WORD len;

	if (!s) return;
	while (*s == ' ') s++;
	len = _fstrlen(s);
	while (len && s[len - 1] == ' ') len--;
	if (!len) return;
	if (len > 63) len = 63;
	if (SmbLen + len + 3 > sizeof(SmbBuf)) return;
	SmbBuf[SmbLen++] = (char)item;
	_fmemcpy(SmbBuf + SmbLen, s, len);
	SmbLen += len;
	SmbBuf[SmbLen++] = '\0';
}

/* String number n of the structure at s (formatted length s[1]) */
static BYTE far *smb_str(BYTE far *s, BYTE far *end, BYTE n)
{
	BYTE far *p = s + s[1];

	if (!n) return NULL;
	while (--n) {
		while (p < end && *p) p++;
		if (++p >= end || !*p) return NULL;
	}
	return p < end && *p ? p : NULL;
}

static void get_smbios(void)
{
	SMBMEM mem[MAXSMBMEM];
	BYTE far *ep = NULL, far *s, far *end;
	WORD i, nmem = 0, cpu = 0;
	char speed[16];

	for (i = 0; i < 0x1000; i++) {		/* F0000-FFFFF */
		BYTE far *p = MK_FP(0xF000 + i, 0);

		if (!_fmemcmp(p, "_SM3_", 5) && p[6] >= 0x18 && !checksum(p, p[6])) {
			if (*(DWORD far *)(p + 0x14)) continue;	/* Above 4 GB */
			MOD.wSmbVer = (p[7] << 8) | p[8];
			MOD.dwSmbTable = *(DWORD far *)(p + 0x10);
			MOD.wSmbLen = *(DWORD far *)(p + 0x0C) > PHYSBUF ?
				PHYSBUF : (WORD)*(DWORD far *)(p + 0x0C);
			ep = p;
			break;
		}
		if (!_fmemcmp(p, "_SM_", 4) && p[5] >= 0x1E && !checksum(p, p[5]) &&
		    !_fmemcmp(p + 0x10, "_DMI_", 5)) {
			MOD.wSmbVer = (p[6] << 8) | p[7];
			MOD.dwSmbTable = *(DWORD far *)(p + 0x18);
			MOD.wSmbLen = *(WORD far *)(p + 0x16);
			if (MOD.wSmbLen > PHYSBUF) MOD.wSmbLen = PHYSBUF;
			ep = p;
			break;
		}
	}
	if (!ep) return;
	MOD.flags |= MOD_SMBIOS;
	if (!MOD.wSmbLen || !read_phys(MOD.dwSmbTable, MOD.wSmbLen)) return;

	SmbLen = 0;
	end = phys_buf + MOD.wSmbLen;
	for (s = phys_buf; s + 4 <= end && s[1] >= 4 && s[0] != 127; ) {
		BYTE far *next = s + s[1];

		while (next + 1 < end && (next[0] || next[1])) next++;
		next += 2;			/* Double NUL */

		switch (s[0]) {
		case 0: 	/* BIOS */
			smb_add(SMB_BIOSVENDOR, smb_str(s, end, s[4]));
			smb_add(SMB_BIOSVERSION, smb_str(s, end, s[5]));
			smb_add(SMB_BIOSDATE, smb_str(s, end, s[8]));
			break;
		case 1: 	/* System */
			smb_add(SMB_SYSMFR, smb_str(s, end, s[4]));
			smb_add(SMB_SYSPRODUCT, smb_str(s, end, s[5]));
			smb_add(SMB_SYSVERSION, smb_str(s, end, s[6]));
			break;
		case 2: 	/* Baseboard */
			if (s[1] >= 6) {
				smb_add(SMB_BOARDMFR, smb_str(s, end, s[4]));
				smb_add(SMB_BOARDPRODUCT, smb_str(s, end, s[5]));
			}
			break;
		case 4: 	/* Processor (the first one) */
			if (cpu++ || s[1] < 0x1A) break;
			smb_add(SMB_CPUSOCKET, smb_str(s, end, s[4]));
			smb_add(SMB_CPUVERSION, smb_str(s, end, s[0x10]));
			if (*(WORD far *)(s + 0x16)) {
				sprintf(speed, "%u MHz", *(WORD far *)(s + 0x16));
				smb_add(SMB_CPUSPEED, (BYTE far *)speed);
			}
			break;
		case 17:	/* Memory device */
			if (s[1] >= 0x15 && nmem < MAXSMBMEM) {
				SMBMEM *m = &mem[nmem++];
				WORD sz = *(WORD far *)(s + 0x0C);
				BYTE far *loc = smb_str(s, end, s[0x10]);

				memset(m, 0, sizeof(*m));
				if (loc) _fstrncpy(m->loc, loc, sizeof(m->loc) - 1);
				if (sz == 0x7FFF && s[1] >= 0x20)
					m->sizemb = (WORD)*(DWORD far *)(s + 0x1C);
				else if (sz != 0xFFFF)
					m->sizemb = sz & 0x8000 ? (sz & 0x7FFF) / 1024 : sz;
				m->type = s[0x12];
				if (s[1] > 0x16) m->speed = *(WORD far *)(s + 0x15);
			}
			break;
		}
		s = next;
	}
	SmbBuf[SmbLen++] = SMB_END;
	sysbuf_store(&MOD.hSmbStr, SmbBuf, SmbLen);
	if (nmem) {
		MOD.nSmbMem = nmem;
		sysbuf_store(&MOD.hSmbMem, mem, nmem * sizeof(SMBMEM));
	}
}

/* Collect everything (needs a 386 or later) */
void modinfo_get(void)
{
	memset(&MOD, 0, sizeof(MOD));
	if (SysInfo->cpu.cpu_type < CPU_80386) return;

	get_memmap();
	get_cpuid();
	get_pci();
	get_optroms();

	phys_buf = my_malloc(PHYSBUF);
	if (phys_buf) {
		get_acpi();
		get_smbios();
		my_free(phys_buf);
		phys_buf = NULL;
	}
}

/* Collected SMBIOS string of item, NULL if none */
const char *smb_string(int item)
{
	char *p;

	if (!MOD.hSmbStr) return NULL;
	for (p = sysbuf_ptr(MOD.hSmbStr); *p != SMB_END; p += strlen(p + 1) + 2)
		if (*p == item) return p + 1;
	return NULL;
}
