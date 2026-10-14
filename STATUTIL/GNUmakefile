# STATUTIL: utility libraries of the 386MAX Windows programs (GNU make, see
# linux/mk/win.mk.5, here only its Windows 3.1 large model variant):
#   LSTUTIL.LIB  general functions
PROJ     := STATUTIL
ROOT     := $(abspath ..)
CMODEL   := l
CPACK    := 1
# called from WINMAXIM, a wxWindows program: OpenWatcom's convention
CCONV    :=
INCDIRS  := . ../INCLUDE ../INC
CDEFS    := _WIN16
# The original /ALw (SS != DS) isn't used: the libraries only go into
# programs (WINMXMZ), which get smart callbacks (-zWs, needs SS = DS)

LIBRARIES := LSTUTIL.LIB
LSTUTIL.LIB_OBJS := GETDIR.OBJ DOSDIR.OBJ HASH.OBJ ACCESS.OBJ SECURITY.OBJ \
                    GSTRING.OBJ STRSTK.OBJ ISTEXT.OBJ ZOPEN.OBJ STKINFO.OBJ \
                    DRIVETYP.OBJ FILECOPY.OBJ TDUTIL.OBJ CTIMEDT.OBJ

include $(ROOT)/linux/mk/win.mk
