#!/usr/bin/env python3
"""Set the maximum allocation (paragraphs) in the MZ header of a DOS
program, like Microsoft LINK /CPARMAXALLOC (JWlink has no such option).

    mzmaxalloc.py PROGRAM.EXE PARAGRAPHS
"""
import struct
import sys

with open(sys.argv[1], 'r+b') as f:
    if f.read(2) not in (b'MZ', b'ZM'):
        sys.exit('%s: no MZ header' % sys.argv[1])
    f.seek(12)
    f.write(struct.pack('<H', int(sys.argv[2], 0)))
