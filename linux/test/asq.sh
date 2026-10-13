#!/bin/bash
# Run ASQ in QEMU (MS-DOS 7.1 without 386MAX): "ASQ /S SNAP.ASQ /X" walks
# through the whole system analysis (ASQENG) and writes a snapshot file.
#
#   linux/test/asq.sh
#
# Environment:
#   ASQEXE   ASQ.EXE to test (default build/bin/ASQ.EXE, see "make")
#   TIMEOUT  seconds until QEMU is stopped (default 120)
#
# Output (build/test-asq/): SNAP.ASQ, serial.log, screen.png
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-asq
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
ASQEXE=${ASQEXE:-$ROOT/build/bin/ASQ.EXE}

rm -rf "$OUT"; mkdir -p "$OUT"
nasm -f bin -o "$OUT/QEXIT.COM" "$ROOT/linux/tools/qexit.asm" || exit 1
cp "$BOOTIMG" "$OUT/boot.img"; chmod u+w "$OUT/boot.img"

crlf() { sed 's/$/\r/'; }
printf 'FILES=40\nSHELL=A:\\COMMAND.COM A:\\ /P\n' | crlf > "$OUT/CONFIG.SYS"
{
    echo '@ECHO OFF'
    echo 'A:\ASQ.EXE /S A:\SNAP.ASQ /D "test" /X'
    echo 'IF ERRORLEVEL 1 ECHO ERRORLEVEL 1 > AUX'
    echo 'ECHO END OF TEST > AUX'
    echo 'QEXIT'
} | crlf > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$OUT/boot.img" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" "$OUT/QEXIT.COM" \
      "$ASQEXE" "$ROOT/LIB/ASQ.HLP" ::/ || exit 1

# QEXIT ends QEMU; the screen dump is for the case that ASQ hangs
{ sleep "${TIMEOUT:-120}"; echo "screendump $OUT/screen.ppm"; sleep 1; echo quit; } |
qemu-system-i386 -machine pc -m 32 -display none -vga std -monitor stdio \
    -drive if=floppy,format=raw,file="$OUT/boot.img" -boot a -nic none \
    -serial file:"$OUT/serial.log" \
    -device isa-debug-exit,iobase=0x501,iosize=0x02 >/dev/null 2>&1
[ -f "$OUT/screen.ppm" ] && command -v magick >/dev/null && magick "$OUT/screen.ppm" "$OUT/screen.png"

echo "=== serial.log"; tr -d '\r' < "$OUT/serial.log"
mcopy -o -i "$OUT/boot.img" ::/SNAP.ASQ "$OUT/SNAP.ASQ" 2>/dev/null || { echo "no SNAP.ASQ"; exit 1; }
echo "=== SNAP.ASQ ($(stat -c %s "$OUT/SNAP.ASQ") bytes)"
strings -n 4 "$OUT/SNAP.ASQ" | grep -E '^(BiosMfr|Mhz|SVGAModel|TimeList)'
tr -d '\r' < "$OUT/serial.log" | grep -q 'END OF TEST' && ! tr -d '\r' < "$OUT/serial.log" | grep -q ERRORLEVEL
