#!/usr/bin/env python3
# CyborgOS's boot loader COSLOAD.BIN on the cpcfw harness: COSLOAD (ROMs started, Z loaded from the
# CYBORGOS.Z1 ... files into C6 on, or kept), then CYBORGOS.BIN loaded at #0040 and started.
#   costest.py <files dir (its A: COSLOAD.BIN, CYBORGOS.BIN, CYBORGOS.Z1 ...)> <CYBORGOS .sym> 'typed' [--ram=576] [--boots=2]
# Prints the screen of each boot, then: COSLOAD opens=<CAS IN OPENs> per boot
import sys, os
args = sys.argv[1:]
boots = 1
for a in list(args):
    if a.startswith('--ram='): os.environ['NTC_RAM'] = a[6:]; args.remove(a)
    if a.startswith('--boots='): boots = int(a[8:]); args.remove(a)
os.environ['NTC_FILES'] = args[0]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ntcrun, cpcrun
syms = {}
for line in open(args[1]):
    p = line.replace(':', ' ').split()
    if len(p) >= 3 and p[1] == 'EQU': syms[p[0]] = int(p[2], 16)
typed = args[2].replace('\\n', '\r')
d = open(os.path.join(args[0], 'A', 'COSLOAD.BIN'), 'rb').read()
cos = d[128:]
opens = []
_cas = ntcrun.Host.cas
def cas(s, f):
    if f == "cas_in_open": opens.append(bytes(s.m.memory[s.m.hl:s.m.hl + s.m.b]).decode("latin-1"))
    return _cas(s, f)
ntcrun.Host.cas = cas
ext = None
for k in range(boots):
    opens.clear()
    h = ntcrun.Host('cpcfw', cos, 0x40, typed)
    cpcrun.endkey_set(h.m, syms)
    if ext is not None: h.ram.ext[:] = ext
    h.run(int(os.environ.get('NTC_LIMIT', '40000')))
    print(h.scr.text())
    print('--- boot %d opens: %s' % (k + 1, ' '.join(opens)))
    ext = bytes(h.ram.ext)
