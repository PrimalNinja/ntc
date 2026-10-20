# play.py [NEX] [seconds] [shots every] - a scripted run: flies left and right, up and down, holds
# fire, changes the pattern now and then; screenshots into test/shots/run_NN.png, a contact sheet
# run.png; the frames counted (var_frames) a second
import os, sys, time, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from zx import Zx, syms
from PIL import Image
H = os.path.dirname(os.path.abspath(__file__))
nex = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(H, '..', 'build', 'CYBORG.NEX'))
secs = int(sys.argv[2]) if len(sys.argv) > 2 else 40
every = float(sys.argv[3]) if len(sys.argv) > 3 else 2
S = syms(nex[:-4] + '.sym')
out = os.path.join(H, 'shots'); os.makedirs(out, exist_ok=True)
for f in os.listdir(out):
    if f.startswith('run'): os.remove(os.path.join(out, f))
z = Zx(nex, wait=6)
def var(n):
    b = z.mem(S['var_' + n], 2); v = b[0] + b[1] * 256
    return v - 65536 if v > 32767 else v
z.tap('z', 0.3)
time.sleep(3)
rnd = random.Random(1)
shots = []
t0 = time.time(); n = 0; nxt = t0 + every
f0 = var('frames'); tf = time.time()
FIRE = [ord(c) for c in os.environ.get('SPRAYS', 'zxcvbnm ')]
for c in FIRE: z.key(c, 1)
held = []
while time.time() - t0 < secs:
    for h in held: z.key(ord(h), 0)
    held = []
    r = rnd.random()
    if r < 0.3: held.append('p')
    elif r < 0.6: held.append('o')
    r = rnd.random()
    if r < 0.3: held.append('q')
    elif r < 0.6: held.append('a')
    for h in held: z.key(ord(h), 1)
    time.sleep(0.4)
    if time.time() >= nxt:
        p = os.path.join(out, 'run_%02d.png' % n); z.shot(p); shots.append(p); n += 1; nxt += every
for h in held: z.key(ord(h), 0)
for c in FIRE: z.key(c, 0)
f1 = var('frames')
print('%.1f frames a second' % (((f1 - f0) & 0xFFFF) / (time.time() - tf)))
for v in ('camx', 'camy', 'alive', 'lives', 'sprays', 'build', 'cybst', 'zone', 'tickl', 'tickm'):
    if 'var_' + v in S: print(v, var(v), end='  ')
print()
z.close()
cols = 4
W = Image.new('RGB', (320 * cols, 256 * ((len(shots) + cols - 1) // cols)))
for i, p in enumerate(shots): W.paste(Image.open(p), ((i % cols) * 320, (i // cols) * 256))
W.save(os.path.join(out, 'run.png'))
print(len(shots), 'shots')
