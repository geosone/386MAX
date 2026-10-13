#!/usr/bin/env python3
"""List the fixups of one segment of two OMF objects side by side
(frame, target, displacement), marking the ones that differ.

    fixcmp.py A.OBJ B.OBJ SEGMENT
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from omf import Omf  # noqa: E402


def seg(path, name):
    for s in Omf(path).segs:
        if s['name'] == name:
            return s
    sys.exit(f'{path}: no segment {name}')


a, b = seg(sys.argv[1], sys.argv[3]), seg(sys.argv[2], sys.argv[3])
na, nb = a.get('fixn', {}), b.get('fixn', {})
for pos in sorted(set(na) | set(nb)):
    x, y = na.get(pos), nb.get(pos)
    print(f'{pos:#06x} {str(x):45} {str(y):45}{"" if x == y else "  <--"}')
