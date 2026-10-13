/******************************************************************************
 *									      *
 * (C) Copyright 1991-96 Qualitas, Inc.  GNU General Public License version 3. *
 *									      *
 * QSHPRINT.C								      *
 *									      *
 * MAX shell printer routines.  Reconstructed for Open 386MAX from the	      *
 * original MAX.EXE; based on ASQPRINT.C.				      *
 *									      *
 ******************************************************************************/

/*	Standard C includes */
#include <bios.h>
#include <ctype.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
#include <help.h>

/*	Program includes */

#include "asqshare.h"
#include "commfunc.h"
#include "button.h"
#include "editwin.h"
#include "libcolor.h"
#include "libtext.h"
#include "qprint.h"
#include "qhelp.h"
#include "inthelp.h"
#include "qwindows.h"
#include "qshtext.h"
#include "qshell.h"
#include "ui.h"
#include "myalloc.h"

/*	Definitions for this Module */
#define EDITOROK

#define PRINTDONE -1
#define PRINTER_PROBLEM 0x29
#define PRINTFILEERROR( prtOut ) (errorMessage( ferror( prtOut )+200 ))
#define MAXPRINTLINE 256

static FILE *prtOut;
static int pageNumber;
static int lineNumber;
static char timeString[32];
static void *saveBehind;
static WINDESC printingWin;


int dumpLine( char *line, PRINTTITLETYPE type);
int doHeader( PRINTTITLETYPE type );
int myPrint( char out );

int printHelp( int context, int followLinks, PRINTTITLETYPE type	);
int printAllHelp( int context, PRINTTITLETYPE type	);
int printEditor( PRINTTITLETYPE type );
int printWindow( PTEXTWIN pWin, PRINTTITLETYPE type, int which );
int printAllQShellData( void );
int printInfo( int id, int first );
int printFile( char *name );
int printTitle( char *title, int type );

void killPrinting( void );
void sayPage( void );
void sayPrinting( void );

/**
*
* Name		doPrintCallBack
*
* Synopsis	void doPrintCallBack( PTEXTWIN pWin, PRINTTYPE type, int which, int HelpNum)
*
* Parameters
*			PTEXTWIN pWin;			Pointer to the current text window
*			PRINTTYPE type; 		What type of window this is
*			int HelpNum,			What help number this is
*			int which;				which window in a given type
*
* Description
*		This routine does that actual printing
*
* Returns	TRUE -> there was an error
*			FALSE -> everything ok
*
* Version	1.0
*/

