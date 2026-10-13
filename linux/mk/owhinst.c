/* _hInstance of the Microsoft C Windows start up code, which OpenWatcom's
 * lacks: the program's WinMain is renamed (win.mk MSHINST=1 compiles it
 * with -dWinMain=owc_WinMain -d_hInstance=owc_hInstance) and called from
 * here after the instance handle is saved. */
#include <windows.h>

HINSTANCE owc_hInstance;

extern int PASCAL owc_WinMain(HINSTANCE, HINSTANCE, LPSTR, int);

int PASCAL WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpszCmdLine, int nCmdShow)
{
    owc_hInstance = hInstance;
    return( owc_WinMain( hInstance, hPrevInstance, lpszCmdLine, nCmdShow ) );
}
