/*
 * VER.H - file version information
 *
 * Open 386MAX - GNU General Public License version 3.
 *
 * Windows programs and resource scripts use OpenWatcom's <win/ver.h>
 * (VER.DLL).  DOS programs use VERLIB (VERLIB/VERLIB.C), which reads the
 * version resource of a file itself: the fixed part of the version
 * information and the two functions of VERLIB are declared here.
 */

#ifndef OPEN386MAX_VER_H
#define OPEN386MAX_VER_H

#if defined(__WINDOWS__) || defined(_WINDOWS) || defined(RC_INVOKED)

#include <win/ver.h>

#else	/* DOS: VERLIB */

#ifndef WINAPI
#define WINAPI	_far _pascal
#define FAR	_far
typedef unsigned char	BYTE;
typedef unsigned short	WORD;
typedef unsigned int	UINT;
typedef unsigned long	DWORD;
typedef int		BOOL;
typedef const char _far *LPCSTR;
#endif

/* fixed part of VS_VERSION_INFO */
typedef struct tagVS_FIXEDFILEINFO {
    DWORD dwSignature;		/* 0FEEF04BDh */
    DWORD dwStrucVersion;
    DWORD dwFileVersionMS;
    DWORD dwFileVersionLS;
    DWORD dwProductVersionMS;
    DWORD dwProductVersionLS;
    DWORD dwFileFlagsMask;
    DWORD dwFileFlags;
    DWORD dwFileOS;
    DWORD dwFileType;
    DWORD dwFileSubtype;
    DWORD dwFileDateMS;
    DWORD dwFileDateLS;
} VS_FIXEDFILEINFO;

/* size of the version resource of a file (0 = none) */
DWORD WINAPI GetFileVersionInfoSize(LPCSTR lpszFile, DWORD FAR *lpdwHandle);
/* read it (dwHandle from GetFileVersionInfoSize) */
BOOL WINAPI GetFileVersionInfo(LPCSTR lpszFile, DWORD dwHandle, DWORD dwLen,
			       void FAR *lpData);

#endif

#endif
