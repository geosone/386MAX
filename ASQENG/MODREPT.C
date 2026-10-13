/*
 * MODREPT.C - ASQ reports about newer hardware
 *
 * Open 386MAX - GNU General Public License version 3.
 *
 * Memory_BIOS_Map	(Memory)	BIOS memory map: INT 15h E820h, E801h
 * Hardware_PCI 	(Equipment)	PCI functions and option ROMs
 * Hardware_Firmware	(Equipment)	processor (CPUID), SMBIOS, ACPI
 *
 * Data from SysInfo->Modern (MODINFO.C, or a snapshot).  Compiled with
 * -zc: the texts stay out of DGROUP.
 */

#include <stdio.h>
#include <string.h>

#include <commfunc.h>		/* Utility functions */
#include <engine.h>		/* DWIDTH2 */
#include "info.h"               /* Info text functions */
#include "sysinfo.h"            /* System info structures */

#ifdef LANG_GR
#define L(us,gr) gr
#else
#define L(us,gr) us
#endif

#define MOD	(SysInfo->Modern)

#define W	DWIDTH1 	/* Width of the report (49) */
#define LW	16		/* Label width */

/* Headline in the label colour, centred */
static void heading(HANDLE info, const char *s)
{
	info_color(info, W);
	ictrtext(info, (char *)s, W);
}

static void blank(HANDLE info)
{
	info_color(info, 0);
	iprintf(info, "");
}

/* Line with a label of n characters */
#define LABEL(n)	info_color(info, (n))

/* "label: value" lines, long values wrapped at blanks */
static void item(HANDLE info, const char *label, const char *value)
{
	char part[W];
	int max = W - LW - 2, n;

	if (!value || !*value) return;
	while (*value) {
		n = strlen(value);
		if (n > max) {
			for (n = max; n > 0 && value[n] != ' '; n--) ;
			if (!n) n = max;
		}
		memcpy(part, value, n);
		part[n] = '\0';
		LABEL(LW);
		if (*label) iprintf(info, "%*.*s: %s", LW, LW, label, part);
		else iprintf(info, "%*s  %s", LW, "", part);
		label = "";
		value += n;
		while (*value == ' ') value++;
	}
}

/* Line of at most W characters */
static void line_w(HANDLE info, int label, const char *s)
{
	char buf[W + 1];

	strncpy(buf, s, W);
	buf[W] = '\0';
	LABEL(label);
	iprintf(info, "%s", buf);
}

/* Size in bytes (64 bit) as text */
static char *size_text(DWORD lo, DWORD hi, char *out)
{
	if (hi || lo >= 0x40000000UL) {		/* GB */
		DWORD gb = hi * 4 + (lo >> 30);
		DWORD tenth = ((lo & 0x3FFFFFFFUL) >> 20) * 10 / 1024;

		if (tenth) sprintf(out, "%lu.%lu GB", gb, tenth);
		else sprintf(out, "%lu GB", gb);
	}
	else if (lo >= 0x100000UL && !(lo & 0xFFFFF))
		sprintf(out, "%lu MB", lo >> 20);
	else if (lo >= 0x100000UL)
		sprintf(out, "%lu KB", lo >> 10);
	else if (lo >= 1024)
		sprintf(out, "%lu KB", lo >> 10);
	else
		sprintf(out, "%lu B", lo);
	return out;
}

static char *addr_text(DWORD lo, DWORD hi, char *out)
{
	if (hi) sprintf(out, "%lX%08lX", hi, lo);
	else sprintf(out, "%08lX", lo);
	return out;
}

static const char *not_386 = L("Needs a 386 or later processor.",
			       "Ben\x94tigt einen 386 oder neueren Prozessor.");

/*------------------------------------------------------------------------*/
/* BIOS memory map							  */
/*------------------------------------------------------------------------*/

static const char *e820_type(DWORD t)
{
	static char buf[16];

	switch ((WORD)t) {
	case 1: return L("Usable", "Frei");
	case 2: return L("Reserved", "Reserviert");
	case 3: return L("ACPI data", "ACPI-Daten");
	case 4: return L("ACPI NVS", "ACPI NVS");
	case 5: return L("Unusable", "Defekt");
	case 6: return L("Disabled", "Abgeschaltet");
	case 7: return L("Persistent", "Persistent");
	}
	sprintf(buf, L("Type %lu", "Typ %lu"), t);
	return buf;
}

