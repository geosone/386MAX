/* SETUPINF.C - answers of an unattended installation (SETUP.INF)
 *
 * A small INI reader for the DOS programs (the Windows programs use
 * GetPrivateProfileString): [section] lines, key=value lines, comments
 * after ';'.  Section and key names are case insensitive.
 *
 * Open 386MAX - GNU General Public License version 3.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <ctype.h>

#include "setupinf.h"

#define INFMAX	8192		/* Largest SETUP.INF we read */

int Unattended = 0;

static char *InfText = NULL;	/* The file, lines NUL terminated */
static unsigned InfLen = 0;
static char LogPath[128] = "";

/* Strip blanks at both ends (in place) */
static char *trim (char *s)
{
	char *e;

	while (*s == ' ' || *s == '\t') s++;
	e = s + strlen (s);
	while (e > s && (e[-1] == ' ' || e[-1] == '\t' || e[-1] == '\r' || e[-1] == '\n')) e--;
	*e = '\0';
	return (s);
}

int inf_load (const char *path)
{
	FILE *fp;
	unsigned n;
	char *p;

	if (InfText) return (0);
	fp = fopen (path, "rb");
	if (!fp) return (-1);
	InfText = malloc (INFMAX + 1);
	if (!InfText) {
		fclose (fp);
		return (-1);
	}
	n = fread (InfText, 1, INFMAX, fp);
	fclose (fp);
	InfText[n] = '\0';
	InfLen = n;

	/* Lines -> NUL terminated, comments removed */
	for (p = InfText; p < InfText + n; p++) {
		if (*p == '\n' || *p == '\r' || *p == 0x1A) *p = '\0';
	}
	for (p = InfText; p < InfText + n; p += strlen (p) + 1) {
		char *c = strchr (p, ';');

		if (c) *c = '\0';
	}

	Unattended = inf_bool ("Setup", "Unattended", 0);
	return (0);
}

int inf_loaded (void)
{
	return (InfText != NULL);
}

/* Next line of the file (NULL at the end) */
static char *nextline (char *p)
{
	if (!p) return (InfText);
	p += strlen (p) + 1;
	return (p < InfText + InfLen ? p : NULL);
}

const char *inf_get (const char *sect, const char *key)
{
	static char value[128];
	char line[160], *p, *l, *eq;
	int insect = 0;

	if (!InfText) return (NULL);
	for (p = nextline (NULL); p; p = nextline (p)) {
		strncpy (line, p, sizeof (line) - 1);
		line[sizeof (line) - 1] = '\0';
		l = trim (line);
		if (*l == '[') {
			char *e = strchr (l, ']');

			if (e) *e = '\0';
			insect = !stricmp (trim (l + 1), sect);
			continue;
		}
		if (!insect || !(eq = strchr (l, '='))) continue;
		*eq = '\0';
		if (stricmp (trim (l), key)) continue;
		strncpy (value, trim (eq + 1), sizeof (value) - 1);
		value[sizeof (value) - 1] = '\0';
		return (*value ? value : NULL);	/* Empty: as if absent */
	}
	return (NULL);
}

int inf_bool (const char *sect, const char *key, int def)
{
	const char *v = inf_get (sect, key);

	if (!v) return (def);
	switch (toupper (*v)) {
	case '1': case 'Y': case 'J': case 'T':	/* 1 Yes Ja True */
		return (1);
	case 'O':			/* On / Off */
		return (toupper (v[1]) == 'N');
	}
	return (0);
}

int inf_section (const char *sect)
{
	char line[160], *p, *l;
	int insect = 0;

	if (!InfText) return (0);
	for (p = nextline (NULL); p; p = nextline (p)) {
		strncpy (line, p, sizeof (line) - 1);
		line[sizeof (line) - 1] = '\0';
		l = trim (line);
		if (*l == '[') {
			char *e = strchr (l, ']');

			if (e) *e = '\0';
			insect = !stricmp (trim (l + 1), sect);
			continue;
		}
		if (insect && strchr (l, '=')) {
			char *eq = strchr (l, '=');

			if (*trim (eq + 1)) return (1);	/* A key with a value */
		}
	}
	return (0);
}

void inf_logfile (const char *path)
{
	strncpy (LogPath, path, sizeof (LogPath) - 1);
	LogPath[sizeof (LogPath) - 1] = '\0';
}

void inf_log (const char *fmt, ...)
{
	FILE *fp;
	va_list ap;

	if (!*LogPath || !(fp = fopen (LogPath, "a"))) return;
	va_start (ap, fmt);
	vfprintf (fp, fmt, ap);
	va_end (ap);
	fputs ("\n", fp);
	fclose (fp);
}
