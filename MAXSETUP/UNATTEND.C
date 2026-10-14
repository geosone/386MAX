/* UNATTEND.C - unattended Windows installation from SETUP.INF (SETUP.EXE)
 *
 * SETUP.INF (written by MAXCFG) lies next to SETUP.EXE.  With [Setup]
 * Unattended=1, UDialogBox() lets each question dialog initialize itself,
 * fills its controls from SETUP.INF and presses Continue: the dialog's own
 * code checks and takes the values.  Dialogs that need the user anyway
 * (another disk, the MCA reference directory) and the progress dialogs
 * are shown as before.  UMessageBox() answers with OK / Yes (Cancel for
 * Retry/Cancel) and notes the message in SETUPMAX.LOG.  SETUP.INF is
 * copied to the 386MAX directory for MAXIMIZE and WINMAXIM.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#define STRICT
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "setup.h"

int Unattended = 0;
static char szInf[_MAX_PATH] = "";
static char szLog[_MAX_PATH] = "";

#define INF	"SETUP.INF"

static void ulog (LPCSTR lp1, LPCSTR lp2)
{
	FILE *fp;

	if (!*szLog || !(fp = fopen (szLog, "a"))) return;
	fprintf (fp, "SETUP: %Fs%Fs\n", lp1, lp2 ? lp2 : (LPCSTR)"");
	fclose (fp);
}

static int inf_int (LPCSTR sect, LPCSTR key, int def)
{
	char buf[16];

	GetPrivateProfileString (sect, key, "", buf, sizeof (buf), szInf);
	switch (buf[0]) {
	case '1': case 'Y': case 'y': case 'J': case 'j': case 'T': case 't':
		return (1);
	case '0': case 'N': case 'n': case 'F': case 'f':
		return (0);
	case 'O': case 'o':
		return (buf[1] == 'N' || buf[1] == 'n');
	}
	return (def);
}

/* Called with the full name of SETUP.EXE */
void unattend_init (LPCSTR lpSetup)
{
	char *p;
	char win[_MAX_PATH];

	lstrcpy (szInf, lpSetup);
	p = strrchr (szInf, '\\');
	strcpy (p ? p + 1 : szInf, INF);
	{
		OFSTRUCT of;

		if (OpenFile (szInf, &of, OF_EXIST) == HFILE_ERROR) {
			*szInf = '\0';
			return;
		}
	}
	GetWindowsDirectory (win, sizeof (win));
	wsprintf (szLog, "%c:\\SETUPMAX.LOG", win[0]);
	Unattended = inf_int ("Setup", "Unattended", 0);
	ulog ("answers from ", szInf);
	if (Unattended) ulog ("unattended", NULL);
}

/* SETUP.INF to the 386MAX directory (for MAXIMIZE, WINMAXIM) */
void unattend_copy (LPCSTR lpDir)
{
	char dst[_MAX_PATH];
	int len;

	if (!*szInf) return;
	lstrcpy (dst, lpDir);
	len = strlen (dst);
	if (len && dst[len - 1] != '\\') strcat (dst, "\\");
	strcat (dst, INF);
	if (lstrcmpi (dst, szInf)) FileCopy (dst, szInf);	// (target, source)
}

