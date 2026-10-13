#!/usr/bin/env python3
"""Port of QMT/WRAPPER.C (Qualitas, GPLv3) for the build on Linux: turn the
binary help text (a .COM file made from MEM_HTX2.A$(LANG)) into MASM source.
ESC sequences in the input control indentation, width, centering, symbols
and colors; the rest is word-wrapped into "db '...'" lines.  The output is
the same as the one of the DOS program, including its quirks.

    wrapper.py INFILE.COM OUTFILE.ASM
"""
import sys

SIGNAL_CHAR = 0x1B


def main():
    buf = open(sys.argv[1], 'rb').read()
    n = len(buf)
    at = lambda k: buf[k] if 0 <= k < n else 0   # C read beyond the end
    out = []                                      # text mode: CR LF
    w = out.append
    st = dict(width=30, indent=0, color=0, curcolor=0, sym=b'', colsym=b'', rowsym=b'')

    def cstr(k):
        e = buf.index(0, k) if 0 in buf[k:] else n
        return buf[k:e]

    def lastsymlen():
        if st['color']:
            w(b'%s equ ($-%s)/(%s+1)\n\n' % (st['rowsym'], st['sym'], st['colsym']))
        else:
            w(b'%s equ ($-%s)/%s\n\n' % (st['rowsym'], st['sym'], st['colsym']))

    def db_prefix():
        if st['color']:
            w(b' db %c, \'' % (st['curcolor'] + ord('0')))
        else:
            w(b" db '")

    def db_center(k):
        s = cstr(k)
        pad = int((st['width'] - len(s)) / 2)     # C division
        db_prefix()
        w(b' ' * max(0, pad + 1))
        w(s)
        w(b' ' * max(0, st['width'] - (pad + len(s))))
        w(b"'\n")
        return len(s) + 1

    def db_raw(k):
        s = cstr(k)
        w(s + b'\n')
        return len(s) + 1

    def db_one_symbol(k):
        s = cstr(k)
        w(b'\n')
        if st['sym']:
            lastsymlen()
        w(b'\t public\t %s\n' % s)
        w(b'%s\t label\t byte\n' % s)
        return len(s) + 1

    def db_color(k):
        st['color'] = 1
        st['curcolor'] = at(k)
        return 1

    def db_symbol(k):
        w(b'\n')
        if st['sym']:
            lastsymlen()
        i = 0
        names = []
        for _ in range(3):
            s = cstr(k + i)
            names.append(s)
            i += len(s) + 1
        st['sym'], st['colsym'], st['rowsym'] = names
        w(b'\t public\t %s,%s,%s\n' % (st['sym'], st['colsym'], st['rowsym']))
        w(b'%s\t label\t byte\n' % st['sym'])
        w(b'%s equ %d\n' % (st['colsym'], st['width'] + 1))
        return i

    line = bytearray(256)
    pos_space = 0
    i_space = 0
    cpos = 0
    i = 0
    while i < n:
        if buf[i] == SIGNAL_CHAR:
            i += 1
            c = at(i)
            if c == ord('I'):
                if cpos == st['indent']:
                    cpos = 0
                i += 1
                st['indent'] = at(i)
                i += 1
            elif c == ord('W'):
                i += 1
                st['width'] = at(i)
                i += 1
            elif c == ord('C'):
                i += 1
                i += db_center(i)
            elif c == ord('S'):
                i += 1
                i += db_symbol(i)
            elif c == ord('R'):
                i += 1
                i += db_raw(i)
            elif c == ord('O'):
                i += 1
                i += db_one_symbol(i)
            elif c == ord('L'):
                i += 1
                i += db_color(i)
            elif c == ord('Z'):
                lastsymlen()
                st['sym'] = st['rowsym'] = st['colsym'] = b''
            else:
                sys.exit('Unknown ESCAPE sequence in input file!!')
            continue
        line[cpos] = buf[i]
        if buf[i] == ord(' '):
            pos_space = cpos
            i_space = i
        elif buf[i] == 0x0D:
            i_space = 0
            pos_space = 0
            line[cpos] = 0
            cpos -= 1
        i += 1
        cpos += 1
        if cpos > st['width'] or at(i - 1) == 0x0D:
            if at(i) in (0x20, 0x0D) and at(i - 1) != 0x0D:
                i += 1
                i_space = 0
            if i_space != 0:
                i = i_space + 1
                cpos = pos_space
            while cpos <= st['width']:
                line[cpos] = 0x20
                cpos += 1
            line[cpos] = 0
            pos_space = i_space = cpos = 0
            text = bytes(line[:line.index(0)]).replace(b"'", b"''")
            if st['color']:
                w(b" db %c, '%s'\n" % (st['curcolor'] + ord('0'), text))
            else:
                w(b" db '%s'\n" % text)
            st['curcolor'] = 0
            if at(i - 1) != 0x0D:
                while cpos < st['indent']:
                    line[cpos] = 0x20
                    cpos += 1
    open(sys.argv[2], 'wb').write(b''.join(out).replace(b'\n', b'\r\n'))


main()
