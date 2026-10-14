# MAXCFG.EXE: edits SETUP.INF, the answers of an unattended installation
# (GNU make, see linux/mk/win.mk).  One program for DOS and Windows: the
# Windows part (MAXWINCF.C) with the DOS part (MAXDOSCF.C, maxdoscf.mk) as
# its stub; both use the option table OPTTAB.C.
PROJ     := MAXCFG
ROOT     := $(abspath ..)
PROGS    := MAXCFG.EXE

DOSPART  := $(ROOT)/build/MAXCFG/DOS/MAXDOSCF.EXE

MAXCFG.EXE_OBJS := MAXWINCF.OBJ OPTTAB.OBJ
MAXCFG.EXE_RC   := MAXCFG.RC
MAXCFG.EXE_DEF  := MAXCFG.DEF
MAXCFG.EXE_STUB := $(DOSPART)

include $(ROOT)/linux/mk/win.mk

$(DOSPART): FORCE
	$(MAKE) -f maxdoscf.mk
clean: maxdoscf-clean
maxdoscf-clean:
	$(MAKE) -f maxdoscf.mk clean
.PHONY: FORCE maxdoscf-clean