/* Fill in the controls of a dialog; return the button to press (0: none) */
static int answer (HWND hDlg, int id)
{
	char buf[_MAX_PATH];

	switch (id) {
	case WELCOMEDLGBOX:
	case LICENSEDLGBOX:
	case MULTIDLGBOX:
	case ASKQUITDLGBOX:
		return (IDC_CONTINUE);

	case DIRECTORYDLGBOX:
		GetPrivateProfileString ("Setup", "Directory", "", buf, sizeof (buf), szInf);
		if (*buf) SetDlgItemText (hDlg, IDC_PATH, buf);
		CheckDlgButton (hDlg, IDC_PROGRAMS, inf_int ("Setup", "ProgramFiles",
			IsDlgButtonChecked (hDlg, IDC_PROGRAMS)));
		CheckDlgButton (hDlg, IDC_ONLINEHELP, inf_int ("Setup", "OnlineHelp",
			IsDlgButtonChecked (hDlg, IDC_ONLINEHELP)));
		CheckDlgButton (hDlg, IDC_DOSREADER, inf_int ("Setup", "DOSHelpReader",
			IsDlgButtonChecked (hDlg, IDC_DOSREADER)));
		return (IDC_CONTINUE);

	case CONFIGUREDLGBOX:
		CheckDlgButton (hDlg, IDC_GOAHEAD, inf_int ("Windows", "GoAhead",
			IsDlgButtonChecked (hDlg, IDC_GOAHEAD)));
		CheckDlgButton (hDlg, IDC_MAXMETER, inf_int ("Windows", "MAXmeter",
			IsDlgButtonChecked (hDlg, IDC_MAXMETER)));
		CheckDlgButton (hDlg, IDC_MDA, inf_int ("386MAX", "MDA",
			IsDlgButtonChecked (hDlg, IDC_MDA)));
		CheckDlgButton (hDlg, IDC_EMS, inf_int ("386MAX", "EMS",
			IsDlgButtonChecked (hDlg, IDC_EMS)));
		CheckDlgButton (hDlg, IDC_QMT, inf_int ("386MAX", "MemoryTester",
			IsDlgButtonChecked (hDlg, IDC_QMT)));
		return (IDC_CONTINUE);

	case FILESDLGBOX:
		GetPrivateProfileString ("Setup", "ConfigChanges", "", buf, sizeof (buf), szInf);
		if (!lstrcmpi (buf, "Save"))
			CheckRadioButton (hDlg, IDC_UPDATEFILES, IDC_NEWFILES, IDC_NEWFILES);
		else if (!lstrcmpi (buf, "Apply"))
			CheckRadioButton (hDlg, IDC_UPDATEFILES, IDC_NEWFILES, IDC_UPDATEFILES);
		return (IDC_CONTINUE);

	case SHOWDLGBOX:
		return (IDOK);

	case EXITSUCCESSDLGBOX:		/* Maximize now? */
		return (inf_int ("Setup", "RunMaximize", 1) ? IDC_CONTINUE : IDC_EXIT);

	case EXITREBOOTDLGBOX:		/* Reboot / restart Windows */
	case EXITRESTARTDLGBOX:
		return (IDC_CONTINUE);

	case EXITNEWDLGBOX:
		return (IDC_EXIT);
	}
	return (0);			/* Shown as before */
}

/* The dialog procedures of the open dialogs (modal dialogs nest) */
#define MAXNEST 4
static struct {
	DLGPROC lpfn;
	int id;
	HWND hDlg;
} Nest[MAXNEST];
static int nNest = 0;

BOOL CALLBACK __export UnattendDlgProc (HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam)
{
	int i, n;
	BOOL rc;

	for (n = nNest - 1, i = 0; i < nNest; i++) {
		if (Nest[i].hDlg == hDlg) {
			n = i;
			break;
		}
	}
	if (n < 0) return (FALSE);
	if (msg == WM_INITDIALOG) Nest[n].hDlg = hDlg;

	rc = (*Nest[n].lpfn) (hDlg, msg, wParam, lParam);

	if (msg == WM_INITDIALOG) {
		int btn = answer (hDlg, Nest[n].id);

		if (btn) {
			char sz[16];

			wsprintf (sz, "%d", Nest[n].id);
			ulog ("answered dialog ", sz);
			PostMessage (hDlg, WM_COMMAND, btn, 0L);
		}
	}
	return (rc);
}

int UDialogBox (HINSTANCE hInst, LPCSTR lpTemplate, HWND hParent, DLGPROC lpfn)
{
	int rc;

	if (!Unattended || HIWORD ((DWORD)lpTemplate) || nNest >= MAXNEST)
		return (DialogBox (hInst, lpTemplate, hParent, lpfn));

	Nest[nNest].lpfn = lpfn;
	Nest[nNest].id = LOWORD ((DWORD)lpTemplate);
	Nest[nNest].hDlg = NULL;
	nNest++;
	rc = DialogBox (hInst, lpTemplate, hParent, (DLGPROC)UnattendDlgProc);
	nNest--;
	return (rc);
}

int UMessageBox (HWND hWnd, LPCSTR lpText, LPCSTR lpCaption, UINT uType)
{
	if (!Unattended) return (MessageBox (hWnd, lpText, lpCaption, uType));
	ulog ("message: ", lpText);
	switch (uType & 0x0F) {
	case MB_YESNO:
	case MB_YESNOCANCEL:
		return (IDYES);
	case MB_RETRYCANCEL:
		return (IDCANCEL);
	case MB_ABORTRETRYIGNORE:
		return (IDIGNORE);
	}
	return (IDOK);
}
