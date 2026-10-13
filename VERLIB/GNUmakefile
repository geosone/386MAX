# VERLIB - version resources of Windows executables (VERL.LIB, replaces the
# library version of VER.DLL from the Windows SDK), OpenWatcom large model
PROJ     := VERLIB
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INCLUDE
CMODEL   := l
DEFS     := MODEL=LARGE
CDEFS    := DOS_VERSION
LIBS     := VERL.LIB

VERL.LIB_OBJS := VERLIB.OBJ

include $(ROOT)/linux/mk/dos.mk
