#!/usr/bin/env python3
"""Compare two LE executables (Windows VxDs such as 386MAX.VXD): object
table, the contents of each object and the fixups (as sets of source
object/offset, type and target object/offset).

    lecmp.py OLD.VXD NEW.VXD
"""
import struct
import sys


def load(path):
    d = open(path, 'rb').read()
    le = struct.unpack_from('<I', d, 0x3c)[0]
    h = lambda o, f='<I': struct.unpack_from(f, d, le + o)[0]
    pagesize, lastpg, npages = h(0x28), h(0x2c), h(0x14)
    objtab, nobj = le + h(0x40), h(0x44)
    pagemap = le + h(0x48)
    fixpg, fixrec = le + h(0x68), le + h(0x6c)
    datapages = h(0x80)
    objs = []
    for i in range(nobj):
        vs, base, fl, pi, pn, _ = struct.unpack_from('<6I', d, objtab + 24 * i)
        objs.append(dict(vsize=vs, base=base, flags=fl, page=pi, npages=pn))
    # LE page map: 4 bytes per page, page number in bytes 1..2 (big endian-ish)
    def pagedata(p):        # p: 1-based logical page
        e = d[pagemap + 4 * (p - 1): pagemap + 4 * p]
        num = (e[0] << 16) | (e[1] << 8) | e[2]
        size = lastpg if p == npages else pagesize
        off = datapages + (num - 1) * pagesize
        return d[off:off + size].ljust(pagesize, b'\0')
    data = []
    for o in objs:
        data.append(b''.join(pagedata(o['page'] + k) for k in range(o['npages']))[:o['vsize']])
    fix = set()
    for p in range(1, npages + 1):
        start = struct.unpack_from('<I', d, fixpg + 4 * (p - 1))[0]
        end = struct.unpack_from('<I', d, fixpg + 4 * p)[0]
        q = fixrec + start
        oi = next(i for i, o in enumerate(objs) if o['page'] <= p < o['page'] + o['npages'])
        pbase = (p - objs[oi]['page']) * pagesize
        while q < fixrec + end:
            src, flg = d[q], d[q + 1]
            q += 2
            if src & 0x20:
                cnt = d[q]; q += 1
            else:
                cnt = 0
                soff = struct.unpack_from('<h', d, q)[0]; q += 2
            if flg & 3 != 0:
                raise SystemExit(f'{path}: unsupported fixup target type {flg:#x}')
            tobj = d[q] if not flg & 0x40 else struct.unpack_from('<H', d, q)[0]
            q += 1 if not flg & 0x40 else 2
            toff = 0
            if (src & 0xf) != 2:            # not a selector fixup
                if flg & 0x10:
                    toff = struct.unpack_from('<I', d, q)[0]; q += 4
                else:
                    toff = struct.unpack_from('<H', d, q)[0]; q += 2
            if src & 0x20:
                offs = [struct.unpack_from('<h', d, q + 2 * k)[0] for k in range(cnt)]
                q += 2 * cnt
            else:
                offs = [soff]
            for so in offs:
                fix.add((oi + 1, pbase + so, src & 0xf, tobj, toff))
    return dict(objs=objs, data=data, fix=fix, eip=(h(0x18), h(0x1c)))


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    bad = 0
    if a['eip'] != b['eip']:
        print(f'entry {a["eip"]} -> {b["eip"]}'); bad += 1
    for i, (x, y) in enumerate(zip(a['objs'], b['objs'])):
        tag = '' if (x['vsize'], x['base'], x['flags']) == (y['vsize'], y['base'], y['flags']) else '   <-- differs'
        print(f'object {i+1}: size {x["vsize"]:#x}/{y["vsize"]:#x} base {x["base"]:#x}/{y["base"]:#x} flags {x["flags"]:#x}/{y["flags"]:#x}{tag}')
        da, db = a['data'][i], b['data'][i]
        n = min(len(da), len(db))
        diff = [k for k in range(n) if da[k] != db[k]]
        if diff or len(da) != len(db):
            bad += 1
            print(f'  {len(diff)} bytes differ, first at {diff[0]:#x}' if diff else '  lengths differ')
    oa, ob = a['fix'] - b['fix'], b['fix'] - a['fix']
    print(f'fixups {len(a["fix"])} / {len(b["fix"])}, only old {len(oa)}, only new {len(ob)}')
    for f in sorted(oa)[:5]:
        print('  only old', f)
    for f in sorted(ob)[:5]:
        print('  only new', f)
    bad += bool(oa or ob)
    print('identical contents and fixups' if not bad else 'DIFFERENT')
    sys.exit(1 if bad else 0)


main()
