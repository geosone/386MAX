#!/usr/bin/env python3
"""Qualitas INSTALL archives (386MAX.1, 386MAX.2, ...; see INSTALL/PACKAGE.H):
list, extract and create them.  Replaces PACKAGE.EXE of the original build.

    qpack.py list   ARCHIVE.1 [ARCHIVE.2 ...]
    qpack.py extract DESTDIR ARCHIVE.1 [ARCHIVE.2 ...]
    qpack.py create  PREFIX ID FILE...      (PREFIX.1, one extent)

write_archive() also splits the data into extents for floppy disks.

Compressed files use the PKWARE Data Compression Library format
("implode", comp 0 = binary / 1 = ASCII); explode() below follows the
format description in zlib's contrib/blast (Mark Adler); implode() is an
own LZ77 encoder for it.  INSTALL extracts with INSTALL/EXPLODE.C.
"""
import os
import struct
import sys
import time
import zlib

CMP_NONE = 2
HEAD = '<lHHHHBB'               # QFHEAD
HEADSIZE = struct.calcsize(HEAD)
DIRENT = '<lHlLllHBB'           # QDIR without path
DIRSIZE = struct.calcsize(DIRENT)


# --- explode (PKWARE DCL) ----------------------------------------------------

def _huffman(rep):
    """Code length table from the compact representation: each byte holds
    the length (low 4 bits) and repeat count - 1 (high 4 bits).  Returns
    (count[len], symbols in canonical order)."""
    lengths = []
    for b in rep:
        lengths += [b & 15] * ((b >> 4) + 1)
    count = [0] * 14
    for n in lengths:
        count[n] += 1
    offs = [0] * 14
    for n in range(1, 13):
        offs[n + 1] = offs[n] + count[n]
    symbol = [0] * len(lengths)
    for sym, n in enumerate(lengths):
        if n:
            symbol[offs[n]] = sym
            offs[n] += 1
    return count, symbol


LITLEN = [11, 124, 8, 7, 28, 7, 188, 13, 76, 4, 10, 8, 12, 10, 12, 10, 8, 23,
          8, 9, 7, 6, 7, 8, 7, 6, 55, 8, 23, 24, 12, 11, 7, 9, 11, 12, 6, 7,
          22, 5, 7, 24, 6, 11, 9, 6, 7, 22, 7, 11, 38, 7, 9, 8, 25, 11, 8, 11,
          9, 12, 8, 12, 5, 38, 5, 38, 5, 11, 7, 5, 6, 21, 6, 10, 53, 8, 7, 24,
          10, 27, 44, 253, 253, 253, 252, 252, 252, 13, 12, 45, 12, 45, 12, 61,
          12, 45, 44, 173]
LENLEN = [2, 35, 36, 53, 38, 23]
DISTLEN = [2, 20, 53, 230, 247, 151, 248]
BASE = [3, 2, 4, 5, 6, 7, 8, 9, 10, 12, 16, 24, 40, 72, 136, 264]
EXTRA = [0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8]
LITCODE, LENCODE, DISTCODE = _huffman(LITLEN), _huffman(LENLEN), _huffman(DISTLEN)


class _Bits:
    def __init__(self, data):
        self.data, self.pos, self.buf, self.cnt = data, 0, 0, 0

    def bits(self, need):
        while self.cnt < need:
            if self.pos >= len(self.data):
                raise ValueError('out of input')
            self.buf |= self.data[self.pos] << self.cnt
            self.pos += 1
            self.cnt += 8
        val = self.buf & ((1 << need) - 1)
        self.buf >>= need
        self.cnt -= need
        return val

    def decode(self, code):
        """Codes are stored bit-inverted, first bit first"""
        count, symbol = code
        c = first = index = 0
        for n in range(1, 14):
            c |= self.bits(1) ^ 1
            cnt = count[n]
            if c < first + cnt:
                return symbol[index + c - first]
            index += cnt
            first = (first + cnt) << 1
            c <<= 1
        raise ValueError('bad code')


def explode(data):
    s = _Bits(data)
    lit, dict_ = s.bits(8), s.bits(8)
    if lit > 1 or not 4 <= dict_ <= 6:
        raise ValueError('bad header')
    out = bytearray()
    while True:
        if s.bits(1):
            sym = s.decode(LENCODE)
            length = BASE[sym] + s.bits(EXTRA[sym])
            if length == 519:
                return bytes(out)
            extra = 2 if length == 2 else dict_
            dist = (s.decode(DISTCODE) << extra) + s.bits(extra) + 1
            if dist > len(out):
                raise ValueError('distance too far')
            for _ in range(length):
                out.append(out[-dist])
        else:
            out.append(s.decode(LITCODE) if lit else s.bits(8))


# --- implode (PKWARE DCL format, own LZ77 encoder) ---------------------------

def _encoder(code):
    """symbol -> (code bits, length) for writing: the decoder reads the
    bit-inverted code MSB first"""
    count, symbol = code
    enc, c, index = {}, 0, 0
    for n in range(1, 14):
        for k in range(count[n]):
            enc[symbol[index + k]] = (c + k, n)
        index += count[n]
        c = (c + count[n]) << 1
    return enc


