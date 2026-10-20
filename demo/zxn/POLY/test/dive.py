# dive.py NEX keys secs - autopilot down to LOW, then hold the keys: altitude and frames every second
import os, sys, time, bisect
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
z = Zx(nex, wait=3)
def w(n):
    b = z.mem(S[n], 2); v = b[0] + b[1] * 256
    return v - 65536 if v > 32767 else v
lo = int(os.environ.get('LOW', '1500'))
while w('var_e3_palt') > lo: time.sleep(1)
for k in sys.argv[2]: z.key(ord(k), 1)
for i in range(int(sys.argv[3])):
    time.sleep(1); print(i, 'alt', w('var_e3_palt'), 'frames', w('var_frames'), 'speed', w('var_speed'), flush=True)
r = z.cmd('get-registers', 0.5); print(r)
z.shot(os.path.join(os.path.dirname(nex), 'dive.png'))
z.close()
