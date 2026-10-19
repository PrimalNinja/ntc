import sys
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
SP, UP, DN, LF, RT, B, I = 56, 16, 8, 41, 40, 60, 42
OUT = '/tmp/claude-0/-home-claude/763e589f-1b39-5ff1-8745-d6aace327178/scratchpad/'
z = nextemu.NextX('build/DEFHYPER.NEX', 'build/DEFHYPER.sym')
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
log = []
def ev(s):
    print(z.frame, s, flush=True)
script = {}
def at(f):
    def deco(fn): script[f] = fn; return fn
    return deco
def skipto(w):
    # everything gone: the wave ends; the next is w
    for n in range(32): seta('arr_uk', n, 0)
    for n in range(15): seta('arr_q', n, 0)
    z.setvar('var_wave', w - 1)
@at(900)
def _(z):
    ev('gate test: hx %d' % (v('var_hx') // 8))
    z.setvar('var_hx', 1500 * 8); z.setvar('var_hy', 84); z.setvar('var_gatet', 0)
@at(903)
def _(z):
    ev('after gate: hx %d hy %d gatet %d' % (v('var_hx') // 8, v('var_hy'), v('var_gatet')))
    z.shots[z.frame + 1] = OUT + 'dt_gate.png'
@at(1200)
def _(z):
    # a humanoid falls from high up: catch it?
    for n in range(10):
        if arr('arr_ps', n) == 1:
            seta('arr_ps', n, 3); seta('arr_py', n, 70); seta('arr_pf', n, 70); seta('arr_pv', n, 0)
            seta('arr_px', n, (v('var_hx') // 8 + 30) & 2047)
            ev('dropped humanoid %d' % n); break
@at(1400)
def _(z): ev('aboard %d catches %d score %d' % (v('var_aboard'), v('var_catches'), score()))
@at(1700)
def _(z): skipto(5); ev('skip to 5 (dogfight)')
@at(2150)
def _(z): z.shots[z.frame] = OUT + 'dt_dogfight.png'
@at(2300)
def _(z): z.shots[z.frame] = OUT + 'dt_dogfight2.png'
@at(2600)
def _(z): skipto(10); ev('skip to 10 (showdown)')
@at(3100)
def _(z): z.shots[z.frame] = OUT + 'dt_showdown.png'
@at(3300)
def _(z): skipto(7); ev('skip to 7')
@at(3700)
def _(z):
    # the planet blows up: all but one gone, that one falling to its death
    first = True
    for n in range(10):
        if first: seta('arr_ps', n, 3); seta('arr_py', n, 60); seta('arr_pf', n, 60); seta('arr_px', n, (v('var_hx') // 8 + 1024) & 2047); first = False
        else: seta('arr_ps', n, 0)
    ev('planet test')
@at(3800)
def _(z):
    ev('planetgone %d' % v('var_planetgone')); z.shots[z.frame] = OUT + 'dt_noplanet.png'
@at(4000)
def _(z):
    # the warp: 4 aboard, wave 7 -> 10? (wave < 10): into the gate facing right
    skipto(3)
@at(4300)
def _(z):
    for n in range(4): seta('arr_ps', n, 4); seta('arr_pa', n, n)
    z.setvar('var_aboard', 4); z.setvar('var_face', 1)
    z.setvar('var_hx', 1490 * 8); z.setvar('var_hy', 84); z.setvar('var_gatet', 0)
    ev('warp test wave %d' % v('var_wave'))
@at(4320)
def _(z): z.shots[z.frame] = OUT + 'dt_warp.png'
@at(4700)
def _(z): ev('after warp: wave %d score %d' % (v('var_wave'), score()))
def onframe(z):
    bot(z)
    if z.frame in script: script[z.frame](z)
    if z.frame % 300 == 0 and v('var_lives') < 3: z.setvar('var_lives', 3)
pf = {'f': 0}
def per(z):
    fr = (v('var_frames') - pf['f']) & 0x7fff; pf['f'] = v('var_frames')
    print('  fps*', fr * 50 // 250, end=' ')
    ppl = sum(1 for n in range(10) if z.arr('arr_ps', n))
    print(z.frame, 'wave', v('var_wave'), 'lives', v('var_lives'), 'score', score(), 'people', ppl, 'kinds', [z.arr('arr_uk', n) for n in range(32) if z.arr('arr_uk', n)], 'q', [z.arr('arr_q', n) for n in range(15)], flush=True)
z.onframe = onframe
z.keysheld = lambda f: held
z.run_frames(int(sys.argv[1]), (250, per))
