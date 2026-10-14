#!/bin/bash
# Start a 386MAX Windows program in Windows 98 SE (QEMU) and take
# screenshots: boots a copy of the image made by linux/test/mkwin98.sh,
# copies build/bin to C:\MAX and starts the program through WIN.INI run=.
#
#   linux/test/win98.sh WINMAXIM.EXE [arguments]
#   SETUPPKG=1 linux/test/win98.sh SETUP.EXE        (Windows installation)
#
# Environment:
#   MM=himem    Windows' HIMEM.SYS (default)
#   MM=386max   386MAX.SYS instead of HIMEM.SYS, 386MAX.VXD in SYSTEM.INI
#   SHOTS       screenshot times in seconds (default "90")
#   KEYS        "t:key,key t:key ..." QEMU sendkey commands at time t
#   TIMEOUT     seconds until QEMU is stopped (default: last shot + 5)
#   FILES       more files to copy to C:\MAX (space separated)
#   BASEIMG     image to start from (default build/win98/win98-base.img)
#   TESTDIR     output directory (default build/win98test)
#   PREP        shell commands run before the boot ($P = mtools image spec,
#               e.g. "mdel -i \$P ::/QMAX/EXTRADOS.MAX")
#   SETUPPKG=1  copy build/package to C:\INSTALL and start its SETUP.EXE
#               (only while C:\QMAX\386MAX.SYS does not exist: MAXIMIZE
#               restarts Windows); the image stays in build/win98test
#
# Output (build/win98test/): shot-<t>.png; monitor socket mon.sock while
# running (linux/test/qemudrv.py)
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
OUT=${TESTDIR:-$ROOT/build/win98test}
BASE=${BASEIMG:-$ROOT/build/win98/win98-base.img}
MM=${MM:-himem}
PROG=${1:?program in build/bin, e.g. WINMAXIM.EXE}; shift
[ -f "$BASE" ] || { echo "run linux/test/mkwin98.sh first"; exit 1; }
[ "${SETUPPKG:-0}" = 1 ] || [ -f "$ROOT/build/bin/$PROG" ] || { echo "no build/bin/$PROG"; exit 1; }

rm -rf "$OUT"; mkdir -p "$OUT/c/MAX"
cp "$ROOT"/build/bin/* "$OUT/c/MAX/"
[ -n "${FILES:-}" ] && cp ${FILES} "$OUT/c/MAX/"
# the profile of MM=386max (WINMAXIM wants a PRO= in the DEVICE line)
[ -f "$OUT/c/MAX/386MAX.PRO" ] || printf '; 386MAX profile\r\n' > "$OUT/c/MAX/386MAX.PRO"
cp --sparse=always "$BASE" "$OUT/test.img"
P="$OUT/test.img@@32256"
mcopy -o -s -i "$P" "$OUT"/c/MAX ::/

# program start through WIN.INI [windows] run= (a list of programs: with
# arguments through a batch file)
RUN="C:\\MAX\\$PROG"
if [ $# -gt 0 ]; then
    printf '@ECHO OFF\r\nC:\\MAX\\%s %s\r\n' "$PROG" "$*" > "$OUT/runprog.bat"
    mcopy -o -i "$P" "$OUT/runprog.bat" ::/MAX/RUNPROG.BAT
    RUN="C:\\MAX\\RUNPROG.BAT"
fi
if [ "${SETUPPKG:-0}" = 1 ]; then
    mmd -i "$P" ::/INSTALL 2>/dev/null
    for f in "$ROOT"/build/package/*; do [ -f "$f" ] && mcopy -o -i "$P" "$f" ::/INSTALL/; done
    printf '@ECHO OFF\r\nIF NOT EXIST C:\\QMAX\\386MAX.SYS C:\\INSTALL\\SETUP.EXE %s\r\n' "$*" > "$OUT/runsetup.bat"
    mcopy -o -i "$P" "$OUT/runsetup.bat" ::/MAX/RUNSETUP.BAT
    RUN="C:\\MAX\\RUNSETUP.BAT"
fi
mcopy -o -i "$P" ::/WINDOWS/WIN.INI "$OUT/win.ini"
sed -i "s#^run=.*#run=${RUN//\\/\\\\}\r#" "$OUT/win.ini"
mcopy -o -i "$P" "$OUT/win.ini" ::/WINDOWS/WIN.INI

[ -n "${PREP:-}" ] && eval "$PREP"

if [ "$MM" = 386max ]; then
    mcopy -o -i "$P" ::/CONFIG.SYS "$OUT/config.sys"
    sed -i 's#^DEVICE=C:\\WINDOWS\\HIMEM.SYS#DEVICE=C:\\MAX\\386MAX.SYS PRO=C:\\MAX\\386MAX.PRO#I' "$OUT/config.sys"
    mcopy -o -i "$P" "$OUT/config.sys" ::/CONFIG.SYS
    mcopy -o -i "$P" ::/WINDOWS/SYSTEM.INI "$OUT/system.ini"
    sed -i 's/^\[386Enh\]\r$/[386Enh]\r\ndevice=C:\\MAX\\386MAX.VXD\r/' "$OUT/system.ini"
    mcopy -o -i "$P" "$OUT/system.ini" ::/WINDOWS/SYSTEM.INI
fi

SHOTS=${SHOTS:-90}
LAST=$(echo $SHOTS | tr ' ' '\n' | sort -n | tail -1)
T=${TIMEOUT:-$((LAST + 5))}
{
    # events "time command", sorted by time
    { for s in $SHOTS; do echo "$s screendump $OUT/shot-$s.ppm"; done
      for e in ${KEYS:-}; do t=${e%%:*}; for k in $(echo "${e#*:}" | tr ',' ' '); do echo "$t sendkey $k"; done; done
      echo "$T quit"; } | sort -s -n -k1,1 | {
        now=0
        while read -r t cmd; do
            [ "$t" -gt "$now" ] && sleep $((t - now)) && now=$t
            echo "$cmd"; sleep 0.3
        done; }
} | qemu-system-i386 -machine pc ${ACCEL:--accel kvm} -cpu pentium3 -m 128 -display none -vga std -monitor stdio \
    -monitor unix:"$OUT/mon.sock",server,nowait \
    -drive if=none,id=hd,format=raw,file="$OUT/test.img" \
    -device ide-hd,drive=hd,bus=ide.0,lcyls=520,lheads=64,lsecs=63 \
    -boot c -nic none -rtc base=localtime > "$OUT/monitor.log" 2>&1
for f in "$OUT"/*.ppm; do [ -f "$f" ] && magick "$f" "${f%.ppm}.png" && rm -f "$f"; done
ls "$OUT"/shot-*.png
