/******************************************************************************
 *									      *
 * (C) Copyright 1991-93 Qualitas, Inc.  GNU General Public License version 3.		      *
 *									      *
 * WRFILES3.C								      *
 *									      *
 * Write the files at the end of MAXIMIZE pass 3			      *
 *									      *
 * The original source was not part of the published tree; this file was     *
 * reconstructed (Open 386MAX) from the shipped object MAXIMIZE\REB\WRFILES3.OBJ *
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
#include <stacker.h>		/* Swapped drive support */

#define WRFILES3_C
#include <maxtext.h>		/* MAXIMIZE message text */
#include <maxvar.h>		/* MAXIMIZE global variables */
#undef WRFILES3_C

#ifndef PROTO
#include "copyfile.pro"
#include "maximize.pro"
#include <maxsub.pro>
#include "parse.pro"
#include "pass2.pro"
#include "proccfg1.pro"
#include "screens.pro"
#include "wrconfig.pro"
#include "wrfiles3.pro"
#endif /*PROTO*/

/************************************ WRFILES3 ********************************/

void wrfiles3(void)
{
	char path[80];

	if (AnyError) return;

	wrconfig(Pass);
	wrprofile(FALSE, FALSE);
	wrbatfile(Pass);

	/* Restore AUTOEXEC.BAT from AUTOEXEC.ABETA and delete the copy */
	strcpy(path, ActiveFiles[AUTOEXEC]);
	strcpy(strchr(path, '.'), "." ABETA);
	copyfile(path, ActiveFiles[AUTOEXEC]);
	do_intmsg(MsgDelAbeta);
	remove(path);

	if (SwappedDrive > 0 && CopyBoot) {
		path[0] = CopyBoot;
		remove(path);
	}

	SwapUpdate(AUTOEXEC);

#ifdef HARPO
	if (!maxcfg.noharpo) {
		if (harpo_pro() && *Harpo_profile) {
			do_intmsg(MsgHarpoPro);
			wrharpo();
		}
		else	do_error(MsgNoHarpoPro, FALSE);
	}
#endif /* ifdef HARPO */
}

#ifdef HARPO
/* Find the SubsIDs[] entry for a subsegment (the first entry if none) */
SUBSID *subsid(SUBFIT far *psubseg)
{
	SUBSID *psid;
	SUBSID *found;

	found = SubsIDs;
	for (psid = SubsIDs + 1; psid->type; psid++) {
		if (psid->owner == psubseg->ownr &&
		    psid->type == psubseg->type) found = psid;
	}
	return found;
}

/* Write the HARPO (ExtraDOS) profile */
void wrharpo(void)
{
	HARPOPROF *h;
	SUBFIT far *psub;
	SUBSID *psid;
	char buff[88];
	int reg;

	if (!read_harpopro()) return;

	/* Throw away GETSIZE and our old subsegment lines */
	for (h = HarpoPro; h; h = h->next) {
		switch (h->optype) {
		case HOPT_GETSIZE:
			h->optype = HOPT_DEADMAN;
			break;

		case HOPT_SUBSEG:
		case HOPT_CCOM:
			if (_strnicmp(h->arg1, "NOLOADHI", 8))
				h->optype = HOPT_DEADMAN;
			break;
		}
	}

	/* Add the HARPO subsegments */
	for (psub = psubsegs; psub && psub->lseg; psub++) {
		if (psub->ownr == SFO_HARPO) {
			psid = subsid(psub);
			sprintf(buff, "%s%s", psid->keywd, psid->comment);
			add2harpopro(0, buff,
				(DWORD) psub->rpara << 4, psub->newreg,
				psub->newreg, (DWORD) psub->rpara << 4);
		}
	}

	/* COMMAND.COM and its environment */
	if (HarpoComspec) {
		sprintf(buff, "C=%%5lu,%%d%s", MsgComspec);
		add2harpopro(0, buff,
			(DWORD) HarpoComspec->ipara << 4, HarpoComspec->preg,
			HarpoComspec->preg, (DWORD) HarpoComspec->ipara << 4);

		if (HarpoComspec->epar0) {
			reg = HarpoComspec->ereg ? HarpoComspec->ereg
						 : HarpoComspec->preg;
			sprintf(buff, "E=%%5lu,%%d%s", MsgEnvironment);
			add2harpopro(0, buff,
				((DWORD) HarpoComspec->epar0 - 1) << 4, reg,
				reg, ((DWORD) HarpoComspec->epar0 - 1) << 4);
		}
	}

	close_harpopro(TRUE);
}
#endif /* ifdef HARPO */
