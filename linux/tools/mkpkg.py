#!/usr/bin/env python3
"""Make the installation package (replaces DISK/DISK.MAK and PACKAGE.EXE):

    mkpkg.py OUTDIR ROOT

PACKAGE/FILES.LST lists the files of the archive with their product ids:
programs come from build/bin, data files (README, PIFs, icons, ...) from
PACKAGE/.  The archive OUTDIR/386MAX.1, .2 (sized for 1.44 MB disks) gets
the installer files next to it.  LICENSE (GPL v3) is added as LICENSE.TXT,
in the archive and next to it.
"""
import os
import shutil
import sys

out, root = sys.argv[1], sys.argv[2]
tools = os.path.join(root, 'linux', 'tools')
sys.path.insert(0, tools)
sys.argv = ['qpack']
src = open(os.path.join(tools, 'qpack.py')).read().replace('\nmain()\n', '\n')
qp = {}
exec(src, qp)

bindir = os.path.join(root, 'build', 'bin')
built = {f.lower(): os.path.join(bindir, f) for f in os.listdir(bindir)}
pkgdir = os.path.join(root, 'PACKAGE')

os.makedirs(out, exist_ok=True)
items, missing = [], []
for line in open(os.path.join(pkgdir, 'FILES.LST')):
    line = line.split(';', 1)[0].split()
    if not line:
        continue
    name, pid, source = line[0], int(line[1]), line[2]
    path = built.get(name.lower()) if source == 'bin' else os.path.join(pkgdir, source)
    if not path or not os.path.isfile(path):
        missing.append(name)
        continue
    # the archive keeps the names of the original package
    if os.path.basename(path) != name:
        stage = os.path.join(out, '.stage')
        os.makedirs(stage, exist_ok=True)
        shutil.copy2(path, os.path.join(stage, name))
        path = os.path.join(stage, name)
    items.append((path, pid))
if missing:
    sys.exit('missing (run make first): ' + ' '.join(missing))

# Open 386MAX: the GPL text (CR/LF) is installed with the programs and lies
# on the disk for the installers' license page
stage = os.path.join(out, '.stage')
os.makedirs(stage, exist_ok=True)
lic = os.path.join(stage, 'license.txt')
with open(os.path.join(root, 'LICENSE'), 'rb') as fi, open(lic, 'wb') as fo:
    fo.write(fi.read().replace(b'\r\n', b'\n').replace(b'\n', b'\r\n'))
items.append((lic, 1))

# installer files (DISK/package.cfg "INSTALL LIST")
inst = {'setupdos.exe': os.path.join(bindir, 'SETUPDOS.EXE'),
        'setupdos.cfg': os.path.join(root, 'INSTALL', 'SETUPDOS.CFG'),
        # SETUPDOS.OVL is the DOS installer itself (original: MAXIB.EXE)
        'setupdos.ovl': os.path.join(bindir, 'SETUPDOS.EXE'),
        'qlogo.ovl': os.path.join(bindir, 'QLOGO.OVL'),
        'setupdos.hlp': os.path.join(bindir, 'setupdos.hlp'),   # DOSHELP
        'setup.hlp': os.path.join(bindir, 'SETUP.HLP'),         # MAXHELP
        # Windows setup (MAXSETUP)
        'setup.exe': os.path.join(bindir, 'SETUP.EXE')}
inst['license.txt'] = lic
for name, path in inst.items():
    shutil.copy2(path, os.path.join(out, name.upper()))

# The archive in extents for 1.44 MB disks (FAT12: 2847 clusters of 512
# bytes): disk 1 holds the installer files and 386MAX.1, the other disks
# 386MAX.2, ...  (The installers ask for the next disk when the next extent
# isn't in their directory, so one directory works for CD/USB as well.)
FLOPPY = 2847 * 512
clus = lambda n: (n + 511) // 512 * 512
first = FLOPPY - sum(clus(os.path.getsize(os.path.join(out, n.upper()))) for n in inst) - 4096
for f in os.listdir(out):
    if f.upper().startswith('386MAX.'):
        os.remove(os.path.join(out, f))
qp['write_archive'](os.path.join(out, '386MAX'), items, [first, FLOPPY - 4096])
shutil.rmtree(os.path.join(out, '.stage'), ignore_errors=True)
