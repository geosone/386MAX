// WINMXMZ.CPP - Windows-based kickoff for Maximize (WINMAXIM.EXE)
//
// Open 386MAX: Win16 API instead of MFC 2.5.  Same steps as
// the MFC version (Henry Groover, Qualitas 1995-96): splash screen,
// welcome, MultiConfig section, express/custom, options, then exit
// Windows and run MAXIMIZE; "/summary<KB>" (from WINLNCH after Maximize)
// shows the summary.
//
// Copyright (C) 1995-96 Qualitas, Inc.  GNU General Public License version 3.
// Open 386MAX contributors 2022-2026.

#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <io.h>
#include <dos.h>
#include <direct.h>
#include <malloc.h>

#include <maxnames.h>
#include <commfunc.h>
#include <mbparse.h>
#include <statutil.h>
#include "winmxmz.h"
#include "mxdlgs.h"
#include "summary.h"

#define	WINMXMZ
#include "messages.h"

#include <mxhelpid.h>
#include <ctl3d.h>

HINSTANCE g_hInstance;
BOOL g_bWin95 = FALSE;
HWND g_hwndDlg = NULL;
char g_szProfile[ _MAX_PATH ] = MAXIMIZE_INI;
char g_szTitle[ 80 ] = "Windows Maximize";

char szMaxDir[ _MAX_PATH ];	// 386MAX directory with trailing BS
char *pszSect = NULL;	// Selected MultiConfig section

#define	MAXBUFF 256

/////////////////////////////////////////////////////////////////////////////
// MAXIMIZE.INI (MFC: CWinApp profile functions)

int ProfileInt(LPCSTR lpSect, LPCSTR lpEntry, int nDefault)
{
	return ::GetPrivateProfileInt( lpSect, lpEntry, nDefault, g_szProfile );
}

void WriteProfileInt(LPCSTR lpSect, LPCSTR lpEntry, int nValue)
{
	char szBuff[ 16 ];
	wsprintf( szBuff, "%d", nValue );
	::WritePrivateProfileString( lpSect, lpEntry, szBuff, g_szProfile );
}

void ProfileString(LPCSTR lpSect, LPCSTR lpEntry, LPCSTR lpDefault, char *pszBuff, int nSize)
{
	::GetPrivateProfileString( lpSect, lpEntry, lpDefault, pszBuff, nSize, g_szProfile );
}

void WriteProfileStr(LPCSTR lpSect, LPCSTR lpEntry, LPCSTR lpValue)
{
	::WritePrivateProfileString( lpSect, lpEntry, lpValue, g_szProfile );
}

int MxMessageBox(LPCSTR lpMsg)
{
	return ::MessageBox( g_hwndDlg, lpMsg, g_szTitle, MB_OK | MB_ICONEXCLAMATION );
}

// Help for the dialogs (MAXHELP.HLP)
void MxWinHelp( DWORD dwData, UINT uCmd )
{
	static BOOL bHelp = FALSE;	// Have not been run yet
	static HWND hwndHelp = NULL;

	if (uCmd == HELP_QUIT) {
		if (bHelp && hwndHelp && ::IsWindow( hwndHelp )) {
			::WinHelp( hwndHelp, MAXHELP_HLP, HELP_QUIT, 0L );
		}
		bHelp = FALSE;
		return;
	}
	if (uCmd == HELP_CONTEXT || uCmd == HELP_CONTEXTPOPUP) {
		dwData |= WINMX_HLP_DWORD;
	}
	if (g_hwndDlg) {
		bHelp = TRUE;
		hwndHelp = g_hwndDlg;
		::WinHelp( g_hwndDlg, MAXHELP_HLP, uCmd, dwData );
	}
}

