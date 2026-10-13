/* Force-included when the MFC 2.5 library (Microsoft Visual C++ 1.5) and
   MFC programs are compiled with OpenWatcom wpp for Windows 3.1
   (linux/mk/mfc.mk): what Microsoft C's and the Windows 3.1 SDK's headers
   define and OpenWatcom's do not. */
#ifndef OWMFC_H
#define OWMFC_H

#include <stdarg.h>             /* va_list: Microsoft's stdio.h defines it */
#include <io.h>                 /* _unlink: Microsoft's stdio.h declares it */

/* compobj.h of the OLE 2 SDK */
#define CLSID_NULL  GUID_NULL
#define IID_NULL    GUID_NULL


/* MFC and its programs use OpenWatcom's convention (wpp can't use -ecc: its
   C++ run time helpers and headers need __watcall); functions of libraries
   made for Microsoft C are marked __cdecl in their headers (QUILIB).  In the
   MFC library itself (linux/mfc: OWMFC_LIB) cdecl is empty: int cdecl
   AfxNewHandler(size_t) is used as _PNH (wpp ignores -Dcdecl=). */
#ifdef OWMFC_LIB
#define cdecl
#endif

/* afxver.cpp: _afx_version() is _export (for the DLL variant) but called
   directly by AfxInitialize(); in an EXE the loader replaces the prologue
   of exported functions (push ds/pop ax -> nop) so DS would come from a
   garbage AX.  linux/mfc compiles that module with OWMFC_NOEXPORT. */
#ifdef OWMFC_NOEXPORT
#define _export
#endif

/* registered message strings of the Windows 3.1 SDK's commdlg.h */
#ifndef LBSELCHSTRING
#define LBSELCHSTRING   "commdlg_LBSelChangedNotify"
#define SHAREVISTRING   "commdlg_ShareViolation"
#define FILEOKSTRING    "commdlg_FileNameOK"
#define COLOROKSTRING   "commdlg_ColorOK"
#define SETRGBSTRING    "commdlg_SetRGBColor"
#define FINDMSGSTRING   "commdlg_FindReplace"
#define HELPMSGSTRING   "commdlg_help"
#endif

/* Microsoft C: _fstat(int, struct _stat *); OpenWatcom's _fstat takes the
   (identical) struct stat */
#include <sys/types.h>
#include <sys/stat.h>
#define _fstat(h, s)    fstat((h), (struct stat *)(s))

/* ole2ui.h of the OLE 2 SDK (COleResizeBar, CRectTracker) */
#define DEFAULT_HATCHBORDER_WIDTH   4

/* MFC tests "this == NULL" (CWnd::GetSafeHwnd() on a NULL pointer, ...);
   OpenWatcom's C++ compiler folds that to false.  linux/mfc rewrites those
   tests to owc_ptrval(this) == 0: the inline code is empty, so the
   compiler can't know the value. */
#ifdef __cplusplus
extern "C" unsigned long owc_ptrval(const void __far *p);
#pragma aux owc_ptrval = "" parm [dx ax] value [dx ax] modify exact [];
#endif

/* message handlers: the message maps hold them as member pointers of type
   void (AFX_MSG_CALL CCmdTarget::*)() with AFX_MSG_CALL = PASCAL, while the
   handlers (afx_msg, a placeholder) have the default convention; CWnd::
   OnWndMsg calls them through a union of other such types.  Microsoft C
   passes the arguments on the stack either way; OpenWatcom makes a
   conversion thunk for each cast, which doesn't fit the type used for the
   call.  With AFX_MSG_CALL empty, handlers and member pointers have the same
   convention and the casts only change the type. */
#define AFX_MSG_CALL

/* BASED_CODE (data in the code segment): OpenWatcom takes
   __based(__segname("_CODE")) as a segment of that name but fills in the
   segment of the module's code -> data in DGROUP instead */
#define BASED_CODE

/* MFC's swap tuning (#pragma code_seg(AFX_CORE1_SEG) ...): OpenWatcom
   puts the static initializers into the module's default code segment and
   calls far functions in the pragma's segment with a near call.  afx.h is
   read here (its guard skips it later) so that the segment names can be
   removed before any source sees them: one code segment per module. */
#ifdef __cplusplus
#include <afx.h>
#undef AFX_CORE1_SEG
#undef AFX_CORE2_SEG
#undef AFX_CORE3_SEG
#undef AFX_CORE4_SEG
#undef AFX_CORE5_SEG
#undef AFX_AUX_SEG
#undef AFX_AUX2_SEG
#undef AFX_COLL_SEG
#undef AFX_COLL2_SEG
#undef AFX_OLE_SEG
#undef AFX_OLE2_SEG
#undef AFX_OLE3_SEG
#undef AFX_OLE4_SEG
#undef AFX_DB_SEG
#undef AFX_INIT_SEG
#undef AFX_VBX_SEG
#undef AFX_PRINT_SEG
#undef AFX_DBG1_SEG
#undef AFX_DBG2_SEG
#undef AFX_DBG3_SEG
#endif

#endif
