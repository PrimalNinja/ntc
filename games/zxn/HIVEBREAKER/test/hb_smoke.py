# HIVEBREAKER smoke test: boot, title, start, drive, shoot (NTC3D's emulator in ntc3d/tools/emu; pip install z80 pillow)
import sys, os, time
HERE = os.path.dirname(os.path.abspath(__file__))
def _emu():
    for p in (os.environ.get('NTC3D_EMU'), os.path.join(os.environ.get('NTC_SRC', ''), 'ntc3d', 'tools', 'emu'), os.path.join(HERE, '..', '..', '..', 'tools', 'emu')):
        if p and os.path.isdir(p):
            return p
    return ''
sys.path.insert(0, _emu())
from emu import NX
os.chdir(os.path.join(HERE, '..'))
os.makedirs('test/shots', exist_ok=True)
SPACE, A, N, M, V, E = 56, 8, 59, 58, 4, 18      # keys: half row x 8 + bit
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
t0 = time.time()
z.run_frames(150); z.shot('test/shots/s1_title.png')
z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(60)
print('mode', var('gmode'), 'frames', var('frames'), 'ox', var('ox'), 'oz', var('oz'), 'shield', var('shield'))
z.shot('test/shots/s2_start.png')
z.held = {SPACE}; z.run_frames(150); z.held = set()
z.held = {A, SPACE}; z.run_frames(120); z.held = set(); z.run_frames(30)
z.shot('test/shots/s3_drive.png')
print('after driving: mode', var('gmode'), 'spd', var('shield'), 'score', var('score'), 'secs %.0f' % (time.time() - t0))
