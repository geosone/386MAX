/*
 * SFTTABS.C - tabbed dialogs for Windows 3.x programs
 *
 * Open replacement of Softel's SFTTABS.DLL 1.0 with the same interface
 * (INCLUDE/SFTTABS.H) and export ordinals, as far as the Toolbox uses it:
 *
 * A TABBEDDIALOG resource names the main dialog's tabs and for each tab
 * the dialog template of its page:
 *	WORD tabs, 0, 1, rows, style; two empty strings;
 *	per tab: text, WORD enabled, WORD dialog id
 * The main dialog (the dialog template with the same id) gets a row of
 * tabs at the top and a frame around the rest; the controls of the
 * active page are created in it, at the page template's position.  The
 * program's callback gets every message of the main dialog together with
 * the page id; a WM_INITDIALOG for each page shown.  Messages it doesn't
 * process go to DlgTabbed_DefProc (macro GetTabbedDialogResult).
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <windows.h>
#include <string.h>
#include "sfttabs.h"

#define MAXCTL		64		/* controls on a page */
#define TABTEXT 	40
#define STRIPCLASS	"SftTabsStrip"
#define PROPNAME	"SftTabs"

typedef struct {
	HINSTANCE hinst;		/* the program's resources */
	TABBEDDLGPROC lpfn;		/* its callback */
	LPARAM lParam;			/* its data for the pages */
	int ntabs, cur;
	struct {
		char text[TABTEXT];
		int enabled;
		int id;
	} tab[MAX_TABBED_ITEMS];
	HWND strip;			/* the tabs (a control) */
	HWND ctl[MAXCTL];		/* controls of the page */
	int nctl;
	int insim;			/* in a simulated WM_INITDIALOG */
	int defaulted;			/* DlgTabbed_DefProc didn't process */
	int left, right, top, bottom;	/* page frame */
	int tabtop;			/* top of the tabs */
	int orgx, orgy; 		/* origin of the main dialog's area */
	HFONT tabfont;
} TABS;

static HINSTANCE hInstDLL;

BOOL CALLBACK _export TabDlgProc(HWND, UINT, WPARAM, LPARAM);
LRESULT CALLBACK _export TabStripProc(HWND, UINT, WPARAM, LPARAM);

static TABS *gettabs(HWND hwnd)
{
	return hwnd ? (TABS *)GetProp(hwnd, PROPNAME) : NULL;
}

/*	Read the TABBEDDIALOG resource */
static TABS *loadtabs(LPTABBEDDIALOGPARM lpTab)
{
	HRSRC hrsrc;
	HGLOBAL hres;
	const char FAR *p;
	TABS *t;
	int i, n;

	hrsrc = FindResource(lpTab->hinst, lpTab->resource, TABBEDDIALOG);
	if (!hrsrc || !(hres = LoadResource(lpTab->hinst, hrsrc))) return NULL;
	p = (const char FAR *)LockResource(hres);
	t = (TABS *)LocalAlloc(LPTR, sizeof(TABS));
	if (p && t) {
		n = *(const int FAR *)p;
		if (n > MAX_TABBED_ITEMS) n = MAX_TABBED_ITEMS;
		p += 5 * sizeof(int);
		p += lstrlen(p) + 1;		/* two strings */
		p += lstrlen(p) + 1;
		for (i = 0; i < n; i++) {
			lstrcpyn(t->tab[i].text, p, TABTEXT);
			p += lstrlen(p) + 1;
			t->tab[i].enabled = ((const int FAR *)p)[0];
			t->tab[i].id = ((const int FAR *)p)[1];
			p += 2 * sizeof(int);
		}
		t->ntabs = n;
		t->hinst = lpTab->hinst;
		t->lpfn = lpTab->lpfnCallback;
		t->lParam = lpTab->lParam;
		t->cur = lpTab->activeItem >= 0 && lpTab->activeItem < n ? lpTab->activeItem : 0;
	}
	if (p) UnlockResource(hres);
	FreeResource(hres);
	if (t && !t->ntabs) {
		LocalFree((HLOCAL)t);
		t = NULL;
	}
	return t;
}

