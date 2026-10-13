#!/usr/bin/env python3
"""Repair a 16-bit (Microsoft format) .res file written by OpenWatcom's wrc.

    resfix.py FILE.RES

wrc -zm writes some resources longer than their header says (an RCDATA
string gets its own terminator and padding to a 4-byte boundary).  In the
16-bit format the next header follows the data directly, so wlink would
read those zero bytes as the next header (QPIFEDIT.EXE became 33 MB).
A header never starts with a zero byte (type FFh+number or a name), so the
zeros after each resource's declared length are removed.
"""
import struct
import sys


def item(d, p):
    if d[p] == 0xFF:
        return p + 3
    return d.index(b'\0', p) + 1


def main():
    path = sys.argv[1]
    d = open(path, 'rb').read()
    out = bytearray()
    p = 0
    while p < len(d):
        while p < len(d) and d[p] == 0:
            p += 1                  # wrc's extra terminator / padding
        if p >= len(d):
            break
        q = item(d, item(d, p))
        size = struct.unpack('<I', d[q + 2:q + 6])[0]
        end = q + 6 + size
        if end > len(d):
            sys.exit('%s: resource at %x runs past the end' % (path, p))
        out += d[p:end]
        p = end
    open(path, 'wb').write(out)


main()
