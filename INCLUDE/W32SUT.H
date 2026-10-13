/*
 * W32SUT.H - Universal Thunk (Win32s / Windows 95), 32-bit side
 *
 * Open 386MAX - GNU General Public License version 3.
 *
 * Only what DOSMAX32 uses (compiled with W32SUT_32).  Requires <windows.h>.
 */

#ifndef OPEN386MAX_W32SUT_H
#define OPEN386MAX_W32SUT_H

#ifdef W32SUT_32

/* entry into the 16-bit DLL, returned by UTRegister */
typedef DWORD (WINAPI *UT32PROC)(LPVOID lpBuff, DWORD dwUserDefined,
				 LPVOID *lpTranslationList);

BOOL WINAPI UTRegister(HANDLE hModule, LPCSTR lpsz16BitDLL,
		       LPCSTR lpszInitName, LPCSTR lpszProcName,
		       UT32PROC *ppfn32Thunk, FARPROC pfnUT32Callback,
		       LPVOID lpBuff);
VOID WINAPI UTUnRegister(HANDLE hModule);

#endif

#endif
