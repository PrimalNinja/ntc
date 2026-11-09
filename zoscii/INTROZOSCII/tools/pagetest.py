# pagetest.py - opens contents items (fresh emulator each) and pages through them, screenshots each page
#   python3 tools/pagetest.py outdir item:pages [item:pages ...]     (item = 0-based contents row)
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('NTC_EMU', '/home/claude/ntc2/NTC/src/ntc3d/tools/emu'))
from emu import NX
S = sys.argv[1]; os.makedirs(S, exist_ok=True)
B = os.path.join(HERE, '..', 'build')
K = {'Q': 16, 'A': 8, 'O': 41, 'P': 40, 'SP': 56, 'Z': 1}
for spec in sys.argv[2:]:
    item, pages = [int(x) for x in spec.split(':')]
    z = NX(os.path.join(B, 'INTRO.NEX'), os.path.join(B, 'INTRO.sym'))
    held = set(); z.keysheld = lambda f: set(held)
    def press(k, wait=40):
        held.add(K[k]); z.run_frames(4); held.discard(K[k]); z.run_frames(wait)
    z.run_frames(60); press('SP', 150); press('SP', 150)
    z.run_frames(60); press('SP', 60)
    if item == 0: z.shot(os.path.join(S, 'menu.png'), 2)
    for i in range(item): press('A', 30)
    press('SP', 60)
    z.shot(os.path.join(S, 'i%02d_p1.png' % item), 2); print('shot', item, 1, flush=True)
    for p in range(2, pages + 1):
        press('P', 40); z.shot(os.path.join(S, 'i%02d_p%d.png' % (item, p)), 2); print('shot', item, p, flush=True)
