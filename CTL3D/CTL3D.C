/*
 * CTL3D.C - 3D look for the dialogs of Windows 3.x programs
 *
 * Open replacement of Microsoft's CTL3DV2.DLL (and the static CTL3DS.LIB)
 * with the same interface (INCLUDE/CTL3D.H) and export ordinals.  Dialogs
 * get the gray "3D" background (COLOR_BTNFACE) with matching static,
 * button and dialog colors: Ctl3dCtlColorEx answers WM_CTLCOLOR, and
 * Ctl3dSubclassDlg / Ctl3dAutoSubclass subclass dialogs to do it for
 * them, give modal dialogs a 3D frame and their controls the 3D look
 * of CTL3D (check boxes, radio buttons, group boxes, sunken edit
 * fields, list boxes and combo boxes, gray text of disabled push
 * buttons).
 *
 * Built as CTL3DV2.DLL (CTL3D_DLL) and as CTL3DS.LIB (CTL3DS.C).
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <windows.h>
#include "ctl3d.h"

/*	In the DLL the API functions must load its DGROUP (_export) */
#ifdef CTL3D_DLL
#define EXPORT _export
#else
#define EXPORT
#endif

#define CTL3D_VERSION	0x0231		/* like CTL3DV2.DLL 2.31 */
#define MAXSUBCLASS	64		/* subclassed dialogs */
#define MAXTASKS	16		/* tasks with automatic subclassing */

#ifdef CTL3D_DLL
static HINSTANCE hInstDLL;
#endif
static HBRUSH hbrFace;			/* COLOR_BTNFACE */
static int nRegistered;

/*	Subclassed dialogs and their original window procedures */
static struct {
	HWND	hwnd;
	WNDPROC proc;
	DWORD	grbit;			/* controls to subclass */
} Sub[MAXSUBCLASS];

/*	Tasks with Ctl3dRegister: their CBT hooks */
static struct {
	HTASK	task;
	HHOOK	hook;
	BOOL	autosub;		/* Ctl3dAutoSubclass */
} Auto[MAXTASKS];

static void makebrush(void)
{
	if (hbrFace) DeleteObject(hbrFace);
	hbrFace = CreateSolidBrush(GetSysColor(COLOR_BTNFACE));
}

static BOOL colorok(void)
{
	HDC hdc = GetDC(NULL);
	int bits = GetDeviceCaps(hdc, BITSPIXEL) * GetDeviceCaps(hdc, PLANES);
	ReleaseDC(NULL, hdc);
	/*	Like CTL3D: no 3D look on monochrome or low resolution screens */
	return bits >= 4 && GetSystemMetrics(SM_CYSCREEN) >= 350;
}

/*	The colors for dialogs, static texts and buttons */
static HBRUSH ctlcolor(HDC hdc, int type)
{
	if (!hbrFace || !colorok()) return NULL;
	switch (type) {
	case CTLCOLOR_DLG:
	case CTLCOLOR_STATIC:
	case CTLCOLOR_BTN:
		SetBkColor(hdc, GetSysColor(COLOR_BTNFACE));
		SetTextColor(hdc, GetSysColor(COLOR_BTNTEXT));
		return hbrFace;
	}
	return NULL;
}

HBRUSH WINAPI EXPORT Ctl3dCtlColorEx(UINT wm, WPARAM wParam, LPARAM lParam)
{
	if (wm != WM_CTLCOLOR) return NULL;
	return ctlcolor((HDC)wParam, HIWORD(lParam));
}

HBRUSH WINAPI EXPORT Ctl3dCtlColor(HDC hdc, LONG lParam)
{
	return ctlcolor(hdc, HIWORD(lParam));
}

/*	The 3D modal frame: Windows draws a black edge and the frame color
 *	(SM_CXDLGFRAME pixels, one less at the top where the caption starts);
 *	from the outside in it becomes shadow/black, white/shadow, gray and a
 *	shadow line at the top and left of the caption and client area; the
 *	line under the caption white */
static void hline(HDC hdc, int x1, int x2, int y, COLORREF c)
{
	RECT r;
	HBRUSH hbr = CreateSolidBrush(c);
	SetRect(&r, x1, y, x2, y + 1);
	FillRect(hdc, &r, hbr);
	DeleteObject(hbr);
}

