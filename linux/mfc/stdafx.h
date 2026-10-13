/* Precompiled-header list of the MFC 2.5 library sources (MFC\SRC\STDAFX.H
 * of Visual C++ 1.5), used instead of it by linux/mfc/GNUmakefile: the
 * library is built without the ODBC (afxdb.h), socket (afxsock.h) and OLE
 * dialog (afxodlgs.h) parts, which the 386MAX programs don't use. */
#include "afx.h"
#include "plex.h"
#include "afxcoll.h"
#ifdef _WINDOWS
#include "afxwin.h"
#include "afxdlgs.h"
#include "afxext.h"
#include "afxole.h"
#include "afxpriv.h"
#include "auxdata.h"
#include "auxvars.h"
#include "oleimpl.h"
#endif
