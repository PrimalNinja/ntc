# wire.py - ROCKS in the emulator, swapping E3W's wireframe on (key 1) and off (key 2): pictures a
# second in each, screenshots into test/shots (wire_*.png). (c) 2026 Cyborg Unicorn Pty Ltd
#   python3 test/wire.py [frames a part]
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', 'tools', 'emu'))
from emu import NX
B = os.path.join(HERE, '..', 'build')
OUT = os.path.join(HERE, 'shots'); os.makedirs(OUT, exist_ok=True)
N = int(sys.argv[1]) if len(sys.argv) > 1 else 1000
z = NX(os.path.join(B, 'ROCKS.NEX'), os.path.join(B, 'ROCKS.sym'))
A, S, X, N_, M, SP, K1, K2 = 8, 9, 2, 59, 58, 56, 24, 25
plan = [{A}, {A, N_}, {A, S}, {A}, {A, M}, {A, X}, {A, SP}, {A}]
def fly(n, tag):
    f0 = z.frame; p0 = z.var('var_frames')
    while z.frame - f0 < n:
        z.held = plan[((z.frame - f0) // 60) % len(plan)]
        if (z.frame // 4) % 2: z.held = z.held - {A}
        z.run_frames(10)
        if (z.frame - f0) % 250 < 10:
            z.shot(os.path.join(OUT, 'wire_%s_%05d.png' % (tag, z.frame - f0)))
    p = z.var('var_frames') - p0
    print('%-6s %d frames, %d pictures: %.1f pictures a second, won %d, shield %d, score %d' % (tag, n, p, p * 50.0 / n,
          z.var('var_e3w_won'), z.var('var_shield'), z.var('var_score')))
def press(k):
    z.held = {k}; z.run_frames(10); z.held = set()
z.run_frames(200)
fly(N, 'solid')
press(K1)
fly(N, 'wire')
press(K2)
fly(N, 'solid2')
press(K1)
fly(N, 'wire2')
