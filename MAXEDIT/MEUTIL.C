//  MEUTIL.C - MAXedit: printing, search, Save As, About, messages
//  (Win16 code of the SDK version MAXEDIT.C, Qualitas 1995-6, kept as it
//  was: it works on the edit control, wxTextWindow's, and uses the dialogs
//  of the resource script; the rest of MAXedit is MAXEDIT.CPP on
//  wxWindows).
//  Copyright (c) 1995-6 Qualitas, Inc.  GNU General Public License version 3.

#include "maxedit.h"
#include "commdlg.h"
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// defined in MAXEDIT.CPP's terms, set by it
PRINTDLG pd;			    /* Common print dialog structure */
HANDLE hInst;			    /* Program instance handle		     */
HWND hwndFrame		 = NULL;    /* Handle to main window		     */
HWND hwndActive 	 = NULL;    /* Handle to currently activated child   */
HWND hwndActiveEdit	 = NULL;    /* Handle to edit control		     */

BOOL FindBreak( LPSTR *lpStart, LPSTR *lpEnd, int nCount, char ch );

BOOL fAbort;		/* TRUE if the user has aborted the print job	 */
HWND hwndPDlg;		/* Handle to the cancel print dialog		 */
PSTR szTitle;		/* Global pointer to job title			 */
int FormatLine( HDC hDC, LPSTR szIn, WORD nInLen, LPSTR FAR *lpRetStr,
				    WORD nMaxPoints, WORD nTabs );

BOOL CALLBACK __export AboutDlgProc ( HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam )
{
	char szBuffer[256];

	switch (msg) {
	case WM_INITDIALOG:
		// Open 386MAX (GPL): no registration, show the license
		lstrcpy( szBuffer, "GNU General Public License version 3" );
		SetDlgItemText( hDlg, 102, szBuffer );
		return TRUE;

	case WM_COMMAND:

	    switch (LOWORD(wParam)) {
	    case IDOK:
		EndDialog(hDlg, TRUE);
		return TRUE;
	    }
	}

	return FALSE;
}


short CDECL MPError(HWND hwnd, WORD bFlags, WORD id, ...)
{
	char sz[160];
	char szFmt[128];

	LoadString (hInst, id, szFmt, sizeof (szFmt));
	wvsprintf (sz, szFmt, (LPSTR)(&id + 1));
	LoadString (hInst, IDS_APPNAME, szFmt, sizeof(szFmt) );

	return (MessageBox (hwndFrame, sz, szFmt, bFlags ));
}


/****************************************************************************
 *									    *
 *  FUNCTION   : QueryCloseAllChildren()				    *
 *									    *
 *  PURPOSE    : Asks the child windows if it is ok to close up app. Nothing*
 *		 is destroyed at this point. The z-order is not changed.    *
 *									    *
 *  RETURNS    : TRUE - If all children agree to the query.		    *
 *		 FALSE- If any one of them disagrees.			    *
 *									    *
 ****************************************************************************/


/****************************************************************************
 *  FUNCTION   : GetPrinterDC ()					    *
 *									    *
 *  PURPOSE    : Creates a printer display context for the printer	    *
 *									    *
 *  RETURNS    : HDC   - A handle to printer DC.			    *
 *									    *
 ****************************************************************************/
HDC PASCAL GetPrinterDC(void)
{
    HDC 	hDC;
    LPDEVMODE	lpDevMode = NULL;
    LPDEVNAMES	lpDevNames;
    LPSTR	lpszDriverName;
    LPSTR	lpszDeviceName;
    LPSTR	lpszPortName;

    if (!PrintDlg((LPPRINTDLG)&pd))
	return (NULL);

    if (pd.hDC)
	hDC = pd.hDC;

    else {

	if (!pd.hDevNames)
	    return(NULL);

	lpDevNames = (LPDEVNAMES)GlobalLock(pd.hDevNames);
	lpszDriverName = (LPSTR)lpDevNames + lpDevNames->wDriverOffset;
	lpszDeviceName = (LPSTR)lpDevNames + lpDevNames->wDeviceOffset;
	lpszPortName   = (LPSTR)lpDevNames + lpDevNames->wOutputOffset;
	GlobalUnlock(pd.hDevNames);

	if (pd.hDevMode)
	    lpDevMode = (LPDEVMODE)GlobalLock(pd.hDevMode);

	hDC = CreateDC(lpszDriverName, lpszDeviceName, lpszPortName, (LPSTR)lpDevMode);

	if (pd.hDevMode && lpDevMode)
	    GlobalUnlock(pd.hDevMode);
      }

#if 0
    if (pd.hDevNames) {
	GlobalFree(pd.hDevNames);
	pd.hDevNames = 0;
    }

    if (pd.hDevMode) {
	GlobalFree(pd.hDevMode);
	pd.hDevMode = 0;
    }
#endif

    return(hDC);
}