void Memory_BIOS_Map(HANDLE info)
{
	E820ENT *e = sysbuf_ptr(MOD.hE820);
	DWORD low = 0, highlo = 0, highhi = 0;
	char a1[20], a2[20], sz[16];
	WORD kk;

	heading(info, "INT 15h E820h");
	blank(info);
	if (SysInfo->cpu.cpu_type < CPU_80386) {
		iprintf(info, (char *)not_386);
		return;
	}
	if (!MOD.nE820) {
		iprintf(info, L("The BIOS does not support INT 15h E820h.",
				"Das BIOS unterst\x81tzt INT 15h E820h nicht."));
	} else {
		line_w(info, W, L("Start-End                 Size  Type",
				  "Anfang-Ende             Gr\x94\xe1" "e  Typ"));
		for (kk = 0; kk < MOD.nE820; kk++, e++) {
			DWORD endlo = e->baselo + e->lenlo - 1;
			DWORD endhi = e->basehi + e->lenhi +
				(endlo < e->baselo ? 1 : 0) - (e->lenlo == 0 ? 1 : 0);

			if (e->lenlo == 0 && e->lenhi) endlo = e->baselo - 1;
			{
				char l[60], r[24];

				sprintf(r, "%s-%s", addr_text(e->baselo, e->basehi, a1),
					addr_text(endlo, endhi, a2));
				sprintf(l, "%-21s %9s  %s", r,
					size_text(e->lenlo, e->lenhi, sz), e820_type(e->type));
				line_w(info, 21, l);
			}
			if (e->type != 1) continue;
			if (!e->basehi && e->baselo < 0x100000UL) {
				DWORD end = e->baselo + e->lenlo;

				if (end > 0x100000UL) end = 0x100000UL;
				low += end - e->baselo;
			} else {
				DWORD o = highlo;

				highlo += e->lenlo;
				highhi += e->lenhi + (highlo < o);
			}
		}
		blank(info);
		item(info, L("Usable < 1 MB", "Frei < 1 MB"),
		     size_text(low, 0, sz));
		item(info, L("Usable > 1 MB", "Frei > 1 MB"),
		     size_text(highlo, highhi, sz));

		/* Areas below 1 MB the BIOS keeps for itself */
		e = sysbuf_ptr(MOD.hE820);
		for (kk = 0; kk < MOD.nE820; kk++, e++) {
			char t[40];

			if (e->type == 1 || e->basehi || e->baselo >= 0x100000UL)
				continue;
			sprintf(t, "%05lX-%05lX %s", e->baselo,
				e->baselo + e->lenlo - 1 < 0xFFFFFUL ?
				e->baselo + e->lenlo - 1 : 0xFFFFFUL,
				e820_type(e->type));
			item(info, L("Reserved < 1 MB", "Reserviert <1 MB"), t);
		}
	}
	if (MOD.flags & MOD_E801) {
		char t[48];

		blank(info);
		heading(info, "INT 15h E801h");
		blank(info);
		sprintf(t, "%u KB", MOD.wE801[0]);
		item(info, "1-16 MB", t);
		sprintf(t, "%u x 64 KB", MOD.wE801[1]);
		item(info, L("Above 16 MB", "\x9a" "ber 16 MB"), t);
	}
}

/*------------------------------------------------------------------------*/
/* PCI									  */
/*------------------------------------------------------------------------*/

