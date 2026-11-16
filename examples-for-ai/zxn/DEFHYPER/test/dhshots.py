import sys
sys.path.insert(0, '/home/claude/work/emu'); sys.path.insert(0, '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad')
import nextemu, dhlib
OUT = '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/'
z = nextemu.NextX('build/DEFHYPER.NEX', 'build/DEFHYPER.sym'); dhlib.install(z)
o = z.onframe; v = z.var
def onscreen():
    cam = v('var_camx'); c = 0
    for n in range(32):
        if z.arr('arr_uk', n):
            x = ((z.arr('arr_ux', n) - cam + 3072) & 2047) - 1024
            if 16 < x < 240: c += 1
    return c
st = {'a': 0}
def of(z):
    o(z)
    f = z.frame
    if 250 < f < 900 and st['a'] < 3 and f % 20 == 0 and onscreen() >= 3 and v('var_alive'):
        z.shots[f + 1] = OUT + 'sh_act%d.png' % st['a']; st['a'] += 1
    if f == 900:
        # a lander carrying a humanoid up, in view
        n = [k for k in range(32) if z.arr('arr_uk', k) == 1]
        p = [k for k in range(10) if z.arr('arr_ps', k) == 1]
        if n and p:
            n, p = n[0], p[0]
            x = (v('var_hx') // 8 + 90) & 2047
            dhlib.seta('arr_ux', n, x); dhlib.seta('arr_uy', n, 110); dhlib.seta('arr_ug', n, p); dhlib.seta('arr_ps', p, 2)
    if f == 904: z.shots[f + 1] = OUT + 'sh_grab.png'
    if f == 1000:
        for k in range(3): dhlib.seta('arr_ps', k, 4); dhlib.seta('arr_pa', k, k)
        z.setvar('var_aboard', 3); z.setvar('var_hy', 120)
    if 1000 <= f < 1010: dhlib.held.clear(); dhlib.held.add(40)
    if f == 1008: z.shots[f + 1] = OUT + 'sh_carry.png'
    if f == 1100: dhlib.skipto(5)
    if f == 1550: z.shots[f] = OUT + 'sh_dogfight.png'
    if f == 1700:
        z.setvar('var_hx', 1440 * 8); z.setvar('var_hy', 100); z.setvar('var_face', 1); z.setvar('var_gatet', 200); z.setvar('var_camx', 1440 - 72); z.setvar('var_hvx', 0)
    if 1700 <= f < 1712: dhlib.held.clear()
    if f == 1704: z.shots[f] = OUT + 'sh_gate.png'
    if f == 1720:
        first = True
        for k in range(10):
            if first: dhlib.seta('arr_ps', k, 3); dhlib.seta('arr_py', k, 60); dhlib.seta('arr_pf', k, 60); dhlib.seta('arr_px', k, (v('var_hx') // 8 + 1024) & 2047); first = False
            else: dhlib.seta('arr_ps', k, 0)
    if f > 1720 and v('var_planetgone') and 'pg' not in st: st['pg'] = f; z.shots[f + 60] = OUT + 'sh_noplanet.png'
z.onframe = of
z.run_frames(1900)
