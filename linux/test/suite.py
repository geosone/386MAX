#!/usr/bin/env python3
"""Regression suite: run DOS test programs under a memory manager in QEMU.

    linux/test/suite.py [-p PROFILE]... [-d DOS]... [-s SUITE]... [-t TEST]...
                        [--check] [--update] [--matrix]

All tests of the chosen suites run in one QEMU boot per profile and DOS image
(C:\\SUITE\\RUN.BAT).  A batch line marks the start and the end of every test
on the screen; the runner reads the screen through the QEMU monitor:

    PASS / FAIL   the test ended with errorlevel 0 / not 0
    END           an external test ended (it has no pass/fail convention)
    HANG          no end within the test's timeout
    CRASH         the machine reset (QEMU runs with -no-reboot)

After a HANG or CRASH the runner boots again and continues with the next test.
QEMU runs with TCG (ACCEL="-accel kvm" for a quick run: KVM is unreliable on
hosts that also load VirtualBox's modules).
Results: build/suite/<suite>-<profile>-<dos>/result.txt and out/<SUITE>_<TEST>.TXT
(the redirected output of each test).

Suites (TESTS/<SUITE>.LST, one test per line:
    NAME [timeout=S] [keys] [floppy] [term] [needs=ems,vcpi,...] [-- ARGS];
    term: errorlevel 255, the client terminated by the host, is a PASS):
    max    the own tests (TESTS/<DIR>/<NAME>.ASM, listed as DIR/NAME)
    jemm   the test programs of Jemm (directory JEMM_TEST, local only)
    hx     the HDPMI regression tests of HX (directory HX_REG, local only)

Profiles: max (386MAX), emm386 (MS HIMEM + EMM386 of the DOS image: the
reference most programs were tested with), himem (MS HIMEM only), and,
with REFDIR pointing to a directory with the reference programs, jemmex,
jemm386 (HIMEMX + JEMM386), himemx (XMS only), hdpmi (HimemX + HDPMI16/32:
the DPMI reference), cwsdpmi (HimemX + CWSDPMI: DJGPP's host, 32-bit clients
only) and maxcws (386MAX NODPMI + CWSDPMI as its VCPI client).

--check compares with TESTS/BASELINE/<suite>-<profile>-<dos>.TXT and
exits with 1 when a test got worse (PASS/END -> FAIL/HANG/CRASH);
--update merges the results into the baseline; --matrix writes
build/suite/matrix.md from the baselines.
"""
import argparse
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
TESTS = os.path.join(ROOT, 'TESTS')
sys.path.insert(0, HERE)
from qemudrv import Monitor  # noqa: E402

BUILD = os.path.join(ROOT, 'build', 'suite')
ENV = dict(os.environ, MTOOLS_SKIP_CHECK='1')
SHELL = 'SHELL=C:\\COMMAND.COM C:\\ /E:1024 /P'
SHELLS = {'svardos': 'SHELL=C:\\COMMAND.COM /P'}   # SvarCOM: no path argument

