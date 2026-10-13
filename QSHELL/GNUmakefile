# MAX.EXE, the MAX shell (GNU make, see linux/mk/dos.mk).  The source of
# the original was not released; QMAIN.C, UTILINFO.C, UPDDISK.C,
# QSHPRINT.C, ASQINFO.C, QSHTEXT.H and VERSDATA.ASM are reconstructed from
# the original MAX.EXE (with its map and Nu-Mega symbol file) and the sibling
# sources of ASQ.  OpenWatcom.
PROJ     := QSHELL
ROOT     := $(abspath ..)
SRCDIRS  := . ../ASQ ../386MAX
ASMINC   := . ../INCLUDE ../INC ../QUILIB ../386MAX
CASEMAP  := mx
CMODEL   := l
DEFS     := MODEL=LARGE BETA=0
CDEFS    := DOS_VERSION
PROGS    := MAX.EXE

MAX.EXE_OBJS  := QMAIN.OBJ UTILINFO.OBJ UPDDISK.OBJ ABORT.OBJ QSHPRINT.OBJ ASQINFO.OBJ \
	VERSBETA.OBJ VERSDATA.OBJ VERSRET.OBJ ZZTAIL.OBJ
MAX.EXE_LIBS  := $(ROOT)/build/QUILIB/LQUILIBR.LIB $(ROOT)/build/HELPENG/LHELP.LIB
MAX.EXE_STACK := 9000


include $(ROOT)/linux/mk/dos.mk
