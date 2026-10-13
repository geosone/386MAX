# QPOPUP.EXE (GNU make, see linux/mk/win.mk).  The DOS stub qpopstub.exe is prebuilt.
PROJ     := QPOPUP
ROOT     := $(abspath ..)
CMODEL   := s
CPACK    := 1
CDEFS    := _DEBUG
INCDIRS  := . ../INCLUDE ../INC
PROGS    := QPOPUP.EXE

QPOPUP.EXE_OBJS := QPOPUP.OBJ
QPOPUP.EXE_RC   := QPOPUP.RC
QPOPUP.EXE_DEF  := QPOPUP.DEF
QPOPUP.EXE_LIBS := toolhelp

include $(ROOT)/linux/mk/win.mk
