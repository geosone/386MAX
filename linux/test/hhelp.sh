#!/bin/bash
# HHELP.EXE (DOS reader for Windows help files) in QEMU: boots DOS, runs
# HHELP with a help file (HLP=file, default build/bin/MAXHELP.HLP), sends
# KEYS (QEMU sendkey names, space separated; "shot" takes a screen shot)
# and takes a screen shot at the end (build/test-hhelp/shot<n>.png).
#   linux/test/hhelp.sh               HLP=..., HHELPEXE=..., KEYS="tab ret shot"
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-hhelp
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
HHELPEXE=${HHELPEXE:-$ROOT/build/bin/HHELP.EXE}
HLP=${HLP:-$ROOT/build/bin/MAXHELP.HLP}
rm -rf "$OUT"; mkdir -p "$OUT/c"
cp "$HHELPEXE" "$OUT/c/HHELP.EXE"
cp "$HLP" "$OUT/c/HELP.HLP"
cp "$BOOTIMG" "$OUT/boot.img"; chmod u+w "$OUT/boot.img"
printf 'FILES=40\r\nSHELL=A:\\COMMAND.COM A:\\ /P\r\n' > "$OUT/CONFIG.SYS"
printf '@ECHO OFF\r\nC:\r\nHHELP HELP.HLP\r\nECHO done %%ERRORLEVEL%%\r\n' > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$OUT/boot.img" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" ::/ || exit 1
n=0
{ sleep "${START:-20}"
  for k in ${KEYS:-}; do
    if [ "$k" = shot ]; then n=$((n + 1)); echo "screendump $OUT/shot$n.ppm"; sleep 1
    else echo "sendkey $k"; sleep "${DELAY:-1}"; fi
  done
  sleep 2; echo "screendump $OUT/final.ppm"; sleep 1; echo quit; } |
qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m 32 -display none -vga std -monitor stdio \
    -drive if=floppy,format=raw,file="$OUT/boot.img" \
    -drive file=fat:rw:"$OUT/c",format=raw,if=ide -boot a -nic none >/dev/null 2>&1
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
ls "$OUT"/*.png
