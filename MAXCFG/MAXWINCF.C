/* MAXWINCF.C - MAXCFG for Windows: edit SETUP.INF (unattended installation)
 *
 * The Windows part of MAXCFG.EXE (its DOS stub is MAXDOSCF.C): one page
 * per section, like MSCONFIG of the Windows 98 support CD.  The controls
 * come from the option table (OPTTAB.C): a yes/no option is a three-state
 * check box (gray: the installer asks), a choice a list with "(ask)"
 * first, a text an edit field (empty: ask).
 *
 *   MAXCFG [file]       (default: SETUP.INF next to MAXCFG.EXE)
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#define STRICT
#include <windows.h>
#include <stdio.h>
#include <string.h>

#include "opttab.h"
#include "maxcfg.h"

#ifdef LANG_GR
#define T(us,gr)	gr
#else
#define T(us,gr)	us
#endif

#define ID_TAB		100	/* + page */
#define ID_OPT		1000	/* + option */
#define ID_LABEL	2000	/* + option */
#define ID_HELP		300
#define ID_FILE		301
#define ID_FRAME	302

#define XMARGIN 10
#define TABY	8
#define TABH	22
#define ROWY	48
#define ROWH	24
#define WIDTH	480
#define HEIGHT	400
#define BOTTOMY (ROWY + 9 * ROWH + 50)

static HINSTANCE hInst;
static HWND hMain;
static HFONT hFont;
static int Page = 0;
static BOOL Changed = FALSE;
static char FileName[128];
static char AppTitle[] = T("Open 386MAX - answers for the installation",
			   "Open 386MAX - Antworten f\xfcr die Installation");

static HWND Ctl (int id) { return GetDlgItem (hMain, id); }

static HWND child (LPCSTR cls, LPCSTR text, DWORD style, int x, int y, int w, int h, int id)
{
	HWND hwnd = CreateWindow (cls, text, WS_CHILD | style, x, y, w, h,
				  hMain, (HMENU)id, hInst, NULL);

	SendMessage (hwnd, WM_SETFONT, (WPARAM)hFont, 0L);
	return (hwnd);
}

/* Controls for every option (shown per page) */
static void create_controls (void)
{
	int p, i, n, y;
	char buf[OPTVALLEN];

	for (p = 0; p < nPages; p++)
		child ("BUTTON", Pages[p].title, WS_VISIBLE | BS_PUSHBUTTON,
		       XMARGIN + p * 90, TABY, 86, TABH, ID_TAB + p);
	child ("BUTTON", "", WS_VISIBLE | BS_GROUPBOX, XMARGIN - 4, ROWY - 12,
	       WIDTH - 2 * XMARGIN, 9 * ROWH + 12, ID_FRAME);

	for (p = 0; p < nPages; p++) {
		for (n = i = 0; i < nOptions; i++) {
			OPTION *o = &Options[i];

			if (lstrcmpi (o->sect, Pages[p].sect)) continue;
			y = ROWY + n++ * ROWH;
			if (o->type == OT_BOOL) {
				child ("BUTTON", o->label, WS_TABSTOP | BS_AUTO3STATE,
				       XMARGIN + 6, y, 300, 20, ID_OPT + i);
				continue;
			}
			child ("STATIC", o->label, SS_LEFT, XMARGIN + 6, y + 3, 190, 18, ID_LABEL + i);
			if (o->type == OT_CHOICE) {
				int c, nc = opt_nchoices (o);
				HWND hcb = child ("COMBOBOX", "", WS_TABSTOP | WS_VSCROLL | CBS_DROPDOWNLIST,
						  XMARGIN + 200, y, 150, 120, ID_OPT + i);

				SendMessage (hcb, CB_ADDSTRING, 0, (LPARAM)(LPCSTR)TxtAsk);
				for (c = 0; c < nc; c++) {
					opt_choice (o, c, buf, sizeof (buf));
					SendMessage (hcb, CB_ADDSTRING, 0, (LPARAM)(LPSTR)buf);
				}
			}
			else {
				child ("EDIT", "", WS_TABSTOP | WS_BORDER | ES_AUTOHSCROLL,
				       XMARGIN + 200, y, 250, 22, ID_OPT + i);
				SendMessage (Ctl (ID_OPT + i), EM_LIMITTEXT, OPTVALLEN - 1, 0L);
			}
		}
	}

	child ("STATIC", "", WS_VISIBLE | SS_LEFT, XMARGIN, ROWY + 9 * ROWH + 8, WIDTH - 2 * XMARGIN, 32, ID_HELP);
	child ("STATIC", "", WS_VISIBLE | SS_LEFT | SS_NOPREFIX, XMARGIN, BOTTOMY + 4, WIDTH - 210, 18, ID_FILE);
	child ("BUTTON", T("&Save", "&Speichern"), WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON,
	       WIDTH - 190, BOTTOMY, 80, 26, IDOK);
	child ("BUTTON", T("Close", "Schlie\xdf\x65n"), WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
	       WIDTH - 100, BOTTOMY, 80, 26, IDCANCEL);
}

