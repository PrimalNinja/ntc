# HIVEBREAKER: the swarm outdoors (all the robot types), a survivor, an electrode, the E.C.M.
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
SPACE, A, M, N, V, E = 16, 56, 40, 41, 8, 18
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
def arr(n, i): return z.arr('arr_obj3d_' + n, i)
def sh(n): z.shot('test/shots/e_%s.png' % n)
def census():
    c = {}
    for j in range(44):
        if arr('ocls', j) == 2:
            t = arr('otype', j); c[t] = c.get(t, 0) + 1
    return c
names = {1: 'grunt', 2: 'hulk', 3: 'scout', 11: 'turret', 12: 'sentry', 16: 'tank-bot', 17: 'orb'}
z.run_frames(150); z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)       # god mode
z.setvar('var_dbg', 7); z.run_frames(5)       # five cores gone: the whole swarm
seen = set(); s0 = var('score')
for i in range(30):
    z.held = {A, M, SPACE} if (i % 6) < 3 else {A, N}
    z.run_frames(40)
    c = census(); seen |= set(c)
    if i in (8, 16, 24): sh('swarm%d' % i)
    if i % 5 == 0: print('t=%4d' % z.frame, {names.get(k, k): v for k, v in c.items()}, 'score', var('score'), 'shield', var('shield'))
z.held = set()
print('robot types seen:', sorted(names.get(k, k) for k in seen), ' score gained', var('score') - s0)
# the E.C.M.
e0 = var('ecm'); z.held = {E}; z.run_frames(8); z.held = set(); z.run_frames(10); sh('ecm')
print('E.C.M.: %d -> %d' % (e0, var('ecm')))
# a survivor
z.setvar('var_dbg', 8); z.run_frames(20)
z.held = {V}; z.run_frames(50); z.held = set()
sh('survivor_near')
z.held = {SPACE}; z.run_frames(120); z.held = set(); z.run_frames(20)
print('pods', var('pods'), 'score', var('score'))
sh('survivor_after')
# an electrode, in a fresh game of its own
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
z.run_frames(150); z.held = {A}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)
z.setvar('var_dbg', 9); z.run_frames(30)
sh('electrode_near')
s0 = var('score'); z.held = {A}; z.run_frames(40); z.held = set(); z.run_frames(10)
print('electrode shot: score +%d' % (var('score') - s0))
sh('electrode_after')
