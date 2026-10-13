/******************************************************************************
 *									      *
 * (C) Copyright 1991-96 Qualitas, Inc.  GNU General Public License version 3. *
 *									      *
 * QMAIN.C								      *
 *									      *
 * Main program module for MAX.EXE (the MAX shell): menus, the editors of     *
 * the system files and the start of ASQ, Maximize and Update.		      *
 *									      *
 * Reconstructed for Open 386MAX from the original MAX.EXE (its symbol       *
 * table and line numbers, MAX.MAP and MAX.SSF) and the sibling sources of    *
 * ASQ (AMAIN.C).							      *
 *									      *
 ******************************************************************************/

/*	C function includes */
#include <ctype.h>
#include <dos.h>
#include <fcntl.h>
#include <io.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <process.h>
#include <sys/types.h>
#include <sys/stat.h>

/*	Program Includes */

#include "button.h"
#include "commfunc.h"
#include "dialog.h"
#include "editwin.h"
#include "intmsg.h"
#include "libcolor.h"
#include "libtext.h"
#include "mbparse.h"
#include "menu.h"
#include "message.h"
#include "mouse.h"
#include "myalloc.h"
#include "options.h"
#include "qprint.h"
#include "qhelp.h"
#include "screen.h"
#include "stacker.h"
#include "ui.h"
#include "asqshare.h"
#include "bioscrc.h"

#define OWNER
#include "qshtext.h"
#include "qshell.h"

/*	Error numbers (ERROR.C) */
#define ERR_NOMAXIMIZE	552	/* MAXIMIZE.EXE not found */
#define ERR_NOUPDATE	553	/* UPDATE.EXE not found */
#define ERR_NOASQ	556	/* ASQ.EXE not found */
#define ERR_SERIAL	559	/* bad serial number */

/*	The CONFIG.SYS section we work on ("[name]" for the editor) */
static char *CfgSect;

static int _cdecl _far QCallBack(CONFIGLINE _far *cfg);

