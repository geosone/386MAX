# HELPENG - QuickHelp help engine for the DOS programs (LHELP.LIB, replaces
# the Microsoft help engine library), OpenWatcom large model
PROJ     := HELPENG
ROOT     := $(abspath ..)
SRCDIRS  := .
ASMINC   := . ../INCLUDE
CMODEL   := l
DEFS     := MODEL=LARGE
CDEFS    := DOS_VERSION
LIBS     := LHELP.LIB

LHELP.LIB_OBJS := HELPENG.OBJ

include $(ROOT)/linux/mk/dos.mk
