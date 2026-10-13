# RDOSMAX.EXE, registers DOSMAX32.DLL (the Windows 95 shell extension);
# written anew for the open source build (GNU make, see linux/mk/win.mk)
PROJ     := RDOSMAX
ROOT     := $(abspath ..)
TARGET   := win32
INCDIRS  := . ../INCLUDE
CDEFS    := STRICT
PROGS    := RDOSMAX.EXE

RDOSMAX.EXE_OBJS := RDOSMAX.OBJ
RDOSMAX.EXE_LIBS := advapi32

include $(ROOT)/linux/mk/win.mk
