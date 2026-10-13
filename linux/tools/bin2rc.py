#!/usr/bin/env python3
"""Replacement for Qualitas' BIN2RC.EXE: write a binary file as the body of
an RCDATA resource (a length word, then the bytes as string literals).

    bin2rc.py FILE OUT.RC

Bytes other than printable ASCII are written as three digit octal escapes,
which, unlike \\x escapes, cannot run into a following character.
"""
import sys


def main():
    src, dst = sys.argv[1], sys.argv[2]
    data = open(src, 'rb').read()
    out = ['// File: %s' % src.replace('/', '\\'),
           '0x%04x   // Segment length in bytes (%d of %d)' % (len(data), len(data), len(data))]
    line = ''
    for b in data:
        c = chr(b)
        if c == '"':
            piece = '\\"'
        elif c == '\\':
            piece = '\\\\'
        elif 32 <= b < 127:
            piece = c
        else:
            piece = '\\%03o' % b
        line += piece
        if len(line) >= 64:
            out.append('\t"%s"' % line)
            line = ''
    if line:
        out.append('\t"%s"' % line)
    out.append('// *EOF*')
    open(dst, 'w', newline='\r\n').write('\n'.join(out) + '\n')


main()
