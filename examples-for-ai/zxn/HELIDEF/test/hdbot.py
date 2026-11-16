import sys
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
SP, UP, DN, LF, RT, B = 56, 16, 8, 41, 40, 60
z = nextemu.NextX('build/HELIDEF.NEX', 'build/HELIDEF.sym')
held = set()
def v(n): return z.var(n)
def arr(n, i): return z.arr(n, i)
def dif(a, b): return ((b - a + 2048 + 1024) & 2047) - 1024
def onframe(z):
    held.clear()
    if z.frame < 60: return
    if z.frame % 40 == 0: held.add(SP)
    if v('var_alive') == 0: return
    hx = v('var_hx') // 8; hy = v('var_hy')
    best = None
    for n in range(20):
        if arr('arr_uk', n):
            d = dif(hx, arr('arr_ux', n))
            if best is None or abs(d) < abs(best[0]): best = (d, arr('arr_uy', n))
    if best:
        d, y = best
        want = d - (60 if d > 0 else -60)
        if want > 8: held.add(RT)
        elif want < -8: held.add(LF)
        elif d > 0 and z.frame % 30 == 0: held.add(RT)
        elif d < 0 and z.frame % 30 == 0: held.add(LF)
        if y > hy + 2: held.add(DN)
        if y < hy - 2: held.add(UP)
        if abs(y - hy) < 10 and abs(d) < 200 and z.frame % 2 == 0: held.add(SP)
def per(z):
    ppl = sum(1 for n in range(10) if z.arr('arr_ps', n))
    sc = z.deek(z.symtab['var_score']) | (z.deek(z.symtab['var_score'] + 2) << 16)
    print(z.frame, 'wave', v('var_wave'), 'lives', v('var_lives'), 'score', sc, 'people', ppl, 'ufos', sum(1 for n in range(20) if z.arr('arr_uk', n)), 'kinds', [z.arr('arr_uk', n) for n in range(20) if z.arr('arr_uk', n)], 'tocome', v('var_tocome'), flush=True)
z.onframe = onframe
z.keysheld = lambda f: held
for a in sys.argv[2].split(','):
    if a: z.shots[int(a)] = '%s_%s.png' % (sys.argv[3], a)
z.run_frames(int(sys.argv[1]), (500, per))
