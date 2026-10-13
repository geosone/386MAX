# QPIFEDIT.EXE, the PIF editor (GNU make, see linux/mk/win.mk). The DOS stub is built from QPIFSTUB.ASM.
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
QPIFEDIT.EXE_STUBSRC := QPIFSTUB.ASM
QPIFEDIT.EXE_LIBS := commdlg ctl3dv2

include $(ROOT)/linux/mk/win.mk
