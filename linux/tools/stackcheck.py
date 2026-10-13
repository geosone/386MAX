#!/usr/bin/env python3
"""Check that a DOS large/medium model program's stack fits into DGROUP.

OpenWatcom's DOS startup (cstrt086) puts the stack behind the end of _BSS
in DGROUP, with the size of the initial SP of the EXE header:
SP = _end + header SP.  If that passes 64 KB, SP wraps around and the stack
overwrites DGROUP from its start - the program destroys its data (and often
the DOS memory chain) without any message.

    stackcheck.py PROG.EXE PROG.EXE.MAP

Exit code 1 if _end + stack exceeds 0FFF0h; programs without a STACK segment
in DGROUP (assembler programs, other startup code) are not checked.
"""
import re
import struct
import sys


def main():
    exe, mapfile = sys.argv[1], sys.argv[2]
    with open(exe, 'rb') as f:
        hdr = f.read(0x1C)
    if hdr[:2] != b'MZ':
        return 0
    sp = struct.unpack_from('<H', hdr, 0x10)[0]
    dgroup = stack = None
    for line in open(mapfile, errors='replace'):
        m = re.match(r'DGROUP\s+[0-9a-f]{4}:[0-9a-f]{4}\s+([0-9a-f]{8})', line)
        if m:
            dgroup = int(m.group(1), 16)
        m = re.match(r'STACK\s+STACK\s+DGROUP\s+\S+\s+([0-9a-f]{8})', line)
        if m:
            stack = int(m.group(1), 16)
    if dgroup is None or stack is None:
        return 0
    end = dgroup - stack		# _end: end of _BSS, start of the stack
    top = ((end + 15) & ~15) + sp
    print('%s: DGROUP %05X + stack %04X = %05X (%d bytes free)'
          % (exe, end, sp, top, 0xFFF0 - top))
    if top > 0xFFF0:
        print('%s: DGROUP and stack exceed 64 KB' % exe, file=sys.stderr)
        return 1
    return 0


sys.exit(main())
