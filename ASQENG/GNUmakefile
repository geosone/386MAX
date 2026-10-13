# LENGINER.LIB, the system analysis engine of ASQ, MAXIMIZE and INSTALL,
# large model (GNU make, see linux/mk/dos.mk; MAKEFILE is the original
# NMAKE file).  Microsoft C 7 is replaced by OpenWatcom.
PROJ     := ASQENG
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INC ../INCLUDE ../386MAX
CASEMAP  := mx
CMODEL   := l
DEFS     := MODEL=3
CDEFS    := DOS_VERSION
LIBS     := LENGINER.LIB

LENGINER.LIB_OBJS := ADF.OBJ BIOSID.OBJ CFG_INFO.OBJ CPUTEXT.OBJ ENGINE.OBJ GLIST.OBJ \
	HDW_INFO.OBJ INFO.OBJ MAPINFO.OBJ MEM_INFO.OBJ MULTIME.OBJ PROFILE.OBJ QTAS.OBJ \
	QTAS_MAC.OBJ READSYS.OBJ SYSBUF.OBJ SYSINFO.OBJ TESTMEM.OBJ TIMER.OBJ WRITSYS.OBJ \
	XMSINFO.OBJ FLEXROMS.OBJ BUSINFO.OBJ

# no original objects of the C build in the tree
NOORIGOBJ := 1

include $(ROOT)/linux/mk/dos.mk