/*	Program Code */
/**
*
* Name		Main - Core function
*
* Synopsis	int main(int argc, char *argv[])
*
* Description
*		Paint the main screen and run the menus.  The programs we start
*	(ASQ, Maximize, Update) run after we exit (execv); they start us again
*	with /Y.
*
* Returns	0 for no errors
*
*/
int main(int argc, char *argv[])
{
	int request = 0;
	int buttonsBad = TRUE;
	int forcePaint = TRUE;
	int result, help;
	char *p;
	char path[128];
	char exepath[244];
	int len;
	FILE *fp;

	/*	The editor's callbacks */
	CB_option_editor = option_editor;
	CB_option_replace = option_replace;
	CB_option_insert = option_insert;
	highlight_areaCB = highlight_area;
	save_changesCB = save_changes;
	cursor3CB = cursor3;
	cursor4CB = cursor4;
	cursor5CB = cursor5;
	askFileNameCB = askFileName;
	get_pathCB = get_path;
	optsActive = OLF_386MAX;

	/* allocate a 1K universal reserve buffer */
	globalReserve = my_malloc(1000);

	set_exename(argv[0], "MAX.EXE");
	setOptions(argc, argv);
	if (fromExec >= 0) readState();

	inst2324();
	enable23();

	read_cfg();

	/*	The active MultiConfig section */
	p = getenv("CONFIG");
	if (p) {
		sprintf(path, "[%s]", p);
		CfgSect = strdup(path);
	}
	else CfgSect = NULL;

	initializeScreenInfo(SnowControl);
	setColors();

	init_input(NULL);
	strcpy(PrintFile, "MAX.PRN");

	hide_cursor();
	set_cursor(thin_cursor());
	if (fromExec == 0) paintBackgroundScreen();

	/*	Initialize the help system - Die if we fail - Starthelp gives the error */
	if (startHelp(HelpFileName, HELPLAST)) goto done;

	if (fromExec < 0) {
		if (sayHello(GraphicsLogo)) goto done;
	}
	wput_csa(&programNameWin, ProgramName, ProgramNameAttr);
	halfShadow(&programNameWin);

	if (!doEdit || !doCmdThenExit) {
		if (!EditOnly) {
			if (fromExec < 1) {
				/*	First start: analyze the system */
				if (doEval()) goto done;
				if (execAsq(1)) goto done;
			}
			initAsq();
			initUtil();
		}

		strcpy(ConfigName, "C:\\config.sys");
		strcpy(AutoexecName, "C:\\autoexec.bat");
		*MAXName = '\0';
		if (!BootDrive) BootDrive = get_bootdrive();
		ConfigName[0] = BootDrive;
		AutoexecName[0] = BootDrive;
		if (!menu_parse(BootDrive, 0)) {
			if (CfgSect) set_current(getenv("CONFIG"));
			if (!config_parse(BootDrive, ActiveOwner, NULL, 0, QCallBack)) {
				strcpy(ConfigName, ConfigSys);
				strcpy(AutoexecName, StartupBat);
				if (*MaxHomeDir) {
					sprintf(LoadCfgName, "%s%s.CFG", MaxHomeDir, LoaderName);
				}
			}
		}
		_searchenv("SYSTEM.INI", "PATH", SYSININame);
		if (SwappedDrive < 1) {
			get_exepath(path, sizeof(path));
			check_swap(*ConfigName, *path);
		}
	}

	if (EditOnly) {
		MainMenu.items[MAIN_MAXPOS].type = ITEM_DISABLED;
		MainMenu.items[MAIN_MAXPOS+1].type = ITEM_DISABLED;
		MainMenu.items[MAIN_ASQPOS].type = ITEM_DISABLED;
		FileMenu.items[FILE_UPDPOS].type = ITEM_DISABLED;
	}
	else if (!qmaxpres(NULL, NULL)) {
		/*	386MAX isn't loaded */
		InfoMenu.items[0].type = ITEM_DISABLED;
		InfoMenu.items[INFO_EMSPOS].type = ITEM_DISABLED;
		InfoMenu.items[INFO_ROMPOS].type = ITEM_DISABLED;
		InfoMenu.items[INFO_TIMEPOS].type = ITEM_DISABLED;
		if (Is_VM()) {
			/*	No Maximize in a DOS box */
			MAXIMIZEMenu.items[MAX_EXPPOS].type = ITEM_DISABLED;
			MAXIMIZEMenu.items[MAX_CUSPOS].type = ITEM_DISABLED;
			MainMenu.items[MAIN_MAXPOS].type = ITEM_DISABLED;
		}
		if (!qmovpres(NULL, NULL)) {
			/*	Neither is Move'em: no information */
			InfoMenu.items[INFO_RESPOS].type = ITEM_DISABLED;
			InfoMenu.items[INFO_DEVPOS].type = ITEM_DISABLED;
			InfoMenu.items[INFO_LOADPOS].type = ITEM_DISABLED;
			MainMenu.items[MAIN_MAXPOS+1].type = ITEM_DISABLED;

			/*	Options of the products installed with us */
			get_exepath(exepath, sizeof(exepath));
			len = strlen(exepath);
			strcat(exepath, "Move'em.mgr");
			if (!access(exepath, 0)) {
				optsActive = OLF_MOVE;
				AsqTitles[ASQT_PROFILE] = AsqTitles[ASQT_MOVEEM];
			}
			strcpy(exepath + len, "386MAX.sys");
			if (!access(exepath, 0)) optsActive |= OLF_386MAX;
			strcpy(exepath + len, "BlueMAX.sys");
			if (!access(exepath, 0)) optsActive |= OLF_BLUEMAX;
		}
		else {
			optsActive = OLF_MOVE;
			AsqTitles[ASQT_PROFILE] = AsqTitles[ASQT_MOVEEM];
		}
	}
	else {
		AsqTitles[ASQT_PROFILE] = AsqTitles[ASQT_386MAX];
	}

	/*	Files we don't have can't be edited */
	if (!*MAXName) FileMenu.items[FILE_PROPOS].type = ITEM_DISABLED;
	if (!*ExtraDOSName) FileMenu.items[FILE_EXTPOS].type = ITEM_DISABLED;
	if (!*SYSININame) FileMenu.items[FILE_SYSPOS].type = ITEM_DISABLED;
	if (!*LoadCfgName) FileMenu.items[FILE_LOADPOS].type = ITEM_DISABLED;

	for (;;) {
		if (buttonsBad) {
			blastButtons();
			addButton(MainButtons, 3, NULL);
			showAllButtons();
			buttonsBad = FALSE;
		}
		helpSystem = HELPMCONTENTS;
		PrintProgramName = ProgramName;

		if (doEdit) {
			/*	/E or /R with a file */
			showMenu((PMENU)&MainMenu, MENU_DISABLED);
			fileEdit(HELPEDITOR, 0, doEdit, BrowseMode, NULL);
			if (doCmdThenExit) goto done;
			doEdit = NULL;
		}

		showMenu((PMENU)&MainMenu, MENU_VISIBLE);
		result = askMenu((PMENU)&MainMenu, NULL, &request, forcePaint);
		if (result == MENU_BUTTON && LastButton.key == KEY_ESCAPE) {
			/*	Escape: go to Exit */
			pushButton(LastButton.number);
			hideMenu(MainMenu.items[MainMenu.info.active].lower);
			MainMenu.info.active = 0;
			FileMenu.info.active = NUMFILEMENUITEMS - 1;
			forcePaint = TRUE;
			continue;
		}

		switch (result) {
		case MENU_DIRECT:
			hideMenu(MainMenu.items[MainMenu.info.active].lower);
			showMenu((PMENU)&MainMenu, MENU_DISABLED);
			forcePaint = FALSE;
			switch (request) {
			case QS_MEMSUM:
				presentAsq(request, HELP_Mem_Sum);
				buttonsBad = TRUE;
				break;
			case QS_CFGSUM:
				presentAsq(request, HELP_Cfg_Sum);
				buttonsBad = TRUE;
				break;
			case QS_HDWSUM:
				presentAsq(request, HELP_Hdw_Sum);
				buttonsBad = TRUE;
				break;
			case QS_EDITCFG:
				fileEdit(HELPEDITOR, 0, ConfigName, 0, CfgSect);
				SwapUpdate(ConfigName, CopyBoot);
				buttonsBad = forcePaint = TRUE;
				break;
			case QS_EDITAUT:
				fileEdit(HELPEDITOR, 0, AutoexecName, 0, CfgSect);
				SwapUpdate(AutoexecName, CopyBoot);
				buttonsBad = forcePaint = TRUE;
				break;
			case QS_EDITPRO:
				fileEdit(HELPEDITOR, 0, MAXName, 0, CfgSect);
				SwapUpdate(MAXName, CopyMax1);
				SwapUpdate(MAXName, CopyMax2);
				buttonsBad = forcePaint = TRUE;
				break;
			case QS_EDITEXT:
				fileEdit(HELPEDITOR, 0, ExtraDOSName, 0, CfgSect);
				SwapUpdate(ExtraDOSName, CopyMax1);
				SwapUpdate(ExtraDOSName, CopyMax2);
				buttonsBad = forcePaint = TRUE;
				break;
			case QS_EDITSYS:
				fileEdit(HELPEDITOR, 0, SYSININame, 0, NULL);
				buttonsBad = forcePaint = TRUE;
				break;
			case QS_EDITLOAD:
				fileEdit(HELPEDITOR, 0, LoadCfgName, 0, NULL);
				SwapUpdate(LoadCfgName, CopyMax1);
				SwapUpdate(LoadCfgName, CopyMax2);
				buttonsBad = forcePaint = TRUE;
				break;
			case QS_EDITOTHER:
				fileEdit(HELPEDITOR, 0, NULL, 0, NULL);
				buttonsBad = forcePaint = TRUE;
				break;
			case QS_UPDATE:
				if (execUpdate()) goto done;
				forcePaint = TRUE;
				break;
			case QS_EXIT:
				goto done;
			case QS_ASQ:
				if (execAsq(0)) goto done;
				break;
			case QS_EXPRESS:
			case QS_CUSTOM:
				if (execMaximize(request)) goto done;
				break;
			case QS_OVERVIEW:
			case QS_EMS:
			case QS_RESIDENT:
			case QS_DEVICES:
			case QS_LOADSIZES:
			case QS_ROMSCAN:
			case QS_TIMEMEM:
				presentUtil(request, request - QS_OVERVIEW + HELP_Info_Mem);
				forcePaint = buttonsBad = TRUE;
				break;
			case QS_HTOPICS:
			case QS_HINDEX:
			case QS_HHELP:
			case QS_HMENUS:
			case QS_HDIALOGS:
			case QS_HPRINT:
			case QS_HEDITOR:
				help = request - QS_HTOPICS;	/* HELPMCONTENTS .. HELPEDITOR */
				showHelp(help, FALSE);
				forcePaint = TRUE;
				break;
			}
			break;
		case MENU_BUTTON:
			pushButton(LastButton.number);
			break;
		}
	}

done:
	endHelp();
	end_input();
	done2324();

	if (ExecArgv[0]) {
		/*	Run the program and come back (/Z) */
		saveState();
		if (UseArgfile) {
			int i;

			fp = fopen(RSPFILE, "w");
			for (i = 1; ExecArgv[i]; i++) {
				fprintf(fp, "%s\n", ExecArgv[i]);
			}
			fclose(fp);
			ExecArgv[1] = "@" RSPFILE;
			ExecArgv[2] = NULL;
		}
		execv(ExecArgv[0], (const char * const *)ExecArgv);
	}
	remove(RSPFILE);

	move_cursor(ScreenSize.row - 1, 0);
	show_cursor();
	set_cursor(thin_cursor());
	SETWINDOW(&DataWin, 0, 0, ScreenSize.row, ScreenSize.col);
	wput_sca(&DataWin, VIDWORD(0x07, ' '));

	if (globalReserve) my_free(globalReserve);
	return 0;
}

