#!/bin/bash
# Development package: release/open386max-<ver>-dev-<commit>.zip with
#   BIN\     the programs as built (build/bin), not the installer archive
#   TESTS\   the regression tests (build/TESTS): RUNTESTS.BAT, README.TXT
#   LICENSE.TXT
# For testers: copy BIN\386MAX.SYS etc. by hand, boot, run TESTS\RUNTESTS.BAT.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
ver=$(tr -d '\r\n ' < "$ROOT/VERSION")
rev=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo local)
git -C "$ROOT" diff --quiet HEAD 2>/dev/null || rev=$rev-mod
out=$ROOT/release/open386max-$ver-dev-$rev.zip
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/BIN" "$tmp/TESTS" "$ROOT/release"
cp "$ROOT"/build/bin/* "$tmp/BIN/"
cp "$ROOT"/build/TESTS/*.EXE "$ROOT/build/TESTS/RUNTESTS.BAT" "$ROOT/build/TESTS/README.TXT" "$tmp/TESTS/"
sed 's/$/\r/' "$ROOT/LICENSE" > "$tmp/LICENSE.TXT"
rm -f "$out"
(cd "$tmp" && zip -q -X -r "$out" BIN TESTS LICENSE.TXT)
echo "$out"
