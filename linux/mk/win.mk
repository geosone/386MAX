# Common rules for the Windows programs of 386MAX: OpenWatcom (wcc/wpp,
# wrc, wlink) instead of Microsoft C 8 / Visual C++ 1.5, RC and LINK.
#
# A project GNUmakefile sets these variables and includes this file:
#   PROJ          project name, objects go to build/$(PROJ)
#   TARGET        win16 (default) or win32
#   CMODEL        win16 memory model s, m, c or l (default s)
#   CPACK         structure packing (Microsoft C /Zp, default 2, win32 8)
#   CDEFS         symbols for the C/C++ modules (NAME or NAME=VALUE)
#   CFLAGS_EXTRA  further wcc/wpp options
#   WINPROLOG     prologue of far functions: -zWs (default; smart callbacks
#                 like Microsoft C /GA: exported functions load DS from SS,
#                 so callbacks need no MakeProcInstance) or -zW (DLLs)
#   ASMDEFS       symbols for the assembler modules (JWasm -Zm -Cu, like Masm 5.1 /Mu)
#   SRCDIRS       directories searched for sources (default .)
#   INCDIRS       include directories (default . ../INCLUDE)
#   PROGS         programs/DLLs to build
#   <prog>_OBJS   objects; FOO.OBJ comes from FOO.C, FOO.CPP or FOO.ASM
#   <prog>_RC     resource script (optional)
#   <prog>_DEF    module definition file (translated by def2wlink.py)
#   <prog>_STUB   DOS stub program instead of the one the DEF file names
#   <prog>_STUBSRC source of the DOS stub (MASM 6 syntax): assembled with
#                 JWasm and linked with jwlink here (sets <prog>_STUB)
#   <prog>_LIBS   libraries (OpenWatcom names, e.g. commdlg ctl3dv2, or paths)
#   <prog>_LINKOPTS further wlink directives (win16: the stack is 8 KB unless
#                 the DEF file or these set it; wlink's own default is none.
#                 Programs are marked for Windows 3.1 like rc -31 did: Windows
#                 treats 3.0 programs differently, e.g. ignores HWND_TOPMOST
#                 moves.  rc -t (protected mode only): option protmode)
#   <prog>_FIRST  object files linked before <prog>_OBJS (paths)
#   <prog>_LINKER linker (default OpenWatcom wlink; JWlink keeps the first of
#                 several start addresses like Microsoft LINK)
#   <obj>_CFLAGS  options for one module
#   MSCOMPAT      1: link the OpenWatcom compatibility modules of linux/mk
#                 (owcompat.c, owcrtmsc.c, owmscw16.asm) and empty Microsoft
#                 C default libraries, for libraries made with or for the
#                 Microsoft C conventions (QUILIB, TEXT/*.LIB)
#   MSHINST       programs that use _hInstance of the Microsoft C start up
#                 code (linux/mk/owhinst.c; WinMain becomes owc_WinMain)
#   WX            1: wxWindows 1.68E (submodule wxWindows, wxWindows/build/
#                 lib/wx.lib): large model C++ with the library's options
#                 (no -ecc/-zp, no owwin.h), resource script includes wx.rc
#   MFC           1: Microsoft Foundation Classes 2.5 (build/mfc, made by
#                 linux/mfc: headers, owmfc.h, -zf, LAFXCW.LIB; large model).
#                 All modules then use OpenWatcom's convention (no -ecc);
#                 headers of libraries made for the Microsoft C convention
#                 mark their functions __cdecl for OpenWatcom C++ (QUILIB)
#   LIBRARIES     static libraries to build (build/$(PROJ)/<lib>)
#   <lib>_OBJS    their objects
#   <lib>_EXTRA   further objects made elsewhere (paths)
#
# Targets: all (default), clean.

ROOT    ?= $(abspath ..)
LX      := $(ROOT)/linux
include $(LX)/mk/version.mk
PYTHON  ?= python3
WATCOM  ?= /opt/watcom
export WATCOM
OWBIN   := $(WATCOM)/binl64
WCC     := $(OWBIN)/wcc
WPP     := $(OWBIN)/wpp
WCC386  := $(OWBIN)/wcc386
WPP386  := $(OWBIN)/wpp386
WRC     := $(OWBIN)/wrc
WLINK   := $(OWBIN)/wlink
JWASM   ?= $(LX)/bin/jwasm
JWLINK  ?= $(LX)/bin/jwlink
MAXLANG ?= US

OUT     := $(ROOT)/build/$(PROJ)
BINDIR  := $(if $(filter $(PROJ),$(notdir $(CURDIR))),$(ROOT)/build/bin,$(OUT)/bin)
TARGET  ?= win16
CMODEL  ?= s
CPACK   ?= $(if $(filter win32,$(TARGET)),8,2)
SRCDIRS ?= .
INCDIRS ?= . ../INCLUDE
CINCDIR := $(OUT)/inc

