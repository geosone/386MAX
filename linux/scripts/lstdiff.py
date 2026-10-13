#!/usr/bin/env python3
"""Compare the MASM 5.10 listing (build/masm/PROJ/M.LST, "make masmref")
with the JWasm listing (build/PROJ/M_OBJ.LST) of a module: code lines are
matched by their source text, and lines whose encoded length or first
bytes differ are shown (at most N, default 10).

    lstdiff.py PROJ MODULE [N]
"""
import re
import sys
import difflib

R = __import__('os').path.abspath(__import__('os').path.dirname(__file__) + '/../../build')


def masm(path):
    out = []
    for l in open(path, encoding='latin-1'):
        l = l.rstrip('\r\n')
        c = re.match(r' {7}([0-9A-F][0-9A-F ]*[0-9A-F])\s*[ERS]?\s*$', l)
        if c and out:
            out[-1] = (out[-1][0], out[-1][1] + c.group(1).replace(' ', ''), out[-1][2])
            continue
        m = re.match(r' ([0-9A-F]{4})  (.*?)\t(.*)$', l)
        if not m:
            continue
        code, src = m.group(2), m.group(3)
        src = src.lstrip('\t ')
        toks = code.replace(':', ' ').replace('|', ' ').replace('/', ' ').split()
        hexb = ''
        for t in toks:
            if re.fullmatch(r'[0-9A-F]+', t) and len(t) % 2 == 0:
                hexb += t if len(t) == 2 else ''.join(reversed([t[i:i + 2] for i in range(0, len(t), 2)]))
            elif t == '----':
                hexb += '0000'
        if not hexb or src.startswith(('db', 'dw', 'dd', 'DB', 'DW', 'DD')):
            continue
        out.append((int(m.group(1), 16), hexb, src))
    return out


def jwasm(path):
    out = []
    for l in open(path, encoding='latin-1'):
        l = l.rstrip('\r\n')
        m = re.match(r'([0-9A-F]{4,8}) ([0-9A-F][0-9A-Fos* ]*?)\s{2,}(?:\d+\s+)?(.*)$', l)
        if not m:
            continue
        code, src = m.group(2), m.group(3).lstrip('\t ')
        hexb = ''
        for t in code.split():
            t = t.rstrip('osR*')
            if re.fullmatch(r'[0-9A-F]+', t) and len(t) % 2 == 0:
                hexb += t if not code.split()[0] != t or len(t) <= 2 else t
        if not hexb or src.startswith(('db', 'dw', 'dd', 'DB', 'DW', 'DD')):
            continue
        out.append((int(m.group(1), 16), hexb, src))
    return out


DATA = ('DB', 'DW', 'DD', 'DF', 'DQ', 'DT', 'LABEL', 'EQU', '=')


def is_data(src):
    w = src.upper().split()
    return any(x in DATA for x in w[:2]) or '<' in ' '.join(w[1:2])


def norm(s):
    return re.sub(r'\s+', ' ', s.split(';')[0]).strip().upper()


def main():
    proj, mod = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    a = masm(f'{R}/masm/{proj}/{mod}.LST')
    b = jwasm(f'{R}/{proj}/{mod}_OBJ.LST')
    sm = difflib.SequenceMatcher(None, [norm(x[2]) for x in a], [norm(x[2]) for x in b], autojunk=False)
    shown = 0
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != 'equal':
            continue
        for k in range(i2 - i1):
            x, y = a[i1 + k], b[j1 + k]
            if is_data(x[2]):
                continue
            if len(x[1]) != len(y[1]) or x[1][:2] != y[1][:2]:
                print(f'{x[0]:04X} {x[1]:20} | {y[0]:04X} {y[1]:20} {x[2][:60]}')
                shown += 1
                if shown >= n:
                    return


main()