#pragma optimize ("leg",off)
int doPrintCallback(			/*	Do all printing */
	PTEXTWIN pWin,			/*	Pointer to the current text window */
	PRINTTYPE type, 		/*	What type of window this is */
	int which,				/*	which window in a given type */
	int HelpNum)			/*	What help number this is */
{
	int errorOut = FALSE;

	/*
	*	First set up the print destionation and set up the printer
	*/
	lineNumber = pageNumber = 1;

	/*	first set up the output device as appropriate */
	if( WherePrintList.items[0].state.checked )
	{
#ifndef OS2_VERSION
		int result = _bios_printer( _PRINTER_STATUS, 0, 0 );			/*	initialize the printer PRN: */
		if( result & PRINTER_PROBLEM )
		{
			errorMessage( prerror(result) );
			return TRUE;
		}
#endif
	} else
	{
		prtOut = fopen( PrintFile,
				WherePrintList.items[1].state.checked ? "wt" : "at" );
		if( (prtOut == NULL) || (ferror( prtOut )) )
		{
			PRINTFILEERROR( prtOut );
			return TRUE;
		}

	}
	sayPrinting( );

	switch( type ) {
	case P_EDITOR:
#ifdef EDITOROK
		if( P_Editor.items[0].state.checked ) {
			/*	Print the current editor file */
			if( pWin )
				errorOut = printEditor( PRINTTYPEFILE );
			else {
				char *name;
				switch( which ) {
				case QS_EDITCFG:
					name = ConfigName;
					break;
				case QS_EDITAUT:
					name = AutoexecName;
					break;
				case QS_EDITPRO:
					name = MAXName;
					break;
				}
				errorOut = printFile( name );
			}
		}
		if( !errorOut && P_Editor.items[1].state.checked ) {
			/*	Print all the editor help topics */
			errorOut = printHelp( HELPEDITOR, TRUE, PRINTTYPEHELP );
		}
		if( !errorOut && P_Editor.items[2].state.checked ) {
			/*	Print all the help topics */
			errorOut = printAllHelp( helpSystem, PRINTTYPEHELP );
		}
#endif
		break;
	case P_HELP:
		if( P_Help.items[0].state.checked ) {
			/*	Print the current Help selection */
			if( pWin )
				errorOut = printWindow( pWin, PRINTTYPEHELP, which );
			else
				errorOut = printHelp( HelpNum, FALSE, PRINTTYPEHELP );

		}
		if( !errorOut && P_Help.items[1].state.checked ) {
			/*	Print all the help topics */
			errorOut = printAllHelp( helpSystem, PRINTTYPEHELP );
		}
		break;
	case P_QMENU:
	case P_MENU:
		if( P_Menu.items[0].state.checked ) {
			/*	Print the current data item	*/
			if( pWin )
				/*	We were in data window so that is valid */
				errorOut = printWindow( pWin, PRINTTYPEANALYSIS,which );
			else
				/*	Here we have to menu return code */
				/*	Solve this by forcing menu return code to match info request */
				errorOut = printInfo( which, TRUE );
		}
		if( !errorOut && P_Menu.items[1].state.checked ) {
			/*	Print all the data items */
			errorOut = printAllQShellData();
		}
		if( !errorOut && P_Menu.items[2].state.checked ) {
			/*	Print the current help topic for this item */
			switch( which ) {
			case QS_MEMSUM: HelpNum = HELP_Mem_Sum; break;
			case QS_CFGSUM: HelpNum = HELP_Cfg_Sum; break;
			case QS_HDWSUM: HelpNum = HELP_Hdw_Sum; break;
			}
			errorOut = printHelp( HelpNum, FALSE, PRINTTYPEHELP );
		}
		if( !errorOut && P_Menu.items[3].state.checked ) {
			/*	Print all the help topics */
			errorOut = printAllHelp( helpSystem, PRINTTYPEHELP );
		}
		break;
	case P_BROWSER:
#ifdef EDITOROK
		if( P_Browser.items[0].state.checked ) {
			/*	Print the current editor file */
			if( pWin )
				errorOut = printEditor( PRINTTYPEFILE );
			else {
				char *name;
				switch( which ) {
				case QS_EDITCFG:
					name = ConfigName;
					break;
				case QS_EDITAUT:
					name = AutoexecName;
					break;
				case QS_EDITPRO:
					name = MAXName;
					break;
				}
				errorOut = printFile( name );
			}
		}
		if( !errorOut && P_Browser.items[1].state.checked ) {
			/*	Print all the Browser help topics */
			errorOut = printHelp( HELPEDITOR, TRUE, PRINTTYPEHELP );
		}
		if( !errorOut && P_Browser.items[2].state.checked ) {
			/*	Print all the help topics */
			errorOut = printAllHelp( helpSystem, PRINTTYPEHELP );
		}
#endif
		break;
	case P_OEDITOR:
#ifdef EDITOROK
		if( !errorOut && P_OEditor.items[0].state.checked ) {
			/*	Print all the editor help topics */
			errorOut = printHelp( HELPEDITOR, TRUE, PRINTTYPEHELP );
		}
		if( !errorOut && P_OEditor.items[1].state.checked ) {
			/*	Print all the help topics */
			errorOut = printAllHelp( helpSystem, PRINTTYPEHELP );
		}
#endif
		break;
	}
	/*	Always dump out a trailing form feed */
	if( !errorOut )
	{
		char outline[2];
		outline[0] = '\f';
		outline[1] = '\0';
		dumpLine( outline, PRINTTYPENONE );
	}

	/*	Now close out result file as approp */
	if( !WherePrintList.items[0].state.checked )
	{
		int result = fclose( prtOut );
		if( result == EOF || ferror( prtOut ))
		{
			PRINTFILEERROR(prtOut);
			return TRUE;
		}
	}

	killPrinting();

	return FALSE;

}
#pragma optimize ("",on)


