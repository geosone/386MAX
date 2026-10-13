#!/usr/bin/env python3
"""The sources were written for DOS: #include "commfunc.h" means
COMMFUNC.H.  Create a directory with symbolic links that maps each
include name as written in the sources (and the headers they include) to
the file found case-insensitively in the include directories.

    mkincdir.py OUTDIR INCDIR... -- SOURCE...
"""
import os
import re
import sys

INC = re.compile(rb'^\s*#\s*include\s*[<"]([^>"]+)[>"]', re.M)


def main():
    args = sys.argv[1:]
    out = args[0]
    sep = args.index('--')
    dirs, srcs = args[1:sep], args[sep + 1:]
    index = {}                      # lower-case name -> path
    for d in dirs:
        if os.path.isdir(d):
            for f in os.listdir(d):
                index.setdefault(f.lower(), os.path.join(d, f))
    os.makedirs(out, exist_ok=True)
    todo, seen = list(srcs), set()
    while todo:
        src = todo.pop()
        if src in seen or not os.path.isfile(src):
            continue
        seen.add(src)
        for raw in INC.findall(open(src, 'rb').read()):
            raw = raw.decode('latin-1')
            if '\\' in raw:
                # <sys\types.h>: a link with exactly this name (a backslash
                # is a normal character in Linux file names)
                path = raw.replace('\\', '/')
                target = next((os.path.join(d, path) for d in dirs
                               if os.path.isfile(os.path.join(d, path))), None)
                link = os.path.join(out, raw)
                if target and not os.path.lexists(link):
                    os.symlink(os.path.abspath(target), link)
                continue
            base = os.path.basename(raw)
            target = index.get(base.lower())
            if target is None:
                continue
            todo.append(target)
            link = os.path.join(out, base)
            data = open(target, 'rb').read()
            if b'\x1a' in data:
                for name in {base, os.path.basename(target)}:
                    p = os.path.join(out, name)
                    if not os.path.lexists(p):
                        open(p, 'wb').write(data.replace(b'\x1a', b''))
            elif os.path.basename(target) != base and not os.path.lexists(link):
                os.symlink(os.path.abspath(target), link)


main()
