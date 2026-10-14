/* OPTTAB.C - the options of SETUP.INF (MAXCFG, DOS and Windows)
 *
 * One table for both front ends: the answers of the installers (SETUPDOS,
 * SETUP for Windows, MAXIMIZE, WINMAXIM, see INCLUDE/SETUPINF.H).  A value
 * of "" is not written: the installer asks.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "opttab.h"

#ifdef LANG_GR
#define T(us,gr)	gr
#else
#define T(us,gr)	us
#endif

const char *TxtAsk = T("(ask)", "(fragen)");

OPTPAGE Pages[] = {
	{ "Setup",	"Setup" },
	{ "386MAX",	"386MAX" },
	{ "Windows",	"Windows" },
	{ "Maximize",	"Maximize" },
	{ "Advanced",	T("Advanced", "Erweitert") },
};
int nPages = sizeof (Pages) / sizeof (Pages[0]);

OPTION Options[] = {
{ "Setup", "Unattended", OT_BOOL, "1", NULL,
  T("Unattended installation", "Unbeaufsichtigte Installation"),
  T("No questions: every answer from SETUP.INF, defaults for the rest.",
    "Keine Fragen: Antworten aus SETUP.INF, sonst die Voreinstellung.") },
{ "Setup", "Directory", OT_TEXT, "C:\\QMAX", NULL,
  T("Install to", "Installieren nach"),
  T("Directory for the Open 386MAX files.",
    "Verzeichnis f\x81r die Dateien von Open 386MAX.") },
{ "Setup", "ProgramFiles", OT_BOOL, "1", NULL,
  T("Program files", "Programmdateien"),
  T("Windows setup: install the program files.",
    "Windows-Setup: Programmdateien installieren.") },
{ "Setup", "OnlineHelp", OT_BOOL, "1", NULL,
  T("On-line help", "Online-Hilfe"),
  T("Windows setup: install the Windows help.",
    "Windows-Setup: Windows-Hilfe installieren.") },
{ "Setup", "DOSHelpReader", OT_BOOL, "1", NULL,
  T("DOS help reader", "DOS-Hilfeleser"),
  T("Windows setup: install the help reader for DOS.",
    "Windows-Setup: Hilfeleser f\x81r DOS installieren.") },
{ "Setup", "ConfigChanges", OT_CHOICE, "Apply", "Apply|Save",
  T("CONFIG.SYS changes", "\x8enderungen an CONFIG.SYS"),
  T("Apply: SETUP changes CONFIG.SYS etc.  Save: only *.ADD files.",
    "Apply: SETUP \x84ndert CONFIG.SYS usw.  Save: nur *.ADD-Dateien.") },
{ "Setup", "RunMaximize", OT_BOOL, "1", NULL,
  T("Run Maximize afterwards", "Danach Maximize starten"),
  T("Maximize loads drivers and programs into high DOS memory.",
    "Maximize l\x84\x64t Treiber und Programme in den HiDOS-Speicher.") },

{ "386MAX", "EMS", OT_BOOL, "0", NULL,
  T("Provide EMS memory", "EMS-Speicher bereitstellen"),
  T("Expanded memory for programs that need it (costs a 64 KB frame).",
    "Expansionsspeicher f\x81r Programme, die ihn brauchen (64-KB-Fenster).") },
{ "386MAX", "MDA", OT_BOOL, "1", NULL,
  T("Use the MDA region (B000-B800)", "MDA-Bereich nutzen (B000-B800)"),
  T("Recovers 32 KB of high DOS memory on VGA systems without MDA.",
    "Gewinnt 32 KB HiDOS-Speicher auf VGA-Systemen ohne MDA.") },
{ "386MAX", "MemoryTester", OT_BOOL, "0", NULL,
  T("Memory test at boot (QMT)", "Speichertest beim Start (QMT)"),
  T("Runs the Qualitas Memory Tester from AUTOEXEC.BAT.",
    "Startet den Qualitas Memory Tester aus AUTOEXEC.BAT.") },

{ "Windows", "GoAhead", OT_BOOL, "1", NULL,
  T("Go Ahead", "Go Ahead"),
  T("Windows setup: more low DOS memory for DOS boxes.",
    "Windows-Setup: mehr LoDOS-Speicher f\x81r DOS-Fenster.") },
{ "Windows", "MAXmeter", OT_BOOL, "1", NULL,
  T("MAXmeter", "MAXmeter"),
  T("Windows setup: the memory meter in the Startup group.",
    "Windows-Setup: Speicheranzeige in der Autostart-Gruppe.") },

{ "Maximize", "Mode", OT_CHOICE, "Express", "Express|Custom",
  T("Maximize mode", "Maximize-Modus"),
  T("Express decides everything; Custom asks (not unattended).",
    "Express entscheidet alles; Custom fragt (nicht unbeaufsichtigt).") },
{ "Maximize", "ROMSearch", OT_BOOL, "0", NULL,
  T("ROM search", "ROM-Suche"),
  T("Finds unused ROM space; needs a key press and mouse movement.",
    "Findet ungenutzten ROM-Platz; braucht Tastendruck und Mausbewegung.") },
{ "Maximize", "VGASwap", OT_BOOL, "1", NULL,
  T("VGASWAP", "VGASWAP"),
  T("Moves the VGA BIOS to gain a contiguous high DOS region.",
    "Verlagert das VGA-BIOS f\x81r einen zusammenh\x84ngenden HiDOS-Bereich.") },
{ "Maximize", "ExtraDOS", OT_BOOL, "1", NULL,
  T("ExtraDOS", "ExtraDOS"),
  T("FILES, BUFFERS, LASTDRIVE, STACKS high (DR-DOS: HIFILES= etc.).",
    "FILES, BUFFERS, LASTDRIVE, STACKS hoch (DR-DOS: HIFILES= usw.).") },
{ "Maximize", "DOSStart", OT_BOOL, "1", NULL,
  T("Maximize DOSSTART.BAT", "DOSSTART.BAT maximieren"),
  T("Windows 9x: also the batch file of the MS-DOS mode.",
    "Windows 9x: auch die Batchdatei des MS-DOS-Modus.") },

{ "Advanced", "VideoB000", OT_CHOICE, "Auto", "Auto|Safe|Unsafe",
  T("Video memory B000-B800", "Videospeicher B000-B800"),
  T("Auto: test the video card; Safe/Unsafe: as /S and /U of SETUP.",
    "Auto: Grafikkarte pr\x81\x66\x65n; Safe/Unsafe: wie /S und /U von SETUP.") },
{ "Advanced", "Overwrite", OT_CHOICE, "All", "All|Older|Changed",
  T("Overwrite files", "Dateien \x81\x62\x65rschreiben"),
  T("All files; only older ones (/O); only changed ones (/P).",
    "Alle; nur \x84ltere (/O); nur ge\x84nderte (/P).") },
{ "Advanced", "Screen", OT_CHOICE, "Auto", "Auto|Color|Mono",
  T("Screen", "Bildschirm"),
  T("Colors of the DOS programs (/C, /B).",
    "Farben der DOS-Programme (/C, /B).") },
{ "Advanced", "Logo", OT_BOOL, "1", NULL,
  T("Logo", "Logo"),
  T("The graphic logo at the start (/V turns it off).",
    "Das Grafiklogo beim Start (/V schaltet es ab).") },
{ "Advanced", "SnowControl", OT_BOOL, "0", NULL,
  T("CGA snow control", "CGA-Schneeschutz"),
  T("For old CGA cards that flicker (/W).",
    "F\x81r alte CGA-Karten, die flimmern (/W).") },
};
int nOptions = sizeof (Options) / sizeof (Options[0]);

void opt_defaults (void)
{
	int i;

	for (i = 0; i < nOptions; i++) {
		strncpy (Options[i].value, Options[i].def, OPTVALLEN - 1);
		Options[i].value[OPTVALLEN - 1] = '\0';
	}
}

static char *trim (char *s)
{
	char *e;

	while (*s == ' ' || *s == '\t') s++;
	e = s + strlen (s);
	while (e > s && strchr (" \t\r\n", e[-1])) e--;
	*e = '\0';
	return (s);
}

/* A file that exists: its keys, "" for the missing ones (ask) */
int opt_load (const char *path)
{
	FILE *fp = fopen (path, "r");
	char line[160], sect[32], *l, *eq, *c;
	int i;

	if (!fp) return (-1);
	for (i = 0; i < nOptions; i++) Options[i].value[0] = '\0';
	sect[0] = '\0';
	while (fgets (line, sizeof (line), fp)) {
		if ((c = strchr (line, ';')) != NULL) *c = '\0';
		l = trim (line);
		if (*l == '[') {
			if ((c = strchr (l, ']')) != NULL) *c = '\0';
			strncpy (sect, trim (l + 1), sizeof (sect) - 1);
			sect[sizeof (sect) - 1] = '\0';
			continue;
		}
		if (!(eq = strchr (l, '='))) continue;
		*eq = '\0';
		l = trim (l);
		for (i = 0; i < nOptions; i++) {
			if (stricmp (Options[i].sect, sect) || stricmp (Options[i].key, l)) continue;
			strncpy (Options[i].value, trim (eq + 1), OPTVALLEN - 1);
			Options[i].value[OPTVALLEN - 1] = '\0';
			break;
		}
	}
	fclose (fp);
	return (0);
}