static void vline(HDC hdc, int x, int y1, int y2, COLORREF c)
{
	RECT r;
	HBRUSH hbr = CreateSolidBrush(c);
	SetRect(&r, x, y1, x + 1, y2);
	FillRect(hdc, &r, hbr);
	DeleteObject(hbr);
}

static void paintframe(HWND hwnd)
{
	RECT r;
	HDC hdc;
	int w, h, d = GetSystemMetrics(SM_CXDLGFRAME);
	COLORREF shadow, light, black;

	if (!hbrFace || !colorok() || IsIconic(hwnd) ||
			!(GetWindowLong(hwnd, GWL_EXSTYLE) & WS_EX_DLGMODALFRAME) ||
			(GetWindowLong(hwnd, GWL_STYLE) & WS_THICKFRAME))
		return;
	GetWindowRect(hwnd, &r);
	w = r.right - r.left;
	h = r.bottom - r.top;
	shadow = GetSysColor(COLOR_BTNSHADOW);
	light = GetSysColor(COLOR_BTNHIGHLIGHT);
	black = GetSysColor(COLOR_WINDOWFRAME);

	hdc = GetWindowDC(hwnd);
	/*	gray frame */
	SetRect(&r, 0, 0, w, d);		FillRect(hdc, &r, hbrFace);
	SetRect(&r, 0, 0, d + 1, h);		FillRect(hdc, &r, hbrFace);
	SetRect(&r, w - d - 1, 0, w, h);	FillRect(hdc, &r, hbrFace);
	SetRect(&r, 0, h - d - 1, w, h);	FillRect(hdc, &r, hbrFace);
	/*	outer edges */
	hline(hdc, 0, w - 1, 0, shadow);
	vline(hdc, 0, 0, h - 1, shadow);
	hline(hdc, 0, w, h - 1, black);
	vline(hdc, w - 1, 0, h, black);
	hline(hdc, 1, w - 2, 1, light);
	vline(hdc, 1, 1, h - 2, light);
	hline(hdc, 1, w - 1, h - 2, shadow);
	vline(hdc, w - 2, 1, h - 1, shadow);
	/*	inner line */
	hline(hdc, d + 1, w - d - 1, d, shadow);
	vline(hdc, d + 1, d, h - d - 1, shadow);
	/*	white line under the caption */
	if ((GetWindowLong(hwnd, GWL_STYLE) & WS_CAPTION) == WS_CAPTION)
		hline(hdc, d + 2, w - d - 1, d + GetSystemMetrics(SM_CYCAPTION) - 1, light);
	ReleaseDC(hwnd, hdc);
}

/*
 *	Controls (CTL3D_BUTTONS, ...): check boxes and radio buttons get a
 *	sunken 3D box, group boxes an etched frame, disabled text is gray;
 *	edit fields, list boxes, combo boxes and statics with a border are
 *	sunken (the dialog draws a shadow/white edge around them, their own
 *	border is black at the top and left, gray at the bottom and right)
 */

#define K_CHECK 	1
#define K_RADIO 	2
#define K_GROUP 	3
#define K_BORDER	4		/* edit, list box, static with a border */
#define K_COMBO 	5
#define K_PUSH		6		/* only disabled: gray text */

/*	Edit fields created with a border (they take WS_BORDER out of their
 *	style and draw the border themselves; the CBT hook sees the style) */
#define MAXBORDER	128
static HWND Bordered[MAXBORDER];
static int nextBordered;

static BOOL bordered(HWND hwnd)
{
	int i;
	for (i = 0; i < MAXBORDER; i++) {
		if (Bordered[i] == hwnd) return TRUE;
	}
	return FALSE;
}

static const char szKind[] = "Ctl3dK";	/* window properties */
static const char szProcLo[] = "Ctl3dL";
static const char szProcHi[] = "Ctl3dH";

