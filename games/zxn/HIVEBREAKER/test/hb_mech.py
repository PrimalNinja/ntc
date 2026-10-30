# HIVEBREAKER: the mech - the tank, the transform to the walker, driving, the jump and its recharge, the guns
import sys, os
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
FIRE, FASTER, SLOWER, LEFT, RIGHT, JUMP, FORM, ECM = 56, 16, 8, 41, 40, 17, 9, 18     # keys: half row x 8 + bit
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
def sh(n): z.shot('test/shots/m_%s.png' % n)
z.run_frames(150); sh('0_title')
z.held = {FIRE}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)
z.held = {FASTER}; z.run_frames(40); z.held = set(); z.run_frames(30); sh('1_tank')
print('tank: mech', var('mech'), 'xf', var('xf'), 'speed', var('spd'), 'eye', var('cam'))
z.held = {FIRE}; z.run_frames(14); sh('2_tank_firing'); z.held = set()
z.held = {FORM}; z.run_frames(6); z.held = set(); z.run_frames(12); sh('3_changing')
z.run_frames(30); sh('4_walker')
print('walker: mech', var('mech'), 'xf', var('xf'), 'speed', var('spd'), 'eye', var('cam'))
z.held = {FIRE}; z.run_frames(14); sh('5_walker_firing'); z.held = set()
z.held = {FASTER, RIGHT}; z.run_frames(50); sh('6_walker_walking'); z.held = set()
j0 = var('jc'); z.held = {JUMP}; z.run_frames(6); z.held = set()
top = 0
for i in range(30):
    z.run_frames(2); top = max(top, var('jy'))
    if i == 8: sh('7_jump')
print('jump: charge %d -> %d, peak height %d, back down: jy %d' % (j0, var('jc'), top, var('jy')))
z.held = {JUMP}; z.run_frames(6); z.held = set(); z.run_frames(10)
print('a second jump at once: jy', var('jy'), '(charge %d)' % var('jc'))
z.run_frames(250); print('after a rest: charge', var('jc'))
