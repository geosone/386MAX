/* Names of the Microsoft C run time that the assembler modules and the
 * libraries compiled with Microsoft C (TEXT/LHELP.LIB) use, mapped to the
 * OpenWatcom run time.  Compiled without the OpenWatcom headers (and
 * without owcompat.h) so that the cdecl names don't collide. */
typedef unsigned size_t;

#pragma aux (__watcall) ow_fmalloc "_fmalloc_"
#pragma aux (__watcall) ow_ffree "_ffree_"
#pragma aux (__watcall) ow_frealloc "_frealloc_"
#pragma aux (__watcall) ow_putch "putch_"
#pragma aux (__watcall) ow_toupper "toupper_"
#pragma aux (__watcall) ow__exit "_exit_" aborts
extern void __far * __watcall ow_fmalloc(size_t);
extern void __watcall ow_ffree(void __far *);
extern void __far * __watcall ow_frealloc(void __far *, size_t);
extern int __watcall ow_putch(int);
extern int __watcall ow_toupper(int);
extern void __watcall ow__exit(int);

/* the callers (Microsoft C) need DS = DGROUP, the OpenWatcom functions
 * may return with another DS (SS = DGROUP) */
#define DGROUP() _asm { push ss } _asm { pop ds }

void __far * __cdecl _fmalloc(size_t n) { void __far *p = ow_fmalloc( n ); DGROUP(); return( p ); }
void __cdecl _ffree(void __far *p) { ow_ffree( p ); DGROUP(); }
void __far * __cdecl _frealloc(void __far *p, size_t n) { p = ow_frealloc( p, n ); DGROUP(); return( p ); }
int __cdecl _putch(int c) { c = ow_putch( c ); DGROUP(); return( c ); }
int __cdecl toupper(int c) { c = ow_toupper( c ); DGROUP(); return( c ); }
void __cdecl _exit(int status) { ow__exit( status ); }     /* STATUTIL\MYEXECV.ASM */

/* stack limit of Microsoft C (checked by its stack probes) */
unsigned __cdecl STKHQQ;

/* __aFlshl: DX:AX <<= CL (far helper of Microsoft C for long shifts) */
#pragma aux __aFlshl "__aFlshl" parm [dx ax] [cl] value [dx ax] modify exact [dx ax cx]
long __aFlshl(long v, unsigned char n)
{
    return( v << n );
}
