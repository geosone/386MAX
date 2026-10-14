// MXDLGS.CPP - WINMAXIM dialogs (Win16 API, formerly MFC)
//
// Same dialogs and behaviour as the MFC version (Henry Groover, Qualitas
// 1995-96): the DIALOG resources of WINMXMZ.RC / .GR with MxDialog in
// place of CDialog, plus the splash screen and the blue background
// (formerly STATUTIL's SPLASH.CPP, BLUESCR.CPP, CENTDLG.CPP).
//
// Copyright (C) 1995-96 Qualitas, Inc.  GNU General Public License version 3.
// Open 386MAX contributors 2022-2026.

#include <windows.h>
#include <stdlib.h>
#include <string.h>

#include <commfunc.h>
#include <mbparse.h>
#include <mxhelpid.h>
#include <statres.h>
#include "winmxmz.h"
#include "mxdlgs.h"

/////////////////////////////////////////////////////////////////////////////
// MxDialog

extern HINSTANCE g_hInstance;

static MxDialog *pDialogs;		// open dialogs, innermost first

BOOL CALLBACK __export MxDlgProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam)
{
	MxDialog *pDlg;

	if (msg == WM_INITDIALOG) {
		pDlg = (MxDialog *)lParam;
		pDlg->m_hWnd = hDlg;
		pDlg->m_pNext = pDialogs;
		pDialogs = pDlg;
		return pDlg->OnInitDialog();
	}
	for (pDlg = pDialogs; pDlg && pDlg->m_hWnd != hDlg; pDlg = pDlg->m_pNext) ;
	if (!pDlg) return FALSE;

	switch (msg) {
	case WM_COMMAND:		// Win16: notification in HIWORD(lParam)
		return pDlg->OnCommand( (int)wParam, HIWORD( lParam ) );
	case WM_CLOSE:			// system menu Close / Alt+F4: as Cancel
		pDlg->OnCancel();
		return TRUE;
	}
	return FALSE;
}

MxDialog::MxDialog(int nID)
{
	m_nID = nID;
	m_hWnd = NULL;
	m_pNext = NULL;
}

int MxDialog::DoModal(HWND hParent)
{
	int nResult = ::DialogBoxParam( g_hInstance, MAKEINTRESOURCE( m_nID ), hParent,
				(DLGPROC)MxDlgProc, (LPARAM)(MxDialog FAR *)this );
	MxDialog **pp;
	for (pp = &pDialogs; *pp; pp = &(*pp)->m_pNext) {
		if (*pp == this) {
			*pp = m_pNext;
			break;
		}
	}
	if (g_hwndDlg == m_hWnd) g_hwndDlg = NULL;
	m_hWnd = NULL;
	return nResult;
}

void MxDialog::EndDialog(int nResult)
{
	::EndDialog( m_hWnd, nResult );
}

BOOL MxDialog::OnInitDialog(void)
{
	g_hwndDlg = m_hWnd;
	DataExchange(FALSE);
	CenterDialog(m_hWnd);
	return TRUE;
}

BOOL MxDialog::OnCommand(int id, int notify)
{
	if (notify != BN_CLICKED) return FALSE;
	switch (id) {
	case IDOK:	OnOK(); return TRUE;
	case IDCANCEL:	OnCancel(); return TRUE;
	case IDC_HELP:	OnHelp(); return TRUE;
	}
	return FALSE;
}

void MxDialog::OnOK(void)
{
	DataExchange(TRUE);
	EndDialog(IDOK);
}

void MxDialog::OnCancel(void)
{
	// Shut down help
	MxWinHelp(0L, HELP_QUIT);
	EndDialog(IDCANCEL);
}

void MxDialog::OnHelp(void)
{
	MxWinHelp(HID_BASE_RESOURCE + m_nID);
}

void CenterDialog(HWND hWnd)
{
	RECT rc;
	::GetWindowRect(hWnd, &rc);
	int cx = rc.right - rc.left, cy = rc.bottom - rc.top;
	::MoveWindow(hWnd, (::GetSystemMetrics(SM_CXSCREEN) - cx) / 2,
			(::GetSystemMetrics(SM_CYSCREEN) - cy) / 2, cx, cy, TRUE);
}

/////////////////////////////////////////////////////////////////////////////
// CCustomOpts dialog

