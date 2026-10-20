# tour2.py NEX secs every - a long run: a clean screenshot every `every` seconds (the emulator stopped
# for it: tour_NNN.png beside the NEX), with the frame rate since the last one, the height, the way point
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
secs = float(sys.argv[2]); every = float(sys.argv[3])
z = Zx(nex, wait=3)
def w(n):
    b = z.mem(S[n], 2); v = b[0] + b[1] * 256
    return v - 65536 if v > 32767 else v
t0 = time.time(); n = 0; lf = w('var_frames'); lt = time.time()
while time.time() - t0 < secs:
    time.sleep(every)
    z.cmd('enter-cpu-step')
    f = w('var_frames'); t = time.time()
    z.shot(os.path.join(os.path.dirname(nex), 'tour_%03d.png' % n))
    print('%3d %5.1fs fps %4.1f alt %5d wp %d' % (n, t - t0, (f - lf) / (t - lt), w('var_e3_palt'), w('var_wp')), flush=True)
    z.cmd('exit-cpu-step')
    lf = w('var_frames'); lt = time.time(); n += 1
z.close()
