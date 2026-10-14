#!/bin/bash
# Start a 386MAX Windows program in Windows for Workgroups 3.11 (enhanced
# mode, QEMU) and take a screenshot: boots the image made by
# linux/test/mkwin311.sh, copies build/bin to C:\MAX and runs
# WIN C:\MAX\<program> (Windows starts the program at once).
#
#   linux/test/win311.sh WINMAXIM.EXE [arguments]
#   linux/test/win311.sh path/TEST.EXE [arguments]    (copied to C:\MAX too)
#   SETUPPKG=1 linux/test/win311.sh SETUP              (Windows installation)
#
# Environment:
#   MM=himem    HIMEM.SYS only (default)
#   MM=386max   386MAX.SYS + 386MAX.VXD from build/bin
#   KEYS        QEMU monitor sendkey commands (| separated) sent after
#               TIMEOUT1 seconds, e.g. "ret|alt-f4"; wait<n>: n seconds pause
#   TIMEOUT     seconds until the (last) screenshot (default 120)
#   SHOTS       further screenshot times in seconds (space separated, before
#               KEYS)
#   KEYSHOTS=1  screenshot key-<n>.png before each key of KEYS
#   SETUPPKG=1  copy build/package (linux/tools/mkpkg.py) to C:\INSTALL and
#               run C:\INSTALL\SETUP.EXE; the image is kept as
#               build/win311test/test.img (KEEP=1: start from it again)
#   FAULTLOG=1  start the program through linux/test/faultlog: faults with
#               module and segment -> fault.log
#   PRE         AUTOEXEC.BAT commands before Windows (| separated, output
#               > AUX), e.g. a TSR to test under Windows
#   FILES       more files to copy to C:\MAX (space separated)
#   ORIGDLL=dir CTL3DV2.DLL / SFTTABS.DLL from dir (e.g. the original ones)
#               instead of ours
#
# Output (build/win311test/): screen.png (screen-<t>.png), serial.log
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/win311test
BASE=$ROOT/build/win311/win311.img
MM=${MM:-himem}
PROG=${1:?program in build/bin, e.g. WINMAXIM.EXE}; shift
[ -f "$BASE" ] || { echo "run linux/test/mkwin311.sh first"; exit 1; }
EXTRA=
case "$PROG" in */*) EXTRA=$PROG; PROG=$(basename "$PROG") ;; esac
[ -n "$EXTRA" ] || [ "${SETUPPKG:-0}" = 1 ] || [ -f "$ROOT/build/bin/$PROG" ] || { echo "no build/bin/$PROG"; exit 1; }

if [ "${KEEP:-0}" = 1 ] && [ -f "$OUT/test.img" ]; then BASE=$OUT/keep.img; mv "$OUT/test.img" "$BASE"; fi
find "$OUT" -mindepth 1 -maxdepth 1 ! -name keep.img -exec rm -rf {} + 2>/dev/null; mkdir -p "$OUT/c/MAX"
nasm -f bin -o "$OUT/c/QEXIT.COM" "$ROOT/linux/tools/qexit.asm" || exit 1
cp "$ROOT"/build/bin/* "$OUT/c/MAX/"
[ -n "$EXTRA" ] && cp "$EXTRA" "$OUT/c/MAX/"
[ -n "${FILES:-}" ] && cp ${FILES} "$OUT/c/MAX/"
cp "$BASE" "$OUT/test.img"
# the profile of MM=386max (WINMAXIM wants a PRO= in the DEVICE line)
[ -f "$OUT/c/MAX/386MAX.PRO" ] || printf '; 386MAX profile\r\n' > "$OUT/c/MAX/386MAX.PRO"

crlf() { tr '|' '\n' | sed 's/$/\r/'; }
{
    case "$MM" in
    himem)  echo 'DEVICE=C:\HIMEM.SYS' ;;
    386max) echo 'DEVICE=C:\MAX\386MAX.SYS PRO=C:\MAX\386MAX.PRO'
            echo 'DOS=HIGH,UMB' ;;
    *) echo "unknown MM=$MM" >&2; exit 1 ;;
    esac
    echo 'FILES=40|BUFFERS=20|LASTDRIVE=Z|SHELL=C:\COMMAND.COM C:\ /P'
} | crlf > "$OUT/c/CONFIG.SYS"
{
    echo '@ECHO OFF'
    echo 'PATH C:\;C:\WINDOWS;C:\MAX'
    [ -n "${PRE:-}" ] && echo "$PRE" | tr '|' '\n' | sed 's/$/ > AUX/'
    echo 'ECHO --- starting Windows > AUX'
    # setup only until MAX is installed (MAXIMIZE saves and restores this
    # file), then plain Windows
    if [ "${SETUPPKG:-0}" = 1 ]; then echo "IF EXIST C:\\QMAX\\386MAX.SYS GOTO WIN|C:\\WINDOWS\\WIN C:\\INSTALL\\SETUP.EXE $*|GOTO END|:WIN|C:\\WINDOWS\\WIN|:END" | tr '|' '\n'
    else echo "C:\\WINDOWS\\WIN ${FAULTLOG:+C:\\MAX\\FAULTLOG.EXE }C:\\MAX\\$PROG $*"; fi
    echo 'ECHO --- back from Windows > AUX'
    # (not with SETUPPKG: MAXIMIZE runs this file again in its phases)
    [ "${SETUPPKG:-0}" = 1 ] || echo 'QEXIT'
} | crlf > "$OUT/c/AUTOEXEC.BAT"
P="$OUT/test.img@@32256"
mcopy -o -s -i "$P" "$OUT"/c/* ::/
if [ "${SETUPPKG:-0}" = 1 ]; then
    mmd -i "$P" ::/INSTALL 2>/dev/null
    for f in "$ROOT"/build/package/*; do [ -f "$f" ] && mcopy -o -i "$P" "$f" ::/INSTALL/; done
fi
# what SETUP puts into WINDOWS\SYSTEM: our CTL3DV2.DLL / SFTTABS.DLL, or
# the originals from ORIGDLL=<directory> (Windows takes a DLL from the
# program's directory first, and the original CTL3DV2.DLL refuses to run
# from there)
for f in CTL3DV2.DLL SFTTABS.DLL; do
    src=$ROOT/build/bin/$f
    if [ -n "${ORIGDLL:-}" ] && [ -f "$ORIGDLL/$f" ]; then
        src=$ORIGDLL/$f
        [ -f "$OUT/c/MAX/$f" ] && mdel -i "$P" ::/MAX/$f
    fi
    mcopy -o -i "$P" "$src" ::/WINDOWS/SYSTEM/
done
if [ "$MM" = 386max ]; then     # Windows needs the VxD in SYSTEM.INI
    mcopy -o -i "$P" ::/WINDOWS/SYSTEM.INI "$OUT/system.ini"
    sed -i 's/^\[386Enh\]\r$/[386Enh]\r\ndevice=C:\\MAX\\386MAX.VXD\r/' "$OUT/system.ini"
    mcopy -o -i "$P" "$OUT/system.ini" ::/WINDOWS/SYSTEM.INI
fi

if [ "${FAULTLOG:-0}" = 1 ]; then
    make -s -C "$ROOT/linux/test/faultlog" >/dev/null || exit 1
    mcopy -o -i "$P" "$ROOT/build/FAULTLOG/FAULTLOG.EXE" ::/MAX/
fi

[ "${FAULTLOG:-0}" = 1 ] || FAULTLOG=
T=${TIMEOUT:-120}
{
    t=0
    for s in ${SHOTS:-}; do sleep $((s - t)); t=$s; echo "screendump $OUT/screen-$s.ppm"; done
    if [ -n "${KEYS:-}" ]; then
        sleep $(( ${TIMEOUT1:-60} - t )); t=${TIMEOUT1:-60}
        n=0
        for k in $(echo "$KEYS" | tr '|' ' '); do
            case $k in wait[0-9]*) sleep ${k#wait}; t=$((t + ${k#wait})); continue ;; esac
            n=$((n + 1))
            [ "${KEYSHOTS:-0}" = 1 ] && { echo "screendump $OUT/key-$n.ppm"; sleep 1; }
            echo "sendkey $k"; sleep 2; t=$((t + 2 + ${KEYSHOTS:-0}))
        done
    fi
    sleep $((T - t > 0 ? T - t : 1)); echo "screendump $OUT/screen.ppm"; sleep 1; echo quit
} | qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m 32 -display none -vga std -monitor stdio \
    -drive if=ide,index=0,format=raw,file="$OUT/test.img" -boot c -nic none \
    -serial file:"$OUT/serial.log" \
    -device isa-debug-exit,iobase=0x501,iosize=0x02 ${QEMU_EXTRA:-} > "$OUT/monitor.log" 2>&1
mcopy -i "$P" ::/FAULT.LOG "$OUT/fault.log" 2>/dev/null && { echo "=== fault.log"; tr -d '\r' < "$OUT/fault.log"; }
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
tr -d '\r' < "$OUT/serial.log"
ls "$OUT"/*.png
