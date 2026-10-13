# LQUILIBW.LIB: the QUILIB functions the Windows programs use (MAXSETUP,
# WINMXMZ), compiled for Windows (GNU make, see linux/mk/win.mk; used by
# GNUmakefile).  The original programs linked the DOS LQUILIBR.LIB: Microsoft
# C's large model keeps DS = DGROUP in both; OpenWatcom's DOS build doesn't.
# The assembler modules are taken from the DOS build (build/QUILIB).
PROJ     := QUILIB-W
ROOT     := $(abspath ..)
CMODEL   := l
CDEFS    := DOS_VERSION
INCDIRS  := . ../INCLUDE ../INC

LIBRARIES := LQUILIBW.LIB
LQUILIBW.LIB_OBJS  := BOOTDRV.OBJ EXENAME.OBJ MBPARSE.OBJ QMAXPRES.OBJ TRUENAME.OBJ
LQUILIBW.LIB_EXTRA := $(addprefix $(ROOT)/build/QUILIB/,DMALLOC.OBJ RAMSCAN.OBJ \
	BIOSCRC.OBJ DPMI_CRC.OBJ VCPI_CRC.OBJ VENDINFO.OBJ)

include $(ROOT)/linux/mk/win.mk
