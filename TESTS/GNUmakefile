# DOS regression tests (see README.md): the programs listed in MAX.LST
# are assembled to build/TESTS, with RUNTESTS.BAT to run them under DOS.
# linux/test/suite.py runs them in QEMU.
ROOT  := $(abspath ..)
JWASM ?= $(ROOT)/linux/bin/jwasm
OUT   := $(ROOT)/build/TESTS
SRCS  := $(shell sed -n 's/^\([A-Z0-9_]*\/[A-Z0-9_]*\).*/\1/p' MAX.LST)
# helpers for scenario tests (no pass/fail of their own)
SRCS  += SCENARIO/TICK
EXES  := $(addprefix $(OUT)/,$(addsuffix .EXE,$(notdir $(SRCS))))

.PHONY: all
all: $(EXES) $(OUT)/RUNTESTS.BAT $(OUT)/README.TXT

$(OUT):
	mkdir -p $@

define TEST_RULE
$(OUT)/$(notdir $(1)).EXE: $(1).ASM INC/TESTLIB.INC $(JWASM) | $(OUT)
	$(JWASM) -q -mz -IINC -I$(dir $(1)) -Fo$$@ -Fw$$@.err $$< > $$@.log || { cat $$@.log; rm -f $$@; exit 1; }
	rm -f $$@.log $$@.err
endef
$(foreach s,$(SRCS),$(eval $(call TEST_RULE,$(s))))

$(OUT)/RUNTESTS.BAT: MAX.LST $(ROOT)/linux/tools/mkruntests.py | $(OUT)
	python3 $(ROOT)/linux/tools/mkruntests.py $< $@

$(OUT)/README.TXT: README.md | $(OUT)
	sed 's/$$/\r/' $< > $@
