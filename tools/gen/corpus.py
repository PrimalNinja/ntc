#!/usr/bin/env python3
# corpus.py - the training text for GEN: every NTC BASIC source (.bas, .cls) and Z80 assembly
# (.asm, not the 68K's) under the folders given, as one file a kind, each source ended by a form
# feed so the model learns where a program starts. Characters kept: ASCII 32-126 and the newline;
# a tab is two spaces; the rest dropped. Lines are cut at 120 characters (a CPC screen and a half).
#   python3 tools/gen/corpus.py OUTDIR FOLDER [FOLDER ...]
# Writes OUTDIR/basic.txt and OUTDIR/asm.txt and prints the sizes.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys
out, folders = sys.argv[1], sys.argv[2:]
os.makedirs(out, exist_ok=True)
SKIP = ('/_old/', '/out/', '/build/', '/3p/', '/node_modules/', '/stage/')
def clean(t):
    r = []
    for line in t.replace('\r\n', '\n').replace('\r', '\n').replace('\t', '  ').split('\n'):
        line = ''.join(c for c in line if 32 <= ord(c) <= 126)
        r.append(line[:120])
    return '\n'.join(r).strip('\n') + '\n'
kinds = {'basic': ('.bas', '.cls'), 'asm': ('.asm',)}
files = {k: [] for k in kinds}
for f in folders:
    for root, dirs, names in os.walk(f):
        for n in sorted(names):
            p = os.path.join(root, n)
            if any(s in p + '/' for s in SKIP): continue
            low = n.lower()
            for k, exts in kinds.items():
                if low.endswith(exts) and not ('68k' in low):
                    files[k].append(p)
for k in kinds:
    seen = set(); parts = []
    for p in files[k]:
        try: t = open(p, encoding='latin-1').read()
        except Exception: continue
        c = clean(t)
        h = hash(c)
        if h in seen or len(c) < 40: continue   # (the same file in two trees once)
        seen.add(h); parts.append(c)
    text = '\f'.join(parts)
    open(os.path.join(out, k + '.txt'), 'w').write(text)
    print('%s: %d files, %d bytes' % (k, len(parts), len(text)))
