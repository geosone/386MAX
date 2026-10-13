#!/usr/bin/env python3
"""Make the installation package (replaces DISK/DISK.MAK and PACKAGE.EXE):

    mkpkg.py OUTDIR ROOT

The file list and the product ids come from the original package
(DISK/386MAX.1, .2).  Each file is taken from build/bin when it is built
there, else from the sources (TEXT/, LIB/: data files, PIFs, icons, ...),
else from the original package.  Programs found only as binaries are
listed as not built.  The installer files are copied next
to the archive OUTDIR/386MAX.1, .2 (sized for 1.44 MB disks).  LICENSE (GPL v3) is added as LICENSE.TXT,
in the archive and next to it.  Prints which files are not built.
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

orig = [os.path.join(root, 'DISK', '386MAX.%d' % n) for n in (1, 2)]
info = qp['read_dir'](orig[0])
origdir = os.path.join(out, '.orig')
if not os.path.isdir(origdir):
    qp['cmd_extract'](origdir, orig)

bindir = os.path.join(root, 'build', 'bin')
built = {f.lower(): os.path.join(bindir, f) for f in os.listdir(bindir)}
# data files in the sources (TEXT/ first, then LIB/)
sources = {}
for d in ('LIB', 'TEXT'):
    for f in os.listdir(os.path.join(root, d)):
        sources[f.lower()] = os.path.join(root, d, f)
BINARY = ('.exe', '.dll', '.com', '.sys', '.drv', '.386', '.ovl', '.cpl')

os.makedirs(out, exist_ok=True)
items, notbuilt = [], []
for f in info['files']:
    name = f['path']
    path = built.get(name.lower())
    if not path and name.lower() in sources:
        path = sources[name.lower()]
        if name.lower().endswith(BINARY):
            notbuilt.append(name)    # a prebuilt program in the sources
    if not path:
        path = os.path.join(origdir, name)
        notbuilt.append(name)
    # the archive keeps the names of the original package
    if os.path.basename(path) != name:
        stage = os.path.join(out, '.stage')
        os.makedirs(stage, exist_ok=True)
        shutil.copy2(path, os.path.join(stage, name))
        path = os.path.join(stage, name)
    items.append((path, f['id']))

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
print('not built yet (prebuilt or from the original package): ' + ' '.join(sorted(notbuilt)))
