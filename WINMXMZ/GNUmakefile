# WINMAXIM.EXE, Windows start of MAXIMIZE (GNU make, see linux/mk/win.mk),
# on wxWindows 1.68E (submodule wxWindows).  Needs QUILIB and STATUTIL.  The
# DOS stub WINLNCH.EXE is built by winlnch.mk.
PROJ     := WINMXMZ
ROOT     := $(abspath ..)
CMODEL   := l
WX       := 1
MSCOMPAT := 1
INCDIRS  := . ../INCLUDE ../INC
CDEFS    := NDEBUG
PROGS    := WINMAXIM.EXE

WINLNCH  := $(ROOT)/build/WINMXMZ/WINLNCH/WINLNCH.EXE

WINMAXIM.EXE_OBJS := WINMXMZ.OBJ MXDLGS.OBJ SUMMARY.OBJ
WINMAXIM.EXE_RC   := WINMXMZ.RC
WINMAXIM.EXE_DEF  := WINMXMZ.DEF
WINMAXIM.EXE_STUB := $(WINLNCH)
WINMAXIM.EXE_LIBS := $(ROOT)/build/QUILIB-W/LQUILIBW.LIB $(ROOT)/build/STATUTIL/LSTUTIL.LIB
WINMAXIM.EXE_LINKOPTS := option stack=16384

WINMAXIM.EXE_LINKOPTS += option protmode   # rc -t of the original
include $(ROOT)/linux/mk/win.mk

$(WINLNCH): FORCE
	$(MAKE) -f winlnch.mk
clean: winlnch-clean
winlnch-clean:
	$(MAKE) -f winlnch.mk clean
.PHONY: FORCE winlnch-clean

# splash bitmap with the version (linux/tools/splashgen.py)
$(OUT)/WINMAXIM.EXE.res: $(CINCDIR)/qmax.bmp
$(CINCDIR)/qmax.bmp: $(ROOT)/INCLUDE/SPLASH.PNG $(VERSION_FILE) $(ROOT)/linux/tools/splashgen.py $(CINCDIR)/.done
	rm -f $@ $(CINCDIR)/QMAX.BMP
	$(PYTHON) $(ROOT)/linux/tools/splashgen.py bmp $< $(VERSION_FILE) $@
	ln -sf qmax.bmp $(CINCDIR)/QMAX.BMP