static int kindof(HWND hwnd, DWORD grbit)
{
	char cls[10];
	DWORD style = GetWindowLong(hwnd, GWL_STYLE);

	if (!GetClassName(hwnd, cls, sizeof(cls))) return 0;
	if (!lstrcmpi(cls, "Button")) {
		if (!(grbit & CTL3D_BUTTONS)) return 0;
		switch ((int)style & 0x0F) {
		case BS_CHECKBOX: case BS_AUTOCHECKBOX:
		case BS_3STATE: case BS_AUTO3STATE:
			return K_CHECK;
		case BS_RADIOBUTTON: case BS_AUTORADIOBUTTON:
			return K_RADIO;
		case BS_GROUPBOX:
			return K_GROUP;
		case BS_PUSHBUTTON: case BS_DEFPUSHBUTTON:
			return K_PUSH;
		}
		return 0;
	}
	if (!lstrcmpi(cls, "Edit"))
		return ((style & WS_BORDER) || bordered(hwnd)) && (grbit & CTL3D_EDITS) ? K_BORDER : 0;
	if (!lstrcmpi(cls, "ListBox"))
		return (style & WS_BORDER) && (grbit & CTL3D_LISTBOXES) ? K_BORDER : 0;
	if (!lstrcmpi(cls, "Static"))
		return (style & WS_BORDER) && (grbit & CTL3D_STATICFRAMES) ? K_BORDER : 0;
	if (!lstrcmpi(cls, "ComboBox"))
		return ((int)style & 3) >= CBS_DROPDOWN && (grbit & CTL3D_COMBOS) ? K_COMBO : 0;
	return 0;
}

static WNDPROC ctlproc(HWND hwnd)
{
	return (WNDPROC)MAKELONG(GetProp(hwnd, szProcLo), GetProp(hwnd, szProcHi));
}

/*	X of a check box (7 x 7) */
static const BYTE checkx[7] = { 0x63, 0x77, 0x3E, 0x1C, 0x3E, 0x77, 0x63 };

static void drawx(HDC hdc, int x, int y, COLORREF c)
{
	int i, j;
	for (i = 0; i < 7; i++) {
		for (j = 0; j < 7; j++) {
			if (checkx[i] & (0x40 >> j)) SetPixel(hdc, x + j, y + i, c);
		}
	}
}

