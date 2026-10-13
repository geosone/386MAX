#!/bin/bash
# Boot MS-DOS 7.1 in QEMU with 386MAX.SYS and report the memory layout.
#
#   linux/test/run.sh [386MAX.SYS options]
#
# Environment:
#   MAXSYS   386MAX.SYS to test (default build/bin/386MAX.SYS, see "make")
#   NOMAX    1: boot without 386MAX (reference run)
#   DEVICES  more CONFIG.SYS lines after 386MAX (| separated)
#   BATCH    AUTOEXEC.BAT commands (| separated, output > AUX)
#   FILES    more files to copy to A:\ (space separated)
#   MEMSIZE  QEMU memory in MB (default 64)
#   QEMU_EXTRA  more QEMU arguments
#   TIMEOUT  seconds until the screen is captured (default 240; 386MAX needs ~150 s in QEMU)
#
# Output (build/test/): serial.log, screen.png
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
MEMEXE=${MEMEXE:-$ROOT/linux/tools/MEM.EXE}
MAXSYS=${MAXSYS:-$ROOT/build/bin/386MAX.SYS}
OPTS="$*"

rm -rf "$OUT"; mkdir -p "$OUT"
nasm -f bin -o "$OUT/QEXIT.COM" "$ROOT/linux/tools/qexit.asm" || exit 1
cp "$BOOTIMG" "$OUT/boot.img"; chmod u+w "$OUT/boot.img"
cp "$MAXSYS" "$OUT/386MAX.SYS"

crlf() { tr '|' '\n' | sed 's/$/\r/'; }
{
    [ -z "${NOMAX:-}" ] && echo "DEVICE=A:\\386MAX.SYS $OPTS"
    echo 'DOS=HIGH,UMB'
    [ -n "${DEVICES:-}" ] && echo "$DEVICES" | tr '|' '\n'
    echo 'FILES=40'
    echo 'SHELL=A:\COMMAND.COM A:\ /P'
} | crlf > "$OUT/CONFIG.SYS"
{
    echo '@ECHO OFF'
    echo 'PATH A:\'
    echo "${BATCH:-MEM /C}" | tr '|' '\n' | sed 's/$/ > AUX/'
    echo 'ECHO END OF TEST > AUX'
    echo 'QEXIT'
} | crlf > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$OUT/boot.img" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" "$OUT/386MAX.SYS" \
      "$OUT/QEXIT.COM" "$MEMEXE" ${FILES:-} ::/ || exit 1

{ sleep "${TIMEOUT:-240}"; echo "screendump $OUT/screen.ppm"; sleep 1; echo quit; } |
qemu-system-i386 -machine pc -m "${MEMSIZE:-64}" -display none -vga std -monitor stdio \
    -drive if=floppy,format=raw,file="$OUT/boot.img" -boot a \
    -nic none ${QEMU_EXTRA:-} \
    -serial file:"$OUT/serial.log" \
    -device isa-debug-exit,iobase=0x501,iosize=0x02 >/dev/null 2>&1
[ -f "$OUT/screen.ppm" ] && command -v magick >/dev/null && magick "$OUT/screen.ppm" "$OUT/screen.png"

echo "=== CONFIG.SYS"; tr -d '\r' < "$OUT/CONFIG.SYS"
echo "=== serial.log"; tr -d '\r' < "$OUT/serial.log"
tr -d '\r' < "$OUT/serial.log" | grep -q 'END OF TEST'
