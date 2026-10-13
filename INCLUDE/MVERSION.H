//' $Header:   P:/PVCS/MAX/INCLUDE/MVERSION.H_V   1.73   23 May 1997 13:36:00   BOB  $
//
// MVERSION.H - Version definitions for Max 8 (Open 386MAX)
// Included by component resource scripts.
//
// ------------------------------------------------------
// Copyright (C) 1995 Qualitas, Inc.  GNU General Public License version 3
// ------------------------------------------------------

#include <maxnames.h>
#include <_lcldefs.h>					// Define BUILD_BETA, BUILD_ALPHA

// Check for required stuff
#ifndef VER_FILEDESCRIPTION_STR
#include <common.ver>					// From SDK
#endif

#ifndef VER_MODULE
#error VER_MODULE not defined
#endif

#ifndef VER_MODULE_STR
#error VER_MODULE_STR not defined
#endif

// Version from the file VERSION (linux/mk/version.mk passes it to the
// compiler and the resource compiler)
#ifndef O386_VER_MAJOR
#error O386_VER_MAJOR not defined (see linux/mk/version.mk)
#endif
#define O386_STR2(x)			#x
#define O386_STR(x)				O386_STR2(x)
#define VER_MAJOR					O386_VER_MAJOR	// 1.xx.xxx.xxx
#define VER_MAJOR_STR				O386_STR(O386_VER_MAJOR)
#define VER_MINOR					O386_VER_MINOR	// x.0.xxx.xxx
#define VER_MINOR_STR				O386_STR(O386_VER_MINOR_S)
#define VER_BETA					4 // x.xx.001.xxx
#define VER_BETA_STR				"004"
// VER_MODULE and VER_MODULE_STR are defined in the component's resource script

#define VERSION_BETA	VER_BETA_STR "." VER_MODULE_STR
#if BUILD_BETA
#define VER_ALPHAFLAGS	VS_FF_PRIVATEBUILD
#define VER_BETAFLAGS	VS_FF_PRERELEASE
#define VERSION 		VER_MAJOR_STR "." VER_MINOR_STR "." VERSION_BETA BUILD_ALPHA
#else
#define VER_ALPHAFLAGS	0
#define VER_BETAFLAGS	0
#define VERSION 		VER_MAJOR_STR "." VER_MINOR_STR
#endif

#define VER_PRODUCTVERSION			VER_MAJOR,VER_MINOR,VER_BETA,VER_MODULE
#define VER_PRODUCTVERSION_STR		VERSION

#define VER_PRODUCTNAME_STR		MAX8PRODUCT
#define VER_LEGALCOPYRIGHT_YEARS	"1987-97"
#define VER_COMPANYNAME_STR		"Qualitas, Inc."
#define VER_COPYRIGHT1_STR			"Copyright \251 " VER_LEGALCOPYRIGHT_YEARS " " VER_COMPANYNAME_STR

// Open 386MAX (short enough for the About boxes)
#define VER_COPYRIGHT2_STR			"Open 386MAX 2022-2026, GNU GPL v3"

#define VER_LEGALCOPYRIGHT_STR		VER_COPYRIGHT1_STR " " VER_COPYRIGHT2_STR
// Define a two-line version of the copyright for when we're low on space.
#define VER_LEGALCOPYRIGHT2_STR 	VER_COPYRIGHT1_STR "\n" VER_COPYRIGHT2_STR

#define VER_FILEFLAGSMASK			VS_FFI_FILEFLAGSMASK
#define VER_FILEFLAGS				(VER_ALPHAFLAGS|VER_BETAFLAGS)
#define VER_FILEOS					VOS_DOS_WINDOWS16