static void paintbutton(HWND hwnd, HDC hdc, int kind)
{
	RECT rc, tr;
	TEXTMETRIC tm;
	char text[128];
	HBRUSH hbr;
	HFONT font, old = NULL;
	UINT state;
	BOOL enabled = IsWindowEnabled(hwnd);
	COLORREF shadow = GetSysColor(COLOR_BTNSHADOW);
	COLORREF light = GetSysColor(COLOR_BTNHIGHLIGHT);
	COLORREF face = GetSysColor(COLOR_BTNFACE);
	COLORREF black = GetSysColor(COLOR_WINDOWFRAME);
	int bx, by, th;

	GetClientRect(hwnd, &rc);
	hbr = (HBRUSH)(UINT)SendMessage(GetParent(hwnd), WM_CTLCOLOR, (WPARAM)hdc,
		MAKELPARAM(hwnd, CTLCOLOR_BTN));
	if (!hbr) hbr = hbrFace;
	font = (HFONT)(UINT)SendMessage(hwnd, WM_GETFONT, 0, 0L);
	if (font) old = (HFONT)SelectObject(hdc, font);
	GetTextMetrics(hdc, &tm);
	th = tm.tmHeight;
	GetWindowText(hwnd, text, sizeof(text));
	state = (UINT)SendMessage(hwnd, BM_GETSTATE, 0, 0L);
	SetTextColor(hdc, enabled ? GetSysColor(COLOR_BTNTEXT) : shadow);
	SetBkColor(hdc, face);

	if (kind == K_GROUP) {
		/*	etched frame through the middle of the text, the text at 4 */
		int y = th / 2, r = rc.right, b = rc.bottom;
		hline(hdc, 1, r, y + 1, light);
		vline(hdc, 1, y + 1, b, light);
		hline(hdc, 0, r, b - 1, light);
		vline(hdc, r - 1, y, b, light);
		hline(hdc, 0, r - 1, y, shadow);
		vline(hdc, 0, y, b - 1, shadow);
		hline(hdc, 0, r - 1, b - 2, shadow);
		vline(hdc, r - 2, y, b - 1, shadow);
		if (text[0]) {
			SetRect(&tr, 4, 0, r - 4, th);
			SetBkMode(hdc, OPAQUE);
			DrawText(hdc, text, -1, &tr, DT_LEFT | DT_TOP | DT_SINGLELINE);
		}
	}
	else {
		FillRect(hdc, &rc, hbr);
		bx = (GetWindowLong(hwnd, GWL_STYLE) & BS_LEFTTEXT) ? rc.right - 13 : 0;
		by = (rc.bottom - 13 + 1) / 2;
		if (kind == K_CHECK) {
			RECT in;
			hline(hdc, bx, bx + 12, by, shadow);
			vline(hdc, bx, by, by + 12, shadow);
			hline(hdc, bx + 1, bx + 11, by + 1, black);
			vline(hdc, bx + 1, by + 1, by + 11, black);
			hline(hdc, bx + 1, bx + 12, by + 11, face);
			vline(hdc, bx + 11, by + 1, by + 12, face);
			hline(hdc, bx + 1, bx + 13, by + 12, light);
			vline(hdc, bx + 12, by + 1, by + 13, light);
			SetRect(&in, bx + 2, by + 2, bx + 11, by + 11);
			if (enabled && !(state & 4)) {
				HBRUSH w = CreateSolidBrush(GetSysColor(COLOR_WINDOW));
				FillRect(hdc, &in, w);
				DeleteObject(w);
			}
			else FillRect(hdc, &in, hbrFace);
			if (state & 3) {
				if (!enabled) drawx(hdc, bx + 4, by + 4, light);
				drawx(hdc, bx + 3, by + 3, enabled && (state & 3) == 1 ?
					GetSysColor(COLOR_WINDOWTEXT) : shadow);
			}
		}
		else {
			HPEN pen, oldpen;
			HBRUSH oldbr, w;
			w = CreateSolidBrush(enabled && !(state & 4) ? GetSysColor(COLOR_WINDOW) : face);
			oldbr = (HBRUSH)SelectObject(hdc, w);
			oldpen = (HPEN)SelectObject(hdc, GetStockObject(NULL_PEN));
			Ellipse(hdc, bx + 1, by + 1, bx + 13, by + 13);
			pen = CreatePen(PS_SOLID, 1, shadow);
			SelectObject(hdc, pen);
			Arc(hdc, bx, by, bx + 12, by + 12, bx + 12, by, bx, by + 12);
			DeleteObject(SelectObject(hdc, CreatePen(PS_SOLID, 1, light)));
			Arc(hdc, bx, by, bx + 12, by + 12, bx, by + 12, bx + 12, by);
			DeleteObject(SelectObject(hdc, CreatePen(PS_SOLID, 1, black)));
			Arc(hdc, bx + 1, by + 1, bx + 11, by + 11, bx + 11, by + 1, bx + 1, by + 11);
			DeleteObject(SelectObject(hdc, CreatePen(PS_SOLID, 1, face)));
			Arc(hdc, bx + 1, by + 1, bx + 11, by + 11, bx + 1, by + 11, bx + 11, by + 1);
			DeleteObject(SelectObject(hdc, GetStockObject(NULL_PEN)));
			SelectObject(hdc, oldbr);
			DeleteObject(w);
			if (state & 3) {
				w = CreateSolidBrush(enabled ? GetSysColor(COLOR_WINDOWTEXT) : shadow);
				SelectObject(hdc, w);
				Ellipse(hdc, bx + 4, by + 4, bx + 9, by + 9);
				SelectObject(hdc, oldbr);
				DeleteObject(w);
			}
			SelectObject(hdc, oldpen);
		}

		/*	the text, 16 to the right of the box (or left of it) */
		if (bx) SetRect(&tr, 0, 0, bx - 3, rc.bottom);
		else SetRect(&tr, 16, 0, rc.right, rc.bottom);
		SetBkMode(hdc, TRANSPARENT);
		DrawText(hdc, text, -1, &tr, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
		if (state & 8) {
			RECT fr = tr;
			int w, h;
			DrawText(hdc, text, -1, &fr, DT_CALCRECT | DT_SINGLELINE);
			w = fr.right - fr.left;
			h = fr.bottom - fr.top;
			SetRect(&fr, tr.left - 1, (tr.top + tr.bottom - h) / 2 - 1, 0, 0);
			fr.right = fr.left + w + 2;
			fr.bottom = fr.top + h + 2;
			if (fr.right > rc.right) fr.right = rc.right;
			DrawFocusRect(hdc, &fr);
		}
	}
	if (old) SelectObject(hdc, old);
}

/*	The inner border of edit fields etc.: gray at the bottom and right
 *	(edit fields draw their border in their client area) */
static void paintinner(HWND hwnd, BOOL client)
{
	RECT r;
	HDC hdc = client ? GetDC(hwnd) : GetWindowDC(hwnd);
	COLORREF face = GetSysColor(COLOR_BTNFACE);

	GetWindowRect(hwnd, &r);
	OffsetRect(&r, -r.left, -r.top);
	hline(hdc, 1, r.right, r.bottom - 1, face);
	vline(hdc, r.right - 1, 1, r.bottom, face);
	ReleaseDC(hwnd, hdc);
}

/*	The outer edge of the sunken controls in a dialog */
static void paintedges(HWND hDlg)
{
	HWND c;
	HDC hdc = NULL;
	RECT r;
	COLORREF shadow = GetSysColor(COLOR_BTNSHADOW);
	COLORREF light = GetSysColor(COLOR_BTNHIGHLIGHT);

	for (c = GetWindow(hDlg, GW_CHILD); c; c = GetWindow(c, GW_HWNDNEXT)) {
		int k = (int)GetProp(c, szKind);
		if ((k != K_BORDER && k != K_COMBO) || !IsWindowVisible(c)) continue;
		if (!hdc) hdc = GetDC(hDlg);
		GetWindowRect(c, &r);
		ScreenToClient(hDlg, (POINT FAR *)&r.left);
		ScreenToClient(hDlg, (POINT FAR *)&r.right);
		if (k == K_COMBO) {
			/*	only around the edit part */
			RECT er;
			SendMessage(c, CB_GETDROPPEDCONTROLRECT, 0, (LPARAM)(RECT FAR *)&er);
			if (!(GetWindowLong(c, GWL_STYLE) & 1) && er.bottom > er.top) {
				int h = (int)SendMessage(c, CB_GETITEMHEIGHT, (WPARAM)-1, 0L);
				if (h > 0 && r.top + h + 6 < r.bottom) r.bottom = r.top + h + 6;
			}
		}
		hline(hdc, r.left - 1, r.right, r.top - 1, shadow);
		vline(hdc, r.left - 1, r.top - 1, r.bottom, shadow);
		hline(hdc, r.left - 1, r.right + 1, r.bottom, light);
		vline(hdc, r.right, r.top - 1, r.bottom + 1, light);
	}
	if (hdc) ReleaseDC(hDlg, hdc);
}

/*	Disabled push buttons: the text in solid gray */
static void paintpush(HWND hwnd)
{
	RECT rc;
	char text[64];
	HDC hdc;
	HFONT font, old = NULL;
	int in = ((int)GetWindowLong(hwnd, GWL_STYLE) & 0x0F) == BS_DEFPUSHBUTTON ? 4 : 3;

	if (IsWindowEnabled(hwnd) || !IsWindowVisible(hwnd)) return;
	hdc = GetDC(hwnd);
	GetClientRect(hwnd, &rc);
	InflateRect(&rc, -in, -in);
	FillRect(hdc, &rc, hbrFace);
	font = (HFONT)(UINT)SendMessage(hwnd, WM_GETFONT, 0, 0L);
	if (font) old = (HFONT)SelectObject(hdc, font);
	GetWindowText(hwnd, text, sizeof(text));
	SetBkMode(hdc, TRANSPARENT);
	SetTextColor(hdc, GetSysColor(COLOR_BTNSHADOW));
	DrawText(hdc, text, -1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
	if (old) SelectObject(hdc, old);
	ReleaseDC(hwnd, hdc);
}

/*	Window procedure of subclassed controls */
LRESULT CALLBACK EXPORT Ctl3dCtlProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	WNDPROC proc = ctlproc(hwnd);
	int kind = (int)GetProp(hwnd, szKind);
	BOOL button = kind == K_CHECK || kind == K_RADIO || kind == K_GROUP;
	LRESULT r;
	PAINTSTRUCT ps;

	if (!proc) return DefWindowProc(hwnd, msg, wParam, lParam);
	switch (msg) {
	case WM_NCDESTROY:
		SetWindowLong(hwnd, GWL_WNDPROC, (LONG)proc);
		RemoveProp(hwnd, szProcLo);
		RemoveProp(hwnd, szProcHi);
		RemoveProp(hwnd, szKind);
		break;
	case WM_PAINT:
		if (kind == K_PUSH || kind == K_BORDER) {
			r = CallWindowProc(proc, hwnd, msg, wParam, lParam);
			if (!colorok()) return r;
			if (kind == K_PUSH) paintpush(hwnd);
			else if (!(GetWindowLong(hwnd, GWL_STYLE) & WS_BORDER)) paintinner(hwnd, TRUE);
			return r;
		}
		if (!button || !colorok()) break;
		BeginPaint(hwnd, &ps);
		paintbutton(hwnd, ps.hdc, kind);
		EndPaint(hwnd, &ps);
		return 0;
	case WM_NCPAINT:
		r = CallWindowProc(proc, hwnd, msg, wParam, lParam);
		if (kind == K_BORDER && colorok() && (GetWindowLong(hwnd, GWL_STYLE) & WS_BORDER))
			paintinner(hwnd, FALSE);
		return r;
	case WM_ENABLE:
	case WM_SETTEXT:
	case WM_SETFOCUS:
	case WM_KILLFOCUS:
	case WM_LBUTTONDOWN:
	case WM_LBUTTONUP:
	case WM_LBUTTONDBLCLK:
	case WM_MOUSEMOVE:
	case WM_KEYDOWN:
	case WM_KEYUP:
	case BM_SETCHECK:
	case BM_SETSTATE:
	case BM_SETSTYLE:
		/*	the button draws itself here: draw it again our way */
		r = CallWindowProc(proc, hwnd, msg, wParam, lParam);
		if (!colorok() || !IsWindow(hwnd) || !IsWindowVisible(hwnd) ||
				(msg == WM_MOUSEMOVE && GetCapture() != hwnd))
			return r;
		if (button) {
			HDC hdc = GetDC(hwnd);
			paintbutton(hwnd, hdc, kind);
			ReleaseDC(hwnd, hdc);
		}
		else if (kind == K_PUSH) paintpush(hwnd);
		return r;
	}
	return CallWindowProc(proc, hwnd, msg, wParam, lParam);
}

static BOOL subclassctl(HWND hwnd, DWORD grbit)
{
	int kind;
	WNDPROC proc;

	if (GetProp(hwnd, szKind)) return TRUE;
	if (!(kind = kindof(hwnd, grbit))) return FALSE;
	SetProp(hwnd, szKind, (HANDLE)kind);
	if (kind == K_COMBO) return TRUE;	/* only the dialog draws */
	proc = (WNDPROC)SetWindowLong(hwnd, GWL_WNDPROC, (LONG)(WNDPROC)Ctl3dCtlProc);
	SetProp(hwnd, szProcLo, (HANDLE)LOWORD(proc));
	SetProp(hwnd, szProcHi, (HANDLE)HIWORD(proc));
	if (kind == K_BORDER)
		SetWindowPos(hwnd, NULL, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE |
			SWP_NOZORDER | SWP_NOACTIVATE | SWP_DRAWFRAME);
	else InvalidateRect(hwnd, NULL, FALSE);
	return TRUE;
}

static void subclassctls(HWND hDlg, DWORD grbit)
{
	HWND c;
	for (c = GetWindow(hDlg, GW_CHILD); c; c = GetWindow(c, GW_HWNDNEXT))
		subclassctl(c, grbit);
}

/*	Window procedure of subclassed dialogs */
LRESULT CALLBACK EXPORT Ctl3dDlgProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	int i;
	WNDPROC proc = NULL;
	LRESULT r;

	for (i = 0; i < MAXSUBCLASS; i++) {
		if (Sub[i].hwnd == hwnd) {
			proc = Sub[i].proc;
			break;
		}
	}
	if (!proc) return DefDlgProc(hwnd, msg, wParam, lParam);

	switch (msg) {
	case WM_CTLCOLOR: {
		/*	The dialog procedure may choose colors itself (DefDlgProc
		 *	would always answer with the default brush) */
		WNDPROC dlgproc = (WNDPROC)GetWindowLong(hwnd, DWL_DLGPROC);
		HBRUSH hbr;
		if (dlgproc) {
			/*	A BOOL or HBRUSH: only AX counts */
			UINT u = (UINT)CallWindowProc(dlgproc, hwnd, msg, wParam, lParam);
			if (u) return u;
		}
		hbr = ctlcolor((HDC)wParam, HIWORD(lParam));
		if (hbr) return (LRESULT)(UINT)hbr;
		break;
	}
	case WM_INITDIALOG:
		r = CallWindowProc(proc, hwnd, msg, wParam, lParam);
		subclassctls(hwnd, Sub[i].grbit);
		return r;
	case WM_PAINT:
		r = CallWindowProc(proc, hwnd, msg, wParam, lParam);
		if (colorok()) paintedges(hwnd);
		return r;
	case WM_NCPAINT:
	case WM_NCACTIVATE:
		r = CallWindowProc(proc, hwnd, msg, wParam, lParam);
		paintframe(hwnd);
		return r;
	case WM_NCDESTROY:
		Sub[i].hwnd = NULL;
		SetWindowLong(hwnd, GWL_WNDPROC, (LONG)proc);
		break;
	}
	return CallWindowProc(proc, hwnd, msg, wParam, lParam);
}

