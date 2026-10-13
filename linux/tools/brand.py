#!/usr/bin/env python3
"""Fill the IDENTIFY block of a 386MAX binary (386MAX.SYS, 386LOAD.*,
386UTIL.COM, QMT ...) the way the old SETUP did, so the unmodified
prebuilt binaries start without the serial number installer.

IDENTIFY (QMAX_IDN.INC) is 350 bytes: a line count, then an ASCIIZ text,
each byte stored as rol4(byte) + 23h; the word after it (IDENT_CHK) is the
sum of the stored bytes.  An unfilled block holds '0123456789' * 35.

    brand.py FILE [TEXT]
"""
import sys

def rol4(b):
    return ((b << 4) | (b >> 4)) & 0xFF

def main():
    path = sys.argv[1]
    text = sys.argv[2] if len(sys.argv) > 2 else 'GNU General Public License version 3'
    data = bytearray(open(path, 'rb').read())
    blank = b'0123456789' * 35
    pos = data.find(blank)
    if pos < 0:
        sys.exit(f'{path}: no unfilled IDENTIFY block')
    lines = text.count('\r\n') + 1
    if not text.endswith('\r\n'):
        text += '\r\n'
    plain = bytes([lines]) + text.encode('cp437') + b'\0'
    plain = plain.ljust(len(blank), b'\0')
    stored = bytes((rol4(b) + 0x23) & 0xFF for b in plain)
    data[pos:pos + len(blank)] = stored
    chk = sum(stored) & 0xFFFF
    data[pos + len(blank):pos + len(blank) + 2] = chk.to_bytes(2, 'little')
    open(path, 'wb').write(data)
    print(f'{path}: IDENTIFY at {pos:#x}, checksum {chk:#06x}')

main()
