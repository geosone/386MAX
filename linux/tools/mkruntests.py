#!/usr/bin/env python3
"""Make RUNTESTS.BAT from TESTS/MAX.LST: runs the regression tests on a
real DOS machine (or any emulator) with the memory manager to test loaded.

    mkruntests.py MAX.LST RUNTESTS.BAT

RUNTESTS.BAT [MOUSE] in the directory with the test programs writes the
output of each test to <NAME>.TXT and one line per test to RESULT.TXT:
PASS (errorlevel 0) or FAIL.  Tests that need a mouse driver run only with
the argument MOUSE.  A test that hangs or resets the machine leaves its
name as the last line of RESULT.TXT ("RUN <NAME>").
"""
import sys

lst, out = sys.argv[1], sys.argv[2]
lines = ['@ECHO OFF',
         'REM Open 386MAX regression tests (made from TESTS\\MAX.LST)',
         'ECHO Open 386MAX regression tests > RESULT.TXT']
n = 0
for line in open(lst):
    line = line.split('#', 1)[0]
    if not line.strip():
        continue
    words, _, args = line.partition(' -- ')
    w = words.split()
    name = w[0].split('/')[-1].upper()
    needs = next((o[6:].split(',') for o in w[1:] if o.startswith('needs=')), [])
    n += 1
    skip = 'S%d' % n
    if 'mouse' in needs:
        lines.append('IF NOT "%%1"=="MOUSE" GOTO %s' % skip)
    # no redirection inside IF (SvarCOM ignores it there)
    lines += ['ECHO RUN %s >> RESULT.TXT' % name,
              'ECHO %s' % name,
              '%s.EXE %s > %s.TXT' % (name, args.strip(), name)]
    if 'term' in w[1:]:   # errorlevel 255: terminated by the host = PASS
        lines += ['IF ERRORLEVEL 255 GOTO P%d' % n]
    lines += ['IF ERRORLEVEL 1 GOTO F%d' % n, ':P%d' % n,
              'ECHO PASS %s >> RESULT.TXT' % name,
              'ECHO   PASS',
              'GOTO N%d' % n,
              ':F%d' % n,
              'ECHO FAIL %s >> RESULT.TXT' % name,
              'ECHO   FAIL',
              ':N%d' % n]
    if 'mouse' in needs:
        lines.append(':%s' % skip)
lines += ['ECHO DONE >> RESULT.TXT', 'TYPE RESULT.TXT']
with open(out, 'w', newline='') as f:
    f.write('\r\n'.join(lines) + '\r\n')