void
ParseCfg( CCustomOpts& opts ) {

	// First, let's read MAXIMIZE.CFG
	char szMaxCfg[ _MAX_PATH ];
	strcpy( szMaxCfg, szMaxDir );
	strcat( szMaxCfg, MAXIMIZE_CFG );
	FILE *pfCfg = fopen( szMaxCfg, "rt" );
	char szBuff[ MAXBUFF + 1 ], *psz;

	if (pfCfg) {

		while (fgets( szBuff, MAXBUFF, pfCfg )) {

			szBuff[ MAXBUFF ] = '\0';

			// Clobber any trailing comments
			psz = strchr( szBuff, ';' );
			if (psz) {
				*psz = '\0';
			}

			// We're only interested in NOROMSRCH, NOVGASWAP, and NOEXTRADOS
			psz = strtok( szBuff, " \t\r\n=" );
			if (psz) {
				if (!_stricmp( psz, "NOROMSRCH" )) {
					opts.m_bROMSrch = FALSE;
				} // Got NOROMSRCH
				else if (!_stricmp( psz, "NOVGASWAP" )) {
					opts.m_bVGASwap = FALSE;
				} // Got NOVGASWAP
				else if (!_stricmp( psz, "NOEXTRADOS" )) {
					opts.m_bExtraDOS = FALSE;
				} // Got NOEXTRADOS
			} // Got a token

		} // Not EOF

		fclose( pfCfg );

	} // Opened OK

} // ParseCfg()

// Class for parsing CONFIG.SYS
class CConfigParse {

public:
	// Initialize with section to parse
	CConfigParse( LPCSTR lpSect );

	~CConfigParse( void );

	// Parse CONFIG.SYS.  Returns 1 if found, else 0.
	int Parse( void );

	char m_szDevLine[ 256 ]; // DEVICE= line
	char m_cBoot;		// Boot drive
	BYTE m_Owner;		// Active owner

	// Callback function used in parsing
	int CBfn( CONFIGLINE _far *lpCfg );

protected:
	int m_nMenuFree; // If non-zero, call config_free when cleaning up.

};

// Implementation of CConfigParse class
CConfigParse::CConfigParse( LPCSTR lpSect ) {

	m_szDevLine[ 0 ] = '\0';
	m_cBoot = ::get_bootdrive();

	m_nMenuFree = ::menu_parse( m_cBoot, 1 );

	::set_current( (LPSTR)lpSect );

	m_Owner = ActiveOwner;

} // CConfigParse::CConfigParse()

// Global pointer needed to call member function
// Note that this will never work for multiple instances.  The mbparse
// callback should be changed to take a DWORD of data for the callback.
static CConfigParse *pParse;

// C callback stub
int _cdecl _far
CConfigParse_CBfn( CONFIGLINE _far *lpCfg ) {
	return pParse->CBfn( lpCfg );
} // CConfigParse_CBfn()

int
CConfigParse::Parse( void ) {

	// Note that parsing frees up menu data
	m_nMenuFree = 0;

	pParse = this;
	return !::config_parse( m_cBoot, m_Owner, "/dev/nul", 0,
					CConfigParse_CBfn );

} // CConfigParse::Parse()

int
CConfigParse::CBfn( CONFIGLINE _far *lpCfg ) {

	char szBuff[ 256 ], szName[ _MAX_FNAME + _MAX_EXT ], szExt[ _MAX_EXT ];
	char *pszTok;

	// Called with data for each line.
	// FIXME allow a list of possible drivers to be specified.
	// Return
	if (lpCfg->ID == ID_DEVICE) {

		lstrcpy( szBuff, lpCfg->line );

		// Skip DEVICE*
		pszTok = strtok( szBuff, " \t=\r\n" );

		// Skip any switches
		while ((pszTok = strtok( NULL, " \t=\r\n" )) && *pszTok == '/') ;

		// If anything left it's our boy
		if (pszTok) {

			_splitpath( pszTok, NULL, NULL, szName, szExt );
			strcat( szName, szExt );

			// Now check for the device we're looking for
			// FIXME use a list passed to our constructor
			// To make things easier we'll start with the path, e.g.
			// c:\386max\386max.sys pro=c:\386max\386max.pro
			if (!_stricmp( szName, MGRNAME_SYS ) ||
				!_stricmp( szName, ALTMGRNAME_SYS )) {
				lstrcpyn( m_szDevLine, (lpCfg->line + (int)(pszTok - szBuff)), sizeof( m_szDevLine ) );
			} // Found it

		} // Got path

	} // Got a device

	return 0; // Don't do any relocation

} // CConfigParse::CBfn()


