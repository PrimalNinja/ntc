# HIVEBREAKER: the robots, one of each in a row (grunt, tank-bot, orb, scout, hulk), seen as a tank and as a walker
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
FIRE, SLOWER, FORM = 56, 8, 9
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
z.run_frames(150); z.held = {FIRE}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)
z.held = {SLOWER}; z.run_frames(60); z.held = set()
z.setvar('var_dbg', 12); z.run_frames(20)
z.shot('test/shots/robots_tank.png')
z.held = {FORM}; z.run_frames(6); z.held = set(); z.run_frames(50)
z.shot('test/shots/robots_walker.png')
print('robots shown: tank form and walker form')
