# MAXEDIT.EXE, the Windows editor for the 386MAX profile and CONFIG.SYS
# (GNU make, see linux/mk/win.mk; MAKEFILE/MAXEDIT.MAK is the original
# NMAKE build with Microsoft C 8)
PROJ     := MAXEDIT
ROOT     := $(abspath ..)
CMODEL   := s
CPACK    := 1
PROGS    := MAXEDIT.EXE

MAXEDIT.EXE_OBJS := MAXEDIT.OBJ TOOLBAR.OBJ
MAXEDIT.EXE_RC   := MAXEDIT.RC
MAXEDIT.EXE_DEF  := MAXEDIT.DEF
MAXEDIT.EXE_LIBS := commdlg toolhelp shell ctl3dv2

include $(ROOT)/linux/mk/win.mk
