#!/bin/bash
# Complete DOS installation and MAXIMIZE run in QEMU: the Windows for
# Workgroups 3.11 image (linux/test/mkwin311.sh, MS-DOS 7.1 on C:) gets a
# typical configuration (HIMEM, IFSHLP, RAMDRIVE, COUNTRY, SMARTDRV, KEYB)
# and the installation package in C:\INSTALL; the first boot runs SETUPDOS,
# which installs to C:\QMAX and starts MAXIMIZE with its reboots.
#
#   linux/test/maxdos.sh [US|GR]
#
# Environment:
#   STEPS    steps for linux/test/qemudrv.py (space separated: wait:TEXT,
#            key:K, sleep:N, shot, text, quit); "_" in TEXT is a blank
#   PKG      installation package (default release/<lang>/package)
#   CFG      CONFIG.SYS lines (| separated) instead of the typical set
#   AUTO     AUTOEXEC.BAT lines (| separated; the SETUPDOS line is appended)
#   CDROM    ISO image as IDE CD-ROM (secondary master)
#   BASEIMG  disk to start from (default the WfW 3.11 image; e.g.
#            build/dosdisk/edrdos.img from linux/test/mkdosdisk.sh)
#   TAG      output to build/test-maxdos-<TAG> (parallel runs)
#   KEEP=1   continue with the disk of the previous run (no new image)
#   MEMSIZE  QEMU memory in MB (default 32)
#   KEYBLINE AUTOEXEC.BAT line for the keyboard driver (default KEYB GR;
#            empty: none)
#
# Output (build/test-maxdos/): shot<n>.png, final.png, result/ (CONFIG.SYS,
# AUTOEXEC.BAT and C:\QMAX\*.PRO after the run)
set -uo pipefail
L=${1:-US}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-maxdos${TAG:+-$TAG}
BASE=${BASEIMG:-$ROOT/build/win311/win311.img}
PKG=${PKG:-$ROOT/release/$L/package}
DOS=${DOS_DIR:-$HOME/Iso/Dos}
DOSIMG=${DOSIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
[ -f "$BASE" ] || { echo "run linux/test/mkwin311.sh first"; exit 1; }
[ -d "$PKG" ] || { echo "no package $PKG (linux/scripts/buildlang.sh $L)"; exit 1; }
P="$OUT/test.img@@32256"
crlf() { tr '|' '\n' | sed 's/$/\r/'; }

if [ "${KEEP:-0}" = 1 ] && [ -f "$OUT/test.img" ]; then
    find "$OUT" -maxdepth 1 -name '*.png' -delete
else
    rm -rf "$OUT"; mkdir -p "$OUT/dos"
    cp "$BASE" "$OUT/test.img"
    nasm -f bin -o "$OUT/QEXIT.COM" "$ROOT/linux/tools/qexit.asm" || exit 1
    # DOS drivers and tools from the DOS boot floppy
    # (another base disk has its own DOS tools: only the CD-ROM driver)
    DOSFILES="COUNTRY.SYS KEYB.COM KEYBOARD.SYS MODE.COM EDIT.COM DISPLAY.SYS EGA.CPI OAKCDROM.SYS MSCDEX.EXE"
    [ -n "${BASEIMG:-}" ] && DOSFILES=OAKCDROM.SYS
    for f in $DOSFILES; do
        mcopy -o -i "$DOSIMG" "::/$f" "$OUT/dos/" 2>/dev/null
    done
    mmd -i "$P" ::/DOS 2>/dev/null; mmd -i "$P" ::/INSTALL 2>/dev/null
    mcopy -o -i "$P" "$OUT"/dos/* ::/DOS/
    mcopy -o -i "$P" "$OUT/QEXIT.COM" ::/
    for f in "$PKG"/*; do [ -f "$f" ] && mcopy -o -i "$P" "$f" ::/INSTALL/; done
    echo "${CFG:-DEVICE=C:\\HIMEM.SYS|DEVICE=C:\\WINDOWS\\IFSHLP.SYS|DEVICE=C:\\WINDOWS\\RAMDRIVE.SYS 512|COUNTRY=049,850,C:\\DOS\\COUNTRY.SYS|FILES=40|BUFFERS=20|SHELL=C:\\COMMAND.COM C:\\ /P}" \
        | crlf > "$OUT/CONFIG.SYS"
    # the installation replaces AUTOEXEC.BAT for MAXIMIZE and restores it
    KB=${KEYBLINE-'C:\DOS\KEYB GR,,C:\DOS\KEYBOARD.SYS'}
    echo "${AUTO:-@ECHO OFF|PATH C:\\;C:\\DOS;C:\\WINDOWS;C:\\QMAX|C:\\WINDOWS\\SMARTDRV.EXE|$KB}|IF NOT EXIST C:\\QMAX\\386MAX.SYS C:\\INSTALL\\SETUPDOS" \
        | crlf > "$OUT/AUTOEXEC.BAT"
    mcopy -o -i "$P" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" ::/
fi

# an empty floppy in A: (MAXIMIZE's ROM search tests the floppy services)
[ -f "$OUT/floppy.img" ] || { dd if=/dev/zero of="$OUT/floppy.img" bs=1k count=1440 2>/dev/null;
    mformat -i "$OUT/floppy.img" -f 1440 ::; }
SOCK=$OUT/monitor.sock
rm -f "$SOCK"
qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m "${MEMSIZE:-32}" -display none -vga std \
    -monitor unix:"$SOCK",server,nowait -drive if=ide,index=0,format=raw,file="$OUT/test.img" \
    -drive if=floppy,index=0,format=raw,file="$OUT/floppy.img" \
    ${CDROM:+-drive if=ide,index=2,media=cdrom,file="$CDROM"} \
    -boot c -nic none -device isa-debug-exit,iobase=0x501,iosize=0x02 -debugcon file:"$OUT/debugcon.log" ${QEMU_EXTRA:-} \
    > "$OUT/qemu.log" 2>&1 &
QPID=$!
# shellcheck disable=SC2086
python3 "$ROOT/linux/test/qemudrv.py" "$SOCK" "$OUT" ${STEPS:-} shot:final quit
RC=$?
wait $QPID
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done

rm -rf "$OUT/result"; mkdir -p "$OUT/result"
mcopy -n -i "$P" ::/CONFIG.SYS ::/AUTOEXEC.BAT "$OUT/result/" 2>/dev/null
mcopy -n -i "$P" '::/QMAX/*.PRO' '::/QMAX/*.BAT' "$OUT/result/" 2>/dev/null
ls "$OUT"/*.png "$OUT/result"
exit $RC
