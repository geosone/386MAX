#!/usr/bin/env python3
"""Splash bitmap of the Windows setup and Windows Maximize (QMAX.BMP).

    splashgen.py art  OUT.PNG          draw the artwork (needs DejaVu Serif
                                       Bold); the result is committed as
                                       INCLUDE/SPLASH.PNG
    splashgen.py bmp  ART.PNG VERSION OUT.BMP
                                       stamp the version line into the
                                       artwork, write a 16 colour Windows
                                       3.x bitmap (410 x 236 like the
                                       original Qualitas picture)
"""
import struct
import sys

from PIL import Image, ImageDraw, ImageFont

W, H = 410, 236
# the 16 colour VGA palette (Windows order)
PAL = [(0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0), (0, 0, 128),
       (128, 0, 128), (0, 128, 128), (192, 192, 192), (128, 128, 128),
       (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255),
       (0, 255, 255), (255, 255, 255)]
BLACK, DGRAY, LGRAY, WHITE, NAVY = 0, 8, 7, 15, 4
FONT = '/usr/share/fonts/dejavu/DejaVuSerif-Bold.ttf'


def frame(d, x0, y0, x1, y1, raised):
    hi, lo = (WHITE, DGRAY) if raised else (DGRAY, WHITE)
    d.line([(x0, y1), (x0, y0), (x1, y0)], fill=hi, width=2)
    d.line([(x1, y0), (x1, y1), (x0, y1)], fill=lo, width=2)


def text_shadow(d, xy, s, font):
    x, y = xy
    d.text((x + 3, y + 3), s, font=font, fill=DGRAY)
    d.text((x, y), s, font=font, fill=BLACK)


def art(out):
    im = Image.new('P', (W, H), LGRAY)
    im.putpalette([c for rgb in PAL for c in rgb] + [0] * (768 - 48))
    d = ImageDraw.Draw(im)
    frame(d, 0, 0, W - 1, H - 1, True)
    frame(d, 6, 6, W - 7, H - 7, False)
    f1 = ImageFont.truetype(FONT, 44)
    size = 120
    while ImageFont.truetype(FONT, size).getlength('386MAX') > W - 60:
        size -= 2
    f2 = ImageFont.truetype(FONT, size)
    text_shadow(d, (26, 12), 'Open', f1)
    text_shadow(d, ((W - f2.getlength('386MAX')) // 2, 78), '386MAX', f2)
    d.line([(26, 66), (W - 30, 66)], fill=NAVY, width=3)
    im.save(out)


def bmp(artfile, version, out):
    im = Image.open(artfile).convert('RGB')
    pim = Image.new('P', (W, H))
    pim.putpalette([c for rgb in PAL for c in rgb] + [0] * (768 - 48))
    im = im.quantize(palette=pim, dither=Image.Dither.NONE)
    d = ImageDraw.Draw(im)
    label = 'Version %s  -  Open 386MAX, GNU GPL v3' % version
    font = ImageFont.load_default()
    x0, y0 = 24, H - 36
    l, t, r, b = d.textbbox((0, 0), label, font=font)
    d.rectangle([x0, y0, x0 + (r - l) + 10, y0 + (b - t) + 8], fill=WHITE, outline=BLACK)
    d.text((x0 + 5 - l, y0 + 4 - t), label, font=font, fill=BLACK)
    # Windows 3.x DIB, 4 bits per pixel, bottom-up rows padded to 4 bytes
    px = im.load()
    rowlen = ((W * 4 + 31) // 32) * 4
    rows = []
    for y in range(H - 1, -1, -1):
        row = bytearray(rowlen)
        for x in range(W):
            v = px[x, y] & 15
            row[x // 2] |= v << 4 if x % 2 == 0 else v
        rows.append(bytes(row))
    bits = b''.join(rows)
    pal = b''.join(struct.pack('<BBBB', b, g, r, 0) for r, g, b in PAL)
    hdr = struct.pack('<IiiHHIIiiII', 40, W, H, 1, 4, 0, len(bits), 0, 0, 16, 16)
    off = 14 + len(hdr) + len(pal)
    with open(out, 'wb') as f:
        f.write(b'BM' + struct.pack('<IHHI', off + len(bits), 0, 0, off))
        f.write(hdr + pal + bits)


if sys.argv[1:2] == ['art']:
    art(sys.argv[2])
elif sys.argv[1:2] == ['bmp']:
    bmp(sys.argv[2], open(sys.argv[3]).read().strip(), sys.argv[4])
else:
    sys.exit(__doc__)