# profile: (CONFIG.SYS lines, files from REFDIR, what it provides)
PROFILES = {
    'max':     (['DEVICE=C:\\MAX\\386MAX.SYS'], [], 'xms ems vcpi dpmi dpmi32 dpmi1 xlat vds qpi'),
    'emm386':  (['DEVICE=C:\\DOS\\HIMEM.SYS', 'DEVICE=C:\\DOS\\EMM386.EXE RAM FRAME=D000 X=E000-EFFF'], [],
                'xms ems vcpi vds'),
    'himem':   (['DEVICE=C:\\DOS\\HIMEM.SYS'], [], 'xms'),
    'jemmex':  (['DEVICE=C:\\REF\\JEMMEX.EXE FRAME=D000 X=E000-EFFF'], ['JEMMEX.EXE'],
                'xms ems vcpi vds'),
    'jemm386': (['DEVICE=C:\\REF\\HIMEMX.EXE',
                 'DEVICE=C:\\REF\\JEMM386.EXE FRAME=D000 X=E000-EFFF'],
                ['HIMEMX.EXE', 'JEMM386.EXE'], 'xms ems vcpi vds'),
    'himemx':  (['DEVICE=C:\\REF\\HIMEMX.EXE'], ['HIMEMX.EXE'], 'xms'),
    # DPMI reference: HimemX + HDPMI16/32 resident (AUTOEXEC, see AUTOEXTRA)
    'hdpmi':   (['DEVICE=C:\\REF\\HIMEMX.EXE'], ['HIMEMX.EXE', 'HDPMI16.EXE', 'HDPMI32.EXE'],
                'xms dpmi dpmi32 xlat'),
    # DJGPP's DPMI host (most DJGPP games): alone on HimemX, and as VCPI
    # client of 386MAX without its own DPMI host (NODPMI); 32-bit clients only
    'cwsdpmi': (['DEVICE=C:\\REF\\HIMEMX.EXE'], ['HIMEMX.EXE', 'CWSDPMI.EXE'], 'xms dpmi32'),
    'maxcws':  (['DEVICE=C:\\MAX\\386MAX.SYS PRO=C:\\MAX\\NODPMI.PRO'], ['CWSDPMI.EXE'],
                'xms ems vcpi vds dpmi32'),
    # QEMM 97 with QDPMI: needs a DOS image with QEMM installed in C:\QEMM
    # (-d qemm622, made locally from the user's own copy)
    'qemm':    (['DEVICE=C:\\QEMM\\QEMM386.SYS RAM FR=D000 X=E000-EFFF',
                 'DEVICE=C:\\QEMM\\QDPMI.SYS SWAPFILE=DPMI.SWP SWAPSIZE=1024'], [],
                'xms ems vcpi vds qpi dpmi dpmi32'),
}
PROFILE_FILES = {'maxcws': {'MAX/NODPMI.PRO': ['NODPMI']}}
AUTOEXTRA = {'hdpmi': ['C:\\REF\\HDPMI16.EXE -r > NUL', 'C:\\REF\\HDPMI32.EXE -r > NUL'],
             'cwsdpmi': ['C:\\REF\\CWSDPMI.EXE -p > NUL'],
             'maxcws': ['C:\\REF\\CWSDPMI.EXE -p > NUL']}
WORSE = {'FAIL', 'HANG', 'CRASH', 'MISSING'}
# TCG by default: KVM on this host is unreliable (KVM and VirtualBox modules
# loaded together), results under KVM only as a quick pre-test
ACCEL = os.environ.get('ACCEL', '-accel tcg')
SLOW = 4 if 'tcg' in ACCEL else 1        # timeouts are scaled by this
GOOD = {'PASS', 'END'}


def sh(*cmd, **kw):
    return subprocess.run(cmd, env=ENV, check=True, **kw)


class Test:
    def __init__(self, suite, line):
        words, _, args = line.partition(' -- ')
        w = words.split()
        self.path = w[0].upper()
        self.suite, self.name, self.args = suite, os.path.basename(self.path), args.strip()
        self.timeout, self.keys, self.floppy, self.needs = 30, False, False, set()
        self.term = False   # errorlevel 255 (client terminated by the host) = PASS
        for o in w[1:]:
            k, _, v = o.partition('=')
            if k == 'timeout':
                self.timeout = int(v)
            elif k == 'keys':
                self.keys = True
            elif k == 'floppy':
                self.floppy = True
            elif k == 'term':
                self.term = True
            elif k == 'needs':
                self.needs = set(v.split(','))
        self.id = '%s/%s' % (suite, self.name)


