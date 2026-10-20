# fuzz.py NEX secs seed [keys] - random flying on the keys; reports where it stops if the frames stop
import os, sys, time, random, bisect
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
nex = os.path.abspath(sys.argv[1]); S = syms(nex[:-4] + '.sym')
secs = float(sys.argv[2]); rnd = random.Random(int(sys.argv[3]))
keys = sys.argv[4] if len(sys.argv) > 4 else 'qaopzx m'
items = sorted((v, k) for k, v in S.items() if not k.startswith(('var_', 'arr_', 'lit_', 'llit_')))
addrs = [a for a, _ in items]
def name(a):
    i = bisect.bisect_right(addrs, a) - 1
    return '%s+%d' % (items[i][1], a - items[i][0]) if i >= 0 else '?'
z = Zx(nex, wait=3)
def w(n):
    b = z.mem(S[n], 2); v = b[0] + b[1] * 256
    return v - 65536 if v > 32767 else v
lo = int(os.environ.get('LOW', '0'))
if lo:
    while w('var_e3_palt') > lo: time.sleep(1)
    print('low at', w('var_e3_palt'))
t0 = time.time(); last = w('var_frames'); stuck = 0; held = []
while time.time() - t0 < secs:
    for k in held: z.key(ord(k), 0)
    held = rnd.sample(keys, rnd.randint(0, 2))
    for k in held: z.key(ord(k), 1)
    time.sleep(0.5 + rnd.random() * 2)
    f = w('var_frames')
    if f == last:
        stuck += 1
        if stuck >= 3:
            r = z.cmd('get-registers', 0.5); print('STUCK at %.0fs' % (time.time() - t0)); print(r)
            pc = int(r.split('PC=')[1][:4], 16); sp = int(r.split('SP=')[1][:4], 16)
            print('pc', name(pc)); m = z.mem(sp, 16); print('stack', [name(m[j] + m[j + 1] * 256) for j in range(0, 16, 2)])
            print('alt', w('var_e3_palt'), 'speed', w('var_speed'), 'cp', list(z.mem(S['arr_e3_cp'], 12)))
            z.shot(os.path.join(os.path.dirname(nex), 'stuck.png'))
            break
    else: stuck = 0
    last = f
else:
    print('ran %.0fs, frames %d, alt %d' % (time.time() - t0, w('var_frames'), w('var_e3_palt')))
z.close()
