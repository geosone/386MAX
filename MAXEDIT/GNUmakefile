# MAXEDIT.EXE, the Windows editor for the 386MAX profile and CONFIG.SYS
# (GNU make, see linux/mk/win.mk), on wxWindows 1.68E (WX.DLL)
PROJ     := MAXEDIT
ROOT     := $(abspath ..)
WX       := 1
PROGS    := MAXEDIT.EXE

MAXEDIT.EXE_OBJS := MAXEDIT.OBJ MEUTIL.OBJ
MAXEDIT.EXE_RC   := MAXEDIT.RC
MAXEDIT.EXE_DEF  := MAXEDIT.DEF

include $(ROOT)/linux/mk/win.mk

# toolbar bitmaps (16 x 15 of the T*.ICO) next to the resource scripts
TBICONS := NEW:TNEW OPEN:TOPEN SAVE:TSAVE PRINT:TPRINT UNDO:TUNDO CUT:TCUT \
           COPY:TCOPY PASTE:TPASTE CASC:TCASCADE TILE:TTILE INI:TINI \
           EXIT:TEXIT HELP:THELP
TBBMPS  := $(foreach t,$(TBICONS),$(CINCDIR)/tb$(shell echo $(word 1,$(subst :, ,$(t))) | tr A-Z a-z).bmp)
$(OUT)/MAXEDIT.EXE.res: $(TBBMPS)
define TBRULE
$(CINCDIR)/tb$(shell echo $(word 1,$(subst :, ,$(1))) | tr A-Z a-z).bmp: $(word 2,$(subst :, ,$(1))).ICO $(ROOT)/linux/tools/ico2bmp.py $(CINCDIR)/.done
	$(PYTHON) $(ROOT)/linux/tools/ico2bmp.py $$< $$@
endef
$(foreach t,$(TBICONS),$(eval $(call TBRULE,$(t))))
