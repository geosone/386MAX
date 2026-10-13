/******************************************************************************
 *									      *
 * (C) Copyright 1991-96 Qualitas, Inc.  GNU General Public License version 3. *
 *									      *
 * UTILINFO.C								      *
 *									      *
 * The Info menu of the MAX shell: runs 386UTIL (or MOVE'EM) once with all    *
 * its reports into MAXUTIL.OUT and shows the reports in windows.	      *
 *									      *
 * Reconstructed for Open 386MAX from the original MAX.EXE.		      *
 *									      *
 ******************************************************************************/

#include <dos.h>
#include <io.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "button.h"
#include "ui.h"
#include "commfunc.h"
#include "intmsg.h"
#include "libcolor.h"
#include "libtext.h"
#include "qhelp.h"
#include "qprint.h"
#include "qwindows.h"
#include "screen.h"

#include "qshtext.h"
#include "qshell.h"

#define ERR_NO386UTIL	550	/* 386UTIL.COM not found */
#define ERR_RUN386UTIL	551	/* 386UTIL.COM didn't run */
#define ERR_NOMOVEEM	557	/* MOVE'EM.COM not found */
#define ERR_RUNMOVEEM	558	/* MOVE'EM.COM didn't run */

#define TIMEPOS 	6	/* Time memory: two lines left out */

/*	Which product made the reports: 0 none, 1 386MAX, 2 Move'em */
static int UtilProduct;

/*	One report in a window */
void presentUtil(int request, int helpNum)
{
	TEXTWIN text;
	WINDESC win, title;
	void *behind = NULL;
	int which = request - QS_OVERVIEW;
	int noData, nrows, ncols, row, col, n, len, err;
	char line[256];

	noData = !UtilFile || which < 0 || which >= UtilCount ||
		UtilLen[which] < 1 || UtilWid[which] < 1;

	memset(&text, 0, sizeof(text));
	win = DataWin;
	if (!noData) {
		/*	Use the quick help area too */
		win.ncols = QuickWin.col + QuickWin.ncols - win.col;
	}
	behind = win_save(&win, TRUE);
	if (!behind) return;
	wput_sca(&win, VIDWORD(DataColor, ' '));

	if (noData) {
		nrows = 2;
		ncols = win.ncols - 2;
	}
	else {
		fseek(UtilFile, UtilPos[which], SEEK_SET);
		ncols = UtilWid[which];
		nrows = UtilLen[which];
		if (which == TIMEPOS) nrows -= 2;
	}

	err = vWin_create(&text, &win,
		nrows + 1 > win.nrows - 2 ? nrows + 1 : win.nrows - 2,
		ncols > win.ncols - 2 ? ncols : win.ncols - 2,
		DataColor, SHADOW_DOUBLE, BORDER_BLANK,
		nrows > win.nrows - 3, ncols > win.ncols - 2, FALSE, TRUE);
	if (err) {
		errorMessage(err);
	}
	else {
		title = win;
		title.nrows = 1;
		justifyString(&title, UtilTitles[which], -1, JUSTIFY_CENTER,
			DataYellowColor, DataYellowColor);

		row = 1;
		col = 0;
		if (noData) {
			col = (ncols + 2 - strlen(UtilDataError)) / 2;
			vWin_put_s(&text, row, col, UtilDataError);
		}
		else {
			for (n = 0; row <= nrows && fgets(line, sizeof(line), UtilFile); ) {
				n++;
				/*	The time report's second and third lines are left out */
				if (which == TIMEPOS && n >= 2 && n <= 3) continue;
				len = strlen(line);
				if (len > 0 && line[len - 1] == '\n') line[len - 1] = '\0';
				vWin_put_s(&text, row, col, line);
				row++;
			}
		}

		setButtonText(KEY_ESCAPE, MenuEsc, 5);
		do {
			if (vWin_ask(&text, NULL) == WIN_BUTTON) {
				pushButton(LastButton.number);
				if (LastButton.key == KEY_F1) {
					showHelp(helpNum, FALSE);
					continue;
				}
				if (LastButton.key == KEY_F2) {
					doPrint(&text, P_MENU, request, helpNum, FALSE);
					continue;
				}
			}
		} while (LastButton.key != KEY_ESCAPE);
		if (text.data) vWin_destroy(&text);
	}
	if (behind) win_restore(behind, TRUE);
}

