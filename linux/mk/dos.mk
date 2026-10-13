# Common rules for the DOS programs of 386MAX written in assembler:
# patched JWasm (Masm 5.1 mode) and JWlink, see linux/scripts/build-tools.sh.
#
# A project GNUmakefile sets these variables and includes this file:
#   PROJ          project name, objects go to build/$(PROJ) (may be
#                 PROJECT/VARIANT for several builds of one directory)
#   DEFS          symbols defined for all modules (NAME or NAME=VALUE)
#   CASEMAP       mu (default: names in upper case, Masm /mu), ml (case
#                 sensitive, Masm /ml) or mx (case kept for PUBLIC/EXTRN, /Mx)
# C (OpenWatcom instead of Microsoft C 7/8, see owcompat.h):
#   CMODEL        memory model s, m, c or l; FOO.OBJ comes from FOO.C if there
#   CDEFS         symbols for the C modules
#   CPACK         structure packing (Microsoft C /Zp, default 2)
#   <lib>_OBJS    for LIBS: libraries made with wlib (FOO.LIB)
#   PROS          prototype files made from C sources like "cl /Zg" (FOO.PRO
#                 from FOO.C, written as foo.pro, see protogen.py)
#   PRODEFS       symbols for making them (PFLAGS of the original makefile)
#   <prog>_LIBS   libraries linked to a program (paths), with C programs the
#                 OpenWatcom run time is added
#   ML6OBJS       objects the original build assembled with ML 6 (MASM 6):
#                 JWasm -Zm6 instead of -Zm
#   <obj>_DEFS    symbols defined for one module
#   SRCDIRS       directories searched for sources (relative to the project)
#   ASMINC        include directories in the order Masm searched them
#                 (build/$(PROJ) for generated files comes first)
#   PROGS         programs to build (.SYS/.EXE: MZ, .COM: binary)
#   <prog>_OBJS   objects in link order; FOO.OPT is FOO.ASM assembled with
#                 /DOPTIM, FOO.NRM without (both as in the Masm build)
#   <prog>_MAP    map file of Microsoft LINK: segment order (optional)
#   <prog>_BIN    1: binary image made with EXE2BIN (device drivers at offset 0)
#   <prog>_COM    1: COM format (link /t) for a name not ending in .COM
#   <prog>_FORMAT JWlink format (default: dos, or dos com for .COM)
#   <prog>_LINKOPTS further JWlink directives
#   <prog>_MAXALLOC MZ header maximum allocation in paragraphs (LINK /CP:)
#   <obj>_PREBUILT object that is not assembled here but copied (path)
#   <obj>_SRC     source when it is not <obj base>.ASM (optional; an
#                 absolute path for a source made during the build)
#   GENERATED     files copied into build/$(PROJ): DEST=SOURCE (optional)
#   EMPTYINC      include files made by Qualitas build tools that hold only
#                 comments (e.g. DIRNTRY.INC): created with a comment line
#
# Targets: all (default), clean.

ROOT    ?= $(abspath ..)
LX      := $(ROOT)/linux
include $(LX)/mk/version.mk
JWASM   ?= $(LX)/bin/jwasm
JWLINK  ?= $(LX)/bin/jwlink
PYTHON  ?= python3
# LANG is the locale of the shell, the product language is MAXLANG
MAXLANG ?= US
OUT     := $(ROOT)/build/$(PROJ)
# a variant build (make PROJ=386MAX-cpd ...) keeps its programs in $(OUT);
# PROJ=DIR/NAME (a second program of DIR) installs into build/bin
BINDIR  := $(if $(filter $(notdir $(CURDIR)),$(firstword $(subst /, ,$(PROJ)))),$(ROOT)/build/bin,$(OUT)/bin)

