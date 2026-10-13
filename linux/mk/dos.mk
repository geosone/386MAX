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
#                 JWasm without -Zm; their reference is the object in RET/
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
#   <prog>_ORIG   original binary for "make check" (default: RET/<prog>)
#   NOORIGOBJ     1: RET/ holds no original objects of this build (origlink)
#   NOMASM        1: Masm 5.10A can't assemble this project; masmref takes
#                 the original objects (ORIGDIRS) as references
#   ORIGDIRS      directories with the original objects (default: RET COMN)
#   <obj>_REF     reference object for a module Masm 5.10A cannot assemble
#                 (e.g. the original object in RET/), used by masmref
#   EMPTYINC      include files made by Qualitas build tools that hold only
#                 comments (e.g. DIRNTRY.INC): created with a comment line
#
# Targets: all (default), clean, check (compare with the original
# binaries in RET/), masmref (Masm 5.10 reference objects, needs MASM_EXE
# and DOSBox), cmp (compare the objects with those references), cmplink
# (link the Masm references the same way and compare the programs),
# origlink (link the original objects of RET/ and COMN/ and compare with
# the original programs: checks JWlink against Microsoft LINK).

ROOT    ?= $(abspath ..)
LX      := $(ROOT)/linux
JWASM   ?= $(LX)/bin/jwasm
JWLINK  ?= $(LX)/bin/jwlink
PYTHON  ?= python3
# LANG is the locale of the shell, the product language is MAXLANG
MAXLANG ?= US
OUT     := $(ROOT)/build/$(PROJ)
# a variant build (make PROJ=386MAX-cpd ...) keeps its programs in $(OUT);
# PROJ=DIR/NAME (a second program of DIR) installs into build/bin
BINDIR  := $(if $(filter $(notdir $(CURDIR)),$(firstword $(subst /, ,$(PROJ)))),$(ROOT)/build/bin,$(OUT)/bin)
MASMREF := $(ROOT)/build/masm/$(PROJ)

SRCDIR  := $(notdir $(CURDIR))
CASEMAP ?= mu
JWCASE  := $(if $(filter ml,$(CASEMAP)),-Cp,$(if $(filter mx,$(CASEMAP)),-Cx,-Cu))
AFLAGS  := -Zm $(JWCASE) -c -q -W1 -DLANG_$(MAXLANG) $(foreach d,$(DEFS),"-D$(d)") -I$(OUT) $(addprefix -I,$(ASMINC))
# ML 6: /Cu /Sp63 /W1 (-Zm6: ML 6.0 operand sizes, see linux/jwasm)
AFLAGS6 := -Zm6 $(JWCASE) -c -q -W1 -DLANG_$(MAXLANG) $(foreach d,$(DEFS),"-D$(d)") -I$(OUT) $(addprefix -I,$(ASMINC))

ALLOBJS := $(sort $(foreach p,$(PROGS) $(LIBS),$($(p)_OBJS)))
GENFILES := $(foreach g,$(GENERATED),$(OUT)/$(firstword $(subst =, ,$(g))))
GENFILES += $(addprefix $(OUT)/,$(EMPTYINC))

