# ASQ.EXE, the system analysis program (GNU make, see linux/mk/dos.mk;
# MAKEFILE is the original NMAKE file).  Microsoft C 7 is replaced by
# OpenWatcom.
PROJ     := ASQ
ROOT     := $(abspath ..)
SRCDIRS  := . ../386MAX
ASMINC   := . ../INCLUDE ../INC ../QUILIB ../ASQENG ../386MAX
CASEMAP  := mx
CMODEL   := l
DEFS     := MODEL=LARGE BETA=0 SNAPSHOT=0
CDEFS    := DOS_VERSION
PROGS    := ASQ.EXE

ASQ.EXE_OBJS  := AMAIN.OBJ AHELP.OBJ ASQPRINT.OBJ ADFSPEC.OBJ ASQ.OBJ SNAP.OBJ ABORT.OBJ \
	READPROF.OBJ ASQDATA.OBJ VERSBETA.OBJ VERSDATA.OBJ VERSRET.OBJ ZZTAIL.OBJ
ASQ.EXE_LIBS  := $(ROOT)/build/QUILIB/LQUILIBR.LIB $(ROOT)/build/ASQENG/LENGINER.LIB \
	$(ROOT)/build/HELPENG/LHELP.LIB $(ROOT)/build/VERLIB/VERL.LIB
ASQ.EXE_STACK := 9000
# segment order of the original link (BUSINFO calls SRCHSTR of SVGA_INF
# near: both must be in one packed code segment)
ASQ.EXE_MAP   := ../LIB/ASQ.MAP

# no original objects of the C build in the tree
NOORIGOBJ := 1

include $(ROOT)/linux/mk/dos.mk