/****************************************************************************
 *									    *
 *  FUNCTION   : AbortProc()						    *
 *									    *
 *  PURPOSE    : To be called by GDI print code to check for user abort.    *
 *									    *
 ****************************************************************************/
int FAR PASCAL __export AbortProc ( HDC hdc, WORD reserved )
{
    MSG msg;

    /* Allow other apps to run, or get abort messages */
    while (!fAbort && PeekMessage (&msg, NULL, NULL, NULL, TRUE))
	if (!hwndPDlg || !IsDialogMessage (hwndPDlg, &msg)) {
	    TranslateMessage (&msg);
	    DispatchMessage  (&msg);
	}

    return !fAbort;
}

/****************************************************************************
 *									    *
 *  FUNCTION   : PrintDlgProc ()					    *
 *									    *
 *  PURPOSE    : Dialog function for the print cancel dialog box.	    *
 *									    *
 *  RETURNS    : TRUE  - OK to abort/ not OK to abort			    *
 *		 FALSE - otherwise.					    *
 *									    *
 ****************************************************************************/
BOOL FAR PASCAL __export PrintDlgProc(HWND hwnd, WORD msg, WORD wParam, LONG lParam)
{
	if (msg == WM_COMMAND) {
		/* abort printing if the only button gets hit */
		fAbort = TRUE;
		return TRUE;
	}

	return FALSE;
}


/****************************************************************************
 *									    *
 *  FUNCTION   : PrintFile ()						    *
 *									    *
 *  PURPOSE    : Prints the contents of the edit control.		    *
 *									    *
 ****************************************************************************/
#define MAXFMTLINES 120
#define MAXCHARSCAN 20
#define PRTLINEBUFLEN 511

