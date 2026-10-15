#!/bin/bash
# Boot a DOS hard disk image (linux/test/mkdosdisk.sh) with 386MAX in QEMU
# and show the screen (via linux/test/qemudrv.py).
#
#   linux/test/dosboot.sh svardos|edrdos|msdos622|IMAGE
#
# Environment:
#   CONFIG   CONFIG.SYS lines (| separated, default 386MAX.SYS and DOS=HIGH,UMB)
#   AUTO     AUTOEXEC.BAT lines (| separated)
#   KEEPCFG=1  leave CONFIG.SYS and AUTOEXEC.BAT of the image as they are
#   STEPS    qemudrv.py steps (default: wait 30 s, text screen)
#   MEMSIZE  QEMU memory in MB (default 32)
#
# 386MAX.SYS, 386LOAD.*, 386UTIL.COM from build/bin are copied to C:\MAX.
# Output (build/test-dosboot/): screen texts and shots
set -uo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
SRC=$1
[ -f "$ROOT/build/dosdisk/$1.img" ] && SRC=$ROOT/build/dosdisk/$1.img
[ -f "$SRC" ] || { echo "no $SRC (linux/test/mkdosdisk.sh)"; exit 1; }
OUT=${TESTDIR:-$ROOT/build/test-dosboot}
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$SRC" "$OUT/test.img"
P="$OUT/test.img@@32256"
crlf() { tr '|' '\n' | sed 's/$/\r/'; }
mmd -i "$P" ::/MAX 2>/dev/null
for f in 386MAX.SYS 386MAX.VXD 386LOAD.SYS 386LOAD.COM 386UTIL.COM EXTRADOS.MAX ASQ.EXE asq.hlp; do
    [ -f "$ROOT/build/bin/$f" ] && mcopy -o -i "$P" "$ROOT/build/bin/$f" ::/MAX/
done
[ "${KEEPCFG:-0}" = 1 ] || {
echo "${CONFIG:-DOS=HIGH,UMB|DEVICE=C:\\MAX\\386MAX.SYS|FILES=40|BUFFERS=20|SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P}" | crlf > "$OUT/CONFIG.SYS"
echo "${AUTO:-@ECHO OFF|PATH C:\\;C:\\MAX}" | crlf > "$OUT/AUTOEXEC.BAT"
mcopy -o -i "$P" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" ::/; }

SOCK=$OUT/monitor.sock
qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m "${MEMSIZE:-32}" -display none -vga std \
    -monitor unix:"$SOCK",server,nowait -drive if=ide,index=0,format=raw,file="$OUT/test.img" \
    -boot c -nic none -device isa-debug-exit,iobase=0x501,iosize=0x02 ${QEMU_EXTRA:-} \
    > "$OUT/qemu.log" 2>&1 &
QPID=$!
# shellcheck disable=SC2086
python3 "$ROOT/linux/test/qemudrv.py" "$SOCK" "$OUT" ${STEPS:-sleep:30 text:screen} shot:final quit
RC=$?
wait $QPID
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
for f in "$OUT"/*.txt; do echo "=== $(basename "$f")"; grep -v '^ *$' "$f"; done
exit $RC