# everything an object can depend on: the include files of all include dirs
INCDEPS := $(wildcard $(addsuffix /*.INC,$(ASMINC) .) $(addsuffix /*.inc,$(ASMINC) .))

comma := ,
empty :=
space := $(empty) $(empty)

ORIGDIRS ?= RET COMN
origfile = $(or $($(1)_PREBUILT),$(firstword $(foreach d,$(ORIGDIRS),$(shell ls $(d)/* 2>/dev/null | grep -i "^$(d)/$(1)$$"))))
srcof = $(if $(filter /%,$($(1)_SRC)),$($(1)_SRC),$(firstword $(wildcard $(foreach x,$(or $($(1)_SRC),$(basename $(1)).ASM $(basename $(1)).C $(basename $(1)).c),$(addsuffix /$(x),$(SRCDIRS))))))
isc = $(filter %.C %.c,$(call srcof,$(1)))
defsof = $(if $(filter %.OPT,$(1)),-DOPTIM)

.PHONY: all clean check masmref cmp cmplink origlink
.SUFFIXES:
.DELETE_ON_ERROR:

all: $(addprefix $(BINDIR)/,$(PROGS)) $(addprefix $(OUT)/,$(LIBS))

$(OUT) $(BINDIR) $(MASMREF):
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
$(OUT)/$(1): $(call srcof,$(1)) $(INCDEPS) $(GENFILES) $(JWASM) | $(OUT)
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
	-DLANG_$(MAXLANG) $(foreach d,$(CDEFS),"-D$(d)") $(if $(CDEBUGINC),-i=$(CDEBUGINC)) -i=$(CINCDIR) -i=$(OUT)/pro $(addprefix -i=,$(ASMINC)) -i=$(WATCOM)/h
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
$(OUT)/$(1): $(call srcof,$(1)) $(INCDEPS) $(wildcard $(addsuffix /*.H,$(ASMINC))) $(CINCDIR)/.done $(LX)/mk/owcompat.h $(PROFILES)
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

# link; Microsoft LINK's segment order comes from its map in RET/
# $(call LINKCMD,program,directory of the objects)
LINKCMD = cd $(2) && $(JWLINK) format $(or $($(1)_FORMAT),dos $(if $(or $(filter %.COM,$(1)),$($(1)_COM)),com)) name $(1)$(if $($(1)_BIN),.EXE) \
	    option quiet option map=$(1).MAP $(if $($(1)_FORMAT),,option stack=0) option nofarcalls $($(1)_LINKOPTS) \
	    $(if $($(1)_MAP),@$(OUT)/$(1).ORD) file $(subst $(space),$(comma),$(strip $($(1)_OBJS))) > $(1).log \
	    || { cat $(1).log; exit 1; } \
	    $(if $($(1)_BIN),&& $(PYTHON) $(LX)/tools/exe2bin.py $(1).EXE $(1))

# programs with C modules: JWlink (handles the AT segments and groups of
# the assembler modules like Microsoft LINK) with the OpenWatcom run time
CLINKCMD = cd $(2) && $(JWLINK) format dos name $(1) option quiet option map=$(1).MAP option nofarcalls option redefsok option packcode=65530 \
	    libpath $(WATCOM)/lib286/dos libpath $(WATCOM)/lib286 libpath $(OUT)/msclib \
	    $(if $($(1)_STACK),option stack=$($(1)_STACK)) \
	    $(if $($(1)_MAP),@$(OUT)/$(1).ORD) $($(1)_LINKOPTS) \
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

# compare with the binaries of the original build (they were built from the
# sources before the GPL release changed some texts, so small differences
# in message strings are expected)
check: all
	@for pr in $(foreach p,$(PROGS),$(p):$($(p)_ORIG)); do p=$${pr%%:*}; ref=$${pr#*:}; \
	    [ -n "$$ref" ] || ref=$$(ls RET/* 2>/dev/null | grep -i "/$$p$$" | head -1); \
	    if [ -z "$$ref" ]; then echo "$$p: no original in RET/"; continue; fi; \
	    case $$p in \
	    *.COM|$(foreach p,$(PROGS),$(if $($(p)_BIN),$(p)|))__) if cmp -s $$ref $(OUT)/$$p; then echo "$$p: identical to $$ref"; \
	           else echo "$$p: $$(cmp -l $$ref $(OUT)/$$p 2>/dev/null | wc -l) bytes differ from $$ref (size $$(stat -c %s $$ref) / $$(stat -c %s $(OUT)/$$p))"; fi ;; \
	    *.VXD) echo "$$p vs $$ref:"; $(PYTHON) $(LX)/tools/lecmp.py $$ref $(OUT)/$$p | sed 's/^/    /' ;; \
	    *) echo "$$p vs $$ref:"; $(PYTHON) $(LX)/tools/mzcmp.py $$ref $(OUT)/$$p | sed 's/^/    /' ;; \
	    esac; \
	done

# Masm 5.10 reference objects of the current sources (Masm is not part of
# this tree; only used to verify the JWasm build)
ifneq ($(NOMASM),)
masmref: | $(MASMREF)
	$(foreach o,$(ALLOBJS),cp $(call origfile,$(o)) $(MASMREF)/$(o);)
else
masmref: $(GENFILES) | $(MASMREF)
	MASMCASE=/$(subst mx,Mx,$(CASEMAP)) $(LX)/scripts/masmref.sh $(SRCDIR) $(PROJ) "$(ASMINC)" "$(addprefix /D,$(DEFS))" \
	    $(foreach o,$(filter-out $(ML6OBJS),$(ASMOBJS)),$(call srcof,$(o))=$(o)=$(if $(call defsof,$(o)),/DOPTIM)$(addprefix /D,$($(o)_DEFS)))
	$(foreach o,$(ALLOBJS),$(if $(or $($(o)_REF),$(filter $(o),$(ML6OBJS)),$($(o)_PREBUILT)),cp $(or $($(o)_REF),$($(o)_PREBUILT),$(call origfile,$(o))) $(MASMREF)/$(o);))
endif

cmp: $(addprefix $(OUT)/,$(ASMOBJS))
	@ok=0; bad=0; for o in $(ASMOBJS); do \
	    ref=$(MASMREF)/$$o; \
	    if [ ! -f $$ref ]; then echo "$$o: no reference (make masmref)"; bad=$$((bad+1)); continue; fi; \
	    if $(PYTHON) $(LX)/tools/omf.py cmp $$ref $(OUT)/$$o > $(OUT)/$$o.cmp 2>&1; then ok=$$((ok+1)); \
	    else echo "$$o: $$(grep -v '^identical' $(OUT)/$$o.cmp | head -3 | tr '\n' ' ')"; bad=$$((bad+1)); fi; \
	done; echo "$(PROJ): identical $$ok, different $$bad"

# link the Masm reference objects (LIDATA expanded for JWlink) and compare
# the programs with the JWasm build
cmplink: all
	@missing=$$(for o in $(ALLOBJS); do [ -f $(MASMREF)/$$o ] || echo $$o; done); \
	if [ -n "$$missing" ]; then echo "$(PROJ): no reference for" $$missing "- links not compared"; exit 0; fi; \
	rm -rf $(MASMREF)/link; mkdir -p $(MASMREF)/link; \
	for o in $(ALLOBJS); do $(PYTHON) $(LX)/tools/omf.py expand $(MASMREF)/$$o $(MASMREF)/link/$$o > /dev/null \
	    || cp $(MASMREF)/$$o $(MASMREF)/link/; done; \
	$(foreach p,$(PROGS),( $(call LINKCMD,$(p),$(MASMREF)/link) ) || exit 1;) \
	for p in $(PROGS); do \
	    case $$p in \
	    *.COM|$(foreach p,$(PROGS),$(if $($(p)_BIN),$(p)|))__) cmp -s $(MASMREF)/link/$$p $(OUT)/$$p && echo "$$p: identical" || echo "$$p: DIFFERENT" ;; \
	    *.VXD) $(PYTHON) $(LX)/tools/lecmp.py $(MASMREF)/link/$$p $(OUT)/$$p | tail -1 | sed "s|^|$$p: |" ;; \
	    *) $(PYTHON) $(LX)/tools/mzcmp.py $(MASMREF)/link/$$p $(OUT)/$$p | grep -q 'image bytes differing: 0' \
	       && echo "$$p: image identical" || echo "$$p: DIFFERENT" ;; \
	    esac; done

# link the original 1998 objects (RET/, COMN/) like the programs and compare
# with the original binaries: checks JWlink against Microsoft LINK
ORIGLINK := $(ROOT)/build/origlink/$(PROJ)
ifneq ($(NOORIGOBJ),)
origlink:
	@echo "$(PROJ): no original objects in RET/ for this build"
else
origlink: | $(OUT)
	@rm -rf $(ORIGLINK); mkdir -p $(ORIGLINK)
	@$(foreach p,$(PROGS),$(if $($(p)_MAP),$(PYTHON) $(LX)/tools/map2lnk.py $($(p)_MAP) > $(OUT)/$(p).ORD;))
	@$(foreach o,$(ALLOBJS),$(if $(call origfile,$(o)),$(PYTHON) $(LX)/tools/omf.py expand $(call origfile,$(o)) $(ORIGLINK)/$(o) > /dev/null || cp $(call origfile,$(o)) $(ORIGLINK)/$(o);,echo "$(PROJ): no original object $(o)";))
	@$(foreach p,$(PROGS),( $(call LINKCMD,$(p),$(ORIGLINK)) ) || exit 1;) \
	for pr in $(foreach p,$(PROGS),$(p):$($(p)_ORIG)); do p=$${pr%%:*}; ref=$${pr#*:}; \
	    [ -n "$$ref" ] || ref=$$(ls RET/* 2>/dev/null | grep -i "/$$p$$" | head -1); \
	    [ -n "$$ref" ] || { echo "$$p: no original program"; continue; }; \
	    case $$p in \
	    *.COM|$(foreach p,$(PROGS),$(if $($(p)_BIN),$(p)|))__) cmp -s $$ref $(ORIGLINK)/$$p && echo "$$p: identical to $$ref" \
	       || echo "$$p: $$(cmp -l $$ref $(ORIGLINK)/$$p | wc -l) bytes differ from $$ref" ;; \
	    *.VXD) $(PYTHON) $(LX)/tools/lecmp.py $$ref $(ORIGLINK)/$$p | tail -1 | sed "s|^|$$p vs $$ref: |" ;; \
	    *) $(PYTHON) $(LX)/tools/mzcmp.py $$ref $(ORIGLINK)/$$p | grep -E 'differing|relocs' | tr '\n' ' ' | sed "s|^|$$p vs $$ref: |"; echo ;; \
	    esac; done
endif