void killPrinting( void )
{

	visible_mouse (0); // Only show mouse when getting input
	restoreButtons( );
	if( saveBehind ) {
		win_restore( saveBehind, TRUE );
	}
	pop_cursor();
}

void sayPage( void )
{
	char pMessage[20];

	sprintf( pMessage, Printing, pageNumber );
	wrapString( &printingWin, pMessage, &ErrorColor );

}


void sayPrinting( void )
{
	push_cursor();
	hide_cursor();

	printingWin.row = (ScreenSize.row - 1 - 6) / 2;
	printingWin.col = (ScreenSize.col - MAXMESSAGEWIDTH ) / 2;
	printingWin.nrows = 6;
	printingWin.ncols = MAXMESSAGEWIDTH;

	saveBehind = win_save( &printingWin, TRUE );
	if( !saveBehind ) {
		pop_cursor();
		goto SAYPRINT_RETURN;
	}

	if( saveButtons() != BUTTON_OK ) {
		my_free( saveBehind );
		pop_cursor();
		goto SAYPRINT_RETURN;
	}

	wput_sca( &printingWin, VIDWORD( ErrorColor, ' ' ));
	shadowWindow( &printingWin );
	box( &printingWin, BOX_DOUBLE, TypeMessage[ERRTYPE_MESSAGE], NULL, ErrorColor );

	/*	Adjust the window inside the box */
	printingWin.row++;
	printingWin.col += 2;
	printingWin.nrows -= 2;
	printingWin.ncols -= 4;

	sayPage();

	PrintingButtons[0].pos.row = printingWin.row + printingWin.nrows - 2;
	PrintingButtons[0].pos.col = ( ScreenSize.col - MAXBUTTONTEXT ) / 2;

	addButton( PrintingButtons, NUMPRINTINGBUTTONS, NULL );
	showAllButtons();
	setButtonFocus( TRUE, KEY_TAB );

SAYPRINT_RETURN:
	visible_mouse (1); // Leave mouse cursor on constantly

} // sayPrinting ()


