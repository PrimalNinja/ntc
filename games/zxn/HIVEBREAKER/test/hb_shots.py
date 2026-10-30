# HIVEBREAKER: pictures for the README (screenshots/)
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
os.makedirs('screenshots', exist_ok=True)
FIRE, FASTER, SLOWER, LEFT, RIGHT, JUMP, FORM = 56, 16, 8, 41, 40, 17, 9      # keys: half row x 8 + bit
z = NX('build/HIVEBRK.NEX', 'build/HIVEBRK.sym')
def var(n): return z.var('var_' + n)
def sh(n): z.shot('screenshots/%s.png' % n)
z.run_frames(150); sh('01_title')
z.held = {FIRE}; z.run_frames(12); z.held = set(); z.run_frames(40)
z.setvar('var_dbg', 3); z.run_frames(5)
z.setvar('var_dbg', 7); z.run_frames(5)                          # the swarm of the late game
z.held = {SLOWER}; z.run_frames(60); z.held = set()
z.setvar('var_dbg', 12); z.run_frames(20); sh('02_the_robots_as_a_tank')          # one of each robot ahead
z.held = {FORM}; z.run_frames(6); z.held = set(); z.run_frames(50); sh('03_the_robots_as_a_walker')
z.held = {FORM}; z.run_frames(6); z.held = set(); z.run_frames(45)   # a tank again
z.setvar('var_dbg', 1); z.run_frames(30)                         # south of hive 0, facing its door
z.held = {SLOWER}; z.run_frames(60); z.held = {FIRE}; z.run_frames(200); z.held = set()
sh('04_tank_hive')
z.held = {FORM}; z.run_frames(6); z.held = set(); z.run_frames(60)
z.held = {FIRE}; z.run_frames(40); sh('05_walker_two_guns'); z.held = set()
z.setvar('var_dbg', 11); z.run_frames(40); z.held = {SLOWER}; z.run_frames(30); z.held = set(); sh('06_pink_pod')
z.held = {JUMP}; z.run_frames(6); z.held = set(); z.run_frames(34); sh('07_jump')
z.setvar('var_dbg', 2); z.run_frames(40); z.held = {SLOWER}; z.run_frames(60); z.held = set(); sh('08_chamber')
z.setvar('var_dbg', 4); z.run_frames(30); z.setvar('var_dbg', 4); z.run_frames(30)
z.held = {SLOWER}; z.run_frames(40); z.held = {FIRE, SLOWER}; z.run_frames(18); sh('09_core_chamber_firing'); z.held = set()
