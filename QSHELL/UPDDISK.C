/******************************************************************************
 *									      *
 * (C) Copyright 1991-96 Qualitas, Inc.  GNU General Public License version 3. *
 *									      *
 * UPDDISK.C								      *
 *									      *
 * Ask for the drive and path of the Update program (File/Update).	      *
 *									      *
 * Reconstructed for Open 386MAX from the original MAX.EXE; the dialog is     *
 * askFileName() of QUILIB/FILENAME.C.					      *
 *									      *
 ******************************************************************************/

#include <ctype.h>
#include <string.h>

#include "button.h"
#include "commfunc.h"
#include "fldedit.h"
#include "input.h"
#include "libcolor.h"
#include "libtext.h"
#include "qhelp.h"
#include "qwindows.h"
#include "screen.h"
#include "ui.h"

#include "qshtext.h"
#include "qshell.h"

#define UPDATENROWS	9
#define UPDATENCOLS	55
#define UPDATETEXTROW	2
#define UPDATEEDITROW	3
#define UPDATEBUTTONROW 6
#define UPDATEPATHLEN	78

/*	Returns the key that ended the dialog; with Enter the path is in
 *	'path' */
int askUpdateDisk(char *path)
{
	enum { EDITFIELD, DBUTTONS } focus = EDITFIELD;
	char workName[UPDATEPATHLEN+2];
	FLDITEM editName;
	INPUTEVENT event;
	void *behind;
	WINDESC win;
	WINDESC workWin;
	WINDESC stringWin;

	/*	Specify where to put the window */
	win.row = ( ScreenSize.row - UPDATENROWS ) / 2;
	win.col = ( ScreenSize.col - UPDATENCOLS ) / 2;
	win.nrows = UPDATENROWS;
	win.ncols = UPDATENCOLS;

	if( saveButtons() != BUTTON_OK )
		return 0;

	/*	Save what's behind us */
	behind = win_save( &win, TRUE );
	if( !behind )
		return 0;

	wput_sca( &win, VIDWORD( BaseColor, ' ' ));
	shadowWindow( &win );
	box( &win, BOX_DOUBLE, UPDATETITLE, NULL, BaseColor );

	/*	Adjust the window inside the box */
	win.col += 2;
	win.ncols -= 5;
	SETWINDOW( &workWin, win.row + UPDATETEXTROW, win.col, 1, win.ncols );
	stringWin = workWin;

	justifyString( &stringWin, UPDATETEXT, -1, JUSTIFY_CENTER, BaseColor, BaseColor );

	workWin.row = win.row + UPDATEEDITROW;
	strcpy( workName, path );
	showFldEdit( &editName, &workWin, 0,
				 workName, UPDATEPATHLEN,
				 EditColor, TRUE, FALSE );

	sendFldEditKey( &editName, KEY_TAB, 0 );

	FileNameButtons[NUMFILENAMEBUTTONS-2].pos.row = win.row + UPDATEBUTTONROW;
	FileNameButtons[NUMFILENAMEBUTTONS-1].pos.row = win.row + UPDATEBUTTONROW;

	addButton( FileNameButtons, NUMFILENAMEBUTTONS, NULL );
	disableButton( KEY_F2, TRUE );
	showAllButtons();

	for(;;) {
		get_input( INPUT_WAIT, &event );
		if( event.key ) {
			int retVal;
			if( focus == EDITFIELD ) {
				switch( toupper (event.key) ) {
				case RESP_CANCEL:
				case RESP_OK:
					sendFldEditKey( &editName, event.key, event.flag );
					continue;
				}
			}

			retVal = testButton( event.key, TRUE );
			switch( retVal ) {
			case KEY_F1:
				showHelp( HELPDIALOGS, FALSE );
				continue;
			case KEY_ESCAPE:
			case KEY_ENTER:
				goto cleanup;
			case BUTTON_LOSEFOCUS:
				goto editFocus;
			case BUTTON_OK:
				goto buttonFocus;
			}
			if( sendFldEditKey( &editName, event.key, event.flag ) == FLD_OK )
				goto editFocus;

		} else {
			if( testButtonClick( &event, TRUE ) ) {
				if( LastButton.key == KEY_F1 ) {
					showHelp( HELPDIALOGS, FALSE );
					continue;
				}
				else
					break;
			}
			if( sendFldEditClick( &editName, &event ) == FLD_OK ) {
				goto editFocus;
			}
		}
		continue;
buttonFocus:
		if( focus == EDITFIELD ) {
			justifyString( &stringWin, UPDATETEXT, -1, JUSTIFY_CENTER, NormalColor, NormalColor );
			focus = DBUTTONS;
			sendFldEditKey( &editName, KEY_STAB, 0 );
		}
		continue;
editFocus:
		if( focus != EDITFIELD ) {
			justifyString( &stringWin, UPDATETEXT, -1, JUSTIFY_CENTER, BaseColor, BaseColor );
			focus = EDITFIELD;
			setButtonFocus( FALSE, KEY_TAB );
			sendFldEditKey( &editName, KEY_TAB, 0);
		}
	}

cleanup:
	restoreButtons( );
	win_restore( behind, TRUE );

	if( LastButton.key == KEY_ENTER )
		strcpy( path, workName );
	return LastButton.key;
}