/*	Run 386UTIL (or MOVE'EM) with all reports into MAXUTIL.OUT */
void run386Util(void)
{
	char path[128], msg[80], outname[128];
	char psp[10], number[8];
	char *argv[16];
	char *util;
	int argc, fh, savefh;
	unsigned written;

	if (qmaxpres(NULL, NULL)) {
		util = "386UTIL.COM";
		UtilProduct = 1;
	}
	else if (qmovpres(NULL, NULL)) {
		util = "MOVE'EM.COM";
		UtilProduct = 2;
	}
	else {
		UtilProduct = 0;
		return;
	}

	get_exepath(path, sizeof(path));
	strcat(path, util);
	if (access(path, 0) == -1) {
		errorMessage(UtilProduct == 1 ? ERR_NO386UTIL : ERR_NOMOVEEM);
		return;
	}

	argc = 0;
	argv[argc++] = path;
	sprintf(psp, "PSP=%04X", _psp);
	argv[argc++] = psp;
	if (UtilProduct == 1) {
		argv[argc++] = "LIST";
		argv[argc++] = "MAPEMS";
	}
	argv[argc++] = "MAPMEM";
	argv[argc++] = "MAPDEV";
	argv[argc++] = "SUMMARY";
	if (UtilProduct == 1) {
		argv[argc++] = "ROMSCAN";
		argv[argc++] = "TIMEMEM";
	}
	argv[argc++] = NULL;

	/*	Output into MAXUTIL.OUT: first line is the product */
	get_exepath(outname, sizeof(outname));
	strcat(outname, UTILOUTFILE);
	if (_dos_creat(outname, _A_NORMAL, &fh)) {
		UtilProduct = 0;
		return;
	}
	savefh = dup(1);
	dup2(fh, 1);
	_dos_close(fh);

	disable23();
	intmsg_setup(12);
	sprintf(msg, RunningUtil, util);
	do_intmsg(msg);
	move_cursor(DataWin.row, DataWin.col);

	sprintf(number, "%d\r\n", UtilProduct);
	_dos_write(1, number, strlen(number), &written);
	if (spawnvp(P_WAIT, argv[0], (const char * const *)argv) == -1) {
		errorMessage(UtilProduct == 1 ? ERR_RUN386UTIL : ERR_RUNMOVEEM);
	}
	intmsg_clear();

	dup2(savefh, 1);
	_dos_close(savefh);
	enable23();
}

/*	Find the reports in MAXUTIL.OUT */
void initUtil(void)
{
	char line[128];
	FILE *fp;
	long pos;
	int which, count, len, first;

	UtilFile = NULL;
	get_exepath(line, sizeof(line));
	strcat(line, UTILOUTFILE);
	if ((fp = fopen(line, "r")) == NULL) return;

	memset(UtilPos, 0, sizeof(UtilPos));
	memset(UtilWid, 0, sizeof(UtilWid));
	memset(UtilLen, 0, sizeof(UtilLen));
	count = 0;
	if (!fgets(line, sizeof(line), fp)) {
		fclose(fp);
		return;
	}
	UtilProduct = 0;
	sscanf(line, "%d", &UtilProduct);
	/*	Move'em has no overview and no EMS report */
	which = UtilProduct == 2 ? 2 : 0;
	pos = ftell(fp);
	UtilPos[which] = pos;

	first = TRUE;
	while (fgets(line, sizeof(line), fp)) {
		/*	A report starts with a box, or without EMS memory with its
		 *	message; the load sizes with an arrow */
		if (line[0] == '\xD5' ||
				(which == 0 && !memicmp(line, "No EMS memory", 13)) ||
				(which == 4 && !memicmp(line, "\a\xCD\xCD>", 4))) {
			if (first) first = FALSE;
			else if (which < MAXUTILS - 1) {
				UtilLen[which] = count;
				count = 0;
				which++;
				UtilPos[which] = pos;
			}
		}
		len = strlen(line);
		if (len > UtilWid[which]) UtilWid[which] = len;
		count++;
		pos = ftell(fp);
	}
	fseek(fp, 0L, SEEK_SET);
	UtilCount = which + 1;
	UtilLen[which] = count;
	UtilFile = fp;
}
