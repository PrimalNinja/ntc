import sys
sys.path.insert(0, '/home/claude/work/emu'); sys.path.insert(0, '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad')
import nextemu, dhlib
z = nextemu.NextX('build/DEFHYPER.NEX', 'build/DEFHYPER.sym'); dhlib.install(z)
o = z.onframe
v = z.var
def onscreen():
    cam = v('var_camx'); c = 0
    for n in range(32):
        if z.arr('arr_uk', n):
            x = ((z.arr('arr_ux', n) - cam + 3072) & 2047) - 1024
            if -8 < x < 264: c += 1
    return c
st = {}
def of(z):
    o(z)
    f = z.frame
    if f >= 700 and 'sb' not in st and onscreen() >= 2:
        st['sb'] = f; print(f, 'smart bomb: on screen', onscreen(), 'smart', v('var_smart'))
    if 'sb' in st and st['sb'] <= f < st['sb'] + 3: dhlib.held.clear(); dhlib.held.add(60)
    if 'sb' in st and f == st['sb'] + 4: print(f, 'after: on screen', onscreen(), 'smart', v('var_smart'))
    if f == 1100: st['hx'] = v('var_hx') // 8; print(f, 'hyperspace from', st['hx'])
    if 1100 <= f < 1103: dhlib.held.clear(); dhlib.held.add(52)
    if f == 1140: print(f, 'now at', v('var_hx') // 8, 'alive', v('var_alive'))
    if f == 1300:
        # an enemy right on top of you, cloaked
        n = [k for k in range(32) if z.arr('arr_uk', k)]
        if n:
            n = n[0]; dhlib.seta('arr_ux', n, (v('var_hx') // 8 + 6) & 2047); dhlib.seta('arr_uy', n, v('var_hy')); z.setvar('var_safe', 0)
            st['cl'] = n; print(f, 'cloak test enemy', n, 'kind', z.arr('arr_uk', n), 'lives', v('var_lives'), 'cloak', v('var_cloak'))
    if 1298 <= f < 1306: dhlib.held.clear(); dhlib.held.add(42)
    if f == 1306 and 'cl' in st: print(f, 'enemy kind now', z.arr('arr_uk', st['cl']), 'alive', v('var_alive'), 'lives', v('var_lives'), 'cloakon', v('var_cloakon'), 'cloak', v('var_cloak'))
z.onframe = of
z.shots[1302] = '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/dk_cloak.png'
z.run_frames(1310)
