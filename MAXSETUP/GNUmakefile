# SETUP.EXE, the Windows setup of Qualitas MAX (GNU make, see
# linux/mk/win.mk).  Its DOS stub (SETUPDOS.EXE) and CLEAN.EXE (an RCDATA
# resource, made with linux/tools/bin2rc.py instead of BIN2RC.EXE) are
# built by setupdos.mk and clean.mk.  PKWARE's IMPLODE.LIB is replaced by
# INSTALL/EXPLODE.C.
PROJ     := MAXSETUP
ROOT     := $(abspath ..)
CMODEL   := l
MSCOMPAT := 1
SRCDIRS  := . ../INSTALL
INCDIRS  := . ../INCLUDE ../INC
PROGS    := SETUP.EXE

STUBDIR  := $(ROOT)/build/MAXSETUP-SETUPDOS
CLEANDIR := $(ROOT)/build/MAXSETUP-CLEAN

# (SERIALNO.OBJ of the original: no serial numbers in Open 386MAX)
SETUP.EXE_OBJS := SETUP.OBJ EXTRACT.OBJ SETUPDDE.OBJ SETUPDIF.OBJ \
	EXTFILE.OBJ MULTI.OBJ FILECOPY.OBJ MISC.OBJ EXPLODE.OBJ
SETUP.EXE_RC   := SETUP.RC
SETUP.EXE_DEF  := SETUP.DEF
SETUP.EXE_LIBS := ver ddeml commdlg toolhelp shell $(ROOT)/build/CTL3D/CTL3DS.LIB \
	$(ROOT)/build/QUILIB-W/LQUILIBW.LIB
SETUP.EXE_LINKOPTS := option stub=$(STUBDIR)/SETUPDOS.EXE

include $(ROOT)/linux/mk/win.mk

# DOS parts
$(STUBDIR)/SETUPDOS.EXE:
	$(MAKE) -f setupdos.mk
$(CLEANDIR)/CLEAN.EXE:
	$(MAKE) -f clean.mk
$(OUT)/SETUP.EXE: $(STUBDIR)/SETUPDOS.EXE
# clean.rc (included by SETUP.RC) is made from CLEAN.EXE
$(OUT)/SETUP.EXE.res: $(CINCDIR)/clean.rc
$(CINCDIR)/clean.rc: $(CLEANDIR)/CLEAN.EXE $(CINCDIR)/.done $(ROOT)/linux/tools/bin2rc.py
	rm -f $@
	$(PYTHON) $(ROOT)/linux/tools/bin2rc.py $< $@
clean: dos-clean
dos-clean:
	$(MAKE) -f setupdos.mk clean
	$(MAKE) -f clean.mk clean
.PHONY: dos-clean

# splash bitmap with the version (linux/tools/splashgen.py)
$(OUT)/SETUP.EXE.res: $(CINCDIR)/qmax.bmp
$(CINCDIR)/qmax.bmp: $(ROOT)/INCLUDE/SPLASH.PNG $(VERSION_FILE) $(ROOT)/linux/tools/splashgen.py $(CINCDIR)/.done
	rm -f $@ $(CINCDIR)/QMAX.BMP
	$(PYTHON) $(ROOT)/linux/tools/splashgen.py bmp $< $(VERSION_FILE) $@
	ln -sf qmax.bmp $(CINCDIR)/QMAX.BMP
