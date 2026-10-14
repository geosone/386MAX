# MAXDOSCF.EXE, MAXCFG for DOS: the DOS stub of MAXCFG.EXE (GNU make, see
# linux/mk/dos.mk; used by GNUmakefile)
PROJ     := MAXCFG/DOS
ROOT     := $(abspath ..)
CMODEL   := s
SRCDIRS  := .
ASMINC   := . ../INCLUDE
PROGS    := MAXDOSCF.EXE

MAXDOSCF.EXE_OBJS := MAXDOSCF.OBJ OPTTAB.OBJ
MAXDOSCF.EXE_LINKOPTS := option stack=0x1000

include $(ROOT)/linux/mk/dos.mk
