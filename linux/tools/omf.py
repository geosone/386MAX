#!/usr/bin/env python3
"""OMF object file helper for the 386MAX build.

    omf.py dump FILE            segments, sizes, publics
    omf.py cmp  OLD NEW         compare the segment images (data bytes and
                                fixup positions) of two objects
    omf.py expand IN OUT        rewrite LIDATA records as LEDATA (with their
                                fixups), for linkers that can't relocate
                                iterated data
"""
import sys
import struct


class Omf:
    def __init__(self, path):
        self.path = path
        self.lnames = ['']
        self.segs = []          # dicts: name, cls, length, data, fix
        self.groups = []
        self.exts = ['']
        self.pubs = []
        self.last = None        # (seg index, offset) of the last data record
        self.tthreads = {}
        self.fthreads = {}
        self.limap = None
        data = open(path, 'rb').read()
        pos = 0
        while pos < len(data):
            typ = data[pos]
            ln = struct.unpack_from('<H', data, pos + 1)[0]
            body = data[pos + 3:pos + 3 + ln - 1]
            pos += 3 + ln
            self.record(typ, body)
            if typ in (0x8A, 0x8B):
                break

    def name(self, method, dat):
        """frame/target as text: method 0 segment, 1 group, 2 external"""
        try:
            if method == 0:
                return 'S:' + self.segs[dat - 1]['name']
            if method == 1:
                return 'G:' + self.groups[dat - 1]
            if method == 2:
                return 'E:' + self.exts[dat]
        except (IndexError, TypeError):
            pass
        return f'{method}:{dat}'

    @staticmethod
    def index(b, p):
        v = b[p]
        if v & 0x80:
            return ((v & 0x7F) << 8) | b[p + 1], p + 2
        return v, p + 1

    def record(self, typ, b):
        big = typ & 1
        if typ == 0x96:                         # LNAMES
            p = 0
            while p < len(b):
                n = b[p]
                self.lnames.append(b[p + 1:p + 1 + n].decode('latin-1'))
                p += 1 + n
        elif typ in (0x98, 0x99):               # SEGDEF
            acbp = b[0]
            p = 1
            if (acbp >> 5) == 0:
                p += 3
            if big:
                length = struct.unpack_from('<I', b, p)[0]
                p += 4
            else:
                length = struct.unpack_from('<H', b, p)[0]
                p += 2
            if acbp & 2:
                length = 0x10000 if not big else 0x100000000
            name, p = self.index(b, p)
            cls, p = self.index(b, p)
            self.segs.append(dict(name=self.lnames[name], cls=self.lnames[cls],
                                  length=length, data=bytearray(length),
                                  fix=set(), acbp=acbp))
        elif typ == 0x9A:                       # GRPDEF
            name, p = self.index(b, 0)
            self.groups.append(self.lnames[name])
        elif typ in (0x8C, 0xB4):               # EXTDEF, LEXTDEF
            p = 0
            while p < len(b):
                n = b[p]
                self.exts.append(b[p + 1:p + 1 + n].decode('latin-1'))
                p += 1 + n
                _, p = self.index(b, p)
        elif typ in (0x90, 0x91, 0xB6, 0xB7):   # PUBDEF, LPUBDEF
            grp, p = self.index(b, 0)
            seg, p = self.index(b, p)
            if seg == 0:
                p += 2
            while p < len(b):
                n = b[p]
                name = b[p + 1:p + 1 + n].decode('latin-1')
                p += 1 + n
                if big:
                    off = struct.unpack_from('<I', b, p)[0]
                    p += 4
                else:
                    off = struct.unpack_from('<H', b, p)[0]
                    p += 2
                _, p = self.index(b, p)
                self.pubs.append((name, seg, off))
        elif typ in (0xA0, 0xA1):               # LEDATA
            seg, p = self.index(b, 0)
            if big:
                off = struct.unpack_from('<I', b, p)[0]
                p += 4
            else:
                off = struct.unpack_from('<H', b, p)[0]
                p += 2
            d = b[p:]
            s = self.segs[seg - 1]
            s['data'][off:off + len(d)] = d
            self.last = (seg, off)
            self.limap = None
        elif typ in (0xA2, 0xA3):               # LIDATA
            seg, p = self.index(b, 0)
            if big:
                off = struct.unpack_from('<I', b, p)[0]
                p += 4
            else:
                off = struct.unpack_from('<H', b, p)[0]
                p += 2
            d = bytearray()
            self.limap = {}
            body = p
            while p < len(b):
                blk, p, m = self.iter_block(b, p, big, len(d))
                d += blk
                for k, v in m.items():
                    self.limap.setdefault(k, []).extend(v)
            s = self.segs[seg - 1]
            s['data'][off:off + len(d)] = d
            self.last = (seg, off)
            self.limap = {k - body: [off + x for x in v] for k, v in self.limap.items()}
        elif typ in (0x9C, 0x9D):               # FIXUPP
            p = 0
            while p < len(b):
                v = b[p]
                if v & 0x80:                    # FIXUP subrecord
                    loc = ((v & 3) << 8) | b[p + 1]
                    selfrel = not v & 0x40
                    loctype = (v >> 2) & 0xF
                    p += 2
                    fd = b[p]
                    p += 1
                    fm, fdat = None, None
                    if fd & 0x80:
                        fm, fdat = self.fthreads.get((fd >> 4) & 3, (None, None))
                    else:
                        fm = (fd >> 4) & 7
                        if fm < 4:
                            fdat, p = self.index(b, p)  # frame datum
                    if fd & 0x08:               # target from a thread
                        tmeth, tdat = self.tthreads.get(fd & 3, (None, None))
                        tmeth = (tmeth or 0) | (fd & 4)
                    else:
                        tmeth = fd & 7
                        tdat, p = self.index(b, p)
                    disp = 0
                    if not fd & 0x04:
                        disp = struct.unpack_from('<I' if big else '<H', b, p)[0]
                        p += 4 if big else 2
                    if self.last:
                        seg, off = self.last
                        if self.limap is not None:   # LIDATA: record offsets
                            where = self.limap.get(loc, [])
                        else:
                            where = [off + loc]
                        for w in where:
                            self.segs[seg - 1]['fix'].add(w)
                            self.segs[seg - 1].setdefault('fixd', {})[w] = (
                                selfrel, loctype, tmeth & 3, tdat, disp)
                            self.segs[seg - 1].setdefault('fixn', {})[w] = (
                                selfrel, loctype, self.name(fm, fdat), self.name(tmeth & 3, tdat), disp)
                else:                           # THREAD subrecord
                    method = (v >> 2) & 7
                    p += 1
                    dat = None
                    if method < 4:
                        dat, p = self.index(b, p)
                    if not v & 0x40:            # target thread
                        self.tthreads[v & 3] = (method, dat)
                    else:
                        self.fthreads[v & 3] = (method, dat)

    def iter_block(self, b, p, big, base):
        """one iterated data block at b[p] -> (expanded bytes, next p,
        {record position: [expanded offsets]})"""
        if big:
            rep = struct.unpack_from('<I', b, p)[0]
            p += 4
        else:
            rep = struct.unpack_from('<H', b, p)[0]
            p += 2
        cnt = struct.unpack_from('<H', b, p)[0]
        p += 2
        m = {}
        if cnt == 0:
            n = b[p]
            content = bytes(b[p + 1:p + 1 + n])
            for i in range(n):
                m[p + 1 + i] = [i]
            p += 1 + n
        else:
            content = bytearray()
            for _ in range(cnt):
                blk, p, sub = self.iter_block(b, p, big, 0)
                for k, v in sub.items():
                    m.setdefault(k, []).extend(len(content) + x for x in v)
                content += blk
        size = len(content)
        out = {k: [base + r * size + x for r in range(rep) for x in v] for k, v in m.items()}
        return bytes(content) * rep, p, out


