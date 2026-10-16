#!/bin/bash
# Install Open 386MAX from its floppy disks in QEMU: DOS boots from A:,
# disk 1 is in B:, C: is an empty FAT16 disk; AUTOEXEC runs B:SETUPDOS.
#
#   linux/test/floppyinst.sh US|GR
#
# Environment:
#   KEYS     QEMU monitor input after START seconds (space separated):
#            sendkey names, "shot" (screen shot), "wait<n>" (n seconds),
#            "disk<n>" (put disk n into B:), "mon:<cmd>" (monitor command,
#            + for blanks)
#   START    seconds before KEYS (default 15)
#   DISKS    floppy images (default release/<LANG>/open386max-<VERSION>-<lang>-disk*.img)
#   SRC=usb  install from the USB image instead (D:\INSTALL, both extents in
#            one directory: no disk change)
# Output (build/test-floppyinst/): shot<n>.png, final.png, installed/ (the
# files of C:\QMAX)
set -uo pipefail
L=${1:?language: US or GR}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=$ROOT/build/test-floppyinst
DOS=${DOS_DIR:-$HOME/Iso/Dos}
BOOTIMG=${BOOTIMG:-$DOS/dos71de/Dos7.1_System_deutsch.IMG}
lc=$(echo "$L" | tr A-Z a-z)
ver=$(tr -d '\r\n ' < "$ROOT/VERSION")
read -r -a disks <<< "${DISKS:-$(ls "$ROOT"/release/$L/open386max-$ver-$lc-disk*.img | sort -V | tr '\n' ' ')}"
rm -rf "$OUT"; mkdir -p "$OUT"
cp "$BOOTIMG" "$OUT/boot.img"; chmod u+w "$OUT/boot.img"
i=0; for d in "${disks[@]}"; do i=$((i + 1)); cp "$d" "$OUT/disk$i.img"; done

# C: 64 MB FAT16 from sector 63
truncate -s 64M "$OUT/hd.img"
echo 'start=63, type=06, bootable' | sfdisk -q "$OUT/hd.img"
mkfs.fat -F 16 -n TESTC -h 63 --offset 63 "$OUT/hd.img" $(( (64 * 1024 * 1024 / 512 - 63) / 2 )) >/dev/null

printf 'FILES=40\r\nBUFFERS=20\r\nSHELL=A:\\COMMAND.COM A:\\ /P\r\n' > "$OUT/CONFIG.SYS"
if [ "${SRC:-}" = usb ]; then
    cp "$ROOT/release/$L/open386max-$ver-$lc-usb.img" "$OUT/usb.img"
    printf '@ECHO OFF\r\nPATH A:\\\r\nD:\r\nCD \\INSTALL\r\nSETUPDOS\r\n' > "$OUT/AUTOEXEC.BAT"
    USBDRIVE=(-drive if=ide,index=1,format=raw,file="$OUT/usb.img")
else
    printf '@ECHO OFF\r\nPATH A:\\\r\nB:\r\nSETUPDOS\r\n' > "$OUT/AUTOEXEC.BAT"
    USBDRIVE=()
fi
mcopy -o -i "$OUT/boot.img" "$OUT/CONFIG.SYS" "$OUT/AUTOEXEC.BAT" ::/ || exit 1

n=0
{ sleep "${START:-15}"
  for k in ${KEYS:-}; do
    case $k in
    shot) n=$((n + 1)); echo "screendump $OUT/shot$n.ppm"; sleep 1 ;;
    wait*) sleep "${k#wait}" ;;
    disk*) echo "change floppy1 $OUT/${k}.img raw"; sleep 1 ;;
    mon:*) echo "${k#mon:}" | tr + ' '; sleep 1 ;;
    *) echo "sendkey $k"; sleep "${DELAY:-1}" ;;
    esac
  done
  sleep 2; echo "screendump $OUT/final.ppm"; sleep 1; echo quit; } |
qemu-system-i386 -machine pc -m 32 -display none -vga std -monitor stdio \
    -drive if=floppy,index=0,format=raw,file="$OUT/boot.img" \
    -drive if=floppy,index=1,format=raw,file="$OUT/disk1.img" \
    -drive if=ide,index=0,format=raw,file="$OUT/hd.img" "${USBDRIVE[@]}" -boot a \
    -nic none ${QEMU_EXTRA:-} >/dev/null 2>&1
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
mkdir -p "$OUT/installed"
mcopy -n -i "$OUT/hd.img@@32256" '::/QMAX/*' "$OUT/installed/" 2>/dev/null
echo "installed: $(ls "$OUT/installed" | wc -l) files"