/**
*
* Name		dumpLine - Print this line to the currently selected out device
*
* Synopsis	void dumpLine( char *line, PRINTTITLETYPE type )
*
* Parameters
*			char *line - Line to transform and dump
*		PRINTTITLETYPE type - PRINTTYPEANALYSIS
*						 PRINTTYPEHELP
*						 PRINTTYPETUTORIAL
*
* Description
*		Given this display line, transform it to all printable characters
*	and shove it out the selected print device.
*	If line == NULL then just dump a blank line
*
*
* Returns	TRUE == SUCCESS  FALSE == FAILED
*
*
* Version	2.0
*
*	Changed to always return value;
*
**/
#pragma optimize ("leg",off)
int dumpLine( char *line, PRINTTITLETYPE type)
{
	char outline[256];
	char *current = line;
	char *out = outline;
	INPUTEVENT event;
	int result;

	/*	Test keyboard for an event */
	if( get_input( 0, &event) ) {
		if( event.key ) {
			if( testButton( event.key, TRUE ) != BUTTON_NOOP)
				return FALSE;
		} else {
			if( testButtonClick( &event, TRUE ) )
				return FALSE;
		}
	}

	if( lineNumber >= 59 )
	{
		if( !doHeader( type ) ) return FALSE;
	}
	else
		lineNumber++;

	if( line )
	{
		/*	Do the character transform */
		while ( *current)
		{
			switch( *current )
			{
			case '\x01':
				*(out++) = ' ';                 /*      continuation line character */
				break;
			case '\x04':
				*(out++) = '*';                 /*      Diamond character */
				break;
			case '\x11':                            /*      Enter key */
				while (*current && *(++current) != '\xD9');
				strcpy( out, Enter);
				out += sizeof(Enter) - 1;
				break;
			case '\x18':                            /*      Up down arrows - SPecial */
				while (*current && *(++current) != '\x19');
				strcpy( out, Arrows);
				out += sizeof(Arrows)-1;
				break;
			case '\x19':
				*(out++) = 'v';                         /*      Down arrow in memory help */
				break;
			case '\xB0':
				*(out++) = 'F';                         /*      Frame EMS Usage */
				break;
			case '\xB1':
				*(out++) = 'X';                         /*      Mottled Bar */
				break;
			case '\xB2':
				*(out++) = 'D';                         /*      Dos Bar */
				break;
			case '\xB3':                                    /*      Vertical */
			case '\xB4':                                    /*      Box joint left */
			case '\xBA':                                    /*      Double Vertical Bar */
			case '\xC3':                                    /*      Box joint right */
				*(out++) = '|';
				break;
			case '\xBF':                                    /*      Box upper Right */
			case '\xC0':                                    /*      Box lower left */
			case '\xC1':                                    /*      Box joint bottom */
			case '\xC2':                                    /*      Box joint top */
			case '\xC4':                                    /*      horizontal */
			case '\xCD':
			case '\xD9':                                    /*      Box upper left */
			case '\xDA':                                    /*      Box upper left */
				*(out++) = '-';
				break;
			case '\xB5':
			case '\xB8':
			case '\xBE':
			case '\xC5':
			case '\xC6':
			case '\xCF':
			case '\xD4':
			case '\xD5':
				*(out++) = '+';
				break;
			case '\xDB':
				*(out++) = '#';                 /*      DOS EMS Usage */
				break;
			case '\xDC':
				*(out++) = '*';                         /*      Timing */
				break;
			case '\xE6':
				*(out++) = 'u';                         /*      Millisecond speed ratio */
				break;
			case '\xFB':
				*(out++) = 'X';                         /*      Check Mark */
				break;
			case '\xFE':
				*(out++) = 'R';                         /*      ROM EMS Usage */
				break;
			case '\xE8':
				*(out++) = 'r';                         /*      RAM EMS Usage */
				break;
			case '\xF7':
				*(out++) = 'V';                         /*      Video EMS Usage */
				break;
			default:
				*(out++) = *current;
				break;
			}
			current++;
		}

		*out = '\0';    /*      Terminate the string */
	} else
		outline[0] = '\0';

	trnbln(outline);
	if( WherePrintList.items[0].state.checked ) {
		out = outline;
		while(*out)
		{
			if( !myPrint( *out ) ) return FALSE;
			out++;
		}

		/*	Now carriage return linefeed pair */
		if( !myPrint( '\r' )) return FALSE;
		if( !myPrint( '\n' )) return FALSE;
	} else {
		result = fputs( outline, prtOut );
		if( result == EOF || ferror( prtOut ))
		{
			PRINTFILEERROR( prtOut );
			return FALSE;
		}
		result = fputc( '\n', prtOut );
		if( result == EOF || ferror( prtOut ))
		{
			PRINTFILEERROR( prtOut );
			return FALSE;
		}
	}
	return TRUE;
}
#pragma optimize ("",off)


/**
*
* Name		myPrint - Print a character - Handle errors
*
* Synopsis	int myPrint( char out )
*
* Parameters
*			char out - Character to be printed
*
* Description
*		This routine dumps a character to the printer and handles
*	all errors
*
*
* Returns	FALSE == Failure
*
*
* Version	1.10
*
**/
int myPrint( char out )
{
	int result;
	unsigned long timeOut;
	time(&timeOut);
	timeOut += 60;

	result = 1;
	while ( result & 1 )
	{
#ifdef OS2_VERSION
		if( out );
		result = 0;
#else
		result = _bios_printer( _PRINTER_WRITE, 0, out );
#endif
		if( (unsigned long)time(NULL) > timeOut ) break;
	}

	if( result & PRINTER_PROBLEM )
	{
		result = prerror( result );
		errorMessage( result );
		return FALSE;
	}

	return TRUE;
}