/*
 *	Drawing
 */

static void fill(HDC hdc, int x1, int y1, int x2, int y2, int color)
{
	RECT r;
	HBRUSH hbr = CreateSolidBrush(GetSysColor(color));
	SetRect(&r, x1, y1, x2, y2);
	FillRect(hdc, &r, hbr);
	DeleteObject(hbr);
}

/*	Tab i: its x range */
static void tabx(TABS *t, int i, int FAR *x1, int FAR *x2)
{
	int w = (t->right - t->left) / t->ntabs;
	*x1 = t->left + i * w;
	*x2 = i == t->ntabs - 1 ? t->right : *x1 + w - 2;
}

static void drawtab(HDC hdc, TABS *t, int i, HFONT font, BOOL focus)
{
	int x1, x2, y1 = t->tabtop, y2 = t->top, active = i == t->cur;
	RECT r;

	tabx(t, i, &x1, &x2);
	if (active) y2 += 3;			/* joins the page */
	fill(hdc, x1 + 1, y1 + 1, x2 - 1, y2, COLOR_BTNFACE);
	/*	outline with cut corners */
	fill(hdc, x1 + 2, y1, x2 - 2, y1 + 1, COLOR_WINDOWFRAME);
	fill(hdc, x1, y1 + 2, x1 + 1, y2, COLOR_WINDOWFRAME);
	fill(hdc, x2 - 1, y1 + 2, x2, y2, COLOR_WINDOWFRAME);
	fill(hdc, x1 + 1, y1 + 1, x1 + 2, y1 + 2, COLOR_WINDOWFRAME);
	fill(hdc, x2 - 2, y1 + 1, x2 - 1, y1 + 2, COLOR_WINDOWFRAME);
	/*	white left and top, shadow right */
	fill(hdc, x1 + 2, y1 + 1, x2 - 2, y1 + 3, COLOR_BTNHIGHLIGHT);
	fill(hdc, x1 + 1, y1 + 2, x1 + 3, y2, COLOR_BTNHIGHLIGHT);
	fill(hdc, x2 - 3, y1 + 2, x2 - 1, y2, COLOR_BTNSHADOW);

	SetRect(&r, x1 + 3, y1 + 3, x2 - 3, t->top);
	if (font) SelectObject(hdc, font);
	SetBkMode(hdc, TRANSPARENT);
	SetTextColor(hdc, GetSysColor(t->tab[i].enabled ? COLOR_BTNTEXT : COLOR_BTNSHADOW));
	DrawText(hdc, t->tab[i].text, -1, &r, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
	if (active && focus) {
		RECT c = r;
		int w, h;
		DrawText(hdc, t->tab[i].text, -1, &c, DT_CALCRECT | DT_SINGLELINE);
		w = c.right - c.left;
		h = c.bottom - c.top;
		c.left = (r.left + r.right - w) / 2 - 2;
		c.right = c.left + w + 4;
		c.top = (r.top + r.bottom - h) / 2 - 1;
		c.bottom = c.top + h + 2;
		DrawFocusRect(hdc, &c);
	}
}

/*	Page frame and tabs, in the dialog's client coordinates */
static void paintall(HWND hDlg, HDC hdc, TABS *t)
{
	int i, x1, x2, l = t->left, r = t->right, y = t->top, b = t->bottom;
	HFONT font = t->tabfont;
	HFONT old = font ? (HFONT)SelectObject(hdc, font) : NULL;

	fill(hdc, l, y, r, y + 1, COLOR_WINDOWFRAME);
	fill(hdc, l, y, l + 1, b, COLOR_WINDOWFRAME);
	fill(hdc, r - 1, y, r, b, COLOR_WINDOWFRAME);
	fill(hdc, l, b - 1, r, b, COLOR_WINDOWFRAME);
	fill(hdc, l + 1, y + 1, r - 1, y + 3, COLOR_BTNHIGHLIGHT);
	fill(hdc, l + 1, y + 1, l + 3, b - 1, COLOR_BTNHIGHLIGHT);
	fill(hdc, r - 3, y + 1, r - 1, b - 1, COLOR_BTNSHADOW);
	fill(hdc, l + 1, b - 3, r - 1, b - 1, COLOR_BTNSHADOW);

	for (i = 0; i < t->ntabs; i++) {
		if (i != t->cur) drawtab(hdc, t, i, font, FALSE);
	}
	drawtab(hdc, t, t->cur, font, GetFocus() == t->strip);
	/*	no frame line under the active tab */
	tabx(t, t->cur, &x1, &x2);
	fill(hdc, x1 + 3, y, x2 - 3, y + 3, COLOR_BTNFACE);
	if (old) SelectObject(hdc, old);
}

/*
 *	Pages
 */

static void destroypage(TABS *t)
{
	int i;
	for (i = 0; i < t->nctl; i++) {
		if (IsWindow(t->ctl[i])) DestroyWindow(t->ctl[i]);
	}
	t->nctl = 0;
}

static const char FAR *skipstr(const char FAR *p)
{
	if ((BYTE)*p == 0xFF) return p + 3;	/* ordinal */
	return p + lstrlen(p) + 1;
}

/*	Create the controls of the page's dialog template in the main
 *	dialog (at the origin of its area) */
static void createpage(HWND hDlg, TABS *t)
{
	HRSRC hrsrc;
	HGLOBAL hres;
	const BYTE FAR *p;
	DWORD style;
	int n;
	HWND prev = t->strip;
	HFONT font = (HFONT)(UINT)SendMessage(hDlg, WM_GETFONT, 0, 0L);
	static const char *classes[] = {
		"Button", "Edit", "Static", "ListBox", "ScrollBar", "ComboBox"
	};

	hrsrc = FindResource(t->hinst, MAKEINTRESOURCE(t->tab[t->cur].id), RT_DIALOG);
	if (!hrsrc || !(hres = LoadResource(t->hinst, hrsrc))) return;
	p = (const BYTE FAR *)LockResource(hres);
	if (!p) {
		FreeResource(hres);
		return;
	}
	style = *(const DWORD FAR *)p;
	n = p[4];
	p += 13;
	p = (const BYTE FAR *)skipstr((const char FAR *)p);	/* menu */
	p = (const BYTE FAR *)skipstr((const char FAR *)p);	/* class */
	p = (const BYTE FAR *)skipstr((const char FAR *)p);	/* caption */
	if (style & DS_SETFONT) {
		p += 2;
		p += lstrlen((const char FAR *)p) + 1;
	}

	while (n-- > 0 && t->nctl < MAXCTL) {
		const int FAR *w = (const int FAR *)p;
		RECT rc;
		int id = w[4];
		DWORD cs = *(const DWORD FAR *)(p + 10);
		const char FAR *cls;
		const char FAR *text;
		char ord[8];
		HWND hwnd;

		SetRect(&rc, w[0], w[1], w[0] + w[2], w[1] + w[3]);
		MapDialogRect(hDlg, &rc);
		OffsetRect(&rc, t->orgx, t->orgy);
		p += 14;
		if (*p & 0x80) {
			cls = (*p & 0x7F) < 6 ? classes[*p & 0x7F] : "Static";
			p++;
		}
		else {
			cls = (const char FAR *)p;
			p += lstrlen(cls) + 1;
		}
		if (*p == 0xFF) {
			wsprintf(ord, "#%u", *(const WORD FAR *)(p + 1));
			text = ord;
			p += 3;
		}
		else {
			text = (const char FAR *)p;
			p += lstrlen(text) + 1;
		}
		p += 1 + *p;			/* create data */

		hwnd = CreateWindow(cls, text, (cs & ~WS_POPUP) | WS_CHILD,
			rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top,
			hDlg, (HMENU)id, t->hinst, NULL);
		if (!hwnd) continue;
		if (font) SendMessage(hwnd, WM_SETFONT, (WPARAM)font, 0L);
		/*	tab order: the tabs, the page, then the main dialog's controls */
		SetWindowPos(hwnd, prev, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
		prev = hwnd;
		t->ctl[t->nctl++] = hwnd;
	}
	UnlockResource(hres);
	FreeResource(hres);
}

static HWND firstctl(TABS *t)
{
	int i;
	for (i = 0; i < t->nctl; i++) {
		LONG s = GetWindowLong(t->ctl[i], GWL_STYLE);
		if ((s & WS_TABSTOP) && (s & WS_VISIBLE) && !(s & WS_DISABLED)) return t->ctl[i];
	}
	return NULL;
}

/*	Show page t->cur and tell the program */
static void showpage(HWND hDlg, TABS *t, BOOL focusstrip)
{
	HWND first;
	LRESULT r;

	createpage(hDlg, t);
	first = firstctl(t);
	t->insim++;
	r = t->lpfn(hDlg, t->tab[t->cur].id, WM_INITDIALOG, (WPARAM)first, t->lParam);
	t->insim--;
	if (focusstrip || !(UINT)r || !first) SetFocus(t->strip);
	else SetFocus(first);
}

static BOOL switchpage(HWND hDlg, TABS *t, int i, BOOL focusstrip)
{
	RECT r;

	if (i < 0 || i >= t->ntabs || !t->tab[i].enabled) return FALSE;
	if (i == t->cur) return TRUE;
	destroypage(t);
	t->cur = i;
	SetRect(&r, t->left, t->tabtop, t->right, t->bottom);
	InvalidateRect(hDlg, &r, TRUE);
	InvalidateRect(t->strip, NULL, TRUE);
	showpage(hDlg, t, focusstrip);
	return TRUE;
}

/*	Next enabled tab in direction d */
static int nexttab(TABS *t, int d)
{
	int i, k = t->cur;
	for (i = 0; i < t->ntabs; i++) {
		k = (k + d + t->ntabs) % t->ntabs;
		if (t->tab[k].enabled) return k;
	}
	return t->cur;
}

/*	The tab with mnemonic ch */
static int mnemonic(TABS *t, int ch)
{
	int i;
	for (i = 0; i < t->ntabs; i++) {
		const char *s = strchr(t->tab[i].text, '&');
		if (s && s[1] && (WORD)(DWORD)AnsiUpper((LPSTR)(DWORD)(BYTE)s[1]) ==
				(WORD)(DWORD)AnsiUpper((LPSTR)(DWORD)(BYTE)ch))
			return i;
	}
	return -1;
}

/*	The tab row: a control so it can have the focus */
LRESULT CALLBACK _export TabStripProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	HWND hDlg = GetParent(hwnd);
	TABS *t = gettabs(hDlg);
	PAINTSTRUCT ps;
	RECT r;
	int i, x1, x2, x;

	if (!t) return DefWindowProc(hwnd, msg, wParam, lParam);
	switch (msg) {
	case WM_PAINT:
		BeginPaint(hwnd, &ps);
		GetWindowRect(hwnd, &r);
		ScreenToClient(hDlg, (POINT FAR *)&r);
		SetViewportOrg(ps.hdc, -r.left, -r.top);
		paintall(hDlg, ps.hdc, t);
		EndPaint(hwnd, &ps);
		return 0;
	case WM_ERASEBKGND: {
		HBRUSH hbr = (HBRUSH)(UINT)SendMessage(hDlg, WM_CTLCOLOR, wParam,
			MAKELPARAM(hDlg, CTLCOLOR_DLG));
		GetClientRect(hwnd, &r);
		FillRect((HDC)wParam, &r, hbr ? hbr : (HBRUSH)GetStockObject(WHITE_BRUSH));
		return 1;
	}
	case WM_GETDLGCODE:
		return DLGC_WANTARROWS;
	case WM_SETFOCUS:
	case WM_KILLFOCUS:
		InvalidateRect(hwnd, NULL, FALSE);
		break;
	case WM_KEYDOWN:
		if (wParam == VK_LEFT || wParam == VK_UP)
			switchpage(hDlg, t, nexttab(t, -1), TRUE);
		else if (wParam == VK_RIGHT || wParam == VK_DOWN)
			switchpage(hDlg, t, nexttab(t, 1), TRUE);
		return 0;
	case WM_LBUTTONDOWN:
		GetWindowRect(hwnd, &r);
		ScreenToClient(hDlg, (POINT FAR *)&r);
		x = LOWORD(lParam) + r.left;
		for (i = 0; i < t->ntabs; i++) {
			tabx(t, i, &x1, &x2);
			if (x >= x1 && x < x2) {
				if (switchpage(hDlg, t, i, TRUE)) SetFocus(hwnd);
				break;
			}
		}
		return 0;
	}
	return DefWindowProc(hwnd, msg, wParam, lParam);
}

/*	Dialog units to pixels */
static int dux(HWND hDlg, int n)
{
	RECT r;
	SetRect(&r, 0, 0, n, 0);
	MapDialogRect(hDlg, &r);
	return r.right;
}

/*	Set up the main dialog like SftTabs 1.0 (pixels for MS Sans Serif 8
 *	at 96 dpi in brackets): the tabs at the top (10, as high as the
 *	font + 5) with the frame below them, 4 dialog units from the sides
 *	(7).  Inside the frame's 3 pixel border lies the main dialog's
 *	area, as large as its template: its own controls (OK, Cancel, ...)
 *	at their positions in it, the pages at its origin.  The dialog gets
 *	the frame's margins around it */
static void inittabs(HWND hDlg, TABS *t)
{
	RECT r, wr, cr;
	HWND child;
	HDC hdc;
	TEXTMETRIC tm;
	LOGFONT lf;
	HFONT font = (HFONT)(UINT)SendMessage(hDlg, WM_GETFONT, 0, 0L), old = NULL;

	/*	the tabs: the dialog's font, not bold */
	if (font && GetObject(font, sizeof(lf), (LPSTR)&lf)) {
		lf.lfWeight = FW_NORMAL;
		t->tabfont = CreateFontIndirect(&lf);
	}
	hdc = GetDC(hDlg);
	if (t->tabfont) old = (HFONT)SelectObject(hdc, t->tabfont);
	GetTextMetrics(hdc, &tm);
	if (old) SelectObject(hdc, old);
	ReleaseDC(hDlg, hdc);

	GetClientRect(hDlg, &cr);
	t->tabtop = (tm.tmHeight + 7) / 2;
	t->top = t->tabtop + tm.tmHeight + 5;
	t->left = dux(hDlg, 4);
	t->orgx = t->left + 3;
	t->orgy = t->top + 3;
	t->right = t->orgx + cr.right + 3;
	t->bottom = t->orgy + cr.bottom + 3;

	for (child = GetWindow(hDlg, GW_CHILD); child; child = GetWindow(child, GW_HWNDNEXT)) {
		GetWindowRect(child, &r);
		ScreenToClient(hDlg, (POINT FAR *)&r.left);
		SetWindowPos(child, NULL, r.left + t->orgx, r.top + t->orgy, 0, 0,
			SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
	}

	GetWindowRect(hDlg, &wr);
	SetWindowPos(hDlg, NULL, 0, 0,
		t->right + t->left + (wr.right - wr.left) - cr.right,
		t->bottom + t->tabtop + (wr.bottom - wr.top) - cr.bottom,
		SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);

	if (!t->tab[t->cur].enabled) t->cur = nexttab(t, 1);
	t->strip = CreateWindow(STRIPCLASS, "", WS_CHILD | WS_VISIBLE | WS_TABSTOP,
		t->left, t->tabtop, t->right - t->left, t->top + 3 - t->tabtop,
		hDlg, (HMENU)-1, hInstDLL, NULL);
	SetWindowPos(t->strip, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
}

static BOOL resultmsg(UINT msg)
{
	return msg == WM_CTLCOLOR || msg == WM_COMPAREITEM || msg == WM_VKEYTOITEM ||
		msg == WM_CHARTOITEM || msg == WM_QUERYDRAGICON ||
		msg == WM_INITDIALOG || msg == WM_QUERYENDSESSION;
}

/*	Dialog procedure of the main dialog: everything goes to the callback */
BOOL CALLBACK _export TabDlgProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam)
{
	TABS *t;
	LRESULT r;
	int saved;

	if (msg == WM_INITDIALOG) {
		t = (TABS *)LOWORD(lParam);
		SetProp(hDlg, PROPNAME, (HANDLE)t);
		inittabs(hDlg, t);
		showpage(hDlg, t, FALSE);
		return FALSE;
	}
	if (!(t = gettabs(hDlg))) return FALSE;

	saved = t->defaulted;
	t->defaulted = 0;
	r = t->lpfn(hDlg, t->tab[t->cur].id, msg, wParam, lParam);
	if (t->defaulted) {
		t->defaulted = saved;
		r = FALSE;		/* for DefDlgProc */
	}
	else {
		t->defaulted = saved;
		if (resultmsg(msg)) r = (UINT)r;
		else {
			SetWindowLong(hDlg, DWL_MSGRESULT, r);
			r = TRUE;
		}
	}
	if (msg == WM_NCDESTROY) {
		RemoveProp(hDlg, PROPNAME);
		if (t->tabfont) DeleteObject(t->tabfont);
		LocalFree((HLOCAL)t);
	}
	return (BOOL)r;
}

/*
 *	API
 */

LRESULT WINAPI _export DlgTabbed_DefProc(HWND hwndDlg, UINT msg, WPARAM wParam, LPARAM lParam)
{
	TABS *t = gettabs(hwndDlg);
	PAINTSTRUCT ps;
	int i;

	(void)lParam;
	if (!t) return 0;
	switch (msg) {
	case WM_PAINT:
		BeginPaint(hwndDlg, &ps);
		paintall(hwndDlg, ps.hdc, t);
		EndPaint(hwndDlg, &ps);
		return 0;
	case WM_MENUCHAR:
		/*	Alt and a tab's mnemonic */
		if ((i = mnemonic(t, wParam)) >= 0 && switchpage(hwndDlg, t, i, TRUE))
			return MAKELRESULT(0, 1);
		break;
	}
	t->defaulted = 1;
	return 0;
}

void WINAPI _export DlgTabbedDlg_EndDialog(HWND hwndDlg, int val)
{
	EndDialog(hwndDlg, val);
}

BOOL WINAPI _export DlgTabbedDlg_InSimulatedMsg(HWND hwnd)
{
	TABS *t = gettabs(hwnd);
	return t && t->insim;
}

BOOL WINAPI _export DlgTabbedDlg_IsTabbed(HWND hwnd)
{
	return gettabs(hwnd) != NULL;
}

static int findtab(TABS *t, int id)
{
	int i;
	for (i = 0; t && i < t->ntabs; i++) {
		if (t->tab[i].id == id) return i;
	}
	return -1;
}

BOOL WINAPI _export DlgTabbedDlg_GetEnable(HWND hwndDlg, int DialogID)
{
	TABS *t = gettabs(hwndDlg);
	int i = findtab(t, DialogID);
	return i >= 0 && t->tab[i].enabled;
}

BOOL WINAPI _export DlgTabbedDlg_Enable(HWND hwndDlg, int DialogID, BOOL fActive)
{
	TABS *t = gettabs(hwndDlg);
	int i = findtab(t, DialogID);

	if (i < 0) return FALSE;
	t->tab[i].enabled = fActive != 0;
	if (t->strip) InvalidateRect(t->strip, NULL, TRUE);
	return TRUE;
}

BOOL WINAPI _export DlgTabbedDlg_GetText(HWND hwndDlg, int DialogID, LPSTR lpszText, int cbText)
{
	TABS *t = gettabs(hwndDlg);
	int i = findtab(t, DialogID);

	if (i < 0 || cbText < 1) return FALSE;
	lstrcpyn(lpszText, t->tab[i].text, cbText);
	return TRUE;
}

BOOL WINAPI _export DlgTabbedDlg_SetText(HWND hwndDlg, int DialogID, LPCSTR lpszText)
{
	TABS *t = gettabs(hwndDlg);
	int i = findtab(t, DialogID);

	if (i < 0) return FALSE;
	lstrcpyn(t->tab[i].text, lpszText, TABTEXT);
	if (t->strip) InvalidateRect(t->strip, NULL, TRUE);
	return TRUE;
}

int WINAPI _export DlgTabbedDlg_GetTabs(HWND hwndDlg)
{
	TABS *t = gettabs(hwndDlg);
	return t ? t->ntabs : 0;
}

BOOL WINAPI _export DlgTabbedDlg_SwitchDialog(HWND hwndDlg, int DialogID)
{
	TABS *t = gettabs(hwndDlg);
	int i = findtab(t, DialogID);
	return i >= 0 && switchpage(hwndDlg, t, i, FALSE);
}

LRESULT WINAPI _export DlgTabbedDlg_GetUserData(HWND hwndDlg)
{
	TABS *t = gettabs(hwndDlg);
	return t ? t->lParam : 0;
}

BOOL WINAPI _export DlgTabbedDlg_Do(LPTABBEDDIALOGPARM lpTab)
{
	TABS *t = loadtabs(lpTab);
	if (!t) return -1;
	return DialogBoxParam(lpTab->hinst, lpTab->resource, lpTab->hwndOwner,
		(DLGPROC)TabDlgProc, (LPARAM)(WORD)t);
}

HWND WINAPI _export DlgTabbedDlg_Create(LPTABBEDDIALOGPARM lpTab)
{
	TABS *t = loadtabs(lpTab);
	HWND hwnd;

	if (!t) return NULL;
	hwnd = CreateDialogParam(lpTab->hinst, lpTab->resource, lpTab->hwndOwner,
		(DLGPROC)TabDlgProc, (LPARAM)(WORD)t);
	if (!hwnd) LocalFree((HLOCAL)t);
	return hwnd;
}

/*	Further exports of SFTTABS.DLL 1.0: internals of its implementation
 *	that programs don't call */
LRESULT CALLBACK _export ActiveTab_WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	return DefWindowProc(hwnd, msg, wParam, lParam);
}

int WINAPI LibMain(HINSTANCE hInst, WORD wDataSeg, WORD cbHeap, LPSTR lpCmdLine)
{
	WNDCLASS wc;

	(void)wDataSeg; (void)cbHeap; (void)lpCmdLine;
	hInstDLL = hInst;
	_fmemset(&wc, 0, sizeof(wc));
	wc.style = CS_GLOBALCLASS;
	wc.lpfnWndProc = TabStripProc;
	wc.hInstance = hInst;
	wc.hCursor = LoadCursor(NULL, IDC_ARROW);
	wc.lpszClassName = STRIPCLASS;
	return RegisterClass(&wc) != 0;
}

int CALLBACK _export WEP(int nParam)
{
	(void)nParam;
	return 1;
}

/*	The other internals exported by SFTTABS.DLL 1.0 (SFTTABS.DEF) */
LONG WINAPI _export SftTabsUnused(void)
{
	return 0;
}
