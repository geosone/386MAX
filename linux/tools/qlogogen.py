#!/usr/bin/env python3
"""Make the logo data of QLOGO.OVL (QUILIB/QLOGO_Q.INC, QLOGOASQ.INC).

    qlogogen.py OLD_QLOGO.OVL OUTDIR [PREVIEW_DIR]

The logos of the DOS programs (MAX, MAXIMIZE, SETUP: 'Q', ASQ: 'A') are
22 x 12 text cells in the 350 line text mode whose characters 127..237 are
loaded with 8 x 14 glyphs (QUILIB/LOGO.C).  Texts are shown at the same
time, so the umlauts (and German sharp s) in that range keep their glyphs
(taken from the old QLOGO.OVL).  On VGA the 9th pixel column of a cell
repeats the 8th only for characters C0..DF: cells whose right column is
set get those codes first, so letters don't get gaps.

The pictures are drawn with a free font (DejaVu Sans Bold) as in DESIGNS;
the most similar cells are merged until the glyphs fit into the free codes.
"""
import os
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 22, 12                   # cells
CW, CH = 8, 14                  # cell size
FIRST, LAST = 127, 237          # loaded characters
KEEP = (129, 132, 142, 148, 153, 154, 164, 224, 225)   # umlauts, sharp s
LINE = range(0xC0, 0xE0)        # 9th column repeats the 8th
# block characters of the screen background and the shadows keep their
# shape (the logo uses the full block too)
FIXED = {0xDB: bytes([0xFF] * 14), 0xDC: bytes(7) + bytes([0xFF] * 7),
         0xDF: bytes([0xFF] * 7) + bytes(7), 0xDD: bytes([0xF0] * 14),
         0xDE: bytes([0x0F] * 14)}
FONT = '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf'

# (text, font size, center y in pixels) per logo
DESIGNS = {
    'Q': [('Open', 30, 22), ('386', 64, 74), ('MAX', 52, 136)],
    'ASQ': [('ASQ', 78, 84)],
}