def dump(path):
    o = Omf(path)
    for i, s in enumerate(o.segs, 1):
        print(f'{i:3} {s["name"]:12} {s["cls"]:8} {s["length"]:6x} fixups {len(s["fix"])}')
    print(f'{len(o.pubs)} publics, {len(o.exts) - 1} externals')


def cmp(a, b):
    oa, ob = Omf(a), Omf(b)
    bad = 0
    sb = {s['name']: s for s in ob.segs}
    for s in oa.segs:
        t = sb.get(s['name'])
        if t is None:
            print(f'{s["name"]}: missing in {b}')
            bad += 1
            continue
        if s['length'] != t['length']:
            print(f'{s["name"]}: length {s["length"]:#x} -> {t["length"]:#x}')
            bad += 1
        if s['cls'] != t['cls'] or s.get('acbp') != t.get('acbp'):
            print(f'{s["name"]}: class/attributes {s["cls"]}/{s.get("acbp")} -> {t["cls"]}/{t.get("acbp")}')
            bad += 1
        n = min(s['length'], t['length'])
        diffs = [i for i in range(n) if s['data'][i] != t['data'][i]
                 and i not in t['fix'] and i not in s['fix']
                 and (i - 1) not in s['fix'] and (i - 1) not in t['fix']
                 and (i - 2) not in s['fix'] and (i - 3) not in s['fix']]
        if diffs:
            print(f'{s["name"]}: {len(diffs)} bytes differ, first at {diffs[0]:#x}')
            bad += 1
        fa, fb = set(s['fix']), set(t['fix'])
        segidx = {x['name']: i for i, x in enumerate(oa.segs, 1)}[s['name']]
        for pos in sorted(fa - fb):
            selfrel, loctype, tm, tdat, disp = s['fixd'][pos]
            # a self-relative 16/32 bit offset to a label of the same
            # segment, which the new object resolved itself: check the value
            if selfrel and loctype in (1, 9) and tm == 0 and tdat == segidx:
                n = 2 if loctype == 1 else 4
                mask = (1 << (8 * n)) - 1
                addend = int.from_bytes(s['data'][pos:pos + n], 'little')
                want = (disp + addend - (pos + n)) & mask
                have = int.from_bytes(t['data'][pos:pos + n], 'little')
                if want == have:
                    fa.discard(pos)
                else:
                    print(f'{s["name"]}: resolved jump at {pos:#x}: {have:#06x}, expected {want:#06x}')
        na, nb = s.get('fixn', {}), t.get('fixn', {})
        def same(x, y):
            fx = x[3] if str(x[2]).startswith('5:') else x[2]
            fy = y[3] if str(y[2]).startswith('5:') else y[2]
            return fx == fy and x[3] == y[3]
        dif = [pos for pos in sorted(set(na) & set(nb)) if not same(na[pos], nb[pos])]
        if dif:
            pos = dif[0]
            print(f'{s["name"]}: {len(dif)} fixup targets differ, first at {pos:#x}: {na[pos]} -> {nb[pos]}')
            bad += 1
        if fa != fb:
            print(f'{s["name"]}: fixups {len(fa)} -> {len(fb)}, '
                  f'{len(fa - fb)} only old, {len(fb - fa)} only new')
            bad += 1
    pa = {n: o for n, _, o in oa.pubs}
    pb = {n: o for n, _, o in ob.pubs}
    if set(pa) != set(pb):
        print(f'publics differ: {sorted(set(pa) ^ set(pb))[:10]}')
        bad += 1
    print('identical' if not bad else f'{bad} differences')
    return bad


