#!/bin/bash
# Build a hard disk image with Windows 98 SE (German), set up unattended in
# QEMU from the user's CD tree with its MSBATCH.INF (product key, options;
# nothing of it is stored in the repository).  Base image for 386MAX tests
# under Windows 98 (VxD, Windows programs).
#
#   linux/test/mkwin98.sh
#
# Steps: 1. setup until its first restart (after copying the files; QEMU
# runs with -no-reboot); 2. patcher9x on the installed C:\WINDOWS for
# current CPUs (TLB bug: "could not combine the .VxD files"), the changed
# files are written back into the image; 3. rest of the setup.
#
# Environment:
#   WIN98_DIR  the CD's WIN98 directory with the CABs, SETUP.EXE and
#              MSBATCH.INF (default ~/Iso/Windows 98/Windows98/win98)
#   PATCHER9X  patcher9x Linux binary (default ~/Iso/Windows 98/patcher9x)
#   BOOTIMG    MS-DOS 7.1 boot floppy image (IO.SYS, MSDOS.SYS, COMMAND.COM)
#   TIMEOUT    seconds per QEMU run (default 3000)
#   SHOTEVERY  screenshot interval in seconds (default 60)
#   RESUME=1   boot the existing build/win98/win98.img again (go on with an
#              interrupted setup; keys through mon.sock)
#
# Output: build/win98/win98.img (1 GB, C: = FAT16), build/win98/shot-<t>.png;
# QEMU monitor socket build/win98/mon.sock (linux/test/qemudrv.py)
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/win98
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
SRC=${WIN98_DIR:-$HOME/Iso/Windows 98/Windows98/win98}
PATCHER=${PATCHER9X:-$HOME/Iso/Windows 98/patcher9x}
ACCEL=${ACCEL:--accel kvm}
T=${TIMEOUT:-3000}
EVERY=${SHOTEVERY:-60}
[ -f "$SRC/SETUP.EXE" ] || [ -f "$SRC/setup.exe" ] || { echo "no Windows 98 setup in $SRC"; exit 1; }
[ -f "$SRC/msbatch.inf" ] || [ -f "$SRC/MSBATCH.INF" ] || { echo "no MSBATCH.INF in $SRC"; exit 1; }
[ -x "$PATCHER" ] || { echo "no patcher9x ($PATCHER)"; exit 1; }

IMG=$OUT/win98.img
if [ "${RESUME:-0}" = 1 ]; then
    [ -f "$IMG" ] || { echo "no $IMG"; exit 1; }
    STAGE=resume
else
    STAGE=new
fi
if [ $STAGE = new ]; then
rm -rf "$OUT"; mkdir -p "$OUT/c"
mcopy -i "$BOOTIMG" ::IO.SYS ::MSDOS.SYS ::COMMAND.COM "$OUT/" || exit 1
HIMEM=$(ls "$SRC"/himem.sys "$SRC"/HIMEM.SYS 2>/dev/null | head -1)

crlf() { tr '|' '\n' | sed 's/$/\r/'; }
echo 'DEVICE=C:\HIMEM.SYS|FILES=40|BUFFERS=30|SHELL=C:\COMMAND.COM C:\ /P' | crlf > "$OUT/c/CONFIG.SYS"
# /IS no ScanDisk  /IQ no cross-link check  /IE no boot disk  /IM no memory
# check  /ID no disk space check  /NM no CPU check  /IV no billboards;
# only once (setup restarts the computer with this AUTOEXEC.BAT)
echo '@ECHO OFF|PATH C:\|IF EXIST C:\WINDOWS\WIN.COM GOTO END|C:\WIN98\SETUP.EXE C:\WIN98\MSBATCH.INF /IS /IQ /IE /IM /ID /NM /IV|:END' | crlf > "$OUT/c/AUTOEXEC.BAT"
cp "$HIMEM" "$OUT/c/HIMEM.SYS"

