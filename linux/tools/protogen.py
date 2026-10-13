#!/usr/bin/env python3
"""Replacement for "cl /Zg" of Microsoft C: write the prototypes of the
functions defined in a preprocessed C file (the .PRO files of MAXIMIZE
and INSTALL).

    protogen.py PREPROCESSED.I SOURCE.C > FILE.PRO

PREPROCESSED.I comes from "wcc -pl" (with #line markers): only the
definitions of SOURCE.C itself are taken, not those of included headers.

Every top-level "head { body }" whose head ends with a parameter list
becomes "head;".  Old style definitions (parameter declarations between
")" and "{") are turned into prototypes with the declared types.
"""
import re
import sys


def strip(text, main, keepall=False):
    """Remove comments, string and character literals and directives;
    text of other files than main (by #line markers) becomes blank
    (unless keepall)."""
    out, i, n = [], 0, len(text)
    inmain = True
    while i < n:
        c = text[i]
        if text.startswith('/*', i):
            j = text.find('*/', i + 2)
            i = n if j < 0 else j + 2
            out.append(' ')
        elif text.startswith('//', i):
            j = text.find('\n', i)
            i = n if j < 0 else j
        elif c in '"\'':
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == '\\' else 1
            out.append(c + c)
            i = j + 1
        elif c == '#' and (i == 0 or text[i - 1] == '\n'):
            j = text.find('\n', i)
            line = text[i:n if j < 0 else j]
            m = re.match(r'#\s*line\s+\d+\s+"([^"]*)"', line)
            if m:
                inmain = m.group(1).replace('\\', '/').split('/')[-1].lower() == main
            i = n if j < 0 else j
        else:
            out.append(c if inmain or keepall or c in '{};' else ' ')
            i += 1
    return ''.join(out)


def paramlist(head):
    """Find the parameter list of an old style head: a top level group
    "(a, b)" of names only, followed by declarations ending with ';'.
    Return (before, names, decls) or None (new style head)."""
    depth, start = 0, None
    for i, c in enumerate(head):
        if c == '(':
            if depth == 0:
                start = i
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                inner, rest = head[start + 1:i], head[i + 1:].strip()
                if rest.endswith(';') and re.fullmatch(r'[\w\s,]*', inner):
                    return head[:start], inner, rest
    return None


def oldstyle(head):
    """f(a, b) int a; char *b;  ->  f(int a, char *b)"""
    p = paramlist(head)
    if not p:
        return head
    before, names, rest = p
    decls = {}
    for d in rest.split(';'):
        d = d.strip()
        if not d:
            continue
        parts = d.split(',')
        tm = re.match(r'(.*?)([\s*]*\w+(?:\s*\[[^\]]*\])*)$', parts[0])
        typ = tm.group(1).strip()
        for k, part in enumerate(parts):
            part = part.strip() if k else tm.group(2).strip()
            name = re.search(r'(\w+)(?:\s*\[[^\]]*\])*$', part).group(1)
            decls[name] = (typ + ' ' + part).strip()
    args = [a.strip() for a in names.split(',') if a.strip()]
    newargs = [decls.get(a, 'int ' + a) for a in args]
    return f'{before.rstrip()}({", ".join(newargs) if newargs else "void"})'


def typedef(head, names, typedefs):
    """typedef struct tag {...} A, *PA;  /  typedef struct tag A;
    /  typedef unsigned char B;  -> typedefs[A] = 'struct tag' etc."""
    if names:                       # body: head "typedef struct tag"
        m = re.match(r'typedef\s+((?:struct|union|enum)\s+\w+)\s*$', head)
        if not m:
            return                  # no tag: nothing to write instead
        base, decls = m.group(1), names
    else:
        m = re.match(r'typedef\s+(.*?)\s*((?:\*\s*)*\w+(?:\s*,\s*(?:\*\s*)*\w+)*)$', head)
        if not m or '(' in head:
            return
        base, decls = m.group(1), m.group(2)
    for d in decls.split(','):
        d = d.strip()
        stars = d.count('*')
        name = d.replace('*', '').strip()
        if re.fullmatch(r'\w+', name):
            typedefs[name] = base + (' ' + '*' * stars if stars else '')


def collect(text):
    """typedefs at file level of text: name -> base type"""
    depth, start, typedefs, pending = 0, 0, {}, None
    for i, c in enumerate(text):
        if c == '{':
            if depth == 0:
                head = ' '.join(text[start:i].split())
                pending = head if head.startswith('typedef') else None
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                start = i + 1
        elif c == ';' and depth == 0:
            decl = ' '.join(text[start:i].split())
            if pending:
                typedef(pending, decl, typedefs)
            elif decl.startswith('typedef'):
                typedef(decl, '', typedefs)
            pending = None
            start = i + 1
    return typedefs


def resolve(name, typedefs, mine, seen=()):
    """Base type of a typedef name like "cl /Zg" writes it"""
    base = typedefs[name]
    if base.startswith('enum'):
        return 'int' if name in mine else name
    words = base.replace('*', ' ').split()
    for w in words:
        if w in typedefs and w not in seen and w != name:
            base = re.sub(r'\b%s\b' % w, resolve(w, typedefs, mine, seen + (name,)), base)
    return base


def main():
    raw = open(sys.argv[1], encoding='latin-1').read()
    mainname = sys.argv[2].split('/')[-1].lower()
    text = strip(raw, mainname)
    alltd = collect(strip(raw, mainname, keepall=True))
    mine = collect(text)
    depth, start, i = 0, 0, 0
    protos = []
    while i < len(text):
        c = text[i]
        if c == '{':
            if depth == 0:
                head = ' '.join(text[start:i].split())
                # a function definition: the head has a parameter list and
                # is no struct/union/enum/initializer
                if head and re.search(r'\)\s*(?:[\w\s,*\[\];]*;)?\s*$', head) and \
                   not re.search(r'=\s*$|\b(struct|union|enum)\s+\w*\s*$', head) and \
                   '(' in head:
                    protos.append(oldstyle(head) + ';')
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                start = i + 1
        elif c == ';' and depth == 0:
            start = i + 1
        i += 1
    # like "cl /Zg": typedef names are written as their base types (where
    # the prototypes are included, the typedefs may be unknown); struct
    # tags get a file level declaration first
    def subst(p):
        def one(m):
            return resolve(m.group(0), alltd, mine) if m.group(0) in alltd else m.group(0)
        # not the function name itself
        return re.sub(r'\b\w+\b', one, p)
    protos = [subst(p) for p in protos]
    tags = sorted(set(re.findall(r'\b((?:struct|union)\s+\w+)', ' '.join(protos))))
    for t in tags:
        print(t + ';')
    for p in protos:
        print(p)


main()