CCustomOpts::CCustomOpts(int nID) : MxDialog(nID)
{
	m_bExtraDOS = FALSE;
	m_bROMSrch = FALSE;
	m_bVGASwap = FALSE;
	m_bDisROMSrch = FALSE;
	m_bDisVGASwap = FALSE;
	m_bDOSStart = FALSE;
	m_szMaxPro[ 0 ] = '\0';
	m_bHasVGASwap = FALSE;
	m_bHasUseHigh = FALSE;
	m_bAutoStrip = FALSE;
	m_bWin95 = FALSE;
	m_bDOSStartEna = TRUE;
	m_bROMSrchEna = TRUE;
}

void CCustomOpts::DataExchange(BOOL bSave)
{
	if (bSave) {
		m_bExtraDOS = GetCheck( IDC_EXTRADOS );
		m_bROMSrch = GetCheck( IDC_ROMSRCH );
		m_bVGASwap = GetCheck( IDC_VGASWAP );
		m_bDisROMSrch = GetCheck( IDC_DISROMSRCH );
		m_bDisVGASwap = GetCheck( IDC_DISVGASWAP );
		if (m_bWin95) m_bDOSStart = GetCheck( IDC_DOSSTART );
	}
	else {
		SetCheck( IDC_EXTRADOS, m_bExtraDOS );
		SetCheck( IDC_ROMSRCH, m_bROMSrch );
		SetCheck( IDC_VGASWAP, m_bVGASwap );
		SetCheck( IDC_DISROMSRCH, m_bDisROMSrch );
		SetCheck( IDC_DISVGASWAP, m_bDisVGASwap );
		if (m_bWin95) SetCheck( IDC_DOSSTART, m_bDOSStart );
	}
}

BOOL CCustomOpts::OnInitDialog()
{
	if (!m_bROMSrchEna) {
		m_bROMSrch = FALSE;
		m_bDisROMSrch = FALSE;
	} // Can't run ROMsrch because of BCF
	MxDialog::OnInitDialog();

	if (m_bROMSrchEna) {
		Enable( IDC_DISROMSRCH, m_bHasUseHigh );
	} // OK to enable ROMSrch if we remove it first
	else {
		Enable( IDC_ROMSRCH, FALSE );
		Enable( IDC_DISROMSRCH, FALSE );
	} // Can't run ROMsrch because of BCF

	Enable( IDC_DISVGASWAP, m_bHasVGASwap );
	if (m_bWin95) {
		Enable( IDC_DOSSTART, m_bDOSStartEna );
	} // Win95
	return TRUE;
}

BOOL CCustomOpts::OnCommand(int id, int notify)
{
	if (notify != BN_CLICKED) return FALSE;
	switch (id) {
	case IDC_BACK:
		DataExchange( TRUE );
		EndDialog( IDC_BACK );
		return TRUE;

	case IDC_DISROMSRCH:
		DataExchange( TRUE );
		if (m_bDisROMSrch) {
			SetCheck( IDC_ROMSRCH, FALSE ); // Clear it
			Enable( IDC_ROMSRCH, FALSE ); // Disable it
		} // Going from off (not removing) to on (removing)
		else {
			Enable( IDC_ROMSRCH, TRUE );
		} // Re-enabling "Run ROMSRCH"
		m_bAutoStrip = FALSE;
		return TRUE;

	case IDC_DISVGASWAP:
		DataExchange( TRUE );
		if (m_bDisVGASwap) {
			SetCheck( IDC_VGASWAP, FALSE ); // Clear it
			Enable( IDC_VGASWAP, FALSE ); // Disable it
		} // Going from off to on
		else {
			Enable( IDC_VGASWAP, TRUE );
		} // Re-enabling
		return TRUE;

	case IDC_ROMSRCH:
		DataExchange( TRUE );
		if (m_bROMSrch && m_bHasUseHigh && !m_bDisROMSrch) {
			m_bDisROMSrch = TRUE;
			m_bAutoStrip = TRUE;
		} // Automatic behavior: strip previous USE= in BIOS area
		else if (!m_bROMSrch && m_bAutoStrip) {
			m_bDisROMSrch = FALSE;
			m_bAutoStrip = FALSE;
		} // Undo automatic behavior
		DataExchange( FALSE );
		return TRUE;
	}
	return MxDialog::OnCommand(id, notify);
}

/////////////////////////////////////////////////////////////////////////////
// CEndPhase1 dialog

BOOL CEndPhase1::OnCommand(int id, int notify)
{
	if (id == IDC_BACK && notify == BN_CLICKED) {
		EndDialog( IDC_BACK );
		return TRUE;
	}
	return MxDialog::OnCommand(id, notify);
}

