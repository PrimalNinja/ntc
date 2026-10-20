# peek.py NEX secs name[:n] ... - after secs, words at symbols (arrays: n words)
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
z = Zx(nex, wait=5); time.sleep(float(sys.argv[2]))
for a in sys.argv[3:]:
    n = 1
    if ':' in a: a, n = a.split(':'); n = int(n)
    ad = int(a[1:], 16) if a.startswith('#') else (S[a] if a in S else S[a.split('+')[0]] + int(a.split('+')[1]))
    b = z.mem(ad, 2 * n)
    w = [b[i] + b[i + 1] * 256 for i in range(0, 2 * n, 2)]
    print(a, [x - 65536 if x > 32767 else x for x in w])
z.close()
