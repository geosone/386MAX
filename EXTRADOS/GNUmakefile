# EXTRADOS.MAX (GNU make, see linux/mk/dos.mk; MAKEFILE is the original
# NMAKE file).  Most modules were assembled with ML 6, GETSIZE (386LOAD)
# and QMAX_MBT (386MAX) with Masm 5.1 and /D@HARPO.  There is no ML 6 here:
# the ML 6 modules are compared with the objects in RET/ (JWasm -Zm6); HARP_INI
# differs from it only by the GPL text (the source of the initial commit
# assembles to the identical object).
PROJ     := EXTRADOS
ROOT     := $(abspath ..)
SRCDIRS  := . ../386MAX ../386LOAD
ASMINC   := . ../INC ../386MAX ../386LOAD
PROGS    := EXTRADOS.MAX

EXTRADOS.MAX_OBJS := EXTRADOS.OBJ HARP_MSC.OBJ HARP_INI.OBJ HARP_FCN.OBJ HARP_DEV.OBJ \
	HARP_INS.OBJ GETSIZE.OBJ QMAX_MBT.OBJ VERSION.OBJ
EXTRADOS.MAX_MAP  := RET/EXTRADOS.map

EXTRADOS.OBJ_SRC  := HARPO.ASM
ML6OBJS  := EXTRADOS.OBJ HARP_MSC.OBJ HARP_INI.OBJ HARP_FCN.OBJ HARP_DEV.OBJ \
	HARP_INS.OBJ VERSION.OBJ
GETSIZE.OBJ_DEFS  := @HARPO
QMAX_MBT.OBJ_DEFS := @HARPO

include $(ROOT)/linux/mk/dos.mk
