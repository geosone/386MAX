/* Definitions of the Microsoft Windows 3.1 SDK headers that OpenWatcom's
   Windows headers lack (force-included by linux/mk/win.mk). */
#ifndef OWWIN_H
#define OWWIN_H

#if !defined(FILEOKSTRING) && !defined(__NT__)  /* win16 commdlg.h */
#define FILEOKSTRING    "commdlg_FileNameOK"
#endif

/* Microsoft C: struct _find_t; OpenWatcom's dos.h maps it to find_t, so a
   prototype seen before dos.h would name another struct */
#ifndef _find_t
#define _find_t find_t
#endif

/* Microsoft C declares tolower/toupper as functions in stdlib.h too;
   without the prototype -ecc would make them cdecl calls */
#include <ctype.h>

/* OpenWatcom's string.h leaves out the _f... prototypes when windowsx.h
   came first; read it before (-ecc would make the calls cdecl) */
#include <string.h>
/* ... but NULL stays undefined: windows.h makes it 0 (Microsoft SDK),
   handles of non-STRICT programs are compared with it */
#undef NULL

#endif
