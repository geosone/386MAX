#!/bin/bash
# The MAX shell (MAX.EXE) in QEMU: boots DOS with 386MAX.SYS from C:\MAX
# (a copy of build/bin), starts MAX.EXE and sends KEYS (QEMU sendkey names,
# space separated; "shot" takes a screen shot, "wait<n>" sleeps n seconds).
#   linux/test/maxsh.sh            MAXEXE=<file> (e.g. the original), NOMAX=1, MAXOPTS=,
#                                  CMD= (instead of MAX.EXE), PKG=1 (package in C:\INSTALL),
#                                  START=seconds, KEYS="..."
# Output (build/test-maxsh/): shot<n>.png, final.png
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-maxsh
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
rm -rf "$OUT"; mkdir -p "$OUT/c/MAX"
cp "$ROOT"/build/bin/* "$OUT/c/MAX/"
[ -n "${MAXEXE:-}" ] && cp "$MAXEXE" "$OUT/c/MAX/MAX.EXE"
# PKG=1: the installation package (build/package, linux/tools/mkpkg.py) in C:\INSTALL
[ "${PKG:-0}" = 1 ] && mkdir -p "$OUT/c/INSTALL" && cp "$ROOT"/build/package/* "$OUT/c/INSTALL/"
cp "$BOOTIMG" "$OUT/boot.img"; chmod u+w "$OUT/boot.img"
{
    [ "${NOMAX:-0}" = 1 ] || echo "DEVICE=C:\MAX\386MAX.SYS ${MAXOPTS:-}"
    echo 'DOS=HIGH,UMB'
    echo 'FILES=40'
    echo 'SHELL=A:\COMMAND.COM A:\ /P'
} | sed 's/$/\r/' > "$OUT/CONFIG.SYS"
printf "@ECHO OFF\r\nPATH A:\;C:\\MAX\r\nC:\r\nCD \\MAX\r\n%s\r\n" "${CMD:-MAX.EXE}" > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$OUT/boot.img" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" ::/ || exit 1
n=0
{ sleep "${START:-60}"
  for k in ${KEYS:-}; do
    case "$k" in
    shot) n=$((n + 1)); echo "screendump $OUT/shot$n.ppm"; sleep 1 ;;
    wait*) sleep "${k#wait}" ;;
    *) echo "sendkey $k"; sleep "${DELAY:-1}" ;;
    esac
  done
  sleep 2; echo "screendump $OUT/final.ppm"; sleep 1; echo quit; } |
qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m ${MEMSIZE:-64} -display none -vga std -monitor stdio \
    -drive if=floppy,format=raw,file="$OUT/boot.img" \
    -drive file=fat:rw:"$OUT/c",format=raw,if=ide -boot a -nic none >/dev/null 2>&1
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
ls "$OUT"/*.png
