/******************************************************************************
 *									      *
 * (C) Copyright 1991-96 Qualitas, Inc.  GNU General Public License version 3. *
 *									      *
 * QSHTEXT.H								      *
 *									      *
 * All MAX shell (MAX.EXE) text strings and related definitions: the	      *
 * menus, the help contexts and the titles.				      *
 *									      *
 * Reconstructed for Open 386MAX from the original MAX.EXE (the source of     *
 * the MAX shell is not part of the released source code).		      *
 *									      *
 ******************************************************************************/

#ifndef GLINIT
#pragma warning( disable : 4746 )
#endif

#ifndef QSHTEXT_INCLUDED
#define QSHTEXT_INCLUDED

#ifdef OWNER
  #undef  GLOBAL
  #undef  GLINIT
  #define GLOBAL
  #define GLINIT
#else
  #undef  GLOBAL
  #undef  GLINIT
  #define GLOBAL extern
#endif /*  OWNER  */
/*	Menu return codes */
enum {
	QS_MEMSUM	= 1,		/* ASQ: memory summary */
	QS_CFGSUM	= 11,		/* ASQ: configuration summary */
	QS_EDITCFG	= 12,		/* edit CONFIG.SYS */
	QS_EDITAUT	= 13,		/* edit AUTOEXEC.BAT */
	QS_EDITPRO	= 14,		/* edit the MAX profile */
	QS_EDITEXT	= 15,		/* edit ExtraDOS.PRO */
	QS_EDITSYS	= 16,		/* edit SYSTEM.INI */
	QS_HDWSUM	= 19,		/* ASQ: equipment summary */
	QS_EDITLOAD	= 52,		/* edit the loader configuration */
	QS_FILEMENU	= 101,
	QS_ASQMENU,
	QS_MAXIMIZEMENU,
	QS_INFOMENU,
	QS_HELPMENU,
	QS_EDITOTHER	= 114,		/* edit another file */
	QS_UPDATE,			/* run UPDATE */
	QS_EXIT,
	QS_ASQ, 			/* run ASQ */
	QS_EXPRESS	= 121,		/* Maximize express */
	QS_CUSTOM,			/* Maximize custom */
	QS_OVERVIEW,			/* 386UTIL information */
	QS_EMS,
	QS_RESIDENT,
	QS_DEVICES,
	QS_LOADSIZES,
	QS_ROMSCAN,
	QS_TIMEMEM,
	QS_HTOPICS,			/* help */
	QS_HINDEX,
	QS_HHELP,
	QS_HMENUS,
	QS_HDIALOGS,
	QS_HPRINT,
	QS_HEDITOR
};

/*	Item counts and positions */
#define NUMMAINMENUITEMS	5
#define NUMFILEMENUITEMS	12
#define NUMASQMENUITEMS 	6
#define NUMMAXIMIZEMENUITEMS	2
#define NUMINFOMENUITEMS	7
#define NUMHELPMENUITEMS	9

#define FILE_EDITPOS	0	/* "- Edit -" */
#define FILE_PROPOS	3	/* MAX PROfile */
#define FILE_EXTPOS	4	/* ExtraDOS.PRO */
#define FILE_SYSPOS	5	/* SYSTEM.INI */
#define FILE_LOADPOS	6	/* Loader Config */
#define FILE_UPDPOS	9	/* Update */
#define ASQ_ASQPOS	0	/* ASQ */
#define ASQ_SUMPOS	2	/* "- Summarize -" */
#define MAX_EXPPOS	0	/* Express */
#define MAX_CUSPOS	1	/* Custom */
#define INFO_EMSPOS	1	/* EMS memory */
#define INFO_RESPOS	2	/* Resident programs */
#define INFO_DEVPOS	3	/* Device drivers */
#define INFO_LOADPOS	4	/* Load sizes */
#define INFO_ROMPOS	5	/* Memory Scan */
#define INFO_TIMEPOS	6	/* Time memory */
#define HELP_USINGPOS	3	/* "- Using -" */
#define MAIN_ASQPOS	1
#define MAIN_MAXPOS	2