CConfigParse::~CConfigParse( void ) {
	if (m_nMenuFree) {
		::config_free();
	} // Need to free menu data
} // CConfigParse::~CConfigParse()

// Parse CONFIG.SYS to find 386MAX.PRO and save profile name.
void
ParseCfgSys( char *pszPro ) {

	// Innocent until proven guilty...
	*pszPro = '\0';

	// Troll for DEVICE=386max.sys or DEVICE=bluemax.sys
	CConfigParse cfgp( pszSect ? pszSect : "common" );

	// If found, parse line for pro= (ignore other statements)
	if (cfgp.Parse()) {

		strlwr( cfgp.m_szDevLine );

		LPSTR lpszPro = (LPSTR)strstr( cfgp.m_szDevLine, "pro=" );

		if (lpszPro) {

			lpszPro = strtok( lpszPro + 4, " \t\r\n" );

			if (lpszPro) {
				strcpy( pszPro, lpszPro );
			} // Got argument

		} // Found pro= statement

	} // Got line

} // ParseCfgSys()

// Parse .PRO file for USE= above F000 and for VGASWAP.
// Also check for BCF= or AUTOBCF and if found, disable ROMSrch.
// opts.m_szMaxPro should already be set.
void
ParsePro( CCustomOpts& opts ) {

	FILE *pfPro;
	char szBuff[ MAXBUFF + 1 ];

	// Innocent until proven guilty...
	opts.m_bHasVGASwap = FALSE;
	opts.m_bHasUseHigh = FALSE;
	opts.m_bROMSrchEna = TRUE;

	// Now parse profile if found.  If no path, tough.
	// FIXME assert boot drive as drive letter, but it's not quite
	// that simple, and assert boot root as directory.
	if (opts.m_szMaxPro[ 0 ] &&
		(pfPro = fopen( opts.m_szMaxPro, "rt" ))) {

		// If no multiconfig, we're seeking common
		int nSectFound = 1; // Always start with common
		char *pszFindSect = "common";

		if (pszSect) {
			pszFindSect = pszSect;
		}

		while (fgets( szBuff, MAXBUFF, pfPro )) {

			// Terminate it
			szBuff[ MAXBUFF ] = '\0';

			// Check for section
			if (szBuff[ 0 ] == '[') {

				char *pszTrail = strchr( &szBuff[ 1 ], ']' );

				if (pszTrail) {
					*pszTrail = '\0';
				} // Got trailing ] to clobber

				// Check for common or the specified section
				nSectFound = (!_stricmp( &szBuff[ 1 ], "common" ) ||
					!_stricmp( &szBuff[ 1 ], pszFindSect ));

			} // Got section name
			else if (nSectFound) {

				// Troll for VGASWAP, USE=, BCF=, etc.
				static char szTokList[] = " \t=,-\r\n";
				char *pszComment = strchr( szBuff, ';' );
				if (pszComment) {
					*pszComment = '\0';
				} // Clobber comments

				char *pszTok = strtok( szBuff, szTokList );
				if (!pszTok) {
					continue;
				} // Empty line

				if (!_stricmp( pszTok, "VGASWAP" )) {
					opts.m_bHasVGASwap = TRUE;
				} // Found VGASWAP
				else if (!_stricmp( pszTok, "USE" ) &&
						 (pszTok = strtok( NULL, szTokList ))) {

					WORD wStart = 0;

					sscanf( pszTok, "%x", &wStart );

					if (wStart >= 0xf000) {
						opts.m_bHasUseHigh = TRUE;
					} // Found one above f000

				} // Found a USE= statement
				else if (!_stricmp( pszTok, "BCF" ) ||
						 !_stricmp( pszTok, "AUTOBCF" )) {
					opts.m_bROMSrchEna = FALSE;
				} // Got BCF= or AUTOBCF

			} // Not ignoring

		} // Not EOF

		fclose( pfPro );

	} // Got a profile name

} // ParsePro()


