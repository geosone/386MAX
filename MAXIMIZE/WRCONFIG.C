/******************************************************************************
 *									      *
 * (C) Copyright 1991-93 Qualitas, Inc.  GNU General Public License version 3.		      *
 *									      *
 * WRCONFIG.C								      *
 *									      *
 * Write CONFIG.SYS file						      *
 *									      *
 * The original source was not part of the published tree; this file was     *
 * reconstructed (Open 386MAX) from the shipped object MAXIMIZE\REB\WRCONFIG.OBJ *
 * and produces the same behavior.					      *
 *									      *
 ******************************************************************************/

/* System Includes */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Local includes */
#include <commfunc.h>		/* Common functions */
#include <intmsg.h>		/* Intermediate message functions */
#include <mbparse.h>		/* MultiBoot parse functions */

#define WRCONFIG_C
#include <maxtext.h>		/* MAXIMIZE message text */
#include <maxvar.h>		/* MAXIMIZE global variables */
#undef WRCONFIG_C

#ifndef PROTO
#include "browse.pro"
#include "copyfile.pro"
#include "maximize.pro"
#include "screens.pro"
#include "wrconfig.pro"
#endif /*PROTO*/

/************************************ WRCONFIG ********************************/

void wrconfig(int pass)
{
	char buff[258];
	FILE *fp;
	DSPTEXT *t;
	char *p;
	SECTNAME _far *sect = NULL; /* MultiBoot section being processed */
	int nskip = 0;

	if (pass == 1) {
		savefile(CONFIG);
		restbatappend(CONFIG);
	}

	if (AnyError) return;

	do_intmsg(MsgUpdConf);

	if (MultiBoot) sect = find_sect("menu");

	disable23();

	fp = fopen(ActiveFiles[CONFIG], "w");
	if (fp) {
		for (t = HbatStrt[CONFIG]; t && !AnyError; t = t->next) {
			switch (pass) {
			case 1:
				if (t->max == 1) {
					/* 386MAX line:  add the profile */
					strncpy(buff, t->text, t->nlead);
					sprintf(buff + t->nlead, "%s pro=%s\n",
						t->devicen, t->profilen);
					if (!AnyError)
						AnyError = (fputs(buff, fp) == EOF);
					break;
				}
				/* Fall through */

			case 2:
				if (t->text != MsgRedundant)
					fputs_text(br_buildcfg(t), fp);
				break;

			case 3:
				p = t->text;
				if (MultiBoot && sect && pass == 3 &&
				    t->MBOwner == sect->OwnerID) {
					if (t->MBtype == 'N' && !nskip) {
						nskip++;
						if (t = t->next) t = t->next;
					}
					else if (strstr(p, "REM mX~") == p) {
						p += 7;
					}
				}
				fputs_text(p, fp);
				break;
			}
		}

		fclose(fp);
		SwapUpdate(CONFIG);
	}
	else	AnyError = 1;

	if (AnyError) do_error(MsgErrConf, TRUE);

	enable23();
}

/* Write a line of text, add a newline if it has none */
void fputs_text(char *text, FILE *ot)
{
	int len;

	if (!AnyError) AnyError = (fputs(text, ot) == EOF);

	len = strlen(text);
	if (!len || text[len - 1] != '\n') {
		if (!AnyError) AnyError = (fputs("\n", ot) == EOF);
	}
}
