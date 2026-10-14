/* MAXDOSCF.C - MAXCFG for DOS: edit SETUP.INF (unattended installation)
 *
 * The DOS stub of MAXCFG.EXE (MAXWINCF.C is the Windows part): one page
 * per section, like MSCONFIG of the Windows 98 support CD.
 *
 *   MAXCFG [file]       (default: SETUP.INF next to MAXCFG.EXE)
 *
 * Keys: Left/Right or Tab - page, Up/Down - option, Space - next value
 * (yes, no, ask), Enter - edit a text, Del - ask, F2 - save, Esc - quit.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <conio.h>
#include <dos.h>
#include <i86.h>

#include "opttab.h"

#ifdef LANG_GR
#define T(us,gr)	gr
#else
#define T(us,gr)	us
#endif

#define COLS	80
#define ROWS	25
#define FIRSTROW 5		/* first option line */
#define HELPROW 20
#define KEYROW	24

#define A_TITLE 0x1F		/* white on blue */
#define A_BACK	0x17		/* gray on blue */
#define A_TAB	0x1F
#define A_TABON 0x70		/* black on gray */
#define A_SEL	0x30		/* black on cyan */
#define A_ASK	0x13		/* cyan on blue: not set */
#define A_HELP	0x1E		/* yellow on blue */
#define A_KEYS	0x70

static unsigned short far *Video;
static int Page = 0, Sel = 0, Changed = 0;
static char FileName[128];
static char Status[COLS + 1] = "";

/* ------------------------------------------------------------------ */

static void put (int row, int col, const char *s, int attr, int width)
{
	unsigned short far *v = Video + row * COLS + col;

	while (width-- > 0 && col++ < COLS) {
		*v++ = (attr << 8) | (unsigned char)(*s ? *s++ : ' ');
	}
}

static void cursor (int row, int col)
{
	union REGS r;

	r.h.ah = 2;
	r.h.bh = 0;
	r.h.dh = row;
	r.h.dl = col;
	int86 (0x10, &r, &r);
}

static void cursor_off (void)
{
	union REGS r;

	r.h.ah = 1;
	r.w.cx = 0x2000;
	int86 (0x10, &r, &r);
}

static void cursor_on (void)
{
	union REGS r;

	r.h.ah = 1;
	r.w.cx = 0x0607;
	int86 (0x10, &r, &r);
}

static int getkey (void)	/* extended keys: 0x100 + scan code */
{
	int c = getch ();

	if (c == 0 || c == 0xE0) return (0x100 + getch ());
	return (c);
}

#define K_UP	0x148
#define K_DOWN	0x150
#define K_LEFT	0x14B
#define K_RIGHT 0x14D
#define K_STAB	0x10F
#define K_DEL	0x153
#define K_F1	0x13B
#define K_F2	0x13C
#define K_HOME	0x147
#define K_END	0x14F

/* ------------------------------------------------------------------ */

/* Index in Options[] of the n-th option of the current page, -1: none */
static int page_option (int n)
{
	int i;

	for (i = 0; i < nOptions; i++) {
		if (stricmp (Options[i].sect, Pages[Page].sect)) continue;
		if (n-- == 0) return (i);
	}
	return (-1);
}

static int page_count (void)
{
	int n = 0;

	while (page_option (n) >= 0) n++;
	return (n);
}

/* The value as shown */
static const char *shown (const OPTION *o, char *buf)
{
	if (!o->value[0]) return (TxtAsk);
	if (o->type == OT_BOOL)
		return (opt_choiceindex (o) == 0 ? T("Yes", "Ja") : T("No", "Nein"));
	strcpy (buf, o->value);
	return (buf);
}

static void draw (void)
{
	char line[COLS + 1], buf[OPTVALLEN];
	int i, n, col, row;

	for (row = 0; row < ROWS; row++) put (row, 0, "", A_BACK, COLS);

	put (0, 0, T(" Open 386MAX - answers for the installation (SETUP.INF)",
		     " Open 386MAX - Antworten f\x81r die Installation (SETUP.INF)"), A_TITLE, COLS);
	sprintf (line, " %s%s", FileName, Changed ? " *" : "");
	put (1, 0, line, A_BACK, COLS);

	/* Tabs */
	for (col = 1, i = 0; i < nPages; i++) {
		sprintf (line, " %s ", Pages[i].title);
		put (3, col, line, i == Page ? A_TABON : A_TAB, strlen (line));
		col += strlen (line) + 1;
	}
	memset (line, 0xC4, COLS);	/* line under the tabs */
	line[COLS] = '\0';
	put (4, 0, line, A_BACK, COLS);

	/* Options of the page */
	for (n = 0; (i = page_option (n)) >= 0; n++) {
		OPTION *o = &Options[i];
		int attr = n == Sel ? A_SEL : (o->value[0] ? A_TITLE : A_ASK);

		row = FIRSTROW + n;
		if (o->type == OT_BOOL) {
			int ci = opt_choiceindex (o);

			sprintf (line, " [%c] %s", ci < 0 ? '?' : (ci == 0 ? 'X' : ' '), o->label);
		}
		else {
			sprintf (line, " %-30s %s", o->label, shown (o, buf));
		}
		put (row, 2, line, attr, COLS - 4);
	}

	/* Help of the selected option */
	if ((i = page_option (Sel)) >= 0) {
		put (HELPROW, 2, Options[i].help, A_HELP, COLS - 4);
		if (Options[i].type == OT_CHOICE) {
			sprintf (line, "%s: %s", T("Choices", "Auswahl"), Options[i].choices);
			put (HELPROW + 1, 2, line, A_HELP, COLS - 4);
		}
	}
	put (HELPROW + 2, 2, Status, A_HELP, COLS - 4);

	put (KEYROW, 0, T(" \x1B\x1A Page  \x18\x19 Option  Space Change  Enter Edit  Del Ask  F2 Save  Esc Quit",
			  " \x1B\x1A Seite  \x18\x19 Option  Leer \x8endern  Enter Text  Entf Fragen  F2 Speichern  Esc Ende"),
	     A_KEYS, COLS);
}