// Set up batch files to reboot into Maximize.
// This is needed only if MAX is not the current memory manager.
// We'll pass Maximize.exe the /R option if all goes well here.
int
SetAutoWMX( LPCSTR lpMaxDir, char *pszMaximize, char *pszOptions ) {

		/***
		 *	User requested to reboot and run MAXIMIZE.
		 *	We need to save the AUTOEXEC.BAT as
		 *	AUTO_WMX.$$$, create a new autoexec.bat which then
		 *	chains to AUTO_WMX.BAT, which itself does the following:
		 *	1. Copies the original AUTOEXEC.BAT back in
		 *	   place.
		 *	2. Displays a brief "Come out of your
		 *	   shell" message.
		 *	3. Processes AUTOEXEC.BAT using BATPROC.
		 *	4. Starts MAXIMIZE with the selected parameters.
		 *     Note the /R should have no effect the second
		 *     time around because we'll either have MAX
		 *     present or we'll be in real mode.
		 ***/

		char szDestpath[ _MAX_PATH ];
		FILE *autotemp, *pfTemp2;

		// Copy AUTOEXEC.BAT to AUTO_WMX.$$$
		wsprintf( szDestpath, "%s" TEMPAUTO_TMP, lpMaxDir );
		if (!CopyFile( StartupBat, szDestpath )) return -1;

		// Copy CONFIG.SYS to AUTO_WMX.CFG
		wsprintf( szDestpath, "%s" TEMPAUTO_CFG, lpMaxDir );
		if (!CopyFile( ConfigSys, szDestpath )) return -1;

		// Create AUTO_WMX.BAT which restores original
		// AUTOEXEC and starts MAXIMIZE.
		wsprintf( szDestpath, "%s" TEMPAUTO_BAT, lpMaxDir );
		autotemp = fopen( szDestpath, "w" );
		if (!autotemp) return -1;

		wsprintf( szDestpath, "%s" TEMPAUTO_TMP, lpMaxDir );
		//truename( szDestpath );
		fprintf( autotemp, MsgAutotemp, szDestpath );

		strcpy( szDestpath, StartupBat );
		//truename( szDestpath );
		fprintf( autotemp, "%s\n", szDestpath );

		wsprintf( szDestpath, "%s" TEMPAUTO_CFG, lpMaxDir );
		//truename( szDestpath );
		fprintf( autotemp, "copy %s %s\n", szDestpath, ConfigSys );
		wsprintf( szDestpath, "%sBATPROC", lpMaxDir );
		//truename( szDestpath );
		fprintf( autotemp, "%s %s * 386LOAD Maximize.trm\n",
				szDestpath, StartupBat );

		fprintf( autotemp, "%s %s\n", pszMaximize, pszOptions );
		fclose( autotemp );

		// Create new AUTOEXEC.BAT which starts c:\386max\autoinst.bat
		autotemp = fopen( StartupBat, "w" );
		if (!autotemp) return -1;

		wsprintf( szDestpath, "%s" TEMPAUTO_BAT, lpMaxDir );
		//truename( szDestpath );
		fprintf( autotemp, "%s\n", szDestpath );
		fclose( autotemp );

		// If MultiConfig write first four lines of CONFIG.SYS
		if (pszSect) {

			char szBuff[ 512 ];

			wsprintf( szDestpath, "%sCFG_SYS.$$$", lpMaxDir );
			pfTemp2 = fopen( szDestpath, "w" );

			if (pfTemp2) {

				fprintf( pfTemp2, "[menu]\nMenuItem=%s\nMenuDefault=%s,0\n[common]\n", pszSect, pszSect );

				if (autotemp = fopen( ConfigSys, "r" )) {

					while (fgets( szBuff, sizeof( szBuff ) - 1, autotemp )) {

						szBuff[ sizeof( szBuff ) - 1 ] = '\0';

						fputs( szBuff, pfTemp2 );

					} // not EOF

					fclose( autotemp );

				} // Opened CONFIG.SYS for input

				fclose( pfTemp2 );

				// Now copy the new file to config.sys
				CopyFile( szDestpath, ConfigSys );

			} // Opened output

		} // Write CONFIG.SYS

		// Now create a _mximize.bat that uses maximize /r to test
		// for whether we're in real mode.
		wsprintf( szDestpath, "%s_MXIMIZE.BAT", lpMaxDir );
		autotemp = fopen( szDestpath, "w" );
		if (autotemp) {

			fprintf( autotemp, "@echo off\necho off\n" );
			fprintf( autotemp, "%Fsmaximize.exe /r\n", lpMaxDir );
			fprintf( autotemp, "if not errorlevel 5 goto end\n"
							   "copy %Fs" TEMPAUTO_CFG " %s\n",
							   	lpMaxDir, ConfigSys );
			fprintf( autotemp, "copy %Fs" TEMPAUTO_TMP " %s\n",
								lpMaxDir, StartupBat );
			fprintf( autotemp, ":end\n" );
			fprintf( autotemp, "%s %s\n", pszMaximize, pszOptions );

			fclose( autotemp );

			// Now set up the new command line
			char *pszComspec = getenv( "COMSPEC" );
			if (!pszComspec) pszComspec = "command.com";

			strcpy( pszMaximize, pszComspec );

			wsprintf( pszOptions, "/c %s", szDestpath );

		} // Created OK

		return 0; // Success

} // SetAutoWMX()