static const struct _pciclass {
	BYTE cls, sub, prog;	/* sub/prog 0xFF: any */
	const char *name;
} PciClass[] = {
	{ 0x00, 0x01, 0xFF, L("VGA (old device)", "VGA (altes Ger\x84t)") },
	{ 0x01, 0x00, 0xFF, L("SCSI controller", "SCSI-Controller") },
	{ 0x01, 0x01, 0xFF, L("IDE controller", "IDE-Controller") },
	{ 0x01, 0x02, 0xFF, L("Floppy controller", "Disketten-Controller") },
	{ 0x01, 0x04, 0xFF, L("RAID controller", "RAID-Controller") },
	{ 0x01, 0x05, 0xFF, L("ATA controller", "ATA-Controller") },
	{ 0x01, 0x06, 0x01, L("SATA controller (AHCI)", "SATA-Controller (AHCI)") },
	{ 0x01, 0x06, 0xFF, L("SATA controller", "SATA-Controller") },
	{ 0x01, 0x07, 0xFF, L("SAS controller", "SAS-Controller") },
	{ 0x01, 0x08, 0x02, L("NVMe controller", "NVMe-Controller") },
	{ 0x01, 0xFF, 0xFF, L("Storage controller", "Massenspeicher-Controller") },
	{ 0x02, 0x00, 0xFF, L("Ethernet controller", "Ethernet-Controller") },
	{ 0x02, 0xFF, 0xFF, L("Network controller", "Netzwerk-Controller") },
	{ 0x03, 0x00, 0xFF, L("Display (VGA)", "Grafik (VGA)") },
	{ 0x03, 0xFF, 0xFF, L("Display controller", "Grafik-Controller") },
	{ 0x04, 0x00, 0xFF, L("Video device", "Video-Ger\x84t") },
	{ 0x04, 0x01, 0xFF, L("Audio device", "Audio-Ger\x84t") },
	{ 0x04, 0x03, 0xFF, L("HD Audio controller", "HD-Audio-Controller") },
	{ 0x04, 0xFF, 0xFF, L("Multimedia device", "Multimedia-Ger\x84t") },
	{ 0x05, 0xFF, 0xFF, L("Memory controller", "Speicher-Controller") },
	{ 0x06, 0x00, 0xFF, L("Host bridge", "Host-Br\x81" "cke") },
	{ 0x06, 0x01, 0xFF, L("ISA bridge", "ISA-Br\x81" "cke") },
	{ 0x06, 0x02, 0xFF, L("EISA bridge", "EISA-Br\x81" "cke") },
	{ 0x06, 0x04, 0xFF, L("PCI bridge", "PCI-Br\x81" "cke") },
	{ 0x06, 0x07, 0xFF, L("CardBus bridge", "CardBus-Br\x81" "cke") },
	{ 0x06, 0xFF, 0xFF, L("Bridge", "Br\x81" "cke") },
	{ 0x07, 0x00, 0xFF, L("Serial controller", "Serieller Controller") },
	{ 0x07, 0x01, 0xFF, L("Parallel port", "Parallele Schnittstelle") },
	{ 0x07, 0x03, 0xFF, L("Modem", "Modem") },
	{ 0x07, 0xFF, 0xFF, L("Communication controller", "Kommunikations-Controller") },
	{ 0x08, 0x00, 0xFF, L("Interrupt controller", "Interrupt-Controller") },
	{ 0x08, 0x01, 0xFF, L("DMA controller", "DMA-Controller") },
	{ 0x08, 0x02, 0xFF, L("Timer", "Zeitgeber") },
	{ 0x08, 0x03, 0xFF, L("Real time clock", "Echtzeituhr") },
	{ 0x08, 0x05, 0xFF, L("SD host controller", "SD-Host-Controller") },
	{ 0x08, 0xFF, 0xFF, L("System peripheral", "System-Peripherie") },
	{ 0x09, 0xFF, 0xFF, L("Input device", "Eingabeger\x84t") },
	{ 0x0B, 0xFF, 0xFF, L("Processor", "Prozessor") },
	{ 0x0C, 0x00, 0xFF, L("FireWire controller", "FireWire-Controller") },
	{ 0x0C, 0x03, 0x00, L("USB controller (UHCI)", "USB-Controller (UHCI)") },
	{ 0x0C, 0x03, 0x10, L("USB controller (OHCI)", "USB-Controller (OHCI)") },
	{ 0x0C, 0x03, 0x20, L("USB controller (EHCI)", "USB-Controller (EHCI)") },
	{ 0x0C, 0x03, 0x30, L("USB controller (xHCI)", "USB-Controller (xHCI)") },
	{ 0x0C, 0x03, 0xFF, L("USB controller", "USB-Controller") },
	{ 0x0C, 0x05, 0xFF, L("SMBus controller", "SMBus-Controller") },
	{ 0x0C, 0xFF, 0xFF, L("Serial bus controller", "Serieller Bus-Controller") },
	{ 0x0D, 0xFF, 0xFF, L("Wireless controller", "Funk-Controller") },
	{ 0x10, 0xFF, 0xFF, L("Encryption controller", "Verschl\x81sselung") },
	{ 0x11, 0xFF, 0xFF, L("Signal processing", "Signalverarbeitung") },
	{ 0x12, 0xFF, 0xFF, L("Processing accelerator", "Beschleuniger") },
	{ 0, 0, 0, NULL }
};

