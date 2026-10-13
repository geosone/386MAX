# SFTTABS.DLL: tabbed dialogs for the Toolbox (replaces Softel's SftTabs
# 1.0; same interface and export ordinals, see SFTTABS.C)
PROJ     := SFTTABS
ROOT     := $(abspath ..)
CMODEL   := s
INCDIRS  := . ../INCLUDE
CDEFS    := STRICT
WINPROLOG := -zW
PROGS    := SFTTABS.DLL

SFTTABS.OBJ_CFLAGS := -zu -bd
SFTTABS.DLL_OBJS := SFTTABS.OBJ
SFTTABS.DLL_DEF  := SFTTABS.DEF
# (the DEF file gives the ordinals of the _export functions)
SFTTABS.DLL_LINKOPTS := file $(WATCOM)/lib286/win/libentry.obj disable 1121

include $(ROOT)/linux/mk/win.mk

# import library for the Toolbox
all: $(OUT)/SFTTABS.LIB
$(OUT)/SFTTABS.LIB: $(BINDIR)/SFTTABS.DLL
	rm -f $@
	$(OWBIN)/wlib -q -n $@ +$<
