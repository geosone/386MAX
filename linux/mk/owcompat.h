/* OpenWatcom compatibility for the Microsoft C 7/8 sources of 386MAX,
 * put in front of every C module (wcc -fi=...).  The sources stay as they
 * are.  The modules are compiled with cdecl as default convention (-ecc)
 * because of the assembler modules; the run time library of OpenWatcom
 * calls back with its register convention, so the functions with
 * callbacks go through wrappers in owcompat.c. */
#ifndef OWCOMPAT_H
#define OWCOMPAT_H

/* DS: Microsoft C keeps DS = DGROUP in all functions, OpenWatcom's large
 * model library lets DS float (it returns with DS = some data segment).
 * The library functions are declared to modify DS (the compiler doesn't
 * rely on DS after calling them), and with -r every function of the
 * sources preserves DS for its callers in assembler and Microsoft C
 * (TEXT/LHELP.LIB).  Small and medium model: DS stays DGROUP anyway. */
#if (defined(__COMPACT__) || defined(__LARGE__) || defined(__HUGE__)) && !defined(__WINDOWS__)
#pragma aux __watcall modify [ax bx cx dx es ds]
/* pascal functions (Microsoft C's help engine TEXT/LHELP.LIB) are called
 * with DS = DGROUP like cdecl functions ("parm loadds"); otherwise the
 * same as OpenWatcom's predefined __pascal */
#pragma aux __pascal "^" parm reverse routine [] loadds value struct float struct caller [] modify [ax bx cx dx es]
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <dos.h>
#include <i86.h>
#include <signal.h>
#include <process.h>
#include <io.h>

/* MS C declared the time/date words of _dos_getftime as unsigned int* */
#define _dos_getftime(h, d, t) _dos_getftime((h), (unsigned *)(d), (unsigned *)(t))

/* MS C <malloc.h>: largest block for malloc/_fmalloc */
#ifndef _HEAP_MAXREQ
#define _HEAP_MAXREQ 0xFFE8
#endif

/* Microsoft C accepted "enum boolean" without a definition (INSTALL) */
enum boolean { OWC_BOOLEAN };

/* Microsoft C 7 names with an underscore that OpenWatcom has only without */
#define _strcmpi strcmpi
#define _movedata movedata
#define _putch putch
#define _cputs cputs
#define _cprintf cprintf
#define _swab swab
#define _tzset tzset

/* QUILIB's own sleep(long msecs) instead of sleep(unsigned seconds) */
#define sleep(ms) quilib_sleep(ms)

/* functions of the projects with the names of OpenWatcom functions */
#ifdef OWC_OWN_DELAY
#define delay owc_own_delay
#endif
#ifdef OWC_OWN_GETLINE
#define getline owc_own_getline
#endif
#ifdef OWC_OWN_TOUPPER
#define toupper owc_own_toupper
#endif
#ifdef OWC_OWN_SPRINTF
#define sprintf owc_own_sprintf
#endif
#ifdef OWC_OWN_SSCANF
#define sscanf owc_own_sscanf
#endif

/* fputs returns 0 on success with Microsoft C (OpenWatcom: the number of
 * characters); the sources test "if (fputs(...))" */
extern int owc_fputs(const char *s, FILE *fp);
#define fputs(s, f) owc_fputs(s, f)

/* strtok as in Microsoft C: a string without tokens moves the saved
 * position to its end.  OpenWatcom's strtok leaves the position of the
 * previous string there; the sources call strtok(NULL, ...) after an empty
 * line (e.g. a comment cut off), which then wrote NULs into stale memory
 * (SETUP find_pro: overwrote its own return address on the stack) */
extern char *owc_strtok(char *s, const char *delim);
#define strtok(s, d) owc_strtok((s), (d))

/* callbacks: cdecl functions of the program, called by the library */
typedef int (__cdecl *owc_cmpfn)(const void *, const void *);
typedef void (__cdecl *owc_sigfn)(int);
extern void owc_qsort(void *base, size_t num, size_t width, owc_cmpfn cmp);
extern owc_sigfn owc_signal(int sig, owc_sigfn func);
#ifndef __WINDOWS__
extern void owc_harderr(void (__cdecl __far *handler)(unsigned, unsigned, unsigned __far *));
#define qsort(b, n, w, f) owc_qsort((b), (n), (w), (owc_cmpfn)(f))
#define signal(s, f) owc_signal((s), (owc_sigfn)(f))
#define _harderr(f) owc_harderr((void (__cdecl __far *)(unsigned, unsigned, unsigned __far *))(f))
#endif


/* every _asm block starts with DS = DGROUP like with Microsoft C
 * (owc_ldgroup also tells the compiler that DS changed).  A _asm block is
 * two statements now: "if (x) _asm {...}" needs braces. */
#if (defined(__COMPACT__) || defined(__LARGE__) || defined(__HUGE__)) && !defined(__WINDOWS__)
extern void owc_ldgroup(void);
#pragma aux owc_ldgroup = "push ss" "pop ds" modify exact [ds];
#define _asm owc_ldgroup(); __asm
#endif

#endif