/**
*
* Name		doHeader - Print the title lines for output
*
* Synopsis	int doHeader( PRINTTITLETYPE type )
*
* Parameters
*		PRINTTITLETYPE type - PRINTTYPEANALYSIS
*						 PRINTTYPEHELP
*						 PRINTTYPETUTORIAL
*
* Description
*		This routine dumps the propganda and page number at the
*	top of the page and also the page number
*
*
* Returns	FALSE == Failure
*
*
* Version	2.0
*
***** Change for version 1.10 - Add Print Type
**/
int doHeader( PRINTTITLETYPE type )
{
	char outline[81];
	int titleLen = sizeof( PRINTPAGETITLE)-1;

	lineNumber = 1;

	sayPage();

	if(pageNumber > 1 )
	{
		outline[0] = '\f';
		outline[1] = '\0';
		if(!dumpLine( outline, type )) return FALSE;
	} else
	{
		time_t aclock;

		/*	Get printout time */
		time(&aclock);
		timedatefmt (&aclock, timeString, 2, 1);

	}

	memset( outline, ' ', sizeof(outline));
	strcpy( outline, PrintProgramName+1 );
	memcpy( outline+strlen( PrintProgramName )-1, PrintPageTitle, titleLen);	/* Kill leading space */
	/*
	****  Change for 1.10 to add titleLen stuff
	*/
	if( type != PRINTTYPENONE )
		memcpy( outline+25, PRINTTYPETEXT[type], strlen(PRINTTYPETEXT[type]));
	sprintf( outline+72, PrintPage, pageNumber);
	pageNumber++;
	memcpy( outline+40, timeString, 25 );
	if( !dumpLine( outline, type ) ) return FALSE;

	memset( outline, '-', sizeof(outline)-1 );
	outline[ sizeof(outline )] = '\0';

	return dumpLine( outline, type );
}

/**
*
* Name		printHelp - Print a series of help blocks
*
* Description
*		walk help to the beginning of the series of topics and follow to
*	the end.  If followlinks false, just print this context.
*
* Returns	FALSE == Success
**/
int printHelp(			/*	Print help information */
	int context,		/*	Where to start */
	int followLinks,	/*	Find first in series and print series? */
	PRINTTITLETYPE type )			/*	What title to use */
{
	long thisContext;
	long next;
	long prev;
	char line[MAXPRINTLINE];
	int row;
	HELPTYPE hType = HelpInfo[context].type;

	thisContext = contextHelp( hType, HelpInfo[context].contextNumber, &prev, &next );
	if( followLinks && thisContext != prev ) {
		/*	Move to the beginning of the current series */
		freeHelp();
		thisContext = contextHelp( hType, prev, NULL, NULL );
	}
	if( !PrintableHelp ) {
		freeHelp();
		return FALSE;
	}

	if( !doHeader( type ) )
		goto error;
	do {
		for( row = 1; getHelpLine( row, line ); row++ ) {
			if( !dumpLine( line, type ) )
				goto error;
		}
		do {
			freeHelp();
			if( followLinks ) {
				if( thisContext == next )
					followLinks = FALSE;
				else {
					thisContext = nextContextHelp( hType, thisContext );
					if( !thisContext )
						followLinks = FALSE;
				}
			}
		} while( followLinks && !PrintableHelp );
	} while( followLinks );

	return FALSE;

error:
	freeHelp();
	return TRUE;
}


/**
*
* Name		printAllHelp - Print all the help in a help file.
*
* Returns	FALSE == OK - No Failure
**/
int printAllHelp(
	int context,				/*	Which help block to start printing */
	PRINTTITLETYPE type	)
{
	long thisContext;
	long lastContext;
	char line[MAXPRINTLINE];
	int row;
	HELPTYPE hType = HelpInfo[context].type;

	thisContext = setHelp( hType, HelpInfo[context].context, NULL, NULL );
	if( !doHeader( type ) )
		goto error;

	do {
		if( PrintableHelp ) {
			for( row = 1; getHelpLine( row, line ); row++ ) {
				if( !dumpLine( line, type ) )
					goto error;
			}
		}
		freeHelp();
		lastContext = thisContext;
		thisContext = nextContextHelp( hType, thisContext );
	} while( thisContext > lastContext );
	freeHelp();

	return FALSE;
error:
	freeHelp();
	return TRUE;
}



