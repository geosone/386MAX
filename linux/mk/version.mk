# The version of Open 386MAX comes from one file, VERSION in the root
# ("8.51"); included by dos.mk and win.mk.  Assembler sources get
# @VER_MAJOR/@VER_MINOR (386MAX/VERSRET.ASM, EXTRADOS/ QMT/VERSION.ASM),
# C sources and resource scripts O386_VER_MAJOR/O386_VER_MINOR and
# O386_VER_MINOR_S (minor as written, for the strings; INCLUDE/MVERSION.H).
VERSION_FILE  := $(ROOT)/VERSION
O386_VERSION  := $(strip $(shell tr -d '\r' < $(VERSION_FILE)))
O386_VMAJ     := $(word 1,$(subst ., ,$(O386_VERSION)))
O386_VMINS    := $(word 2,$(subst ., ,$(O386_VERSION)))
O386_VMIN     := $(or $(patsubst 0%,%,$(O386_VMINS)),0)
ifeq ($(O386_VMAJ)$(O386_VMINS),)
$(error $(VERSION_FILE): no version (major.minor))
endif
VERDEFS_ASM   := -D@VER_MAJOR=$(O386_VMAJ) -D@VER_MINOR=$(O386_VMIN)
VERDEFS_C     := -dO386_VER_MAJOR=$(O386_VMAJ) -dO386_VER_MINOR=$(O386_VMIN) \
		 -dO386_VER_MINOR_S=$(O386_VMINS)
