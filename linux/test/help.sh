#!/bin/bash
# The DOS help in QEMU: starts ASQ with a help database (HLP=file, default
# build/bin/asq.hlp), opens the help (F1), follows a link (Tab, Enter) and
# takes screen shots (build/test-help/help1.png, help2.png).
#   linux/test/help.sh            HLP=..., ASQEXE=..., KEYS2="tab ret"
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-help
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
ASQEXE=${ASQEXE:-$ROOT/build/bin/ASQ.EXE}
HLP=${HLP:-$ROOT/build/bin/asq.hlp}
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$BOOTIMG" "$OUT/boot.img"; chmod u+w "$OUT/boot.img"
cp "$HLP" "$OUT/ASQ.HLP"
cp "$ASQEXE" "$OUT/ASQ.EXE"
printf 'FILES=40\r\nSHELL=A:\\COMMAND.COM A:\\ /P\r\n' > "$OUT/CONFIG.SYS"
printf '@ECHO OFF\r\nA:\\ASQ.EXE\r\n' > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$OUT/boot.img" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" "$OUT/ASQ.EXE" "$OUT/ASQ.HLP" ::/ || exit 1
{ sleep "${START:-25}"
  echo "sendkey f1"; sleep 3; echo "screendump $OUT/help1.ppm"; sleep 1
  for k in ${KEYS2:-tab ret}; do echo "sendkey $k"; sleep 1; done
  sleep 2; echo "screendump $OUT/help2.ppm"; sleep 1; echo quit; } |
qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m 32 -display none -vga std -monitor stdio \
    -drive if=floppy,format=raw,file="$OUT/boot.img" -boot a -nic none >/dev/null 2>&1
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
ls "$OUT"/*.png
