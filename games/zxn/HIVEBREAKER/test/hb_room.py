# HIVEBREAKER: into hive 0 (the debug hook), look at the chamber
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
SPACE, A = 16, 56
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
z.run_frames(150)
z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)        # god mode
z.setvar('var_dbg', 2); z.run_frames(60)       # into hive 0
print('mode', var('gmode'), 'room', var('inroom'), 'locked', var('locked'), 'cz', var('shield'))
z.shot('test/shots/r1_room0.png')
z.held = {SPACE}; z.run_frames(60); z.held = set(); z.run_frames(10)
z.shot('test/shots/r2_room0_moved.png')