const char *pci_classname(BYTE cls, BYTE sub, BYTE prog)
{
	static char buf[24];
	const struct _pciclass *p;

	for (p = PciClass; p->name; p++)
		if (p->cls == cls && (p->sub == 0xFF || p->sub == sub) &&
		    (p->prog == 0xFF || p->prog == prog))
			return p->name;
	sprintf(buf, L("Class %02X.%02X", "Klasse %02X.%02X"), cls, sub);
	return buf;
}

static const struct _pcivendor {
	WORD id;
	const char *name;
} PciVendor[] = {
	{ 0x1002, "AMD/ATI" },	{ 0x1022, "AMD" },	{ 0x1039, "SiS" },
	{ 0x104C, "TI" },	{ 0x105A, "Promise" },	{ 0x1095, "SiI" },
	{ 0x10B7, "3Com" },	{ 0x10B9, "ALi" },	{ 0x10DE, "NVIDIA" },
	{ 0x10EC, "Realtek" },	{ 0x1102, "Creative" },	{ 0x1106, "VIA" },
	{ 0x1180, "Ricoh" },	{ 0x11AB, "Marvell" },	{ 0x1234, "Bochs" },
	{ 0x1274, "Ensoniq" },	{ 0x13F6, "C-Media" },	{ 0x14E4, "Broadcom" },
	{ 0x15AD, "VMware" },	{ 0x168C, "Atheros" },	{ 0x197B, "JMicron" },
	{ 0x1AF4, "virtio" },	{ 0x1B21, "ASMedia" },	{ 0x1B36, "QEMU" },
	{ 0x1B4B, "Marvell" },	{ 0x1D6B, "Linux" },	{ 0x5333, "S3" },
	{ 0x80EE, "VirtualBox" }, { 0x8086, "Intel" },	{ 0x9004, "Adaptec" },
	{ 0x9005, "Adaptec" },	{ 0, NULL }
};

const char *pci_vendorname(WORD ven)
{
	const struct _pcivendor *p;

	for (p = PciVendor; p->name; p++)
		if (p->id == ven) return p->name;
	return "";
}

/* "bb:dd.f" of the PCI function with vendor/device ID, or "" */
static char *pci_owner(WORD ven, WORD dev, char *out)
{
	PCIDEV *d = sysbuf_ptr(MOD.hPci);
	WORD kk;

	*out = '\0';
	for (kk = 0; kk < MOD.nPci; kk++, d++)
		if (d->ven == ven && d->dev == dev) {
			sprintf(out, "%02X:%02X.%X", d->bus, d->devfn >> 3, d->devfn & 7);
			break;
		}
	return out;
}

