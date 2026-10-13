# BATPROC.EXE, the batch file processor used by MAXIMIZE (GNU make, see
# linux/mk/dos.mk; MAKEFILE is the original NMAKE file).  Microsoft C is
# replaced by OpenWatcom.
PROJ     := BATPROC
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INCLUDE ../INC ../386MAX ../386LOAD
CMODEL   := s
CPACK    := 1
CDEFS    := COMPAT_4DOS=1 BPDBG=0 OWC_OWN_DELAY OWC_OWN_GETLINE OWC_OWN_TOUPPER \
	OWC_OWN_SPRINTF OWC_OWN_SSCANF
PROGS    := BATPROC.EXE

BATPROC.EXE_OBJS := PARSER.OBJ CMDS.OBJ EXPAND.OBJ EVAL.OBJ DIRCMDS.OBJ FILECMDS.OBJ \
	SYSCMDS.OBJ MISC.OBJ ENV.OBJ BATCH.OBJ ERROR.OBJ SCREENIO.OBJ INPUT.OBJ \
	OUTPUT.OBJ LINES.OBJ _FILE.OBJ BATERRS.OBJ BATUTIL.OBJ EXEC.OBJ
BATPROC.EXE_STACK := 4096
# Microsoft LINK without /NOI: names match regardless of case (the
# assembler modules are /mu, the C modules mixed case)
BATPROC.EXE_LINKOPTS := option nocaseexact

# the C objects in RET/ come from Microsoft C
NOORIGOBJ := 1

include $(ROOT)/linux/mk/dos.mk