# 1 GB disk, one FAT16 partition (type 6, CHS: the BIOS geometry is set to
# 520/64/63 below, QEMU's default 16 heads would reach only 504 MB), DOS 7
# boot record (ms-sys), IO.SYS first
truncate -s 1G "$IMG"
echo 'start=63, type=6, bootable' | sfdisk -q "$IMG"
mkfs.fat -F16 -h 63 -g 64/63 -n WIN98 --offset 63 "$IMG" $(( (1024*2048 - 63) / 2 )) >/dev/null
dd if="$IMG" of="$OUT/part.img" bs=512 skip=63 count=8 status=none
ms-sys -f -6 "$OUT/part.img" >/dev/null
dd if="$OUT/part.img" of="$IMG" bs=512 seek=63 count=1 conv=notrunc status=none
rm -f "$OUT/part.img"
ms-sys -f -9 "$IMG" >/dev/null       # DOS MBR
P="$IMG@@32256"
mcopy -i "$P" "$OUT/IO.SYS" ::/
mcopy -i "$P" "$OUT/MSDOS.SYS" ::/
mcopy -i "$P" "$OUT/COMMAND.COM" ::/
mcopy -i "$P" "$OUT"/c/* ::/
mmd -i "$P" ::/WIN98
# names differing only in case (apix.vxd, APIX.VXD): overwrite
mcopy -s -o -D oO -i "$P" "$SRC"/* ::/WIN98/ || exit 1
# the copy of MSBATCH.INF on the disk gets a user name (setup asks for it
# otherwise); the original in the CD tree is not changed
B=$(ls "$SRC"/msbatch.inf "$SRC"/MSBATCH.INF 2>/dev/null | head -1)
tr -d '\r' < "$B" | sed '/^\[NameAndOrg\]/a Name="Test"\nOrg="Open 386MAX"' | sed 's/$/\r/' > "$OUT/MSBATCH.INF"
mcopy -o -D oO -i "$P" "$OUT/MSBATCH.INF" ::/WIN98/MSBATCH.INF

fi
P="$IMG@@32256"
TOT=$(ls "$OUT"/shot-*.p?m 2>/dev/null | sed 's/.*shot-\([0-9]*\).*/\1/' | sort -n | tail -1); TOT=${TOT:-0}
qemu() {    # qemu <seconds> [options]: screenshots every $EVERY seconds
    local lim=$1 t=0 start=$TOT; shift
    rm -f "$OUT/qemu.run"
    {
        sleep 3
        while [ $t -lt "$lim" ] && [ -e "$OUT/qemu.run" ]; do
            sleep "$EVERY"; t=$((t + EVERY)); echo "screendump $OUT/shot-$((start + t)).ppm"
        done
        sleep 1; echo quit
    } | { touch "$OUT/qemu.run"
          qemu-system-i386 -machine pc $ACCEL -cpu pentium3 -m 128 -display none -vga std -monitor stdio \
            -monitor unix:"$OUT/mon.sock",server,nowait \
            -drive if=none,id=hd,format=raw,file="$IMG" \
        -device ide-hd,drive=hd,bus=ide.0,lcyls=520,lheads=64,lsecs=63 \
        -boot c -nic none -rtc base=localtime \
            -device isa-debug-exit,iobase=0x501,iosize=0x02 "$@" >/dev/null 2>&1
          rm -f "$OUT/qemu.run"; cat >/dev/null; }
    TOT=$((start + lim))
}

if [ $STAGE = new ]; then
# 1. setup until its first restart: QEMU ends there (-no-reboot)
qemu "$T" -no-reboot
mdir -b -i "$P" ::/WINDOWS/WIN.COM >/dev/null 2>&1 || { echo "setup did not copy Windows (see shots)"; exit 1; }

# 2. patcher9x on the installed C:\WINDOWS, changed files back into the image
rm -rf "$OUT/windows"; mkdir -p "$OUT/windows"
mcopy -s -n -m -i "$P" ::/WINDOWS/* "$OUT/windows/" || exit 1
touch "$OUT/patch.stamp"; sleep 1
SYSD=$(ls -d "$OUT"/windows/[Ss][Yy][Ss][Tt][Ee][Mm] | head -1)
"$PATCHER" -auto -no-backup "$SYSD" > "$OUT/patcher9x.log" 2>&1 || { cat "$OUT/patcher9x.log"; exit 1; }
(cd "$OUT/windows" && find . -type f -newer "$OUT/patch.stamp") | while read -r f; do
    f=${f#./}; echo "patched: WINDOWS/$f"
    mcopy -o -D oO -i "$P" "$OUT/windows/$f" "::/WINDOWS/$f" || exit 1
done

fi

# 3. rest of the setup (hardware detection, first start of Windows)
qemu "$T"
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
ls "$OUT"/shot-*.png | sort -t- -k2 -n | tail -1