def build_suite(suite):
    """returns ([Test], {DOS name: local file})"""
    lst = os.path.join(TESTS, suite.upper() + '.LST')
    tests = [Test(suite, l.strip()) for l in open(lst)
             if l.strip() and not l.startswith('#')]
    files = {}
    out = os.path.join(BUILD, 'bin', '%s-%d' % (suite, os.getpid()))
    os.makedirs(out, exist_ok=True)
    if suite == 'max':   # built by TESTS/GNUmakefile
        subprocess.run(['make', '-s', '-C', TESTS], check=True)
        for t in tests:
            files[t.name + '.EXE'] = os.path.join(ROOT, 'build', 'TESTS', t.name + '.EXE')
    elif suite == 'jemm':
        top = os.environ.get('JEMM_TEST')
        if not top or not os.path.isdir(top):
            sys.exit('suite jemm: set JEMM_TEST to the Test directory of Jemm')
        for t in tests:
            src = top
            asm = [f for f in os.listdir(src) if f.upper() == t.name + '.ASM'][0]
            exe = os.path.join(out, t.name + '.EXE')
            r = subprocess.run(['jwasm', '-q', '-mz', '-I' + src, '-Fo' + exe,
                                os.path.join(src, asm)], cwd=out,
                               capture_output=True, text=True)
            if r.returncode:
                sys.exit('jwasm %s:\n%s%s' % (asm, r.stdout, r.stderr))
            files[t.name + '.EXE'] = exe
    elif suite == 'hx':
        src = os.environ.get('HX_REG')
        if not src or not os.path.isdir(src):
            sys.exit('suite hx: set HX_REG to a directory with the built HX regression tests')
        for f in os.listdir(src):
            files[f.upper()] = os.path.join(src, f)
    return tests, files


def make_image(dos, profile, suites, tests, out):
    base = dos if os.path.isfile(dos) else os.path.join(ROOT, 'build', 'dosdisk', dos + '.img')
    img = os.path.join(out, 'test.img')
    shutil.copy(base, img)
    p = img + '@@32256'
    for d in ['MAX', 'REF', 'SUITE'] + ['SUITE\\' + s for s in suites] + ['SUITE\\OUT'] + ['SUITE\\OUT\\' + s for s in suites]:
        subprocess.run(['mmd', '-i', p, '::/' + d.replace('\\', '/')], env=ENV,
                       capture_output=True)
    for f in ['386MAX.SYS', '386MAX.VXD', '386LOAD.SYS', '386LOAD.COM', '386UTIL.COM']:
        f = os.path.join(ROOT, 'build', 'bin', f)
        if os.path.exists(f):
            sh('mcopy', '-o', '-i', p, f, '::/MAX/')
    cfg, ref, _ = PROFILES[profile]
    for f in ref:
        rd = os.environ.get('REFDIR', '')
        src = [os.path.join(rd, x) for x in os.listdir(rd or '.') if x.upper() == f] if rd else []
        if not src:
            sys.exit('profile %s: REFDIR must contain %s' % (profile, f))
        sh('mcopy', '-o', '-i', p, src[0], '::/REF/' + f)
    for s, files in suites.items():
        for name, path in files.items():
            sh('mcopy', '-o', '-i', p, path, '::/SUITE/%s/%s' % (s, name))
    name = os.path.basename(base).lower()
    shell = next((v for k, v in SHELLS.items() if k in name), SHELL)
    lines = cfg + ['DOS=HIGH,UMB', 'FILES=40', 'BUFFERS=20', shell]
    write_dos(p, 'CONFIG.SYS', lines)
    for name, content in PROFILE_FILES.get(profile, {}).items():
        write_dos(p, name, content)
    write_dos(p, 'AUTOEXEC.BAT', ['@ECHO OFF', 'PATH C:\\;C:\\DOS;C:\\MAX;C:\\SUITE\\HX']
              + AUTOEXTRA.get(profile, []) + ['CALL C:\\SUITE\\RUN.BAT'])
    return img