int opt_save (const char *path)
{
	FILE *fp = fopen (path, "w");
	int p, i, any;

	if (!fp) return (-1);
	fprintf (fp, "; SETUP.INF - answers for the installation of Open 386MAX\n"
		     "; (MAXCFG.EXE).  Read by SETUPDOS, SETUP (Windows), MAXIMIZE and\n"
		     "; WINMAXIM; a missing key: the installer asks.\n");
	for (p = 0; p < nPages; p++) {
		for (any = i = 0; i < nOptions; i++) {
			if (stricmp (Options[i].sect, Pages[p].sect) || !Options[i].value[0]) continue;
			if (!any++) fprintf (fp, "\n[%s]\n", Pages[p].sect);
			fprintf (fp, "%s=%s\n", Options[i].key, Options[i].value);
		}
	}
	return (fclose (fp) ? -1 : 0);
}

int opt_nchoices (const OPTION *o)
{
	const char *p;
	int n;

	if (o->type == OT_BOOL) return (2);
	if (o->type != OT_CHOICE) return (0);
	for (n = 1, p = o->choices; *p; p++) if (*p == '|') n++;
	return (n);
}

/* n-th choice (OT_BOOL: "1", "0") */
int opt_choice (const OPTION *o, int n, char *buf, int size)
{
	const char *p, *e;

	if (o->type == OT_BOOL) {
		strcpy (buf, n ? "0" : "1");
		return (n < 2);
	}
	for (p = o->choices; n > 0 && p; n--) {
		p = strchr (p, '|');
		if (p) p++;
	}
	if (!p) return (0);
	e = strchr (p, '|');
	if (!e) e = p + strlen (p);
	if (e - p >= size) e = p + size - 1;
	memcpy (buf, p, e - p);
	buf[e - p] = '\0';
	return (1);
}

int opt_choiceindex (const OPTION *o)
{
	char buf[OPTVALLEN];
	int i, n = opt_nchoices (o);

	if (!o->value[0]) return (-1);
	if (o->type == OT_BOOL) {
		return (strchr ("1YyJjTt", o->value[0]) || !stricmp (o->value, "On")) ? 0 : 1;
	}
	for (i = 0; i < n; i++) {
		opt_choice (o, i, buf, sizeof (buf));
		if (!stricmp (buf, o->value)) return (i);
	}
	return (-1);
}
