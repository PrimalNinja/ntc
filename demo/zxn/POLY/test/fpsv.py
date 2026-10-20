# fpsv.py NEX [vars...] - frames counted in 10 s (no keys), the vars, a screenshot
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
z = Zx(nex, wait=5)
def v(n):
    b = z.mem(S[n], 2); x = b[0] + b[1] * 256
    return x - 65536 if x > 32767 else x
time.sleep(2)
a = v('var_frames'); t = time.time(); time.sleep(6); b = v('var_frames')
print('%.1f loops a second' % (((b - a) & 0xFFFF) / (time.time() - t)))
for e in sys.argv[2:]: print(e, v(e))
z.shot(nex[:-4] + '.png')
z.close()