/*	MBPARSE callback for each CONFIG.SYS line: finds 386MAX (or BlueMAX,
 *	Move'em) and ExtraDOS and the names of their profiles */
static int _cdecl _far QCallBack(CONFIGLINE _far *cfg)
{
	char line[512];
	char drive[_MAX_DRIVE], dir[_MAX_DIR], fname[_MAX_FNAME], ext[_MAX_EXT];
	char _far *tok;
	char *target;

	if (!cfg->line || cfg->ID != ID_DEVICE) return 0;
	_fstrncpy(line, cfg->line, sizeof(line) - 1);
	line[sizeof(line) - 1] = '\0';
	if ((tok = strchr(line, '\n')) != NULL) *tok = '\0';

	if (!(tok = strtok(line, ValPathTerms))) return 0;
	if (strnicmp(tok, "device", 6)) return 0;
	if (!(tok = strtok(NULL, ValPathTerms))) return 0;
	_splitpath(tok, drive, dir, fname, ext);

	if (!stricmp(fname, "EXTRADOS")) {
		target = ExtraDOSName;
	}
	else if (*MaxHomeDir) {
		return 0;
	}
	else {
		if (!stricmp(fname, "386MAX") || !stricmp(fname, "BLUEMAX")) {
			target = MAXName;
		}
		else if (!stricmp(fname, MoveName)) {
			target = MAXName;
			LoaderName = MoveName;
		}
		else return 0;
		sprintf(MaxHomeDir, "%s%s", drive, dir);
	}

	/*	The profile: pro=d:\path\name */
	while ((tok = strtok(NULL, ValPathTerms)) != NULL) {
		if (!stricmp(tok, "pro")) {
			if ((tok = strtok(NULL, ValPathTerms)) != NULL) {
				strcpy(target, tok);
			}
			break;
		}
	}
	return 0;
}