VOID PASCAL PrintFile( HWND hwnd, HWND hwndEdit )
    {
    TEXTMETRIC tm;
    HDC     hdc;
    WORD    i;
    int     yExtPage;
    int     xExtPage;
    int     yExtSoFar;
    WORD    cch;
    WORD    iLine;
    WORD    nLinesEc;
    WORD    nRLines;
    DOCINFO di;
    ABORTPROC lpfnAbort;
    FARPROC lpfnPDlg;
    WORD    dy;
    WORD    fError = TRUE;
    char    sz[32], szLine[ PRTLINEBUFLEN + 1];
    LPSTR   lpRetStr;
    LPSTR   lpNext;
    int     nLineLen;
    int     aTabs[2];
    int     nTS = 1;

#if defined(_WIN32) || defined(__WIN32__)
    SIZE sizeRect;
#endif


    /* Create the job title by loading the title string from STRINGTABLE */
    cch = LoadString (hInst, IDS_PRINTJOB, sz, sizeof(sz));
    szTitle = sz + cch;
    cch += GetWindowText (hwnd, sz + cch, 32 - cch);
    sz[31] = 0;

    di.cbSize = sizeof( DOCINFO );
    di.lpszDocName = sz;
    di.lpszOutput = NULL;


	// Make instances of the Abort proc. and the Print dialog function.
    lpfnAbort = MakeProcInstance( (FARPROC)AbortProc, hInst );
    if (!lpfnAbort)
	{
	goto getout;
	}
    lpfnPDlg = MakeProcInstance( (FARPROC)PrintDlgProc, hInst );
    if (!lpfnPDlg)
	{
	goto getout4;
	}

	// Initialize the printer
    hdc = GetPrinterDC( );
    if (!hdc)
	{
	fError = FALSE;
	goto getout5;
	}

	// get the average char width.
    GetTextMetrics( hdc, &tm );
    aTabs[0] = tm.tmAveCharWidth * 10;
    aTabs[1] = aTabs[0] * 2;

	//Disable the main application window and create the Cancel dialog.
    EnableWindow (hwnd, FALSE);
    hwndPDlg = CreateDialog ( hInst, MAKEINTRESOURCE(IDD_PRINT), hwnd, (DLGPROC)lpfnPDlg);
    if (!hwndPDlg)
	{
	goto getout3;
	}
    ShowWindow (hwndPDlg, SW_SHOW);
    UpdateWindow (hwndPDlg);

	// Allow the app. to inform GDI of the escape function to call.
    if( SetAbortProc( hdc, lpfnAbort ) < 0)
	{
	goto getout3;
	}

	// Initialize the document.
    if( StartDoc( hdc, &di ) == SP_ERROR )
	{
	goto getout3;
	}

	// Get the height of one line and the height of a page.
#if defined(_WIN32) || defined(__WIN32__)
    GetTextExtentPoint( hdc, "CC", 2 , &sizeRect );
    dy = (WORD)sizeRect.cy;
#else
    dy = HIWORD (GetTextExtent (hdc, "CC", 2));
#endif

    yExtPage = GetDeviceCaps (hdc, VERTRES);
    xExtPage = GetDeviceCaps (hdc, HORZRES);

	// Get the lines in document and and a handle to the text buffer.
    iLine     = 0;
    yExtSoFar = 0;
    nLinesEc  = (WORD)SendMessage (hwndEdit, EM_GETLINECOUNT, 0, 0L);

    if( nLinesEc <= 0 )
	{
	goto getout3;
	}

    if( StartPage( hdc ) < 0 )
	{
	goto getout2;
	}

	// While more lines print out the text.
    while( iLine < nLinesEc )
	{
	    /* Get the length and position of the line in the buffer */
	*((WORD *)&szLine[0]) = PRTLINEBUFLEN;
	cch = (WORD)SendMessage( hwndEdit, EM_GETLINE, iLine, (LPARAM)(LPSTR)szLine );
	szLine[cch] = '\0';

	    // this should return a double null terminated list of strings.
	nRLines = FormatLine( hdc, szLine, lstrlen( szLine ), &lpRetStr, xExtPage, 10 );
	lpNext = lpRetStr;

	for( i=0; i < nRLines; i++ )
	    {
	    nLineLen = lstrlen( lpNext );
	    if (yExtSoFar + (int)dy > yExtPage)
		{
			// Reached the end of a page.
			// Tell the device driver to eject a page
		if ( ( EndPage( hdc ) < 0) || fAbort)
		    {
		    goto getout2;
		    }

		if( StartPage( hdc ) < 0 )
		    {
		    goto getout2;
		    }
		yExtSoFar = 0;
		}

		// Print the line.
	    TabbedTextOut (hdc, 0, yExtSoFar, (LPSTR)lpNext, nLineLen,
			   nTS, aTabs, 0 );

		// Test and see if the Abort flag has been set. If yes, exit.
	    if (fAbort)
		{
		goto getout2;
		}

		// Move down the page.
	    yExtSoFar += dy;

	    if( (i+1) < nRLines )
		{
		    // point to the next line.
		lpNext += (nLineLen + 1);
		}
	    }

	if( lpRetStr != NULL )
	    {
	    _ffree( lpRetStr );
	    lpRetStr = NULL;
	    }

	    // increment the index of lines in the edit control.
	iLine++;
	} // end while.

	// Eject the last page.
    if( EndPage( hdc ) < 0)
	{
	goto getout2;
	}

	// Complete the document.
    if( EndDoc( hdc ) < 0)
	{
getout2:
	    // Ran into a problem before NEWFRAME? Abort the document.
	AbortDoc( hdc );
	}
    else
	{
	fError=FALSE;
	}

getout3:
	    // Close the cancel dialog and re-enable main app. window.
    EnableWindow ( hwnd, TRUE);
    DestroyWindow (hwndPDlg);
    hwndPDlg = NULL;
    DeleteDC(hdc);

getout5:
	    // Get rid of dialog procedure instances.
    FreeProcInstance (lpfnPDlg);

getout4:
    FreeProcInstance (lpfnAbort);

getout:
    /* Error? make sure the user knows... */
    if (fError)
	MPError (hwnd, MB_OK | MB_ICONEXCLAMATION, IDS_PRINTERROR, (LPSTR)szTitle);
    }

