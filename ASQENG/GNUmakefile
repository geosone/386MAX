# LENGINER.LIB, the system analysis engine of ASQ, MAXIMIZE and INSTALL,
# large model (GNU make, see linux/mk/dos.mk).  Microsoft C 7 is replaced by OpenWatcom.
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
	XMSINFO.OBJ FLEXROMS.OBJ BUSINFO.OBJ MODINFO.OBJ MODREPT.OBJ MODHW.OBJ

# texts in the code segment: DGROUP of ASQ plus its 9000 byte stack must
# stay below 64 KB (the stack lies behind _BSS)
MODREPT.OBJ_CFLAGS := -zc
MODINFO.OBJ_CFLAGS := -zc


include $(ROOT)/linux/mk/dos.mk
