#!/usr/bin/env python3
"""QuickHelp (.HLP) databases of the DOS help: decode and build them.
Replaces Microsoft HELPMAKE in the open source build.

    qhelp.py dump FILE.HLP                 readable dump of the database
    qhelp.py build OUT.HLP HMAKEL.C SOURCE:WIDTH ...
                                           build from the sources (Word RTF
                                           or QuickHelp markup); the
                                           databases are concatenated

The format (signature 'LN', header, topic index, context strings, context
map, keywords, Huffman tree, topics; per topic: decompressed length,
keyword/run-length compression and Huffman coding of lines with style and
link blocks) follows the description in fancidev/DosHelp
(QuickHelp/Serialization/Format.txt, Apache 2.0).

Open 386MAX - GNU General Public License version 3.
"""
import struct
import sys


# --- reading --------------------------------------------------------------

def read_db(data):
    if data[:2] != b'LN':
        raise ValueError('not a QuickHelp database')
    (version, attrs, ctlchar, _, ntopics, nctx, width, npre, name, _,
     o_index, o_ctx, o_map, o_kw, o_huff, o_text, _, _, size) = \
        struct.unpack_from('<HHBBHHHH14sIIIIIIIIII', data, 2)
    db = {'version': version, 'attrs': attrs, 'ctlchar': ctlchar,
          'width': width, 'predefined': npre,
          'name': name.split(b'\0')[0].decode('latin-1'), 'size': size}
    offs = struct.unpack_from('<%dI' % (ntopics + 1), data, o_index)
    ctxs = data[o_ctx:o_map].split(b'\0')[:nctx]
    cmap = struct.unpack_from('<%dH' % nctx, data, o_map)
    kws = []
    if o_kw:
        p, end = o_kw, (o_huff or o_text)
        while p < end:
            n = data[p]
            kws.append(data[p + 1:p + 1 + n])
            p += 1 + n
    tree = None
    if o_huff:
        tree = []
        p = o_huff
        while True:
            w = struct.unpack_from('<H', data, p)[0]
            p += 2
            if w == 0:
                break
            tree.append(w)
    db['keywords'] = kws
    db['huffman'] = tree is not None
    db['contexts'] = [(c.decode('latin-1'), t) for c, t in zip(ctxs, cmap)]
    topics = []
    for i in range(ntopics):
        raw = data[offs[i]:offs[i + 1]]
        topics.append(decode_topic(raw, kws, tree))
    db['topics'] = topics
    return db


