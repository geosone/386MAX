/******************************************************************************
 *									      *
 * (C) Copyright 1991-96 Qualitas, Inc.  GNU General Public License version 3. *
 *									      *
 * QSHELL.H								      *
 *									      *
 * Global data and functions of the MAX shell (MAX.EXE).		      *
 *									      *
 * Reconstructed for Open 386MAX from the original MAX.EXE.		      *
 *									      *
 ******************************************************************************/

#ifndef QSHELL_INCLUDED
#define QSHELL_INCLUDED

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

#include <stdio.h>

#define MAXUTILS	7		/* windows of the Info menu */
#define MAXASQ		6		/* sections of the ASQ output */
#define MAXEXECARGS	36		/* arguments of a program to run */

/*	Files written by the programs we run */
#define ASQOUTFILE	"ASQSUMM.OUT"   /* ASQ summaries (/W) */
#define UTILOUTFILE	"MAXUTIL.OUT"   /* 386UTIL output */
#define STATEFILE	"MAXSAVE.$$$"   /* our state while another program runs */
#define CFGFILE 	"MAX.CFG"       /* settings */
#define RSPFILE 	"MAX.RSP"       /* arguments for the next program */

/*	Command line and settings */
GLOBAL char far *doEdit;		/* /E or /R: file to edit (and exit) */
GLOBAL int BrowseMode;			/* /R: browse only */
GLOBAL int doCmdThenExit;		/* edit the file, then exit */
GLOBAL int fromExec			/* /Y: 1 after ASQ, 2 after the others */
#ifdef GLINIT
= -1
#endif
;
GLOBAL int GraphicsLogo 		/* /V turns the logo off */
#ifdef GLINIT
= 1
#endif
;
GLOBAL int UseArgfile;			/* pass the arguments in MAX.RSP */
GLOBAL int SnowControl; 		/* /W: CGA snow control */
GLOBAL int EditOnly;			/* /E without a file */
GLOBAL char BootDrive;			/* /F: boot drive */

/*	Configuration found in CONFIG.SYS */
GLOBAL char MaxHomeDir[88];		/* where 386MAX (or Move'em) lives */
GLOBAL char LoadCfgName[80];		/* loader configuration (386LOAD.CFG) */

/*	Output of ASQ (ASQINFO.C) */
GLOBAL FILE *AsqFile;
GLOBAL long AsqFileLength;
GLOBAL int AsqCount;
GLOBAL long AsqPos[MAXASQ];
GLOBAL int AsqFlag[MAXASQ];
GLOBAL int AsqNum[MAXASQ];
GLOBAL int AsqWid[MAXASQ];
GLOBAL int AsqLen[MAXASQ];

/*	Output of 386UTIL (UTILINFO.C) */
GLOBAL FILE *UtilFile;
GLOBAL int UtilCount;
GLOBAL long UtilPos[MAXUTILS];
GLOBAL int UtilWid[MAXUTILS];
GLOBAL int UtilLen[MAXUTILS];

/*	Program to run when we exit */
GLOBAL char far *ExecArgv[MAXEXECARGS];


/*	QMAIN.C */
void paintback(void);
int doEval(void);
int execAsq(int request);
int execMaximize(int request);
int execUpdate(void);
void saveState(void);
void readState(void);
void setOptions(int argc, char **argv);
void setColors(void);
void quickAsq(int infoNum);
void read_cfg(void);
void SwapUpdate(char *name, int drive);
int sayHello(int doit);

/*	UTILINFO.C */
void presentUtil(int request, int helpNum);
void run386Util(void);
void initUtil(void);

/*	UPDDISK.C */
int askUpdateDisk(char far *path);

/*	ASQINFO.C */
void presentAsq(int request, int helpNum);
void initAsq(void);
int asqinfo_lookup(int num);

/*	ABORT.C */
void abortprep(int flag);

#endif /* QSHELL_INCLUDED */
