# MECHRA - the sprites and the panel's tiles: writes ../gfx/* (the backgrounds: bgart.py)
# (run: python3 tools/art_mechra.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, math, random
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from artkit import *
from cvkit import Cv

HERE = os.path.dirname(os.path.abspath(__file__))
D = HERE                              # (in DEFENDER HELLGATE: its sheet stays here, for merge_mechra.py)
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# ---------------------------------------------------------------- tiles: the panel
# 0 black, 1 white, 2 light grey, 3 grey, 4 the panel (deep blue), 5 its line (cyan), 6 red,
# 7 orange, 8 yellow, 9 cyan, 10 blue, 11 pink, 12 green, 13 dark red, 14 purple
TP = [c(0,0,0), c(7,7,3), c(5,5,2), c(3,3,1), c(0,0,1), c(1,4,3), c(7,1,0), c(7,4,0),
      c(7,7,0), c(2,7,3), c(1,2,3), c(7,3,2), c(2,6,0), c(3,0,0), c(3,0,2), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=0, paper=4)
K = {'k': 0, 'w': 1, 'l': 2, 'g': 3, 'N': 4, 'n': 5, 'r': 6, 'o': 7, 'y': 8, 'c': 9, 'b': 10, 'p': 11, 'e': 12, 'R': 13, 'v': 14}
T.put(1, 0, ['NNNNNNNN'] * 8, K)
T.put(2, 0, ['nnnnnnnn'] + ['NNNNNNNN'] * 7, K)
T.put(3, 0, ['kkkkkkkk'] * 8, K)
T.put(4, 0, ['NNNNNNNn'] * 8, K)
T.put(5, 0, ['nNNNNNNN'] * 8, K)
T.put(6, 0, ['NNNccNNN', 'NNkwwkNN', 'NbwllwbN', 'bwlbblwb', 'NklbblkN', 'NNkllkNN', 'NNkookNN', 'NNNyyNNN'], K)  # a mech left
T.put(7, 0, ['NNcccNNN', 'NcwwwcNN', 'cwNNNwcN', 'cwNNNwcN', 'cwNNNwcN', 'NcwwwcNN', 'NNcccNNN', 'NNNNNNNN'], K)  # a guard left
T.put(8, 0, ['NNNNNNNN'] * 8, K)
for k in range(9):          # 16-24: a gauge, 0-8 filled
    rows = []
    for y in range(8):
        if y in (0, 1, 6, 7): rows.append('NNNNNNNN')
        else: rows.append(''.join(('y' if y < 4 else 'o') if x < k else 'k' for x in range(8)))
    T.put((16 + k) % 16, (16 + k) // 16, rows, K)
for k in range(5):          # 9-13: the power gauge (cyan): 0, 2, 4, 6, 8 filled
    rows = []
    for y in range(8):
        if y in (0, 1, 6, 7): rows.append('NNNNNNNN')
        else: rows.append(''.join(('c' if y < 4 else 'b') if x < k * 2 else 'k' for x in range(8)))
    T.put(9 + k, 0, rows, K)
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprite palettes
# 0 black, 1 white, 2 light steel, 3 steel, 4 dark steel, 5 cyan, 6 blue, 7 dark blue, 8 yellow,
# 9 orange, 10 red, 11 dark red, 12 pink, 13 purple, 14 green
SP0 = [c(0,0,0), c(7,7,3), c(5,5,3), c(3,3,2), c(1,1,1), c(2,7,3), c(1,3,3), c(0,1,2),
       c(7,7,0), c(7,4,0), c(7,1,0), c(4,0,0), c(7,3,3), c(3,0,2), c(2,6,0), MAGENTA]
FLASH = [c(5,5,2)] + [c(7,7,3)] * 14 + [MAGENTA]
PINK = [c(3,0,1), c(7,7,3), c(7,5,3), c(7,2,2)] + SP0[4:]
BLUE = [c(0,0,2), c(7,7,3), c(4,6,3), c(1,3,3)] + SP0[4:]
GOLD = [c(3,1,0), c(7,7,3), c(7,7,1), c(7,4,0)] + SP0[4:]
# bosses: 0 outline, 1 highlight, 2-4 armour light-dark, 5-7 second metal, 8-9 glow, 10-11 visor,
# 12-14 detail
def bosspal(h, m, g, cn, d):
    return [c(0,0,0), c(7,7,3), h[0], h[1], h[2], m[0], m[1], m[2], g[0], g[1], cn[0], cn[1], d[0], d[1], d[2], MAGENTA]
B1 = bosspal([c(6,1,0), c(4,0,0), c(2,0,0)], [c(5,5,2), c(3,3,2), c(1,1,1)], [c(7,7,0), c(7,3,0)], [c(2,7,3), c(0,3,2)], [c(7,6,1), c(5,3,0), c(2,1,0)])
B2 = bosspal([c(6,5,1), c(4,3,0), c(2,1,0)], [c(4,4,2), c(2,2,1), c(1,1,0)], [c(7,2,0), c(4,0,0)], [c(7,7,1), c(5,4,0)], [c(3,6,1), c(1,4,0), c(0,2,0)])
B3 = bosspal([c(5,5,3), c(3,3,2), c(1,1,1)], [c(2,4,3), c(1,2,3), c(0,1,2)], [c(2,7,3), c(0,4,3)], [c(7,2,3), c(4,0,2)], [c(7,7,1), c(6,4,0), c(3,2,0)])
B4 = bosspal([c(3,1,3), c(2,0,2), c(1,0,1)], [c(6,6,3), c(4,4,2), c(2,2,1)], [c(7,3,3), c(5,0,2)], [c(3,7,3), c(1,4,3)], [c(7,7,0), c(5,4,0), c(2,2,0)])
B5 = bosspal([c(7,7,3), c(5,5,2), c(3,3,2)], [c(7,6,0), c(5,4,0), c(3,2,0)], [c(7,3,0), c(7,0,0)], [c(2,7,3), c(0,3,3)], [c(2,2,3), c(1,1,2), c(0,0,1)])
ALT = SP0[:]                       # the enemies' later colours: green and purple
ALT[10] = c(2,6,0); ALT[11] = c(0,3,0); ALT[3] = c(3,2,3); ALT[4] = c(1,0,1); ALT[2] = c(5,4,3)
palette_png(D + '/spr_pal.png', [SP0, FLASH, PINK, BLUE, GOLD, B1, B2, B3, B4, B5, ALT])

S = Sheet(16, 6, SP0)
names = []

def ell(v, cx, cy, rx, ry, i):
    for y in range(v.h):
        for x in range(v.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1: v.set(x, y, i)

def light(v, groups):
    # light from the top left: lit edges a shade lighter, the far edges darker
    q = [r[:] for r in v.p]
    for y in range(v.h):
        for x in range(v.w):
            p = v.p[y][x]
            if p not in groups: continue
            lit, dark = groups[p]
            if v.get(x - 1, y) != p or v.get(x, y - 1) != p: q[y][x] = lit
            elif v.get(x + 1, y) != p or v.get(x, y + 1) != p: q[y][x] = dark
    v.p = q

def cells(v, col, row, w, h):
    for j in range(h):
        for i in range(w):
            cv = Cv(16, 16)
            for y in range(16):
                for x in range(16): cv.p[y][x] = v.p[j * 16 + y][i * 16 + x]
            cv.into(S, col + i, row + j)

# ---- the player's mech: 32 x 32, flying up the screen. 0-1 level (the jets flicker), 2 banked
# right (the game mirrors it for left)
def mech(f):
    v = Cv(32, 32)
    bank = 1 if f == 2 else 0
    sh = 1.5 * bank
    # the wing binders: angled blue plates off the back
    v.poly([(13, 13), (3 + sh, 22), (2 + sh, 27), (7 + sh, 25), (14, 19)], 6)
    v.poly([(19, 13), (29 - sh * 2, 22), (30 - sh * 2, 27), (25 - sh * 2, 25), (18, 19)], 6)
    v.poly([(5 + sh, 23), (3 + sh, 26), (7 + sh, 25)], 5)
    v.poly([(27 - sh * 2, 23), (29 - sh * 2, 26), (25 - sh * 2, 25)], 5)
    # the legs and the foot jets
    v.rect(12, 21, 14, 27, 3); v.rect(18, 21, 20, 27, 3)
    v.rect(11, 26, 15, 28, 4); v.rect(17, 26, 21, 28, 4)
    flame = (8, 9) if f != 1 else (9, 10)
    v.rect(12, 29, 14, 30, flame[0]); v.rect(18, 29, 20, 30, flame[0])
    v.set(13, 31, flame[1]); v.set(19, 31, flame[1])
    if f == 1: v.rect(12, 31, 14, 31, flame[1]); v.rect(18, 31, 20, 31, flame[1])
    # the body: white armour, a blue chest, a glowing core
    v.poly([(11, 11), (21, 11), (20, 21), (12, 21)], 2)
    v.rect(13, 13, 19, 18, 6)
    v.rect(15, 14, 17, 16, 5); v.set(16, 15, 1)
    v.rect(13, 19, 19, 21, 4)
    # the shoulders
    ell(v, 9 + bank, 12, 3.6, 3.2, 2); ell(v, 23 - bank, 12, 3.6 - bank * 0.6, 3.2, 2)
    v.rect(7 + bank, 13, 11 + bank, 14, 6); v.rect(21 - bank, 13, 25 - bank, 14, 6)
    # the arms; the rifle up the right side, the shield on the left
    v.rect(7 + bank, 15, 9 + bank, 20, 3)
    v.poly([(4 + bank, 15), (9 + bank, 15), (9 + bank, 21), (6 + bank, 23), (4 + bank, 21)], 6)
    v.rect(5 + bank, 16, 5 + bank, 20, 5)
    v.rect(23 - bank, 15, 25 - bank, 20, 3)
    v.rect(24 - bank, 1, 25 - bank, 19, 4); v.rect(23 - bank, 9, 26 - bank, 12, 3)
    v.rect(24 - bank, 0, 25 - bank, 1, 5)
    # the head: a V fin, a cyan eye strip
    v.rect(14, 6, 18, 10, 2)
    v.rect(14, 8, 18, 8, 5)
    v.poly([(12, 3), (16, 7), (20, 3), (16, 5)], 8)
    v.set(16, 5, 10)
    light(v, {2: (1, 3), 3: (2, 4), 6: (5, 7)})
    v.outline(0)
    return v
for f in range(3):
    cells(mech(f), f * 2, 0, 2, 2)
names.append('sprite PLAYER   0 0 3 2 2 # your mech (32 x 32): level (2: the jets flicker), banked right')

# ---- your shot, the beam
v = Cv(16, 16)
for y in range(1, 15):
    v.set(7, y, 1); v.set(8, y, 5 if y > 3 else 1)
    if y > 4: v.set(6, y, 6); v.set(9, y, 6)
v.into(S, 6, 0)
names.append('sprite SHOT     6 0       # your shot')
v = Cv(16, 16)
for y in range(16):
    for x in range(2, 14):
        d = abs(x - 7.5)
        ch = 1 if d < 1.5 else 5 if d < 3 else 6 if d < 4.5 else (7 if (y // 2 + x) % 3 == 0 else None)
        v.set(x, y, ch)
v.into(S, 7, 0)
v = Cv(16, 16)
for y in range(16):
    for x in range(16):
        d = math.hypot(x - 7.5, y - 9.5); a = math.atan2(y - 9.5, x - 7.5)
        if d < 2.5: v.set(x, y, 1)
        elif d < 4.5: v.set(x, y, 5)
        elif d < 7.5 and (int(a * 8 / math.pi + 16) % 2 == 0): v.set(x, y, 6 if d < 6 else 12)
v.into(S, 8, 0)
names.append('sprite LASER    7 0 2     # the lock beam (drawn twice as tall), where it hits')

# ---- bullets (drawn in 0-3: a palette row colours them)
def ball(r0, r1, r2, r3):
    v = Cv(16, 16)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5)
            if d < r0: v.set(x, y, 1)
            elif d < r1: v.set(x, y, 2)
            elif d < r2: v.set(x, y, 3)
            elif d < r3: v.set(x, y, 0)
    return v
ball(1.0, 1.9, 2.9, 3.7).into(S, 9, 0)
ball(1.6, 3.0, 4.3, 5.2).into(S, 10, 0)
v = Cv(16, 16)                     # a needle (diamond)
for y in range(16):
    for x in range(16):
        dx, dy = abs(x - 7.5), abs(y - 7.5)
        m = dx * 2.2 + dy
        if m < 2.5: v.set(x, y, 1)
        elif m < 4.5: v.set(x, y, 2)
        elif m < 6: v.set(x, y, 3)
v.outline(0)
v.into(S, 11, 0)
names.append('sprite BULLET   9 0 3     # their bullets: small, big, needle')

# ---- enemy mechs (heading down the screen)
def drone(f):
    v = Cv(16, 16)
    ell(v, 8, 7, 4.5, 4, 3)
    v.rect(2, 6, 4, 11, 4); v.rect(11, 6, 13, 11, 4)        # the arms (guns)
    v.rect(3, 11, 3, 13, 2); v.rect(12, 11, 12, 13, 2)
    v.circle(8, 9, 1.6, 10); v.set(8, 9, 8)                 # the eye
    v.rect(6, 2, 9, 3, 2)
    v.rect(6, 0, 9, 1, 9 if f else 8)                       # its jet (behind it)
    light(v, {3: (2, 4)})
    v.outline(0)
    return v
drone(0).into(S, 12, 0); drone(1).into(S, 13, 0)
names.append('sprite POP      12 0 2    # a drone: two frames')
v = Cv(16, 16)                     # a jet-mech, diving
v.poly([(8, 15), (14, 4), (15, 0), (10, 2), (8, 5), (6, 2), (1, 0), (2, 4)], 10)
v.rect(7, 4, 8, 12, 3)
v.rect(7, 10, 8, 12, 5)
v.rect(3, 2, 4, 3, 9); v.rect(11, 2, 12, 3, 9)
light(v, {10: (12, 11), 3: (2, 4)})
v.outline(0)
v.into(S, 14, 0)
names.append('sprite DART     14 0      # a jet-mech, diving')
def walker(f):
    v = Cv(16, 16)
    o = 1 if f else 0
    for (x, y, dx) in ((3, 3 + o, -1), (12, 3 + 1 - o, 1), (3, 12 - o, -1), (12, 12 - 1 + o, 1)):
        v.rect(x - 1, y - 1, x + 1, y + 1, 4); v.set(x + dx * 2, y, 3)
    v.rect(4, 4, 11, 11, 3)
    v.circle(8, 8, 2.8, 2); v.rect(7, 9, 8, 15, 4); v.set(7, 7, 1)
    v.rect(5, 4, 5, 5, 10); v.rect(10, 4, 10, 5, 10)
    light(v, {3: (2, 4)})
    v.outline(0)
    return v
walker(0).into(S, 15, 0); walker(1).into(S, 0, 2)
names.append('sprite TANK     15 0      # a walker (its second frame: TANK2)')
names.append('sprite TANK2    0 2')
v = Cv(16, 16)                     # a gun emplacement: twin barrels
v.circle(8, 8, 7, 4); v.circle(8, 8, 5.5, 3); v.circle(8, 8, 3.5, 2)
v.rect(5, 8, 6, 15, 4); v.rect(9, 8, 10, 15, 4)
v.circle(8, 8, 1.5, 10); v.set(8, 8, 8)
for a in range(8):
    v.set(8 + math.cos(a * math.pi / 4) * 6.2, 8 + math.sin(a * math.pi / 4) * 6.2, 9)
v.outline(0)
v.into(S, 1, 2)
names.append('sprite TURRET   1 2       # a gun on the ground')
v = Cv(16, 16)                     # a cargo mech (twice the size): it carries a big P
v.rect(3, 2, 12, 12, 3)
v.rect(1, 4, 2, 10, 4); v.rect(13, 4, 14, 10, 4)
v.rect(5, 4, 10, 10, 7); v.rect(6, 5, 9, 9, 8); v.rect(7, 6, 7, 8, 9); v.set(8, 6, 9)
v.rect(5, 13, 6, 15, 4); v.rect(9, 13, 10, 15, 4)
v.rect(6, 0, 9, 1, 9)
light(v, {3: (2, 4)})
v.outline(0)
v.into(S, 2, 2)
names.append('sprite CARRIER  2 2       # a cargo mech: drops big P (twice the size)')
v = Cv(16, 16)                     # a heavy mech (twice the size)
v.poly([(8, 15), (13, 12), (15, 6), (14, 2), (10, 1), (8, 3), (6, 1), (2, 2), (1, 6), (3, 12)], 11)
v.rect(6, 4, 9, 12, 3)
v.circle(3.5, 5, 2, 4); v.circle(12.5, 5, 2, 4)
v.rect(3, 6, 4, 11, 4); v.rect(12, 6, 13, 11, 4)
v.rect(7, 9, 8, 11, 5); v.set(7, 9, 1)
v.rect(7, 13, 8, 15, 9)
light(v, {11: (10, 4), 3: (2, 4)})
v.outline(0)
v.into(S, 3, 2)
names.append('sprite GUNSHIP  3 2       # a heavy mech (twice the size)')

# ---- the pickups: a small P (spinning: 4 frames), a big P (2), a gem (2)
GL = {'P': ['1111.', '1...1', '1111.', '1....', '1....']}
def pcoin(w, big=False, f=0):
    v = Cv(16, 16)
    r = 6.5 if big else 5.5
    rim, face, hi = (9, 8, 1) if big else (6, 5, 1)
    ell(v, 7.5, 7.5, max(1.2, r * w), r, rim)
    ell(v, 7.5, 7.5, max(0.6, (r - 1.4) * w), r - 1.4, face)
    if w > 0.7:
        for y, row in enumerate(GL['P']):
            for x, ch in enumerate(row):
                if ch == '1': v.set(5 + x, 5 + y, 7 if not big else 11)
    v.set(5, 3, hi); v.set(4, 4, hi)
    if big and f:
        for a in range(4):
            an = a * math.pi / 2 + math.pi / 4
            v.set(7.5 + math.cos(an) * 7.5, 7.5 + math.sin(an) * 7.5, 1)
    v.outline(0)
    return v
for f, w in enumerate((1.0, 0.6, 0.15, 0.6)): pcoin(w).into(S, 4 + f, 2)
names.append('sprite ITEM     4 2 4     # a P: spinning')
pcoin(1.0, True, 0).into(S, 8, 2); pcoin(1.0, True, 1).into(S, 9, 2)
names.append('sprite BIGP     8 2 2     # a big P: glinting')
for f in range(2):
    v = Cv(16, 16)
    v.poly([(7.5, 2), (12, 7), (7.5, 14), (3, 7)], 14 if f == 0 else 12)
    v.poly([(7.5, 2), (12, 7), (7.5, 7)], 1)
    v.poly([(3, 7), (7.5, 14), (7.5, 7)], 4 if f == 0 else 13)
    if f: v.set(11, 2, 1); v.set(10, 3, 1); v.set(12, 3, 1); v.set(11, 4, 1)
    v.outline(0)
    v.into(S, 10 + f, 2)
names.append('sprite GEM      10 2 2    # a gem (score)')
v = Cv(16, 16)                     # the guard: a ring (twice the size round the mech)
for y in range(16):
    for x in range(16):
        d = math.hypot(x - 7.5, y - 7.5)
        a = math.atan2(y - 7.5, x - 7.5)
        if 6.2 < d < 7.6: v.set(x, y, 5 if int((a + 4) * 3) % 2 else 1)
        elif 5.4 < d < 6.2 and int((a + 4) * 3) % 3 == 0: v.set(x, y, 6)
v.into(S, 12, 2)
names.append('sprite GUARD    12 2      # the guard (twice the size, round the mech)')
v = Cv(16, 16)
for k in range(8):
    a = k * math.pi / 4
    for t in range(1, 5): v.set(7.5 + math.cos(a) * t, 7.5 + math.sin(a) * t, 1 if t < 3 else 5)
v.into(S, 13, 2)
names.append('sprite SPARK    13 2      # a shot hitting')
# ---- an explosion: four frames
rnd = random.Random(5)
for f in range(4):
    v = Cv(16, 16)
    r = 2.5 + f * 1.7
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5) + rnd.uniform(-1.0, 1.0)
            if f == 3:
                if r - 2.2 < d < r: v.set(x, y, 4 if rnd.random() < 0.55 else 3)
            elif d < r * 0.35: v.set(x, y, 1)
            elif d < r * 0.6: v.set(x, y, 8)
            elif d < r * 0.85: v.set(x, y, 9)
            elif d < r: v.set(x, y, 10)
    for k in range(3 + f):          # flying bits
        a = rnd.uniform(0, 6.28); t = r + 1 + rnd.uniform(0, 2)
        v.set(7.5 + math.cos(a) * t, 7.5 + math.sin(a) * t, 8 if f < 2 else 3)
    v.into(S, f, 3)
names.append('sprite BOOM     0 3 4     # an explosion: four frames')

# ---- the bosses: giant mechs, 64 x 48 (only the left half kept: the game mirrors it)
def boss(kind):
    v = Cv(64, 48)
    # everything is drawn on the right half (x >= 32) and mirrored
    if kind == 1:     # GOLIATH: a broad walker with shoulder cannons
        v.poly([(32, 46), (44, 42), (50, 30), (50, 10), (40, 4), (32, 4)], 2)
        v.circle(54, 16, 9, 5); v.circle(54, 16, 6, 6); v.rect(52, 22, 56, 40, 7); v.rect(53, 38, 55, 44, 9)
        v.rect(32, 10, 42, 30, 3); v.circle(32, 18, 6, 10); v.circle(32, 18, 3, 11); v.circle(32, 18, 1.5, 8)
        for y in range(32, 44, 3): v.rect(34, y, 44, y, 12)
        v.rect(44, 6, 48, 8, 13)
    elif kind == 2:   # WARHOUND: a long hull with jaws and four legs
        v.poly([(32, 47), (38, 40), (42, 6), (36, 0), (32, 0)], 2)
        v.poly([(38, 38), (46, 47), (42, 47), (36, 42)], 5)
        for (y, l) in ((8, 1), (24, 1)):
            v.poly([(40, y), (60, y - 4), (62, y + 2), (58, y + 8), (40, y + 6)], 5)
            v.rect(56, y - 2, 60, y + 6, 6)
        v.circle(32, 30, 5, 10); v.circle(32, 30, 2.5, 11); v.circle(32, 14, 4, 8); v.circle(32, 14, 2, 9)
        for y in range(4, 40, 5): v.rect(33, y, 39, y, 3)
    elif kind == 3:   # SERAPH: winged, a halo of guns
        v.poly([(32, 44), (40, 40), (42, 20), (36, 6), (32, 4)], 2)
        v.poly([(40, 18), (63, 2), (63, 12), (56, 24), (44, 30)], 5)
        v.poly([(44, 28), (60, 26), (58, 36), (44, 36)], 6)
        for k in range(4): v.rect(48 + k * 4, 8 - k, 49 + k * 4, 24 - k * 3, 7)
        v.circle(32, 16, 7, 10); v.circle(32, 16, 4, 11); v.circle(32, 16, 1.5, 1)
        for a in range(6):
            an = a * math.pi / 6 - math.pi / 2
            v.circle(32 + math.cos(an) * 13, 28 + math.sin(an) * 13 * -1, 2, 8)
    elif kind == 4:   # LEVIATHAN: a massive armoured tank-mech with a main gun
        v.poly([(32, 46), (60, 46), (62, 40), (62, 6), (56, 2), (32, 2)], 2)
        v.rect(54, 4, 62, 44, 4)
        for y in range(6, 44, 4): v.rect(55, y, 61, y, 3)
        v.circle(32, 22, 12, 5); v.circle(32, 22, 9, 6); v.rect(30, 30, 33, 47, 7)
        v.circle(32, 22, 4, 10); v.circle(32, 22, 2, 8)
        v.rect(40, 34, 50, 40, 12); v.rect(41, 35, 49, 36, 13)
        v.circle(46, 10, 3, 9)
    else:             # ARCHANGEL: a white knight, wings, a lance
        v.poly([(32, 46), (38, 44), (40, 26), (38, 10), (32, 6)], 2)
        v.poly([(38, 12), (62, 0), (63, 8), (52, 18), (40, 22)], 5)
        v.poly([(40, 22), (63, 14), (60, 24), (42, 30)], 6)
        v.poly([(40, 30), (58, 30), (54, 38), (40, 36)], 7)
        v.circle(44, 14, 5, 3); v.rect(46, 18, 48, 40, 3)
        v.rect(47, 40, 47, 47, 8)
        v.circle(32, 14, 5, 10); v.circle(32, 14, 2.5, 11); v.circle(32, 26, 3, 8); v.circle(32, 26, 1.5, 1)
        v.poly([(28, 4), (32, 8), (36, 4), (32, 0)], 12)
    v.mirror_r()
    q = [r[:] for r in v.p]
    groups = {2: (2, 4), 3: (2, 4), 4: (2, 4), 5: (5, 7), 6: (5, 7), 7: (5, 7)}
    for y in range(48):
        for x in range(64):
            p = v.p[y][x]
            if p not in groups: continue
            lo, hi = groups[p]
            if v.get(x - 1, y) != p or v.get(x, y - 1) != p:
                q[y][x] = 1 if p == lo else p - 1
            elif v.get(x + 1, y) != p or v.get(x, y + 1) != p:
                q[y][x] = min(hi, p + 1)
            elif p == 2 and y % 8 == 4 and (x // 4) % 3 != 1:
                q[y][x] = 3
    v.p = q
    v.outline(0)
    return v
for k in range(5):
    b = boss(k + 1)
    left = Cv(32, 48)
    for y in range(48):
        for x in range(32): left.p[y][x] = b.p[y][x]
    cells(left, 4 + k * 2, 3, 2, 3)
    names.append('sprite BOSS%d    %d 3 1 2 3 # stage %d\'s boss: its left half (32 x 48)' % (k + 1, 4 + k * 2, k + 1))
S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# MECHRA - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# (the backgrounds are Layer 2 blocks: tools/bgart.py)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
# sprite palettes (spr_pal.png rows): 0 the art, 1 hit flash, 2 pink, 3 blue, 4 gold bullets,
# 5-9 the bosses, 10 the enemies' later colours
tile   PANEL    1
tile   PANELT   2         # a panel cell with a line along its top
tile   BLACK    3
tile   PANELR   4         # a line on its right
tile   PANELL   5         # a line on its left
tile   LIFE     6         # a mech left
tile   BOMB     7         # a guard left
tile   GAUGE    16 9      # the chain gauge: 0-8 filled
tile   PGAUGE   9 5       # the power gauge: 0, 2, 4, 6, 8 filled

''' + '\n'.join(names) + '\n')
print('ok')
