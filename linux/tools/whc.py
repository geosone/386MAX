#!/usr/bin/env python3
"""Windows 3.1 help files (WinHelp .HLP): decode and build them.
Replaces the Microsoft help compiler HC31 in the open source build.

    whc.py dump FILE.HLP            readable dump (internal files, topics)
    whc.py build PROJECT.HPJ [-o OUT.HLP] [-DNAME]
                                    compile the help project (Word RTF)
    whc.py getsect PROJECT.HPJ SECTION   print one section of a project
    whc.py makehm RESOURCE.H PREFIX HEXPRE
                                    help map of resource identifiers

The format follows the description in helpdeco (helpfile.txt, M.
Winterhoff, GPL).  Written are uncompressed Windows 3.1 help files
(|SYSTEM version 21, 4 KB topic blocks, no phrase compression), like HC31
with COMPRESS=FALSE.

Open 386MAX - GNU General Public License version 3.
"""
import os
import re
import struct
import sys
import time

BLOCKSIZE = 4096
DECOMPSIZE = 0x4000
TBHDR = 12


# --- common ---------------------------------------------------------------

HASHTAB = [
    0x00, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xDB,
    0xDC, 0xDD, 0xDE, 0xDF, 0xE0, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7,
    0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF, 0xF0, 0x0B, 0xF2, 0xF3,
    0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0x0C, 0xFF,
    0x0A, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B,
    0x0C, 0x0D, 0x0E, 0x0F, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23,
    0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0D,
    0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B,
    0x1C, 0x1D, 0x1E, 0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
    0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F, 0x50, 0x51, 0x52, 0x53,
    0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C, 0x5D, 0x5E, 0x5F,
    0x60, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B,
    0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77,
    0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D, 0x7E, 0x7F, 0x80, 0x81, 0x82, 0x83,
    0x0B, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8E, 0x8F,
    0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99, 0x9A, 0x9B,
    0x9C, 0x9D, 0x9E, 0x9F, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7,
    0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAE, 0xAF, 0xB0, 0xB1, 0xB2, 0xB3,
    0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF,
    0xC0, 0xC1, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xCB,
    0xCC, 0xCD, 0xCE, 0xCF]


def ctxhash(name):
    """hash of a context string (signed 32 bit)"""
    h = 0
    for c in name.encode('latin-1'):
        t = HASHTAB[c]
        if t >= 0x80:
            t -= 0x100
        h = (h * 43 + t) & 0xFFFFFFFF
    if not name:
        h = 1
    return h - (1 << 32) if h & 0x80000000 else h


class Reader:
    def __init__(self, data, pos=0):
        self.d = data
        self.p = pos

    def u8(self):
        v = self.d[self.p]
        self.p += 1
        return v

    def s8(self):
        v = self.u8()
        return v - 256 if v >= 128 else v

    def u16(self):
        v = struct.unpack_from('<H', self.d, self.p)[0]
        self.p += 2
        return v

    def s16(self):
        v = struct.unpack_from('<h', self.d, self.p)[0]
        self.p += 2
        return v

    def u32(self):
        v = struct.unpack_from('<I', self.d, self.p)[0]
        self.p += 4
        return v

    def s32(self):
        v = struct.unpack_from('<i', self.d, self.p)[0]
        self.p += 4
        return v

    def sz(self):
        e = self.d.index(0, self.p)
        s = self.d[self.p:e].decode('latin-1')
        self.p = e + 1
        return s

    # compressed values of LinkData1
    def cus(self):
        b = self.u8()
        return b >> 1 if not b & 1 else (b >> 1) + 128 * self.u8()

    def css(self):
        b = self.u8()
        return (b >> 1) - 64 if not b & 1 else (b >> 1) + 128 * self.u8() - 16384

    def cul(self):
        w = self.u16()
        return w >> 1 if not w & 1 else (w >> 1) + 32768 * self.u16()

    def csl(self):
        w = self.u16()
        if not w & 1:
            return (w >> 1) - 0x4000
        return (w >> 1) + 32768 * self.u16() - 0x40000000


# --- reading --------------------------------------------------------------

def read_btree(data, keyf, valf):
    """all (key, value) of a B+ tree (internal file data)"""
    r = Reader(data)
    magic, flags, pagesize = r.u16(), r.u16(), r.u16()
    if magic != 0x293B:
        raise ValueError('not a B+ tree')
    r.p += 16
    r.u16(), r.u16()
    root = r.s16()
    r.u16()
    r.u16()
    levels = r.u16()
    r.u32()
    base = 38
    page = root
    for _ in range(levels - 1):        # down to the first leaf
        page = struct.unpack_from('<h', data, base + page * pagesize + 4)[0]
    out = []
    while page != -1:
        r = Reader(data, base + page * pagesize)
        r.u16()
        n = r.s16()
        r.s16()
        nxt = r.s16()
        for _ in range(n):
            k = keyf(r)
            out.append((k, valf(r)))
        page = nxt
    return out


class HelpFile:
    def __init__(self, data):
        r = Reader(data)
        if r.u32() != 0x00035F3F:
            raise ValueError('not a Windows help file')
        dirstart = r.u32()
        self.data = data
        self.files = {}
        for name, off in read_btree(self.file_at(dirstart),
                                    Reader.sz, Reader.u32):
            self.files[name] = off

    def file_at(self, off):
        reserved, used = struct.unpack_from('<II', self.data, off)
        return self.data[off + 9:off + 9 + used]

    def file(self, name):
        return self.file_at(self.files[name]) if name in self.files else None


def read_system(b):
    r = Reader(b)
    magic, minor, major = r.u16(), r.u16(), r.u16()
    gendate, flags = r.u32(), r.u16()
    sysd = {'minor': minor, 'flags': flags, 'records': []}
    while r.p + 4 <= len(b):
        typ, size = r.u16(), r.u16()
        rec = b[r.p:r.p + size]
        r.p += size
        sysd['records'].append((typ, rec))
    return sysd


def read_font(b):
    r = Reader(b)
    nface, ndesc, oface, odesc = r.u16(), r.u16(), r.u16(), r.u16()
    flen = (odesc - oface) // nface if nface else 0
    faces = [b[oface + i * flen:oface + (i + 1) * flen].split(b'\0')[0]
             .decode('latin-1') for i in range(nface)]
    descs = []
    for i in range(ndesc):
        attr, hp, fam, face = struct.unpack_from('<BBBH', b, odesc + i * 11)
        fg = b[odesc + i * 11 + 5:odesc + i * 11 + 8]
        descs.append((attr, hp, fam, faces[face] if face < nface else face,
                      '%02X%02X%02X' % tuple(fg)))
    return faces, descs


