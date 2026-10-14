/* OPTTAB.H - the options of SETUP.INF (MAXCFG, DOS and Windows)
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#ifndef OPTTAB_INCLUDED
#define OPTTAB_INCLUDED

#define OT_BOOL		1	/* 1 / 0 */
#define OT_CHOICE	2	/* one of choices ("A|B|C") */
#define OT_TEXT		3	/* free text (a path) */

#define OPTVALLEN	64

typedef struct {
	const char *sect;	/* SETUP.INF section */
	const char *key;	/* ... key */
	int type;		/* OT_... */
	const char *def;	/* default value */
	const char *choices;	/* OT_CHOICE: "A|B|C" */
	const char *label;	/* shown in MAXCFG */
	const char *help;	/* one line of explanation */
	char value[OPTVALLEN];	/* "" = not set: the installer asks */
} OPTION;

typedef struct {
	const char *sect;	/* section of the page's options */
	const char *title;	/* tab title */
} OPTPAGE;

extern OPTION Options[];
extern int nOptions;
extern OPTPAGE Pages[];
extern int nPages;

extern const char *TxtAsk;	/* "(ask)" */

void opt_defaults (void);			/* every option its default */
int opt_load (const char *path);		/* 0 if read */
int opt_save (const char *path);		/* 0 if written */
int opt_choice (const OPTION *o, int n, char *buf, int size); /* n-th choice */
int opt_nchoices (const OPTION *o);
int opt_choiceindex (const OPTION *o);		/* of value, -1 = ask */

#endif
