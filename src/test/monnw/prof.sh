#!/bin/bash
# MON vs MONNW: CyborgOS runs "mon" (the map's index page), then 8 (Hex), then a link; the samples
# (NTC_PROF: SP each 13333 T chunk) in MON's own BASIC subs counted by sub
cd "$(dirname "$0")/.."
# the fixtures: CyborgOS's sources, SYSTEM.MAP, and the three MONs built with their symbols
rm -rf t; mkdir -p t/cy t/files/A; cp ../bas/cyborgos320kb/*.bas ../bas/cyborgos320kb/*.cls t/cy/; cp ../bas/cyborgos320kb/apps/mon/SYSTEM.MAP t/files/A/
A=../bas/cyborgos320kb/apps/mon; X="$A/Mouse.cls ../bas/cyborgos320kb/cmds/CybSys.cls"
node cli.js $A/MON.bas $A/Bml.cls $X --platform=cpm > monnw/MON.asm 2>/dev/null
node cli.js $A/MON.bas monnw/Bml.cls $X --platform=cpm > monnw/MONNW.asm 2>/dev/null
node cli.js $A/MON.bas monnw/fastr/Bml.cls $X --platform=cpm > monnw/MONFR.asm 2>/dev/null
for v in MON MONNW MONFR; do (cd monnw && ${SJASMPLUS:-sjasmplus} --nologo --msg=err --raw=$v.COM --sym=$v.sym $v.asm > /dev/null); done
W=$(printf '~%.0s' $(seq 1 40))
for v in ${VERS:-MON MONNW MONFR}; do
  python3 -c "import ntcrun; d = open('monnw/$v.COM', 'rb').read(); open('t/files/A/MON.CYB', 'wb').write(ntcrun.amsdos_header(d, 0x100) + d)"
  NTC_PROF=t/prof_$v.json NTC_LIMIT=40000 timeout 2500 python3 ntcrun.py t/cy/Main.bas "mon\n${W}${W}8${W}\n${W}${W}" t/cy/Hyp.cls t/cy/Hot.cls t/cy/Ent.cls --platform=cpcfw --ram=576 > t/out_$v.txt 2>&1
  python3 - $v <<'PY'
import json, sys, collections
v = sys.argv[1]
p = json.load(open('t/prof_%s.json' % v))['pc']
labs = []
for line in open('monnw/%s.sym' % v):
    a = line.replace(':', ' ').split()
    if a[0].startswith('p_') and not any(a[0].endswith(x) for x in ('_c', '_r')) and '_si' not in a[0] and '_e' != a[0][-2:]:
        labs.append((int(a[2], 16), a[0][2:]))
labs.sort()
end = max(x for x, n in labs) + 0x200
c = collections.Counter(); slot = 0
for pc, inbank, sp, _ in p:
    if not inbank: c['(hypervisor / main RAM)'] += 1; continue
    slot += 1
    if sp < labs[0][0] or sp > end: c['(MON: stack / library)'] += 1; continue
    n = [nm for a, nm in labs if a <= sp][-1]
    c['bml.' + n[4:] if n.startswith('bml_') else n] += 1
tot = len(p)
print('%s: %d samples (13333 T each, 1/300 s at 4MHz), in slots %d' % (v, tot, slot))
for n, k in c.most_common(14): print('  %-28s %6d  %5.1f%%' % (n, k, 100.0 * k / tot))
PY
done
