# SNAPSHOT.EXE (GNU make, see linux/mk/dos.mk; MAKEFILE is the original
# NMAKE file).  Microsoft C is replaced by OpenWatcom.
PROJ     := SNAPSHOT
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INCLUDE ../INC
CMODEL   := s
PROGS    := SNAPSHOT.EXE

SNAPSHOT.EXE_OBJS  := SNAPSHOT.OBJ
SNAPSHOT.EXE_STACK := 4096

# no original objects of the C build in the tree
NOORIGOBJ := 1

include $(ROOT)/linux/mk/dos.mk