SRCDIR  := $(notdir $(CURDIR))
CASEMAP ?= mu
JWCASE  := $(if $(filter ml,$(CASEMAP)),-Cp,$(if $(filter mx,$(CASEMAP)),-Cx,-Cu))
AFLAGS  := -Zm $(JWCASE) -c -q -W1 -DLANG_$(MAXLANG) $(VERDEFS_ASM) $(foreach d,$(DEFS),"-D$(d)") -I$(OUT) $(addprefix -I,$(ASMINC))
# ML 6: /Cu /Sp63 /W1 (-Zm6: ML 6.0 operand sizes, see linux/jwasm)
AFLAGS6 := -Zm6 $(JWCASE) -c -q -W1 -DLANG_$(MAXLANG) $(VERDEFS_ASM) $(foreach d,$(DEFS),"-D$(d)") -I$(OUT) $(addprefix -I,$(ASMINC))

ALLOBJS := $(sort $(foreach p,$(PROGS) $(LIBS),$($(p)_OBJS)))
GENFILES := $(foreach g,$(GENERATED),$(OUT)/$(firstword $(subst =, ,$(g))))
GENFILES += $(addprefix $(OUT)/,$(EMPTYINC))

# everything an object can depend on: the include files of all include dirs
INCDEPS := $(wildcard $(addsuffix /*.INC,$(ASMINC) .) $(addsuffix /*.inc,$(ASMINC) .))

comma := ,
empty :=
space := $(empty) $(empty)

srcof = $(if $(filter /%,$($(1)_SRC)),$($(1)_SRC),$(firstword $(wildcard $(foreach x,$(or $($(1)_SRC),$(basename $(1)).ASM $(basename $(1)).C $(basename $(1)).c),$(addsuffix /$(x),$(SRCDIRS))))))
isc = $(filter %.C %.c,$(call srcof,$(1)))
defsof = $(if $(filter %.OPT,$(1)),-DOPTIM)

.PHONY: all clean
.SUFFIXES:
.DELETE_ON_ERROR:

all: $(addprefix $(BINDIR)/,$(PROGS)) $(addprefix $(OUT)/,$(LIBS))

$(OUT) $(BINDIR):
	mkdir -p $@

define GENRULE
$(OUT)/$(1): $(2) | $(OUT)
	cp $$< $$@
endef
$(foreach g,$(GENERATED),$(eval $(call GENRULE,$(firstword $(subst =, ,$(g))),$(lastword $(subst =, ,$(g))))))

$(addprefix $(OUT)/,$(EMPTYINC)): | $(OUT)
	printf '; made by the build (originally written by a Qualitas tool)\r\n' > $@

define PREBUILTRULE
$(OUT)/$(1): $($(1)_PREBUILT) | $(OUT)
	cp $$< $$@
endef
$(foreach o,$(ALLOBJS),$(if $($(o)_PREBUILT),$(eval $(call PREBUILTRULE,$(o)))))
ASMOBJS := $(foreach o,$(ALLOBJS),$(if $($(o)_PREBUILT),,$(if $(call isc,$(o)),,$(o))))
COBJS   := $(foreach o,$(ALLOBJS),$(if $(call isc,$(o)),$(o)))

define OBJRULE
$(OUT)/$(1): $(call srcof,$(1)) $(INCDEPS) $(GENFILES) $(JWASM) $(VERSION_FILE) | $(OUT)
	$(JWASM) $(if $(filter $(1),$(ML6OBJS)),$(AFLAGS6),$(AFLAGS)) $(call defsof,$(1)) $(addprefix -D,$($(1)_DEFS)) -Fl=$(OUT)/$(subst .,_,$(1)).LST -Fw$(OUT)/$(1).err -Fo$$@ $$< > $(OUT)/$(1).log || { cat $(OUT)/$(1).log; exit 1; }
endef
$(foreach o,$(ASMOBJS),$(eval $(call OBJRULE,$(o))))

# C: OpenWatcom wcc with the conventions of Microsoft C: cdecl (-ecc),
# signed char (-j), int-sized enums (-ei), 2 byte packing (-zp2), no stack
# checks (/Gs = -s); owcompat.h in front of every module; after linking,
# DS:0000 (_NULL) is cleared like Microsoft C has it (linux/tools/mznull.py)
WATCOM  ?= /opt/watcom
OWBIN   := $(WATCOM)/binl64
# structure packing of the C modules (Microsoft C /Zp, default 2)
CPACK   ?= 2
WCC     := $(OWBIN)/wcc
WLINK   := $(OWBIN)/wlink
WLIB    := $(OWBIN)/wlib
CINCDIR := $(OUT)/cinc
# CDEBUGINC: include directory searched first (debug headers)
CFLAGS  := -bt=dos -m$(CMODEL) -ecc -ei -j -zp$(CPACK) -r -s -zq -os -fr -fi=$(LX)/mk/owcompat.h \
	-DLANG_$(MAXLANG) $(VERDEFS_C) $(foreach d,$(CDEFS),"-D$(d)") $(if $(CDEBUGINC),-i=$(CDEBUGINC)) -i=$(CINCDIR) -i=$(OUT)/pro $(addprefix -i=,$(ASMINC)) -i=$(WATCOM)/h
export WATCOM

CINCSRCS = $(sort $(foreach o,$(COBJS),$(call srcof,$(o))) $(foreach p,$(PROS),$(call srcof,$(basename $(p)).OBJ)))
$(CINCDIR)/.done: $(CINCSRCS) $(LX)/tools/mkincdir.py | $(OUT)
	rm -rf $(CINCDIR)
	$(PYTHON) $(LX)/tools/mkincdir.py $(CINCDIR) $(ASMINC) $(WATCOM)/h -- $(CINCSRCS)
	touch $@

# prototype files (Microsoft C "cl /Zg"): preprocess with #line markers,
# then take the heads of the functions defined in the source
lc = $(shell echo $(1) | tr A-Z a-z)
PROFILES := $(foreach f,$(PROS),$(OUT)/pro/$(call lc,$(f)))
define PRORULE
$(OUT)/pro/$(call lc,$(1)): $(call srcof,$(basename $(1)).OBJ) $(CINCDIR)/.done $(LX)/tools/protogen.py
	mkdir -p $(OUT)/pro
	$(WCC) -pl $(CFLAGS) $(foreach d,$(PRODEFS),"-D$(d)") -fo=$$@.i $$< > $$@.log 2>&1 || { cat $$@.log; exit 1; }
	$(PYTHON) $(LX)/tools/protogen.py $$@.i $$< > $$@
endef
$(foreach f,$(PROS),$(eval $(call PRORULE,$(f))))

define COBJRULE
$(OUT)/$(1): $(call srcof,$(1)) $(INCDEPS) $(wildcard $(addsuffix /*.H,$(ASMINC))) $(CINCDIR)/.done $(LX)/mk/owcompat.h $(PROFILES) $(VERSION_FILE)
	$(WCC) $(CFLAGS) $(foreach d,$($(1)_DEFS),"-D$(d)") -fo=$$@ $$< > $(OUT)/$(1).log 2>&1 || { cat $(OUT)/$(1).log; exit 1; }
endef
$(foreach o,$(COBJS),$(eval $(call COBJRULE,$(o))))

# wrappers for the callbacks of the run time (owcompat.h), linked to every
# program with C modules
$(OUT)/OWCOMPAT.OBJ: $(LX)/mk/owcompat.c $(LX)/mk/owcompat.h | $(OUT)
	$(WCC) $(CFLAGS) -fo=$@ $< > $@.log 2>&1 || { cat $@.log; exit 1; }
# names of the Microsoft C run time (VERL.LIB, assembler modules)
$(OUT)/OWCRTMSC.OBJ: $(LX)/mk/owcrtmsc.c | $(OUT)
	$(WCC) -bt=dos -m$(CMODEL) -ecc -j -zp2 -r -s -zq -fr -os -fo=$@ $< > $@.log 2>&1 || { cat $@.log; exit 1; }
$(OUT)/OWAHINCR.OBJ: $(LX)/mk/owahincr.asm $(JWASM) | $(OUT)
	$(JWASM) -c -q -Cx -Fo$@ $< > $@.log 2>&1 || { cat $@.log; exit 1; }
OWOBJS := OWCOMPAT.OBJ OWCRTMSC.OBJ OWAHINCR.OBJ
# Microsoft C default libraries requested by libraries compiled with it
# (TEXT/VERL.LIB): empty, OpenWatcom's run time takes their place
MSCLIBS := SLIBCE.lib MLIBCE.lib CLIBCE.lib LLIBCE.lib OLDNAMES.lib
# one rule for all (wlib uses a fixed temporary file name)
$(OUT)/msclib/.done: | $(OUT)
	mkdir -p $(OUT)/msclib
	for l in $(MSCLIBS); do rm -f $(OUT)/msclib/$$l && $(WLIB) -q -n $(OUT)/msclib/$$l || exit 1; done
	touch $@

define LIBRULE
$(OUT)/$(1): $(addprefix $(OUT)/,$($(1)_OBJS))
	rm -f $$@
	$(WLIB) -q -n -b $$@ $$(addprefix +,$$^)
endef
$(foreach l,$(LIBS),$(eval $(call LIBRULE,$(l))))

# link; Microsoft LINK's segment order comes from its map (<prog>_MAP)
# $(call LINKCMD,program,directory of the objects)
LINKCMD = cd $(2) && $(JWLINK) format $(or $($(1)_FORMAT),dos $(if $(or $(filter %.COM,$(1)),$($(1)_COM)),com)) name $(1)$(if $($(1)_BIN),.EXE) \
	    option quiet option map=$(1).MAP $(if $($(1)_FORMAT),,option stack=0) option nofarcalls $($(1)_LINKOPTS) \
	    $(if $($(1)_MAP),@$(1).ORD) file $(subst $(space),$(comma),$(strip $($(1)_OBJS))) > $(1).log \
	    || { cat $(1).log; exit 1; } \
	    $(if $($(1)_BIN),&& $(PYTHON) $(LX)/tools/exe2bin.py $(1).EXE $(1))

# programs with C modules: JWlink (handles the AT segments and groups of
# the assembler modules like Microsoft LINK) with the OpenWatcom run time
CLINKCMD = cd $(2) && $(JWLINK) format dos name $(1) option quiet option map=$(1).MAP option nofarcalls option redefsok option packcode=65530 \
	    libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286 libpath $(OUT)/msclib \
	    $(if $($(1)_STACK),option stack=$($(1)_STACK)) \
	    $(if $($(1)_MAP),@$(1).ORD) $($(1)_LINKOPTS) \
	    file $(subst $(space),$(comma),$(strip $($(1)_OBJS) $(OWOBJS))) \
	    $(if $($(1)_LIBS),library $(subst $(space),$(comma),$(strip $($(1)_LIBS)))) > $(1).log \
	    || { cat $(1).log; exit 1; }
hasc = $(strip $(foreach o,$($(1)_OBJS),$(call isc,$(o))))

define LINKRULE
$(OUT)/$(1): $(addprefix $(OUT)/,$($(1)_OBJS)) $(if $(call hasc,$(1)),$(addprefix $(OUT)/,$(OWOBJS)) $(OUT)/msclib/.done) $($(1)_LIBS) $($(1)_MAP) $(JWLINK)
	$(if $($(1)_MAP),$(PYTHON) $(LX)/tools/map2lnk.py $($(1)_MAP) > $(OUT)/$(1).ORD)
	$(if $(call hasc,$(1)),$(call CLINKCMD,$(1),$(OUT)),$(call LINKCMD,$(1),$(OUT)))
	$(if $(call hasc,$(1)),$(PYTHON) $(LX)/tools/mznull.py $(OUT)/$(1) $(OUT)/$(1).MAP)
	$(if $($(1)_MAXALLOC),$(PYTHON) $(LX)/tools/mzmaxalloc.py $(OUT)/$(1) $($(1)_MAXALLOC))

$(BINDIR)/$(1): $(OUT)/$(1) | $(BINDIR)
	cp $$< $$@
endef
$(foreach p,$(PROGS),$(eval $(call LINKRULE,$(p))))

clean:
	rm -rf $(OUT) $(addprefix $(BINDIR)/,$(PROGS))

