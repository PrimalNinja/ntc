# t5.py - the Demo with an SD card: python3 tools/t5.py outdir mode PROTO   shots the challenge page and every encoding page, presses SPACE on the challenge page (saves the files), lists the SD folder
import os, sys, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get('NTC_EMU', '/home/claude/ntc2/NTC/src/ntc3d/tools/emu'))
sys.path.insert(0, '/home/claude/game/ZOSCIITOOL_ZXN/tools')
from esx import ESX
S = sys.argv[1]; md = int(sys.argv[2]); pro = int(sys.argv[3]); os.makedirs(S, exist_ok=True)
SD = os.path.join(S, 'sd'); shutil.rmtree(SD, ignore_errors=True); os.makedirs(SD)
B = os.path.join(HERE, '..', 'build')
K = {'ENTER': 48, 'T': 20, 'K': 33, 'Q': 16, 'A': 8, 'O': 41, 'P': 40, 'SP': 56, 'Z': 1}
z = ESX(os.path.join(B, os.environ.get('NEX', 'INTRO') + '.NEX'), os.path.join(B, os.environ.get('NEX', 'INTRO') + '.sym'), SD)
held = set(); z.keysheld = lambda f: set(held)
def press(k, wait=40):
    held.add(K[k]); z.run_frames(4); held.discard(K[k]); z.run_frames(wait)
def shot(n): z.shot(os.path.join(S, n + '.png'), 2); print('shot', n, flush=True)
z.run_frames(60); press('SP', 150); press('SP', 150); z.run_frames(60); press('SP', 60)
for i in range(11 + md): press('A', 30)
press('SP', 60)
for i in range((pro + 1) % 6): press('A', 20)
shot('intro')
press('SP', int(os.environ.get('GENW', '6000'))); shot('p01')
for p in range(2, 5): press('P', 60); shot('p%02d' % p)
press('SP', 120); shot('p04_saved')
for p in range(5, int(os.environ.get('LAST', '9'))): press('P', 80); shot('p%02d' % p)
print(sorted(os.listdir(SD)), z.log[-3:])
for f in sorted(os.listdir(SD)): print(f, os.path.getsize(os.path.join(SD, f)))
if os.environ.get('FULL'):
    shot('atk_type')
    K.update({'A': 8, 'T': 20, 'K': 33})
    for c in 'ATK': press(c, 6)
    shot('atk_typed')
    press('ENTER', 1500); shot('atk_done')
    press('P', 100); shot('answer')
    press('P', 600); shot('proof')
