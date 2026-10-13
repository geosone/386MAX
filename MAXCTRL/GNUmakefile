# TOOLBOX.EXE, the Open 386MAX Toolbox (GNU make, see linux/mk/win.mk) and
# EVAP.EXE (DOS, see evap.mk).  SFTTABS (tab control): ../SFTTABS.
PROJ     := MAXCTRL
ROOT     := $(abspath ..)
CMODEL   := l
CPACK    := 1
INCDIRS  := . ../INCLUDE ../INC
PROGS    := TOOLBOX.EXE

TOOLBOX.EXE_OBJS := TOOLBOX.OBJ SETUPDDE.OBJ FILECOPY.OBJ MISC.OBJ
TOOLBOX.EXE_RC   := TOOLBOX.RC
TOOLBOX.EXE_DEF  := MAXCTRL.DEF
TOOLBOX.EXE_LIBS := ddeml toolhelp shell $(ROOT)/build/SFTTABS/SFTTABS.LIB ctl3dv2

include $(ROOT)/linux/mk/win.mk

all: evap
evap:
	$(MAKE) -f evap.mk
clean: evap-clean
evap-clean:
	$(MAKE) -f evap.mk clean
.PHONY: evap evap-clean
