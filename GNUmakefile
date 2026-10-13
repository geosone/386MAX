# Build 386MAX with GNU make and open-source tools only:
#   linux/jwasm   JWasm with Masm 5.1 compatibility patches  -> linux/bin/jwasm
#   linux/jwlink  jwlink with MS LINK compatibility patches   -> linux/bin/jwlink
#   (git submodules: branch 386max of github.com/geosone/JWasm and
#   github.com/geosone/jwlink; git clone --recursive or
#   git submodule update --init)
#   OpenWatcom (WATCOM=/opt/watcom) for the C and Windows programs
# Programs go to build/bin, objects to build/<project>.
#
#   make            tools and all projects
#   make 386MAX     one project
#   make MFC_ARCHIVE=.../MSVC152C.iso   also the MFC programs (linux/mfc)
#   make MAXLANG=GR the German version (linux/scripts/buildlang.sh builds
#                   each language in its own tree, mkmedia.sh the media)
#   make clean      remove build/ (except the WfW test image and MFC);
#                   make distclean removes everything and the tools too

PROJECTS := 386MAX 386LOAD 386DISK MEMLIMIT ROMSRCH XLAT RAMBASIC QMT EXTRADOS MAXVRAM VXD QUILIB ASQENG ASQ MAXIMIZE INSTALL SNAPSHOT BATPROC STRIPMGR
# new open source parts instead of binaries of the original (help engine,
# version library, DOS reader for Windows help files, the MAX shell
# reconstructed from the binary)
NEWPROJECTS := HELPENG VERLIB HHELP QSHELL
# Windows programs (OpenWatcom, linux/mk/win.mk) and help files
WINPROJECTS := CTL3D SFTTABS MAXMETER MAXEDIT QPOPUP QPIFEDIT DOSMAX16 DOSMAX32 RDOSMAX MAXCTRL GOAHEAD MAXSETUP DOSHELP MAXHELP
# MFC programs: need the MFC 2.5 sources of Visual C++ 1.5x (not part of
# this tree), see linux/mfc: make MFC_ARCHIVE=/path/to/MSVC152C.iso (or a
# .7z holding it) or MFCDIR=/path/to/MSVC15/MFC; built once, later runs
# find build/mfc (the library or the unpacked MFC tree)
MFCPROJECTS := STATUTIL WINMXMZ
ifneq ($(MFC_ARCHIVE)$(MFCDIR)$(wildcard build/mfc/LAFXCW.LIB build/mfc/MSVC15/MFC/.done),)
WINPROJECTS += $(MFCPROJECTS)
export MFC_ARCHIVE MFCDIR
endif

JWASM_SRC  := $(wildcard linux/jwasm/src/*.c linux/jwasm/src/H/*.h)
JWLINK_SRC := $(shell find linux/jwlink -name '*.[ch]' -not -path '*/build/*')

.PHONY: all tools $(PROJECTS) $(NEWPROJECTS) $(WINPROJECTS) clean distclean

all: $(PROJECTS) $(NEWPROJECTS) $(WINPROJECTS)

tools: linux/bin/jwasm linux/bin/jwlink

# JWasm's makefile has no header dependencies: rebuild from scratch
linux/bin/jwasm: $(JWASM_SRC) linux/jwasm/GccUnix.mak
	rm -rf linux/jwasm/build/GccUnixR
	$(MAKE) -C linux/jwasm -f GccUnix.mak
	mkdir -p linux/bin
	cp linux/jwasm/build/GccUnixR/jwasm $@

linux/bin/jwlink: $(JWLINK_SRC) linux/jwlink/GccUnix.mak
	$(MAKE) -C linux/jwlink -f GccUnix.mak
	mkdir -p linux/bin
	cp linux/jwlink/build/jwlinkLR/jwlink $@

$(PROJECTS) $(NEWPROJECTS) $(WINPROJECTS): tools
	$(MAKE) -C $@

# libraries used by other projects
ASQ: QUILIB ASQENG HELPENG VERLIB
QSHELL: QUILIB HELPENG
MAXIMIZE: QUILIB HELPENG
INSTALL: QUILIB HELPENG VERLIB
MAXSETUP: QUILIB CTL3D
WINMXMZ: QUILIB STATUTIL
MAXCTRL: SFTTABS

# the Windows 3.11 test image in build/win311 and the MFC sources in
# build/mfc survive (a long unattended install, the Visual C++ CD)
clean:
	find build -mindepth 1 -maxdepth 1 ! -name win311 ! -name dosdisk ! -name win98 ! -name mfc -exec rm -rf {} + 2>/dev/null || true
	$(MAKE) -C linux/mfc clean

distclean:
	rm -rf build linux/bin linux/jwasm/build linux/jwlink/build
