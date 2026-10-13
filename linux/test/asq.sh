#!/bin/bash
# Run ASQ in QEMU (MS-DOS 7.1 without 386MAX): "ASQ /S SNAP.ASQ /X" walks
# through the whole system analysis (ASQENG) and writes a snapshot file.
#
#   linux/test/asq.sh
#
# Environment:
#   ASQEXE   ASQ.EXE to test (default build/bin/ASQ.EXE, see "make")
#   ASQHLP   its help file (default asq.hlp next to ASQEXE)
#   TIMEOUT  seconds until QEMU is stopped (default 120)
#   KEYS     interactive instead: ASQ runs with ASQARGS (default none), these
#            QEMU monitor inputs follow after START seconds (default 40),
#            space separated: sendkey names, "shot" (screen shot shot<n>.png),
#            "wait<n>" (n seconds)
#   QEMU     emulator (default qemu-system-i386)
#   MACHINE, MEMSIZE, QEMU_EXTRA  QEMU machine (pc), memory in MB (32) and more
#            arguments (default -nic none)
#   SNAP     snapshot file copied to A:\SNAP.ASQ (e.g. for ASQARGS="/S A:\SNAP.ASQ")
#
# Output (build/test-asq/): SNAP.ASQ, serial.log, screen.png, shot<n>.png
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
    if [ -n "${KEYS:-}" ]; then echo "A:\\ASQ.EXE ${ASQARGS:-}"
    else echo 'A:\ASQ.EXE /S A:\SNAP.ASQ /D "test" /X'; fi
    echo 'IF ERRORLEVEL 1 ECHO ERRORLEVEL 1 > AUX'
    echo 'ECHO END OF TEST > AUX'
    echo 'QEXIT'
} | crlf > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$OUT/boot.img" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" "$OUT/QEXIT.COM" \
      "${ASQHLP:-$(dirname "$ASQEXE")/asq.hlp}" ::/ || exit 1
mcopy -o -i "$OUT/boot.img" "$ASQEXE" ::/ASQ.EXE || exit 1
[ -n "${SNAP:-}" ] && { mcopy -o -i "$OUT/boot.img" "$SNAP" ::/SNAP.ASQ || exit 1; }

# QEXIT ends QEMU; the screen dump is for the case that ASQ hangs
n=0
{ if [ -n "${KEYS:-}" ]; then
    sleep "${START:-40}"
    for k in $KEYS; do
      case $k in
      shot) n=$((n + 1)); echo "screendump $OUT/shot$n.ppm"; sleep 1 ;;
      wait*) sleep "${k#wait}" ;;
      *) echo "sendkey $k"; sleep 1 ;;
      esac
    done
  else sleep "${TIMEOUT:-120}"; fi
  echo "screendump $OUT/screen.ppm"; sleep 1; echo quit; } |
${QEMU:-qemu-system-i386} -machine ${MACHINE:-pc} -m ${MEMSIZE:-32} -display none -vga std -monitor stdio \
    -drive if=floppy,format=raw,file="$OUT/boot.img" -boot a ${QEMU_EXTRA:--nic none} \
    -serial file:"$OUT/serial.log" \
    -device isa-debug-exit,iobase=0x501,iosize=0x02 >/dev/null 2>&1
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
[ -n "${KEYS:-}" ] && exit 0

echo "=== serial.log"; tr -d '\r' < "$OUT/serial.log"
mcopy -o -i "$OUT/boot.img" ::/SNAP.ASQ "$OUT/SNAP.ASQ" 2>/dev/null || { echo "no SNAP.ASQ"; exit 1; }
echo "=== SNAP.ASQ ($(stat -c %s "$OUT/SNAP.ASQ") bytes)"
strings -n 4 "$OUT/SNAP.ASQ" | grep -E '^(BiosMfr|Mhz|SVGAModel|TimeList)'
tr -d '\r' < "$OUT/serial.log" | grep -q 'END OF TEST' && ! tr -d '\r' < "$OUT/serial.log" | grep -q ERRORLEVEL
