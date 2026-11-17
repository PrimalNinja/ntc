# play.py - X-TYPE in the emulated Next: the title, the game started, the ship flown; pictures as it goes.
#   python3 test/play.py            writes pictures to screenshots/
# (c) 2026 Cyborg Unicorn Pty Ltd
import os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.join(HERE, '..')
sys.path.insert(0, HERE)
import nextemu
SHOT = os.path.join(ROOT, 'screenshots'); os.makedirs(SHOT, exist_ok=True)
e = nextemu.Emu(os.path.join(ROOT, 'build', 'XTYPE.NEX'), os.path.join(ROOT, 'build', 'XTYPE.sym'))
def V(name):
    return e.peekw('var_' + name)
def shot(n): e.picture(os.path.join(SHOT, n), 2, False); print('shot', n, 'frame', V('g_intframe'), 'scr', V('g_intscr'), 'ship', V('g_intpx'), V('g_intpy'), 'lives', V('g_intlives'), 'dead', V('g_intdead'))
t0 = time.time()
e.frame(60); e.press('space', 4, 4); e.frame(60); e.press('space', 4, 4); e.frame(120)
shot('01_title.png')
e.press('space', 4, 4); e.frame(80)
shot('02_stage_banner.png')
e.frame(120)
shot('03_flying.png')
e.held = {'p'}; e.frame(30); e.held = set(); e.frame(2)
e.held = {'space'}; e.frame(3); e.held = set()
e.frame(20)
shot('04_shooting.png')
print('time', time.time() - t0)