def topic_blocks(t):
    """|TOPIC -> buffer addressed by TOPICPOS - 12 (block * 0x4000 + off)"""
    blocks = {}
    for i in range(0, len(t), BLOCKSIZE):
        blocks[i // BLOCKSIZE] = t[i + TBHDR:i + BLOCKSIZE]
    return blocks


def topic_read(blocks, pos, n):
    out = bytearray()
    while n > 0:
        blk, off = divmod(pos - TBHDR, DECOMPSIZE)
        b = blocks.get(blk)
        if b is None:
            break
        take = b[off:off + n]
        out += take
        n -= len(take)
        pos = (blk + 1) * DECOMPSIZE + TBHDR
    return bytes(out)


def parse_para(r, rtype):
    """Paragraphinfo of a display or table record -> dict"""
    p = {}
    if rtype == 0x23:
        p['column'] = r.s16()
        if p['column'] == -1:
            return p
        r.s16()
        r.u8()
    p['u1'] = r.u8()
    p['u2'] = r.s8()
    p['id'] = r.u16()
    bits = r.u16()
    p['bits'] = bits
    if bits & 0x0001:
        p['unk'] = r.csl()
    if bits & 0x0002:
        p['sb'] = r.css()
    if bits & 0x0004:
        p['sa'] = r.css()
    if bits & 0x0008:
        p['sl'] = r.css()
    if bits & 0x0010:
        p['li'] = r.css()
    if bits & 0x0020:
        p['ri'] = r.css()
    if bits & 0x0040:
        p['fi'] = r.css()
    if bits & 0x0100:
        p['border'] = (r.u8(), r.s16())
    if bits & 0x0200:
        tabs = []
        for _ in range(r.css()):
            ts = r.cus()
            tt = r.cus() if ts & 0x4000 else 0
            tabs.append((ts & 0x3FFF, tt))
        p['tabs'] = tabs
    if bits & 0x1000:
        p['keep'] = 1
    if bits & 0x0400:
        p['align'] = 'r'
    if bits & 0x0800:
        p['align'] = 'c'
    return p


def parse_display(ld1, ld2, rtype):
    """LinkData1/2 of a 0x20/0x23 record -> (topiclength, items)
    items: ('para', dict), ('text', str), ('cmd', name, arg)"""
    r = Reader(ld1)
    r.csl()                         # TopicSize
    tlen = r.cus()
    items = []
    if rtype == 0x23:
        ncol, ttype = r.u8(), r.u8()
        minw = r.s16() if ttype in (0, 2) else None
        cols = [(r.s16(), r.s16()) for _ in range(ncol)]
        items.append(('table', ttype, minw, cols))
    t = Reader(ld2)
    while True:
        para = parse_para(r, rtype)
        items.append(('para', para))
        if para.get('column') == -1:
            break
        while True:
            if t.p < len(ld2):
                s = t.sz()
                if s:
                    items.append(('text', s))
            c = r.u8()
            if c == 0xFF:
                break
            if c == 0x20:
                items.append(('cmd', 'vfld', r.s32()))
            elif c == 0x21:
                items.append(('cmd', 'dtype', r.s16()))
            elif c == 0x80:
                items.append(('cmd', 'font', r.s16()))
            elif c == 0x81:
                items.append(('cmd', 'line', None))
            elif c == 0x82:
                items.append(('cmd', 'par', None))
            elif c == 0x83:
                items.append(('cmd', 'tab', None))
            elif c in (0x86, 0x87, 0x88):
                typ = r.u8()
                size = r.csl()
                nhs = r.cus() if typ == 0x22 else 0
                pic = ld1[r.p:r.p + size]
                r.p += size
                pr = Reader(pic)
                emb = pr.s16()
                arg = ('bm%d' % pr.s16()) if typ in (3, 0x22) and emb == 0 else pic.hex()
                items.append(('cmd', {0x86: 'bmc', 0x87: 'bml', 0x88: 'bmr'}[c],
                              (typ, arg, nhs)))
            elif c == 0x89:
                items.append(('cmd', 'endhot', None))
            elif c == 0x8B:
                items.append(('cmd', 'nbsp', None))
            elif c == 0x8C:
                items.append(('cmd', 'nbhyph', None))
            elif c in (0xC8, 0xCC):
                n = r.s16()
                items.append(('cmd', 'macro%02X' % c,
                              ld1[r.p:r.p + n - 3].split(b'\0')[0].decode('latin-1')))
                r.p += n - 3
            elif c in (0xE0, 0xE1, 0xE2, 0xE3, 0xE6, 0xE7):
                items.append(('cmd', 'jump%02X' % c, r.u32()))
            elif c in (0xEA, 0xEB, 0xEE, 0xEF):
                n = r.s16()
                items.append(('cmd', 'xjump%02X' % c, ld1[r.p:r.p + n].hex()))
                r.p += n
            else:
                raise ValueError('unknown formatting command %02X' % c)
        if rtype != 0x23:
            break
    return tlen, items


def read_topics(t):
    """|TOPIC -> list of (topicpos, topicoffset, rtype, data)"""
    blocks = topic_blocks(t)
    pos = struct.unpack_from('<I', t, 4)[0]
    toff = 0
    links = []
    seen = set()
    while pos not in (0, 0xFFFFFFFF) and pos not in seen:
        seen.add(pos)
        hdr = topic_read(blocks, pos, 21)
        if len(hdr) < 21:
            break
        bsize, dlen2, prev, nxt, dlen1, rtype = struct.unpack('<iiIIiB', hdr)
        raw = topic_read(blocks, pos, bsize)
        ld1 = raw[21:dlen1]
        ld2 = raw[dlen1:bsize]
        if rtype == 2:
            th = struct.unpack_from('<iIIiIII', ld1)
            strs = ld2[:dlen2].split(b'\0') if dlen2 else []
            links.append((pos, toff, 2, (th, [s.decode('latin-1') for s in strs])))
        elif rtype in (0x20, 0x23):
            tlen, items = parse_display(ld1, ld2, rtype)
            links.append((pos, toff, rtype, (tlen, items)))
            toff += tlen
        else:
            links.append((pos, toff, rtype, raw))
        if nxt in (0, 0xFFFFFFFF):
            break
        if (nxt - TBHDR) // DECOMPSIZE != (pos - TBHDR) // DECOMPSIZE:
            toff = ((nxt - TBHDR) // DECOMPSIZE) * 0x8000
        pos = nxt
    return links


def dump(path, out=sys.stdout, norm=False):
    """norm: positions resolved to topic numbers, fonts to descriptors"""
    w = out.write
    hf = HelpFile(open(path, 'rb').read())
    links = read_topics(hf.file('|TOPIC'))
    tnum = {}
    hoff = {}
    cur = None
    for i, (pos, toff, rtype, d) in enumerate(links):
        if rtype == 2:
            cur = d[0][3]
            # topic offset: that of the first record of the topic
            hoff[i] = links[i + 1][1] if i + 1 < len(links) else toff
            tnum[hoff[i]] = cur
        tnum.setdefault(toff, cur)
    T = (lambda o: 'T%s' % tnum.get(o, '?%08X' % o) if o != 0xFFFFFFFF else '-') if norm \
        else (lambda o: '%08X' % o)
    w('files: %s\n' % ' '.join(sorted(hf.files)))
    sysd = read_system(hf.file('|SYSTEM'))
    w('system: minor %d flags %d\n' % (sysd['minor'], sysd['flags']))
    for typ, rec in sysd['records']:
        if typ in (1, 2, 4):
            w('  rec %d: %s\n' % (typ, rec.split(b'\0')[0].decode('latin-1')))
        elif typ == 3:
            w('  rec 3: contents %s\n' % T(struct.unpack('<I', rec)[0]))
        elif typ == 6:
            fl = struct.unpack_from('<H', rec)[0]
            typ_, name, cap = (rec[2:12], rec[12:21], rec[21:72])
            vals = struct.unpack_from('<hhhhhII', rec, 72)
            z = lambda s, f: s.split(b'\0')[0].decode('latin-1') if f else '-'
            w('  rec 6: flags %04X type %s name %s caption %s xywh %s max %d '
              'rgb %06X nsr %06X\n' % (fl, z(typ_, fl & 1), z(name, fl & 2),
                                       z(cap, fl & 4),
                                       vals[:4], vals[4], vals[5], vals[6]))
        else:
            w('  rec %d: %s\n' % (typ, rec.hex()))
    faces, descs = read_font(hf.file('|FONT'))
    w('fonts: %s\n' % ', '.join(faces))
    fdesc = ['attr %02X size %d family %d face %s color %s' % dsc for dsc in descs]
    if not norm:
        for i, dsc in enumerate(fdesc):
            w('  font %d: %s\n' % (i, dsc))
    offname = {}
    ctx = read_btree(hf.file('|CONTEXT'), Reader.s32, Reader.u32)
    for h, off in ctx:
        offname.setdefault(off, []).append(h)
    w('contexts: %d\n' % len(ctx))
    m = hf.file('|CTXOMAP')
    if m:
        n = struct.unpack_from('<H', m)[0]
        for i in range(n):
            mid, off = struct.unpack_from('<iI', m, 2 + 8 * i)
            w('  map %d -> %s\n' % (mid, T(off)))
    titles = read_btree(hf.file('|TTLBTREE'), Reader.u32, Reader.sz)
    w('titles: %d\n' % len(titles))
    kw = []
    if hf.file('|KWBTREE'):
        kwd = hf.file('|KWDATA')
        for k, (cnt, off) in read_btree(hf.file('|KWBTREE'), Reader.sz,
                                       lambda r: (r.u16(), r.u32())):
            offs = struct.unpack_from('<%dI' % cnt, kwd, off)
            kw.append((k, offs))
    w('keywords: %d\n' % len(kw))
    for k, offs in kw:
        w('  K %s: %s\n' % (k, ' '.join(T(o) for o in offs)))
    for name in sorted(hf.files):
        if name.startswith('|bm'):
            b = hf.file(name)
            w('  %s: %d bytes %s\n' % (name, len(b), b[:24].hex()))
    for i, (pos, toff, rtype, d) in enumerate(links):
        if rtype == 2:
            toff = hoff[i]
            th, strs = d
            if norm:
                w('TOPIC %d: %s\n' % (th[3], strs))
                w('  browse %s %s nonscroll %s ctx %s\n'
                  % (T(th[1]), T(th[2]), th[4] != 0xFFFFFFFF,
                     ' '.join('%08X' % (h & 0xFFFFFFFF) for h in sorted(offname.get(toff, [])))))
                continue
            w('TOPIC %d at %08X/%08X: %s\n' % (th[3], pos, toff, strs))
            w('  browse %08X %08X nonscroll %08X scroll %08X next %08X ctx %s\n'
              % (th[1], th[2], th[4], th[5], th[6],
                 ' '.join('%08X' % (h & 0xFFFFFFFF) for h in offname.get(toff, []))))
        elif rtype in (0x20, 0x23):
            tlen, items = d
            if norm:
                w(' REC\n')
            else:
                w(' REC %02X at %08X/%08X len %d\n' % (rtype, pos, toff, tlen))
            for it in items:
                if it[0] == 'para':
                    w('  para %s\n' % ' '.join('%s=%s' % kv for kv in sorted(it[1].items())))
                elif it[0] == 'text':
                    w('  text %r\n' % it[1])
                elif it[0] == 'table':
                    w('  table type %d minw %s cols %s\n' % it[1:])
                elif norm and it[1] == 'font':
                    w('  font %s\n' % (fdesc[it[2]] if it[2] < len(fdesc) else it[2]))
                else:
                    w('  %s %s\n' % (it[1], '' if it[2] is None else
                                     ('%08X' % it[2] if it[1].startswith('jump') else it[2])))
        else:
            w(' REC %02X at %08X: %d bytes\n' % (rtype, pos, len(d)))


# --- writing: compressed values -----------------------------------------

def e_css(v):
    if -64 <= v < 64:
        return bytes([(v + 64) * 2])
    return struct.pack('<H', ((v + 0x4000) * 2 + 1) & 0xFFFF)


def e_cus(v):
    if v < 128:
        return bytes([v * 2])
    return struct.pack('<H', v * 2 + 1)


def e_csl(v):
    if -0x4000 <= v < 0x4000:
        return struct.pack('<H', (v + 0x4000) * 2)
    return struct.pack('<I', ((v + 0x40000000) * 2 + 1) & 0xFFFFFFFF)


def e_cul(v):
    if v < 0x8000:
        return struct.pack('<H', v * 2)
    return struct.pack('<I', v * 2 + 1)


def twips(t):
    """RTF twips -> help file units (HC31: (t + 5) / 10 truncated)"""
    return int((t + 5) / 10)


# --- RTF ------------------------------------------------------------------

SKIPDEST = {'fonttbl', 'colortbl', 'stylesheet', 'info', 'header', 'headerl',
            'headerr', 'headerf', 'footer', 'footerl', 'footerr', 'footerf',
            'pict', 'object', 'pn', 'pntext', 'pntxta', 'pntxtb', 'fldinst',
            'template', 'listtable', 'listoverridetable', 'revtbl', 'xe', 'tc',
            'bkmkstart', 'bkmkend', 'filetbl', 'rsidtbl', 'generator'}

CDEF = {'f': 0, 'fs': 24, 'b': 0, 'i': 0, 'ul': 0, 'uldb': 0, 'v': 0,
        'strike': 0, 'scaps': 0, 'cf': 0}
PDEF = {'sb': 0, 'sa': 0, 'sl': 0, 'li': 0, 'ri': 0, 'fi': 0, 'align': '',
        'keepn': 0, 'tabs': (), 'border': 0, 'brdrw': 0}


class Para:
    def __init__(self, pfmt):
        self.pfmt = pfmt
        self.items = []          # ('text', s, cfmt) ('tab', cfmt) ('line', cfmt)
        self.endfmt = None       # character format of the paragraph mark


class Topic:
    def __init__(self):
        self.contexts = []
        self.title = None
        self.keywords = []
        self.browse = None
        self.macros = []
        self.paras = []


class RtfReader:
    def __init__(self, data, name):
        self.d = data
        self.name = name
        self.fonts = {}          # number -> (name, family)
        self.colors = []
        self.deff = 0

    def tokens(self):
        d = self.d
        i, n = 0, len(d)
        while i < n:
            c = d[i]
            if c == '{' or c == '}':
                yield (c,)
                i += 1
            elif c == '\\':
                m = re.match(r"\\([a-zA-Z]+)(-?\d+)? ?", d[i:i + 64])
                if m:
                    yield ('w', m.group(1), None if m.group(2) is None else int(m.group(2)))
                    i += m.end()
                elif d[i + 1:i + 2] == "'":
                    yield ('t', chr(int(d[i + 2:i + 4], 16)))
                    i += 4
                elif d[i + 1:i + 2] in ('\r', '\n'):
                    yield ('w', 'par', None)
                    i += 2
                else:
                    yield ('s', d[i + 1])
                    i += 2
            elif c in '\r\n':
                i += 1
            else:
                j = i
                while j < n and d[j] not in '{}\\\r\n':
                    j += 1
                yield ('t', d[i:j])
                i = j

    def parse(self):
        """-> list of Topic"""
        topics = [Topic()]
        cfmt = dict(CDEF)
        pfmt = dict(PDEF)
        stack = []
        dest = None              # None = body, else name of destination
        tabpending = 0
        para = Para(None)
        fnote = None             # [marker, text] while in a footnote
        skipsp = False
        fonttbl = None
        colortbl = None
        field = None
        brdr = 0
        border_side = 0

        def topic():
            return topics[-1]

        def addtext(t):
            nonlocal skipsp
            if skipsp:
                t = t.lstrip(' ')
                if not t:
                    return
                skipsp = False
            para.items.append(('text', t, tuple(sorted(cfmt.items()))))

        def endpara(mark=True):
            nonlocal para
            merged = []
            for it in para.items:
                if merged and it[0] == 'text' and merged[-1][0] == 'text' \
                        and merged[-1][2] == it[2]:
                    merged[-1] = ('text', merged[-1][1] + it[1], it[2])
                else:
                    merged.append(it)
            para.items = merged
            para.pfmt = tuple(sorted(pfmt.items()))
            para.endfmt = tuple(sorted(cfmt.items()))
            if para.items or mark:
                topic().paras.append(para)
            para = Para(None)

        for tok in self.tokens():
            k = tok[0]
            if k == '{':
                stack.append((dict(cfmt), dest, fnote is not None))
                continue
            if k == '}':
                if not stack:
                    break
                prevdest = dest
                cfmt, dest, infn = stack.pop()
                if fnote is not None and not infn:
                    self.footnote(topic(), fnote)
                    fnote = None
                    skipsp = True
                if prevdest == 'fonttbl' and dest != 'fonttbl' and fonttbl:
                    fonttbl = None
                continue
            if dest == 'skip':
                continue
            if dest == 'fonttbl':
                if k == 'w':
                    w, a = tok[1], tok[2]
                    if w == 'f':
                        fonttbl = [a, 'nil', '']
                        self.fonts[a] = ('', 'nil')
                    elif w.startswith('f') and w[1:] in ('nil', 'roman', 'swiss', 'modern', 'script', 'decor', 'tech'):
                        if fonttbl:
                            fonttbl[1] = w[1:]
                    elif w == 'fonttbl':
                        pass
                elif k == 't' and fonttbl:
                    fonttbl[2] += tok[1]
                    nm = fonttbl[2].split(';')[0].strip()
                    self.fonts[fonttbl[0]] = (nm, fonttbl[1])
                continue
            if dest == 'colortbl':
                if k == 'w' and tok[1] in ('red', 'green', 'blue'):
                    colortbl[{'red': 0, 'green': 1, 'blue': 2}[tok[1]]] = tok[2]
                elif k == 't' and ';' in tok[1]:
                    for _ in range(tok[1].count(';')):
                        self.colors.append(tuple(colortbl))
                        colortbl = [0, 0, 0]
                continue
            if k == 'w':
                w, a = tok[1], tok[2]
                if w == 'fonttbl':
                    dest = 'fonttbl'
                elif w == 'colortbl':
                    dest = 'colortbl'
                    colortbl = [0, 0, 0]
                elif w in SKIPDEST:
                    dest = 'skip'
                elif w == 'deff':
                    self.deff = a
                elif w == 'footnote':
                    marker = ''
                    if para.items and para.items[-1][0] == 'text':
                        t = para.items[-1][1]
                        marker = t[-1]
                        if len(t) > 1:
                            para.items[-1] = ('text', t[:-1], para.items[-1][2])
                        else:
                            para.items.pop()
                    fnote = [marker, '']
                    dest = 'footnote'
                elif dest == 'footnote':
                    if w == 'tab':
                        fnote[1] += ' '
                    continue
                elif w == 'plain':
                    cfmt = dict(CDEF)
                    cfmt['f'] = self.deff
                elif w in ('b', 'i', 'v', 'strike', 'scaps', 'uldb'):
                    cfmt[w] = 0 if a == 0 else 1
                elif w in ('ul', 'uld', 'ulw', 'uldash', 'ulth'):
                    cfmt['ul'] = 0 if a == 0 else 1
                elif w == 'ulnone':
                    cfmt['ul'] = cfmt['uldb'] = 0
                elif w in ('f', 'fs', 'cf'):
                    cfmt[w] = a
                elif w == 'pard':
                    pfmt = dict(PDEF)
                    border_side = 0
                elif w in ('sb', 'sa', 'sl', 'li', 'ri', 'fi'):
                    pfmt[w] = a or 0
                elif w == 'qc':
                    pfmt['align'] = 'c'
                elif w == 'qr':
                    pfmt['align'] = 'r'
                elif w in ('ql', 'qj'):
                    pfmt['align'] = ''
                elif w == 'keepn':
                    pfmt['keepn'] = 1
                elif w in ('tqr', 'tqc'):
                    tabpending = 1 if w == 'tqr' else 2
                elif w == 'tx':
                    pfmt['tabs'] = pfmt['tabs'] + ((a, tabpending),)
                    tabpending = 0
                elif w in ('box', 'brdrt', 'brdrl', 'brdrb', 'brdrr'):
                    border_side = {'box': 1, 'brdrt': 2, 'brdrl': 4, 'brdrb': 8, 'brdrr': 16}[w]
                    pfmt['border'] |= border_side
                elif w == 'brdrth' and border_side:
                    pfmt['border'] |= 0x20
                elif w == 'brdrdb' and border_side:
                    pfmt['border'] |= 0x40
                elif w == 'brdrw' and border_side:
                    pfmt['brdrw'] = a
                elif w == 'par':
                    endpara()
                elif w == 'page':
                    if para.items:
                        endpara()
                    topics.append(Topic())
                elif w == 'tab':
                    para.items.append(('tab', tuple(sorted(cfmt.items()))))
                elif w == 'line':
                    para.items.append(('line', tuple(sorted(cfmt.items()))))
                elif w in ('lquote', 'rquote', 'ldblquote', 'rdblquote', 'bullet', 'endash', 'emdash'):
                    addtext({'lquote': '\x91', 'rquote': '\x92', 'ldblquote': '\x93',
                             'rdblquote': '\x94', 'bullet': '\x95', 'endash': '\x96',
                             'emdash': '\x97'}[w])
                continue
            if k == 's':
                c = tok[1]
                if c == '*':
                    dest = 'skip'
                elif dest == 'footnote':
                    if c in '\\{}':
                        fnote[1] += c
                elif c in '\\{}':
                    addtext(c)
                elif c == '~':
                    addtext('\xa0')
                elif c == '_':
                    addtext('-')
                continue
            if k == 't':
                if dest == 'footnote':
                    fnote[1] += tok[1]
                else:
                    addtext(tok[1])
        if para.items:
            endpara()
        return topics

    def footnote(self, topic, fn):
        marker, text = fn
        sp = ' \t'
        text = text.strip(sp)
        if text[:1] == marker:
            text = text[1:].strip(sp)
        if marker == '#':
            topic.contexts += [c.strip(sp) for c in text.split(';') if c.strip(sp)]
        elif marker == '$':
            topic.title = text
        elif marker == 'K':
            topic.keywords += [k.strip(sp) for k in text.split(';') if k.strip(sp)]
        elif marker == '+':
            topic.browse = text
        elif marker == '!':
            topic.macros.append(text)


# --- help project ---------------------------------------------------------

def read_hpj(path, defines=()):
    """-> {section: [lines]} (#include/INCLUDE and #ifdef handled)"""
    base = os.path.dirname(path)
    secs = {}
    cur = [None]

    def find(name):
        for start in (base or '.', '.'):
            p = start
            for part in name.split('/'):
                hit = [e for e in os.listdir(p) if e.lower() == part.lower()] \
                    if os.path.isdir(p) else []
                if not hit:
                    p = None
                    break
                p = os.path.join(p, hit[0])
            if p:
                return p
        raise FileNotFoundError(name)

    def rd(p):
        cond = []
        for ln in open(p, 'rb').read().decode('cp850').splitlines():
            s = ln.strip()
            m = re.match(r'#\s*(ifdef|ifndef)\s+(\w+)', s)
            if m:
                cond.append((m.group(2) in defines) == (m.group(1) == 'ifdef'))
                continue
            if re.match(r'#\s*else', s):
                cond[-1] = not cond[-1]
                continue
            if re.match(r'#\s*endif', s):
                cond.pop()
                continue
            if not all(cond):
                continue
            m = re.match(r'(?:#\s*include|INCLUDE)\s*[<"]([^>"]+)[>"]', s, re.I)
            if m:
                rd(find(m.group(1).replace('\\', '/')))
                continue
            m = re.match(r'\[(\w+)\]', s)
            if m:
                cur[0] = m.group(1).upper()
                secs.setdefault(cur[0], [])
                continue
            if cur[0] is not None:
                secs[cur[0]].append(ln)

    rd(path)
    return secs


def hpj_options(lines):
    opt = {}
    for ln in lines:
        s = ln.split(';')[0].strip() if not ln.strip().upper().startswith('COPYRIGHT') else ln.strip()
        if '=' in s:
            k, v = s.split('=', 1)
            opt[k.strip().upper()] = v.strip()
    return opt


def hpj_map(lines):
    out = []
    for ln in lines:
        s = re.split(r';|//', ln)[0].strip()
        if not s:
            continue
        m = re.match(r'#\s*define\s+(\S+)\s+(\S+)', s)
        if m:
            name, val = m.group(1), m.group(2)
        else:
            parts = re.split(r'[\s=]+', s)
            if len(parts) < 2:
                continue
            name, val = parts[0], parts[1]
        out.append((name, int(val, 0)))
    return out


def hpj_alias(lines):
    out = {}
    for ln in lines:
        s = ln.split(';')[0].strip()
        if '=' in s:
            a, b = s.split('=', 1)
            out[a.strip().lower()] = b.strip()
    return out


def hpj_window(line):
    """main="caption", (x,y,w,h), max, (rgb), (rgb), ontop"""
    name, rest = line.split('=', 1)
    name = name.strip()
    parts = []
    depth, cur, q = 0, '', False
    for c in rest:
        if c == '"':
            q = not q
        if c == '(' and not q:
            depth += 1
        if c == ')' and not q:
            depth -= 1
        if c == ',' and depth == 0 and not q:
            parts.append(cur.strip())
            cur = ''
        else:
            cur += c
    parts.append(cur.strip())
    parts += [''] * (6 - len(parts))
    flags = 0x0001 | 0x0002
    cap = parts[0].strip('"')
    if parts[0]:
        flags |= 0x0004
    xywh = [0, 0, 0, 0]
    if parts[1]:
        v = [int(x) if x.strip() else None for x in parts[1].strip('()').split(',')]
        for i, x in enumerate(v[:4]):
            if x is not None:
                xywh[i] = x
                flags |= 0x0008 << i
    mx = 0
    if parts[2]:
        mx = int(parts[2], 0)
        flags |= 0x0080
    rgb = [0, 0]
    for i in (0, 1):
        if parts[3 + i]:
            r, g, b = [int(x) for x in parts[3 + i].strip('()').split(',')]
            rgb[i] = r | g << 8 | b << 16
            flags |= 0x0100 << i
    if parts[5] and int(parts[5]):
        flags |= 0x0400
    pad = lambda s, n: s.encode('latin-1')[:n - 1].ljust(n, b'\0')
    return (struct.pack('<H', flags) + pad(name, 10) + pad(name, 9) + pad(cap, 51)
            + struct.pack('<hhhhhII', *xywh, mx, rgb[0], rgb[1]))


# --- pictures ---------------------------------------------------------------

def rle(data):
    out = bytearray()
    i, n = 0, len(data)
    lit = bytearray()

    def flush():
        while lit:
            chunk = lit[:127]
            out.append(0x80 | len(chunk))
            out.extend(chunk)
            del lit[:127]

    while i < n:
        j = i
        while j < n and j - i < 127 and data[j] == data[i]:
            j += 1
        if j - i >= 3:
            flush()
            out += bytes([j - i, data[i]])
            i = j
        else:
            lit.append(data[i])
            i += 1
    flush()
    return bytes(out)


def bmp_to_lp(bmp):
    """Windows .BMP -> help picture (lp format, DIB, run length packed)"""
    if bmp[:2] != b'BM':
        raise ValueError('not a BMP file')
    off = struct.unpack_from('<I', bmp, 10)[0]
    (hsize, w, h, planes, bits, comp, isize, xppm, yppm, used,
     important) = struct.unpack_from('<IiiHHIIiiII', bmp, 14)
    if hsize != 40 or comp != 0:
        raise ValueError('unsupported BMP format')
    ncol = used or (1 << bits if bits <= 8 else 0)
    pal = bmp[14 + hsize:14 + hsize + 4 * ncol]
    rowlen = ((w * bits + 31) // 32) * 4
    pix = bmp[off:off + rowlen * abs(h)]
    packed = rle(pix)
    dpi = lambda ppm: round(ppm * 0.0254) if ppm else 96
    hdr = (bytes([6, 1]) + e_cul(dpi(xppm)) + e_cul(dpi(yppm)) + e_cus(planes)
           + e_cus(bits) + e_cul(w) + e_cul(abs(h)) + e_cul(ncol) + e_cul(0)
           + e_cul(len(packed)) + e_cul(0))
    dataoff = len(hdr) + 8 + len(pal)
    pic = hdr + struct.pack('<II', dataoff, 0) + pal + packed
    return struct.pack('<HHI', 0x706C, 1, 8) + pic


# --- topics -> |TOPIC -------------------------------------------------------

class Fonts:
    FAM = {'modern': 1, 'roman': 2, 'swiss': 3, 'tech': 3, 'nil': 3,
           'script': 4, 'decor': 5}

    def __init__(self, rtf):
        self.rtf = rtf
        self.faces = []
        self.descs = []
        self.index = {}

    def get(self, cfmt, hot=False):
        c = dict(cfmt)
        name, fam = self.rtf.fonts.get(c['f'], ('Arial', 'swiss'))
        attr = (c['b'] and 1) | (c['i'] and 2) | (c['strike'] and 8) | (c['scaps'] and 0x20)
        if not hot:
            attr |= (c['ul'] and 4) | (c['uldb'] and 0x10)
        cf = c['cf']
        rgb = bytes(self.rtf.colors[cf]) if 0 < cf < len(self.rtf.colors) else b'\x01\x01\x00'
        if name not in self.faces:
            self.faces.append(name)
        key = (attr, c['fs'] or 24, self.FAM.get(fam, 3), self.faces.index(name), rgb)
        if key not in self.index:
            self.index[key] = len(self.descs)
            self.descs.append(key)
        return self.index[key]

    def build(self):
        fl = 20
        faces = b''.join(f.encode('latin-1')[:fl - 1].ljust(fl, b'\0') for f in self.faces)
        descs = b''.join(struct.pack('<BBBH', a, hp, fam, face) + rgb + b'\x01\x01\x00'
                         for a, hp, fam, face, rgb in self.descs)
        return struct.pack('<HHHH', len(self.faces), len(self.descs), 8,
                           8 + len(faces)) + faces + descs


BMRE = re.compile(r'\{(bm[clr])t? +([^}]+)\}', re.I)


class Encoder:
    """paragraphs with equal format -> one display record (0x20)"""

    def __init__(self, fonts, pics, warn):
        self.fonts = fonts
        self.pics = pics
        self.warn = warn

    def start(self, pfmt):
        self.pfmt = dict(pfmt)
        self.strs = ['']
        self.cmds = []
        self.font = None
        self.npics = 0

    def cmd(self, b):
        self.cmds.append(b)
        self.strs.append('')

    def setfont(self, fnt):
        if fnt != self.font:
            self.cmd(b'\x80' + struct.pack('<h', fnt))
            self.font = fnt

    def text(self, t, fnt):
        self.setfont(fnt)
        self.strs[-1] += t

    def para(self, p):
        items = hotspots(p.items)
        for it in items:
            if it[0] == 'text':
                self.vtext(it[1], it[2])
            elif it[0] in ('tab', 'line'):
                self.setfont(self.fonts.get(it[1]))
                self.cmd(b'\x83' if it[0] == 'tab' else b'\x81')
            elif it[0] == 'hot':
                kind, target, runs = it[1], it[2], it[3]
                self.cmd(bytes([0xE2 if kind == 'popup' else 0xE3])
                         + struct.pack('<i', ctxhash(target)))
                for r in runs:
                    if r[0] == 'text':
                        self.vtext(r[1], r[2], hot=True)
                    elif r[0] == 'tab':
                        self.setfont(self.fonts.get(r[1], True))
                        self.cmd(b'\x83')
                self.cmd(b'\x89')
        self.setfont(self.fonts.get(p.endfmt))
        self.cmd(b'\x82')

    def vtext(self, t, cfmt, hot=False):
        pos = 0
        for m in BMRE.finditer(t):
            if m.start() > pos:
                self.text(t[pos:m.start()], self.fonts.get(cfmt, hot))
            n = self.pics(m.group(2).strip())
            if n is not None:
                self.setfont(self.fonts.get(cfmt, hot))
                kind = {'bmc': 0x86, 'bml': 0x87, 'bmr': 0x88}[m.group(1).lower()]
                self.cmd(bytes([kind, 0x22]) + e_csl(4) + e_cus(1) + struct.pack('<hh', 0, n))
                self.npics += 1
            pos = m.end()
        if pos < len(t):
            self.text(t[pos:], self.fonts.get(cfmt, hot))

    def size(self):
        """formatting commands and strings so far (HC31 starts a new
        record after a paragraph when this reaches 482)"""
        return sum(len(c) for c in self.cmds) + sum(len(s) + 1 for s in self.strs)

    def finish(self):
        self.cmds.append(b'\xFF')
        ld2 = b''.join(s.encode('latin-1') + b'\0' for s in self.strs)
        p = self.pfmt
        bits = 0
        vals = b''
        for bit, k in ((0x02, 'sb'), (0x04, 'sa'), (0x08, 'sl'), (0x10, 'li'),
                       (0x20, 'ri'), (0x40, 'fi')):
            if p[k]:
                bits |= bit
                vals += e_css(twips(p[k]))
        if p['border']:
            bits |= 0x100
            vals += bytes([p['border'] or 1]) + struct.pack('<h', twips(p['brdrw']))
        if p['tabs']:
            bits |= 0x200
            vals += e_css(len(p['tabs']))
            for pos, typ in p['tabs']:
                v = twips(pos) & 0x3FFF
                vals += e_cus(v | 0x4000) + e_cus(typ) if typ else e_cus(v)
        if p['align'] == 'r':
            bits |= 0x400
        elif p['align'] == 'c':
            bits |= 0x800
        rest = bytes([0, 0x80]) + struct.pack('<HH', 0, bits) + vals + b''.join(self.cmds)
        tlen = len(ld2) + self.npics
        # TopicSize counts the data after itself and TopicLength
        ld1 = e_csl(len(rest)) + e_cus(tlen) + rest
        return ld1, ld2, tlen


def hotspots(items):
    """underlined runs followed by hidden text -> ('hot', kind, target, runs)"""
    out = []
    i = 0
    while i < len(items):
        it = items[i]
        f = dict(it[-1])
        if it[0] == 'text' and f['v']:
            target = ''
            while i < len(items) and items[i][0] == 'text' and dict(items[i][2])['v']:
                target += items[i][1]
                i += 1
            run = []
            while out and out[-1][0] in ('text', 'tab') and (
                    dict(out[-1][-1])['ul'] or dict(out[-1][-1])['uldb']
                    or dict(out[-1][-1])['strike']):
                run.insert(0, out.pop())
            target = target.strip()
            if run and target:
                kind = 'jump' if any(dict(r[-1])['uldb'] or dict(r[-1])['strike'] for r in run) else 'popup'
                out.append(('hot', kind, target, run))
            else:
                out += run
            continue
        out.append(it)
        i += 1
    return out


def pos_of(off):
    return (off // (BLOCKSIZE - TBHDR)) * DECOMPSIZE + TBHDR + off % (BLOCKSIZE - TBHDR)


def build_topic_file(topics, enc):
    """-> (|TOPIC bytes, list of topic offsets, terminator offset)"""
    recs = []                    # [rtype, ld1, ld2, tlen, topic index]
    for ti, t in enumerate(topics):
        recs.append([2, None, None, 0, ti])
        groups = []
        for p in t.paras:
            groups.append(p)
        cur = None
        for p in groups:
            key = (p.pfmt,)
            if cur is not None and (cur[0] != key or enc.size() >= 482):
                ld1, ld2, tl = enc.finish()
                recs.append([0x20, ld1, ld2, tl, ti, cur[1]])
                cur = None
            if cur is None:
                enc.start(dict(p.pfmt))
                cur = (key, dict(p.pfmt)['keepn'])
            enc.para(p)
        if cur is not None:
            ld1, ld2, tl = enc.finish()
            recs.append([0x20, ld1, ld2, tl, ti, cur[1]])
    recs.append([2, None, None, 0, len(topics)])          # terminator
    # layout: stream offsets (a link header never crosses a block)
    off = 0
    starts = []
    for r in recs:
        size = 21 + (28 + len(topics[r[4]].title or '') if r[0] == 2 and r[4] < len(topics) else 0)
        if r[0] == 2:
            t = topics[r[4]] if r[4] < len(topics) else None
            ld2 = b'' if t is None else '\0'.join([t.title or ''] + t.macros).encode('latin-1')
            if t is not None and not t.title and not t.macros:
                ld2 = b''
            r[2] = ld2
            size = 21 + 28 + len(ld2)
        else:
            size = 21 + len(r[1]) + len(r[2])
        room = (BLOCKSIZE - TBHDR) - off % (BLOCKSIZE - TBHDR)
        if room < 21:
            off += room
        starts.append(off)
        off += size
    total = off
    pos = [pos_of(o) for o in starts]
    # topic offsets
    toffs = []
    blk = -1
    cnt = 0
    for r, o in zip(recs, starts):
        b = o // (BLOCKSIZE - TBHDR)
        if b != blk:
            blk, cnt = b, 0
        toffs.append(b * 0x8000 + cnt)
        cnt += r[3]
    hdr_idx = [i for i, r in enumerate(recs) if r[0] == 2]
    # a topic's offset is that of its first record (the next block's
    # start when that record begins in the next block)
    topic_toff = [toffs[i + 1] if i + 1 < len(recs) else toffs[i] for i in hdr_idx]
    # browse sequences
    seqs = {}
    for ti, t in enumerate(topics):
        if t.browse is not None:
            g, _, minor = t.browse.rpartition(':') if ':' in t.browse else ('', '', t.browse)
            seqs.setdefault(g, []).append((minor, ti))
    bck = [-1] * len(topics)
    fwd = [-1] * len(topics)
    for g, lst in seqs.items():
        lst.sort(key=lambda x: x[0].lower())
        for (a, ta), (b, tb) in zip(lst, lst[1:]):
            fwd[ta] = topic_toff[tb]
            bck[tb] = topic_toff[ta]
    # encode links
    stream = bytearray(total)
    for k, (r, o) in enumerate(zip(recs, starts)):
        prev = pos[k - 1] if k else 0xFFFFFFFF
        nxt = pos[k + 1] if k + 1 < len(recs) else 0xFFFFFFFF
        if r[0] == 2:
            ti = r[4]
            nh = hdr_idx.index(k)
            if ti < len(topics):
                mine = [j for j in range(k + 1, hdr_idx[nh + 1])]
                ns = [pos[j] for j in mine if recs[j][5]]
                sc = [pos[j] for j in mine if not recs[j][5]]
                size = sum(21 + len(recs[j][1]) + len(recs[j][2]) for j in mine)
                ld1 = struct.pack('<iIIiIII', size + 21 + 28 + len(r[2]),
                                  bck[ti] & 0xFFFFFFFF, fwd[ti] & 0xFFFFFFFF, ti,
                                  ns[0] if ns else 0xFFFFFFFF,
                                  sc[0] if sc else 0xFFFFFFFF, pos[hdr_idx[nh + 1]])
            else:
                ld1 = struct.pack('<iIIiIII', 24, 0xFFFFFFFF, 0xFFFFFFFF, ti,
                                  0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF)
                nxt = 0xFFFFFFFF
            ld2 = r[2]
        else:
            ld1, ld2 = r[1], r[2]
        link = struct.pack('<iiIIiB', 21 + len(ld1) + len(ld2), len(ld2), prev, nxt,
                           21 + len(ld1), r[0]) + ld1 + ld2
        stream[o:o + len(link)] = link
    # blocks
    dsz = BLOCKSIZE - TBHDR
    nblk = (total + dsz - 1) // dsz
    out = bytearray()
    for b in range(nblk):
        first = [k for k, o in enumerate(starts) if o // dsz == b]
        before = [k for k, o in enumerate(starts) if o // dsz < b]
        last = pos[before[-1]] if before else 0xFFFFFFFF
        fl = pos[first[0]] if first else 0xFFFFFFFF
        lim = first[0] if first else len(recs)
        hdrs = [k for k in hdr_idx if k < lim]
        lth = pos[hdrs[-1]] if (b and hdrs) else 0
        out += struct.pack('<III', last, fl, lth)
        out += stream[b * dsz:(b + 1) * dsz]
    return bytes(out), topic_toff[:-1], topic_toff[-1]


# --- B+ trees and the file system ---------------------------------------

def btree(entries, struc, pagesize=2048, flags=0x0002):
    """entries: sorted [(leafbytes, indexkeybytes)] -> (data, leaf map)"""
    leaves = []
    cur = []
    used = 8
    for e in entries:
        if cur and used + len(e[0]) > pagesize:
            leaves.append(cur)
            cur, used = [], 8
        cur.append(e)
        used += len(e[0])
    leaves.append(cur)
    pages = []
    for i, lv in enumerate(leaves):
        body = b''.join(e[0] for e in lv)
        pages.append(struct.pack('<Hhhh', pagesize - 8 - len(body), len(lv),
                                 i - 1 if i else -1, i + 1 if i + 1 < len(leaves) else -1)
                     + body)
    levels = 1
    level = [(i, lv[0][1] if lv else b'') for i, lv in enumerate(leaves)]
    while len(level) > 1:
        levels += 1
        nxt = []
        grp = []
        used = 6
        groups = []
        for pg, key in level:
            if grp and used + len(key) + 2 > pagesize:
                groups.append(grp)
                grp, used = [], 6
            grp.append((pg, key))
            used += len(key) + 2
        groups.append(grp)
        for g in groups:
            body = b''.join(k + struct.pack('<h', pg) for pg, k in g[1:])
            pages.append(struct.pack('<Hhh', pagesize - 6 - len(body), len(g) - 1, g[0][0])
                         + body)
            nxt.append((len(pages) - 1, g[0][1]))
        level = nxt
    root = level[0][0]
    hdr = struct.pack('<HHH', 0x293B, flags, pagesize) + struc.encode().ljust(16, b'\0') \
        + struct.pack('<hhhhhhi', 0, 0, root, -1, len(pages), levels, len(entries))
    return hdr + b''.join(p.ljust(pagesize, b'\0') for p in pages), leaves


def write_help(files, path):
    """files: {name: bytes} -> help file"""
    names = sorted(files, key=lambda n: n.encode('latin-1'))
    off = 16
    offs = {}
    body = bytearray()
    for n in names:
        offs[n] = off
        d = files[n]
        body += struct.pack('<IIB', len(d) + 9, len(d), 0) + d
        off += 9 + len(d)
    ents = [(n.encode('latin-1') + b'\0' + struct.pack('<I', offs[n]),
             n.encode('latin-1') + b'\0') for n in names]
    dirb, _ = btree(ents, 'z4', 1024, 0x0402)
    dirhdr = struct.pack('<IIB', len(dirb) + 9, len(dirb), 4)
    total = 16 + len(body) + len(dirhdr) + len(dirb)
    data = struct.pack('<IIiI', 0x00035F3F, 16 + len(body), -1, total) + body + dirhdr + dirb
    open(path, 'wb').write(data)


# --- project helpers (MAKEHELP.BAT of the original build) --------------

def getsect(path, section):
    """lines of one [section] of a help project (GETSECT)"""
    out = []
    cur = None
    for ln in open(path, 'rb').read().decode('latin-1').splitlines():
        m = re.match(r'\s*\[(\w+)\]', ln)
        if m:
            cur = m.group(1).lower()
            continue
        if cur == section.lower():
            out.append(ln)
    while out and not out[-1].strip():
        out.pop()
    return out


HMKINDS = [('Commands (ID_* and IDM_*)', (('ID_', 'HID_', 1), ('IDM_', 'HIDM_', 1))),
           ('Prompts (IDP_*)', (('IDP_', 'HIDP_', 3),)),
           ('Resources (IDR_*)', (('IDR_', 'HIDR_', 2),)),
           ('Dialogs (IDD_*)', (('IDD_', 'HIDD_', 2),)),
           ('Controls (IDC_* and IDW_*)', (('IDC_', 'HIDC_', 5), ('IDW_', 'HIDW_', 5))),
           ('Hit-Tests (IDHT_*)', (('IDHT_', 'HIDHT_', 4),))]


def makehm(header, prefix, hexpre):
    """help map of the resource identifiers of a header (MAKEHLP2.BAT with
    MAKEHM): ID_x -> prefix_HID_x = hexpre<base>0000 + value"""
    defs = []
    for ln in open(header, 'rb').read().decode('latin-1').splitlines():
        m = re.match(r'\s*#\s*define\s+(\w+)\s+(0[xX][0-9a-fA-F]+|\d+)\b', ln)
        if m:
            defs.append((m.group(1), int(m.group(2), 0)))
    out = ['', '', '// Help mappings for %s %s' % (prefix, header), '']
    for title, rules in HMKINDS:
        out.append('// %s' % title)
        for name, val in defs:
            for src, dst, base in rules:
                if name.startswith(src):
                    v = int('%s%d0000' % (hexpre, base), 16) + val
                    out.append('%-40s0x%X' % ('%s_%s%s' % (prefix, dst, name[len(src):]), v))
        out.append('')
    return out

# --- compiler ---------------------------------------------------------------

def compile_project(hpj, out, defines=(), log=sys.stderr):
    warn = lambda msg: log.write('%s: warning: %s\n' % (os.path.basename(hpj), msg))
    secs = read_hpj(hpj, defines)
    base = os.path.dirname(hpj)
    opt = hpj_options(secs.get('OPTIONS', []))

    def find(name, dirs):
        name = name.replace('\\', '/')
        for d in dirs:
            d = d or '.'
            if not os.path.isdir(d):
                continue
            for e in os.listdir(d):
                if e.lower() == os.path.basename(name).lower():
                    return os.path.join(d, e)
        return None

    topics = []
    rtf = None
    for ln in secs.get('FILES', []):
        f = ln.split(';')[0].strip()
        if not f:
            continue
        path = find(f, [base])
        if not path:
            raise FileNotFoundError(f)
        rtf = RtfReader(open(path, 'rb').read().decode('latin-1'), path)
        topics += rtf.parse()
    topics = [t for t in topics if t.paras or t.contexts]
    bmdirs = [base, os.path.join(base, 'BITMAPS'), os.path.join(base, 'bitmaps')]
    for d in opt.get('BMROOT', '').split(','):
        d = d.strip().replace('\\', '/')
        if d:
            bmdirs += [os.path.join(base, d), os.path.join(base, os.path.basename(d))]
    pics = {}
    picdata = []

    def pic(name):
        key = name.lower()
        if key not in pics:
            path = find(name, bmdirs)
            if not path:
                warn('bitmap %s not found' % name)
                return None
            pics[key] = len(picdata)
            picdata.append(bmp_to_lp(open(path, 'rb').read()))
        return pics[key]

    fonts = Fonts(rtf)
    enc = Encoder(fonts, pic, warn)
    topicdata, toff, termoff = build_topic_file(topics, enc)

    ctx = {}
    for t, o in zip(topics, toff):
        for c in t.contexts:
            h = ctxhash(c)
            if h in ctx and ctx[h][1] != o:
                warn('context %s defined twice' % c)
            ctx[h] = (c, o)
    alias = hpj_alias(secs.get('ALIAS', []))
    for a, b in alias.items():
        h = ctxhash(b)
        if h in ctx:
            ctx.setdefault(ctxhash(a), (a, ctx[h][1]))
        else:
            warn('alias %s: context %s not defined' % (a, b))
    actx = ctx
    files = {'|TOPIC': topicdata, '|FONT': fonts.build()}
    # |SYSTEM
    gendate = int(os.environ.get('SOURCE_DATE_EPOCH', '0')) or int(os.path.getmtime(hpj))
    sysd = struct.pack('<HHHIH', 0x036C, 21, 1, gendate, 0)
    rec = lambda typ, d: struct.pack('<HH', typ, len(d)) + d
    sz = lambda s: s.encode('cp1252', 'replace') + b'\0'
    if opt.get('TITLE'):
        sysd += rec(1, sz(opt['TITLE']))
    cont = 0
    if opt.get('CONTENTS'):
        h = ctxhash(opt['CONTENTS'])
        if h in ctx:
            cont = ctx[h][1]
        else:
            warn('contents topic %s not found' % opt['CONTENTS'])
    sysd += rec(3, struct.pack('<I', cont))
    if opt.get('COPYRIGHT'):
        sysd += rec(2, sz(opt['COPYRIGHT']))
    for m in secs.get('CONFIG', []):
        m = m.strip()
        if m and not m.startswith(';'):
            sysd += rec(4, sz(m))
    for w in secs.get('WINDOWS', []):
        w = w.split(';')[0].strip() if not '"' in w else w.strip()
        if '=' in w:
            sysd += rec(6, hpj_window(w))
    files['|SYSTEM'] = sysd
    # |CONTEXT
    ents = [(struct.pack('<iI', h, o), struct.pack('<i', h)) for h, (c, o) in sorted(ctx.items())]
    files['|CONTEXT'], _ = btree(ents, 'L4')
    # |CTXOMAP
    m = hpj_map(secs.get('MAP', []))
    if m:
        cm = struct.pack('<H', len(m))
        for name, val in m:
            h = ctxhash(name)
            o = actx[h][1] if h in actx else 0xFFFFFFFF
            if h not in actx:
                warn('mapped context %s not defined' % name)
            cm += struct.pack('<iI', val, o)
        files['|CTXOMAP'] = cm
    # |TTLBTREE
    szr = lambda s: s.encode('latin-1') + b'\0'
    ents = [(struct.pack('<I', o) + szr(t.title or ''), struct.pack('<I', o))
            for t, o in zip(topics, toff)]
    ents.append((struct.pack('<I', termoff) + b'\0', struct.pack('<I', termoff)))
    files['|TTLBTREE'], _ = btree(ents, 'Lz')
    # keywords
    kws = {}
    for t, o in zip(topics, toff):
        for k in t.keywords:
            lst = kws.setdefault(k.lower(), [k, []])[1]
            if o not in lst:
                lst.append(o)
    if kws:
        kwdata = bytearray()
        ents = []
        for key in sorted(kws):
            k, lst = kws[key]
            ents.append((szr(k) + struct.pack('<HI', len(lst), len(kwdata)), szr(k)))
            kwdata += struct.pack('<%dI' % len(lst), *lst)
        files['|KWBTREE'], leaves = btree(ents, 'i24')
        files['|KWDATA'] = bytes(kwdata)
        km = struct.pack('<H', len(leaves))
        n = 0
        for i, lv in enumerate(leaves):
            km += struct.pack('<Ih', n, i)
            n += len(lv)
        files['|KWMAP'] = km
    for i, d in enumerate(picdata):
        files['|bm%d' % i] = d
    write_help(files, out)
    return len(topics)


def main():
    a = sys.argv[1:]
    if len(a) == 2 and a[0] == 'dump':
        dump(a[1])
        return 0
    if len(a) == 3 and a[0] == 'getsect':
        sys.stdout.write(''.join(l + '\r\n' for l in getsect(a[1], a[2])))
        return 0
    if len(a) == 4 and a[0] == 'makehm':
        sys.stdout.write(''.join(l + '\r\n' for l in makehm(a[1], a[2], a[3])))
        return 0
    if len(a) == 3 and a[0] == 'dump' and a[1] == '-n':
        dump(a[2], norm=True)
        return 0
    if len(a) >= 2 and a[0] == 'build':
        hpj = a[1]
        out = os.path.splitext(hpj)[0] + '.HLP'
        defines = []
        i = 2
        while i < len(a):
            if a[i] == '-o':
                out = a[i + 1]
                i += 2
            elif a[i].startswith('-D'):
                defines.append(a[i][2:])
                i += 1
            else:
                break
        n = compile_project(hpj, out, defines)
        sys.stderr.write('%s: %d topics\n' % (out, n))
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == '__main__':
    sys.exit(main())