/* help contexts (HelpNames/HelpInfo index) */
enum {
	/* 0..8: HELPMCONTENTS .. HELPOPTEDITOR of LIBTEXT.H */
	QSHELPDEFAULT = 9,	/*  9 H.Default */
	QSHELPINDEX,		/* 10 H.Index */
	QSHELPCONTENTS,		/* 11 H.Contents */
	QSHELPHELP,			/* 12 H.U_Help */
	QSHELPMENUS,		/* 13 H.Default */
	QSHELPDIALOGS,		/* 14 H.U_Dial */
	QSHELPPRINT,		/* 15 H.U_Print */
	QUICK_Cfg_Sum,		/* 16 Q_Cfg_Sum */
	QUICK_Exit,			/* 17 Q_Exit */
	QUICK_Hdw_Sum,		/* 18 Q_Hdw_Sum */
	QUICK_Help,			/* 19 Q_Help */
	HELP_Mem_Sum,		/* 20 H.Mem_Sum */
	HELP_Cfg_Sum,		/* 21 H.Cfg_Sum */
	HELP_Hdw_Sum,		/* 22 H.Hdw_Sum */
	QUICK_ASQ,			/* 23 Q_ASQ */
	QUICK_Cfg_Sum2,		/* 24 Q_Cfg_Sum */
	QUICK_Edit_AUT,		/* 25 Q_Edit_AUT */
	QUICK_Edit_CFG,		/* 26 Q_Edit_CFG */
	QUICK_Edit_PRO,		/* 27 Q_Edit_PRO */
	QUICK_Edit_Ext,		/* 28 Q_Edit_Ext */
	QUICK_Edit_SYS,		/* 29 Q_Edit_SYS */
	QUICK_Edit_Load,		/* 30 Q_Edit_Load */
	QUICK_Edit_Othr,		/* 31 Q_Edit_Othr */
	QUICK_Exit2,		/* 32 Q_Exit */
	QUICK_Hdw_Sum2,		/* 33 Q_Hdw_Sum */
	QUICK_Help2,		/* 34 Q_Help */
	QUICK_Info_Dev,		/* 35 Q_Info_Dev */
	QUICK_Info_EMS,		/* 36 Q_Info_EMS */
	QUICK_Info_Load,		/* 37 Q_Info_Load */
	QUICK_Info_Mem,		/* 38 Q_Info_Mem */
	QUICK_Info_Res,		/* 39 Q_Info_Res */
	QUICK_Info_ROM,		/* 40 Q_Info_ROM */
	QUICK_Info_Time,		/* 41 Q_Info_Time */
	QUICK_Max_Full,		/* 42 Q_Max_Full */
	QUICK_Max_Quick,		/* 43 Q_Max_Quick */
	QUICK_Mem_Sum,		/* 44 Q_Mem_Sum */
	QUICK_Update,		/* 45 Q_Update */
	HELP_ASQ,			/* 46 H.ASQ */
	HELP_Mem_Sum2,		/* 47 H.Mem_Sum */
	HELP_Cfg_Sum2,		/* 48 H.Cfg_Sum */
	HELP_Hdw_Sum2,		/* 49 H.Hdw_Sum */
	HELP_Max_Quick,		/* 50 H.Max_Quick */
	HELP_Max_Full,		/* 51 H.Max_Full */
	HELP_Info_Mem,		/* 52 H.Info_Mem */
	HELP_Info_EMS,		/* 53 H.Info_EMS */
	HELP_Info_Res,		/* 54 H.Info_Res */
	HELP_Info_Dev,		/* 55 H.Info_Dev */
	HELP_Info_Load,		/* 56 H.Info_Load */
	HELP_Info_ROM,		/* 57 H.Info_ROM */
	HELP_Info_Time,		/* 58 H.Info_Time */
	HELP_U_Update,		/* 59 H.U_Update */
	HELPLAST
};

#define HELPNAMEWIDTH (unsigned)15
#define WORKSPACESIZE ((unsigned)(2666*HELPNAMEWIDTH)) /*	39990 bytes */
GLOBAL char HelpNames[(WORKSPACESIZE/HELPNAMEWIDTH)][HELPNAMEWIDTH]
#ifdef GLINIT
= {
	"H.Contents",	/*  0 */
	"H.Index",		/*  1 */
	"H.U_Help",		/*  2 */
	"H.Default",		/*  3 */
	"H.U_Dial",		/*  4 */
	"H.U_Print",		/*  5 */
	"H.U_Editor",	/*  6 */
	"H.U_Browse",	/*  7 */
	"H.E_Option",	/*  8 */
	"H.Default",		/*  9 */
	"H.Index",		/* 10 */
	"H.Contents",	/* 11 */
	"H.U_Help",		/* 12 */
	"H.Default",		/* 13 */
	"H.U_Dial",		/* 14 */
	"H.U_Print",		/* 15 */
	"Q_Cfg_Sum",		/* 16 */
	"Q_Exit",		/* 17 */
	"Q_Hdw_Sum",		/* 18 */
	"Q_Help",		/* 19 */
	"H.Mem_Sum",		/* 20 */
	"H.Cfg_Sum",		/* 21 */
	"H.Hdw_Sum",		/* 22 */
	"Q_ASQ",		/* 23 */
	"Q_Cfg_Sum",		/* 24 */
	"Q_Edit_AUT",	/* 25 */
	"Q_Edit_CFG",	/* 26 */
	"Q_Edit_PRO",	/* 27 */
	"Q_Edit_Ext",	/* 28 */
	"Q_Edit_SYS",	/* 29 */
	"Q_Edit_Load",	/* 30 */
	"Q_Edit_Othr",	/* 31 */
	"Q_Exit",		/* 32 */
	"Q_Hdw_Sum",		/* 33 */
	"Q_Help",		/* 34 */
	"Q_Info_Dev",	/* 35 */
	"Q_Info_EMS",	/* 36 */
	"Q_Info_Load",	/* 37 */
	"Q_Info_Mem",	/* 38 */
	"Q_Info_Res",	/* 39 */
	"Q_Info_ROM",	/* 40 */
	"Q_Info_Time",	/* 41 */
	"Q_Max_Full",	/* 42 */
	"Q_Max_Quick",	/* 43 */
	"Q_Mem_Sum",		/* 44 */
	"Q_Update",		/* 45 */
	"H.ASQ",		/* 46 */
	"H.Mem_Sum",		/* 47 */
	"H.Cfg_Sum",		/* 48 */
	"H.Hdw_Sum",		/* 49 */
	"H.Max_Quick",	/* 50 */
	"H.Max_Full",	/* 51 */
	"H.Info_Mem",	/* 52 */
	"H.Info_EMS",	/* 53 */
	"H.Info_Res",	/* 54 */
	"H.Info_Dev",	/* 55 */
	"H.Info_Load",	/* 56 */
	"H.Info_ROM",	/* 57 */
	"H.Info_Time",	/* 58 */
	"H.U_Update",	/* 59 */
}
#endif
;

