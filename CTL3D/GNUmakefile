# CTL3DV2.DLL and CTL3DS.LIB: 3D dialog colors for the Windows programs
# (replaces Microsoft's CTL3DV2.DLL and its static library; same interface
# and export ordinals, see CTL3D.C)
PROJ     := CTL3D
ROOT     := $(abspath ..)
CMODEL   := s
INCDIRS  := . ../INCLUDE
CDEFS    := STRICT
WINPROLOG := -zW
PROGS    := CTL3DV2.DLL
LIBRARIES := CTL3DS.LIB

CTL3D.OBJ_CFLAGS := -zu -bd -DCTL3D_DLL
CTL3DV2.DLL_OBJS := CTL3D.OBJ
CTL3DV2.DLL_DEF  := CTL3DV2.DEF
# (the DEF file gives the ordinals of the _export functions)
CTL3DV2.DLL_LINKOPTS := file $(WATCOM)/lib286/win/libentry.obj disable 1121

# the static library: large model like SETUP
CTL3DS.OBJ_CFLAGS := -ml -zWs
CTL3DS.LIB_OBJS := CTL3DS.OBJ

include $(ROOT)/linux/mk/win.mk