//------------------------------------------------------------------
// search for end of line chars...changes *lpEnd if found.
//------------------------------------------------------------------
BOOL FindBreak( LPSTR *lpStart, LPSTR *lpEnd, int nCount, char ch )
    {
    LPSTR lpScan;
    int t;

    for( t = 0, lpScan = (*lpEnd) ;
	(lpScan > (*lpStart) ) && (t < nCount ) ;
	t++, lpScan-- )
	{
	if( *lpScan == ch )
	    {
	    *lpEnd = lpScan;
	    return TRUE;
	    }
	}
    return FALSE;
    }

//------------------------------------------------------------------
int FormatLine( HDC hDC, LPSTR szIn, WORD nInLen, LPSTR FAR *lpRetStr,
				    WORD nMaxPoints, WORD nTabs )
    {
    WORD i;
    static int aTabs[2];
    int nRetLines;
    int nTabCount;
    int nCurLen;
    LPSTR lpBuff;
    LPSTR lpStart;
    LPSTR lpNew;
    LPSTR lpEnd;
    WORD nLTabs;
    WORD nOutLen;
    WORD xPointLen;
    TEXTMETRIC tm;

	// count tabs.
    for( i = 0, nTabCount = 0; i < nInLen; i++ )
	{
	if( szIn[i] == '\t' )
	    {
	    nTabCount++;
	    }
	}

    nLTabs = ( nTabs > 1 ) ? nTabs : 1;

	// calculate a buffer long enough to expand.
    nOutLen = nInLen + MAXFMTLINES + 8;

	// make a buffer.
    if(( lpBuff = (LPSTR)_fmalloc( nOutLen )) == NULL )
	{
	return 0;
	}

    *lpRetStr = lpBuff;

    _fstrcpy( lpBuff, szIn );

	// get the average char width.
    GetTextMetrics( hDC, &tm );
    aTabs[0] = tm.tmAveCharWidth * 10;
    aTabs[1] = aTabs[0] * 2;

	// get the string width
    xPointLen = LOWORD(GetTabbedTextExtent( hDC, lpBuff, lstrlen(lpBuff), 1, aTabs ));

	// skip the calculations if we don't need them.
    if( xPointLen < nMaxPoints )
	{
	nRetLines = 1;
	return nRetLines;
	}

	// if we got here, We must break up the line.
    for( lpNew = lpBuff, nRetLines = 1; ; nRetLines++)
	{
	    // don't exceed the buffer limit.
	if( nRetLines > MAXFMTLINES )
	    {
	    break;
	    }

	lpStart = lpNew;

	    // point to the null.
	nCurLen = lstrlen( lpStart ) + 1;
	lpEnd = lpStart + nCurLen;

	// get the string width
	xPointLen = LOWORD(GetTabbedTextExtent( hDC, lpBuff, nCurLen, 1, aTabs ));
	if( xPointLen < nMaxPoints )
	    {
		// a double null finishes it off.
	    *lpEnd++ = '\0';
	    *lpEnd = '\0';
	    return nRetLines;
	    }

	nCurLen = (int)(nMaxPoints / tm.tmAveCharWidth);

	    // find the maximum last character.
	do
	    {
	    xPointLen = LOWORD(GetTabbedTextExtent( hDC, lpStart, nCurLen, 1, aTabs ));
	    if( xPointLen >= nMaxPoints )
		{
		nCurLen--;
		}
	    } while( xPointLen > nMaxPoints );

	    // set the result as the end for now.
	lpEnd = lpStart + nCurLen;

	    // look for spaces
	if (!FindBreak( &lpStart, &lpEnd, MAXCHARSCAN, ' ' ))
	    {
		// look for semicolons
	    FindBreak( &lpStart, &lpEnd, MAXCHARSCAN, ';' );
	    }

	    // skip over the null to the next character.
	lpNew = lpEnd + 2;

	    // move the buffer down...including the null.
	_fmemmove( lpNew, lpEnd+1, lstrlen( lpEnd + 1) + 1 );
	    // terminate the first line.
	*(lpEnd + 1) = '\0';
	}

    return nRetLines;
    }


/****************************************************************************
 *									    *
 *  FUNCTION   : AlreadyOpen(szFile)					    *
 *									    *
 *  PURPOSE    : Checks to see if the file described by the string pointed  *
 *		 to by 'szFile' is already open.                            *
 *									    *
 *  RETURNS    : a handle to the described file's window if that file is    *
 *		 already open;	NULL otherwise. 			    *
 *									    *
 ****************************************************************************/


