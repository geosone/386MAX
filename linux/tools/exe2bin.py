#!/usr/bin/env python3
"""Convert an MZ executable into a binary image like DOS EXE2BIN did:
the load image without the header.  Only programs without segment
relocations can be converted (EXE2BIN would ask for a base segment).

    exe2bin.py IN.EXE OUT.BIN
"""
import struct
import sys

d = open(sys.argv[1], 'rb').read()
last, pages, nrel, hdr = struct.unpack_from('<4H', d, 2)
size = pages * 512 - (512 - last if last else 0)
if nrel:
    sys.exit(f'{sys.argv[1]}: {nrel} segment relocations, cannot convert to binary')
open(sys.argv[2], 'wb').write(d[hdr * 16:size])
