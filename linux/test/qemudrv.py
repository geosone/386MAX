#!/usr/bin/env python3
"""Drive a QEMU run through its monitor: wait for text on the screen, then
press keys.  The text screen is read from the VGA memory at B8000h, so the
steps work for DOS text mode programs; for graphics screens use "sleep".

    qemudrv.py SOCKET OUTDIR STEP...

SOCKET is the monitor's unix socket (qemu -monitor unix:SOCKET,server,nowait).
Steps:
    wait:TEXT[:SECONDS]   wait until TEXT is on the screen (default 120 s);
                          "_" in TEXT stands for a blank
    key:K[,K...]          sendkey (QEMU key names), 0.3 s apart
    type:TEXT             type TEXT (US layout, "_" = blank) and Enter
    sleep:N               wait N seconds
    shot[:NAME]           screen shot OUTDIR/NAME.png (default shot<n>)
    mon:CMD[>NAME]        monitor command ("+" for blanks), output to
                          OUTDIR/NAME.txt (default mon<n>)
    regs[:NAME]           CPU registers to OUTDIR/NAME.txt (default regs<n>)
    text[:NAME]           text screen to OUTDIR/NAME.txt (default text<n>)
    rule:TEXT=K[,K...]    answer: whenever TEXT is on the screen during
                          "until", press the keys (rules keep their order)
    until:TEXT[:SECONDS]  like wait, applying the rules meanwhile (default
                          600 s); each answered screen is saved as
                          rule<n>.txt
    quit                  end QEMU
A step that waits in vain stores the screen as fail.png/fail.txt and ends
with exit code 1.
"""
import os
import socket
import subprocess
import sys
import time


KEYS = {' ': 'spc', '\\': 'backslash', '/': 'slash', '.': 'dot', ':': 'shift-semicolon',
        ',': 'comma', '-': 'minus', '=': 'equal', '>': 'shift-dot', '<': 'shift-comma',
        ';': 'semicolon', '*': 'shift-8', '?': 'shift-slash', '|': 'shift-backslash',
        '"': 'shift-apostrophe'}


class Monitor:
    def __init__(self, path):
        for _ in range(100):
            try:
                self.s = socket.socket(socket.AF_UNIX)
                self.s.connect(path)
                break
            except OSError:
                time.sleep(0.2)
        else:
            sys.exit('no QEMU monitor at ' + path)
        self.read()

    def read(self, timeout=1.0):
        self.s.settimeout(timeout)
        out = b''
        try:
            while not out.endswith(b'(qemu) '):
                d = self.s.recv(65536)
                if not d:
                    break
                out += d
        except socket.timeout:
            pass
        return out.decode('latin-1')

    def cmd(self, c, timeout=5.0):
        self.s.sendall((c + '\n').encode())
        return self.read(timeout)

    def screen(self):
        """80x25 text screen (VGA text memory at B8000h)"""
        out = self.cmd('xp /2000hx 0xb8000')
        chars = []
        for line in out.splitlines():
            if ':' not in line or not line.strip().startswith('00000000000b8'):
                continue
            for w in line.split(':', 1)[1].split():
                v = int(w, 16) & 0xFF
                chars.append(chr(v) if 32 <= v < 127 else ' ')
        text = ''.join(chars)[:2000]
        return '\n'.join(text[i:i + 80] for i in range(0, len(text), 80))


def main():
    sock, outdir = sys.argv[1], sys.argv[2]
    m = Monitor(sock)
    n = 0
    rules = []
    fired = 0
    for step in sys.argv[3:]:
        what, _, arg = step.partition(':')
        if what == 'wait':
            text, _, secs = arg.rpartition(':')
            if not secs.isdigit():
                text, secs = arg, ''
            text = text.replace('_', ' ')
            end = time.time() + (float(secs) if secs else 120)
            while text not in m.screen():
                if time.time() > end:
                    print('timeout waiting for %r' % text, flush=True)
                    with open(os.path.join(outdir, 'fail.txt'), 'w') as f:
                        f.write(m.screen())
                    m.cmd('screendump ' + os.path.join(outdir, 'fail.ppm'))
                    m.cmd('quit')
                    return 1
                time.sleep(1)
            print('found %r' % text, flush=True)
        elif what == 'rule':
            text, _, keys = arg.partition('=')
            rules.append((text.replace('_', ' '), keys.split(',')))
        elif what == 'until':
            text, _, secs = arg.rpartition(':')
            if not secs.isdigit():
                text, secs = arg, ''
            text = text.replace('_', ' ')
            end = time.time() + (float(secs) if secs else 600)
            idle = time.time()
            while True:
                scr = m.screen()
                if time.time() - idle > 30:	# no rule for a while: show it
                    with open(os.path.join(outdir, 'idle.txt'), 'w') as f:
                        f.write(scr)
                    idle = time.time()
                if text in scr:
                    print('found %r' % text, flush=True)
                    break
                if time.time() > end:
                    print('timeout waiting for %r' % text, flush=True)
                    with open(os.path.join(outdir, 'fail.txt'), 'w') as f:
                        f.write(scr)
                    m.cmd('screendump ' + os.path.join(outdir, 'fail.ppm'))
                    m.cmd('quit')
                    return 1
                for rtext, keys in rules:
                    if rtext in scr:
                        fired += 1
                        with open(os.path.join(outdir, 'rule%d.txt' % fired), 'w') as f:
                            f.write(scr)
                        print('rule %r: %s' % (rtext, ','.join(keys)), flush=True)
                        idle = time.time()
                        time.sleep(1)
                        for k in keys:
                            m.cmd('sendkey ' + k)
                            time.sleep(0.3)
                        time.sleep(3)
                        break
                else:
                    time.sleep(1)
        elif what == 'type':
            for ch in arg.replace('_', ' '):
                m.cmd('sendkey ' + KEYS.get(ch, ch.lower() if not ch.isupper() else 'shift-' + ch.lower()))
                time.sleep(0.1)
            m.cmd('sendkey ret')
            time.sleep(0.5)
        elif what == 'key':
            for k in arg.split(','):
                m.cmd('sendkey ' + k)
                time.sleep(0.3)
        elif what == 'sleep':
            time.sleep(float(arg))
        elif what == 'shot':
            n += 1
            m.cmd('screendump ' + os.path.join(outdir, (arg or 'shot%d' % n) + '.ppm'))
        elif what == 'text':
            n += 1
            with open(os.path.join(outdir, (arg or 'text%d' % n) + '.txt'), 'w') as f:
                f.write(m.screen())
        elif what == 'regs':
            n += 1
            with open(os.path.join(outdir, (arg or 'regs%d' % n) + '.txt'), 'w') as f:
                f.write(m.cmd('info registers'))
        elif what == 'mon':
            c, _, name = arg.partition('>')
            n += 1
            with open(os.path.join(outdir, (name or 'mon%d' % n) + '.txt'), 'w') as f:
                f.write(m.cmd(c.replace('+', ' ')))
        elif what == 'quit':
            m.cmd('quit')
            return 0
        else:
            sys.exit('unknown step ' + step)
    return 0


sys.exit(main())
