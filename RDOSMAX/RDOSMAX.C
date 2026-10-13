/******************************************************************************
 *									      *
 * Open 386MAX - GNU General Public License version 3.			      *
 *									      *
 * RDOSMAX.C								      *
 *									      *
 * Registers DOSMAX32.DLL, the Windows 95 shell extension that adds the      *
 * DOSMAX property sheet to DOS programs, batch files and PIFs.  Called by   *
 * the Windows SETUP (MAXSETUP) with the installation directory:	      *
 *									      *
 *	RDOSMAX dir	register DOSMAX32.DLL in dir			      *
 *	RDOSMAX /U	remove the registration 			      *
 *									      *
 * Written anew for the open source build (the original was binary only).   *
 *									      *
 ******************************************************************************/

#include <windows.h>
#include <string.h>

#define CLSID_DOSMAX "{E7BDB3C0-080D-11CF-BABB-444553540000}"
#define KEY_CLSID    "CLSID\\" CLSID_DOSMAX

static const char *handlers[] = {
	"batfile\\shellex\\PropertySheetHandlers\\BATPage",
	"comfile\\shellex\\PropertySheetHandlers\\COMPage",
	"exefile\\shellex\\PropertySheetHandlers\\EXEPage",
	"PIFFile\\shellex\\PropertySheetHandlers\\PIFPage"
};

/* HKEY_CLASSES_ROOT\key: default value (and an optional named value) */
static BOOL set_key( const char *key, const char *value, const char *name, const char *data )
{
	HKEY h;
	BOOL ok;
	if ( RegCreateKey( HKEY_CLASSES_ROOT, key, &h ) != ERROR_SUCCESS )
		return FALSE;
	ok = RegSetValue( HKEY_CLASSES_ROOT, key, REG_SZ, value, strlen( value ) ) == ERROR_SUCCESS;
	if ( ok && name )
		ok = RegSetValueEx( h, name, 0, REG_SZ, (const BYTE *)data, strlen( data ) + 1 ) == ERROR_SUCCESS;
	RegCloseKey( h );
	return ok;
}

int PASCAL WinMain( HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show )
{
	char dll[MAX_PATH], *p;
	int i, ok = 1;

	(void)inst; (void)prev; (void)show;
	while ( *cmd == ' ' )
		cmd++;
	if ( ( cmd[0] == '/' || cmd[0] == '-' ) && ( cmd[1] == 'u' || cmd[1] == 'U' ) ) {
		for ( i = 0; i < 4; i++ )
			RegDeleteKey( HKEY_CLASSES_ROOT, handlers[i] );
		RegDeleteKey( HKEY_CLASSES_ROOT, KEY_CLSID "\\InProcServer32" );
		RegDeleteKey( HKEY_CLASSES_ROOT, KEY_CLSID );
		return 0;
	}
	/* the directory (without quotes and a trailing backslash) */
	if ( *cmd == '"' )
		cmd++;
	strncpy( dll, cmd, sizeof(dll) - 16 );
	dll[sizeof(dll) - 16] = 0;
	if ( ( p = strchr( dll, '"' ) ) != NULL )
		*p = 0;
	for ( p = dll + strlen( dll ); p > dll && ( p[-1] == ' ' || p[-1] == '\\' ); p-- )
		p[-1] = 0;
	if ( *dll )
		strcat( dll, "\\" );
	strcat( dll, "DOSMAX32.DLL" );

	ok &= set_key( KEY_CLSID, "Qualitas DOSMAX PIF Extensions", NULL, NULL );
	ok &= set_key( KEY_CLSID "\\InProcServer32", dll, "ThreadingModel", "Apartment" );
	for ( i = 0; i < 4; i++ )
		ok &= set_key( handlers[i], CLSID_DOSMAX, NULL, NULL );
	return ok ? 0 : 1;
}