/////////////////////////////////////////////////////////////////////////////
// CSelectMBoot dialog

CSelectMBoot::CSelectMBoot(LPCSTR lpDefault) : MxDialog(IDD_SELECTMBOOT)
{
	m_szSelDesc[ 0 ] = '\0';
	m_szSelected[ 0 ] = '\0';
	if (lpDefault) {
		lstrcpyn( m_szSelected, lpDefault, sizeof( m_szSelected ) );
	}
}

BOOL CSelectMBoot::OnInitDialog( void )
{
	MxDialog::OnInitDialog();

	char cBoot = ::get_bootdrive();
	int nFoundSelect = -1;
	HWND hCb = Item( IDC_SELECTMB );

	::SendMessage( hCb, CB_RESETCONTENT, 0, 0L );
	::SendMessage( hCb, CB_LIMITTEXT, sizeof( m_szSelDesc ) - 1, 0L );

	// Get list of sections
	if (::menu_parse( cBoot, 0 )) {
		::SendMessage( hCb, CB_ADDSTRING, 0, (LPARAM)(LPSTR)m_szSelected );
	} // Failed; add default
	else {
		SECTNAME FAR *lpSect;
		int nPosition;

		for (lpSect = FirstSect; lpSect; lpSect = lpSect->next) {
			if (!_fstricmp( lpSect->name, "menu" ) ||
				!_fstricmp( lpSect->name, "common" )) {
					continue;
			} // These aren't real sections...

			LPSTR lpText = (lpSect->text && *lpSect->text) ? lpSect->text : lpSect->name;
			nPosition = (int)::SendMessage( hCb, CB_ADDSTRING, 0, (LPARAM)lpText );

			if (nFoundSelect < 0 && !_fstricmp( lpSect->name, m_szSelected )) {
				nFoundSelect = nPosition;
				lstrcpyn( m_szSelDesc, lpText, sizeof( m_szSelDesc ) );
			} // Save index to highlight

			if (nPosition >= 0) {
				::SendMessage( hCb, CB_SETITEMDATA, nPosition, (LPARAM)lpSect->name );
			} // String added successfully
		} // for all sections
	} // Get all sections

	::SendMessage( hCb, CB_SETCURSEL, nFoundSelect, 0L );
	return TRUE;
}

void CSelectMBoot::OnOK()
{
	HWND hCb = Item( IDC_SELECTMB );
	::GetWindowText( hCb, m_szSelDesc, sizeof( m_szSelDesc ) );

	// Get selected section and ensure it's valid
	int nSelected = (int)::SendMessage( hCb, CB_FINDSTRINGEXACT, (WPARAM)-1,
					(LPARAM)(LPSTR)m_szSelDesc );
	if (nSelected != CB_ERR) {
		lstrcpyn( m_szSelected,
			(LPCSTR)::SendMessage( hCb, CB_GETITEMDATA, nSelected, 0L ),
			sizeof( m_szSelected ) );
	} // Found index
	else {
		int n, nTotal = (int)::SendMessage( hCb, CB_GETCOUNT, 0, 0L );
		for (n = 0; n < nTotal; n++) {
			LPCSTR lpName = (LPCSTR)::SendMessage( hCb, CB_GETITEMDATA, n, 0L );
			if (!lstrcmpi( m_szSelDesc, lpName )) {
				lstrcpyn( m_szSelected, lpName, sizeof( m_szSelected ) );
				break;
			} // Found a match
		} // Try to find matching section
		if (n >= nTotal) {
			char szMsg[ 256 ];
			n = strspn( m_szSelDesc, " \t." );
			wsprintf( szMsg, "Invalid section [%s] - please try again", (LPSTR)m_szSelDesc );
			MxMessageBox( m_szSelDesc[ n ] ? szMsg : "You must select a MultiConfig section" );
			return;
		} // Didn't find it
	} // Check to ensure it's a real section

	EndDialog( IDOK );
}

/////////////////////////////////////////////////////////////////////////////
// CSelectMode dialog

BOOL CSelectMode::OnInitDialog( void )
{
	MxDialog::OnInitDialog();
	::SendMessage( m_hWnd, DM_SETDEFID, m_bCustom ? IDC_CUSTOM : IDC_EXPRESS, 0L );
	::SetFocus( Item( m_bCustom ? IDC_CUSTOM : IDC_EXPRESS ) );
	return FALSE;		// focus set
}

