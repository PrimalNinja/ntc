# stages.py - X-TYPE's stages: the terrain of every 8 pixel column (ceiling and floor heights, in cells) and the
# event lists (what appears at which column), as tables in Stages.cls (read by B(k) bytes and W(k) words).
#   python3 tools/stages.py
# (c) 2026 Cyborg Unicorn Pty Ltd
import os, math, random
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
T_DRONE, T_DART, T_SWOOP, T_CRAWL, T_TURRET, T_SNAKE, T_CARRIER, T_MINE, T_ORBIT, T_MID, T_BOSS = range(1, 12)

def terrain(prof, total):
    ce, fl = [], []
    c, f = prof[0][1], prof[0][2]
    for ln, tc, tf in prof:
        for i in range(ln):
            if i % 2 == 0:
                if c < tc: c += 1
                elif c > tc: c -= 1
                if f < tf: f += 1
                elif f > tf: f -= 1
            ce.append(c); fl.append(f)
    while len(ce) < total: ce.append(ce[-1]); fl.append(fl[-1])
    return ce[:total], fl[:total]

class Stage:
    def __init__(s, n, total, prof, seed):
        s.n = n; s.total = total; s.rng = random.Random(seed)
        s.ce, s.fl = terrain(prof, total); s.ev = []; s.cps = [0]
    def clear(s, col, lo=0):
        c = min(s.ce[col:col + 12] or [2]); f = min(s.fl[col:col + 12] or [2])
        return c, f
    def free_y(s, col):
        c = max(s.ce[col:col + 6] or [2]); f = max(s.fl[col:col + 6] or [2])
        return c * 8 + 10, 256 - f * 8 - 26
    def add(s, col, t, y, a=0): s.ev.append((col, t, y, a))
    def drones(s, col, n, y, gap=3):
        lo, hi = s.free_y(col)
        y = max(lo + 36, min(hi - 36, y))
        for i in range(n): s.add(col + i * gap, T_DRONE, y, 0)
    def darts(s, col, n, y, gap=5):
        lo, hi = s.free_y(col)
        for i in range(n): s.add(col + i * gap, T_DART, max(lo, min(hi, y + (i % 2) * 18)), 0)
    def swoops(s, col, n, top):
        for i in range(n): s.add(col + i * 6, T_SWOOP, 0, 0 if top else 1)
    def floor_things(s, col, t, a=0):
        s.add(col, t, 0, a)
    def tsorted(s):
        return sorted(s.ev, key=lambda e: e[0])

def stage1():
    prof = [(60, 2, 2), (40, 4, 3), (60, 3, 6), (50, 6, 3), (40, 3, 3), (50, 2, 7), (60, 7, 2), (40, 4, 4), (50, 6, 6), (40, 3, 3),
            (60, 3, 8), (50, 8, 3), (50, 4, 4), (60, 3, 3), (60, 5, 5), (50, 3, 3), (50, 2, 2), (400, 3, 3)]
    s = Stage(1, 860, prof, 11)
    s.cps = [0, 170, 340, 530]
    s.add(70, T_CARRIER, 100, 2)                              # the orb
    s.drones(40, 5, 100); s.drones(100, 5, 150); s.add(125, T_CARRIER, 150, 0)
    s.darts(150, 4, 100); s.floor_things(162, T_CRAWL); s.floor_things(180, T_TURRET); s.floor_things(188, T_TURRET, 1)
    s.drones(210, 6, 80); s.floor_things(226, T_CRAWL); s.floor_things(236, T_CRAWL)
    s.swoops(250, 4, True); s.add(262, T_CARRIER, 120, 1); s.floor_things(270, T_TURRET); s.floor_things(276, T_TURRET, 1)
    s.drones(300, 6, 170); s.add(318, T_MINE, 120, 0); s.add(326, T_MINE, 150, 0)
    s.darts(340, 5, 160); s.floor_things(352, T_TURRET); s.floor_things(360, T_TURRET, 1); s.floor_things(368, T_CRAWL)
    s.swoops(380, 4, False); s.add(392, T_CARRIER, 130, 0); s.drones(402, 5, 90)
    s.floor_things(420, T_TURRET); s.floor_things(428, T_TURRET, 1); s.add(440, T_SNAKE, 120, 0)
    s.add(470, T_MID, 128, 0)
    s.drones(540, 6, 100); s.drones(556, 6, 170); s.floor_things(570, T_CRAWL); s.add(580, T_ORBIT, 90, 0); s.add(584, T_ORBIT, 170, 0)
    s.darts(600, 5, 120); s.add(612, T_CARRIER, 120, 1); s.floor_things(620, T_TURRET); s.floor_things(626, T_TURRET, 1)
    s.swoops(640, 4, True); s.swoops(650, 4, False); s.add(670, T_SNAKE, 90, 0); s.add(690, T_SNAKE, 170, 0)
    s.add(730, T_BOSS, 120, 1)
    return s

