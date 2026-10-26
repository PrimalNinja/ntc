# run.py - ROCKS in the emulator (NTC3D's tools/emu: nextemu with NEXTREG and the DMA):   # <--- CHANGED
# flies it with the keys held in turns, firing, for a while; screenshots into test/shots, a log in
# test/run_log.txt. (c) 2026 Cyborg Unicorn Pty Ltd
#   python3 test/run.py [frames]   # <--- CHANGED
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', '..', '..', 'tools', 'emu'))   # <--- CHANGED (the framework's own copy)
from emu import NX
B = os.path.join(HERE, '..', 'build')
OUT = os.path.join(HERE, 'shots'); os.makedirs(OUT, exist_ok=True)
N = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
z = NX(os.path.join(B, 'ROCKS.NEX'), os.path.join(B, 'ROCKS.sym'))
log = open(os.path.join(HERE, 'run_log.txt'), 'w')
def say(s): print(s); log.write(s + '\n'); log.flush()
A, S, X, N_, M, SP = 8, 9, 2, 59, 58, 56
plan = [{A}, {A, N_}, {A, S}, {A}, {A, M}, {A, X}, {A, SP}, {A}]
kinds = {}
evs = {'hits': 0}
f0 = z.frame; pics0 = 0; shot = 0
while z.frame - f0 < N:
    z.held = plan[((z.frame - f0) // 60) % len(plan)]
    if (z.frame // 4) % 2: z.held = z.held - {A}       # (fire as presses)
    z.run_frames(10)
    for i in range(32):
        if z.arr('arr_obj3d_ocls', i):
            k = (z.arr('arr_obj3d_otype', i), z.arr('arr_obj3d_omv', i))
            kinds[k] = kinds.get(k, 0) + 1
    if (z.frame - f0) % 500 < 10:
        z.shot(os.path.join(OUT, 'rocks_%05d.png' % (z.frame - f0))); shot += 1
        say('frame %d: score %d shield %d objects %d pictures %d' % (z.frame - f0, z.var('var_score'), z.var('var_shield'),
            sum(1 for i in range(32) if z.arr('arr_obj3d_ocls', i)), z.var('var_frames')))
pics = z.var('var_frames')
say('%d frames, %d pictures: %.2f frames a picture' % (z.frame - f0, pics, (z.frame - f0) / max(1, pics)))
say('seen (type, mover): times seen ' + ', '.join('%s %d' % (k, v) for k, v in sorted(kinds.items())))
