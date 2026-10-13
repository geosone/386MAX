/* Wrappers for owcompat.h: the OpenWatcom run time calls callbacks with
 * its register convention (__watcall), the 386MAX sources pass cdecl
 * functions (compiled with -ecc like Microsoft C). */
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <dos.h>
#undef qsort
#undef strtok
#undef fputs
#undef signal
#undef _harderr

/* the trampolines are called by the library: they must preserve DS
 * (owcompat.h declares the library's __watcall functions to modify DS) */
#pragma aux (__watcall) owc_cmp_tramp modify exact [ax bx cx dx es]
#pragma aux (__watcall) owc_sig_tramp modify exact [ax bx cx dx es]
#ifndef __WINDOWS__
#pragma aux (__watcall) owc_harderr_tramp modify exact [ax bx cx dx es]
#endif

/* qsort: not reentrant, which the sources don't need */
static owc_cmpfn owc_cmp;

static int __watcall owc_cmp_tramp(const void *a, const void *b)
{
    return( owc_cmp( a, b ) );
}

void owc_qsort(void *base, size_t num, size_t width, owc_cmpfn cmp)
{
    owc_cmpfn old = owc_cmp;
    owc_cmp = cmp;
    qsort( base, num, width, owc_cmp_tramp );
    owc_cmp = old;
}

/* signal: one cdecl handler per signal number */
#define OWC_NSIG 32
static owc_sigfn owc_sighandler[OWC_NSIG];

static void __watcall owc_sig_tramp(int sig)
{
    if ( sig >= 0 && sig < OWC_NSIG && owc_sighandler[sig] )
        owc_sighandler[sig]( sig );
}

owc_sigfn owc_signal(int sig, owc_sigfn func)
{
    __sig_func prev;
    owc_sigfn oldc;
    /* SIG_DFL, SIG_IGN, SIG_ERR are small constants, not functions */
    if ( (unsigned long)func <= 3 || sig < 0 || sig >= OWC_NSIG ) {
        prev = signal( sig, (__sig_func)func );
    } else {
        prev = signal( sig, owc_sig_tramp );
    }
    oldc = ( sig >= 0 && sig < OWC_NSIG ) ? owc_sighandler[sig] : 0;
    if ( sig >= 0 && sig < OWC_NSIG )
        owc_sighandler[sig] = ( (unsigned long)func <= 3 ) ? 0 : func;
    if ( prev == owc_sig_tramp )
        return( oldc );
    return( (owc_sigfn)prev );
}

#ifndef __WINDOWS__     /* DOS only: no _harderr / spawn under Windows */
/* _harderr: Microsoft C's handler returns with _hardresume/_hardretn or
 * falls through (then the call fails) */
static void (__cdecl __far *owc_harderr_fn)(unsigned, unsigned, unsigned __far *);

static int __far __watcall owc_harderr_tramp(unsigned deverr, unsigned errcode, unsigned __far *devhdr)
{
    owc_harderr_fn( deverr, errcode, devhdr );
    return( _HARDERR_FAIL );
}

void owc_harderr(void (__cdecl __far *handler)(unsigned, unsigned, unsigned __far *))
{
    owc_harderr_fn = handler;
    /* <dos.h> has no convention for the handler (cdecl with -ecc), the
     * library calls it with its own register convention */
    _harderr( (int (__far *)(unsigned, unsigned, unsigned __far *))owc_harderr_tramp );
}

/* Microsoft C run time functions called by the assembler modules (cdecl
 * names, MAXIMIZE\MAXSUB.ASM) */
#pragma aux msc_spawnl "__spawnl"
#pragma aux msc_exit "_exit"

int msc_spawnl(int mode, const char *path, const char *arg0, ...)
{
    /* the arguments up to the NULL lie on the stack like an argv[] */
    return( spawnv( mode, path, &arg0 ) );
}

void msc_exit(int status)
{
    exit( status );
}

#endif

/* fputs with the return value of Microsoft C */
int owc_fputs(const char *s, FILE *fp)
{
    return( fputs( s, fp ) == EOF ? EOF : 0 );
}


/* strtok with the behaviour of Microsoft C (owcompat.h) */
char *owc_strtok(char *s, const char *delim)
{
    static char *next;
    char *t;

    if( s == NULL ) s = next;
    if( s == NULL ) return( NULL );
    s += strspn( s, delim );
    if( *s == '\0' ) {
        next = s;
        return( NULL );
    }
    t = s + strcspn( s, delim );
    if( *t != '\0' ) *t++ = '\0';
    next = t;
    return( s );
}