ifeq ($(TARGET),win32)
CC_C    := $(WCC386)
CC_CPP  := $(WPP386)
OWINC   := $(WATCOM)/h $(WATCOM)/h/nt
CFLAGS  := -bt=nt -mf -zp$(CPACK) -j -s -os -zq -ei
RCFLAGS := -bt=nt
else
CC_C    := $(WCC)
CC_CPP  := $(WPP)
OWINC   := $(WATCOM)/h $(WATCOM)/h/win
WINPROLOG ?= -zWs
CFLAGS  := -bt=windows $(WINPROLOG) -m$(CMODEL) -ecc -zp$(CPACK) -j -2 -s -os -zq -ei
RCFLAGS := -bt=windows
endif
ifneq ($(MSHINST),)
CDEFS   += WinMain=owc_WinMain _hInstance=owc_hInstance
endif
ifeq ($(MFC),1)
MFCOUT  := $(ROOT)/build/mfc
MFCLIB  := $(MFCOUT)/LAFXCW.LIB
# OpenWatcom names its C++ run time only in the module with the C entry;
# MFC itself calls COMMDLG and SHELL.  Full path: wlink would take the DOS
# plib of lib286 first
MFCRTL  := $(WATCOM)/lib286/win/plib$(CMODEL).lib commdlg shell
CDEFS   += OWMFC _WINDOWS
INCDIRS += $(MFCOUT)/include $(LX)/mk/owwin16
CPPFLAGS_MFC := -zf
CFLAGS  := $(filter-out -ecc,$(CFLAGS))
endif
ifeq ($(WX),1)
# as wxWindows/GNUmakefile builds the library: calling convention, packing
# and data threshold must match
WXDIR   := $(ROOT)/wxWindows
WXLIB   := $(WXDIR)/build/lib/wx.lib
WXRTL   := $(WATCOM)/lib286/win/plibl.lib commdlg mmsystem shell ddeml ctl3dv2
CMODEL  := l
INCDIRS += $(WXDIR)/include/msw $(WXDIR)/include/base $(WXDIR)/contrib/fafa
CFLAGS  := -bt=windows -zw -ml -zt256 -zq -fr -w1 -dwx_msw -dLANG_$(MAXLANG) $(VERDEFS_C) $(foreach d,$(CDEFS),-d$(d)) \
           -i=$(CINCDIR) $(foreach d,$(INCDIRS) $(OWINC),-i=$(d)) $(CFLAGS_EXTRA)
RCFLAGS += -i=$(WXDIR)/include/msw -i=$(WXDIR)/contrib/fafa
# one segment per library module would give more than the 254 segments the
# Windows loader takes: pack code and far data into 64 KB segments
WXLINKOPTS := option packcode=65520 option packdata=65520
else
CFLAGS  += -fr -fi=$(LX)/mk/owwin.h -i=$(LX)/mk -dLANG_$(MAXLANG) $(VERDEFS_C) $(foreach d,$(CDEFS),-d$(d)) -i=$(CINCDIR) \
           $(foreach d,$(INCDIRS) $(OWINC),-i=$(d)) $(CFLAGS_EXTRA)
endif

ALLOBJS := $(sort $(foreach p,$(PROGS) $(LIBRARIES),$($(p)_OBJS)))
srcof    = $(firstword $(foreach d,$(SRCDIRS),$(wildcard $(d)/$(basename $(1)).C $(d)/$(basename $(1)).CPP $(d)/$(basename $(1)).ASM $(d)/$(basename $(1)).c $(d)/$(basename $(1)).cpp)))
# German build (MAXLANG=GR): the resource scripts FOO.GR instead of FOO.RC
ifeq ($(MAXLANG),GR)
$(foreach p,$(PROGS),$(eval $(p)_RC := $(foreach r,$($(p)_RC),$(firstword $(wildcard $(basename $(r)).GR) $(r)))))
endif
RCSRCS  := $(foreach p,$(PROGS),$($(p)_RC))

all: $(addprefix $(OUT)/,$(LIBRARIES)) $(addprefix $(BINDIR)/,$(PROGS))

ifeq ($(MFC),1)
$(MFCLIB):
	$(MAKE) -C $(LX)/mfc
endif
ifeq ($(WX),1)
$(WXLIB):
	$(MAKE) -C $(WXDIR) lib
endif

define LIBRULE
$(OUT)/$(1): $(addprefix $(OUT)/,$($(1)_OBJS)) $($(1)_EXTRA)
	rm -f $$@
	$(OWBIN)/wlib -q -n -b $$@ $$(addprefix +,$$^)
