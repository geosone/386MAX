# STRIPMGR.EXE, removes other memory managers from CONFIG.SYS etc. (GNU
# make, see linux/mk/dos.mk; MAKEFILE is the original NMAKE file).
# Microsoft C is replaced by OpenWatcom.
PROJ     := STRIPMGR
ROOT     := $(abspath ..)
SRCDIRS  := . ../QUILIB
ASMINC   := . ../INCLUDE ../INC ../QUILIB
CMODEL   := s
CPACK    := 1
CDEFS    := STRIPMGR=1 OWC_OWN_DELAY OWC_OWN_GETLINE OWC_OWN_TOUPPER \
	OWC_OWN_SPRINTF OWC_OWN_SSCANF
DEFS     := MODEL=SMALL
PROGS    := STRIPMGR.EXE

STRIPMGR.EXE_OBJS := PARSER.OBJ CMDS.OBJ EXPAND.OBJ FILECMDS.OBJ SYSCMDS.OBJ MISC.OBJ \
	BATCH.OBJ ERROR.OBJ INPUT.OBJ OUTPUT.OBJ MBPARSE.OBJ DMALLOC.OBJ
STRIPMGR.EXE_STACK := 6144
# Microsoft LINK without /NOI: names match regardless of case
STRIPMGR.EXE_LINKOPTS := option nocaseexact

# the C objects in RET/ come from Microsoft C
NOORIGOBJ := 1

include $(ROOT)/linux/mk/dos.mk
