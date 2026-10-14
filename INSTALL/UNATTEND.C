/* UNATTEND.C - unattended installation from SETUP.INF (SETUPDOS)
 *
 * SETUP.INF (written by MAXCFG) lies next to SETUPDOS.EXE, or /A:file
 * names it.  [Advanced] replaces the old command line switches; with
 * [Setup] Unattended=1 the dialogs are answered from it (DialogHook in
 * QUILIB's dialog()); a dialog without an answer takes its default
 * button, noted in SETUPMAX.LOG on the boot drive.  SETUP.INF is copied
 * to the 386MAX directory, where MAXIMIZE reads its [Maximize] section.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <io.h>

#include "compile.h"
#include "common.h"
#include "commfunc.h"
#include "extn.h"
#include "fldedit.h"
#include "keyboard.h"
#include "dialog.h"
#include "ui.h"
#include "screen.h"
#include "setupinf.h"

void copy_file (char *srcpath, char *dstpath);
enum boolean locate_winfles (char *sysini_path);

char InfPath[MAXPATH+1] = "";		/* /A:file */

extern int TimeoutInput;		/* QUILIB: input times out ... */
extern long TimeoutDelay;		/* ... after this many ms */

/* Yes/no answer from SETUP.INF, else the default button */
static KEYCODE yesno (DIALOGPARM *parm, const char *sect, const char *key)
{
	if (!inf_get (sect, key)) return (dialog_default (parm));
	return (inf_bool (sect, key, 0) ? RESP_YES : RESP_NO);
}

static KEYCODE inst_hook (DIALOGPARM *parm, char *title, char *message,
	int helpnum, DIALOGEDIT *edit, int nEdit)
{
	const char *v;

	if (!message) message = "";

	/* Windows setup?  SETUPDOS stays the DOS setup */
	if (!strcmp (message, "M.NoWinSupp")) return (RESP_NO);
	if (!strcmp (message, "M.NoWin")) return (RESP_NO);
	if (!strcmp (message, "M.WinPath")) return (KEY_ESCAPE);

	if (!strcmp (message, "M.DestDir") && nEdit > 0 &&
	    (v = inf_get ("Setup", "Directory")) != NULL) {
		strncpy (edit[0].editText, v, edit[0].editLen);
		edit[0].editText[edit[0].editLen] = '\0';
		return (KEY_ENTER);
	}
	if (!strcmp (message, "L.EnableEMS") || !strcmp (message, "L.DisableEMS"))
		return (yesno (parm, "386MAX", "EMS"));
	if (!strcmp (message, "M.GetMono") || !strcmp (message, "M.SVGAWarn"))
		return (yesno (parm, "386MAX", "MDA"));
	if (!strcmp (message, "M.QMT"))
		return (yesno (parm, "386MAX", "MemoryTester"));
	if (!strcmp (message, "M.Maximize") || !strcmp (message, "M.MaxBack") ||
	    !strcmp (message, "M.NoMaximize"))
		return (inf_bool ("Setup", "RunMaximize", 1) ? RESP_YES : RESP_NO);
	if (!strcmp (message, "L.MMMaximize"))
		return (inf_bool ("Setup", "RunMaximize", 1) ? RESP_REBOOT :
							dialog_default (parm));

	/* Everything else: notes, warnings, errors */
	inf_log ("SETUPDOS: %s: %.60s (default)", title ? title : "",
		*message ? message : "?");
	return (dialog_default (parm));
}

/* After the command line: read SETUP.INF, apply [Advanced] */
void unattend_init (void)
{
	char path[MAXPATH+1];
	const char *v;

	if (*InfPath) strcpy (path, InfPath);
	else sprintf (path, "%s" SETUPINF_NAME, source_subdir);
	if (inf_load (path)) return;
	strcpy (InfPath, path);

	sprintf (path, "%c:\\SETUPMAX.LOG", boot_drive);
	inf_logfile (path);
	inf_log ("SETUPDOS: answers from %s%s", InfPath,
		Unattended ? " (unattended)" : "");

	/* [Advanced]: the old switches /S /U /B /C /V /W /O /P */
	if (!(VGAWARN >= 0 && (VGAWARN & VW_FORCED)) &&
	    (v = inf_get ("Advanced", "VideoB000")) != NULL) {
		if (!stricmp (v, "Safe")) VGAWARN = VW_SAFE|VW_FORCED;
		else if (!stricmp (v, "Unsafe")) VGAWARN = VW_UNSAFE|VW_FORCED;
	}
	if ((v = inf_get ("Advanced", "Screen")) != NULL && !ScreenSet) {
		if (!stricmp (v, "Mono")) { ScreenType = SCREEN_MONO; ScreenSet = TRUE; }
		else if (!stricmp (v, "Color")) { ScreenType = SCREEN_COLOR; ScreenSet = TRUE; }
	}
	if (!inf_bool ("Advanced", "Logo", 1)) GraphicsLogo = 0;
	if (inf_bool ("Advanced", "SnowControl", 0)) SnowControl = TRUE;
	if ((v = inf_get ("Advanced", "Overwrite")) != NULL) {
		if (!stricmp (v, "Older")) Overwrite = TRUE;
		else if (!stricmp (v, "Changed")) PatchPrep = TRUE;
	}

	if (!Unattended) return;
	DialogHook = inst_hook;
	TimeoutInput = 1;		/* Any other wait (logo...): Enter */
	TimeoutDelay = 3000L;

	/* Windows entries but no Windows: only a note */
	if (inf_section ("Windows")) {
		char win[MAXPATH+1];

		if (!locate_winfles (win)) {
			printf ("SETUP.INF: [Windows] entries, but Windows is not installed - ignored.\n");
			inf_log ("SETUPDOS: [Windows] entries, but Windows is not installed - ignored");
		}
		else inf_log ("SETUPDOS: [Windows] entries are for the Windows setup (SETUP.EXE)");
	}
}

/* SETUP.INF to the 386MAX directory (for MAXIMIZE) */
void unattend_copy (void)
{
	char path[MAXPATH+1];

	if (!inf_loaded ()) return;
	sprintf (path, "%s" SETUPINF_NAME, dest_subdir);
	if (stricmp (path, InfPath)) copy_file (InfPath, path);
}

/* CONFIG.SYS & co.: 1 = make the changes, 0 = only *.ADD files */
int unattend_apply_config (void)
{
	const char *v = inf_get ("Setup", "ConfigChanges");

	return (!(v && !stricmp (v, "Save")));
}
