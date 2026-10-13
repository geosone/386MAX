#!/bin/bash
# Installation media of one language from its package (buildlang.sh):
#
#   linux/scripts/mkmedia.sh US|GR [PACKAGE_DIR]
#
# release/<LANG>/ gets
#   open386max-<ver>-<lang>-disk<n>.img   1.44 MB floppy disks: disk 1 has
#                                         the installers (SETUPDOS.EXE for
#                                         DOS, SETUP.EXE for Windows) and
#                                         386MAX.1, disk n 386MAX.n
#   open386max-<ver>-<lang>-usb.img       hard disk image (MBR, FAT16) for
#                                         USB sticks: all files in \INSTALL
#   open386max-<ver>-<lang>.iso           CD image: all files in \INSTALL
#   open386max-<ver>-<lang>.zip           all files
# The media hold no DOS (they aren't bootable): start INSTALL\SETUPDOS.EXE
# (or A:SETUPDOS) from DOS, or SETUP.EXE from Windows.
set -euo pipefail
L=${1:?language: US or GR}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REL=$ROOT/release/$L
PKG=${2:-$REL/package}
lc=$(echo "$L" | tr A-Z a-z)
ver=$(tr -d '\r\n ' < "$ROOT/VERSION")
base=$REL/open386max-$ver-$lc
mkdir -p "$REL"
rm -f "$base"-disk*.img "$base"-usb.img "$base".iso "$base".zip

# installer files (disk 1) and archive extents
inst=(SETUPDOS.EXE SETUPDOS.OVL SETUPDOS.CFG SETUPDOS.HLP QLOGO.OVL SETUP.EXE SETUP.HLP LICENSE.TXT)
ext=$(cd "$PKG" && ls 386MAX.[0-9]* | sort -t. -k2 -n)
all=("${inst[@]}" $ext)

# floppy disks
n=0
for e in $ext; do
    n=$((n + 1))
    img=$base-disk$n.img
    mformat -C -f 1440 -v "OPEN386M_$n" -i "$img" ::
    if [ $n = 1 ]; then
        (cd "$PKG" && mcopy -i "$img" "${inst[@]}" "$e" ::/)
    else
        (cd "$PKG" && mcopy -i "$img" "$e" ::/)
    fi
    echo "$img: $(mdir -i "$img" -b :: | wc -l) files, $(LC_ALL=C mdir -i "$img" :: | sed -n 's/^ *\([0-9 ]*\) bytes free/\1/p' | tr -d ' ') bytes free"
done

# USB stick image: 32 MB, one FAT16 partition from sector 63 (DOS geometry
# 16 heads x 63 sectors)
img=$base-usb.img
truncate -s 32M "$img"
echo 'start=63, type=06, bootable' | sfdisk -q "$img"
mkfs.fat -F 16 -n OPEN386MAX -h 63 --offset 63 -S 512 "$img" $(( (32 * 1024 * 1024 / 512 - 63) / 2 )) >/dev/null
mmd -i "$img@@32256" ::/INSTALL
(cd "$PKG" && mcopy -i "$img@@32256" "${all[@]}" ::/INSTALL/)
echo "$img"

# CD image
stage=$(mktemp -d)
mkdir "$stage/INSTALL"
(cd "$PKG" && cp "${all[@]}" "$stage/INSTALL/")
xorriso -as mkisofs -quiet -V "OPEN386MAX_$L" -J -r -o "$base.iso" "$stage"
rm -rf "$stage"
echo "$base.iso"

# zip
(cd "$PKG" && zip -q -X "$base.zip" "${all[@]}")
echo "$base.zip"
