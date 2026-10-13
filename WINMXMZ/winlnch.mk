# WINLNCH.EXE, the DOS stub of WINMAXIM.EXE (GNU make, see linux/mk/dos.mk;
# used by GNUmakefile).  MYEXECV.ASM (STATUTIL, Masm 6 like the original
# /Cp build) must come first.  Microsoft C is replaced by OpenWatcom.
PROJ     := WINMXMZ/WINLNCH
ROOT     := $(abspath ..)
SRCDIRS  := . ../STATUTIL
ASMINC   := . ../INCLUDE ../INC
CMODEL   := s
CASEMAP  := ml
PROGS    := WINLNCH.EXE
ML6OBJS  := MYEXECV.OBJ

WINLNCH.EXE_OBJS := MYEXECV.OBJ WINLNCH.OBJ
# LINK /CP:0x400 and the default 2 KB stack of the original
WINLNCH.EXE_MAXALLOC := 0x400
WINLNCH.EXE_LINKOPTS := option stack=0x800

NOORIGOBJ := 1

include $(ROOT)/linux/mk/dos.mk
