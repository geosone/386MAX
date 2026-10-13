# EVAP.EXE, DOS helper of the Toolbox (GNU make, see linux/mk/dos.mk;
# used by GNUmakefile).  Microsoft C is replaced by OpenWatcom.
PROJ     := MAXCTRL/EVAP
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INCLUDE ../INC
CMODEL   := l
CPACK    := 1
PROGS    := EVAP.EXE

EVAP.EXE_OBJS := EVAP.OBJ


include $(ROOT)/linux/mk/dos.mk
