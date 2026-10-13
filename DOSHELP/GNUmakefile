# DOS help files (GNU make; MAKEFILE/MAXHELP.MAK is the original NMAKE
# build with Microsoft HELPMAKE).  linux/tools/qhelp.py builds the QuickHelp
# databases from the Word RTF sources (*.RUS, German *.RGR; the \'xx table
# of HMAKEL.C) and the QuickHelp markup sources (*.AUS/*.AGR), with the
# widths of MAXHELP.MAK, and concatenates them like the original build.
#   make [MAXLANG=US|GR] (like the other projects)
ROOT    := $(abspath ..)
BINDIR  := $(ROOT)/build/bin
OUT     := $(ROOT)/build/DOSHELP
QHELP   := python3 $(ROOT)/linux/tools/qhelp.py
MAXLANG ?= US
L       := $(if $(filter GR gr Gr,$(MAXLANG)),GR,US)
R       := R$(L)
A       := A$(L)
MSIZE   := $(if $(filter GR,$(L)),56,52)
MSIZ2   := $(if $(filter GR,$(L)),68,69)

# installed name : databases (source:width), as MAXHELP.MAK
ASQ_SRC      := AS_H_HLP.$(R):$(MSIZ2) AS_T_HLP.$(R):$(MSIZ2) AS_G_HLP.$(R):$(MSIZ2) \
                AS_L_HLP.$(R):$(MSIZ2) AS_Q_HLP.$(R):19
INSTALL_SRC  := IN_H_HLP.$(R):$(MSIZ2) IN_S_HLP.$(R):33 IN_M_HLP.$(R):$(MSIZE) \
                IN_L_HLP.$(R):$(MSIZ2) IN_Q_HLP.$(R):19
MAXIMIZE_SRC := MX_H_HLP.$(R):$(MSIZ2) MX_S_HLP.$(R):33 MX_M_HLP.$(R):$(MSIZE) \
                MX_L_HLP.$(R):$(MSIZ2) MX_Q_HLP.$(R):19 MX_D_HLP.$(A):76
QSHELL_SRC   := QS_H_HLP.$(R):$(MSIZ2) QS_O_HLP.$(R):53 QS_Q_HLP.$(R):19

HELPS := asq.hlp setupdos.hlp maximize.hlp max.hlp update.hlp

all: $(addprefix $(BINDIR)/,$(HELPS))

$(BINDIR) $(OUT):
	mkdir -p $@

srcs = $(foreach s,$(1),$(firstword $(subst :, ,$(s))))
$(OUT)/ASQ.HLP: $(call srcs,$(ASQ_SRC)) HMAKEL.C | $(OUT)
	$(QHELP) build $@ HMAKEL.C $(ASQ_SRC)
$(OUT)/INSTALL.HLP: $(call srcs,$(INSTALL_SRC)) HMAKEL.C | $(OUT)
	$(QHELP) build $@ HMAKEL.C $(INSTALL_SRC)
$(OUT)/MAXIMIZE.HLP: $(call srcs,$(MAXIMIZE_SRC)) HMAKEL.C | $(OUT)
	$(QHELP) build $@ HMAKEL.C $(MAXIMIZE_SRC)
$(OUT)/QSHELL.HLP: $(call srcs,$(QSHELL_SRC)) HMAKEL.C | $(OUT)
	$(QHELP) build $@ HMAKEL.C $(QSHELL_SRC)

# MAXHELP.MAK: asq <- ASQ, setupdos/update <- INSTALL, max <- QSHELL
$(BINDIR)/asq.hlp: $(OUT)/ASQ.HLP | $(BINDIR)
	cp $< $@
$(BINDIR)/setupdos.hlp $(BINDIR)/update.hlp: $(OUT)/INSTALL.HLP | $(BINDIR)
	cp $< $@
$(BINDIR)/maximize.hlp: $(OUT)/MAXIMIZE.HLP | $(BINDIR)
	cp $< $@
$(BINDIR)/max.hlp: $(OUT)/QSHELL.HLP | $(BINDIR)
	cp $< $@

clean:
	rm -rf $(OUT) $(addprefix $(BINDIR)/,$(HELPS))

.PHONY: all clean
