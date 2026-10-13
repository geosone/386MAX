# Windows help files MAXHELP.HLP and SETUP.HLP (GNU make).
# linux/tools/whc.py compiles the help projects; the steps of the original
# build (Microsoft Help Compiler) are done the same way in
# build/MAXHELP/<lang>: the [WINDOWS], [CONFIG] and [MAP] sections of
# MAXHELP.H?? / SETUP.H?? (GETSECT), the help map of WINMXMZ's resource
# identifiers (MAKEHM), the project files
# _MAXHELP.SRC / _SETUP.SRC; sources *.RUS (German *.RGR), bitmaps in
# BITMAPS.
#   make [MAXLANG=US|GR] (like the other projects)
ROOT    := $(abspath ..)
BINDIR  := $(ROOT)/build/bin
MAXLANG ?= US
L       := $(if $(filter GR gr Gr,$(MAXLANG)),GR,US)
OUT     := $(ROOT)/build/MAXHELP/$(L)
WHC     := python3 $(ROOT)/linux/tools/whc.py
DEFS    := -DLANG_$(L)
# WINMX_HLP_PRE of INCLUDE/MXHELPID.H
HLP_PRE := 0x010

HELPS   := MAXHELP.HLP SETUP.HLP

all: $(addprefix $(BINDIR)/,$(HELPS))

$(BINDIR) $(OUT)/hlp:
	mkdir -p $@

$(OUT)/MAXHELP.RTF: MAXHELP.R$(L) | $(OUT)/hlp
	cp $< $@
$(OUT)/SETUP.RTF: SETUP.R$(L) | $(OUT)/hlp
	cp $< $@
$(OUT)/BITMAPS: | $(OUT)/hlp
	ln -sfn $(CURDIR)/BITMAPS $@

# sections of the language's project (GETSECT)
sect = $(if $(filter win,$(1)),windows,$(if $(filter cfg,$(1)),config,map))
$(OUT)/hlp/maxhelp.%: MAXHELP.H$(L) | $(OUT)/hlp
	$(WHC) getsect $< $(call sect,$*) > $@
$(OUT)/hlp/setup.%: SETUP.H$(L) | $(OUT)/hlp
	$(WHC) getsect $< $(call sect,$*) > $@
# help map of the resource identifiers of WINMAXIM (MAKEHLP2.BAT)
$(OUT)/hlp/max.hm: $(ROOT)/WINMXMZ/RESOURCE.H HELPAFX.H | $(OUT)/hlp
	{ $(WHC) makehm $(ROOT)/WINMXMZ/RESOURCE.H WMX $(HLP_PRE) && \
	  $(WHC) makehm HELPAFX.H WMX $(HLP_PRE); } > $@
$(OUT)/winmaxim.ali: WINMAXIM.A$(L) | $(OUT)/hlp
	cp $< $@
$(OUT)/_maxhelp.hpj: _MAXHELP.SRC | $(OUT)/hlp
	sed 's/winmaxim\.LANGALI/winmaxim.ali/' $< > $@
$(OUT)/_setup.hpj: _SETUP.SRC | $(OUT)/hlp
	cp $< $@

MAXHELP_DEPS := $(OUT)/_maxhelp.hpj $(OUT)/MAXHELP.RTF $(OUT)/BITMAPS $(OUT)/winmaxim.ali \
	$(addprefix $(OUT)/hlp/,maxhelp.win maxhelp.cfg maxhelp.hm max.hm)
SETUP_DEPS   := $(OUT)/_setup.hpj $(OUT)/SETUP.RTF \
	$(addprefix $(OUT)/hlp/,setup.win setup.cfg setup.hm)

# (warnings in maxhelp.err / setup.err, like HC's ERRORLOG)
$(OUT)/MAXHELP.HLP: $(MAXHELP_DEPS) $(ROOT)/linux/tools/whc.py
	$(WHC) build $< -o $@ $(DEFS) 2> $(OUT)/maxhelp.err || { cat $(OUT)/maxhelp.err; exit 1; }
$(OUT)/SETUP.HLP: $(SETUP_DEPS) $(ROOT)/linux/tools/whc.py
	$(WHC) build $< -o $@ $(DEFS) 2> $(OUT)/setup.err || { cat $(OUT)/setup.err; exit 1; }

$(BINDIR)/%.HLP: $(OUT)/%.HLP | $(BINDIR)
	cp $< $@

clean:
	rm -rf $(ROOT)/build/MAXHELP $(addprefix $(BINDIR)/,$(HELPS))

.PHONY: all clean
