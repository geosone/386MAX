/******************************************************************************
 *									      *
 * (C) Copyright 1991-96 Qualitas, Inc.  GNU General Public License version 3. *
 *									      *
 * ASQINFO.C								      *
 *									      *
 * The ASQ summaries of the MAX shell: ASQ writes them (/Y1 /W) into	      *
 * ASQSUMM.OUT; they are shown in windows like ASQ shows its data.	      *
 *									      *
 * Reconstructed for Open 386MAX from the original MAX.EXE and ASQDATA.C.     *
 *									      *
 ******************************************************************************/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "button.h"
#include "commfunc.h"
#include "libcolor.h"
#include "libtext.h"
#include "qhelp.h"
#include "qprint.h"
#include "qwindows.h"
#include "screen.h"
#include "stacker.h"
#include "ui.h"
#include "asqshare.h"

#include "qshtext.h"
#include "qshell.h"

/*	Lines of ASQSUMM.OUT: "|cf|text", c = count of description characters
 *	+ QS_CODE_BASE, f = format (QS_CENTER_LINE) */
#define QS_CODE_BASE	' '
#define QS_IEXTRA		4
#define QS_CENTER_LINE	('~' - QS_CODE_BASE)
#define QS_CONTIN_LINE	-1

/*	One ASQ summary in the data window */
void presentAsq(int request, int helpNum)
{
	TEXTWIN text;
	WINDESC workWin;
	void *behind;
	int which, noData, nrows, ncols, err, len, count, format, nc;
	char line[256];
	char *dataLine, *start;

	which = asqinfo_lookup(request);
	noData = !AsqFile || which < 0 || which >= AsqCount ||
		AsqLen[which] < 1 || AsqWid[which] < 1;

	memset(&text, 0, sizeof(text));
	behind = win_save(&DataWin, TRUE);
	if (!behind) return;
	wput_sca(&DataWin, VIDWORD(DataColor, ' '));

	if (noData) {
		nrows = 2;
		ncols = DataWin.ncols - 2;
	}
	else {
		fseek(AsqFile, AsqPos[which], SEEK_SET);
		ncols = AsqWid[which];
		nrows = AsqLen[which];
	}

	err = vWin_create(&text, &DataWin,
		nrows + 1 > DataWin.nrows - 2 ? nrows + 1 : DataWin.nrows - 2,
		ncols + 1 > DataWin.ncols - 2 ? ncols + 1 : DataWin.ncols - 2,
		DataColor, SHADOW_DOUBLE, BORDER_BLANK,
		nrows > DataWin.nrows - 3, ncols > DataWin.ncols - 3, FALSE, TRUE);
	if (err) {
		errorMessage(err);
	}
	else {
		workWin = DataWin;
		workWin.nrows = 1;
		justifyString(&workWin, AsqTitles[which < 0 ? 0 : which], -1,
			JUSTIFY_CENTER, DataYellowColor, DataYellowColor);

		workWin.row = 1;
		workWin.col = 0;
		if (noData) {
			workWin.col = (ncols + 2 - strlen(AsqDataError)) / 2;
			vWin_put_s(&text, workWin.row, workWin.col, AsqDataError);
		}
		else {
			while (workWin.row <= nrows && fgets(line, sizeof(line), AsqFile)) {
				len = strlen(line);
				if (len > 0 && line[len - 1] == '\n') line[len - 1] = '\0';

				workWin.col = 0;
				len = 0;
				count = line[1] - QS_CODE_BASE;
				dataLine = line + QS_IEXTRA;
				format = line[2] - QS_CODE_BASE;
				if (format == QS_CENTER_LINE) {
					/* Handle centered lines */
					nc = (DataWin.ncols - strlen(dataLine)) / 2;
					if (nc > 0) workWin.col += nc;
				}

				if (count >= 0) {
					start = dataLine + count;
					len = count;
				}
				else if (count == QS_CONTIN_LINE) {
					/*	Continuation line - Indent is in 1st position */
					workWin.col = dataLine[0] - '0';
					start = dataLine + workWin.col;
				}
				else start = dataLine;

				/*	The description in yellow */
				if (len > 0) {
					workWin.ncols = len;
					vWinPut_sca(&text, &workWin, dataLine, DataYellowColor);
					workWin.col += len;
				}
				else if (count == QS_CONTIN_LINE) {
					vWin_put_a(&text, workWin.row, workWin.col++, (char)DataContinueColor);
					start++;
				}
				/*	The value in white */
				vWin_put_s(&text, workWin.row, workWin.col, start);
				workWin.row++;
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
	win_restore(behind, TRUE);
}

/*	Read the names of the system files and find the summaries in
 *	ASQSUMM.OUT */
void initAsq(void)
{
	char line[256];
	FILE *fp;
	int n;

	get_exepath(line, sizeof(line));
	strcat(line, ASQOUTFILE);
	if ((fp = fopen(line, "r")) != NULL) {
		memset(AsqPos, 0, sizeof(AsqPos));
		memset(AsqFlag, 0, sizeof(AsqFlag));
		memset(AsqWid, 0, sizeof(AsqWid));
		memset(AsqLen, 0, sizeof(AsqLen));
		if (fgets(ConfigName, 80, fp) && (trim(ConfigName), fgets(AutoexecName, 80, fp)) &&
				(trim(AutoexecName), fgets(MAXName, 80, fp)) &&
				(trim(MAXName), fgets(ExtraDOSName, 80, fp)) &&
				(trim(ExtraDOSName), fgets(SYSININame, 80, fp))) {
			trim(SYSININame);
			if (SwappedDrive < 1) check_swap(*ConfigName, *line);

			for (n = 0; fgets(line, sizeof(line), fp); ) {
				if (*line != '!') continue;
				AsqPos[n] = ftell(fp);
				sscanf(line + 1, "%d %d %d", &AsqNum[n], &AsqWid[n], &AsqLen[n]);
				if (++n >= MAXASQ) break;
			}
			AsqFileLength = ftell(fp);
			fseek(fp, 0L, SEEK_SET);
			AsqFile = fp;
			AsqCount = n;
			return;
		}
		fclose(fp);
	}
	AsqCount = 0;
	AsqFile = NULL;
}

/*	Index of an ASQ report (info number) in ASQSUMM.OUT, -1 if none */
int asqinfo_lookup(int num)
{
	int i;

	for (i = 0; i < AsqCount; i++) {
		if (AsqNum[i] == num) return i;
	}
	return -1;
}
