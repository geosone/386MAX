// WINMXMZ.H - main header file for WINMAXIM (Open 386MAX 9, wxWindows 1.68E)
//
// Copyright (C) 1995 Qualitas, Inc.  GNU General Public License version 3.
// Open 386MAX contributors 2022-2026.

#ifndef _WINMXMZ_INCLUDED
#define	_WINMXMZ_INCLUDED

#include "resource.h"       // main symbols

#define	HID_BASE_RESOURCE	0x00020000UL	// help ids of the dialogs (as MFC)

class CWinmxmzApp : public wxApp
{
public:
	wxFrame *OnInit(void);
	int OnExit(void);
};

extern BOOL g_bWin95;		// Windows 95/98
extern HWND g_hwndDlg;		// dialog for WinHelp
extern char g_szProfile[];	// MAXIMIZE.INI with path
extern char g_szTitle[];	// "Windows Maximize"

// MAXIMIZE.INI
int ProfileInt(LPCSTR lpSect, LPCSTR lpEntry, int nDefault);
void WriteProfileInt(LPCSTR lpSect, LPCSTR lpEntry, int nValue);
void ProfileString(LPCSTR lpSect, LPCSTR lpEntry, LPCSTR lpDefault, char *pszBuff, int nSize);
void WriteProfileStr(LPCSTR lpSect, LPCSTR lpEntry, LPCSTR lpValue);

void MxWinHelp(DWORD dwData, UINT uCmd = HELP_CONTEXT);
int MxMessageBox(LPCSTR lpMsg);

#endif
