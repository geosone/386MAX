# GOAHEAD.DRV (installable driver) and GOAHEAD.EXE (GNU make, see
# linux/mk/win.mk)
PROJ     := GOAHEAD
ROOT     := $(abspath ..)
CMODEL   := s
SRCDIRS  := . ../MAXCTRL
INCDIRS  := . ../MAXCTRL ../INCLUDE ../INC
CDEFS    := NDEBUG
ASMDEFS  := DEBUG=0
PROGS    := GOAHEAD.DRV GOAHEAD.EXE
MSHINST  := GOAHEAD.EXE

# like the original (/AS /GA): no DLL start up code, SS = DS assumed
SETUPDDE.OBJ_CFLAGS :=
GOAHEAD.DRV_OBJS := GDADRV.OBJ GDARID.OBJ MISCFNS.OBJ STRFNS.OBJ SETUPDDE.OBJ
GOAHEAD.DRV_RC   := DRVELSE.RC DRVVERS.RC
GOAHEAD.DRV_DEF  := GDADRV.DEF
# clibs: OpenWatcom names its run time only in the module with the C entry
GOAHEAD.DRV_LIBS := toolhelp ddeml clibs
# entry point: LibMain of GDADRV.ASM (END LibMain) like the original, no
# OpenWatcom libentry.obj

GOAHEAD.EXE_OBJS := GOAHEAD.OBJ
GOAHEAD.EXE_RC   := APPELSE.RC APPVERS.RC
GOAHEAD.EXE_DEF  := GOAHEAD.DEF
GOAHEAD.EXE_LIBS := ver ctl3dv2

GOAHEAD.DRV_LINKOPTS += option protmode   # rc -t of the original
GOAHEAD.EXE_LINKOPTS += option protmode   # rc -t of the original
include $(ROOT)/linux/mk/win.mk