def write_dos(p, name, lines):
    tmp = os.path.join(BUILD, 'tmp_%d_%s' % (os.getpid(), os.path.basename(name)))
    with open(tmp, 'w', newline='') as f:
        f.write('\r\n'.join(lines) + '\r\n')
    sh('mcopy', '-o', '-i', p, tmp, '::/' + name)
    os.remove(tmp)


def run_batch(p, tests):
    # no redirection inside IF: SvarCOM ignores it there
    lines = ['@ECHO OFF']
    for n, t in enumerate(tests):
        d = 'C:\\SUITE\\' + t.suite
        lines += ['CD %s' % d, 'ECHO @@B %s' % t.id, 'ECHO @@B %s >> %s' % (t.id, LOG),
                  '%s\\%s.EXE %s > C:\\SUITE\\OUT\\%s\\%s.TXT' % (d, t.name, t.args, t.suite, t.name)]
        if t.term:
            lines += ['IF ERRORLEVEL 255 GOTO P%d' % n]
        lines += ['IF ERRORLEVEL 1 GOTO F%d' % n, ':P%d' % n,
                  'ECHO @@E %s 0' % t.id, 'ECHO @@E %s 0 >> %s' % (t.id, LOG), 'GOTO N%d' % n,
                  ':F%d' % n,
                  'ECHO @@E %s 1' % t.id, 'ECHO @@E %s 1 >> %s' % (t.id, LOG),
                  ':N%d' % n]
    lines += ['CD \\', 'ECHO @@DONE', 'ECHO @@DONE >> %s' % LOG, 'C:\\SUITE\\QEXIT.COM']
    write_dos(p, 'SUITE/RUN.BAT', lines)


LOG = 'C:\\SUITE\\LOG.TXT'
QEXIT = bytes.fromhex('ba0105b000eeb8004ccd21')  # out 501h,0 (isa-debug-exit); int 21h 4C00h