void Hardware_PCI(HANDLE info)
{
	PCIDEV *d = sysbuf_ptr(MOD.hPci);
	char line[128], t[24];
	WORD kk;
	int i;

	heading(info, L("PCI devices", "PCI-Ger\x84te"));
	blank(info);
	if (SysInfo->cpu.cpu_type < CPU_80386) {
		iprintf(info, (char *)not_386);
		return;
	}
	if (!(MOD.flags & MOD_PCI)) {
		iprintf(info, L("No PCI BIOS found.", "Kein PCI-BIOS gefunden."));
	} else {
		sprintf(line, L("%X.%02X, buses 0-%u", "%X.%02X, Busse 0-%u"),
			MOD.wPciVer >> 8, MOD.wPciVer & 0xFF, MOD.wPciLastBus);
		item(info, "PCI BIOS", line);
		blank(info);
		line_w(info, W, L("Bus:Dv.F Ven:Dev   Function",
				  "Bus:Gr.F Herst:Ger Funktion"));
		for (kk = 0; kk < MOD.nPci; kk++, d++) {
			int n = 0;

			{
				const char *vn = pci_vendorname(d->ven);
				char l[80];

				sprintf(l, "%02X:%02X.%X  %04X:%04X %s%s%s",
					d->bus, d->devfn >> 3, d->devfn & 7, d->ven, d->dev,
					vn, *vn ? " " : "",
					pci_classname(d->cls, d->sub, d->prog));
				line_w(info, 7, l);
			}

			/* Resources */
			line[0] = '\0';
			if (d->irq && d->irq != 0xFF)
				n += sprintf(line + n, " IRQ %u", d->irq);
			for (i = 0; i < 6 && n < 60; i++) {
				DWORD b = d->bar[i];

				if (!b) continue;
				if (b & 1) {
					if (b & 0xFFFC)
						n += sprintf(line + n, L(" I/O %lX", " E/A %lX"), b & 0xFFFCUL);
				} else if ((b & 6) == 4 && i < 5) {
					if ((b & ~0xFUL) || d->bar[i + 1])
						n += sprintf(line + n, L(" Mem %s", " Spch %s"),
							addr_text(b & ~0xFUL, d->bar[i + 1], t));
					i++;
				} else if (b & ~0xFUL)
					n += sprintf(line + n, L(" Mem %lX", " Spch %lX"), b & ~0xFUL);
			}
			if (d->rom & 1)
				n += sprintf(line + n, " ROM %lX", d->rom & ~0x7FFUL);
			/* wrapped at the report width, indented */
			{
				char *p = line;

				while (*p == ' ') p++;
				while (*p) {
					char l[W + 1];
					int m = strlen(p);

					if (m > W - 9) {
						for (m = W - 9; m > 0 && p[m] != ' '; m--) ;
						if (!m) m = W - 9;
					}
					sprintf(l, "         %.*s", m, p);
					line_w(info, 0, l);
					p += m;
					while (*p == ' ') p++;
				}
			}
		}
	}

	blank(info);
	heading(info, L("Option ROMs C0000-EFFFF", "Options-ROMs C0000-EFFFF"));
	blank(info);
	if (!MOD.nOptRom) {
		iprintf(info, L("None found.", "Keine gefunden."));
	} else {
		OPTROM *o = sysbuf_ptr(MOD.hOptRom);

		for (kk = 0; kk < MOD.nOptRom; kk++, o++) {
			DWORD start = (DWORD)o->seg << 4;
			DWORD end = start + o->size * 512UL - 1;

			char l[80];

			if ((o->ven || o->dev) && *pci_owner(o->ven, o->dev, t))
				sprintf(l, "%05lX-%05lX %3u KB %s %s",
					start, end, (o->size + 1) / 2, t,
					pci_classname(o->cls, o->sub, 0xFF));
			else if (o->ven || o->dev)
				sprintf(l, "%05lX-%05lX %3u KB %04X:%04X %s",
					start, end, (o->size + 1) / 2, o->ven, o->dev,
					pci_classname(o->cls, o->sub, 0xFF));
			else
				sprintf(l, "%05lX-%05lX %3u KB %s",
					start, end, (o->size + 1) / 2,
					L("no PCI data (ISA/BIOS)",
					  "ohne PCI-Daten (ISA/BIOS)"));
			line_w(info, 11, l);
		}
	}
}

/*------------------------------------------------------------------------*/
/* Processor, SMBIOS, ACPI						  */
/*------------------------------------------------------------------------*/

