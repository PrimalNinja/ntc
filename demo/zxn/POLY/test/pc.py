# pc.py NEX [n] - where the PC is, sampled n times (the nearest symbol)
import os, sys, time, bisect, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
items = sorted((v, k) for k, v in S.items() if not k.startswith(('var_', 'arr_', 'lit_', 'llit_')))
addrs = [a for a, _ in items]
def name(a):
    i = bisect.bisect_right(addrs, a) - 1
    return '%s+%d' % (items[i][1], a - items[i][0]) if i >= 0 else '?'
z = Zx(nex, wait=5)
c = collections.Counter()
for k in range(int(sys.argv[2]) if len(sys.argv) > 2 else 20):
    r = z.cmd('get-registers', 0.5)
    try: pc = int(r.split('PC=')[1][:4], 16); sp = int(r.split('SP=')[1][:4], 16)
    except Exception: continue
    c['%s  (sp %04x)' % (name(pc), sp)] += 1
z.close()
for n, v in c.most_common(40): print(v, n)