def rec(typ, body):
    body = bytes(body)
    ln = len(body) + 1
    chk = (-(typ + (ln & 0xFF) + (ln >> 8) + sum(body))) & 0xFF
    return bytes([typ]) + struct.pack('<H', ln) + body + bytes([chk])


def expand(src, dst):
    """LIDATA -> LEDATA; the FIXUPPs after an LIDATA get their locations
    mapped to the expanded data (a fixup inside a repeated block is
    repeated)."""
    o = Omf.__new__(Omf)
    data = open(src, 'rb').read()
    out = bytearray()
    pend = None

    def flush():
        hdr, big, off, d, m, fix, threads, fbig = pend
        for c in range(0, max(len(d), 1), 1024):
            chunk = d[c:c + 1024]
            ofs = off + c
            b = bytearray(hdr) + (struct.pack('<I', ofs) if big else struct.pack('<H', ofs)) + chunk
            out.extend(rec(0xA1 if big else 0xA0, b))
            fb = bytearray(threads if c == 0 else b'')
            for k in sorted(fix):
                if c <= k < c + len(chunk):
                    for v, rest in fix[k]:
                        l = k - c
                        fb += bytes([v | 0x80 | (l >> 8), l & 0xFF]) + rest
            if fb:
                out.extend(rec(0x9D if fbig else 0x9C, fb))

    fthr = {}
    tthr = {}

    def idx(n):
        return bytes([0x80 | (n >> 8), n & 0xFF]) if n >= 0x80 else bytes([n])

    pos = 0
    while pos < len(data):
        typ = data[pos]
        ln = struct.unpack_from('<H', data, pos + 1)[0]
        body = data[pos + 3:pos + 3 + ln - 1]
        raw = data[pos:pos + 3 + ln]
        pos += 3 + ln
        if typ in (0x9C, 0x9D):
            # follow the thread definitions in every FIXUPP (they stay
            # valid across records); fixups after an LIDATA are rewritten
            # with explicit frame and target, so their order doesn't matter
            p = 0
            while p < len(body):
                v = body[p]
                st = p
                if v & 0x80:
                    loc = ((v & 3) << 8) | body[p + 1]
                    p += 2
                    fd = body[p]
                    p += 1
                    if fd & 0x80:
                        fm, fdat = fthr.get((fd >> 4) & 3, (5, None))
                    else:
                        fm = (fd >> 4) & 7
                        fdat = None
                        if fm < 4:
                            fdat, p = Omf.index(body, p)
                    if fd & 0x08:
                        tm, tdat = tthr.get(fd & 3, (0, 0))
                        tm = (tm & 3) | (fd & 4)
                    else:
                        tm = fd & 7
                        tdat, p = Omf.index(body, p)
                    disp = b''
                    if not fd & 0x04:
                        n = 4 if typ & 1 else 2
                        disp = bytes(body[p:p + n])
                        p += n
                    if pend is not None:
                        hdr, big, off, d, m, fix, threads, fbig = pend
                        nd = bytes([(fm << 4) | (tm & 7)])
                        if fm < 4:
                            nd += idx(fdat)
                        nd += idx(tdat) + disp
                        for w in m.get(loc, []):
                            fix.setdefault(w - off, []).append((v & 0xFC, nd))
                else:
                    method = (v >> 2) & 7
                    p += 1
                    dat = None
                    if method < 4 or not v & 0x40:
                        if not (v & 0x40 and method >= 4):
                            dat, p = Omf.index(body, p)
                    if v & 0x40:
                        fthr[v & 3] = (method, dat)
                    else:
                        tthr[v & 3] = (method, dat)
            if pend is not None:
                hdr, big, off, d, m, fix, threads, fbig = pend
                pend = (hdr, big, off, d, m, fix, threads, fbig or (typ & 1))
                continue
        if pend is not None:
            flush()
            pend = None
        if typ in (0xA2, 0xA3):
            big = typ & 1
            seg, p = Omf.index(body, 0)
            hdr = body[:p]
            if big:
                off = struct.unpack_from('<I', body, p)[0]
                p += 4
            else:
                off = struct.unpack_from('<H', body, p)[0]
                p += 2
            d = bytearray()
            m = {}
            bp = p
            while p < len(body):
                blk, p, mm = o.iter_block(body, p, big, len(d))
                d += blk
                for k, v in mm.items():
                    m.setdefault(k - bp, []).extend(off + x for x in v)
            pend = (hdr, big, off, bytes(d), m, {}, bytearray(), 0)
            continue
        out += raw
    if pend is not None:
        flush()
    open(dst, 'wb').write(out)


if __name__ == '__main__':
    if sys.argv[1] == 'dump':
        dump(sys.argv[2])
    elif sys.argv[1] == 'expand':
        expand(sys.argv[2], sys.argv[3])
    elif sys.argv[1] == 'cmp':
        sys.exit(1 if cmp(sys.argv[2], sys.argv[3]) else 0)
