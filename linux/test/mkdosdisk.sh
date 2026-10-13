#!/bin/bash
# Make a bootable 128 MB hard disk image with SvarDOS, EDR-DOS or MS-DOS 6.22
# for the tests (linux/test/maxdos.sh BASEIMG=...): FAT16 partition with a DOS MBR
# (ms-sys), the system transferred by the system's own SYS C: in QEMU from
# its boot floppy.
#
#   linux/test/mkdosdisk.sh svardos|edrdos|msdos622|freedos
#
# Environment:
#   DOS_DIR  directory with the system floppies (default ~/Iso/Dos):
#              svardos/svdos-1.44M-disk-1.img
#              edr-dos/edrdos.img
#              msdos622/MS-DOS-6.22-Disk1.img, -Disk2.img (the drivers are
#              expanded into C:\DOS)
#              freedos/FD14LITE.img (FreeDOS 1.4 Lite USB; \FREEDOS\BIN is
#              copied)
#
# Output: build/dosdisk/<os>.img
set -uo pipefail
OS=${1:?svardos, edrdos, msdos622 or freedos}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
DOS=${DOS_DIR:-$HOME/Iso/Dos}
OUT=$ROOT/build/dosdisk
case $OS in
svardos) FLOPPY=$DOS/svardos/svdos-1.44M-disk-1.img; AUTO=AUTOEXEC.BAT
	 EXTRA="MEM.EXE MODE.COM MORE.COM SVED.COM FDISK.EXE FORMAT.EXE" ;;
edrdos)  FLOPPY=$DOS/edr-dos/edrdos.img; AUTO=DAUTO.BAT
	 EXTRA="COUNTRY.SYS" ;;
msdos622) M=$DOS/msdos622
	 FLOPPY=$M/MS-DOS-6.22-Disk1.img; FLOPPYB=$M/MS-DOS-6.22-Disk2.img; AUTO=AUTOEXEC.BAT
	 EXTRA="MSCDEX.EXE KEYB.COM KEYBOARD.SYS COUNTRY.SYS EDIT.COM QBASIC.EXE"
	 EXPANDA="EGA.CP_ MEM.EX_ EMM386.EX_ XCOPY.EX_"
	 EXPANDB="HIMEM.SY_ ANSI.SY_ DISPLAY.SY_ SMARTDRV.EX_ DOSKEY.CO_ MODE.CO_ SETVER.EX_ SHARE.EX_ RAMDRIVE.SY_ CHOICE.COM MORE.COM" ;;
freedos) FLOPPY=$DOS/freedos/FD14LITE.img; AUTO=FDAUTO.BAT; BOOTHD=1 ;;
*) echo "unknown system $OS" >&2; exit 1 ;;
esac
[ -f "$FLOPPY" ] || { echo "no $FLOPPY"; exit 1; }
declare -A EXT=([EGA.CP_]=I [MEM.EX_]=E [EMM386.EX_]=E [XCOPY.EX_]=E [HIMEM.SY_]=S
    [ANSI.SY_]=S [DISPLAY.SY_]=S [SMARTDRV.EX_]=E [DOSKEY.CO_]=M [MODE.CO_]=M
    [SETVER.EX_]=E [SHARE.EX_]=E [RAMDRIVE.SY_]=S)
mkdir -p "$OUT"; W=$OUT/$OS.work; rm -rf "$W"; mkdir -p "$W"
IMG=$OUT/$OS.img
crlf() { tr '|' '\n' | sed 's/$/\r/'; }

# empty disk: one FAT16 partition, DOS MBR
rm -f "$IMG"; truncate -s 128M "$IMG"
echo 'start=63, type=6, bootable' | sfdisk -q "$IMG"
mkfs.fat -F16 -h 63 -g 16/63 -n "$(echo $OS | tr a-z A-Z)" --offset 63 "$IMG" $(( (128*2048 - 63) / 2 )) >/dev/null
ms-sys -f -9 "$IMG" >/dev/null

