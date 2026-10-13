# DOSMAX32.DLL, the Windows 95 shell extension (DOSMAX property sheet of
# DOS programs), 32-bit side of the Universal Thunk to DOSMAX16.DLL
# (GNU make, see linux/mk/win.mk)
PROJ     := DOSMAX32
ROOT     := $(abspath ..)
TARGET   := win32
INCDIRS  := . ../INCLUDE
CDEFS    := STRICT
CFLAGS_EXTRA := -bd
PROGS    := DOSMAX32.DLL

DOSMAX32.DLL_OBJS := DOSMAX32.OBJ PROPSHET.OBJ SHEXINIT.OBJ
DOSMAX32.DLL_RC   := DOSMAX32.RC
DOSMAX32.DLL_DEF  := DOSMAX32.DEF
DOSMAX32.DLL_LIBS := ole32 shell32 comctl32 uuid
# UTRegister/UTUnRegister of the Windows 95 KERNEL32 (TEXT/W32SUT32.LIB)
DOSMAX32.DLL_LINKOPTS := import \'_UTRegister@28\' kernel32.UTRegister \
                         import \'_UTUnRegister@4\' kernel32.UTUnRegister

include $(ROOT)/linux/mk/win.mk
