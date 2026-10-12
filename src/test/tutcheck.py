import os, re, sys, subprocess, shutil
# tutcheck.py - check the tutorial (docs/tutorial): every ```basic block in it: it compiles; with a ```text block after it, it
# prints that (ntcrun, test platform unless <!-- run: plat ... --> says otherwise)
# <!-- file: X.cls --> : the block is an extra file for the next plain block
# <!-- nocheck --> : skip the next block;  <!-- platform: cpm --> : compile (and run) there
# <!-- run: cpm keys="..." cmdline="..." ram=576 --> : platform, typed keys, command tail
T = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(T, '..', '..', 'docs', 'tutorial')
W = os.path.join(T, 't', 'tut')
only = sys.argv[1:]
bad = 0; n = 0
for f in sorted(os.listdir(D)):
    if not re.match(r'\d+\.\d+-', f): continue
    if only and not any(f.startswith(o + '-') for o in only): continue
    text = open(os.path.join(D, f)).read()
    parts = re.split(r'(<!--.*?-->|```basic\n.*?```\n(?:\n*```text\n.*?```\n)?)', text, flags=re.S)
    extra = []; meta = {}
    for p in parts:
        if p.startswith('<!--'):
            c = p[4:-3].strip()
            if c.startswith('file:'): meta['file'] = c[5:].strip()
            elif c == 'nocheck': meta['nocheck'] = 1
            elif c.startswith('platform:'): meta['plat'] = c[9:].strip()
            elif c.startswith('run:'):
                r = c[4:].strip(); meta['plat'] = r.split()[0]
                k = re.search(r'keys="(.*?)"', r); meta['keys'] = k.group(1) if k else ''
                k = re.search(r'cmdline="(.*?)"', r); meta['cmdline'] = k.group(1) if k else None
                k = re.search(r'ram=(\d+)', r); meta['ram'] = k.group(1) if k else None
                k = re.search(r'files="(.*?)"', r); meta['files'] = k.group(1) if k else None
            continue
        if not p.startswith('```basic'): continue
        m = re.match(r'```basic\n(.*?)```\n(?:\n*```text\n(.*?)```\n)?', p, re.S)
        code, want = m.group(1), m.group(2)
        if meta.get('nocheck'): meta = {}; continue
        if 'file' in meta: extra.append((meta['file'], code)); meta = {k: v for k, v in meta.items() if k != 'file'}; continue
        n += 1
        if os.path.exists(W): shutil.rmtree(W)
        os.makedirs(W)
        open(os.path.join(W, 'Main.bas'), 'w').write(code)
        files = []
        for nm, c in extra:
            open(os.path.join(W, nm), 'w').write(c); files.append(os.path.join(W, nm))
        plat = meta.get('plat', 'test')
        args = ['python3', os.path.join(T, 'ntcrun.py'), os.path.join(W, 'Main.bas'), (meta.get('keys') or '') + '~x~x~x'] + files + ['--platform=' + plat]
        if meta.get('cmdline'): args.append('--cmdline=' + meta['cmdline'])
        if meta.get('ram'): args.append('--ram=' + meta['ram'])
        if meta.get('files'):
            fd = os.path.join(T, 't', 'files', 'A'); os.makedirs(fd, exist_ok=True)
            for spec in meta['files'].split(';'):
                fn, body = spec.split('=', 1); open(os.path.join(fd, fn), 'w').write(body.replace('\\n', '\r\n'))
        r = subprocess.run(['node', os.path.join(T, 'cli.js'), os.path.join(W, 'Main.bas')] + files + ['--platform=' + plat], capture_output=True, text=True)
        errs = [l for l in r.stderr.splitlines() if l.startswith('ERR')]
        if errs:
            bad += 1; print('%s: COMPILE %s' % (f, errs[:3])); print(code[:200]); meta = {}; extra = []; continue
        if want is not None:
            o = subprocess.run(args, capture_output=True, text=True, timeout=300).stdout
            lines = [l.rstrip() for l in o.splitlines() if not l.startswith('---') and not l.startswith('TIMEOUT') and not l.startswith('WARN')]
            while lines and not lines[-1]: lines.pop()
            got = '\n'.join(lines)
            exp = '\n'.join(l.rstrip() for l in want.rstrip('\n').splitlines())
            if got != exp:
                bad += 1; print('%s: OUTPUT\n--- want\n%s\n--- got\n%s' % (f, exp, got))
        meta = {}; extra = []
print(n, 'blocks,', bad, 'bad')
sys.exit(1 if bad else 0)
