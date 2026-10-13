# HHELP.EXE, reader for Windows help files in DOS (replaces the third-party
# HHELP.EXE of the original package; MAXHELP.BAT runs it with MAXHELP.HLP).
# OpenWatcom, large model.
ROOT    := $(abspath ..)
BINDIR  := $(ROOT)/build/bin
OUT     := $(ROOT)/build/HHELP
WATCOM  ?= /opt/watcom
export WATCOM
WCC     := $(WATCOM)/binl64/wcc
WLINK   := $(WATCOM)/binl64/wlink
CFLAGS  := -bt=dos -ml -zq -ox -s -w4 -i=$(WATCOM)/h
OBJS    := $(OUT)/HHELP.OBJ $(OUT)/HLPFILE.OBJ

all: $(BINDIR)/HHELP.EXE

$(OUT) $(BINDIR):
	mkdir -p $@

$(OUT)/%.OBJ: %.C HLPFILE.H | $(OUT)
	$(WCC) $(CFLAGS) -fo=$@ $<

$(OUT)/HHELP.EXE: $(OBJS)
	$(WLINK) @$(WATCOM)/binl64/wlink.lnk option quiet system dos name $@ option stack=8192 \
	    option map=$(OUT)/HHELP.MAP file { $(OBJS) }

$(BINDIR)/HHELP.EXE: $(OUT)/HHELP.EXE | $(BINDIR)
	cp $< $@

clean:
	rm -rf $(OUT) $(BINDIR)/HHELP.EXE

.PHONY: all clean
