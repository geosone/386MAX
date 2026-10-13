# SETUPDOS.EXE for SETUP.EXE (DOS, GNU make, see linux/mk/dos.mk; used by
# GNUmakefile; not installed into build/bin)
PROJ     := MAXSETUP-SETUPDOS
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INCLUDE ../INC
CMODEL   := s
PROGS    := SETUPDOS.EXE

SETUPDOS.EXE_OBJS := SETUPDOS.OBJ


include $(ROOT)/linux/mk/dos.mk
