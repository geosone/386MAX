// MXDLGS.H - WINMAXIM dialogs on wxWindows 1.68E (Open 386MAX 9)
//
// The dialogs are the DIALOG resources of WINMXMZ.RC / WINMXMZ.GR, loaded
// by wxDialogBox::LoadNativeDialog; MxDialog takes the place of MFC's
// CDialog (DoModal, EndDialog, OnInitDialog, OnOK, OnCancel, data
// exchange).
//
// Copyright (C) 1995 Qualitas, Inc.  GNU General Public License version 3.
// Open 386MAX contributors 2022-2026.

#ifndef _MXDLGS_INCLUDED
#define	_MXDLGS_INCLUDED

class MxDialog;

// the wxWindows window of a dialog: passes commands to the MxDialog
class MxDialogBox : public wxDialogBox
{
public:
	MxDialogBox(MxDialog *pDlg) { m_pDlg = pDlg; }
	Bool OnNativeCommand(int id, int notify);
	Bool OnClose(void);
	MxDialog *m_pDlg;
};

class MxDialog
{
public:
	MxDialog(int nID);
	virtual ~MxDialog() {}

	int DoModal(wxWindow *pParent = NULL);	// IDOK, IDCANCEL, ...
	void EndDialog(int nResult);

	virtual BOOL OnInitDialog(void);
	virtual void DataExchange(BOOL bSave) {}	// controls <-> members
	virtual BOOL OnCommand(int id, int notify);	// TRUE: handled
	virtual void OnOK(void);
	virtual void OnCancel(void);
	virtual void OnHelp(void);

	// controls
	HWND Item(int id) { return ::GetDlgItem(m_hWnd, id); }
	BOOL GetCheck(int id) { return ::IsDlgButtonChecked(m_hWnd, id) != 0; }
	void SetCheck(int id, BOOL b) { ::CheckDlgButton(m_hWnd, id, b ? 1 : 0); }
	void Enable(int id, BOOL b) { ::EnableWindow(Item(id), b); }

	HWND m_hWnd;
	int m_nID;		// IDD_...
	int m_nResult;
	BOOL m_bEnded;
	MxDialogBox *m_pBox;
};

class CCustomOpts : public MxDialog
{
public:
	CCustomOpts(int nID = IDD_CUSTOPTS);

	BOOL	m_bExtraDOS;
	BOOL	m_bROMSrch;
	BOOL	m_bVGASwap;
	BOOL	m_bDisROMSrch;
	BOOL	m_bDisVGASwap;
	BOOL	m_bDOSStart;

	char m_szMaxPro[ _MAX_PATH ];	// Path of 386MAX.PRO file
	BOOL m_bHasVGASwap; // TRUE if VGASWAP already present
	BOOL m_bHasUseHigh;	// TRUE if USE= >= F000 already present
	BOOL m_bAutoStrip;	// TRUE if m_bDisROMSrch turned on automatically
	BOOL m_bWin95;		// TRUE if Win95
	BOOL m_bDOSStartEna; // If Win95, TRUE if DOSSTART exists
	BOOL m_bROMSrchEna;	// FALSE if ROMSrch must not be run (e.g. BCF)

	BOOL OnInitDialog(void);
	void DataExchange(BOOL bSave);
	BOOL OnCommand(int id, int notify);
};

class CEndPhase1 : public MxDialog
{
public:
	CEndPhase1() : MxDialog(IDD_END_PHASE1) {}
	BOOL OnCommand(int id, int notify);
};

class CSelectMBoot : public MxDialog
{
public:
	CSelectMBoot(LPCSTR lpDefault);
	char m_szSelDesc[ 81 ];
	char m_szSelected[ 81 ];
	BOOL OnInitDialog(void);
	void OnOK(void);
};

class CSelectMode : public MxDialog
{
public:
	CSelectMode() : MxDialog(IDD_SELECTMODE) { m_bCustom = FALSE; }
	BOOL m_bCustom; // TRUE if custom, FALSE if express
	BOOL OnInitDialog(void);
	BOOL OnCommand(int id, int notify);
};

class CWelcome : public MxDialog
{
public:
	CWelcome() : MxDialog(IDD_WELCOME) {}
};

class CExit : public MxDialog
{
public:
	CExit() : MxDialog(IDD_CONFIRMEXIT) {}
	void OnCancel(void) { EndDialog(IDCANCEL); }	// no help to close
};

// Splash screen (bitmap IDB_STAT_SPLASHSCRN) while starting
class CSplash : public wxDialogBox
{
public:
	CSplash();
	~CSplash();
	void OnPaint(void);
	HBITMAP m_hbm;
};

// Blue background of the summary
class CBlue : public wxDialogBox
{
public:
	CBlue();
	void OnPaint(void);
	Bool OnClose(void) { return FALSE; }
};

void CenterDialog(HWND hWnd);

#endif
