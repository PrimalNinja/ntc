# splashtest.py - the startup splash: python3 tools/splashtest.py outdir   shots the two splash screens (fade in, hold) and the title after them
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('NTC_EMU', '/home/claude/ntc2/NTC/src/ntc3d/tools/emu'))
from emu import NX
S = sys.argv[1]; os.makedirs(S, exist_ok=True)
B = os.path.join(HERE, '..', 'build')
z = NX(os.path.join(B, 'INTRO.NEX'), os.path.join(B, 'INTRO.sym'))
z.keysheld = lambda f: set()
def shot(n): z.shot(os.path.join(S, n + '.png'), 2); print('shot', n, flush=True)
z.run_frames(30); shot('splash1_fadein')
z.run_frames(100); shot('splash1_hold')
z.run_frames(330); shot('splash2_ntc')
z.run_frames(400); shot('after')