static BOOL subclass(HWND hwnd, DWORD grbit)
{
	int i, free = -1;

	if (!IsWindow(hwnd)) return FALSE;
	if (!(grbit & CTL3D_NODLGWINDOW)) {
		for (i = 0; i < MAXSUBCLASS; i++) {
			if (Sub[i].hwnd == hwnd) break;
			if (!Sub[i].hwnd && free < 0) free = i;
		}
		if (i == MAXSUBCLASS) {
			if (free < 0) return FALSE;
			Sub[free].hwnd = hwnd;
			Sub[free].grbit = grbit;
			Sub[free].proc = (WNDPROC)SetWindowLong(hwnd, GWL_WNDPROC,
				(LONG)(WNDPROC)Ctl3dDlgProc);
		}
	}
	subclassctls(hwnd, grbit);
	return TRUE;
}

BOOL WINAPI EXPORT Ctl3dSubclassDlg(HWND hwnd, WORD grbit)
{
	return subclass(hwnd, grbit);
}

BOOL WINAPI EXPORT Ctl3dSubclassDlgEx(HWND hwnd, DWORD grbit)
{
	return subclass(hwnd, grbit);
}

BOOL WINAPI EXPORT Ctl3dSubclassCtl(HWND hwnd)
{
	return subclassctl(hwnd, CTL3D_ALL);
}