/*	The help work space is the same storage as the help names */
GLOBAL char far *tutorWorkSpace
#ifdef GLINIT
= (char far *)HelpNames
#endif
;

GLOBAL HELPDEF HelpInfo[ HELPLAST+1 ]
#ifdef GLINIT
= {
	{ HELP_HELP,	HelpNames[HELPMCONTENTS],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPINDEX],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPHELP],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPMENUS],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPDIALOGS],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPPRINT],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPEDITOR],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPBROWSE],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELPOPTEDITOR],	0,	NULL },
	{ HELP_HELP,	HelpNames[QSHELPDEFAULT],	0,	NULL },
	{ HELP_HELP,	HelpNames[QSHELPINDEX],	0,	NULL },
	{ HELP_HELP,	HelpNames[QSHELPCONTENTS],	0,	NULL },
	{ HELP_HELP,	HelpNames[QSHELPHELP],	0,	NULL },
	{ HELP_HELP,	HelpNames[QSHELPMENUS],	0,	NULL },
	{ HELP_HELP,	HelpNames[QSHELPDIALOGS],	0,	NULL },
	{ HELP_HELP,	HelpNames[QSHELPPRINT],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Cfg_Sum],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Exit],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Hdw_Sum],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Help],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Mem_Sum],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Cfg_Sum],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Hdw_Sum],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_ASQ],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Cfg_Sum2],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Edit_AUT],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Edit_CFG],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Edit_PRO],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Edit_Ext],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Edit_SYS],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Edit_Load],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Edit_Othr],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Exit2],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Hdw_Sum2],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Help2],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Info_Dev],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Info_EMS],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Info_Load],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Info_Mem],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Info_Res],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Info_ROM],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Info_Time],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Max_Full],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Max_Quick],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Mem_Sum],	0,	NULL },
	{ HELP_QSQUICK,	HelpNames[QUICK_Update],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_ASQ],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Mem_Sum2],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Cfg_Sum2],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Hdw_Sum2],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Max_Quick],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Max_Full],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Info_Mem],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Info_EMS],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Info_Res],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Info_Dev],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Info_Load],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Info_ROM],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_Info_Time],	0,	NULL },
	{ HELP_HELP,	HelpNames[HELP_U_Update],	0,	NULL },
	{ HELP_LAST,	NULL,	0,	NULL }
}
#endif
;
GLOBAL struct
{
	MENUINFO info;
	MENUITEM items[ NUMFILEMENUITEMS ];
} FileMenu
#ifdef GLINIT
#ifdef LANG_GR
= {
	{ NUMFILEMENUITEMS, MENU_VERTICAL, { 1, 0, 14, 21 }, 1, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, 0, ITEM_INFO, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 16, FG_BLUE  | BG_GRAY, "  - Bearbeiten -" },
		{ {  2,  1 }, QS_EDITCFG, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_CFG, HELPEDITOR, P_EDITOR, -1, { 'c', 'C', 0 }, 10, FG_BLACK | BG_GRAY, "CONFIG.SYS" },
		{ {  3,  1 }, QS_EDITAUT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_AUT, HELPEDITOR, P_EDITOR, -1, { 'a', 'A', 0 }, 12, FG_BLACK | BG_GRAY, "AUTOEXEC.BAT" },
		{ {  4,  1 }, QS_EDITPRO, ITEM_ACTIVE, { 0, 0 }, NULL, 5, QUICK_Edit_PRO, HELPEDITOR, P_EDITOR, -1, { 'p', 'P', 0 }, 10, FG_BLACK | BG_GRAY, "MAX-PROfil" },
		{ {  5,  1 }, QS_EDITEXT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_Ext, HELPEDITOR, P_EDITOR, -1, { 'e', 'E', 0 }, 12, FG_BLACK | BG_GRAY, "ExtraDOS.PRO" },
		{ {  6,  1 }, QS_EDITSYS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_SYS, HELPEDITOR, P_EDITOR, -1, { 's', 'S', 0 }, 10, FG_BLACK | BG_GRAY, "SYSTEM.INI" },
		{ {  7,  1 }, QS_EDITLOAD, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_Load, HELPEDITOR, P_EDITOR, -1, { 'l', 'L', 0 }, 13, FG_BLACK | BG_GRAY, "Lader-Konfig." },
		{ {  8,  1 }, QS_EDITOTHER, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_Othr, HELPEDITOR, P_OEDITOR, -1, { 'w', 'W', 0 }, 16, FG_BLACK | BG_GRAY, "Weitere Datei..." },
		{ {  9,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ { 10,  1 }, QS_UPDATE, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Update, HELP_U_Update, P_HELP, -1, { 'u', 'U', 0 }, 6, FG_BLACK | BG_GRAY, "Update" },
		{ { 11,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ { 12,  1 }, QS_EXIT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Exit2, -1, -1, -1, { 'b', 'B', 0 }, 7, FG_BLACK | BG_GRAY, "Beenden" }
	}
}
#else
= {
	{ NUMFILEMENUITEMS, MENU_VERTICAL, { 1, 0, 14, 18 }, 1, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, 0, ITEM_INFO, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 11, FG_BLUE  | BG_GRAY, "   - Edit -" },
		{ {  2,  1 }, QS_EDITCFG, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_CFG, HELPEDITOR, P_EDITOR, -1, { 'c', 'C', 0 }, 10, FG_BLACK | BG_GRAY, "CONFIG.SYS" },
		{ {  3,  1 }, QS_EDITAUT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_AUT, HELPEDITOR, P_EDITOR, -1, { 'a', 'A', 0 }, 12, FG_BLACK | BG_GRAY, "AUTOEXEC.BAT" },
		{ {  4,  1 }, QS_EDITPRO, ITEM_ACTIVE, { 0, 0 }, NULL, 5, QUICK_Edit_PRO, HELPEDITOR, P_EDITOR, -1, { 'p', 'P', 0 }, 14, FG_BLACK | BG_GRAY, "MAX PROfile" },
		{ {  5,  1 }, QS_EDITEXT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_Ext, HELPEDITOR, P_EDITOR, -1, { 'e', 'E', 0 }, 14, FG_BLACK | BG_GRAY, "ExtraDOS.PRO" },
		{ {  6,  1 }, QS_EDITSYS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_SYS, HELPEDITOR, P_EDITOR, -1, { 's', 'S', 0 }, 14, FG_BLACK | BG_GRAY, "SYSTEM.INI" },
		{ {  7,  1 }, QS_EDITLOAD, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_Load, HELPEDITOR, P_EDITOR, -1, { 'l', 'L', 0 }, 14, FG_BLACK | BG_GRAY, "Loader Config" },
		{ {  8,  1 }, QS_EDITOTHER, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Edit_Othr, HELPEDITOR, P_OEDITOR, -1, { 'o', 'O', 0 }, 13, FG_BLACK | BG_GRAY, "Other file..." },
		{ {  9,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ { 10,  1 }, QS_UPDATE, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Update, HELP_U_Update, P_HELP, -1, { 'u', 'U', 0 }, 6, FG_BLACK | BG_GRAY, "Update" },
		{ { 11,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ { 12,  1 }, QS_EXIT, ITEM_ACTIVE, { 0, 0 }, NULL, 2, QUICK_Exit2, -1, -1, -1, { 'x', 'X', 0 }, 4, FG_BLACK | BG_GRAY, "Exit" }
	}
}
#endif
#endif
;
GLOBAL struct
{
	MENUINFO info;
	MENUITEM items[ NUMASQMENUITEMS ];
} ASQMenu
#ifdef GLINIT
#ifdef LANG_GR
= {
	{ NUMASQMENUITEMS, MENU_VERTICAL, { 1, 7, 8, 18 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_ASQ, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_ASQ, HELP_ASQ, P_HELP, -1, { 'a', 'A', 0 }, 3, FG_BLACK | BG_GRAY, "ASQ" },
		{ {  2,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ {  3,  1 }, 0, ITEM_INFO, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 13, FG_BLUE  | BG_GRAY, "- öbersicht -" },
		{ {  4,  1 }, QS_MEMSUM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Mem_Sum, HELP_Mem_Sum2, P_QMENU, -1, { 's', 'S', 0 }, 8, FG_BLACK | BG_GRAY, "Speicher" },
		{ {  5,  1 }, QS_CFGSUM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Cfg_Sum2, HELP_Cfg_Sum2, P_QMENU, -1, { 'k', 'K', 0 }, 13, FG_BLACK | BG_GRAY, "Konfiguration" },
		{ {  6,  1 }, QS_HDWSUM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Hdw_Sum2, HELP_Hdw_Sum2, P_QMENU, -1, { 'g', 'G', 0 }, 6, FG_BLACK | BG_GRAY, "GerÑte" }
	}
}
#else
= {
	{ NUMASQMENUITEMS, MENU_VERTICAL, { 1, 6, 8, 17 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_ASQ, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_ASQ, HELP_ASQ, P_HELP, -1, { 'a', 'A', 0 }, 3, FG_BLACK | BG_GRAY, "ASQ" },
		{ {  2,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ {  3,  1 }, 0, ITEM_INFO, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 13, FG_BLUE  | BG_GRAY, "- Summarize -" },
		{ {  4,  1 }, QS_MEMSUM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Mem_Sum, HELP_Mem_Sum2, P_QMENU, -1, { 'm', 'M', 0 }, 6, FG_BLACK | BG_GRAY, "Memory" },
		{ {  5,  1 }, QS_CFGSUM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Cfg_Sum2, HELP_Cfg_Sum2, P_QMENU, -1, { 'c', 'C', 0 }, 13, FG_BLACK | BG_GRAY, "Configuration" },
		{ {  6,  1 }, QS_HDWSUM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Hdw_Sum2, HELP_Hdw_Sum2, P_QMENU, -1, { 'e', 'E', 0 }, 9, FG_BLACK | BG_GRAY, "Equipment" }
	}
}
#endif
#endif
;
GLOBAL struct
{
	MENUINFO info;
	MENUITEM items[ NUMMAXIMIZEMENUITEMS ];
} MAXIMIZEMenu
#ifdef GLINIT
#ifdef LANG_GR
= {
	{ NUMMAXIMIZEMENUITEMS, MENU_VERTICAL, { 1, 12, 4, 16 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_EXPRESS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Max_Quick, HELP_Max_Quick, P_HELP, -1, { 'e', 'E', 0 }, 7, FG_BLACK | BG_GRAY, "Express" },
		{ {  2,  1 }, QS_CUSTOM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Max_Full, HELP_Max_Full, P_HELP, -1, { 'i', 'I', 0 }, 11, FG_BLACK | BG_GRAY, "Individuell" }
	}
}
#else
= {
	{ NUMMAXIMIZEMENUITEMS, MENU_VERTICAL, { 1, 11, 4, 12 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_EXPRESS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Max_Quick, HELP_Max_Quick, P_HELP, -1, { 'e', 'E', 0 }, 5, FG_BLACK | BG_GRAY, "Express" },
		{ {  2,  1 }, QS_CUSTOM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Max_Full, HELP_Max_Full, P_HELP, -1, { 'c', 'C', 0 }, 4, FG_BLACK | BG_GRAY, "Custom" }
	}
}
#endif
#endif
;
GLOBAL struct
{
	MENUINFO info;
	MENUITEM items[ NUMINFOMENUITEMS ];
} InfoMenu
#ifdef GLINIT
#ifdef LANG_GR
= {
	{ NUMINFOMENUITEMS, MENU_VERTICAL, { 1, 22, 9, 24 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_OVERVIEW, ITEM_ACTIVE, { 0, 0 }, NULL, 2, QUICK_Info_Mem, HELP_Info_Mem, P_QMENU, -1, { 'b', 'B', 0 }, 9, FG_BLACK | BG_GRAY, "öberblick" },
		{ {  2,  1 }, QS_EMS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_EMS, HELP_Info_EMS, P_QMENU, -1, { 'e', 'E', 0 }, 12, FG_BLACK | BG_GRAY, "EMS-Speicher" },
		{ {  3,  1 }, QS_RESIDENT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Res, HELP_Info_Res, P_QMENU, -1, { 'r', 'R', 0 }, 19, FG_BLACK | BG_GRAY, "Residente Programme" },
		{ {  4,  1 }, QS_DEVICES, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Dev, HELP_Info_Dev, P_QMENU, -1, { 'g', 'G', 0 }, 13, FG_BLACK | BG_GRAY, "GerÑtetreiber" },
		{ {  5,  1 }, QS_LOADSIZES, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Load, HELP_Info_Load, P_QMENU, -1, { 'l', 'L', 0 }, 11, FG_BLACK | BG_GRAY, "Lade-Grî·en" },
		{ {  6,  1 }, QS_ROMSCAN, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_ROM, HELP_Info_ROM, P_QMENU, -1, { 's', 'S', 0 }, 13, FG_BLACK | BG_GRAY, "Speicher-Scan" },
		{ {  7,  1 }, QS_TIMEMEM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Time, HELP_Info_Time, P_QMENU, -1, { 'z', 'Z', 0 }, 11, FG_BLACK | BG_GRAY, "Zeitmessung" }
	}
}
#else
= {
	{ NUMINFOMENUITEMS, MENU_VERTICAL, { 1, 21, 9, 22 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_OVERVIEW, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Mem, HELP_Info_Mem, P_QMENU, -1, { 'o', 'O', 0 }, 8, FG_BLACK | BG_GRAY, "Overview" },
		{ {  2,  1 }, QS_EMS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_EMS, HELP_Info_EMS, P_QMENU, -1, { 'e', 'E', 0 }, 10, FG_BLACK | BG_GRAY, "EMS memory" },
		{ {  3,  1 }, QS_RESIDENT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Res, HELP_Info_Res, P_QMENU, -1, { 'r', 'R', 0 }, 17, FG_BLACK | BG_GRAY, "Resident programs" },
		{ {  4,  1 }, QS_DEVICES, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Dev, HELP_Info_Dev, P_QMENU, -1, { 'd', 'D', 0 }, 14, FG_BLACK | BG_GRAY, "Device drivers" },
		{ {  5,  1 }, QS_LOADSIZES, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Load, HELP_Info_Load, P_QMENU, -1, { 'l', 'L', 0 }, 10, FG_BLACK | BG_GRAY, "Load sizes" },
		{ {  6,  1 }, QS_ROMSCAN, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_ROM, HELP_Info_ROM, P_QMENU, -1, { 'm', 'M', 0 }, 11, FG_BLACK | BG_GRAY, "Memory Scan" },
		{ {  7,  1 }, QS_TIMEMEM, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Info_Time, HELP_Info_Time, P_QMENU, -1, { 't', 'T', 0 }, 11, FG_BLACK | BG_GRAY, "Time memory" }
	}
}
#endif
#endif
;
GLOBAL struct
{
	MENUINFO info;
	MENUITEM items[ NUMHELPMENUITEMS ];
} HelpMenu
#ifdef GLINIT
#ifdef LANG_GR
= {
	{ NUMHELPMENUITEMS, MENU_VERTICAL, { 1, 28, 11, 15 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_HTOPICS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPMCONTENTS, P_HELP, -1, { 't', 'T', 0 }, 6, FG_BLACK | BG_GRAY, "Themen" },
		{ {  2,  1 }, QS_HINDEX, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPINDEX, P_HELP, -1, { 's', 'S', 0 }, 10, FG_BLACK | BG_GRAY, "Stichworte" },
		{ {  3,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ {  4,  1 }, 0, ITEM_INFO, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 10, FG_BLUE  | BG_GRAY, "-Hilfe zu-" },
		{ {  5,  1 }, QS_HHELP, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPHELP, P_HELP, -1, { 'h', 'H', 0 }, 5, FG_BLACK | BG_GRAY, "Hilfe" },
		{ {  6,  1 }, QS_HMENUS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPMENUS, P_HELP, -1, { 'm', 'M', 0 }, 5, FG_BLACK | BG_GRAY, "MenÅs" },
		{ {  7,  1 }, QS_HDIALOGS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPDIALOGS, P_HELP, -1, { 'd', 'D', 0 }, 7, FG_BLACK | BG_GRAY, "Dialoge" },
		{ {  8,  1 }, QS_HPRINT, ITEM_ACTIVE, { 0, 0 }, NULL, 3, QUICK_Help2, HELPPRINT, P_HELP, -1, { 'u', 'U', 0 }, 5, FG_BLACK | BG_GRAY, "Druck" },
		{ {  9,  1 }, QS_HEDITOR, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPEDITOR, P_OEDITOR, -1, { 'e', 'E', 0 }, 6, FG_BLACK | BG_GRAY, "Editor" }
	}
}
#else
= {
	{ NUMHELPMENUITEMS, MENU_VERTICAL, { 1, 27, 11, 13 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  1,  1 }, QS_HTOPICS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPMCONTENTS, P_HELP, -1, { 't', 'T', 0 }, 8, FG_BLACK | BG_GRAY, "Topics" },
		{ {  2,  1 }, QS_HINDEX, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPINDEX, P_HELP, -1, { 'i', 'I', 0 }, 5, FG_BLACK | BG_GRAY, "Index" },
		{ {  3,  1 }, 0, ITEM_SEPARATOR, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 0, FG_BLACK | BG_GRAY, "" },
		{ {  4,  1 }, 0, ITEM_INFO, { 0, 0 }, NULL, -1, -1, -1, -1, -1, { 0, 0, 0 }, 9, FG_BLUE  | BG_GRAY, "- Using -" },
		{ {  5,  1 }, QS_HHELP, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPHELP, P_HELP, -1, { 'h', 'H', 0 }, 4, FG_BLACK | BG_GRAY, "Help" },
		{ {  6,  1 }, QS_HMENUS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPMENUS, P_HELP, -1, { 'm', 'M', 0 }, 5, FG_BLACK | BG_GRAY, "Menus" },
		{ {  7,  1 }, QS_HDIALOGS, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPDIALOGS, P_HELP, -1, { 'd', 'D', 0 }, 7, FG_BLACK | BG_GRAY, "Dialogs" },
		{ {  8,  1 }, QS_HPRINT, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPPRINT, P_HELP, -1, { 'p', 'P', 0 }, 5, FG_BLACK | BG_GRAY, "Print" },
		{ {  9,  1 }, QS_HEDITOR, ITEM_ACTIVE, { 0, 0 }, NULL, 1, QUICK_Help2, HELPEDITOR, P_OEDITOR, -1, { 'e', 'E', 0 }, 6, FG_BLACK | BG_GRAY, "Editor" }
	}
}
#endif
#endif
;

GLOBAL struct
{
	MENUINFO info;
	MENUITEM items[ NUMMAINMENUITEMS ];
} MainMenu
#ifdef GLINIT
#ifdef LANG_GR
= {
	{ NUMMAINMENUITEMS, MENU_BAR, { 0, 0, 1, 35 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  0,  1 }, QS_FILEMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&FileMenu, 1, -1, -1, -1, -1, { 'd', 'D', 0 }, 5, FG_BLACK | BG_GRAY, "Datei" },
		{ {  0,  8 }, QS_ASQMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&ASQMenu, 1, -1, -1, -1, -1, { 'a', 'A', 0 }, 3, FG_BLACK | BG_GRAY, "ASQ" },
		{ {  0, 13 }, QS_MAXIMIZEMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&MAXIMIZEMenu, 1, -1, -1, -1, -1, { 'm', 'M', 0 }, 8, FG_BLACK | BG_GRAY, "Maximize" },
		{ {  0, 23 }, QS_INFOMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&InfoMenu, 1, -1, -1, -1, -1, { 'i', 'I', 0 }, 4, FG_BLACK | BG_GRAY, "Info" },
		{ {  0, 29 }, QS_HELPMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&HelpMenu, 1, -1, -1, -1, -1, { 'h', 'H', 0 }, 5, FG_BLACK | BG_GRAY, "Hilfe" }
	}
}
#else
= {
	{ NUMMAINMENUITEMS, MENU_BAR, { 0, 0, 1, 35 }, 0, 0, MENU_NOTSHOWN, (FG_BLACK | BG_GRAY), NULL, NULL },
	{
		{ {  0,  1 }, QS_FILEMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&FileMenu, 1, -1, -1, -1, -1, { 'f', 'F', 0 }, 4, FG_BLACK | BG_GRAY, "File" },
		{ {  0,  7 }, QS_ASQMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&ASQMenu, 1, -1, -1, -1, -1, { 'a', 'A', 0 }, 3, FG_BLACK | BG_GRAY, "ASQ" },
		{ {  0, 12 }, QS_MAXIMIZEMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&MAXIMIZEMenu, 1, -1, -1, -1, -1, { 'm', 'M', 0 }, 8, FG_BLACK | BG_GRAY, "Maximize" },
		{ {  0, 22 }, QS_INFOMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&InfoMenu, 1, -1, -1, -1, -1, { 'i', 'I', 0 }, 4, FG_BLACK | BG_GRAY, "Info" },
		{ {  0, 28 }, QS_HELPMENU, ITEM_ACTIVE, { 0, 0 }, (PMENU)&HelpMenu, 1, -1, -1, -1, -1, { 'h', 'H', 0 }, 4, FG_BLACK | BG_GRAY, "Help" }
	}
}
#endif
#endif
;

GLOBAL WINDESC programNameWin
#ifdef GLINIT
= { 0, 64, 1, 15 }	/* " Open 386MAX 8 " */
#endif
;

extern char ProgramName[];	/* Actual data in VERSDATA.ASM */
extern char *MsgLogoText[];
extern char HelpString[];

GLOBAL char *WhichLogo
#ifdef GLINIT
= "Q"
#endif /*GLINIT*/
;

/*	Titles of the 386UTIL information windows (Info menu) */
GLOBAL char *UtilTitles[]
#ifdef GLINIT
#ifdef LANG_GR
= {
	"\x9Aberblick",
	"EMS-Speicher",
	"Residente Programme",
	"Ger\x84tetreiber",
	"Lade-Gr\x94\xe1en",
	"Speicher-Scan",
	"Speicher-Zeitmessung"
}
#else
= {
	"Overview",
	"EMS Memory",
	"Resident Programs",
	"Device Drivers",
	"Load Sizes",
	"Memory Scan",
	"Time Memory"
}
#endif
#endif
;

/*	Titles of the ASQ data windows (ASQ menu and the editors) */
GLOBAL char *AsqTitles[]
#ifdef GLINIT
#ifdef LANG_GR
= {
	"Speicher-\x9Abersicht",
	"Konfigurations-\x9Abersicht",
	"Ger\x84te-\x9Abersicht",
	"Datei CONFIG.SYS",
	"Datei AUTOEXEC.BAT",
	"Qualitas-PROFile",
	"Datei 386MAX.PRO",
	"Datei MOVE'EM.PRO"
}
#else
= {
	"Memory Summary",
	"Configuration Summary",
	"Equipment Summary",
	"CONFIG.SYS File",
	"AUTOEXEC.BAT File",
	"Qualitas PROFile",
	"386MAX.PRO File",
	"MOVE'EM.PRO File"
}
#endif
#endif
;
#define ASQT_PROFILE	5	/* AsqTitles index of the profile */
#define ASQT_386MAX	6
#define ASQT_MOVEEM	7

GLOBAL char *UtilDataError
#ifdef GLINIT
#ifdef LANG_GR
= "Daten nicht verf\x81gbar."
#else
= "Data not available."
#endif
#endif
;

GLOBAL char *AsqDataError
#ifdef GLINIT
#ifdef LANG_GR
= "ASQ-Daten nicht verf\x81gbar."
#else
= "ASQ data not available."
#endif
#endif
;

GLOBAL char RunningUtil[]
#ifdef GLINIT
#ifdef LANG_GR
= "%s l\x84uft"
#else
= "Running %s"
#endif
#endif
;

/*	Snapshot description given to ASQ */
GLOBAL char AsqSnapDesc[]
#ifdef GLINIT
#ifdef LANG_GR
= "\"Daten der MAX-Analyse.\""
#else
= "\"Data from MAX analysis.\""
#endif
#endif
;

/*	Names of the loaders */
GLOBAL char *LoaderName
#ifdef GLINIT
= "386LOAD"
#endif
;

GLOBAL char *MoveName
#ifdef GLINIT
= "MOVE'EM"
#endif
;

/*
*	All the stuff relating to error messages or printer messages
*/

#ifdef LANG_GR
#define ERROR " Fehler "
#define MESSAGE " Meldung "
#define PRINTING "Drucke Seite %d..."
#else
#define ERROR " Error "
#define MESSAGE " Message "
#define PRINTING "Printing page %d..."
#endif
GLOBAL char Error[ sizeof( ERROR )]
#ifdef GLINIT
= ERROR
#endif
;

GLOBAL char Message[ sizeof( MESSAGE )]
#ifdef GLINIT
= MESSAGE
#endif
;

GLOBAL char Printing[ sizeof( PRINTING )]
#ifdef GLINIT
= PRINTING
#endif
;

typedef enum { PRINTTYPEANALYSIS,
			   PRINTTYPEHELP,
			   PRINTTYPEFILE,
			   PRINTTYPEGLOSSARY,
			   PRINTTYPENONE } PRINTTITLETYPE;
GLOBAL char *PRINTTYPETEXT[PRINTTYPENONE]
#ifdef GLINIT
#ifdef LANG_GR
=
{
	"ANALYSE",
	"HILFE",
	"DATEI",
	"GLOSSAR"
}
#else
=
{
	"ANALYSIS",
	"HELP",
	"FILE",
	"GLOSSARY"
}
#endif
#endif
;

#ifdef LANG_GR
#define PRINTPAGETITLE ""	/* the program name says Open 386MAX */
#else
#define PRINTPAGETITLE ""	/* the program name says Open 386MAX */
#endif
GLOBAL char PrintPageTitle[ sizeof( PRINTPAGETITLE )]
#ifdef GLINIT
= PRINTPAGETITLE
#endif
;

GLOBAL char PrintPage[]
#ifdef GLINIT
#ifdef LANG_GR
= "Seite: %d"
#else
= "page: %d"
#endif
#endif
;

#ifdef LANG_GR
#define FILEPROMPT "Datei: "
#else
#define FILEPROMPT "File: "
#endif
GLOBAL char FilePrompt[sizeof( FILEPROMPT )]
#ifdef GLINIT
= FILEPROMPT
#endif
;

#ifdef LANG_GR
#define ARROWS "Pfeiltasten"
#define ENTER "<ƒŸ"
#else
#define ARROWS "Arrows"
#define ENTER "Enter"
#endif
GLOBAL char Arrows[sizeof(ARROWS)]
#ifdef GLINIT
= ARROWS
#endif
;


GLOBAL char Enter[ sizeof( ENTER )]
#ifdef GLINIT
= ENTER
#endif
;

#define NUMPRINTINGBUTTONS 1
GLOBAL BUTTON PrintingButtons[ NUMPRINTINGBUTTONS ]
#ifdef GLINIT
#ifdef LANG_GR
= {
   { { 15, 34 }, 12, "Abbruch",  { KEY_ESCAPE, 'a', 'A', KEY_ALTA }, KEY_ESCAPE, TRUE,  TRUE,  0, 1, FG_BLUE     | BG_GRAY, FALSE },
}
#else
= {
   { { 15, 34 }, 12, "Cancel",  { KEY_ESCAPE, 'c', 'C', KEY_ALTC }, KEY_ESCAPE, TRUE,  TRUE,  0, 1, FG_BLUE     | BG_GRAY, FALSE },
}
#endif
#endif
;

/*	The Update dialog (UPDDISK.C) */
#ifdef LANG_GR
#define UPDATETITLE " Update "
#define UPDATETEXT "Laufwerk und/oder Pfad des Update-Programms eingeben:"
#else
#define UPDATETITLE " Update "
#define UPDATETEXT "Enter the drive and/or path for the Update program:"
#endif

#endif /* QSHTEXT_INCLUDED */
