# demotest.py - the Demo: python3 tools/demotest.py outdir mode(0|1)   shots every page (page 9 is the attacker: types ATK, default SEVERE; mode 1 plays the pairing game, answering 1 to 10 in order)
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('NTC_EMU', '/home/claude/ntc2/NTC/src/ntc3d/tools/emu'))
from emu import NX
S = sys.argv[1]; md = int(sys.argv[2]); os.makedirs(S, exist_ok=True)
B = os.path.join(HERE, '..', 'build')
K = {'Q': 16, 'A': 8, 'O': 41, 'P': 40, 'SP': 56, 'Z': 1, 'E': 18, 'S': 9, 'V': 4, 'R': 19, 'T': 20, 'N': 59, 'ENTER': 48}
z = NX(os.path.join(B, 'INTRO.NEX'), os.path.join(B, 'INTRO.sym'))
held = set(); z.keysheld = lambda f: set(held)
def press(k, wait=40):
    held.add(K[k]); z.run_frames(4); held.discard(K[k]); z.run_frames(wait)
def shot(n): z.shot(os.path.join(S, n + '.png'), 2); print('shot', n, flush=True)
z.run_frames(60); press('SP', 150); press('SP', 150); z.run_frames(60); press('SP', 60)
for i in range(11 + md): press('A', 30)
press('SP', 60)
for i in range(int(os.environ.get('PROTO', '0'))): press('A', 20)
shot('intro')
press('SP', int(os.environ.get('GENW', '6000'))); shot('p01')
n = 11 + md
ATK = os.environ.get('ATK', 'SEVERE')
for p in range(2, n + 1):
    if p == 9:
        press('P', 60); shot('p09_type')
        for c in ATK: press(c, 6)
        shot('p09_typed')
        press('ENTER', int(os.environ.get('ATKW', '1500')))
    elif md == 1 and p == 10:
        press('P', 60); shot('p10_game')
        for i in range(10): press('SP' if i % 2 else 'SP', 40)
    else:
        press('P', 60)
    shot('p%02d' % p)
