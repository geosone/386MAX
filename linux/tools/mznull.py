#!/usr/bin/env python3
"""Clear the null pointer area at DGROUP:0000 of a DOS program linked with
the OpenWatcom run time, like Microsoft C has it.

    mznull.py PROGRAM.EXE PROGRAM.MAP

OpenWatcom's start up code fills its _NULL segment (DS:0000-001F) with
01h bytes; Microsoft C's has zeros there, and the Qualitas sources rely
on *(char *)NULL == 0 (e.g. STRIPMGR ntharg(NULL, n) ends a loop by
returning NULL; OpenWatcom also drops the later NULL test because the
pointer was already used).  The _NULL segment is located in the map file.
The run time's exit check ("*** NULL assignment detected", __exit_ in
cstart: repe scasw over __nullarea against 0101h) is changed to compare
with 0000h, so it still reports writes through NULL like Microsoft C.
"""
import re
import struct
import sys

exe, mapf = sys.argv[1], sys.argv[2]
m = None
for line in open(mapf, encoding='latin-1'):
    m = re.match(r'\s*_NULL\s+BEGDATA\s+DGROUP\s+([0-9a-fA-F]+):([0-9a-fA-F]+)\s+([0-9a-fA-F]+)', line)
    if m:
        break
if not m:
    sys.exit(0)                 # no OpenWatcom C run time
seg, off, size = (int(x, 16) for x in m.groups())
with open(exe, 'r+b') as f:
    hdr = f.read(28)
    if hdr[:2] != b'MZ':
        sys.exit('%s: no MZ header' % exe)
    pos = struct.unpack('<H', hdr[8:10])[0] * 16 + seg * 16 + off
    f.seek(pos)
    old = f.read(size)
    if old.strip(b'\x01') and old.strip(b'\x00'):
        sys.exit('%s: unexpected _NULL contents %r' % (exe, old))
    f.seek(pos)
    f.write(bytes(size))
    # the exit check: mov cx,10h / mov ax,0101h / repe scasw
    f.seek(0)
    data = f.read()
    pat = bytes.fromhex('B91000B80101F3AF')
    n = data.count(pat)
    if n != 1:
        sys.exit('%s: NULL check found %d times' % (exe, n))
    f.seek(data.index(pat) + 4)
    f.write(b'\x00\x00')