/* Option values -> controls */
static void to_controls (void)
{
	int i;

	for (i = 0; i < nOptions; i++) {
		OPTION *o = &Options[i];
		int ci = opt_choiceindex (o);

		switch (o->type) {
		case OT_BOOL:
			CheckDlgButton (hMain, ID_OPT + i, ci < 0 ? 2 : (ci == 0 ? 1 : 0));
			break;
		case OT_CHOICE:
			SendDlgItemMessage (hMain, ID_OPT + i, CB_SETCURSEL, ci + 1, 0L);
			break;
		default:
			SetDlgItemText (hMain, ID_OPT + i, o->value);
		}
	}
}

/* Controls -> option values */
static void from_controls (void)
{
	int i, c;

	for (i = 0; i < nOptions; i++) {
		OPTION *o = &Options[i];

		switch (o->type) {
		case OT_BOOL:
			c = IsDlgButtonChecked (hMain, ID_OPT + i);
			if (c == 2) o->value[0] = '\0';
			else opt_choice (o, c ? 0 : 1, o->value, OPTVALLEN);
			break;
		case OT_CHOICE:
			c = (int)SendDlgItemMessage (hMain, ID_OPT + i, CB_GETCURSEL, 0, 0L);
			if (c <= 0) o->value[0] = '\0';
			else opt_choice (o, c - 1, o->value, OPTVALLEN);
			break;
		default:
			GetDlgItemText (hMain, ID_OPT + i, o->value, OPTVALLEN);
		}
	}
}

static void show_page (int p)
{
	int i;

	Page = p;
	for (i = 0; i < nPages; i++)
		SendMessage (Ctl (ID_TAB + i), BM_SETSTATE, i == p, 0L);
	for (i = 0; i < nOptions; i++) {
		int sw = lstrcmpi (Options[i].sect, Pages[p].sect) ? SW_HIDE : SW_SHOW;

		ShowWindow (Ctl (ID_OPT + i), sw);
		if (Ctl (ID_LABEL + i)) ShowWindow (Ctl (ID_LABEL + i), sw);
	}
	SetDlgItemText (hMain, ID_HELP, "");
}

static void set_status (LPCSTR lp)
{
	char buf[200];

	wsprintf (buf, "%s%s%s", (LPSTR)FileName, (LPSTR)(Changed ? " *" : ""),
		  (LPSTR)(lp ? lp : ""));
	SetDlgItemText (hMain, ID_FILE, buf);
}

static BOOL save (void)
{
	from_controls ();
	if (opt_save (FileName)) {
		MessageBox (hMain, T("SETUP.INF could not be written.", "SETUP.INF konnte nicht geschrieben werden."),
			    AppTitle, MB_OK | MB_ICONSTOP);
		return (FALSE);
	}
	Changed = FALSE;
	set_status (T(" - saved", " - gespeichert"));
	return (TRUE);
}

