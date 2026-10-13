# CLEAN.EXE for SETUP.EXE (DOS, GNU make, see linux/mk/dos.mk; used by
# GNUmakefile; not installed into build/bin)
PROJ     := MAXSETUP-CLEAN
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INCLUDE ../INC
CMODEL   := s
PROGS    := CLEAN.EXE

CLEAN.EXE_OBJS := CLEAN.OBJ


include $(ROOT)/linux/mk/dos.mk