def huffman_decode(bits, tree):
    out = bytearray()
    node = 0
    for byte in bits:
        for k in range(7, -1, -1):
            b = (byte >> k) & 1
            node = (tree[node] // 2) if b == 0 else node + 1
            if tree[node] & 0x8000:
                out.append(tree[node] & 0xFF)
                node = 0
    return bytes(out)


def decompress(comp, outlen, kws):
    out = bytearray()
    i = 0
    while len(out) < outlen and i < len(comp):
        c = comp[i]
        i += 1
        if 0x10 <= c <= 0x17:
            idx = ((c & 3) << 8) | comp[i]
            i += 1
            out += kws[idx]
            if c & 4:
                out.append(0x20)
        elif c == 0x18:
            out += b' ' * comp[i]
            i += 1
        elif c == 0x19:
            out += bytes([comp[i]]) * comp[i + 1]
            i += 2
        elif c == 0x1A:
            out.append(comp[i])
            i += 1
        else:
            out.append(c)
    return bytes(out[:outlen])


def decode_topic(raw, kws, tree):
    outlen = struct.unpack_from('<H', raw, 0)[0]
    comp = raw[2:]
    if tree is not None:
        comp = huffman_decode(comp, tree)
    return parse_lines(decompress(comp, outlen, kws))


def parse_lines(binary):
    """binary topic -> [(text, [(start, len, style)], [(start, end, target)])]"""
    lines = []
    p = 0
    while p < len(binary):
        tl = binary[p]
        text = binary[p + 1:p + tl]
        p += tl
        al = binary[p]
        attr = binary[p + 1:p + al]
        p += al
        styles, links = [], []
        q = 0
        pos = 0
        style = 0
        first = True
        while q < len(attr) and attr[q] != 0xFF:
            if first:
                n = attr[q]
                q += 1
                first = False
            else:
                style = attr[q]
                n = attr[q + 1]
                q += 2
            if n:
                styles.append((pos, n, style))
            pos += n
        if q < len(attr) and attr[q] == 0xFF:
            q += 1
            while q < len(attr):
                s, e = attr[q], attr[q + 1]
                q += 2
                z = attr.index(0, q)
                ctx = attr[q:z]
                q = z + 1
                if not ctx:
                    target = '#%d' % struct.unpack_from('<H', attr, q)[0]
                    q += 2
                else:
                    target = ctx.decode('latin-1')
                links.append((s, e, target))
        lines.append((text, styles, links))
    return lines


def dump(db, out=sys.stdout):
    w = out.write
    w('name %s width %d ctlchar %02X attrs %d keywords %d huffman %s\n' % (
        db['name'], db['width'], db['ctlchar'], db['attrs'],
        len(db['keywords']), db['huffman']))
    names = {}
    for c, t in db['contexts']:
        names.setdefault(t, []).append(c)
    for i, lines in enumerate(db['topics']):
        w('=== topic %d: %s\n' % (i, ' '.join(names.get(i, []))))
        for text, styles, links in lines:
            w('| %s\n' % text.decode('cp437'))
            st = [(a, min(n, len(text) - a), c) for a, n, c in styles if c and a < len(text)]
            if st:
                w('  styles %s\n' % ' '.join('%d+%d:%d' % x for x in st))
            if links:
                w('  links %s\n' % ' '.join('%d-%d>%s' % x for x in links))


# --- building: sources ----------------------------------------------------

def hmakel_table(path):
    """the \\'xx translation of HMAKEL.C (bytes 80h-FFh, '?' = unknown)"""
    src = open(path, 'rb').read()
    start = src.index(b'char *xtab')
    end = src.index(b';', start)
    parts = []
    i = src.index(b'=', start)
    while True:
        q = src.find(b'"', i, end)
        if q < 0:
            break
        r = src.index(b'"', q + 1)
        parts.append(src[q + 1:r])
        i = r + 1
    tab = b''.join(parts)
    assert len(tab) == 128, len(tab)
    return tab


class Para:
    def __init__(self):
        self.chars = []          # (byte, style, hidden)
        self.li = self.fi = 0    # indents in twips


def rtf_paragraphs(data, xtab):
    """RTF -> list of Para (only the text in the document body)"""
    paras, cur = [], Para()
    stack = []
    st = {'b': 0, 'i': 0, 'ul': 0, 'v': 0, 'skip': 0}
    i, n = 0, len(data)
    skipwords = (b'fonttbl', b'colortbl', b'stylesheet', b'info', b'pict',
                 b'header', b'footer', b'footnote', b'field', b'object')

    def put(c):
        if st['skip']:
            return
        style = (1 if st['b'] else 0) | (2 if st['i'] else 0) | (4 if st['ul'] else 0)
        cur.chars.append((c, style, st['v']))

    while i < n:
        c = data[i]
        if c == 0x7B:            # {
            stack.append(dict(st))
            i += 1
            if data[i:i + 2] == b'\\*':
                st['skip'] = 1
            continue
        if c == 0x7D:            # }
            if stack:
                st.clear()
                st.update(stack.pop())
            i += 1
            continue
        if c in (0x0D, 0x0A):
            i += 1
            continue
        if c != 0x5C:            # text
            put(c)
            i += 1
            continue
        # control word or symbol
        nxt = data[i + 1:i + 2]
        if nxt == b"'":
            v = int(data[i + 2:i + 4], 16)
            i += 4
            if v >= 0x80:
                t = xtab[v - 0x80]
                v = t if t != 0x3F else v
            put(v)
            continue
        if nxt in (b'\\', b'{', b'}'):
            put(nxt[0])
            i += 2
            continue
        if nxt == b'~':
            put(0x20)
            i += 2
            continue
        if nxt in (b'-', b'_', b'|', b':'):
            if nxt == b'_':
                put(0x2D)
            i += 2
            continue
        if nxt in (b'\r', b'\n'):  # \<newline> = \par
            word, arg = b'par', None
            i += 2
        else:
            j = i + 1
            while j < n and (0x61 <= data[j] <= 0x7A or 0x41 <= data[j] <= 0x5A):
                j += 1
            word = data[i + 1:j]
            k = j
            if k < n and (data[k] == 0x2D or 0x30 <= data[k] <= 0x39):
                k += 1
                while k < n and 0x30 <= data[k] <= 0x39:
                    k += 1
            arg = int(data[j:k]) if k > j else None
            if k < n and data[k] == 0x20:
                k += 1
            i = k
        if word in skipwords:
            st['skip'] = 1
        elif word == b'b':
            st['b'] = 0 if arg == 0 else 1
        elif word == b'i':
            st['i'] = 0 if arg == 0 else 1
        elif word in (b'ul', b'uld', b'uldb', b'ulw'):
            st['ul'] = 0 if arg == 0 else 1
        elif word == b'ulnone':
            st['ul'] = 0
        elif word == b'v':
            st['v'] = 0 if arg == 0 else 1
        elif word == b'plain':
            st.update(b=0, i=0, ul=0, v=0)
        elif word == b'pard':
            cur.li = cur.fi = 0
        elif word == b'li':
            cur.li = arg or 0
        elif word == b'fi':
            cur.fi = arg or 0
        elif word == b'par':
            if not st['skip']:
                paras.append(cur)
                li, fi = cur.li, cur.fi
                cur = Para()
                cur.li, cur.fi = li, fi
        elif word == b'line':
            put(0x0A)
        elif word == b'tab':
            put(0x20)        # (HELPMAKE's tab columns are not reproduced)
    if cur.chars:
        paras.append(cur)
    return paras


def wrap_para(p, width, twips):
    """a paragraph -> lines of (byte, style) and links"""
    # visible characters and the links (hidden text after underlined text)
    vis, links = [], []
    k = 0
    chars = p.chars
    while k < len(chars):
        c, style, hidden = chars[k]
        if hidden:
            j = k
            while j < len(chars) and chars[j][2]:
                j += 1
            target = bytes(x[0] for x in chars[k:j]).strip()
            # the link covers the underlined text right before it
            e = len(vis)
            s = e
            while s > 0 and vis[s - 1][1] & 4:
                s -= 1
            if target and s < e:
                links.append((s, e, target))
            k = j
            continue
        vis.append((c, style))
        k += 1
    first = max(0, (p.li + p.fi) // twips)
    rest = max(0, p.li // twips)
    lines = []
    ind = first
    text = vis
    if not text:
        return [([], [])]
    # words with the spaces after them; a word fits when it and the spaces
    # after it fit in the width (HELPMAKE)
    words = []
    k = 0
    while k < len(text):
        j = k
        while j < len(text) and text[j][0] != 0x20:
            j += 1
        while j < len(text) and text[j][0] == 0x20:
            j += 1
        words.append((k, j))
        k = j
    w = 0
    while w < len(words):
        avail = max(1, width - ind)
        start = words[w][0]
        end = words[w][1]
        w += 1
        while w < len(words) and words[w][1] - start <= avail:
            end = words[w][1]
            w += 1
        if end - start > avail and end == words[w - 1][1]:
            # a single word longer than the line: cut it
            pass
        seg = [(0x20, 0)] * ind + text[start:end]
        while seg and seg[-1][0] == 0x20:   # no trailing spaces
            seg.pop()
        segl = []
        for ls_, le_, t in links:
            if ls_ < end and le_ > start:
                segl.append((max(ls_, start) - start + ind, min(le_, end) - start + ind, t))
        lines.append((seg, segl))
        ind = rest
    return lines


def rtf_topics(data, xtab, width, twips=144):
    topics = []
    cur = None
    for p in rtf_paragraphs(data, xtab):
        txt = bytes(c for c, s, h in p.chars if not h)
        if txt.startswith(b'>>'):
            ctx = txt[2:].strip()
            if cur is not None and not cur[1]:
                cur[0].append(ctx)       # several contexts for one topic
            else:
                cur = ([ctx], [])
                topics.append(cur)
            continue
        if cur is None:
            continue                     # notes before the first context
        for seg, links in wrap_para(p, width, twips):
            cur[1].append((seg, links))
    return topics


def qh_topics(text):
    """QuickHelp markup (.context, .comment, \\b \\i \\u \\p, \\v link \\v)"""
    topics, cur = [], None
    src = text.split(b'\n')
    if src and not src[-1].strip(b'\r\x1a'):
        src.pop()                    # the line break at the end of the file
    for raw in src:
        raw = raw.rstrip(b'\r')
        if raw.startswith(b'.context'):
            ctx = raw[8:].strip()
            if cur is not None and not cur[1]:
                cur[0].append(ctx)
            else:
                cur = ([ctx], [])
                topics.append(cur)
            continue
        if raw.startswith(b'.comment') or cur is None:
            continue
        seg, links = [], []
        style = 0
        k = 0
        extra = 0                    # columns added by tabs so far
        while k < len(raw):
            c = raw[k]
            if c == 0x5C and k + 1 < len(raw):
                d = raw[k + 1:k + 2]
                if d == b'b':
                    style ^= 1; k += 2; continue
                if d == b'i':
                    style ^= 2; k += 2; continue
                if d == b'u':
                    style ^= 4; k += 2; continue
                if d == b'p':
                    style = 0; k += 2; continue
                if d == b'v':
                    j = raw.find(b'\\v', k + 2)
                    if j < 0:
                        j = len(raw)
                    target = raw[k + 2:j]
                    e = len(seg)
                    s = e
                    while s > 0 and seg[s - 1][0] != 0x20:
                        s -= 1
                    links.append((s, e, target))
                    k = j + 2
                    continue
                if d == b'\\':
                    seg.append((0x5C, style)); k += 2; continue
            if c == 0x09:            # tab stops every 8 columns of the source
                n = 8 - ( k + extra ) % 8   # line, markup included (HELPMAKE)
                seg += [(0x20, style)] * n
                extra += n - 1
                k += 1
                continue
            seg.append((c, style))
            k += 1
        cur[1].append((seg, links))
    return topics


# --- building: binary topics and compression -----------------------------

def encode_line(seg, links):
    """one line: text block and attribute block.  The style list is written
    as HELPMAKE does (Microsoft's help engine needs this form): a 0 (empty
    first chunk), then (style, length) pairs, the last normal run left out"""
    text = bytes(c for c, s in seg)
    runs = []
    for c, s in seg:
        if runs and runs[-1][0] == s:
            runs[-1][1] += 1
        else:
            runs.append([s, 1])
    while runs and runs[-1][0] == 0:
        runs.pop()
    attr = bytearray([0])
    for s, cnt in runs:
        while cnt > 0:
            n = min(cnt, 255)
            attr += bytes([s, n])
            cnt -= n
    if links:
        attr.append(0xFF)
        for s, e, t in links:
            attr += bytes([s + 1, e]) + t + b'\0'
    return bytes([len(text) + 1]) + text + bytes([len(attr) + 1]) + attr


def is_wordch(c):
    return 0x30 <= c <= 0x39 or 0x41 <= c <= 0x5A or 0x61 <= c <= 0x7A or c == 0x27


def words_of(data):
    """(start, end) of the words (runs of letters/digits) in data"""
    i, n = 0, len(data)
    while i < n:
        if is_wordch(data[i]) and (i == 0 or not is_wordch(data[i - 1])):
            j = i
            while j < n and is_wordch(data[j]):
                j += 1
            yield i, j
            i = j
        else:
            i += 1


def keywords(bins, maxn=1024):
    """the dictionary: the words that save most (sorted)"""
    count = {}
    for b in bins:
        for i, j in words_of(b):
            if j - i >= 3:
                w = b[i:j]
                count[w] = count.get(w, 0) + 1
    gain = sorted(((c * (len(w) - 2) - (len(w) + 1), w) for w, c in count.items()
                   if c * (len(w) - 2) - (len(w) + 1) > 0), reverse=True)
    return sorted(w for g, w in gain[:maxn])


def rle(data, kwidx=None):
    out = bytearray()
    i = 0
    starts = {}
    if kwidx:
        for a, b in words_of(data):
            if data[a:b] in kwidx:
                starts[a] = b
    while i < len(data):
        if i in starts:              # dictionary word (and a space after it)
            b = starts[i]
            idx = kwidx[data[i:b]]
            sp = b < len(data) and data[b] == 0x20 and not (b + 1 < len(data) and data[b + 1] == 0x20)
            out += bytes([0x10 | (4 if sp else 0) | (idx >> 8), idx & 0xFF])
            i = b + (1 if sp else 0)
            continue
        c = data[i]
        j = i
        while j < len(data) and data[j] == c and j - i < 255:
            j += 1
        run = j - i
        if c == 0x20 and run >= 3:
            out += bytes([0x18, run]); i = j; continue
        if run >= 4:
            out += bytes([0x19, c, run]); i = j; continue
        if 0x10 <= c <= 0x1A:
            out += bytes([0x1A, c])
        else:
            out.append(c)
        i += 1
    return bytes(out)


def huffman_tree(freq):
    """serialized tree (list of words) and the codes {byte: bits}"""
    import heapq
    items = [(f, i, ('leaf', b)) for i, (b, f) in enumerate(sorted(freq.items()))]
    if len(items) == 1:
        items.append((0, 999, ('leaf', (items[0][2][1] + 1) & 255)))
    heapq.heapify(items)
    k = 1000
    while len(items) > 1:
        a = heapq.heappop(items)
        b = heapq.heappop(items)
        heapq.heappush(items, (a[0] + b[0], k, ('node', a[2], b[2])))
        k += 1
    root = items[0][2]
    # serialize: Node[i] internal -> right child at i+1, left child at Node[i]/2
    words, codes = [], {}

    def ser(node, code):
        idx = len(words)
        if node[0] == 'leaf':
            words.append(0x8000 | node[1])
            codes[node[1]] = code
            return idx
        words.append(0)
        ser(node[2], code + '1')         # right (1) follows directly
        left = ser(node[1], code + '0')
        words[idx] = left * 2
        return idx
    ser(root, '')
    return words, codes


def build_db(name, width, topics):
    ctxs, cmap, bins = [], [], []
    for t, (names, lines) in enumerate(topics):
        for c in names:
            ctxs.append(c)
            cmap.append(t)
        bins.append(b''.join(encode_line(seg, links) for seg, links in lines))
    import os
    kws = [] if os.environ.get('QHELP_NOKW') else keywords(bins)
    kwidx = {w: k for k, w in enumerate(kws)}
    comps = [rle(b, kwidx) for b in bins]
    freq = {}
    for c in comps:
        for x in c:
            freq[x] = freq.get(x, 0) + 1
    if not freq:
        freq = {0: 1}
    tree, codes = huffman_tree(freq)
    if os.environ.get('QHELP_NOHUFF'):
        tree, codes = None, None
    texts = []
    for b, c in zip(bins, comps):
        if codes is None:
            enc = c
        else:
            bits = ''.join(codes[x] for x in c)
            bits += '0' * (-len(bits) % 8)
            enc = bytes(int(bits[i:i + 8], 2) for i in range(0, len(bits), 8))
        texts.append(struct.pack('<H', len(b)) + enc)
    ntop, nctx = len(topics), len(ctxs)
    hdr_size = 0x46
    o_index = hdr_size
    o_ctx = o_index + 4 * (ntop + 1)
    ctxdata = b''.join(c + b'\0' for c in ctxs)
    o_map = o_ctx + len(ctxdata)
    mapdata = struct.pack('<%dH' % nctx, *cmap)
    kwdata = b''.join(bytes([len(w)]) + w for w in kws)
    o_kw = o_map + len(mapdata) if kws else 0
    o_huff = o_map + len(mapdata) + len(kwdata)
    treedata = struct.pack('<%dH' % (len(tree) + 1), *(tree + [0])) if tree else b''
    o_text = o_huff + len(treedata)
    if not tree:
        o_huff = 0
    offs, p = [], o_text
    for t in texts:
        offs.append(p)
        p += len(t)
    offs.append(p)
    size = p
    nm = name.encode('latin-1')[:13]
    hdr = b'LN' + struct.pack('<HHBBHHHH14sIIIIIIIIII', 2, 0, 0xFF, 0, ntop, nctx,
                              width, 0, nm, 0, o_index, o_ctx, o_map, o_kw,
                              o_huff, o_text, 0, 0, size)
    return (hdr + struct.pack('<%dI' % (ntop + 1), *offs) + ctxdata + mapdata
            + kwdata + treedata + b''.join(texts))


def read_dbs(data):
    """all databases of a file (they may be concatenated)"""
    dbs = []
    while len(data) >= 0x46 and data[:2] == b'LN':
        db = read_db(data)
        dbs.append(db)
        data = data[db['size']:]
    return dbs


def build_part(src, width, xtab):
    data = open(src, 'rb').read()
    if data.lstrip().startswith(b'{\\rtf'):
        topics = rtf_topics(data, xtab, width)
    else:
        topics = qh_topics(data)
    name = src.rsplit('/', 1)[-1].rsplit('.', 1)[0].lower() + '.hlp'
    return build_db(name, width, topics)


def main():
    if len(sys.argv) >= 3 and sys.argv[1] == 'dump':
        for db in read_dbs(open(sys.argv[2], 'rb').read()):
            dump(db)
    elif len(sys.argv) >= 5 and sys.argv[1] == 'build':
        # build OUT.HLP HMAKEL.C SOURCE:WIDTH ... (databases concatenated)
        xtab = hmakel_table(sys.argv[3])
        out = b''
        for spec in sys.argv[4:]:
            src, width = spec.rsplit(':', 1)
            out += build_part(src, int(width), xtab)
        open(sys.argv[2], 'wb').write(out)
    else:
        print(__doc__)
        sys.exit(1)


if __name__ == '__main__':
    main()