/////////////////////////////////////////////////////////////////////////////
// Start: splash screen, then the dialogs (or the summary)

static int Winmaxim(HINSTANCE hInstance, LPSTR lpCmdLine);

int PASCAL WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
	g_hInstance = hInstance;
	::LoadString( hInstance, IDS_APP_TITLE, g_szTitle, sizeof( g_szTitle ) );

	// Enable 3D controls
	Ctl3dRegister( hInstance );
	Ctl3dAutoSubclass( hInstance );

	Winmaxim( hInstance, lpCmdLine );

	// Shut down help
	MxWinHelp( 0L, HELP_QUIT );

	Ctl3dUnregister( hInstance );
	return 0;
}

static int Winmaxim(HINSTANCE hInstance, LPSTR lpCmdLine)
{
	DWORD dwVer;

	// command line (WINLNCH: "/summary<KB>"; Toolbox: "/I")
	char szCmdLine[ 128 ];
	lstrcpyn( szCmdLine, lpCmdLine, sizeof( szCmdLine ) );

	// Display splash screen
	HWND hSplash = SplashCreate();

	DWORD dwStartSplash = ::GetTickCount();
	DWORD dwNow;

	// find out if we're in Win95.
	dwVer = GetVersion();
	g_bWin95 = ( LOBYTE( LOWORD( dwVer )) > 3 ) ||
		   ( ( LOBYTE( LOWORD( dwVer )) > 2) && ( HIBYTE( LOWORD( dwVer )) > 15) );

	WORD wHigh, wLSeg;
	BOOL bQMax = qmaxpres( &wHigh, &wLSeg );

	// Get directory we're loaded from to locate Max components.
	char szExe[ _MAX_PATH ], szDrive[ _MAX_DRIVE ], szDir[ _MAX_DIR ];
	::GetModuleFileName( hInstance, szExe, sizeof( szExe ) );
	_splitpath( szExe, szDrive, szDir, NULL, NULL );

	// Now reassemble the drive and directory (with trailing backslash)
	strcpy( szMaxDir, szDrive );
	strcat( szMaxDir, szDir );

	// Put up our dialogs
	// From here on out we're running a simple state machine
	// or finite-state automaton.
	// Some states are optional, and may repeat the previous
	// direction.
	enum {
		START_STATE=0,
		MBOOT_STATE,
		MODE_STATE,
		OPTION_STATE,
		REBOOT_STATE,
		END_STATE,
		CANCEL_STATE
	};
	int nState = START_STATE;
	int nDirection = 1;
	int nRes;
	CWelcome welcome;
	CSelectMode mode;
	CCustomOpts opts( g_bWin95 ? IDD_CUSTOPTS95 : IDD_CUSTOPTS );
	CEndPhase1 end1;
	CExit confexit;
	char addbat[ _MAX_PATH ];
	addbat[ 0 ] = '\0';

	// Don't try to evade a faked current section
	char *pszConfig = getenv( "CONFIG" );
	if (pszConfig) {
		pszSect = _fstrdup( pszConfig );
	} // CONFIG defined in environment

	// Set defaults from MAXIMIZE.INI
	strcpy( g_szProfile, szMaxDir );
	strcat( g_szProfile, MAXIMIZE_INI );

	mode.m_bCustom = ProfileInt( INIS_DEFAULTS, INI_CUSTOM, FALSE );

	opts.m_bWin95 = g_bWin95;
	if (g_bWin95) {
		opts.m_bDOSStart = ProfileInt( INIS_DEFAULTS, INI_DOSSTART, FALSE );
	} // Get additional option for Win95

	opts.m_bROMSrch = ProfileInt( INIS_DEFAULTS, INI_ROMSRCH, TRUE );
	opts.m_bVGASwap = ProfileInt( INIS_DEFAULTS, INI_VGASWAP, TRUE );
	opts.m_bExtraDOS = ProfileInt( INIS_DEFAULTS, INI_EXTRADOS, TRUE );

	// Now try to find a DEVICE=386max.sys or DEVICE=bluemax.sys line
	// and get m_csMaxPro
	ParseCfgSys( opts.m_szMaxPro );

	// Check Maximize.CFG and 386MAX.PRO specifically for NO* statements
	// and USE= statements at or above F000
	ParseCfg( opts );

	// If the current section does _not_ have 386MAX.SYS and we're
	// not going to ask about Multiconfig, bail out now...
	if (!pszSect && !opts.m_szMaxPro[ 0 ]) {
		MxMessageBox( ERRMSG_NOMAX );
		return 0;
	} // Max not found

	// Parse profile for m_bHasVGASwap, m_bHasUseHigh
	ParsePro( opts );

	// If ROMSrch has already been run for this section, turn it off.
	if (opts.m_bHasUseHigh || !opts.m_bROMSrchEna) {
		opts.m_bROMSrch = FALSE;
	} // ROMsrch-recovered areas already present

	// Create and save path to DOSSTART.BAT
	if (g_bWin95) {

		char szDir[ _MAX_DIR ], szPath[ _MAX_PATH ];

		GetWindowsDirectory( szDir, sizeof( szDir ) );

		// Drive component in directory c:\win95 will _not_ be discarded
		// as the docs so erroneously indicate.
		_makepath( szPath, "", szDir, "DOSStart", ".bat" );

		strcpy( addbat, szPath );

	} // Save path to DOSSTART.BAT

	// Wait a bit
	do {
		dwNow = ::GetTickCount();
		{
			MSG msg;
			while (::PeekMessage( &msg, NULL, 0, 0, PM_REMOVE )) {
				::TranslateMessage( &msg );
				::DispatchMessage( &msg );
			}
		}
	} while (dwNow - dwStartSplash < 1600);

	// Dump the splash screen
	SplashDestroy( hSplash );

	// Note that only one _or_ the other of /I or /summary is allowed...
	int nFromToolbox = !_stricmp( szCmdLine, "/I" );

	if (!_strnicmp( szCmdLine, "/summary", 8 ))
	{
		// If invoked with /summary get summary data from MAXIMIZE.INI
		// This also removes the line that forces a Windows start at
		// the end of autoexec.
		HWND hBlue = BlueCreate();
		CSummary summ( atoi( &szCmdLine[ 8 ] ) );
		int nRes = summ.DoModal( hBlue );

		::DestroyWindow( hBlue );

		// If we're to revert, exit Windows and run Premaxim then reboot
		if (nRes == IDC_REVERT) {

			char szMaximize[ _MAX_PATH ];

			// Build path to maximize
			wsprintf( szMaximize, "%s" MAXIMIZE_EXE, szMaxDir );

			// If this fails, bitch about it
			if (!::ExitWindowsExec( szMaximize, "/X /P" )) {
				MxMessageBox( ERRMSG_CANTPREMAXIM );
			} // Failed to run maximize /X /P

		} // Take me home, daddy...

		return 0;
	}

	while (nState < END_STATE) {

		switch (nState) {

			case START_STATE:
				nDirection = 1;
				if (!nFromToolbox && welcome.DoModal() != IDOK) {
					nState = CANCEL_STATE;
				}
				break;

			case MBOOT_STATE:
				// If started from Toolbox, only allow Maximize
				// on current section.
				if (pszSect && !nFromToolbox) {

					CSelectMBoot selectmb( pszSect );

					nDirection = 1;
					_ffree( pszSect );

					switch (selectmb.DoModal()) {

						case IDOK:
							pszSect = _fstrdup( selectmb.m_szSelected );
							// Now re-read profile (possibly a different
							// profile or a different section in the same
							// profile)
							ParseCfgSys( opts.m_szMaxPro );
							opts.m_bROMSrch = ProfileInt( INIS_DEFAULTS,
										INI_ROMSRCH, FALSE );
							if (!opts.m_szMaxPro[ 0 ]) {
								MxMessageBox( ERRMSG_MAX_MCFG );
								nDirection = 0;
							} // Bitch about it
							else {

								ParsePro( opts );

								// If ROMSrch has already been run for this
								// section, turn it off.
								if (opts.m_bHasUseHigh) {
									opts.m_bROMSrch = FALSE;
								} // ROMsrch-recovered areas already present

							} // Parse MAX profile for this section

							break;

						case IDCANCEL:
							// No confirmation needed yet
							nState = CANCEL_STATE;
							break;

					} // switch ( selectmb )

				} // Multiconfig present
				break;

			case MODE_STATE:
				if (!nFromToolbox)
				  switch (mode.DoModal()) {

					case IDC_BACK:
						nDirection = -1;
						break;

					case IDC_EXPRESS:
						// If going from custom to express, should we
						// revert to basic express assumptions or leave
						// everything as is?

						// I guess we should revert...
						if (!opts.m_bHasUseHigh && opts.m_bROMSrchEna) {
							opts.m_bROMSrch = TRUE;
						}

						if (!opts.m_bHasVGASwap) {
							opts.m_bVGASwap = TRUE;
						}

						opts.m_bExtraDOS = TRUE;

						// Fall through to custom case

					case IDC_CUSTOM:
						nDirection = 1;
						break;

					case IDCANCEL:
						nDirection = 0;
						if (confexit.DoModal() == IDOK) {
							nState = CANCEL_STATE;
						} // Got confirmation
						break;

				  } // switch ()
				break;

			case OPTION_STATE:
				// If DOSSTART.BAT doesn't exist, disable the option
				if (g_bWin95) {

					opts.m_bDOSStartEna = !_access( addbat, 00 );

				} // Win95, make sure DOSSTART.BAT exists

				if (mode.m_bCustom) switch (opts.DoModal()) {

					case IDC_BACK:
						nDirection = -1;
						break;

					case IDOK:
						nDirection = 1;
						break;

					case IDCANCEL:
						nDirection = 0;
						if (confexit.DoModal() == IDOK) {
							nState = CANCEL_STATE;
						} // Got confirmation
						break;

				} // m_bCustom
				break;

			case REBOOT_STATE:
				nRes = end1.DoModal();
				if (nRes == IDOK) {

					char szMaximize[ _MAX_PATH ];
					char szOptions[ 128 ];

					// Save options in MAXIMIZE.INI.  Note that if we bail
					// out before getting this far, none of the option
					// changes we've made here will be saved.
					WriteProfileInt( INIS_DEFAULTS, INI_CUSTOM, mode.m_bCustom );
					WriteProfileInt( INIS_DEFAULTS, INI_ROMSRCH, opts.m_bROMSrch );
					WriteProfileInt( INIS_DEFAULTS, INI_VGASWAP, opts.m_bVGASwap );
					WriteProfileInt( INIS_DEFAULTS, INI_EXTRADOS, opts.m_bExtraDOS );

					if (g_bWin95) {
						WriteProfileInt( INIS_DEFAULTS, INI_DOSSTART, opts.m_bDOSStart );
					}

					// Save special commands
					WriteProfileInt( INIS_REMOVE, INI_USEHIGH, opts.m_bDisROMSrch );
					WriteProfileInt( INIS_REMOVE, INI_VGASWAP, opts.m_bDisVGASwap );

					// Build path to maximize
					wsprintf( szMaximize, "%s" MAXIMIZE_EXE, szMaxDir );

					// Build options
					sprintf( szOptions, "/X /V %s",
									mode.m_bCustom ? "/U" : "/E" );

					if (pszSect) {
						sprintf( &szOptions[ strlen( szOptions ) ], " /A %s",
							pszSect );
					} // MultiConfig section selected

					// FIXME we need a scheme that'll work for DOS and Windows.
					// We're close to running out of command line space
					// in some configurations though it's _highly_ unlikely.
					if (g_bWin95 && opts.m_bDOSStart && addbat[ 0 ]) {
						strcat( szOptions, " /O " );
						strcat( szOptions, addbat );
					} // Process DOSSTART.BAT too

					// Save startup name in MAXIMIZE.INI.  This is used to
					// save some code in MAXIMIZE.EXE.
					WriteProfileStr( INIS_CURRENTSECT, INI_STARTUPBAT, StartupBat );

					// If Max isn't present, set up batch file to boot into
					// Maximize
					if (!bQMax) {
						SetAutoWMX( szMaxDir, szMaximize, szOptions );
					} // MAX is not present

					// Exit and start Maximize.  Note that this may be done
					// via a batch file (szMaximize = "%COMSPEC%" and
					// szOptions = "/c c:\386max\_mximize.bat")
					if (!::ExitWindowsExec( szMaximize, szOptions )) {
						MxMessageBox( ERRMSG_CANTEXIT );
						nDirection = 0;
					} // Failed, try again

				} // Go ahead and reboot
				else switch (nRes) {

					case IDC_BACK:
						if (!nFromToolbox) {
							nDirection = -1;
						} // Not from Toolbox
						// FIXME Should we turn off nFromToolbox and let 'em
						// go back if they want to?
						else {
							nFromToolbox = 0;
							nDirection = -1;
						} // Let 'em go back
						break;

					case IDCANCEL:
						nDirection = 0;
						if (confexit.DoModal() == IDOK) {
							nState = CANCEL_STATE;
						} // Got confirmation
						break;

				} // Handle other cases
				break;

			default:
				nDirection = 0;
				if (confexit.DoModal() == IDOK) {
					nState = CANCEL_STATE;
				} // Got confirmation
				break;

		} // switch

		nState += nDirection;

	} // Not end of loop

	return 0;
}