/**
*
* Name		printEditor - Print all the lines in an edited file.
*
* Synopsis	int printEditor( PRINTTITLETYPE type )
*
* Parameters
*		PRINTTITLETYPE type	What title to use
*
* Description
*		Dump the file that is stored in the editor
*
*
* Returns	FALSE == No Error
*
*
* Version	2.0
**/
int printEditor( PRINTTITLETYPE type )
{
	int i;

	if( !doHeader( type ) )
		goto error;

	if( !printTitle( EditorFileName, type )) return FALSE;

	for (i = 0; i < EditorLines; i++) {
		if (EditorLine[i]) {
			if(!dumpLine( EditorLine[i], type ))
				return FALSE;
		} else
			if(!dumpLine( NULL, type ))
				return FALSE;
	}


	return FALSE;
error:
	return TRUE;

}

/**
*
* Name		printWindow - Print the current text window
*
* Synopsis	int printWindow( PTEXTWIN pWin, PRINTTITLETYPE type, int which )
*
* Parameters
*		PTEXTWIN pWin			Window to print
*		PRINTTITLETYPE type	What title to use
*		int which				What to print as the title
*
* Description
*	Walk a text window and dump it's text to output
*
*
* Returns	FALSE == No Error
*
*
* Version	2.0
**/
int printWindow( PTEXTWIN pWin, PRINTTITLETYPE type, int which )
{
	int row;
	char line[MAXPRINTLINE];

	if( !doHeader( type	) )
		goto error;

	if( type == PRINTTYPEANALYSIS ) {
		/*	A 386UTIL report or an ASQ summary */
		if( which >= QS_OVERVIEW && which <= QS_TIMEMEM ) {
			if( !printTitle( UtilTitles[which - QS_OVERVIEW], type )) return FALSE;
		}
		else {
			int i = asqinfo_lookup( which );
			if( !printTitle( AsqTitles[i < 0 ? 0 : i], type )) return FALSE;
		}
	}


	for( row = 0; row < pWin->size.row; row++ ) {
		memset( line, 0, MAXPRINTLINE );
		vWinGet_s( pWin, row, line );
		if( !dumpLine( line, type ) )
			goto error;
	}

	return FALSE;
error:
	return TRUE;


}




/**
*
* Name		printFile - Print the requested text file
*
* Synopsis	int printFile( char *name )
*
* Parameters
*		char *name			Name of file to print
*
* Description
*	Walk a text File and dump it's text to output
*
*
* Returns	FALSE == No Error
*
*
* Version	2.0
**/
int printFile( char *name )
{
	FILE *fh;
	char line[ MAXPRINTLINE ];
	int len;

	if( !doHeader( PRINTTYPEFILE	) )
		goto error;
	if( !printTitle( name, PRINTTYPEFILE	) )
		goto error;

	fh = fopen ( name, "r");
	if( !fh ) {
		errorMessage( 201 ); /* Unable to open file */
		goto error;
	}

	while( fgets( line, MAXPRINTLINE-1, fh ) != NULL ) {
		if( feof( fh ))
			break;
		len = strlen( line )-1;
		if( len < MAXPRINTLINE )
			line[len ] = '\0';      /*      Strip off cr */

		if(!dumpLine( line, PRINTTYPEFILE ))
				goto error;

	}
	return FALSE;
error:
	return TRUE;
}

/**
*
* title 	printTitle - Print the requested text file
*
* Synopsis	int printTitle( char *title )
*
* Parameters
*		char *title			title of file to print
*
* Description
*	Center the title to pos 40 with a blank line before and after
*
*
* Returns	FALSE == No Error
*
*
* Version	2.0
**/
int printTitle( char *title, int type )
{
	char line[ MAXPRINTLINE ];
	char *start;
	int len;
	len = strlen( title );

	memset( line, ' ', 40 );
	start = line + 40 - len / 2;
	strcpy( start, title );

	/*	Force to upper case */
	while ( *start)
	{
		*start = (char)toupper( *start );
		start++;
	}

	if(!dumpLine( NULL, type ))
		goto error;

	if(!dumpLine( line, type ))
		goto error;

	return dumpLine( NULL, type );

error:
	return TRUE;
}

