import sys
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
SP, UP, DN, LF, RT, B, I = 56, 16, 8, 41, 40, 60, 42
OUT = '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/'
held = set()
def v(n): return z.var(n)
def arr(n, i): return z.arr(n, i)
def seta(n, i, val):
    a = z.symtab[n] + i * 2; z.poke(a, val & 255); z.poke(a + 1, (val >> 8) & 255)
def dif(a, b): return ((b - a + 2048 + 1024) & 2047) - 1024
def score():
    return z.deek(z.symtab['var_score']) | (z.deek(z.symtab['var_score'] + 2) << 16)
def bot(z):
    held.clear()
    if z.frame < 60: return
    if z.frame % 40 == 0: held.add(SP)
    if v('var_alive') == 0: return
    hx = v('var_hx') // 8; hy = v('var_hy')
    # a humanoid falling: get under it
    for n in range(10):
        if arr('arr_ps', n) == 3:
            d = dif(hx, arr('arr_px', n))
            if d > 4: held.add(RT)
            elif d < -4: held.add(LF)
            if arr('arr_py', n) > hy + 6: held.add(DN)
            elif arr('arr_py', n) < hy: held.add(UP)
            return
    if v('var_aboard') > 0: held.add(DN); return
    best = None
    for n in range(32):
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
        if abs(d) < 24 and abs(y - hy) < 16: held.add(I)

def install(zz, lives=True):
    global z
    z = zz
    def onframe(z):
        bot(z)
        if lives and z.frame % 300 == 0: z.setvar('var_lives', 3)
    z.onframe = onframe
    z.keysheld = lambda f: held
def skipto(w):
    for n in range(32): seta('arr_uk', n, 0)
    for n in range(15): seta('arr_q', n, 0)
    z.setvar('var_wave', w - 1)