/*	A dialog: the dialog class or one with DefDlgProc as window procedure */
static BOOL isdialog(HWND hwnd)
{
	char cls[8];

	if (!hwnd || !IsWindow(hwnd)) return FALSE;
	if (GetClassName(hwnd, cls, sizeof(cls)) && !lstrcmp(cls, "#32770")) return TRUE;
	return GetClassLong(hwnd, GCL_WNDPROC) == (LONG)(FARPROC)DefDlgProc;
}

/*	CBT hook: notes edit fields with a border; with Ctl3dAutoSubclass
 *	dialogs of the task get the 3D look when they are activated or get
 *	the focus (when they are created they don't have their window
 *	procedure yet) */
LRESULT CALLBACK EXPORT Ctl3dCbtProc(int code, WPARAM wParam, LPARAM lParam)
{
	HTASK task = GetCurrentTask();
	HHOOK hook = NULL;
	BOOL autosub = FALSE;
	int i;

	for (i = 0; i < MAXTASKS; i++) {
		if (Auto[i].task == task) {
			hook = Auto[i].hook;
			autosub = Auto[i].autosub;
			break;
		}
	}
	if (code == HCBT_CREATEWND) {
		/*	edit fields with a border */
		char cls[6];
		if ((((CBT_CREATEWND FAR *)lParam)->lpcs->style & WS_BORDER) &&
				GetClassName((HWND)wParam, cls, sizeof(cls)) && !lstrcmpi(cls, "Edit")) {
			Bordered[nextBordered] = (HWND)wParam;
			nextBordered = (nextBordered + 1) % MAXBORDER;
		}
	}
	if ((code == HCBT_ACTIVATE || code == HCBT_SETFOCUS) && wParam && autosub) {
		HWND hwnd = (HWND)wParam;
		if (code == HCBT_SETFOCUS && !isdialog(hwnd)) hwnd = GetParent(hwnd);
		if (isdialog(hwnd)) {
			BOOL known = FALSE;
			for (i = 0; i < MAXSUBCLASS; i++) {
				if (Sub[i].hwnd == hwnd) known = TRUE;
			}
			subclass(hwnd, CTL3D_ALL);
			if (!known) RedrawWindow(hwnd, NULL, NULL,
				RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN);
		}
	}
	return CallNextHookEx(hook, code, wParam, lParam);
}