/**
*
* Name		printInfo - Print an ASQ summary or a 386UTIL report
*
* Returns	FALSE == No Error
**/
int printInfo( int id, int first )
{
	char line[MAXPRINTLINE];
	char *dataLine;
	int which, len, count, n;

	if( first ) {
		if( !doHeader( PRINTTYPEANALYSIS ) ) return FALSE;
	} else
		if( !dumpLine( NULL, PRINTTYPEANALYSIS ) ) return FALSE;

	if( id >= QS_OVERVIEW && id <= QS_TIMEMEM ) {
		/*	386UTIL report */
		which = id - QS_OVERVIEW;
		if( !printTitle( UtilTitles[which], PRINTTYPEANALYSIS ) ) return FALSE;
		if( UtilLen[which] < 1 || UtilWid[which] < 1 ) {
			dumpLine( UtilDataError, PRINTTYPEANALYSIS );
			return FALSE;
		}
		fseek( UtilFile, UtilPos[which], SEEK_SET );
		len = UtilLen[which];
		if( which == 6 ) len -= 2;
		for( n = count = 0; count < len && fgets( line, sizeof(line), UtilFile ); ) {
			n++;
			/*	The time report's second and third lines are left out */
			if( which == 6 && n >= 2 && n <= 3 ) continue;
			dataLine = line + strlen( line );
			if( dataLine > line && dataLine[-1] == '\n' ) dataLine[-1] = '\0';
			if( !dumpLine( line, PRINTTYPEANALYSIS ) ) return TRUE;
			count++;
		}
	}
	else {
		/*	ASQ summary: lines "|cf|text" */
		which = asqinfo_lookup( id );
		if( !printTitle( AsqTitles[which < 0 ? 0 : which], PRINTTYPEANALYSIS ) ) return FALSE;
		if( which < 0 || AsqLen[which] < 1 || AsqWid[which] < 1 ) {
			dumpLine( AsqDataError, PRINTTYPEANALYSIS );
			return FALSE;
		}
		fseek( AsqFile, AsqPos[which], SEEK_SET );
		for( count = 0; count < AsqLen[which] && fgets( line, sizeof(line), AsqFile ); count++ ) {
			dataLine = line + strlen( line );
			if( dataLine > line && dataLine[-1] == '\n' ) dataLine[-1] = '\0';
			dataLine = line + 4;
			if( line[1] - ' ' == -1 )	/* continuation line */
				dataLine[0] = ' ';
			switch( id ) {
			case QS_CFGSUM:
			case QS_EDITCFG:
			case QS_EDITAUT:
			case QS_EDITPRO:
				{
					/*	Strip out all char > 127 to '.' */
					register unsigned char *cp = (unsigned char *)dataLine;
					while( *cp ) {
						if( *cp > 127 )
							*cp = '.';
						cp++;
					}
					break;
				}
			}
			memset( line + 2, ' ', 2 );
			if( !dumpLine( line + 2, PRINTTYPEANALYSIS ) )
				return TRUE;
		}
	}
	return FALSE;
}

/**
*
* Name		printAllQShellData - Print all summaries and reports
*
* Returns	FALSE == No Error
**/
int printAllQShellData( void )
{
	int id;

	if( printInfo( QS_MEMSUM, TRUE ) || printInfo( QS_CFGSUM, FALSE ) ||
			printInfo( QS_HDWSUM, FALSE ) )
		return TRUE;
	/*	The reports we have (their menu items are active) */
	for( id = QS_OVERVIEW; id <= QS_TIMEMEM; id++ ) {
		if( InfoMenu.items[id - QS_OVERVIEW].type != ITEM_DISABLED &&
				printInfo( id, FALSE ) )
			return TRUE;
	}
	return FALSE;
}
