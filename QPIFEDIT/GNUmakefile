# QPIFEDIT.EXE, the PIF editor (GNU make, see linux/mk/win.mk; MAKEFILE is
# the original NMAKE build with Microsoft C 8).  The DOS stub qpifstub.exe
# is prebuilt.
PROJ     := QPIFEDIT
ROOT     := $(abspath ..)
CMODEL   := s
CPACK    := 1
CDEFS    := DEBUG
INCDIRS  := . ../INCLUDE ../INC
PROGS    := QPIFEDIT.EXE

QPIFEDIT.EXE_OBJS := QPIFEDIT.OBJ
QPIFEDIT.EXE_RC   := QPIFEDIT.RC
QPIFEDIT.EXE_DEF  := QPIFEDIT.DEF
QPIFEDIT.EXE_LIBS := commdlg ctl3dv2

include $(ROOT)/linux/mk/win.mk
