# tour.py NEX secs every [names...] - a long run: a screenshot every `every` seconds (tour_NNN.png in
# the NEX's folder) and the named variables printed with it
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
secs = float(sys.argv[2]); every = float(sys.argv[3]); names = sys.argv[4:]
z = Zx(nex, wait=3)
t0 = time.time(); n = 0
while time.time() - t0 < secs:
    time.sleep(every)
    p = os.path.join(os.path.dirname(nex), 'tour_%03d.png' % n)
    z.shot(p)
    vals = []
    for a in names:
        b = z.mem(S[a], 2)
        v = b[0] + b[1] * 256
        vals.append('%s=%d' % (a, v - 65536 if v > 32767 else v))
    print('%3d %5.1fs %s' % (n, time.time() - t0, ' '.join(vals)), flush=True)
    n += 1
z.close()
