// Run time class of COleException for the OLE-less MFC library of
// linux/mfc: OpenWatcom references it from modules that see the inline
// constructor in afxole.inl (wincore); its own module olemisc.cpp would
// bring in OLE 2 (OLE2.DLL, COMPOBJ.DLL), which the 386MAX programs don't use.
#include "stdafx.h"

IMPLEMENT_DYNAMIC(COleException, CException)
