# nrun.py prog.asm : an NTC zxn program (its NEX) on NTC's Next harness; prints the T-states between OUT (254), n marks and the screen
import sys, os, re
sys.path.insert(0, sys.argv[2])
import zxnrun
asm = sys.argv[1]
syms = {}
for l in open(asm[:-4] + '.sym'):
    mm = re.match(r'^(\S+):\s+EQU\s+0x([0-9A-Fa-f]+)', l)
    if mm: syms[mm.group(1)] = int(mm.group(2), 16)
z = zxnrun.Next(zxnrun.nex_name(asm), '', syms)
marks = []; old = z.out
def out(port, val):
    if (port & 0xFF) == 0xFE: marks.append((val, z.T + (z.q - z.m.ticks_to_stop if z.q else 0)))
    old(port, val)
z.m.set_output_callback(out)
z.run(limit=3000000)
for i in range(1, len(marks)): print('B%d %d' % (marks[i - 1][0], marks[i][1] - marks[i - 1][1]))
print(z.screen().strip()[:200], '| ints', z.ints, '| speed reg', z.regs.get(7))
