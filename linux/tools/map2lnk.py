#!/usr/bin/env python3
"""Write a JWlink ORDER directive that places the segments the way
Microsoft LINK did, taken from the segment table of a LINK .MAP file.

    map2lnk.py MAPFILE > ORDER.LNK
"""
import re
import sys


def main():
    order = []          # [(class, [segments])]
    for line in open(sys.argv[1], encoding='latin-1'):
        m = re.match(r'\s*[0-9A-F]{5}H\s+[0-9A-F]{5}H\s+[0-9A-F]{5}H\s+(\S+)\s+(\S+)\s*$', line)
        if not m:
            if order and line.strip().startswith('Origin'):
                break
            continue
        seg, cls = m.group(1), m.group(2)
        if not order or order[-1][0] != cls:
            order.append((cls, []))
        order[-1][1].append(seg)
    print(f'# segment order of Microsoft LINK ({sys.argv[1].split("/")[-1]})')
    print('order')
    for cls, segs in order:
        print(f'  clname {cls}')
        for s in segs:
            print(f'    segment {s}')


main()