def stage2():
    prof = [(50, 3, 3), (40, 6, 4), (50, 4, 8), (50, 8, 4), (40, 6, 6), (60, 3, 9), (60, 9, 3), (40, 5, 5), (50, 7, 7), (50, 4, 4),
            (60, 6, 9), (60, 9, 6), (50, 5, 5), (60, 7, 7), (50, 3, 3), (50, 4, 4), (400, 3, 3)]
    s = Stage(2, 860, prof, 22)
    s.cps = [0, 160, 330, 520]
    s.add(60, T_CARRIER, 120, 0); s.drones(30, 5, 120); s.darts(90, 5, 100)
    s.floor_things(110, T_TURRET); s.floor_things(118, T_TURRET, 1); s.floor_things(130, T_CRAWL)
    s.swoops(150, 4, True); s.add(162, T_CARRIER, 130, 1); s.add(180, T_SNAKE, 110, 0); s.floor_things(196, T_TURRET, 1)
    s.floor_things(206, T_TURRET); s.drones(220, 6, 130); s.floor_things(236, T_CRAWL); s.floor_things(244, T_CRAWL)
    s.add(260, T_MINE, 110, 0); s.add(266, T_MINE, 140, 0); s.add(272, T_MINE, 170, 0)
    s.darts(290, 5, 130); s.add(300, T_CARRIER, 140, 0); s.floor_things(310, T_TURRET); s.floor_things(316, T_TURRET, 1)
    s.swoops(335, 4, False); s.add(350, T_ORBIT, 90, 0); s.add(354, T_ORBIT, 170, 0); s.add(358, T_ORBIT, 130, 0)
    s.floor_things(370, T_CRAWL); s.floor_things(380, T_TURRET); s.floor_things(386, T_TURRET, 1); s.drones(400, 6, 150)
    s.add(420, T_SNAKE, 100, 0); s.add(436, T_SNAKE, 170, 0)
    s.add(450, T_MID, 128, 0)
    s.drones(530, 6, 120); s.darts(550, 5, 140); s.add(562, T_CARRIER, 130, 1); s.floor_things(574, T_TURRET); s.floor_things(580, T_TURRET, 1)
    s.swoops(600, 4, True); s.swoops(612, 4, False); s.floor_things(630, T_CRAWL); s.floor_things(638, T_CRAWL)
    s.add(650, T_MINE, 120, 0); s.add(656, T_MINE, 160, 0); s.add(670, T_SNAKE, 100, 0); s.add(690, T_SNAKE, 170, 0)
    s.drones(700, 6, 130)
    s.add(730, T_BOSS, 120, 2)
    return s

ST = [stage1(), stage2()]
bt = []; words = []; consts = []
sine = [int(round(math.sin(i * math.pi * 2 / 64) * 40)) for i in range(64)]
dive = [int(round(math.sin(i * math.pi / 63) * 96)) for i in range(64)]
consts.append(('SINE', len(words))); words += sine
consts.append(('DIVE', len(words))); words += dive
for s in ST:
    consts.append(('TERR%d' % s.n, len(bt))); bt += s.ce; bt += s.fl
    consts.append(('LEN%d' % s.n, s.total))
    consts.append(('EV%d' % s.n, len(words)))
    for e in s.tsorted(): words += list(e)
    words += [30000, 0, 0, 0]
    consts.append(('CP%d' % s.n, len(words)))
    words += s.cps + [30000]
def db(vals, per=16, op='db', f=lambda v: '%d' % v):
    return ['            %s %s' % (op, ','.join(f(v) for v in vals[i:i + per])) for i in range(0, len(vals), per)]
L = ["' Stages - X-TYPE's stages (made by tools/stages.py: don't edit). B(k): a byte of the terrain table (each stage: the",
     "' ceiling heights of its columns, then the floor heights, in 8 pixel cells), W(k): a word of the event table (the sine,",
     "' the dive curve, each stage's events as col, type, y, arg ending with col 30000, and its checkpoint columns).",
     "' (c) 2026 Cyborg Unicorn Pty Ltd", "Option Explicit", ""]
for n, v in consts: L.append('Public Const %s = %d' % (n, v))
L += ["", "Public Function B(k As Integer) As Integer", "#asm", "            pop hl", "            ld e, (hl)", "            inc hl", "            ld d, (hl)",
      "            ld hl, stg_b", "            add hl, de", "            ld e, (hl)", "            pop hl", "            ld (hl), e", "            inc hl", "            ld (hl), 0",
      "            jp stg_b_end", "stg_b:"] + db(bt) + ["stg_b_end:", "#endasm", "End Function", "",
      "Public Function W(k As Integer) As Integer", "#asm", "            pop hl", "            ld e, (hl)", "            inc hl", "            ld d, (hl)",
      "            ex de, hl", "            add hl, hl", "            ld de, stg_w", "            add hl, de", "            ld e, (hl)", "            inc hl", "            ld d, (hl)",
      "            pop hl", "            ld (hl), e", "            inc hl", "            ld (hl), d", "            jp stg_w_end", "stg_w:"] + \
     db([v & 0xFFFF for v in words], 8, 'dw') + ["stg_w_end:", "#endasm", "End Function"]
open(os.path.join(ROOT, 'Stages.cls'), 'w').write('\n'.join(L) + '\n')
print('stages: %d terrain bytes, %d words' % (len(bt), len(words)), [(n, v) for n, v in consts if n.startswith(('TERR', 'EV', 'CP'))])