BOOL CSelectMode::OnCommand(int id, int notify)
{
	if (notify == BN_CLICKED) switch (id) {
	case IDC_CUSTOM:
		m_bCustom = TRUE;
		EndDialog( IDC_CUSTOM );
		return TRUE;
	case IDC_EXPRESS:
		m_bCustom = FALSE;
		EndDialog( IDC_EXPRESS );
		return TRUE;
	case IDC_BACK:
		EndDialog( IDC_BACK );
		return TRUE;
	case IDOK:		// Enter: the default button
		EndDialog( m_bCustom ? IDC_CUSTOM : IDC_EXPRESS );
		return TRUE;
	}
	return MxDialog::OnCommand(id, notify);
}

/////////////////////////////////////////////////////////////////////////////
// Splash screen

static HBITMAP hbmSplash;

BOOL CALLBACK __export SplashProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	BITMAP bm;
	PAINTSTRUCT ps;

	switch (msg) {
	case WM_INITDIALOG:
		::ShowWindow( ::GetDlgItem( hWnd, IDC_STAT_SPLASHBMP ), SW_HIDE );
		if (hbmSplash && ::GetObject( hbmSplash, sizeof( bm ), &bm )) {
			::MoveWindow( hWnd, 0, 0, bm.bmWidth, bm.bmHeight, FALSE );
		}
		CenterDialog( hWnd );
		return TRUE;

	case WM_PAINT:
		::BeginPaint( hWnd, &ps );
		if (hbmSplash) {
			HDC hdcMem = ::CreateCompatibleDC( ps.hdc );
			if (hdcMem) {
				::GetObject( hbmSplash, sizeof( bm ), &bm );
				HBITMAP hOld = (HBITMAP)::SelectObject( hdcMem, hbmSplash );
				::BitBlt( ps.hdc, 0, 0, bm.bmWidth, bm.bmHeight, hdcMem, 0, 0, SRCCOPY );
				::SelectObject( hdcMem, hOld );
				::DeleteDC( hdcMem );
			}
		}
		::EndPaint( hWnd, &ps );
		return TRUE;
	}
	return FALSE;
}

HWND SplashCreate(void)
{
	hbmSplash = ::LoadBitmap( g_hInstance, MAKEINTRESOURCE( IDB_STAT_SPLASHSCRN ) );
	HWND hWnd = ::CreateDialog( g_hInstance, MAKEINTRESOURCE( IDD_STAT_SPLASH ), NULL,
				(DLGPROC)SplashProc );
	if (hWnd) {
		::ShowWindow( hWnd, SW_SHOW );
		::UpdateWindow( hWnd );
	}
	return hWnd;
}

void SplashDestroy(HWND hWnd)
{
	if (hWnd) ::DestroyWindow( hWnd );
	if (hbmSplash) ::DeleteObject( hbmSplash );
	hbmSplash = NULL;
}

/////////////////////////////////////////////////////////////////////////////
// Blue screen behind the summary

BOOL CALLBACK __export BlueProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
	PAINTSTRUCT ps;
	RECT rc;
	int i, xInc, yInc;

	switch (msg) {
	case WM_INITDIALOG:
		::MoveWindow( hWnd, 0, 0, ::GetSystemMetrics( SM_CXSCREEN ),
				::GetSystemMetrics( SM_CYSCREEN ), TRUE );
		return TRUE;

	case WM_ERASEBKGND:
		return TRUE;		// WM_PAINT covers all of it

	case WM_PAINT:
		::BeginPaint( hWnd, &ps );
		::GetClientRect( hWnd, &rc );
		xInc = (rc.right - rc.left) / 10;
		yInc = (rc.bottom - rc.top) / 10;

		// Six nested rectangles, lighter towards the middle
		for (i = 0; i < 6; i++, ::InflateRect( &rc, -xInc, -yInc )) {
			HBRUSH hbr = ::CreateSolidBrush( RGB( 0, 10 + i * 4, 127 + i + 16 ) );
			if (!hbr) continue;
			::FillRect( ps.hdc, &rc, hbr );
			::DeleteObject( hbr );
		} // for all colors
		::EndPaint( hWnd, &ps );
		return TRUE;
	}
	return FALSE;
}

HWND BlueCreate(void)
{
	HWND hWnd = ::CreateDialog( g_hInstance, MAKEINTRESOURCE( IDD_STAT_BLUESCREEN ), NULL,
				(DLGPROC)BlueProc );
	if (hWnd) {
		::ShowWindow( hWnd, SW_SHOW );
		::UpdateWindow( hWnd );
	}
	return hWnd;
}