static BOOL may_close (void)
{
	int rc;

	if (!Changed) return (TRUE);
	rc = MessageBox (hMain, T("Save the changes?", "\xc4nderungen speichern?"), AppTitle,
			 MB_YESNOCANCEL | MB_ICONQUESTION);
	if (rc == IDCANCEL) return (FALSE);
	if (rc == IDYES) return (save ());
	return (TRUE);
}

LRESULT CALLBACK __export MainWndProc (HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	switch (msg) {
	case WM_CREATE:
		hMain = hwnd;
		create_controls ();
		to_controls ();
		show_page (0);
		set_status (NULL);
		return (0);

	case WM_COMMAND:
		if (wParam >= ID_TAB && wParam < ID_TAB + (WPARAM)nPages) {
			show_page (wParam - ID_TAB);
			return (0);
		}
		if (wParam >= ID_OPT && wParam < ID_OPT + (WPARAM)nOptions) {
			int i = wParam - ID_OPT;
			int code = HIWORD (lParam);	/* Win16 notification */

			SetDlgItemText (hwnd, ID_HELP, Options[i].help);
			if (code == BN_CLICKED || code == CBN_SELCHANGE || code == EN_CHANGE) {
				if (!Changed) {
					Changed = TRUE;
					set_status (NULL);
				}
			}
			return (0);
		}
		if (wParam == IDOK) {
			save ();
			return (0);
		}
		if (wParam == IDCANCEL) {
			if (may_close ()) DestroyWindow (hwnd);
			return (0);
		}
		break;

	case WM_CTLCOLOR:		/* labels and check boxes on button face */
		if (HIWORD (lParam) == CTLCOLOR_STATIC || HIWORD (lParam) == CTLCOLOR_BTN) {
			static HBRUSH hbr = NULL;

			if (!hbr) hbr = CreateSolidBrush (GetSysColor (COLOR_BTNFACE));
			SetBkColor ((HDC)wParam, GetSysColor (COLOR_BTNFACE));
			return ((LRESULT)(UINT)hbr);
		}
		break;

	case WM_CLOSE:
		if (may_close ()) DestroyWindow (hwnd);
		return (0);

	case WM_DESTROY:
		PostQuitMessage (0);
		return (0);
	}
	return (DefWindowProc (hwnd, msg, wParam, lParam));
}

int PASCAL WinMain (HINSTANCE hInstance, HINSTANCE hPrev, LPSTR lpCmdLine, int nCmdShow)
{
	WNDCLASS wc;
	MSG msg;

	hInst = hInstance;
	while (*lpCmdLine == ' ') lpCmdLine++;
	if (*lpCmdLine) lstrcpyn (FileName, lpCmdLine, sizeof (FileName));
	else {
		char *p;

		GetModuleFileName (hInstance, FileName, sizeof (FileName) - 13);
		p = strrchr (FileName, '\\');
		strcpy (p ? p + 1 : FileName, "SETUP.INF");
	}
	if (opt_load (FileName)) opt_defaults ();

	hFont = (HFONT)GetStockObject (ANSI_VAR_FONT);

	if (!hPrev) {
		memset (&wc, 0, sizeof (wc));
		wc.lpfnWndProc = MainWndProc;
		wc.hInstance = hInstance;
		wc.hIcon = LoadIcon (hInstance, MAKEINTRESOURCE (IDI_MAXCFG));
		wc.hCursor = LoadCursor (NULL, IDC_ARROW);
		wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
		wc.lpszClassName = "MaxCfg";
		if (!RegisterClass (&wc)) return (1);
	}
	hMain = CreateWindow ("MaxCfg", AppTitle, WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
			      CW_USEDEFAULT, CW_USEDEFAULT, WIDTH, HEIGHT, NULL, NULL, hInstance, NULL);
	if (!hMain) return (1);
	ShowWindow (hMain, nCmdShow);
	UpdateWindow (hMain);

	while (GetMessage (&msg, NULL, 0, 0)) {
		if (!IsDialogMessage (hMain, &msg)) {
			TranslateMessage (&msg);
			DispatchMessage (&msg);
		}
	}
	return (msg.wParam);
}