int sayHello(int doit)
{
	int abort;
	int badspawn;
	char serial[100];

	if (!decrypt_serialno(serial, sizeof(serial))) {
		/* Not branded by SETUP: no serial number needed (GPL) */
		strcpy(serial, "\001GNU GPL v3");
	}

	badspawn = showLogo(doit, WhichLogo, MsgLogoText, serial, paintback);

	disable23();
	if (doEdit && doCmdThenExit) {
		sleep(1000L);
		abort = FALSE;
	}
	else {
		abort = pressAnyKey(2500L);
	}
	enable23();

	if (!badspawn) showLogo(-1, WhichLogo, NULL, NULL, paintback);
	return abort;
}

void paintback(void)
{
	paintBackgroundScreen();
	wput_csa(&programNameWin, ProgramName, ProgramNameAttr);
	halfShadow(&programNameWin);
}

/*	Collect the 386UTIL information */
int doEval(void)
{
	run386Util();
	return 0;
}

/*	Next: ASQ.  request 0: interactive (back with /Y2), else the summaries
 *	for us (/Y1).  Returns TRUE if ASQ is to run (we exit). */
int execAsq(int request)
{
	int n;
	char *snap;
	struct stat cfgstat, snapstat;

	UseArgfile = TRUE;
	ExecArgv[0] = my_malloc(130);
	get_exepath(ExecArgv[0], 130);
	strcat(ExecArgv[0], "ASQ.EXE");
	if (access(ExecArgv[0], 0) == -1) {
		errorMessage(ERR_NOASQ);
		my_free(ExecArgv[0]);
		ExecArgv[0] = NULL;
		return FALSE;
	}

	ExecArgv[1] = ScreenType == SCREEN_MONO ? "/B" : "/C";
	n = 2;
	if (!GraphicsLogo) ExecArgv[n++] = "/V";

	if (!request) {
		ExecArgv[n++] = "/Y2";
		snap = my_malloc(130);
		get_exepath(snap, 127);
		strcat(snap, "MAXSNAP.OUT");
		/*	Load the snapshot if it's newer than CONFIG.SYS, else save a
		 *	new one */
		if (!stat(ConfigName, &cfgstat) && !stat(snap, &snapstat) &&
				cfgstat.st_mtime < snapstat.st_mtime) {
			ExecArgv[n++] = "/L";
		}
		else {
			ExecArgv[n++] = "/S";
		}
		ExecArgv[n++] = snap;
	}
	else {
		ExecArgv[n++] = "/Y1";
		ExecArgv[n++] = "/W";
		ExecArgv[n] = my_malloc(130);
		get_exepath(ExecArgv[n], 127);
		strcat(ExecArgv[n++], ASQOUTFILE);
		ExecArgv[n++] = "/S";
		ExecArgv[n] = my_malloc(130);
		get_exepath(ExecArgv[n], 127);
		strcat(ExecArgv[n++], "MAXSNAP.OUT");
		ExecArgv[n++] = "/D";
		ExecArgv[n++] = AsqSnapDesc;
		if (BootDrive) {
			static char bootarg[] = "A:";

			ExecArgv[n++] = "/F";
			*bootarg = BootDrive;
			ExecArgv[n++] = bootarg;
		}
	}
	ExecArgv[n++] = "/Z";
	ExecArgv[n++] = get_exename();
	ExecArgv[n] = NULL;
	return TRUE;
}

