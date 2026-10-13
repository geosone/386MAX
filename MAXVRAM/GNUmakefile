# MAXVRAM: RVMXTSR.COM and RVMXDEV.SYS (GNU make, see linux/mk/dos.mk;
# MAKEFILE is the original NMAKE file).  Not part of MAX.MAK.
PROJ     := MAXVRAM
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INC ../386MAX
PROGS    := RVMXTSR.COM RVMXDEV.SYS

RVMXTSR.COM_OBJS := RVMXTSR.OBJ
RVMXDEV.SYS_OBJS := RVMXDEV.OBJ
RVMXDEV.SYS_BIN  := 1
# no original objects in the tree
NOORIGOBJ := 1

include $(ROOT)/linux/mk/dos.mk