LITENC, LENENC, DISTENC = _encoder(LITCODE), _encoder(LENCODE), _encoder(DISTCODE)


class _BitWriter:
    def __init__(self):
        self.out, self.buf, self.cnt = bytearray(), 0, 0

    def bits(self, val, n):
        self.buf |= val << self.cnt
        self.cnt += n
        while self.cnt >= 8:
            self.out.append(self.buf & 0xff)
            self.buf >>= 8
            self.cnt -= 8

    def code(self, enc, sym):
        c, n = enc[sym]
        for i in range(n - 1, -1, -1):
            self.bits(((c >> i) & 1) ^ 1, 1)

    def flush(self):
        if self.cnt:
            self.out.append(self.buf & 0xff)
        return bytes(self.out)


def _matches(data, dictbits=6, chain=48):
    """LZ77 parse: list of (length, distance) or (0, literal byte)"""
    win, maxlen = 1 << (dictbits + 6), 518
    head, prev = {}, [0] * len(data)
    i, n, out = 0, len(data), []

    def insert(j):
        if j + 2 < n:
            h = data[j:j + 3]
            prev[j] = head.get(h, -1)
            head[h] = j

    while i < n:
        best, bdist = 0, 0
        if i + 2 < n:
            j, tries = head.get(data[i:i + 3], -1), chain
            while j >= 0 and i - j <= win and tries:
                if data[j + best] == data[i + best] if i + best < n else False:
                    l = 0
                    while l < maxlen and i + l < n and data[j + l] == data[i + l]:
                        l += 1
                    if l > best:
                        best, bdist = l, i - j
                        if l == maxlen:
                            break
                j, tries = prev[j], tries - 1
        if best < 3 and i + 1 < n:
            # length 2 matches (distance up to 256)
            for d in range(1, min(i, 256) + 1):
                if data[i - d] == data[i] and data[i - d + 1] == data[i + 1]:
                    best, bdist = 2, d
                    break
        if best >= 2:
            out.append((best, bdist))
            for j in range(i, i + best):
                insert(j)
            i += best
        else:
            out.append((0, data[i]))
            insert(i)
            i += 1
    return out


def _encode(tokens, lit, dictbits):
    w = _BitWriter()
    w.bits(lit, 8)
    w.bits(dictbits, 8)
    for length, val in tokens:
        if length:
            w.bits(1, 1)
            sym = next(k for k in range(16) if BASE[k] <= length < BASE[k] + (1 << EXTRA[k]))
            w.code(LENENC, sym)
            w.bits(length - BASE[sym], EXTRA[sym])
            d, extra = val - 1, 2 if length == 2 else dictbits
            w.code(DISTENC, d >> extra)
            w.bits(d & ((1 << extra) - 1), extra)
        else:
            w.bits(0, 1)
            if lit:
                w.code(LITENC, val)
            else:
                w.bits(val, 8)
    # end of stream: length 519
    w.bits(1, 1)
    w.code(LENENC, 15)
    w.bits(519 - BASE[15], EXTRA[15])
    return w.flush()


def implode(data, dictbits=6):
    """Returns the smaller of the binary and the ASCII (coded literal) form"""
    tokens = _matches(data, dictbits)
    return min((_encode(tokens, lit, dictbits) for lit in (0, 1)), key=len)


# --- archives ----------------------------------------------------------------

def read_dir(path):
    d = open(path, 'rb').read()
    crc, dirofs, dlen, ver, fnum, num, ext = struct.unpack_from(HEAD, d, 0)
    files = []
    p = dirofs
    for _ in range(fnum if dirofs else 0):
        nxt, pid, start, date, size, csiz, att, fnum_, comp = struct.unpack_from(DIRENT, d, p)
        name = d[p + DIRSIZE:d.index(b'\0', p + DIRSIZE)].decode('latin-1')
        files.append(dict(next=nxt, id=pid, start=start, date=date, size=size,
                          csiz=csiz, att=att, num=fnum_, comp=comp, path=name))
        p = nxt if nxt else p
    return dict(ver=ver, num=num, ext=ext, files=files)


def extents(paths):
    """Concatenated archive data in extent order, offsets per extent"""
    data = {}
    for p in paths:
        num = struct.unpack_from(HEAD, open(p, 'rb').read(HEADSIZE), 0)[5]
        data[num] = open(p, 'rb').read()
    return data


def file_data(ext, f):
    """Compressed data of a file (QCHEAD crc + data), may span extents
    (the next extent continues after its header)"""
    num, start, need = f['num'], f['start'], f['csiz']   # csiz includes the CRC
    out = b''
    while need:
        d = ext[num]
        chunk = d[start:start + need]
        out += chunk
        need -= len(chunk)
        num, start = num + 1, HEADSIZE
    return out


def dostime_str(t):
    date, tm = t >> 16, t & 0xffff
    return '%04d-%02d-%02d %02d:%02d' % (1980 + (date >> 9), (date >> 5) & 15,
                                         date & 31, tm >> 11, (tm >> 5) & 63)


