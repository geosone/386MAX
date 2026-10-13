	 TITLE	 VERSDATA -- Version-dependent data
	 page	 58,122
	 name	 VERSDATA

COMMENT|		Module Specifications

Version-dependent data for MAX.EXE (the MAX shell).
Reconstructed for Open 386MAX from the original MAX.EXE.

Copyright:  (C) Copyright 1992-97 Qualitas, Inc.  GNU General Public License version 3.

Segmentation:  Ungrouped:
	       Group DGROUP:
	       Data    segment _DATA,	 word-aligned,	public, class 'data'

Link requirements: Data to be referenced from MS C.

Program derived from:  None.

Original code by:  Henry Groover, January, 1992.

|

.8086
.xlist
	 include ASCII.INC
	 extrn	 BETA_H:abs
	 extrn	 BETA_T:abs
	 extrn	 BETA_U:abs
.list

%.model  &MODEL

.data

; ASYS constant values for different builds
MAX		equ	0	; 386MAX
BLUEMAX 	equ	1	; BlueMAX
MOVEM		equ	2	; Move'em

PROGNAME	equ	'MAX'
ifdef LANG_GR
PROGTITLE	equ	'Der intelligente Speicher-Manager'
else
PROGTITLE	equ	'The Intelligent Memory Manager'
endif			; IFDEF LANG_??

	 extrn	 VER:abs,VERS_H:abs,VERS_T:abs,VERS_U:abs,VERSLTR1:abs
	 extrn	 BINVERS_H:abs,BINVERS_TU:abs

MAXMAJVERTEXT equ <VERS_H,'.',VERS_T,VERS_U,VERSLTR1>
if BETA
MAXVERTEXT equ	<MAXMAJVERTEXT,'.',BETA_H,BETA_T,BETA_U,'',0E1h>
else
MAXVERTEXT equ	<MAXMAJVERTEXT>
endif		; BETA

; Data from QSHTEXT.H
	 public  _ProgramName
_ProgramName db  ' Open 386',PROGNAME,' ',VERS_H,' ',0 ; " Open 386MAX 8 "

	 public  _MsgLogoText
MsgLogoText_1 db 'Open 386',PROGNAME,' ',VERS_H,'.',VERS_T,VERS_U,0
MsgLogoText_2 db PROGTITLE,0
MsgLogoText_3 db PROGNAME,0
MsgLogoText_4 db 'Version ',MAXVERTEXT,0
MsgLogoText_5 db 0
if @datasize
_MsgLogoText dd  DGROUP:MsgLogoText_1,DGROUP:MsgLogoText_2
	 dd	 DGROUP:MsgLogoText_3,DGROUP:MsgLogoText_4
	 dd	 DGROUP:MsgLogoText_5,0
else
_MsgLogoText dw  MsgLogoText_1,MsgLogoText_2,MsgLogoText_3,MsgLogoText_4
	 dw	 MsgLogoText_5,0
endif		; Far/near pointers

	 public  _HelpString
_HelpString label byte
ifdef LANG_GR
 db	LF
 db	'Bearbeitet Systemdateien und startet die Open 386MAX-Programme.',LF
 db	 LF
 db	 PROGNAME,' [Schalter]',LF
 db	 LF
 db	 '  /B           startet ',PROGNAME,' in Monochrom (SW)',LF
 db	 '  /C           startet ',PROGNAME,' in Farbe',LF
 db	 '  /E [datei]   startet ',PROGNAME,' nur als Editor, l',84h,'dt ''datei''',LF
 db	 '               (falls angegeben) in den Editor',LF
 db	 '  /F laufw:    liest CONFIG.SYS und AUTOEXEC.BAT von ''laufw:''',LF
 db	 '  /R datei     startet ',PROGNAME,' mit ''datei'' im Betrachter',LF
 db	 '  /T n         Anzahl Leerzeichen f',81h,'r Tabulatoren beim Bearbeiten',LF
 db	 '               von Dateien (1 bis 8, Vorgabe 8)',LF
 db	 '  /V           startet ohne grafisches Begr',81h,0E1h,'ungs-Logo',LF
 db	 LF
 db	 PROGNAME,' ',MAXVERTEXT,', '
 db	 '(C) Copyright 1987-96 Qualitas, Inc.   GNU General Public License version 3.',LF,0
else
 db	LF
 db	'Provides for editing of system files and execution of Open 386MAX products.',LF
 db	 LF
 db	 PROGNAME,' [switches]',LF
 db	 LF
 db	 '  /B           Start ',PROGNAME,' in monochrome (B&W) mode',LF
 db	 '  /C           Start ',PROGNAME,' in color mode',LF
 db	 '  /E [filename] Start ',PROGNAME,' as an editor only, with ''filename''',LF
 db	 '               optionally loaded in editor',LF
 db	 '  /F drive:    Read CONFIG.SYS and AUTOEXEC.BAT from ''drive:''',LF
 db	 '  /R filename  Start ',PROGNAME,' with ''filename'' loaded in browser',LF
 db	 '  /T n         Number of spaces to expand tab characters when editing',LF
 db	 '               files, where ''n'' is 1 to 8; if the switch is not used,',LF
 db	 '               the default tab expansion value is 8',LF
 db	 '  /V           Inhibit graphic introduction logo',LF
 db	 LF
 db	 PROGNAME,' ',MAXVERTEXT,', '
 db	 '(C) Copyright 1987-96 Qualitas, Inc.   GNU General Public License version 3.',LF,0
endif			; IFDEF LANG_??
	 end