def boot(img, out, tests, results, log):
    """one boot: run tests until done, hang or crash; fill results"""
    p = img + '@@32256'
    q = os.path.join(BUILD, 'tmp_qexit_%d' % os.getpid())
    open(q, 'wb').write(QEXIT)
    sh('mcopy', '-o', '-i', p, q, '::/SUITE/QEXIT.COM')
    os.remove(q)
    subprocess.run(['mdel', '-i', p, '::/SUITE/LOG.TXT'], env=ENV, capture_output=True)
    run_batch(p, tests)
    sock = os.path.join(out, 'monitor.sock')
    fda = ['-drive', 'if=floppy,index=0,format=raw,file=' + os.path.join(out, 'floppy.img')]
    qemu = subprocess.Popen(
        ['qemu-system-i386', '-machine', 'pc'] + ACCEL.split()
        + ['-m', os.environ.get('MEMSIZE', '64'), '-display', 'none', '-vga', 'std',
           '-monitor', 'unix:%s,server,nowait' % sock, '-no-reboot',
           '-drive', 'if=ide,index=0,format=raw,file=' + img] + fda
        + ['-boot', 'c', '-nic', 'none', '-device', 'isa-debug-exit,iobase=0x501,iosize=0x02']
        + os.environ.get('QEMU_EXTRA', '').split(),
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    m = Monitor(sock)
    byid = {t.id: t for t in tests}
    cur, since, lastkey, booted, seen, killed = None, time.time(), 0, time.time(), False, None
    ended = set()
    while qemu.poll() is None:
        try:
            scr = m.screen()
        except OSError:
            break
        for line in scr.splitlines():
            w = line.split()
            if len(w) >= 2 and w[0] == '@@B' and w[1] in byid and w[1] not in ended \
                    and w[1] != cur:
                cur, since, seen = w[1], time.time(), True
            elif len(w) >= 3 and w[0] == '@@E' and w[1] in byid:
                ended.add(w[1])
                if cur == w[1]:
                    cur = None
        if not seen and time.time() - booted > 120 * SLOW:
            killed = 'boot'
            save_screen(out, 'boot', scr)
        elif cur:
            t = byid[cur]
            if t.keys and time.time() - lastkey > 3:
                m.cmd('sendkey ret')
                lastkey = time.time()
            if time.time() - since > t.timeout * SLOW:
                killed = cur
                save_screen(out, t.id, scr)
        if killed:
            m.cmd('quit')
            break
        time.sleep(0.5)
    try:
        qemu.wait(timeout=15)
    except subprocess.TimeoutExpired:   # monitor dead (e.g. a guest stuck in HLT)
        qemu.kill()
        qemu.wait()
    r = subprocess.run(['mtype', '-i', p, '::/SUITE/LOG.TXT'], env=ENV,
                       capture_output=True, text=True, errors='replace')
    last = None
    for line in r.stdout.splitlines():
        w = line.split()
        if len(w) >= 2 and w[0] == '@@B' and w[1] in byid:
            last = w[1]
        elif len(w) >= 3 and w[0] == '@@E' and w[1] in byid and w[1] not in results:
            t = byid[w[1]]
            ok = w[2] == '0'
            st = ('PASS' if ok else 'FAIL') if t.suite == 'max' else 'END'
            results[w[1]] = (st, w[2])
            log('%s %s' % (w[1], st))
            last = None
    if killed == 'boot' and not results and not last:
        results['boot'] = ('HANG', '')
    elif last and last not in results:
        st = 'HANG' if killed == last else 'CRASH'
        results[last] = (st, '')
        log('%s %s' % (last, st))
    if killed == 'boot' and last and last not in results:
        results[last] = ('HANG', '')   # its screen covered the @@B line
        log('%s HANG' % last)
    if killed and killed != 'boot' and killed not in results:
        results[killed] = ('HANG', '')
        log('%s HANG' % killed)


def save_screen(out, name, scr):
    with open(os.path.join(out, 'out', name.replace('/', '_') + '.SCR'), 'w') as f:
        f.write(scr)


def run(profile, dos, suites, only, suffix=''):
    tag = '%s-%s-%s%s' % ('+'.join(suites), profile, os.path.splitext(os.path.basename(dos))[0],
                          suffix)
    out = os.path.join(BUILD, tag)
    shutil.rmtree(out, ignore_errors=True)
    os.makedirs(os.path.join(out, 'out'))
    have = set(PROFILES[profile][2].split())
    tests, files = [], {}
    for s in suites:
        t, f = build_suite(s)
        if os.environ.get('SUITE_KEYS') == '1':
            for x in t:
                x.keys = True
        tests += [x for x in t if not only or x.name in only or x.id in only]
        files[s] = f
    results = {}
    skipped = [t for t in tests if not t.needs <= have]
    for t in skipped:
        results[t.id] = ('SKIP', '')
    todo = [t for t in tests if t.id not in results]
    sh('mformat', '-C', '-f', '1440', '-v', 'SUITE', '-i', os.path.join(out, 'floppy.img'), '::')
    logf = open(os.path.join(out, 'log.txt'), 'w')

    def log(s):
        print('%-16s %s' % (tag, s), flush=True)
        logf.write(s + '\n')
    img = make_image(dos, profile, files, tests, out)
    while todo:
        n = len(results)
        boot(img, out, todo, results, log)
        if 'boot' in results:
            log('boot failed, see out/boot.SCR')
            break
        if len(results) == n:   # no progress: give up on the first one
            results[todo[0].id] = ('HANG', '')
        todo = [t for t in todo if t.id not in results]
    for t in tests:
        results.setdefault(t.id, ('MISSING', ''))
    for t in tests:   # the output files
        subprocess.run(['mcopy', '-o', '-i', img + '@@32256', '::/SUITE/OUT/%s/%s.TXT'
                        % (t.suite, t.name), os.path.join(out, 'out', '%s_%s.TXT' % (t.suite, t.name))],
                       env=ENV, capture_output=True)
    with open(os.path.join(out, 'result.txt'), 'w') as f:
        for t in tests:
            f.write('%-24s %s\n' % (t.id, results[t.id][0]))
    if os.environ.get('KEEPIMG') != '1':
        os.remove(img)
    return tag, {t.id: results[t.id][0] for t in tests}


def read_result(path):
    r = {}
    if os.path.exists(path):
        for line in open(path):
            w = line.split()
            if len(w) == 2:
                r[w[0]] = w[1]
    return r


ORDER = ['emm386', 'himem', 'qemm', 'jemmex', 'jemm386', 'himemx', 'hdpmi', 'cwsdpmi', 'maxcws', 'max']
DOSORDER = ['msdos622', 'msdos71', 'edrdos', 'svardos', 'freedos', 'qemm622']


def matrix():
    """build/suite/matrix.md from TESTS/BASELINE: one table per suite, MS
    reference first"""
    runs = {}
    bdir = os.path.join(TESTS, 'BASELINE')
    for f in os.listdir(bdir):
        w = os.path.splitext(f)[0].split('-')
        if len(w) == 3 and w[1] in PROFILES:
            runs.setdefault(w[0], []).append((w[1], w[2], os.path.join(bdir, f)))
    out = []
    for suite in sorted(runs):
        cols = sorted(runs[suite], key=lambda c: (ORDER.index(c[0]) if c[0] in ORDER else 99,
                                                  DOSORDER.index(c[1]) if c[1] in DOSORDER else 99))
        res = {c[2]: read_result(c[2]) for c in cols}
        ids = sorted({i for r in res.values() for i in r})
        out += ['### suite %s' % suite, '',
                '| test | ' + ' | '.join('%s<br>%s' % (c[0], c[1]) for c in cols) + ' |',
                '|---' * (len(cols) + 1) + '|']
        for i in ids:
            out.append('| %s | %s |' % (i.split('/', 1)[1],
                                        ' | '.join(res[c[2]].get(i, '') for c in cols)))
        out.append('')
    path = os.path.join(BUILD, 'matrix.md')
    open(path, 'w').write('\n'.join(out))
    print('\n'.join(out))
    print('->', path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('-p', '--profile', action='append', choices=sorted(PROFILES))
    ap.add_argument('-d', '--dos', action='append', help='msdos622, edrdos, freedos, ... or an image')
    ap.add_argument('-s', '--suite', action='append')
    ap.add_argument('-t', '--test', action='append', default=[])
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--update', action='store_true')
    ap.add_argument('--matrix', action='store_true')
    ap.add_argument('--tag', default='', help='suffix of the result directory (not with --check/--update)')
    ap.add_argument('--keys', action='store_true', help='press Enter every 3 s during every test')
    a = ap.parse_args()
    if a.keys:
        os.environ['SUITE_KEYS'] = '1'
    os.makedirs(BUILD, exist_ok=True)
    if a.matrix and not a.profile:
        return matrix()
    bad = 0
    for dos in a.dos or ['msdos622']:
        for prof in a.profile or ['max']:
            tag, res = run(prof, dos, a.suite or ['max'], set(x.upper() for x in a.test),
                           '-' + a.tag if a.tag else '')
            base = os.path.join(TESTS, 'BASELINE', tag + '.TXT')
            if a.update:
                os.makedirs(os.path.dirname(base), exist_ok=True)
                old = read_result(base)
                old.update(res)
                with open(base, 'w') as f:
                    for i in sorted(old):
                        f.write('%-24s %s\n' % (i, old[i]))
            if a.check:
                old = read_result(base)
                for i, st in sorted(res.items()):
                    if old.get(i) in GOOD and st in WORSE:
                        print('REGRESSION %s %s: %s -> %s' % (tag, i, old[i], st))
                        bad += 1
                    elif i not in old:
                        print('new %s %s: %s' % (tag, i, st))
    if a.matrix:
        matrix()
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
