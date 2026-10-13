#!/bin/bash
# Reference build with the original Microsoft MASM 5.10 in DOSBox, only to
# compare with the JWasm objects (MASM is not part of this tree and not
# needed for building).  Called by "make masmref" (linux/mk/dos.mk).
#
#   MASM_EXE=/path/to/MASM.EXE masmref.sh SRCDIR PROJ "INCDIRS" "DEFINES" SRC=OBJ[=DEFINES] ...
#
# SRC is relative to the project directory (passed to Masm as an absolute
# path like the original makefiles did: Masm 5.10 looks into the source
# directory only for paths starting with ".."), INCDIRS are the include
# directories (relative to the project) in search order.
# SRCDIR is the project directory, PROJ the name of the build (build/PROJ).
# Output: build/masm/PROJ/OBJ, a listing and the Masm messages.
set -u
R=$(cd "$(dirname "$0")/../.." && pwd)
: "${MASM_EXE:?set MASM_EXE to MASM.EXE (5.10)}"
SRCDIR=$1 PROJ=$2 INCS=$3 GDEFS=$4; shift 4
OUT=$R/build/masm/$PROJ
mkdir -p "$OUT" "$R/build/$PROJ"
cp "$MASM_EXE" "$OUT/MASM.EXE"
dos() { echo "$1" | tr '/' '\\'; }
inc="e:\\"
for i in $INCS; do inc="$inc;$(dos "$i")"; done
# all Masm calls in one batch file (DOSBox takes only ~10 -c commands)
{
    # options in the MASM variable (like the original makefiles): the DOS
    # command line holds only 127 characters
    printf '@echo off\r\nset INCLUDE=%s\r\nset MASM=%s /p /r /t /w1 /DLANG_US %s\r\nc:\r\ncd \\%s\r\n' \
        "$inc" "${MASMCASE:-/mu}" "$GDEFS" "$SRCDIR"
    for it in "$@"; do
        IFS='=' read -r src obj defs <<< "$it"
        base=${obj%.*}
        case ${obj##*.} in OBJ) l=LST o=OUT ;; OPT) l=LSO o=OUO ;; *) l=LSN o=OUN ;; esac
        printf 'd:masm %s %s,d:%s,d:%s.%s; > d:%s.%s\r\n' \
            "$defs" "c:$(dos "$(realpath -m --relative-to="$R" "$(cd "$R/$SRCDIR" && realpath -m "$src")" | sed 's|^|/|')")" "$obj" "$base" "$l" "$base" "$o"
    done
    printf 'exit\r\n'
} > "$OUT/MASMREF.BAT"
timeout 1800 env SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy dosbox -conf "$R/linux/scripts/masmref.conf" \
    -c "mount c $R" -c "mount d $OUT" -c "mount e $R/build/$PROJ" -c "d:\\MASMREF.BAT" >/dev/null 2>&1
for it in "$@"; do
    IFS='=' read -r src obj defs <<< "$it"
    base=${obj%.*}; case ${obj##*.} in OBJ) o=OUT ;; OPT) o=OUO ;; *) o=OUN ;; esac
    printf '%s: ' "$obj"; grep -a -E 'Severe|Warning Errors' "$OUT/$base.$o" 2>/dev/null | tr -s ' \r\n' ' '; echo
done