endef
$(foreach l,$(LIBRARIES),$(eval $(call LIBRULE,$(l))))

$(OUT) $(BINDIR):
	mkdir -p $@

# include names as written in the sources -> files (case insensitive)
$(CINCDIR)/.done: $(MAKEFILE_LIST) $(foreach o,$(ALLOBJS),$(call srcof,$(o))) $(RCSRCS) $(LX)/tools/mkincdir.py | $(OUT)
	rm -rf $(CINCDIR)
	$(PYTHON) $(LX)/tools/mkincdir.py $(CINCDIR) $(INCDIRS) $(SRCDIRS) $(OWINC) -- $(filter-out %.py,$^)
	for d in $(SRCDIRS); do for f in $$d/*; do [ -f "$$f" ] || continue; \
	  l=$$(basename "$$f" | tr A-Z a-z); [ -e "$(CINCDIR)/$$l" ] || ln -s "$$(realpath "$$f")" "$(CINCDIR)/$$l"; \
	  b=$$(basename "$$f"); [ -e "$(CINCDIR)/$$b" ] || ln -s "$$(realpath "$$f")" "$(CINCDIR)/$$b"; done; done
	touch $@

define OBJRULE
$(OUT)/$(1): $(call srcof,$(1)) $(CINCDIR)/.done $(VERSION_FILE) $(LX)/mk/owwin.h $(if $(MFC),$(LX)/mk/owmfc.h $(MFCLIB)) $(if $(WX),$(WXLIB)) | $(OUT)
	$$(if $$(filter %.ASM,$$<),$(JWASM) -q -Zm -Cu -c -DLANG_$(MAXLANG) $(VERDEFS_ASM) $(addprefix -D,$(ASMDEFS)) -Fo$$@ $$(foreach d,$(INCDIRS),-I$$(d)) $$<,\
	  $$(if $$(filter %.CPP %.cpp,$$<),$(CC_CPP) $(CPPFLAGS_MFC),$(CC_C)) $(CFLAGS) $$($(1)_CFLAGS) -fo=$$@ $$<)
endef
$(foreach o,$(ALLOBJS),$(eval $(call OBJRULE,$(o))))

ifeq ($(MSCOMPAT),1)
WLIB    := $(OWBIN)/wlib
$(OUT)/OWCOMPAT.OBJ: $(LX)/mk/owcompat.c $(LX)/mk/owcompat.h | $(OUT)
	$(CC_C) $(CFLAGS) -fi=$(LX)/mk/owcompat.h -fo=$@ $<
$(OUT)/OWCRTMSC.OBJ: $(LX)/mk/owcrtmsc.c | $(OUT)
	$(CC_C) $(filter-out -fi=%,$(CFLAGS)) -r -fo=$@ $<
$(OUT)/OWAHINCR.OBJ: $(LX)/mk/owahincr.asm | $(OUT)
	$(JWASM) -c -q -Cx -Fo$@ $<
$(OUT)/OWMSCW16.OBJ: $(LX)/mk/owmscw16.asm | $(OUT)
	$(JWASM) -c -q -Cx -Fo$@ $<
# Windows: __AHINCR comes from KERNEL (windows.lib)
MSCOBJS := OWCOMPAT.OBJ OWCRTMSC.OBJ $(if $(filter win32,$(TARGET)),OWAHINCR.OBJ,OWMSCW16.OBJ)
MSCLIBS := SLIBCE MLIBCE CLIBCE LLIBCE SLIBCEW MLIBCEW CLIBCEW LLIBCEW SDLLCEW \
           MDLLCEW LDLLCEW LIBW OLDNAMES
$(OUT)/msclib/.done: | $(OUT)
	mkdir -p $(OUT)/msclib
	for l in $(MSCLIBS); do rm -f $(OUT)/msclib/$$l.lib && $(WLIB) -q -n $(OUT)/msclib/$$l.lib || exit 1; done
	touch $@
endif

$(OUT)/OWHINST.OBJ: $(LX)/mk/owhinst.c | $(OUT)
	$(CC_C) $(filter-out -dWinMain=% -d_hInstance=%,$(CFLAGS)) -fo=$@ $<

# DOS stubs from source (<prog>_STUBSRC)
define STUBRULE
$(1)_STUB := $(OUT)/$(basename $(notdir $($(1)_STUBSRC))).EXE
$(OUT)/$(basename $(notdir $($(1)_STUBSRC))).EXE: $($(1)_STUBSRC) | $(OUT)
	$(JWASM) -q -c -DLANG_$(MAXLANG) $$(foreach d,$(INCDIRS),-I$$(d)) -Fo$$(@:.EXE=.OBJ) $$<
	cd $(OUT) && $(JWLINK) format dos name $$(notdir $$@) option quiet file $$(notdir $$(@:.EXE=.OBJ))
endef
$(foreach p,$(PROGS),$(if $($(p)_STUBSRC),$(eval $(call STUBRULE,$(p)))))

define PROGRULE
# resources: preprocessed by wrc -o, string literals merged (rcprep.py),
# compiled by wrc in the directory with
# the case-insensitive file names (icons, bitmaps); several scripts give
# several .res files that are concatenated (as the original makefiles did;
# -zm: Microsoft format, OpenWatcom's own has a file header; resfix.py
# repairs the 16-bit format only)
$(OUT)/$(1).res: $($(1)_RC) $(CINCDIR)/.done $(VERSION_FILE) $(LX)/tools/rcprep.py $(LX)/tools/resfix.py | $(OUT)
	rm -f $$@
	for r in $($(1)_RC); do b=$$$$(basename $$$$r); \
	  (cd $(CINCDIR) && $(WRC) -o -q $(RCFLAGS) -dLANG_$(MAXLANG) $(VERDEFS_C) $(foreach d,$(CDEFS),-d$(d)) \
	    -i=$(CINCDIR) $(foreach d,$(abspath $(INCDIRS)) $(OWINC),-i=$(d)) -fo=$$$$b.i $(CURDIR)/$$$$r) && \
	  $(PYTHON) $(LX)/tools/rcprep.py $(CINCDIR)/$$$$b.i $(CINCDIR)/$$$$b.rcp && \
	  (cd $(CINCDIR) && $(WRC) -r -q -zm $(RCFLAGS) -i=$(CINCDIR) -fo=$$@.part $$$$b.rcp) && \
	  $(if $(filter win32,$(TARGET)),,$(PYTHON) $(LX)/tools/resfix.py $$@.part &&) \
	  cat $$@.part >> $$@ || exit 1; done
	rm -f $$@.part

$(OUT)/$(1).lnk: $($(1)_DEF) $($(1)_STUB) $(LX)/tools/def2wlink.py $(if $(filter win32,$(TARGET)),$(addprefix $(OUT)/,$($(1)_OBJS))) | $(OUT)
	$(PYTHON) $(LX)/tools/def2wlink.py $(if $($(1)_STUB),--stub=$($(1)_STUB)) $$< $(TARGET) $(if $(filter win32,$(TARGET)),$(addprefix $(OUT)/,$($(1)_OBJS))) > $$@

$(OUT)/$(1): $(filter %.LIB %.lib,$($(1)_LIBS)) $(addprefix $(OUT)/,$($(1)_OBJS) $(MSCOBJS) $(if $(filter $(1),$(MSHINST)),OWHINST.OBJ)) $(MFCLIB) $(if $(MSCOBJS),$(OUT)/msclib/.done) $(if $($(1)_RC),$(OUT)/$(1).res) $(if $($(1)_DEF),$(OUT)/$(1).lnk)
	cd $(OUT) && $(or $($(1)_LINKER),$(WLINK)) option quiet \
	  $$(if $$(shell grep -q '^# kind dll' $(OUT)/$(1).lnk 2>/dev/null && echo dll),\
	    $(if $(filter win32,$(TARGET)),format windows nt dll,format windows dll),\
	    $(if $(filter win32,$(TARGET)),format windows nt,format windows)) \
	  name $(1) \
	  $(if $(filter win32,$(TARGET)),libpath $(WATCOM)/lib386/nt libpath $(WATCOM)/lib386 library kernel32 library user32 library gdi32,\
	    libpath $(WATCOM)/lib286/win libpath $(WATCOM)/lib286 library windows option nocaseexact) \
	  $(foreach o,$($(1)_FIRST) $($(1)_OBJS) $(MSCOBJS) $(if $(filter $(1),$(MSHINST)),OWHINST.OBJ),file $(o)) $(if $(MSCOBJS),libpath msclib) \
	  $(foreach l,$($(1)_LIBS) $(MFCLIB) $(MFCRTL) $(WXLIB) $(WXRTL),library $(l)) \
	  $(if $(filter win32,$(TARGET)),,option stack=8k option version=3.10) \
	  $(if $($(1)_DEF),@$(1).lnk) \
	  $(if $($(1)_RC),option resource=$(1).res) \
	  option map=$(1).map $($(1)_LINKOPTS) $(WXLINKOPTS)

$(BINDIR)/$(1): $(OUT)/$(1) | $(BINDIR)
	cp $$< $$@
endef
$(foreach p,$(PROGS),$(eval $(call PROGRULE,$(p))))

clean:
	rm -rf $(OUT) $(addprefix $(BINDIR)/,$(PROGS))

.PHONY: all clean
