#!/usr/bin/env python3
"""Toolbar bitmap from an icon: the top-left WxH pixels of the icon (the
MAXedit toolbar icons use 16 x 15 of their 32 x 32), transparent pixels in
the button colour, written as a 16 colour Windows DIB (BITMAP resource for
wxToolBar).

    ico2bmp.py IN.ICO OUT.BMP [W H]
"""
import struct
import sys

from PIL import Image

PAL = [(0, 0, 0), (128, 0, 0), (0, 128, 0), (128, 128, 0), (0, 0, 128),
       (128, 0, 128), (0, 128, 128), (192, 192, 192), (128, 128, 128),
       (255, 0, 0), (0, 255, 0), (255, 255, 0), (0, 0, 255), (255, 0, 255),
       (0, 255, 255), (255, 255, 255)]
FACE = 7                                # button face (light grey)


def main():
    src, out = sys.argv[1], sys.argv[2]
    w, h = (int(sys.argv[3]), int(sys.argv[4])) if len(sys.argv) > 4 else (16, 15)
    ico = Image.open(src).convert('RGBA').crop((0, 0, w, h))
    rgb = Image.new('RGB', (w, h), PAL[FACE])
    rgb.paste(ico, (0, 0), ico)
    pim = Image.new('P', (w, h))
    pim.putpalette([c for p in PAL for c in p] + [0] * (768 - 48))
    img = rgb.quantize(palette=pim, dither=Image.Dither.NONE)
    px = img.load()
    rowlen = ((w * 4 + 31) // 32) * 4
    bits = b''
    for y in range(h - 1, -1, -1):
        row = bytearray(rowlen)
        for x in range(w):
            row[x // 2] |= (px[x, y] & 15) << (4 if x % 2 == 0 else 0)
        bits += bytes(row)
    pal = b''.join(struct.pack('<BBBB', b, g, r, 0) for r, g, b in PAL)
    hdr = struct.pack('<IiiHHIIiiII', 40, w, h, 1, 4, 0, len(bits), 0, 0, 16, 16)
    off = 14 + len(hdr) + len(pal)
    with open(out, 'wb') as f:
        f.write(b'BM' + struct.pack('<IHHI', off + len(bits), 0, 0, off) + hdr + pal + bits)


main()