/*	Next: Maximize (express or custom).  Returns TRUE if it is to run. */
int execMaximize(int request)
{
	int n;

	UseArgfile = FALSE;
	ExecArgv[0] = my_malloc(130);
	get_exepath(ExecArgv[0], 130);
	strcat(ExecArgv[0], "MAXIMIZE.EXE");
	if (access(ExecArgv[0], 0) == -1) {
		errorMessage(ERR_NOMAXIMIZE);
		my_free(ExecArgv[0]);
		ExecArgv[0] = NULL;
		return FALSE;
	}

	ExecArgv[1] = request == QS_EXPRESS ? "/E" : "/U";
	ExecArgv[2] = ScreenType == SCREEN_MONO ? "/B" : "/C";
	n = 3;
	if (!GraphicsLogo) ExecArgv[n++] = "/V";
	ExecArgv[n++] = "/Z";
	ExecArgv[n++] = get_exename();
	ExecArgv[n] = NULL;
	return TRUE;
}

/*	Next: UPDATE.EXE from a disk.  Returns TRUE if it is to run. */
int execUpdate(void)
{
	int n;

	UseArgfile = FALSE;
	ExecArgv[0] = my_malloc(130);
	strcpy(ExecArgv[0], "A:\\");
	if (askUpdateDisk(ExecArgv[0]) != KEY_ESCAPE &&
			(n = trim(ExecArgv[0])) > 0) {
		if (ExecArgv[0][n - 1] != '\\') strcat(ExecArgv[0], "\\");
		strcat(ExecArgv[0], "UPDATE.EXE");
		if (access(ExecArgv[0], 0) != -1) {
			ExecArgv[1] = ScreenType == SCREEN_MONO ? "/B" : "/C";
			n = 2;
			if (!GraphicsLogo) ExecArgv[n++] = "/V";
			ExecArgv[n++] = "/Z";
			ExecArgv[n++] = get_exename();
			ExecArgv[n] = NULL;
			return TRUE;
		}
		errorMessage(ERR_NOUPDATE);
	}
	my_free(ExecArgv[0]);
	ExecArgv[0] = NULL;
	return FALSE;
}