static const struct _feat {
	BYTE reg, bit;		/* dwFeat[reg], bit */
	const char *name;
} Feat[] = {
	{ 0, 0, "FPU" },  { 0, 1, "VME" },  { 0, 3, "PSE" },  { 0, 4, "TSC" },
	{ 0, 5, "MSR" },  { 0, 6, "PAE" },  { 0, 8, "CX8" },  { 0, 9, "APIC" },
	{ 0, 11, "SEP" }, { 0, 12, "MTRR" }, { 0, 13, "PGE" }, { 0, 15, "CMOV" },
	{ 0, 16, "PAT" }, { 0, 17, "PSE36" }, { 0, 19, "CLFSH" }, { 0, 23, "MMX" },
	{ 0, 24, "FXSR" }, { 0, 25, "SSE" }, { 0, 26, "SSE2" }, { 0, 28, "HTT" },
	{ 1, 0, "SSE3" }, { 1, 9, "SSSE3" }, { 1, 12, "FMA" }, { 1, 13, "CX16" },
	{ 1, 19, "SSE4.1" }, { 1, 20, "SSE4.2" }, { 1, 22, "MOVBE" },
	{ 1, 23, "POPCNT" }, { 1, 25, "AES" }, { 1, 28, "AVX" },
	{ 1, 30, "RDRAND" }, { 2, 11, "SYSCALL" }, { 2, 20, "NX" },
	{ 2, 27, "RDTSCP" }, { 2, 29, "LM" }, { 2, 31, "3DNow!" },
	{ 3, 0, "LAHF64" }, { 3, 5, "ABM" }, { 3, 6, "SSE4A" },
	{ 0, 0, NULL }
};

static const char *mem_type(BYTE t)
{
	static char buf[8];

	switch (t) {
	case 0x0F: return "SDRAM";	case 0x12: return "DDR";
	case 0x13: return "DDR2";	case 0x18: return "DDR3";
	case 0x1A: return "DDR4";	case 0x1B: return "LPDDR";
	case 0x1C: return "LPDDR2";	case 0x1D: return "LPDDR3";
	case 0x1E: return "LPDDR4";	case 0x22: return "DDR5";
	case 0x23: return "LPDDR5";	case 0x07: return "RAM";
	case 0x02: return L("unknown", "unbekannt");
	}
	sprintf(buf, "%u", t);
	return buf;
}

static void firm_cpu(HANDLE info)
{
	char line[80], t[40];
	const struct _feat *f;
	WORD fam, model, n;

	heading(info, L("Processor (CPUID)", "Prozessor (CPUID)"));
	blank(info);
	if (!(MOD.flags & MOD_CPUID)) {
		iprintf(info, L("No CPUID instruction.", "Kein CPUID-Befehl."));
		return;
	}
	item(info, L("Vendor", "Hersteller"), MOD.szVendor);
	item(info, L("Name", "Name"), MOD.szBrand);
	fam = (WORD)(MOD.dwSig >> 8) & 0xF;
	model = (WORD)(MOD.dwSig >> 4) & 0xF;
	if (fam == 0xF) fam += (WORD)(MOD.dwSig >> 20) & 0xFF;
	if (fam == 6 || fam >= 0xF) model |= ((WORD)(MOD.dwSig >> 16) & 0xF) << 4;
	sprintf(t, L("%u/%u stepping %u (%02X_%02XH)", "%u/%u Stepping %u (%02X_%02XH)"),
		fam, model, (WORD)MOD.dwSig & 0xF, fam, model);
	item(info, L("Family/model", "Familie/Modell"), t);
	item(info, L("64-bit", "64 Bit"),
	     MOD.dwFeat[2] & (1UL << 29) ? L("yes", "ja") : L("no", "nein"));
	if (MOD.dwFeat[1] & (1UL << 31))
		item(info, L("Virtual machine", "Virtuelle Masch."),
		     L("yes (hypervisor)", "ja (Hypervisor)"));

	/* Features, wrapped */
	n = 0;
	line[0] = '\0';
	for (f = Feat; f->name; f++) {
		if (!(MOD.dwFeat[f->reg] & (1UL << f->bit))) continue;
		if (n + strlen(f->name) + 1 > W - LW - 2) {
			item(info, L("Features", "Merkmale"), line);
			n = 0;
			line[0] = '\0';
		}
		n += sprintf(line + n, "%s%s", n ? " " : "", f->name);
	}
	if (n) item(info, L("Features", "Merkmale"), line);
}