def cmd_list(paths):
    info = read_dir(paths[0])
    print('version %04x, %d extents, %d files' % (info['ver'], info['ext'], len(info['files'])))
    for f in info['files']:
        print('%-14s id %d ext %d comp %d %8d -> %8d  %s' % (
            f['path'], f['id'], f['num'], f['comp'], f['size'], f['csiz'], dostime_str(f['date'])))


def cmd_extract(dest, paths):
    info = read_dir(paths[0])
    ext = extents(paths)
    os.makedirs(dest, exist_ok=True)
    bad = 0
    for f in info['files']:
        raw = file_data(ext, f)
        crc, data = struct.unpack_from('<l', raw)[0], raw[4:]
        if f['comp'] == CMP_NONE:
            out = data
        else:
            ok = zlib.crc32(data) == crc & 0xffffffff
            out = explode(data)
            if not ok:
                print('%s: CRC of the compressed data differs' % f['path'])
                bad += 1
        if len(out) != f['size']:
            print('%s: size %d, expected %d' % (f['path'], len(out), f['size']))
            bad += 1
        target = os.path.join(dest, f['path'].replace('\\', '/'))
        os.makedirs(os.path.dirname(target) or '.', exist_ok=True)
        open(target, 'wb').write(out)
    print('%d files extracted, %d problems' % (len(info['files']), bad))
    return bad


def dostime(t):
    lt = time.localtime(t)
    date = ((lt.tm_year - 1980) << 9) | (lt.tm_mon << 5) | lt.tm_mday
    tm = (lt.tm_hour << 11) | (lt.tm_min << 5) | (lt.tm_sec // 2)
    return (date << 16) | tm


def write_archive(prefix, items, caps=None):
    """Extents PREFIX.1, PREFIX.2, ... with items [(path, product id)];
    files are imploded (comp 0/1) unless that doesn't make them smaller
    (then stored, CMP_NONE).  caps: the size limits of the extent files
    (the last one repeats; None: one extent).  The directory lies in the
    first extent; returns the extent file names"""
    entries = []
    for path, pid in items:
        raw = open(path, 'rb').read()
        data = implode(raw)
        comp = data[0]                  # 0 binary, 1 ASCII literals
        if len(data) >= len(raw):
            data, comp = raw, CMP_NONE
        entries.append((os.path.basename(path), pid, data, zlib.crc32(data),
                        os.path.getmtime(path), len(raw), comp))
    dirlen = sum(DIRSIZE + len(e[0]) + 1 for e in entries)
    blobs = [struct.pack('<L', e[3]) + e[2] for e in entries]
    cap = lambda n: (caps[min(n - 1, len(caps) - 1)] if caps else 1 << 62)
    # place the data: extent n holds HEADSIZE + data (+ directory in 1);
    # a file never spans extents (like the original disks: the installers
    # read each file from one extent)
    ext = [bytearray()]
    used = HEADSIZE + dirlen
    where = []
    for blob in blobs:
        if used + len(blob) > cap(len(ext)) and used > HEADSIZE:
            ext.append(bytearray())
            used = HEADSIZE
        if used + len(blob) > cap(len(ext)):
            sys.exit('a file is larger than an extent')
        where.append((len(ext), used))
        ext[-1] += blob
        used += len(blob)
    if (HEADSIZE + dirlen) > cap(1):
        sys.exit('directory does not fit into the first extent')
    p = HEADSIZE
    dirdata = b''
    for i, ((name, pid, data, crc, mtime, size, comp), (num, start)) in enumerate(zip(entries, where)):
        size_ent = DIRSIZE + len(name) + 1
        nxt = p + size_ent if i < len(entries) - 1 else 0
        dirdata += struct.pack(DIRENT, nxt, pid, start, dostime(mtime), size,
                               len(data) + 4, 0x20, num, comp) + name.encode('latin-1') + b'\0'
        p += size_ent
    names = []
    for n, body in enumerate(ext, 1):
        if n == 1:
            head = struct.pack(HEAD, 0, HEADSIZE, dirlen, 0x0103, len(entries), 1, len(ext))
            body = dirdata + bytes(body)
        else:
            head = struct.pack(HEAD, 0, 0, 0, 0x0103, 0, n, len(ext))
        name = '%s.%d' % (prefix, n)
        open(name, 'wb').write(head + bytes(body))
        names.append(name)
        print('%s: %d bytes%s' % (name, len(head) + len(body),
                                   ', %d files' % len(entries) if n == 1 else ''))
    return names


def cmd_create(prefix, pid, files):
    write_archive(prefix, [(f, pid) for f in files])


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'list':
        cmd_list(sys.argv[2:])
    elif cmd == 'extract':
        sys.exit(1 if cmd_extract(sys.argv[2], sys.argv[3:]) else 0)
    elif cmd == 'create':
        cmd_create(sys.argv[2], int(sys.argv[3]), sys.argv[4:])
    else:
        sys.exit(__doc__)


main()