BOOL PASCAL ChangeFile ( HWND hwnd, BOOL fUntitled )
{
    char    szFile[128];
    OPENFILENAME of;

    if (fUntitled)
	lstrcpy(szFile, "*.INI");
    else
	GetWindowText(hwnd, szFile, 128);

    of.lStructSize  = sizeof(OPENFILENAME);
    of.hwndOwner    = hwnd;
    of.lpstrFilter  = (LPSTR)"INI Files (*.INI)\0*.INI\0Profile Files (*.PRO)\0*.PRO\0All Files (*.*)\0*.*\0";
    of.lpstrCustomFilter = NULL;
    of.nFilterIndex = 1;
    of.lpstrFile    = (LPSTR)szFile;
    of.nMaxFile     = 128;
    of.lpstrInitialDir = NULL;
    of.lpstrTitle   = NULL;
    of.Flags	    = OFN_HIDEREADONLY;
    of.lpstrDefExt  = NULL;
    of.lpstrFileTitle	= NULL;

    if (!GetSaveFileName( &of ))
       return FALSE;

    SetWindowText( hwnd, szFile );

    return TRUE;
}


#undef HIWORD
#undef LOWORD

#define HIWORD(l) (((WORD*)&(l))[1])
#define LOWORD(l) (((WORD*)&(l))[0])

BOOL fCase	   = FALSE;    /* Turn case sensitivity off */
char szSearch[160] = "";       /* Initialize search string  */

/****************************************************************************
 *									    *
 *  FUNCTION   : RealSlowCompare ()					    *
 *									    *
 *  PURPOSE    : Compares subject string with the target string. This fn/   *
 *		 is called repeatedly so that all substrings are compared,  *
 *		 which makes it O(n ** 2), hence it's name.                 *
 *									    *
 *  RETURNS    : TRUE  - If pSubject is identical to pTarget.		    *
 *		 FALSE - otherwise.					    *
 *									    *
 ****************************************************************************/

BOOL PASCAL RealSlowCompare ( LPSTR pSubject, LPSTR pTarget )
{
    if (fCase) {
	while (*pTarget)
	    if (*pTarget++ != *pSubject++)
		return FALSE;
    } else {
	/* If case-insensitive, convert both subject and target to lowercase
	 * before comparing. */
	AnsiLower ((LPSTR)pTarget);
	while (*pTarget)
	    if (*pTarget++ != (char)(DWORD)AnsiLower ((LPSTR)(DWORD)(BYTE)*pSubject++))
		return FALSE;
    }

    return TRUE;
}


/****************************************************************************
 *									    *
 *  FUNCTION   : MyFindText ()						    *
 *									    *
 *  PURPOSE    : Finds the search string in the active window according to  *
 *		 search direction (dch) specified ( -1 for reverse and 1 for*
 *		 forward searches).					    *
 *									    *
 ****************************************************************************/

VOID PASCAL MyFindText( register int dch )
{
    LPSTR pText;
    LONG l;
    WORD cch;
    int i;
    HGLOBAL hGlobal;

    if (!*szSearch)
	return;

    /* Find the current selection range */
    l = (int)SendMessage(hwndActiveEdit, EM_GETSEL, 0, 0L);

    /* Get the length of the text */
    cch = (WORD)SendMessage (hwndActiveEdit, WM_GETTEXTLENGTH, 0, 0L);

    hGlobal = GlobalAlloc( GMEM_MOVEABLE | GMEM_ZEROINIT, cch );
    pText = GlobalLock( hGlobal );
    SendMessage( hwndActiveEdit, WM_GETTEXT, cch, (LPARAM)pText );

    /* Start with the next char. in selected range ... */
    pText += LOWORD (l) + dch;

    /* Compute how many characters are before/after the current selection */
    if (dch < 0)
	i = LOWORD (l);
    else
	i = cch - LOWORD (l) + 1 - lstrlen (szSearch);

    /* While there are uncompared substrings... */
    while ( i > 0) {

	LOWORD(l) += dch;

	/* Does this substring match? */
	if (RealSlowCompare(pText, szSearch)) {

	    /* Yes, unlock the buffer.*/
	    GlobalUnlock( hGlobal );
	    GlobalFree( hGlobal );

	    /* Select the located string */
	    HIWORD(l) = LOWORD(l) + lstrlen (szSearch);
	    SendMessage (hwndActiveEdit, EM_SETSEL, 0, l);
	    return;
	}
	i--;

	/* increment/decrement start position by 1 */
	pText += dch;
    }

    /* Not found... unlock buffer. */
    GlobalUnlock ( hGlobal );
    GlobalFree( hGlobal );

    /* Give a message */
    MPError (hwndFrame, MB_OK | MB_ICONEXCLAMATION, IDS_CANTFIND, (LPSTR)szSearch);
}


