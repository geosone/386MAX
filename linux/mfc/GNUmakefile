# Microsoft Foundation Classes 2.5 for the 386MAX Windows programs
# WINMXMZ and STATUTIL, built with OpenWatcom from the MFC sources of
# Microsoft Visual C++ 1.5x (not part of this tree):
#
#   make MFC_ARCHIVE=/path/to/MSVC152C.iso    (or a .7z holding the ISO)
#   make MFCDIR=/path/to/MSVC15/MFC           (an unpacked MFC directory)
#
# Output: build/mfc/LAFXCW.LIB (large model, Windows, release; the original
# makefile's MODEL=L TARGET=W DEBUG=0) and build/mfc/include (MFC headers,
# case-insensitive names) for win.mk (MFC := 1).
# Built: the library modules of the original makefile without the ODBC,
# socket, OLE server/container (OLEDLL), VBX, pen edit and MAPI modules;
# olexcpt.cpp (ours) supplies COleException's run time class instead of
# olemisc.cpp.
# Changes for OpenWatcom are made by linux/mk/owmfc.h (force-included),
# linux/mk/owwin16 (missing Windows SDK headers) and compiler options:
# -zf (for-loop scope of Visual C++ 1.5), "this == NULL" tests rewritten
# (see put below), _PORTABLE for the two modules
# with inline assembler that OpenWatcom's assembler doesn't take, cdecl
# defined empty (OpenWatcom's convention throughout, see owmfc.h), smart
# callbacks (-zWs, Microsoft C /GA: the library is for programs, not DLLs).

ROOT    := $(abspath ../..)
LX      := $(ROOT)/linux
OUT     := $(ROOT)/build/mfc
WATCOM  ?= /opt/watcom
export WATCOM
OWBIN   := $(WATCOM)/binl64
WPP     := $(OWBIN)/wpp
WLIB    := $(OWBIN)/wlib
PYTHON  ?= python3

ifeq ($(MFCDIR),)
MFCDIR  := $(OUT)/MSVC15/MFC
endif

MODS := objcore except afxver validadd dumpcont dumpflt arccore arcobj arcex \
	dumpinit dumpout afxasert afxmem afxabort \
	filecore filetxt filemem filex filest \
	array_b array_d array_p array_o array_s array_u array_w list_o list_p list_s \
	map_pp map_pw map_so map_sp map_ss map_wo map_wp plex \
	strcore1 strcore2 strex timecore \
	wincore winfrm winfrmx winmdi winhand winmain barcore bartool bardlg \
	dcprev dcmeta trckrect fileshrd \
	dlgcore dlgdata dlgfloat winctrl winbtn dlgfile dlgprnt dlgclr dlgfnt dlgfr dlgprop \
	wingdi wingdix winstr winmenu auxdata afxtrace winutil \
	cmdtarg doccore doctempl docsingl docmulti viewcore viewprnt winsplit viewscrl \
	viewform viewedit viewprev \
	appcore appinit appterm appui appui2 appgray appdlg appprnt apphelp apphelpx appdata \
	olelock1 olelock2 oledata olexcpt
PORTABLE := validadd wincore
NOEXPORT := afxver

INC     := $(OUT)/include
SRC     := $(OUT)/src
OBJ     := $(OUT)/obj
CFLAGS  := -bt=windows -zWs -ml -zp1 -zf -j -2 -s -os -zq -fr -ei \
	-D_WINDOWS -DNDEBUG -DOWMFC_LIB -fi=$(LX)/mk/owmfc.h \
	-i=$(SRC) -i=$(INC) -i=$(LX)/mk/owwin16 -i=$(WATCOM)/h -i=$(WATCOM)/h/win

all: $(OUT)/LAFXCW.LIB

# MFC directory from the Visual C++ 1.5x CD image (ISO, or a 7z holding it)
$(OUT)/MSVC15/MFC/.done:
	@test -n "$(MFC_ARCHIVE)" || { echo "set MFC_ARCHIVE (Visual C++ 1.5x CD image) or MFCDIR"; exit 1; }
	rm -rf $(OUT)/MSVC15 $(OUT)/iso
	mkdir -p $(OUT)/iso
	case "$(MFC_ARCHIVE)" in \
	  *.iso|*.ISO) 7z x -y -o$(OUT) "$(MFC_ARCHIVE)" 'MSVC15/MFC/*' >/dev/null ;; \
	  *) 7z x -y -o$(OUT)/iso "$(MFC_ARCHIVE)" '*.iso' '*.ISO' -r >/dev/null && \
	     7z x -y -o$(OUT) "$$(find $(OUT)/iso -iname '*.iso' | head -1)" 'MSVC15/MFC/*' >/dev/null ;; \
	esac
	rm -rf $(OUT)/iso
	touch $@

# put SOURCE DEST: a link, or a copy with "this == NULL" / "this != NULL"
# rewritten (see owmfc.h: OpenWatcom folds these tests)
NULLTHIS := this *([!=])= *NULL
put = if grep -q -E '$(NULLTHIS)' "$(1)"; then sed -E 's/$(NULLTHIS)/owc_ptrval(this) \1= 0/g' "$(1)" > "$(2)"; \
	else ln -sf "$$(realpath "$(1)")" "$(2)"; fi

# lower-case names (the sources include "afxwin.h", "sys\types.h"); our
# stdafx.h instead of the original
$(OUT)/.tree: $(if $(filter $(OUT)/MSVC15/MFC,$(MFCDIR)),$(OUT)/MSVC15/MFC/.done) stdafx.h olexcpt.cpp
	rm -rf $(INC) $(SRC)
	mkdir -p $(INC) $(SRC) $(OBJ)
	for f in $(MFCDIR)/INCLUDE/* $(MFCDIR)/SRC/*.H $(MFCDIR)/SRC/*.h; do [ -f "$$f" ] || continue; \
	  b=$$(basename "$$f"); l=$$(echo "$$b" | tr A-Z a-z); \
	  $(call put,$$f,$(INC)/$$l); [ -e $(INC)/$$b ] || ln -sf $$l $(INC)/$$b; done
	for f in $(MFCDIR)/SRC/*.CPP $(MFCDIR)/SRC/*.cpp; do [ -f "$$f" ] || continue; \
	  $(call put,$$f,$(SRC)/$$(basename "$$f" | tr A-Z a-z)); done
	rm -f $(INC)/stdafx.h $(INC)/STDAFX.H
	cp stdafx.h $(SRC)/stdafx.h
	cp olexcpt.cpp $(SRC)/olexcpt.cpp
	ln -sf $(WATCOM)/h/sys/types.h '$(INC)/sys\types.h'
	ln -sf $(WATCOM)/h/sys/stat.h '$(INC)/sys\stat.h'
	touch $@

$(OBJ)/%.obj: $(OUT)/.tree $(LX)/mk/owmfc.h
	$(WPP) $(CFLAGS) $(if $(filter $*,$(PORTABLE)),-D_PORTABLE) $(if $(filter $*,$(NOEXPORT)),-DOWMFC_NOEXPORT) -fo=$@ $(SRC)/$*.cpp

$(OUT)/LAFXCW.LIB: $(addprefix $(OBJ)/,$(addsuffix .obj,$(MODS)))
	rm -f $@
	$(WLIB) -q -n -b $@ $(addprefix +,$^)

clean:
	rm -rf $(OBJ) $(SRC) $(OUT)/.tree $(OUT)/LAFXCW.LIB

distclean:
	rm -rf $(OUT)

.PHONY: all clean distclean