static void firm_smbios(HANDLE info)
{
	char t[80];

	if (!(MOD.flags & MOD_SMBIOS)) {
		heading(info, "SMBIOS");
		blank(info);
		iprintf(info, L("No SMBIOS entry point in F0000-FFFFF.",
				"Kein SMBIOS-Einsprungpunkt in F0000-FFFFF."));
		return;
	}
	sprintf(t, "SMBIOS %u.%u", MOD.wSmbVer >> 8, MOD.wSmbVer & 0xFF);
	heading(info, t);
	blank(info);
	if (!MOD.hSmbStr) {
		iprintf(info, L("The SMBIOS table could not be read.",
				"Die SMBIOS-Tabelle konnte nicht gelesen werden."));
		return;
	}
	item(info, L("BIOS vendor", "BIOS-Hersteller"), smb_string(SMB_BIOSVENDOR));
	item(info, L("BIOS version", "BIOS-Version"), smb_string(SMB_BIOSVERSION));
	item(info, L("BIOS date", "BIOS-Datum"), smb_string(SMB_BIOSDATE));
	item(info, L("System", "System"), smb_string(SMB_SYSMFR));
	item(info, "", smb_string(SMB_SYSPRODUCT));
	item(info, "", smb_string(SMB_SYSVERSION));
	item(info, L("Mainboard", "Hauptplatine"), smb_string(SMB_BOARDMFR));
	item(info, "", smb_string(SMB_BOARDPRODUCT));
	item(info, L("Processor", "Prozessor"), smb_string(SMB_CPUVERSION));
	item(info, L("Socket", "Sockel"), smb_string(SMB_CPUSOCKET));
	item(info, L("Speed", "Takt"), smb_string(SMB_CPUSPEED));
	if (MOD.nSmbMem) {
		SMBMEM *m = sysbuf_ptr(MOD.hSmbMem);
		WORD kk;

		blank(info);
		line_w(info, W, L("Memory slot           Size Type   Speed",
				  "Speicherplatz        Gr\x94\xe1" "e Typ    Takt"));
		for (kk = 0; kk < MOD.nSmbMem; kk++, m++) {
			char l[60];

			if (!m->sizemb)
				sprintf(l, "%-16s %s", m->loc, L("empty", "leer"));
			else {
				sprintf(t, "%u MT/s", m->speed);
				sprintf(l, "%-16s %6u MB %-6s %s", m->loc, m->sizemb,
					mem_type(m->type), m->speed ? t : "");
			}
			line_w(info, 16, l);
		}
	}
}

static void firm_acpi(HANDLE info)
{
	char t[60];

	heading(info, "ACPI");
	blank(info);
	if (!(MOD.flags & MOD_ACPI)) {
		iprintf(info, L("No ACPI (RSDP not found).",
				"Kein ACPI (RSDP nicht gefunden)."));
		return;
	}
	sprintf(t, "%s, OEM \"%s\"", MOD.bAcpiRev >= 2 ? "2.0+" : "1.0",
		MOD.szAcpiOem);
	item(info, "ACPI", t);
	sprintf(t, L("%05lX, revision %u", "%05lX, Revision %u"), MOD.dwRsdp,
		MOD.bAcpiRev);
	item(info, "RSDP", t);
	if (MOD.nAcpi) {
		ACPITAB *a = sysbuf_ptr(MOD.hAcpi);
		WORD kk;

		blank(info);
		line_w(info, W, L("Tab. Rev  Length OEM    OEM tab. Address",
				  "Tab. Rev   L\x84nge OEM    OEM-Tab. Adresse"));
		for (kk = 0; kk < MOD.nAcpi; kk++, a++) {
			char l[60];

			sprintf(l, "%.4s %3u %7lu %-6.6s %-8.8s %08lX",
				a->sig, a->rev, a->len, a->oem, a->oemtab, a->addr);
			line_w(info, 4, l);
		}
	} else if (MOD.flags & MOD_XMOVE) {
		item(info, L("Tables", "Tabellen"),
		     L("above 1 MB not readable (INT 15h AH=87h)",
		       "\x81" "ber 1 MB nicht lesbar (INT 15h AH=87h)"));
	}
}

void Hardware_Firmware(HANDLE info)
{
	if (SysInfo->cpu.cpu_type < CPU_80386) {
		heading(info, L("Processor, SMBIOS, ACPI", "Prozessor, SMBIOS, ACPI"));
		blank(info);
		iprintf(info, (char *)not_386);
		return;
	}
	firm_cpu(info);
	blank(info);
	firm_smbios(info);
	blank(info);
	firm_acpi(info);
}
