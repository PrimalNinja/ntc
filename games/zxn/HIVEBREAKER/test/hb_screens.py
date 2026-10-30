# HIVEBREAKER: dying, game over, the Warden, the last core and the victory screen
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
SPACE, A, V = 16, 56, 8
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
def sh(n): z.shot('test/shots/x_%s.png' % n)
def start():
    z.run_frames(150); z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(40)
start()
# dying: a life gone, repaired
z.setvar('var_shield', 0); z.run_frames(12)
print('died once: lives', var('lives'), 'shield', var('shield'), 'mode', var('gmode')); sh('died_msg')
# game over
z.setvar('var_lives', 1); z.setvar('var_shield', 0); z.run_frames(20)
print('last life gone: mode', var('gmode')); z.run_frames(40); sh('gameover')
z.run_frames(300); print('then: mode', var('gmode')); sh('title_again')
# a new game: the Warden
z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(40)
print('new game: mode', var('gmode'), 'lives', var('lives'), 'score', var('score'))
z.setvar('var_dbg', 3); z.run_frames(5)
z.setvar('var_dbg', 2); z.run_frames(30)
z.held = {V}; z.run_frames(40); z.held = set()
z.setvar('var_dbg', 6); z.run_frames(120)
print('warden spawned:', any(z.arr('arr_obj3d_otype', j) == 14 and z.arr('arr_obj3d_ocls', j) for j in range(44)))
sh('warden')
# the last core: five gone, the sixth shot, out again - the victory screen (a fresh game: the Warden's been at us)
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
z.run_frames(150); z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)
z.setvar('var_dbg', 2); z.run_frames(30)
z.setvar('var_dbg', 7); z.run_frames(5)
z.setvar('var_dbg', 4); z.run_frames(20); z.setvar('var_dbg', 4); z.run_frames(20)
z.held = {V}; z.run_frames(60); z.held = {A, V}
for i in range(60):
    z.run_frames(10)
    if var('cores') == 6: break
z.held = set()
print('cores', var('cores'))
for i in range(80):
    z.run_frames(10)
    if var('gmode') == 4: break
print('mode', var('gmode'), 'score', var('score')); z.run_frames(20); sh('victory')