/*	Our settings survive the other programs in MAXSAVE.$$$ */
void saveState(void)
{
	char name[130];
	FILE *fp;

	get_exepath(name, sizeof(name));
	strcat(name, STATEFILE);
	if ((fp = fopen(name, "w")) != NULL) {
		fprintf(fp, "%d %d %d %d %d\n", ScreenType, GraphicsLogo,
			BrowseMode, BootDrive, TabStop);
		fclose(fp);
	}
}

void readState(void)
{
	char name[130];
	FILE *fp;
	int type, boot;

	get_exepath(name, sizeof(name));
	strcat(name, STATEFILE);
	if ((fp = fopen(name, "r")) != NULL) {
		boot = BootDrive;
		type = ScreenType;
		fscanf(fp, "%d %d %d %d %d", &type, &GraphicsLogo,
			&BrowseMode, &boot, &TabStop);
		ScreenType = type;
		BootDrive = (char)boot;
		ScreenSet = TRUE;
		fclose(fp);
		unlink(name);
	}
}

void setOptions(int argc, char **argv)
{
	int xOK = FALSE;
	int opt;
	char *pp;

	/* Mark video mode as not set */
	ScreenSet = FALSE;

	/* EOF means end of list, 0 means next token is not a switch,
	   0x8000 set means missing required argument or invalid option */
	while ((opt = arg_getopt(argc, argv, "bce:f:r:t:vwy:")) != EOF) {

		switch (opt & 0xff) {
		case 'B':       /* B&W monitor */
			ScreenType = SCREEN_MONO;
			ScreenSet = TRUE;
			break;

		case 'C':       /* Color monitor */
			ScreenType = SCREEN_COLOR;
			ScreenSet = TRUE;
			break;

		case 'E':       /* Editor only */
			pp = arg_argument();
			if (pp) {
				doCmdThenExit = TRUE;
				doEdit = my_malloc(strlen(pp) + 1);
				if (doEdit) strcpy(doEdit, pp);
			}
			else EditOnly = TRUE;
			xOK = TRUE;
			break;

		case 'F':       /* Boot drive */
			pp = arg_argument();
			if (pp && strlen(pp) == 2 && isalpha(*pp) && pp[1] == ':') {
				BootDrive = (char)toupper(*pp);
			}
			else	goto showHelp;
			break;

		case 'R':       /* Browse a file */
			BrowseMode = TRUE;
			pp = arg_argument();
			if (!pp) goto showHelp;
			doCmdThenExit = TRUE;
			doEdit = my_malloc(strlen(pp) + 1);
			if (doEdit) strcpy(doEdit, pp);
			xOK = TRUE;
			break;

		case 'T':       /* Tab stops of the editor */
			pp = arg_argument();
			if (!pp || (TabStop = atoi(pp)) < 1 || TabStop > 8) goto showHelp;
			break;

		case 'V':       /* Inhibit logo */
			GraphicsLogo = FALSE;
			break;

		case 'W':       /* Enable snow control on CGA systems */
			SnowControl = TRUE;
			break;

		case 'Y':       /* Back from one of the programs we ran */
			pp = arg_argument();
			if (pp && strlen(pp) == 1 && isdigit(*pp)) {
				fromExec = *pp - '0';
			}
			else	goto showHelp;
			break;

		default:
			/* Any switch we don't understand */
			goto showHelp;
		}
	}

	if (!doCmdThenExit || xOK) return;

showHelp:
	printf(HelpString);
	exit(2);
}