/* Next value: Yes, No, ask / choices..., ask */
static void next_value (OPTION *o)
{
	int n = opt_nchoices (o), ci = opt_choiceindex (o);

	if (o->type == OT_TEXT) return;
	if (ci < 0) ci = 0;		/* ask -> first */
	else if (++ci >= n) ci = -1;	/* last -> ask */
	if (ci < 0) o->value[0] = '\0';
	else opt_choice (o, ci, o->value, OPTVALLEN);
	Changed = 1;
}

/* Edit a text value in its line */
static void edit_text (OPTION *o, int row)
{
	char buf[OPTVALLEN];
	int len, c, col = 2 + 1 + 31;

	strcpy (buf, o->value);
	cursor_on ();
	for (;;) {
		len = strlen (buf);
		put (row, col, buf, A_TABON, COLS - col - 2);
		cursor (row, col + len);
		c = getkey ();
		if (c == 13) {
			strcpy (o->value, buf);
			Changed = 1;
			break;
		}
		if (c == 27) break;
		if (c == 8 && len) buf[len - 1] = '\0';
		else if (c >= ' ' && c < 0x100 && len < OPTVALLEN - 1 && len < COLS - col - 3) {
			buf[len] = (char)c;
			buf[len + 1] = '\0';
		}
	}
	cursor_off ();
}

static void save (void)
{
	if (opt_save (FileName))
		sprintf (Status, T("Cannot write %s", "Kann %s nicht schreiben"), FileName);
	else {
		sprintf (Status, T("Saved: %s", "Gespeichert: %s"), FileName);
		Changed = 0;
	}
}

/* ------------------------------------------------------------------ */

int main (int argc, char *argv[])
{
	union REGS r;
	int c, i, n;

	/* Default: SETUP.INF next to MAXCFG.EXE */
	if (argc > 1) strncpy (FileName, argv[1], sizeof (FileName) - 13);
	else {
		char *p;

		strncpy (FileName, argv[0], sizeof (FileName) - 13);
		p = strrchr (FileName, '\\');
		strcpy (p ? p + 1 : FileName, "SETUP.INF");
	}
	FileName[sizeof (FileName) - 1] = '\0';

	if (opt_load (FileName)) {
		opt_defaults ();
		strcpy (Status, T("New file: the defaults are set.", "Neue Datei: Voreinstellungen gesetzt."));
	}

	r.h.ah = 0x0F;			/* Video mode: 7 = monochrome */
	int86 (0x10, &r, &r);
	Video = (unsigned short far *)MK_FP (r.h.al == 7 ? 0xB000 : 0xB800, 0);
	cursor_off ();

	for (;;) {
		n = page_count ();
		if (Sel >= n) Sel = n - 1;
		if (Sel < 0) Sel = 0;
		draw ();
		c = getkey ();
		i = page_option (Sel);
		Status[0] = '\0';

		switch (c) {
		case K_LEFT:
		case K_STAB:
			Page = (Page + nPages - 1) % nPages;
			Sel = 0;
			break;
		case K_RIGHT:
		case 9:
			Page = (Page + 1) % nPages;
			Sel = 0;
			break;
		case K_UP:
			if (Sel > 0) Sel--;
			break;
		case K_DOWN:
			if (Sel < n - 1) Sel++;
			break;
		case K_HOME:
			Sel = 0;
			break;
		case K_END:
			Sel = n - 1;
			break;
		case ' ':
			if (i >= 0) {
				if (Options[i].type == OT_TEXT) edit_text (&Options[i], FIRSTROW + Sel);
				else next_value (&Options[i]);
			}
			break;
		case 13:
			if (i >= 0) {
				if (Options[i].type == OT_TEXT) edit_text (&Options[i], FIRSTROW + Sel);
				else next_value (&Options[i]);
			}
			break;
		case K_DEL:
			if (i >= 0) {
				Options[i].value[0] = '\0';
				Changed = 1;
			}
			break;
		case K_F2:
			save ();
			break;
		case 27:
			if (Changed) {
				strcpy (Status, T("Save the changes? (Y/N, Esc: back)",
						  "\x8enderungen speichern? (J/N, Esc: zur\x81\x63k)"));
				draw ();
				c = getkey ();
				if (c == 27) {
					Status[0] = '\0';
					break;
				}
				if (strchr ("YyJj", c)) {
					save ();
					if (Changed) break;	/* could not write */
				}
			}
			for (i = 0; i < ROWS; i++) put (i, 0, "", 0x07, COLS);
			cursor (0, 0);
			cursor_on ();
			return (0);
		}
	}
}
