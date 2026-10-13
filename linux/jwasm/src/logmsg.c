/****************************************************************************
*
*                            Open Watcom Project
*
*    Portions Copyright (c) 1983-2002 Sybase, Inc. All Rights Reserved.
*
*  ========================================================================
*
*    This file contains Original Code and/or Modifications of Original
*    Code as defined in and that are subject to the Sybase Open Watcom
*    Public License version 1.0 (the 'License'). You may not use this file
*    except in compliance with the License. BY USING THIS FILE YOU AGREE TO
*    ALL TERMS AND CONDITIONS OF THE LICENSE. A copy of the License is
*    provided with the Original Code and Modifications, and is also
*    available at www.sybase.com/developer/opensource.
*
*    The Original Code and all software distributed under the License are
*    distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
*    EXPRESS OR IMPLIED, AND SYBASE AND ALL CONTRIBUTORS HEREBY DISCLAIM
*    ALL SUCH WARRANTIES, INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF
*    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR
*    NON-INFRINGEMENT. Please see the License for the specific language
*    governing rights and limitations under the License.
*
*  ========================================================================
*
* Description:  write log
*
****************************************************************************/

#include <stdarg.h>
#include <ctype.h>
#include <setjmp.h>

#include "globals.h"
#include "memalloc.h"
#include "parser.h"
#include "input.h"
#include "tokenize.h"
#include "macro.h"
#include "msgtext.h"
#include "segment.h"

/* v2.21: this code has been moved from errmsg.c to this new file;
 *        thus it's possible to activate debug logs for a specific file only.
 */

/* there are intransparent IDEs that don't want to tell you the real, current command line arguments
 * and often those tools also swallow anything that is written to stdout or stderr.
 * To make jwasm write a trace log to a file, enable the next line!
 * Additionally, you'll probably have to enable line Set_dt() in cmdline.c, function ParseCmdline().
 */
//#define DBGLOGFILE "jwasm.log"

#ifdef DBGLOGFILE
FILE *fdbglog = NULL;
#endif

#ifndef DEBUG_OUT

/* GetTopLine() is defined in input.c, but only if DEBUG_OUT is defined.
 * If debug logs are to be written without general definition of DEBUG_OUT,
 * this dummy function is used.
 */
static char *GetTopLine( char *buffer )
{
    *buffer = NULLC;
    return( buffer );
}
#endif

void DoDebugMsg( const char *format, ... )
/****************************************/
{
    va_list args;
#ifdef DEBUG_OUT
    if( !Options.debug ) return;
#endif
    if( ModuleInfo.cref == FALSE && CurrFName[ASM] != NULL )
        return;

    va_start( args, format );
#ifdef DBGLOGFILE
    if ( fdbglog == NULL )
        fdbglog = fopen( DBGLOGFILE, "w" );
    vfprintf( fdbglog, format, args );
#else
    vprintf( format, args );
#endif
    va_end( args );
#if 0
#ifdef DBGLOGFILE
    fflush( fdbglog );
#else
    fflush( stdout );
#endif
#endif
}

void DoDebugMsg1( const char *format, ... )
/****************************************/
{
    va_list args;
    char buffer[MAX_LINE_LEN];
#ifdef DEBUG_OUT
    if( !Options.debug ) return;
#endif
    if( ModuleInfo.cref == FALSE ) return;

#ifdef DBGLOGFILE
    if ( fdbglog == NULL )
        fdbglog = fopen( DBGLOGFILE, "w" );
#endif
    //if ( CurrFName[ASM] )
    if ( ModuleInfo.g.src_stack ) {
#ifdef DBGLOGFILE
        fprintf( fdbglog, "%" I32_SPEC "u%s. ", GetLineNumber(), GetTopLine( buffer ) );
#else
        printf( "%" I32_SPEC "u%s. ", GetLineNumber(), GetTopLine( buffer ) );
#endif
    }
    va_start( args, format );
#ifdef DBGLOGFILE
    vfprintf( fdbglog, format, args );
#else
    vprintf( format, args );
#endif
    va_end( args );

#if 0
# ifdef DBGLOGFILE
    fflush( fdbglog );
# else
    fflush( stdout );
# endif
#endif
}
//#endif

