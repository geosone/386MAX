#!/bin/bash
# Build Open 386MAX for one language (US or GR) in its own tree:
#
#   linux/scripts/buildlang.sh US|GR
#
# The sources are mirrored into release/<LANG>/tree (without build/ and
# release/) and built there with MAXLANG=<LANG>; the MFC library of
# build/mfc is shared.  The installation package goes to
# release/<LANG>/package (linux/tools/mkpkg.py), the media are made by
# linux/scripts/mkmedia.sh.
set -euo pipefail
L=${1:?language: US or GR}
case $L in US|GR) ;; *) echo "unknown language $L" >&2; exit 1;; esac
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
REL=$ROOT/release/$L
mkdir -p "$REL/tree"
rsync -a --delete --exclude /build/ --exclude /release/ --exclude /.git/ "$ROOT/" "$REL/tree/"
# always a clean build: the makefiles know no header dependencies
rm -rf "$REL/tree/build"
mkdir -p "$REL/tree/build"
[ -e "$ROOT/build/mfc" ] && ln -sfn "$ROOT/build/mfc" "$REL/tree/build/mfc"
make -C "$REL/tree" MAXLANG=$L
python3 "$ROOT/linux/tools/mkpkg.py" "$REL/package" "$REL/tree"