/*	The task's CBT hook (Ctl3dRegister; it notes edit fields with a
 *	border, with Ctl3dAutoSubclass it subclasses the dialogs too) */
static int hooktask(HANDLE hinst)
{
	HTASK task = GetCurrentTask();
	int i, free = -1;

	for (i = 0; i < MAXTASKS; i++) {
		if (Auto[i].task == task) return i;
		if (!Auto[i].task && free < 0) free = i;
	}
	if (free < 0) return -1;
	/*	The program's instance: Windows 3.1 faults in SetWindowsHookEx
	 *	with the DLL's for a task hook */
	Auto[free].hook = SetWindowsHookEx(WH_CBT, (HOOKPROC)Ctl3dCbtProc,
		(HINSTANCE)hinst, task);
	if (!Auto[free].hook) return -1;
	Auto[free].task = task;
	Auto[free].autosub = FALSE;
	return free;
}

BOOL WINAPI EXPORT Ctl3dAutoSubclass(HANDLE hinst)
{
	int i;

	if (!colorok() || (i = hooktask(hinst)) < 0) return FALSE;
	Auto[i].autosub = TRUE;
	return TRUE;
}

BOOL WINAPI EXPORT Ctl3dRegister(HANDLE hinst)
{
	if (!hbrFace) makebrush();
	nRegistered++;
	hooktask(hinst);
	return colorok();
}