if [ "${BOOTHD:-0}" = 1 ]; then
    # FreeDOS USB image as C:, the new disk as D:
    cp "$FLOPPY" "$W/boot.img"; chmod u+w "$W/boot.img"
    BP="$W/boot.img@@32256"
    nasm -f bin -o "$W/QEXIT.COM" "$ROOT/linux/tools/qexit.asm" || exit 1
    echo '@ECHO OFF|SET PATH=C:\FREEDOS\BIN|SYS D:|MD D:\FREEDOS|MD D:\FREEDOS\BIN|MD D:\FREEDOS\NLS|XCOPY C:\FREEDOS\BIN\*.* D:\FREEDOS\BIN /Y|XCOPY C:\FREEDOS\NLS\*.* D:\FREEDOS\NLS /Y|COPY C:\QEXIT.COM D:\|QEXIT' | crlf > "$W/FDAUTO.BAT"
    echo 'FILES=20|SHELL=C:\COMMAND.COM C:\ /E:1024 /P=C:\FDAUTO.BAT' | crlf > "$W/FDCONFIG.SYS"
    mcopy -o -i "$BP" "$W/FDAUTO.BAT" "$W/FDCONFIG.SYS" "$W/QEXIT.COM" ::/ || exit 1
    timeout 180 qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m 32 -display none -vga std \
        -drive if=ide,index=0,format=raw,file="$W/boot.img" \
        -drive if=ide,index=1,format=raw,file="$IMG" -boot c -nic none \
        -device isa-debug-exit,iobase=0x501,iosize=0x02 -monitor none >/dev/null 2>&1
else
# boot floppy: transfer the system, copy some tools, end QEMU
cp "$FLOPPY" "$W/boot.img"; chmod u+w "$W/boot.img"
nasm -f bin -o "$W/QEXIT.COM" "$ROOT/linux/tools/qexit.asm" || exit 1
{ echo '@ECHO OFF|SYS C:'
  for f in $EXTRA; do echo "COPY A:\\$f C:\\"; done
  [ -n "${EXPANDA:-}${EXPANDB:-}" ] && echo 'MD C:\DOS'
  for f in ${EXPANDA:-}; do echo "A:\\EXPAND A:\\$f C:\\DOS\\${f%_}${EXT[$f]:-}"; done
  for f in ${EXPANDB:-}; do echo "A:\\EXPAND B:\\$f C:\\DOS\\${f%_}${EXT[$f]:-}"; done
  echo 'COPY A:\QEXIT.COM C:\|QEXIT'; } | crlf > "$W/$AUTO"
# MS-DOS 6.22 disk 1 starts SETUP from its CONFIG.SYS/AUTOEXEC.BAT
printf 'FILES=20\r\n' > "$W/CONFIG.SYS"
mcopy -o -i "$W/boot.img" "$W/$AUTO" "$W/QEXIT.COM" ::/ || exit 1
[ "$OS" = msdos622 ] && mcopy -o -i "$W/boot.img" "$W/CONFIG.SYS" ::/
[ -n "${FLOPPYB:-}" ] && { cp "$FLOPPYB" "$W/b.img"; chmod u+w "$W/b.img"; }
timeout 120 qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -m 32 -display none -vga std \
    -drive if=floppy,index=0,format=raw,file="$W/boot.img" \
    ${FLOPPYB:+-drive if=floppy,index=1,format=raw,file="$W/b.img"} \
    -drive if=ide,index=0,format=raw,file="$IMG" -boot a -nic none \
    -device isa-debug-exit,iobase=0x501,iosize=0x02 -monitor none >/dev/null 2>&1

fi

P="$IMG@@32256"
mdir -i "$P" ::/ || exit 1
# minimal startup files (replaced by the tests)
echo 'FILES=40|BUFFERS=20|SHELL=C:\COMMAND.COM C:\ /E:1024 /P' | crlf > "$W/CONFIG.SYS"
echo '@ECHO OFF|PATH C:\' | crlf > "$W/AUTOEXEC.BAT"
mcopy -o -i "$P" "$W/CONFIG.SYS" "$W/AUTOEXEC.BAT" ::/
rm -rf "$W"
echo "$IMG"
