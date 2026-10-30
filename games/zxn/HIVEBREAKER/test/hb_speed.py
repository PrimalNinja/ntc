# HIVEBREAKER: how fast is it? pictures drawn (the BASIC var 'frames') against 50ths gone, outdoors and in
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
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
z.run_frames(150); z.held = {56}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)
def rate(tag, n=300, keys=()):
    f0 = var('frames'); z.held = set(keys); z0 = z.frame; z.run_frames(n); z.held = set()
    p = (var('frames') - f0) & 0x7FFF
    print('%-26s %3d pictures in %d frames: %.2f frames a picture' % (tag, p, z.frame - z0, (z.frame - z0) / max(1, p)))
rate('outdoors, still', 200)
rate('outdoors, throttle + turn', 300, (16, 40))
z.shot('test/shots/sp_out.png')
z.setvar('var_dbg', 2); z.run_frames(40)
rate('hive chamber', 300)
z.shot('test/shots/sp_in.png')
