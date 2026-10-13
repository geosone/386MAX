#!/usr/bin/env python3
"""Compare two DOS MZ executables (e.g. 386MAX.SYS): header fields, the set
of relocations and the load image.

    mzcmp.py OLD NEW
"""
import struct
import sys


def load(path):
    d = open(path, 'rb').read()
    f = struct.unpack_from('<14H', d, 0)
    sig, last, pages, nrel, hdr, minalloc, maxalloc, ss, sp, csum, ip, cs, relofs, ovl = f
    size = pages * 512 - (512 - last if last else 0)
    image = d[hdr * 16:size]
    rel = set()
    for i in range(nrel):
        o, s = struct.unpack_from('<HH', d, relofs + 4 * i)
        rel.add(s * 16 + o)
    return dict(hdr=hdr, nrel=nrel, minalloc=minalloc, maxalloc=maxalloc,
                ss=ss, sp=sp, ip=ip, cs=cs, image=image, rel=rel)


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    for k in ('hdr', 'nrel', 'minalloc', 'maxalloc', 'ss', 'sp', 'cs', 'ip'):
        mark = '' if a[k] == b[k] else '   <-- differs'
        print(f'{k:9} {a[k]:#7x} {b[k]:#7x}{mark}')
    print(f'image     {len(a["image"]):#7x} {len(b["image"]):#7x}')
    print(f'relocs only old {len(a["rel"] - b["rel"])}, only new {len(b["rel"] - a["rel"])}')
    n = min(len(a['image']), len(b['image']))
    diff = [i for i in range(n) if a['image'][i] != b['image'][i]]
    print(f'image bytes differing: {len(diff)}')
    shown = 0
    i = 0
    while i < len(diff) and shown < 15:
        s = diff[i]
        j = i
        while j + 1 < len(diff) and diff[j + 1] - diff[j] < 8:
            j += 1
        e = diff[j]
        print(f'  {s:#07x}-{e:#07x}: {a["image"][s:e + 1][:12].hex(" ")} | {b["image"][s:e + 1][:12].hex(" ")}')
        shown += 1
        i = j + 1


main()
