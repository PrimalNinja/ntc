#!/usr/bin/env python3
# CyborgOS reset survival: boot once (RAM discs built from disc), keep the expansion RAM as a
# reset would, boot again. The second boot must reclaim the RAM discs from the surviving pages
# (its driver page's "CYBD" signature and D_POOL checksum) with no file loading at all.
# Prints: RESET opens1=<n> opens2=<n> zfiles=<names>
# Args like ntcrun.py: Main.bas, then the .cls files, then --platform / --ram
import sys, os, subprocess
sys.path.insert(0, '.')
import ntcrun, cpcrun

args = sys.argv[1:]
plat = 'cpcfw'
for a in list(args):
    if a.startswith('--platform='): plat = a[11:]; args.remove(a)
    if a.startswith('--ram='): os.environ['NTC_RAM'] = a[6:]; args.remove(a)
bas = args[0]; extra = args[1:]
asm = bas[:-4] + '.asm'
r = subprocess.run(['node', 'cli.js', bas] + extra + ['--platform=' + plat], capture_output=True, text=True)
open(asm, 'w').write(r.stdout)
b, syms = cpcrun.assemble(asm)
org = syms['ntc_start']

opens = [0]
_cas = ntcrun.Host.cas
def cas(s, f):
    if f == 'cas_in_open': opens[0] += 1
    return _cas(s, f)
ntcrun.Host.cas = cas

def boot(ext):
    h = ntcrun.Host(plat, b, org, '')
    cpcrun.endkey_set(h.m, syms)
    if ext is not None: h.ram.ext[:] = ext
    opens[0] = 0
    h.run(int(os.environ.get('NTC_LIMIT', '60000')))
    return h

h1 = boot(None); o1 = opens[0]
ext = bytes(h1.ram.ext)
h2 = boot(ext); o2 = opens[0]
# the surviving driver page: find "CYBD", read its D_VOL letter and D_DIR names
e = bytes(h2.ram.ext); names = []; letter = '-'
i = e.find(b'CYBD')
if i >= 0:
    pg = (i // 0x4000) * 0x4000                 # the driver page's start in ext
    dv = e[pg + 0x2A00]
    letter = chr(dv) if dv else '-'
    base = pg + 0x2C00
    for k in range(16):
        d = e[base + k * 20:base + k * 20 + 20]
        if d and d[0]: names.append(''.join(chr(c & 0x7F) for c in d[1:12] if c > 32))
print('RESET opens1=%d opens2=%d zletter=%s zfiles=%s' % (o1, o2, letter, ','.join(names)))