/****************************************************************************
 *									    *
 *  FUNCTION   : FindPrev ()						    *
 *									    *
 *  PURPOSE    : Finds the previous occurence of the search string. Calls   *
 *		 MyFindText () with a negative search direction.		    *
 *									    *
 ****************************************************************************/

VOID PASCAL FindPrev(void)
{
	MyFindText(-1);
}


/****************************************************************************
 *									    *
 *  FUNCTION   : FindNext ()						    *
 *									    *
 *  PURPOSE    : Finds the next occurence of search string. Calls	    *
 *		 MyFindText () with a positive search direction.		    *
 *									    *
 ****************************************************************************/

VOID PASCAL FindNext(void)
{
	MyFindText(1);
}


/****************************************************************************
 *									    *
 *  FUNCTION   : FindDlgProc(hwnd, message, wParam, lParam)		    *
 *									    *
 *  PURPOSE    : Dialog function for the Search/Find command. Prompts user  *
 *		 for target string, case flag and search direction.	    *
 *									    *
 ****************************************************************************/

BOOL FAR PASCAL FindDlgProc(HWND hwnd, WORD msg, WORD wParam, LONG lParam)
{
	switch (msg){
	case WM_INITDIALOG:{

	    /* Check/uncheck case button */
	    CheckDlgButton (hwnd, IDD_CASE, fCase);

	    /* Set default search string to most recently searched string */
	    SetDlgItemText (hwnd, IDD_SEARCH, szSearch);

	    /* Allow search only if target is nonempty */
	    if (!lstrlen (szSearch)){
		EnableWindow (GetDlgItem (hwnd, IDOK), FALSE);
		EnableWindow (GetDlgItem (hwnd, IDD_PREV), FALSE);
	    }
	    break;
	}

	case WM_COMMAND:{

	    /* Search forward by default (see IDOK below) */
	    int i = 1;

	    switch (wParam){
		/* if the search target becomes non-empty, enable searching */
		case IDD_SEARCH:
		    if (HIWORD (lParam) == EN_CHANGE){
			if (!(WORD) SendDlgItemMessage (hwnd,
				IDD_SEARCH, WM_GETTEXTLENGTH, 0, 0L))
			    i = FALSE;
			else
			    i = TRUE;
			EnableWindow (GetDlgItem (hwnd, IDOK), i);
			EnableWindow (GetDlgItem (hwnd, IDD_PREV), i);
		    }
		    break;

		case IDD_CASE:
		    /* Toggle state of case button */
		    CheckDlgButton (hwnd, IDD_CASE, !IsDlgButtonChecked (hwnd, IDD_CASE));
		    break;

		case IDD_PREV:
		    // Set direction to backwards
		    i = -1;
		    /*** FALL THRU ***/

		case IDOK:
		    /* Save case selection */
		    fCase = IsDlgButtonChecked( hwnd, IDD_CASE );

		    /* Get search string */
		    GetDlgItemText (hwnd, IDD_SEARCH, szSearch, sizeof (szSearch));

		    /* Find the text */
		    MyFindText (i);
		    /*** FALL THRU ***/

		/* End the dialog */
		case IDCANCEL:
		    EndDialog ( hwnd, 0 );
		    break;

		default:
		    return FALSE;
	    }
	    break;
	}
	default:
	    return FALSE;
	}

	return TRUE;
}


/****************************************************************************
 *									    *
 *  FUNCTION   : Find() 						    *
 *									    *
 *  PURPOSE    : Invokes the Search/Find dialog.			    *
 *									    *
 ****************************************************************************/

VOID PASCAL Find( void )
{
	FARPROC lpfn;

	lpfn = MakeProcInstance ( FindDlgProc, hInst );
	DialogBox ( hInst, IDD_FIND, hwndFrame, lpfn );
	FreeProcInstance ( lpfn );
}

