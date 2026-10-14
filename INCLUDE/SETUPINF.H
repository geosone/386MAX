/* SETUPINF.H - answers of an unattended installation (SETUP.INF)
 *
 * SETUP.INF is written by MAXCFG and read by SETUPDOS, SETUP (Windows),
 * MAXIMIZE and WINMAXIM.  Every key is optional: a missing key means the
 * program asks as before.  One file serves every installer: a program
 * uses the sections that apply to it.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#ifndef SETUPINF_INCLUDED
#define SETUPINF_INCLUDED

#define SETUPINF_NAME	"SETUP.INF"

extern int Unattended;		/* SETUP.INF loaded with [Setup] Unattended=1 */

int inf_load (const char *path);		/* 0: read (sets Unattended) */
int inf_loaded (void);				/* SETUP.INF read at all */
const char *inf_get (const char *sect, const char *key); /* NULL: absent */
int inf_bool (const char *sect, const char *key, int def); /* 1/0, def if absent */
int inf_section (const char *sect);		/* section present with keys */
void inf_logfile (const char *path);		/* where inf_log() writes */
void inf_log (const char *fmt, ...);		/* note, e.g. a skipped message */

#endif /* SETUPINF_INCLUDED */
