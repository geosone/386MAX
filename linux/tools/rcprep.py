#!/usr/bin/env python3
"""Prepare a Microsoft RC resource script for OpenWatcom's wrc.

    rcprep.py IN.I OUT.RC

IN.I is the script preprocessed by wrc (wrc -o: includes, #if and macros
done like RC does them).  Microsoft RC concatenates adjacent string
literals ("Version " VER_PRODUCTVERSION_STR becomes "Version " "8.03");
wrc does not, so every run of adjacent literals is made one literal.
wrc also writes wrong lengths for a version VALUE made of several strings
("CompanyName", "Qualitas, Inc.", "\\0"): such a list is made one string
(a trailing "\\0" is dropped, wrc adds the terminator).  And wrc (2.0)
writes a VALUE string without its terminating zero, relying on the padding
to a 4-byte boundary, but counts it: a string whose length is a multiple
of 4 gets an explicit "\\0".
"""
import re
import sys

STR = r'"(?:[^"\\\n]|\\.|"")*"'


def merge_adjacent(text):
    """"a" "b" -> "ab", also across line breaks (as RC does), not in
    preprocessor lines (#line ...)"""
    lines = text.split('\n')
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.lstrip().startswith('#'):
            out.append(line)
            i += 1
            continue
        # a line ending in a literal: join following lines that are only
        # literals (blank lines in between are kept out)
        while re.search(STR + r'\s*$', line):
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            if j < len(lines) and re.fullmatch(r'\s*' + STR + r'(?:\s*' + STR + r')*\s*', lines[j]):
                line = line.rstrip() + ' ' + lines[j].strip()
                i = j
            else:
                break
        line = re.sub(r'(?:' + STR + r'\s*){2,}',
                      lambda m: '"' + ''.join(s[1:-1] for s in re.findall(STR, m.group(0))) + '" ',
                      line)
        out.append(line)
        i += 1
    return '\n'.join(out)


def strlen(lit):
    """bytes of a C string literal body"""
    return len(re.findall(r'\\(?:[0-7]{1,3}|x[0-9a-fA-F]+|.)|""|[^\\]', lit))


def join_values(text):
    """VALUE "key", "a", "b" -> VALUE "key", "ab" (strings only)"""
    def repl(m):
        items = re.findall(STR + r'|[^\s,]+', m.group(2))
        if not items or not all(i.startswith('"') for i in items):
            return m.group(0)
        if items[-1] == r'"\0"':
            items = items[:-1]
        body = ''.join(i[1:-1] for i in items)
        if strlen(body) % 4 == 0:
            body += r'\0'
        return m.group(1) + '"' + body + '"'
    return re.sub(r'^(\s*VALUE\s+' + STR + r'\s*,\s*)(.*?)\s*$', repl, text, flags=re.M)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    text = open(src, encoding='latin-1').read()
    open(dst, 'w', encoding='latin-1').write(join_values(merge_adjacent(text)))


main()
