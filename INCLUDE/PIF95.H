/*
 * PIF95.H - PIFMGR.DLL property functions of Windows 95
 *
 * Open 386MAX - GNU General Public License version 3.
 *
 * Only what DOSMAX16 uses; the import library is made from
 * DOSMAX16/PIFMGR.IMP.  Requires <windows.h>.
 */

#ifndef OPEN386MAX_PIF95_H
#define OPEN386MAX_PIF95_H

int WINAPI OpenProperties(LPCSTR lpszApp, LPCSTR lpszPIF, int hInf, int flOpt);
int WINAPI GetProperties(int hProps, LPCSTR lpszGroup, LPVOID lpProps,
			 int cbProps, int flOpt);
int WINAPI SetProperties(int hProps, LPCSTR lpszGroup, const void FAR *lpProps,
			 int cbProps, int flOpt);
int WINAPI CloseProperties(int hProps, int flOpt);

#endif
