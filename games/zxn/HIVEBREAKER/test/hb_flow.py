# HIVEBREAKER: the whole loop - to a hive, in by its door, the chambers, the core, out again
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
SPACE, A, V = 16, 56, 8
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
def sh(n): z.shot('test/shots/f_%s.png' % n)
t0 = time.time()
z.run_frames(150); z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)          # god mode
z.setvar('var_dbg', 1); z.run_frames(30)         # 2560 units south of hive 0, facing its door
z.held = {V}; z.run_frames(40); z.held = set()   # throttle down a bit
sh('1_approach')
z.held = {SPACE}; z.run_frames(60); z.held = set(); sh('2_closer')
entered = False
for i in range(60):
    z.run_frames(10)
    if var('gmode') == 2: entered = True; break
print('entered the hive by its door:', entered, '(frames %d)' % z.frame)
z.run_frames(20); sh('3_room0')
print('room', var('inroom'), 'locked', var('locked'))
z.setvar('var_dbg', 4); z.run_frames(30); sh('4_room1'); print('room', var('inroom'), 'locked', var('locked'))
z.setvar('var_dbg', 4); z.run_frames(30); sh('5_room2'); print('room', var('inroom'))
z.held = {V}; z.run_frames(40); z.held = {A, V}; z.run_frames(15); sh('6_shooting')
n = 0
while var('cores') == 0 and n < 60:
    z.run_frames(10); n += 1
print('core destroyed:', var('cores') == 1, 'score', var('score'), 'exitT', var('exitt'))
z.held = set(); z.run_frames(40); sh('7_meltdown')
for i in range(60):
    z.run_frames(10)
    if var('gmode') == 1: break
print('back outside: mode', var('gmode'), 'cores', var('cores'), 'secs %.0f' % (time.time() - t0))
z.run_frames(30); sh('8_outside_again')