BOOL WINAPI EXPORT Ctl3dUnregister(HANDLE hinst)
{
	HTASK task = GetCurrentTask();
	int i;

	(void)hinst;
	for (i = 0; i < MAXTASKS; i++) {
		if (Auto[i].task == task) {
			UnhookWindowsHookEx(Auto[i].hook);
			Auto[i].task = NULL;
		}
	}
	if (nRegistered > 0 && --nRegistered == 0 && hbrFace) {
		DeleteObject(hbrFace);
		hbrFace = NULL;
	}
	return TRUE;
}

WORD WINAPI EXPORT Ctl3dGetVer(void)
{
	return CTL3D_VERSION;
}

BOOL WINAPI EXPORT Ctl3dEnabled(void)
{
	return colorok();
}

BOOL WINAPI EXPORT Ctl3dColorChange(void)
{
	if (hbrFace) makebrush();
	return TRUE;
}

LONG WINAPI EXPORT Ctl3dDlgFramePaint(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	LONG r = DefWindowProc(hwnd, msg, wParam, lParam);
	if (msg == WM_NCPAINT || msg == WM_NCACTIVATE) paintframe(hwnd);
	return r;
}

VOID WINAPI EXPORT Ctl3dWinIniChange(void)
{
}

#ifdef CTL3D_DLL
int WINAPI LibMain(HINSTANCE hInst, WORD wDataSeg, WORD cbHeap, LPSTR lpCmdLine)
{
	(void)wDataSeg; (void)cbHeap; (void)lpCmdLine;
	hInstDLL = hInst;
	return 1;
}

int CALLBACK EXPORT WEP(int nParam)
{
	(void)nParam;
	if (hbrFace) DeleteObject(hbrFace);
	return 1;
}

/*	Exports of CTL3DV2.DLL that programs don't call: the window
 *	procedures of its control classes and the old style switch */
LRESULT CALLBACK EXPORT BtnWndProc3D(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	return DefWindowProc(hwnd, msg, wParam, lParam);
}
LRESULT CALLBACK EXPORT EditWndProc3D(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	return DefWindowProc(hwnd, msg, wParam, lParam);
}
LRESULT CALLBACK EXPORT ListWndProc3D(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	return DefWindowProc(hwnd, msg, wParam, lParam);
}
LRESULT CALLBACK EXPORT ComboWndProc3D(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	return DefWindowProc(hwnd, msg, wParam, lParam);
}
LRESULT CALLBACK EXPORT StaticWndProc3D(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	return DefWindowProc(hwnd, msg, wParam, lParam);
}
int WINAPI EXPORT Ctl3dSetStyle(HANDLE hinst, LPSTR lpszName, WORD grbit)
{
	(void)hinst; (void)lpszName; (void)grbit;
	return 0;
}
#endif
