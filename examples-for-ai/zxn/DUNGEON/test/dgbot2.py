import sys
from collections import deque
sys.path.insert(0, '/home/claude/work/emu')
import nextemu
SP, UP, DN, LF, RT, M, U, H = 56, 16, 8, 41, 40, 58, 43, 52
z = nextemu.NextX('build/DUNGEON.NEX', 'build/DUNGEON.sym')
q = []; held = set()
def press(k, n=1):
    for _ in range(n): q.extend([k, k, None, None])
def text():
    z.pageall(); b = z.page(11)
    return '\n'.join(''.join(chr(b[(y * 40 + x) * 2]) if 32 <= b[(y * 40 + x) * 2] < 96 else ' ' for x in range(40)) for y in range(32))
def v(n): return z.var(n)
WAY = [(0, -1), (1, 0), (0, 1), (-1, 0)]
st = {'log': []}
def decide():
    t = text()
    if 'SPACE TO BEGIN' in t or 'SPACE' == t.strip()[-5:]: press(SP); return
    if 'FIGHT' in t and 'SPELL' in t:
        press(LF); press(LF); press(SP); return
    if 'WHICH ONE' in t: press(SP); return
    if 'STAIRS DOWN!' in t: press(SP); return
    if 'THE MAP.' in t: press(UP); return
    if 'R.I.P' in t or 'VICTORY' in t: press(SP); return
    # heal when someone's low
    hp = [z.arr('arr_hhp', h) for h in range(4)]; mx = [z.arr('arr_hmx', h) for h in range(4)]
    if any(0 < hp[h] < mx[h] // 3 for h in range(4)):
        if z.arr('arr_hmp', 2) >= 4 and hp[2] > 0: press(H); return
        if v('var_potions') > 0: press(U); return
    a = z.symtab['arr_mp']; mp = z.m.memory[a:a + 1024]
    px, py, pd = v('var_px'), v('var_py'), v('var_pd')
    # BFS to the stairs (doors passable), through cells
    goal = [i for i in range(1024) if mp[i] == 4]
    if not goal: goal = [None]
    prev = {(px, py): None}; dq = deque([(px, py)]); found = None
    while dq:
        c = dq.popleft()
        if goal[0] is not None and c[1] * 32 + c[0] == goal[0]: found = c; break
        for dx, dy in WAY:
            n = (c[0] + dx, c[1] + dy)
            if n in prev or not (0 <= n[0] < 32 and 0 <= n[1] < 32): continue
            if mp[n[1] * 32 + n[0]] in (1, 6): continue
            prev[n] = c; dq.append(n)
    if found is None:
        # the dragon's level: go to where the dragon is
        g = [(z.arr('arr_gx', j), z.arr('arr_gy', j)) for j in range(24) if z.arr('arr_gk', j) == 18]
        if g:
            gx, gy = g[0]
            best = None
            for c in prev:
                d = abs(c[0] - gx) + abs(c[1] - gy)
                if best is None or d < best[0]: best = (d, c)
            found = best[1]
            if found == (px, py):
                for d, (dx, dy) in enumerate(WAY):
                    if (px + dx, py + dy) == (gx, gy):
                        if d != pd: press(RT if (d - pd) % 4 == 1 else LF)
                        else: press(UP)
                        return
        else:
            press(LF); return
    path = []
    c = found
    while c and c != (px, py): path.append(c); c = prev[c]
    if not path: return
    n = path[-1]
    d = WAY.index((n[0] - px, n[1] - py))
    if d != pd:
        press(RT if (d - pd) % 4 == 1 else LF); return
    if mp[n[1] * 32 + n[0]] == 2: press(SP); return
    press(UP)
def onframe(z):
    held.clear()
    if q:
        k = q.pop(0)
        if k is not None: held.add(k)
        return
    if z.frame > 100 and z.frame % 6 == 0: decide()
def per(z):
    print(z.frame, 'level', v('var_lvl'), 'pos', v('var_px'), v('var_py'), 'hp', [z.arr('arr_hhp', h) for h in range(4)], 'lv', [z.arr('arr_hlv', h) for h in range(4)], 'gold', z.deek(z.symtab['var_gold']), 'pot', v('var_potions'), 'over', v('var_over'), 'won', v('var_won'), flush=True)
shot = {}
def onf2(z):
    onframe(z)
    if z.frame % 20 == 0:
        t = text()
        lv = v('var_lvl')
        for w, nm in (('var_won', 'WON'), ('var_over', 'OVER')):
            if v(w) and nm not in shot:
                shot[nm] = 1
                for dd in (2, 300, 500, 800): z.shots[z.frame + dd] = '%s_%s%d.png' % (sys.argv[3], nm, dd)
                print('EVENT', nm, z.frame, flush=True)
        if 'DRAGON' in t and lv == 10 and 'DRAGONF' not in shot:
            shot['DRAGONF'] = 1; z.shots[z.frame + 1] = '%s_dragon.png' % sys.argv[3]
        for w in ():
            if w in t and w not in shot:
                shot[w] = 1; z.shots[z.frame + 1] = '%s_%s.png' % (sys.argv[3], w.replace('.', ''))
                print('EVENT', w, z.frame, flush=True)
        if 'FIGHT' in t and 'SPELL' in t and lv not in shot:
            shot[lv] = 1; z.shots[z.frame + 1] = '%s_fight%d.png' % (sys.argv[3], lv)
z.onframe = onf2
z.keysheld = lambda f: held
for a in sys.argv[2].split(','):
    if a: z.shots[int(a)] = '%s_%s.png' % (sys.argv[3], a)
z.run_frames(int(sys.argv[1]), (1000, per))
