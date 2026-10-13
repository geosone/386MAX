/*
 * MODINFO.H - information about newer hardware for ASQ
 *
 * Open 386MAX - GNU General Public License version 3.
 *
 * BIOS memory map (E820/E801), CPUID, PCI devices and their option ROMs,
 * ACPI tables and SMBIOS.  Collected by modinfo_get() (MODINFO.C) into
 * SysInfo->Modern, shown by the reports in MODREPT.C, written to and read
 * from snapshots by WRITSYS.C / READSYS.C.
 */

#ifndef MODINFO_INCLUDED
#define MODINFO_INCLUDED

/* E820 memory map entry (as returned by the BIOS) */
typedef struct _e820ent {
	DWORD baselo, basehi;	/* Start address */
	DWORD lenlo, lenhi;	/* Length in bytes */
	DWORD type;		/* 1 usable, 2 reserved, 3 ACPI, 4 NVS, 5 bad */
	DWORD attr;		/* ACPI 3 extended attributes */
} E820ENT;
#define MAXE820 	64

/* PCI function */
typedef struct _pcidev {
	BYTE bus, devfn;	/* Bus, device * 8 + function */
	BYTE hdr, rev;		/* Header type, revision */
	WORD ven, dev;		/* Vendor and device ID */
	WORD subven, subdev;	/* Subsystem IDs (header type 0) */
	BYTE cls, sub, prog;	/* Class code */
	BYTE irq;		/* Interrupt line (FFh = none) */
	DWORD bar[6];		/* Base address registers (header type 0) */
	DWORD rom;		/* Expansion ROM base address */
} PCIDEV;
#define MAXPCI		64

/* Option ROM in C0000-EFFFF */
typedef struct _optrom {
	WORD seg;		/* Segment */
	WORD size;		/* Size in 512 byte blocks */
	WORD ven, dev;		/* From the PCI data structure, 0 if none */
	BYTE cls, sub;		/* Class code of the PCI data structure */
} OPTROM;
#define MAXOPTROM	16

/* ACPI table header */
typedef struct _acpitab {
	char sig[4];		/* Signature */
	DWORD len;		/* Length */
	BYTE rev;		/* Revision */
	char oem[6];		/* OEM ID */
	char oemtab[8]; 	/* OEM table ID */
	DWORD addr;		/* Physical address */
} ACPITAB;
#define MAXACPI 	32

/* SMBIOS memory device (type 17) */
typedef struct _smbmem {
	char loc[16];		/* Device locator */
	WORD sizemb;		/* Size in MB, 0 = empty slot */
	WORD speed;		/* MT/s, 0 = unknown */
	BYTE type;		/* Memory type (SMBIOS table 76) */
} SMBMEM;
#define MAXSMBMEM	16

/* SMBIOS strings (SysInfo->Modern.hSmbStr: item, string, ..., 0) */
enum {
	SMB_END,
	SMB_BIOSVENDOR, SMB_BIOSVERSION, SMB_BIOSDATE,
	SMB_SYSMFR, SMB_SYSPRODUCT, SMB_SYSVERSION,
	SMB_BOARDMFR, SMB_BOARDPRODUCT,
	SMB_CPUSOCKET, SMB_CPUVERSION, SMB_CPUSPEED,
	SMB_LAST
};

typedef struct _moderninfo {
	WORD flags;
#define MOD_E820	0x0001	/* E820 map collected */
#define MOD_E801	0x0002	/* E801 values valid */
#define MOD_CPUID	0x0004	/* CPUID available */
#define MOD_PCI 	0x0008	/* PCI BIOS present */
#define MOD_ACPI	0x0010	/* ACPI RSDP found */
#define MOD_SMBIOS	0x0020	/* SMBIOS entry point found */
#define MOD_XMOVE	0x0040	/* INT 15h AH=87h failed: tables not read */
	WORD nE820;		/* E820 entries */
	SYSBUFH hE820;		/* E820ENT [nE820] */
	WORD wE801[2];		/* KB 1-16 MB, 64 KB blocks above 16 MB */

	DWORD dwMaxLeaf;	/* Highest standard CPUID leaf */
	DWORD dwMaxExt; 	/* Highest extended CPUID leaf */
	char szVendor[13];	/* CPU vendor ID */
	char szBrand[49];	/* CPU brand string */
	DWORD dwSig;		/* Leaf 1 EAX: family/model/stepping */
	DWORD dwFeat[4];	/* Leaf 1 EDX, ECX; 80000001h EDX, ECX */

	WORD wPciVer;		/* PCI BIOS version (BCD) */
	WORD wPciLastBus;	/* Last PCI bus */
	WORD nPci;		/* PCI functions */
	SYSBUFH hPci;		/* PCIDEV [nPci] */
	WORD nOptRom;		/* Option ROMs */
	SYSBUFH hOptRom;	/* OPTROM [nOptRom] */

	BYTE bAcpiRev;		/* RSDP revision */
	char szAcpiOem[7];	/* RSDP OEM ID */
	DWORD dwRsdp;		/* RSDP address */
	DWORD dwRsdt;		/* RSDT address */
	DWORD dwXsdt[2];	/* XSDT address (low, high) */
	WORD nAcpi;		/* ACPI tables */
	SYSBUFH hAcpi;		/* ACPITAB [nAcpi] */

	WORD wSmbVer;		/* SMBIOS version (major * 256 + minor) */
	DWORD dwSmbTable;	/* Structure table address */
	WORD wSmbLen;		/* Structure table length */
	SYSBUFH hSmbStr;	/* SMBIOS strings, see SMB_* */
	WORD nSmbMem;		/* Memory devices */
	SYSBUFH hSmbMem;	/* SMBMEM [nSmbMem] */
} MODERNINFO;

void modinfo_get(void);			/* Collect (live system) */
const char *pci_classname(BYTE cls, BYTE sub, BYTE prog);
const char *pci_vendorname(WORD ven);
const char *smb_string(int item);	/* Collected SMBIOS string or NULL */

/* MODREPT.C: reports */
void Memory_BIOS_Map(HANDLE info);
void Hardware_PCI(HANDLE info);
void Hardware_Firmware(HANDLE info);

/* MODHW.ASM */
int pascal far MODHW_E820(DWORD far *cont, void far *buf);
int pascal far MODHW_E801(WORD far *res);
int pascal far MODHW_HASCPUID(void);
void pascal far MODHW_CPUID(DWORD leaf, DWORD far *regs);
int pascal far MODHW_PCIBIOS(WORD far *info);
DWORD pascal far MODHW_PCIREAD(WORD busdevfn, WORD reg);
int pascal far MODHW_XMOVE(DWORD phys, void far *dst, WORD bytes);

#endif /* MODINFO_INCLUDED */
