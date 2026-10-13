#!/bin/bash
# Build a hard disk image with MS-DOS 7.1 (the user's boot disk: IO.SYS
# patched for Windows 3.x) and Windows for Workgroups 3.11 (German), set up
# unattended (SETUP /H) in QEMU.  Base image for linux/test/win311.sh.
#
#   linux/test/mkwin311.sh
#
# Output: build/win311/win311.img (128 MB, C: = FAT16), build/win311/serial.log
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/win311
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
WFW=${WFW:-$HOME/Iso/MSDOS-WfW/WfW}          # Disk1 .. Disk9
MSCAB=${MSCAB:-"$HOME/Iso/Windows 98/Windows98/WIN95/WIN95_02.CAB"}
ACCEL=${ACCEL:--accel kvm}

rm -rf "$OUT"; mkdir -p "$OUT/c" "$OUT/src"
nasm -f bin -o "$OUT/c/QEXIT.COM" "$ROOT/linux/tools/qexit.asm" || exit 1
mcopy -i "$BOOTIMG" ::IO.SYS ::MSDOS.SYS ::COMMAND.COM "$OUT/" || exit 1
(cd "$OUT" && cabextract -q -F himem.sys "$MSCAB" 2>/dev/null) && cp "$OUT/himem.sys" "$OUT/c/HIMEM.SYS"
for d in "$WFW"/Disk*; do cp "$d"/* "$OUT/src/"; done

crlf() { tr '|' '\n' | sed 's/$/\r/'; }
# unattended setup: no network, printer, accessories; leave CONFIG.SYS and
# AUTOEXEC.BAT alone (they are written as .WIN files) and return to DOS
crlf > "$OUT/src/AUTO.SHH" <<'EOF'
[sysinfo]|showsysinfo=no|[configuration]|machine = ibm_compatible|display = vga|mouse = ps2mouse|network = nonet|keyboard = t4s0enha|language = deu|kblayout = gerdll|[windir]|c:\windows|[userinfo]|"Test"|"Test"|[dontinstall]|accessories|readmes|games|screensavers|bitmaps|[options]|[printers]|[endinstall]|configfiles = save|endopt = exit
EOF
echo 'DEVICE=C:\HIMEM.SYS|FILES=40|BUFFERS=20|SHELL=C:\COMMAND.COM C:\ /P' | crlf > "$OUT/c/CONFIG.SYS"
echo '@ECHO OFF|PATH C:\|C:\WFWSRC\SETUP /H:C:\WFWSRC\AUTO.SHH|ECHO SETUPDONE > AUX|DIR C:\WINDOWS\WIN.COM > AUX|QEXIT' | crlf > "$OUT/c/AUTOEXEC.BAT"

# 128 MB disk, one FAT16 partition, DOS 7 boot record (ms-sys), IO.SYS first
truncate -s 128M "$OUT/win311.img"
echo 'start=63, type=6, bootable' | sfdisk -q "$OUT/win311.img"
mkfs.fat -F16 -h 63 -g 16/63 -n WIN311 --offset 63 "$OUT/win311.img" $(( (128*2048 - 63) / 2 )) >/dev/null
dd if="$OUT/win311.img" of="$OUT/part.img" bs=512 skip=63 status=none
ms-sys -f -6 "$OUT/part.img" >/dev/null
dd if="$OUT/part.img" of="$OUT/win311.img" bs=512 seek=63 count=1 conv=notrunc status=none
rm -f "$OUT/part.img"
ms-sys -f -9 "$OUT/win311.img" >/dev/null       # DOS MBR
P="$OUT/win311.img@@32256"
mcopy -i "$P" "$OUT/IO.SYS" ::/
mcopy -i "$P" "$OUT/MSDOS.SYS" ::/
mcopy -i "$P" "$OUT/COMMAND.COM" ::/
mcopy -i "$P" "$OUT"/c/* ::/
mmd -i "$P" ::/WFWSRC
mcopy -i "$P" "$OUT"/src/* ::/WFWSRC/

{ sleep "${TIMEOUT:-900}"; echo "screendump $OUT/screen.ppm"; sleep 1; echo quit; } |
qemu-system-i386 -machine pc $ACCEL -m 32 -display none -vga std -monitor stdio \
    -drive if=ide,index=0,format=raw,file="$OUT/win311.img" -boot c -nic none \
    -serial file:"$OUT/serial.log" \
    -device isa-debug-exit,iobase=0x501,iosize=0x02 >/dev/null 2>&1
[ -f "$OUT/screen.ppm" ] && command -v magick >/dev/null && magick "$OUT/screen.ppm" "$OUT/screen.png"
tr -d '\r' < "$OUT/serial.log"
tr -d '\r' < "$OUT/serial.log" | grep -q 'WIN.*COM' && echo "=== $OUT/win311.img ready"