def render(lines):
    im = Image.new('1', (W * CW, H * CH), 0)
    dr = ImageDraw.Draw(im)
    for text, size, cy in lines:
        font = ImageFont.truetype(FONT, size)
        x0, y0, x1, y1 = dr.textbbox((0, 0), text, font=font)
        dr.text(((W * CW - (x1 - x0)) // 2 - x0, cy - (y1 - y0) // 2 - y0),
                text, font=font, fill=1)
    return im


def cells(im):
    out = []
    for r in range(H):
        row = []
        for c in range(W):
            g = []
            for y in range(CH):
                b = 0
                for x in range(CW):
                    if im.getpixel((c * CW + x, r * CH + y)):
                        b |= 0x80 >> x
                g.append(b)
            row.append(bytes(g))
        out.append(row)
    return out


def reduce(grid, limit):
    """Merge the most similar glyphs until at most limit are left"""
    blank = bytes(CH)
    count = {}
    for row in grid:
        for g in row:
            if g != blank and g not in FIXED.values():
                count[g] = count.get(g, 0) + 1
    diff = lambda a, b: sum(bin(x ^ y).count('1') for x, y in zip(a, b))
    repl = {}
    while len(count) > limit:
        keys = list(count)
        best = None
        for i, a in enumerate(keys):
            for b in keys[i + 1:]:
                # weigh by how often the dropped glyph occurs
                d = diff(a, b) * min(count[a], count[b])
                if best is None or d < best[0]:
                    best = (d, a, b)
        _, a, b = best
        keep, drop = (a, b) if count[a] >= count[b] else (b, a)
        count[keep] += count.pop(drop)
        repl[drop] = keep
        for k, v in list(repl.items()):
            if v == drop:
                repl[k] = keep
    return [[repl.get(g, g) for g in row] for row in grid]


def assign(grid, old):
    """Character codes for the distinct glyphs; returns matrix, glyph table"""
    blank = bytes(CH)
    glyphs = {}
    for r in range(H):
        for c in range(W):
            g = grid[r][c]
            if g == blank:
                continue
            nxt = grid[r][c + 1] if c + 1 < W else blank
            # wants a line character: right column set and the next cell
            # continues there
            want = sum(1 for y in range(CH) if g[y] & 1 and nxt[y] & 0x80)
            glyphs[g] = glyphs.get(g, 0) + want
    free = [ch for ch in range(FIRST, LAST + 1) if ch not in KEEP and ch not in FIXED]
    fixed = {g: ch for ch, g in FIXED.items()}
    line = [ch for ch in free if ch in LINE]
    other = [ch for ch in free if ch not in LINE]
    if len([g for g in glyphs if g not in fixed]) > len(free):  # (reduce() came first)
        sys.exit('%d glyphs, only %d characters' % (len(glyphs), len(free)))
    code = {}
    for g, want in sorted(glyphs.items(), key=lambda kv: -kv[1]):
        if g in fixed:
            code[g] = fixed[g]
        else:
            code[g] = (line if want and line else other or line).pop(0)
    table = {ch: old[ch] for ch in KEEP}
    table.update(FIXED)
    for g, ch in code.items():
        table[ch] = g
    matrix = [bytes(code.get(grid[r][c], 32) for c in range(W)) for r in range(H)]
    return matrix, table, len(glyphs)


def emit(name, lead, matrix, table, nglyph):
    n = LAST - FIRST + 1
    s = ['; %s - Data to build QLOGO.OVL (made by linux/tools/qlogogen.py)' % name,
         ';',
         '; Open 386MAX - GNU General Public License version 3.',
         ';',
         '; %d characters %d..%d (%d glyphs of the picture, umlauts kept)' % (n, FIRST, LAST, nglyph),
         '',
         '\tpublic w%sCount' % lead,
         'w%sCount\tdw\t%d' % (lead, n),
         '',
         '\tpublic b%sLogo' % lead,
         'b%sLogo\tlabel byte' % lead]
    for row in matrix:
        s.append('\tdb\t' + ','.join('%03xh' % b for b in row))
    s.append('')
    for ch in range(FIRST, LAST + 1):
        g = table.get(ch, bytes(CH))
        s.append('\tpublic\tb%sChar%d' % (lead, ch))
        s.append('b%sChar%d\tlabel byte' % (lead, ch))
        for b in g:
            s.append('\tdb\t%sb' % format(b, '08b'))
        s.append('')
    return '\r\n'.join(s) + '\r\n'


def oldglyphs(path):
    d = open(path, 'rb').read()
    n = struct.unpack_from('<H', d, 0)[0]
    g = d[2 + W * H:2 + W * H + n * CH]
    return {ch: g[(ch - FIRST) * CH:(ch - FIRST + 1) * CH] for ch in range(FIRST, FIRST + n)}


def preview(matrix, table, path):
    im = Image.new('L', (W * 9, H * CH), 0)
    for r in range(H):
        for c in range(W):
            ch = matrix[r][c]
            if ch not in table:
                continue
            for y, b in enumerate(table[ch]):
                for x in range(8):
                    if b & (0x80 >> x):
                        im.putpixel((c * 9 + x, r * CH + y), 255)
                if ch in LINE and b & 1:
                    im.putpixel((c * 9 + 8, r * CH + y), 255)
    im.resize((im.width * 3, im.height * 3)).save(path)


def main():
    old = oldglyphs(sys.argv[1])
    out = sys.argv[2]
    pv = sys.argv[3] if len(sys.argv) > 3 else None
    for key, fname, lead in (('Q', 'QLOGO_Q.INC', 'Q'), ('ASQ', 'QLOGOASQ.INC', 'A')):
        nfree = LAST - FIRST + 1 - len(KEEP) - len(FIXED)
        matrix, table, n = assign(reduce(cells(render(DESIGNS[key])), nfree), old)
        open(os.path.join(out, fname), 'wb').write(emit(fname, lead, matrix, table, n).encode('ascii'))
        if pv:
            preview(matrix, table, os.path.join(pv, 'logo_%s.png' % key))
        print('%s: %d glyphs' % (fname, n))


main()
