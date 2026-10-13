# QMT.EXE (memory tester shipped with 386MAX, OEM=QMT) and RAMEXAM.EXE
# (full RAMexam, OEM=RET) (GNU make, see linux/mk/dos.mk; MAKEFILE is the
# original NMAKE file).  Without OEM= both are built.
ROOT     := $(abspath ..)

ifeq ($(OEM),)
TARGETS := all clean check masmref cmp cmplink origlink
.PHONY: $(TARGETS)
$(TARGETS):
	$(MAKE) OEM=QMT $@
	$(MAKE) OEM=RET $@
else

PROJ     := QMT/$(OEM)
SRCDIRS  := . ../386MAX
ASMINC   := . ../INC ../386MAX
DEFS     := OEM=$(OEM)
EMPTYINC := DIRNTRY.INC

ifeq ($(OEM),QMT)
PRODNAME := QMT
VERSOBJ  := VERSRET.OBJ
QMT.EXE_MAP  := ../LIB/QMT.MAP
QMT.EXE_ORIG := ../LIB/QMT.EXE
# RET/ holds the objects of the RAMEXAM build
NOORIGOBJ := 1
else
PRODNAME := RAMEXAM
VERSOBJ  := VERSION.OBJ
RAMEXAM.EXE_MAP := RET/RAMEXAM.MAP
endif
PROGS    := $(PRODNAME).EXE

$(PRODNAME).EXE_OBJS := MEM_MAIN.OBJ MEM_CMD.OBJ MEM_EPM.OBJ MEM_FALT.OBJ MEM_FCN.OBJ \
	MEM_KEY.OBJ MEM_MISC.OBJ MEM_SCRN.OBJ MEM_SYS.OBJ MEM_TIME.OBJ MEM_FMT.OBJ \
	MEM_HELP.OBJ MEM_HTXT.OBJ MEM_CAL.OBJ MEM_MSGS.OBJ MEM_USF.OBJ MEM_UTF.OBJ \
	MEM_UIN.OBJ MEM_UID.OBJ MEM_LIN.OBJ MEM_LID.OBJ $(VERSOBJ) VERSBETA.OBJ \
	MEM_A20.OBJ MEM_HTX3.OBJ MEM_IDN.OBJ

# The help text: MEM_HTX2.A<language> is assembled and linked to a .COM
# file, which WRAPPER (linux/tools/wrapper.py, a port of WRAPPER.C) turns
# into the word-wrapped source of MEM_HTX3.OBJ.
HTXLANG  := $(if $(filter GR,$(MAXLANG)),AGR,AUS)
# Masm 5.10A rejects "call near ptr PGROUP:x" in MEM_EPM; the original
# object of the RAMEXAM build is the reference there
ifeq ($(OEM),RET)
MEM_EPM.OBJ_REF := RET/MEM_EPM.OBJ
endif
MEM_HTX3.OBJ_SRC := $(ROOT)/build/$(PROJ)/MEM_HTX2.AS2

include $(ROOT)/linux/mk/dos.mk

$(OUT)/MEM_HTX3.OB2: MEM_HTX2.$(HTXLANG) $(INCDEPS) $(JWASM) | $(OUT)
	$(JWASM) $(AFLAGS) -Fw$@.err -Fo$@ $< > $@.log || { cat $@.log; exit 1; }
$(OUT)/MEM_HTX2.COM: $(OUT)/MEM_HTX3.OB2
	cd $(OUT) && $(JWLINK) format dos com name MEM_HTX2.COM option quiet file MEM_HTX3.OB2
$(OUT)/MEM_HTX2.AS2: $(OUT)/MEM_HTX2.COM $(LX)/tools/wrapper.py
	$(PYTHON) $(LX)/tools/wrapper.py $< $@

endif
