#!/usr/bin/env python3
"""Translate a Microsoft LINK module definition file (.DEF) of a Windows
program or DLL into OpenWatcom wlink directives.

    def2wlink.py [--stub=EXE] FILE.DEF [win16|win32 [OBJ...]] > FILE.lnk

--stub replaces the STUB program of the DEF file (e.g. one built here).

win32: Microsoft LINK exports a __stdcall function _Name@N under the name
written in the DEF file (Name); wlink needs the decorated name, which is
looked up in the object files.

Handled: NAME, LIBRARY, DESCRIPTION, EXETYPE, PROTMODE, STUB, CODE, DATA,
SEGMENTS, HEAPSIZE, STACKSIZE, EXPORTS, IMPORTS.  The format directive is written by
the caller (it depends on NAME vs. LIBRARY, see the first output line).
"""
import os
import re
import sys


def words(line):
    return re.findall(r"'[^']*'|\"[^\"]*\"|[^\s=]+(?:=[^\s]+)?", line)


def segattrs(ws):
    m = {'PRELOAD': 'preload', 'LOADONCALL': 'loadoncall',
         'MOVEABLE': 'moveable', 'MOVABLE': 'moveable', 'FIXED': 'fixed',
         'DISCARDABLE': 'discardable', 'NONDISCARDABLE': None,
         'PURE': 'shared', 'SHARED': 'shared', 'IMPURE': 'nonshared',
         'NONSHARED': 'nonshared', 'READONLY': 'readonly',
         'EXECUTEONLY': 'executeonly', 'EXECUTEREAD': 'executeread',
         'READWRITE': 'readwrite', 'CONFORMING': 'conforming'}
    return ' '.join(m[w.upper()] for w in ws if m.get(w.upper()))


def main():
    stubover = None
    if sys.argv[1].startswith('--stub='):
        stubover = sys.argv.pop(1)[len('--stub='):]
    path = sys.argv[1]
    target = sys.argv[2] if len(sys.argv) > 2 else 'win16'
    objdata = b''.join(open(o, 'rb').read() for o in sys.argv[3:])
    out = []
    kind = 'exe'
    section = None
    for raw in open(path, encoding='latin-1'):
        line = raw.replace('\x1a', '').split(';', 1)[0].strip()   # ^Z: DOS end of file
        if not line:
            continue
        ws = words(line)
        key = ws[0].upper()
        if key in ('NAME', 'LIBRARY'):
            kind = 'dll' if key == 'LIBRARY' else 'exe'
            section = None
            if len(ws) > 1:
                out.append('option modname=%s' % ws[1].strip("'\""))
            continue
        if key == 'DESCRIPTION':
            out.append("option description '%s'" % line.split(None, 1)[1].strip().strip("'\""))
            section = None
            continue
        if key == 'PROTMODE':
            section = None
            out.append('option protmode')
            continue
        if key in ('EXETYPE', 'APPLOADER', 'REALMODE'):
            section = None
            continue
        if key == 'STUB':
            section = None
            stub = ws[1].strip("'\"") if len(ws) > 1 else ''
            if stubover:
                out.append('option stub=%s' % os.path.abspath(stubover))
            elif stub.upper() != 'WINSTUB.EXE':   # else OpenWatcom's stub
                d = os.path.dirname(os.path.abspath(path))
                for f in os.listdir(d):
                    if f.lower() == stub.lower():
                        out.append('option stub=%s' % os.path.join(d, f))
            continue
        if key in ('HEAPSIZE', 'STACKSIZE'):
            section = None
            if key == 'HEAPSIZE' and ws[1] == '0':
                continue        # no local heap (wlink rejects 0)
            out.append('option %s=%s' % ('heapsize' if key == 'HEAPSIZE' else 'stack', ws[1]))
            continue
        if key in ('CODE', 'DATA') and target == 'win16':
            section = None
            attrs = segattrs(ws[1:])
            if key == 'DATA':
                up = [w.upper() for w in ws[1:]]
                if 'MULTIPLE' in up:
                    out.append('option manyautodata')
                elif 'SINGLE' in up:
                    out.append('option oneautodata')
            if attrs:
                out.append('segment type %s %s' % (key.lower(), attrs))
            continue
        if key in ('SEGMENTS', 'EXPORTS', 'IMPORTS'):
            section = key
            ws = ws[1:]
            if not ws:
                continue
        if section == 'SEGMENTS' and target == 'win16':
            name = ws[0].strip("'\"")
            rest = [w for w in ws[1:] if not w.upper().startswith('CLASS')]
            attrs = segattrs(rest)
            if attrs:
                out.append("segment '%s' %s" % (name, attrs))
        elif section == 'EXPORTS':
            name = ws[0]
            internal = None
            if '=' in name:
                name, internal = name.split('=', 1)
            ordinal = next((w[1:] for w in ws[1:] if w.startswith('@')), None)
            res = 'RESIDENTNAME' in (w.upper() for w in ws[1:])
            spec = name + (('.' + ordinal) if ordinal else '')
            if not internal and target == 'win32':
                m = re.search(rb'_' + re.escape(name.encode()) + rb'@\d+', objdata)
                if m:
                    internal = "'%s'" % m.group(0).decode()
            if internal:
                spec += '=' + internal
            if res:
                spec += ' resident'
            out.append('export %s' % spec)
        elif section == 'IMPORTS':
            entry = ws[0]
            if '=' in entry:
                internal, ext = entry.split('=', 1)
            else:
                internal, ext = None, entry
            mod, _, what = ext.partition('.')
            if what.isdigit():
                out.append('import %s %s.%s' % (internal or what, mod, what))
            else:
                out.append('import %s %s.%s' % (internal or what, mod, what))
    print('# kind %s' % kind)
    print('\n'.join(out))


main()
