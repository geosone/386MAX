# Build 386MAX with GNU make and open-source tools only:
#   linux/jwasm   JWasm with Masm 5.1 compatibility patches  -> linux/bin/jwasm
#   linux/jwlink  JWlink with MS LINK compatibility patches   -> linux/bin/jwlink
#   OpenWatcom (WATCOM=/opt/watcom) for the C and Windows programs
# Programs go to build/bin, objects to build/<project>.
# (MAX.MAK is the original top-level NMAKE file.)
#
#   make            tools and all projects
#   make 386MAX     one project
#   make MFC_ARCHIVE=.../MSVC152C.iso   also the MFC programs (linux/mfc)
#   make check      compare with the original binaries in */RET
#   make cmp        compare all objects with Masm 5.10 references
#                   (made by "make masmref MASM_EXE=..." with DOSBox)
#   make cmplink    link those references too and compare the programs
#   make origlink   link the original objects of */RET with JWlink and
#                   compare with the original programs
#   make clean      remove build/ except the Masm references (build/masm);
#                   make distclean removes them and the tools too

PROJECTS := 386MAX 386LOAD 386DISK MEMLIMIT ROMSRCH XLAT RAMBASIC QMT EXTRADOS MAXVRAM VXD QUILIB ASQENG ASQ MAXIMIZE INSTALL SNAPSHOT BATPROC STRIPMGR
# new open source parts instead of binaries of the original (help engine,
# version library, DOS reader for Windows help files, the MAX shell
# reconstructed from the binary): not part of check/cmp
NEWPROJECTS := HELPENG VERLIB HHELP QSHELL
# Windows programs (OpenWatcom, linux/mk/win.mk) and help files: not part
# of check/cmp (no Masm/Microsoft C references)
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
JWLINK_SRC := $(shell find linux/jwlink -name '*.[ch]' -not -path '*/GccUnixR/*')
JWLINK_CC  := gcc -m32 -std=gnu99 -w -fpermissive

.PHONY: all tools $(PROJECTS) $(NEWPROJECTS) $(WINPROJECTS) check cmp cmplink origlink masmref clean distclean

all: $(PROJECTS) $(NEWPROJECTS) $(WINPROJECTS)

tools: linux/bin/jwasm linux/bin/jwlink

# JWasm's makefile has no header dependencies: rebuild from scratch
linux/bin/jwasm: $(JWASM_SRC) linux/jwasm/GccUnix.mak
	rm -rf linux/jwasm/build/GccUnixR
	$(MAKE) -C linux/jwasm -f GccUnix.mak
	mkdir -p linux/bin
	cp linux/jwasm/build/GccUnixR/jwasm $@

# JWlink works only as a 32-bit program
linux/bin/jwlink: $(JWLINK_SRC)
	for d in dwarf/dw orl sdk/rc/wres .; do \
	    $(MAKE) -C linux/jwlink/$$d -f GccUnix.mak CC="$(JWLINK_CC)" || exit 1; done
	mkdir -p linux/bin
	cp linux/jwlink/GccUnixR/jwlink $@

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

check cmp cmplink origlink masmref: tools
	@for p in $(PROJECTS); do $(MAKE) -s -C $$p $@ || exit 1; done

# the Masm references in build/masm, the Windows 3.11 test image in
# build/win311 and the MFC sources in build/mfc survive (DOSBox + Masm, a
# long unattended install, the Visual C++ CD)
clean:
	find build -mindepth 1 -maxdepth 1 ! -name masm ! -name win311 ! -name mfc -exec rm -rf {} + 2>/dev/null || true
	$(MAKE) -C linux/mfc clean

distclean:
	rm -rf build linux/bin linux/jwasm/build
	for d in dwarf/dw orl sdk/rc/wres .; do rm -rf linux/jwlink/$$d/GccUnixR; done