void setColors(void)
{
	FileMenu.items[FILE_EDITPOS].attr = DataContinueColor;
	ASQMenu.items[ASQ_SUMPOS].attr = DataContinueColor;
	HelpMenu.items[HELP_USINGPOS].attr = DataContinueColor;
	PrintingButtons[0].attr = DataContinueColor;
}

void quickAsq(int infoNum)
{
	(void)infoNum;
}

/*	MAX.CFG: NOLOGO, SNOWCONTROL, BOOTDRIVE d, USECOLOR y|n */
void read_cfg(void)
{
	char name[260], line[256];
	char *p, *key, *val;
	FILE *fp;

	get_exepath(name, sizeof(name));
	strcat(name, CFGFILE);
	if ((fp = fopen(name, "r")) == NULL) return;

	while (fgets(line, sizeof(line) - 1, fp)) {
		line[sizeof(line) - 1] = '\0';
		if ((p = strpbrk(line, QComments)) != NULL) *p = '\0';
		key = strtok(line, CfgKeywordSeps);
		val = strtok(NULL, CfgKeywordSeps);
		if (!key) continue;
		if (!stricmp(key, "NOLOGO")) {
			GraphicsLogo = FALSE;
		}
		else if (!stricmp(key, "SNOWCONTROL")) {
			SnowControl = TRUE;
		}
		else if (!stricmp(key, "BOOTDRIVE") && val) {
			BootDrive = *val;
		}
		else if (!stricmp(key, "USECOLOR") && val && !ScreenSet) {
			ScreenSet = TRUE;
			if (strchr("yYtT1", *val) || !stricmp(val, "ON")) {
				ScreenType = SCREEN_COLOR;
			}
			else ScreenType = SCREEN_MONO;
		}
	}
	fclose(fp);
}

/*	A file was edited on a swapped (compressed) drive: copy it to the boot
 *	drive if it is newer there */
void SwapUpdate(char *name, int drive)
{
	int newer = FALSE;
	char copyname[128];
	unsigned date1, time1, date2, time2;
	int fh1, fh2;

	strcpy(copyname, name);
	*copyname = (char)drive;
	if (SwappedDrive > 0 && drive && (fh1 = open(copyname, O_RDONLY)) != -1) {
		if (!_dos_getftime(fh1, &date1, &time1) &&
				(fh2 = open(name, O_RDONLY)) != -1) {
			if (!_dos_getftime(fh2, &date2, &time2) &&
					(date1 < date2 || (date1 == date2 && time1 < time2))) {
				newer = TRUE;
			}
			close(fh2);
		}
		close(fh1);
		if (newer) copy(name, copyname);
	}
}
