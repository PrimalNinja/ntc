# CHAOTIC - the sprites and the panel's tiles: writes ../gfx/* (then gfxtool.js makes GfxData.cls)
# (run: python3 tools/art_chaotic.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# Everything is drawn as glowing lines, like the web: each shape is a list of line ends worked
# out here (so the claw turned 45 degrees is the same lines, turned), drawn into 16 x 16 cells.
# The far-away size of each enemy is the same lines at half size.
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
from cvkit import Cv

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# ---------------------------------------------------------------- tiles: the panel
# 0 black, 1 white, 2 light grey, 3 grey, 4 the panel (deep violet), 5 its line (magenta), 6 red,
# 7 orange, 8 yellow, 9 cyan, 10 blue, 11 pink, 12 green, 13 dark red, 14 purple
TP = [c(0,0,0), c(7,7,3), c(5,5,2), c(3,3,1), c(1,0,1), c(6,1,3), c(7,1,0), c(7,4,0),
      c(7,7,0), c(2,7,3), c(1,2,3), c(7,3,2), c(2,6,0), c(3,0,0), c(3,0,2), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=0, paper=15)
K = {'k': 0, 'w': 1, 'l': 2, 'g': 3, 'N': 4, 'n': 5, 'r': 6, 'o': 7, 'y': 8, 'c': 9, 'b': 10, 'p': 11, 'e': 12, 'R': 13, 'v': 14, '.': 15}
T.put(1, 0, ['NNNNNNNN'] * 8, K)                                   # the panel
T.put(2, 0, ['NNNNNNNN'] * 7 + ['nnnnnnnn'], K)                    # its bottom edge
T.put(3, 0, ['........', '...yy...', '..y..y..', '.y.yy.y.', 'y.y..y.y', 'yy....yy', 'y......y', '........'], K)  # a life (a claw)
T.put(4, 0, ['........', '..rrrr..', '.roooor.', 'roowwoor', 'roowwoor', '.roooor.', '..rrrr..', '........'], K)  # a nova
T.put(5, 0, ['........', '..cccc..', '.c....c.', 'c..ww..c', 'c..ww..c', '.c....c.', '..cccc..', '........'], K)  # a guard
for k in range(9):          # 16-24: the chain gauge 0-8
    rows = []
    for y in range(8):
        if y in (0, 7): rows.append('........')
        else: rows.append(''.join(('y' if y < 4 else 'o') if x < k else 'g' for x in range(8)))
    T.put((16 + k) % 16, (16 + k) // 16, rows, K)
for k in range(5):          # 9-13: the power gauge 0-8 in twos
    rows = []
    for y in range(8):
        if y in (0, 7): rows.append('........')
        else: rows.append(''.join(('c' if y < 4 else 'b') if x < k * 2 else 'g' for x in range(8)))
    T.put(9 + k, 0, rows, K)
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprite palettes
# 0 black, 1 white, 2 yellow, 3 orange, 4 red, 5 magenta, 6 purple, 7 blue, 8 cyan, 9 green,
# 10 lime, 11 pink, 12 dark blue, 13 dark red, 14 grey
SP0 = [c(0,0,0), c(7,7,3), c(7,7,0), c(7,4,0), c(7,0,0), c(7,0,3), c(4,0,3), c(1,2,3),
       c(0,7,3), c(0,6,0), c(5,7,0), c(7,3,3), c(0,0,2), c(3,0,0), c(4,4,2), MAGENTA]
FLASH = [c(5,5,2)] + [c(7,7,3)] * 14 + [MAGENTA]
# bullets use 1 (core) 2 3 4 (rings, light to dark)
PINK = SP0[:]; PINK[2:5] = [c(7,5,3), c(7,2,3), c(5,0,2)]
CYAN = SP0[:]; CYAN[2:5] = [c(4,7,3), c(0,6,3), c(0,3,3)]
GOLD = SP0[:]; GOLD[2:5] = [c(7,7,1), c(7,5,0), c(6,2,0)]
GREEN = SP0[:]; GREEN[2:5] = [c(5,7,1), c(2,7,0), c(0,4,0)]
# the enemies' later colours: everything shifted round the colour wheel
ALT1 = SP0[:]; ALT1[4] = c(0,7,3); ALT1[5] = c(7,7,0); ALT1[9] = c(7,0,3); ALT1[8] = c(7,3,0); ALT1[6] = c(0,4,2)
ALT2 = SP0[:]; ALT2[4] = c(7,7,0); ALT2[5] = c(0,7,0); ALT2[9] = c(0,3,3); ALT2[8] = c(7,0,0); ALT2[6] = c(4,4,0)
CORE2 = SP0[:]; CORE2[5] = c(7,7,3); CORE2[6] = c(7,0,3); CORE2[8] = c(7,7,0)
palette_png(D + '/spr_pal.png', [SP0, FLASH, PINK, CYAN, GOLD, GREEN, ALT1, ALT2, CORE2])

S = Sheet(16, 4, SP0)

def line(v, x0, y0, x1, y1, i):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 2) + 1
    for k in range(n + 1):
        t = k / n
        v.set(round(x0 + (x1 - x0) * t), round(y0 + (y1 - y0) * t), i)

def shape(lines, size=16, scale=1.0, rot=0.0, cx=None, cy=None):
    # lines: (x0, y0, x1, y1, colour) about the middle (-8 .. 8)
    v = Cv(size, size)
    cx = size / 2 - 0.5 if cx is None else cx
    cy = size / 2 - 0.5 if cy is None else cy
    ca, sa = math.cos(rot), math.sin(rot)
    for x0, y0, x1, y1, i in lines:
        a = (x0 * ca - y0 * sa) * scale + cx, (x0 * sa + y0 * ca) * scale + cy
        b = (x1 * ca - y1 * sa) * scale + cx, (x1 * sa + y1 * ca) * scale + cy
        line(v, a[0], a[1], b[0], b[1], i)
    return v

def loop(pts, i):
    return [(pts[k][0], pts[k][1], pts[(k + 1) % len(pts)][0], pts[(k + 1) % len(pts)][1], i) for k in range(len(pts))]

def ngon(n, r, rot=0.0):
    return [(r * math.sin(rot + 2 * math.pi * k / n), -r * math.cos(rot + 2 * math.pi * k / n)) for k in range(n)]

# ---- the claw: on the rim, its two prongs reaching in (up, here), the rim under its feet
def claw(f):
    L = [(-7, 5, -3, -6, 2), (7, 5, 3, -6, 2), (-7, 5, 7, 5, 2), (-3, -6, 0, 1, 3), (3, -6, 0, 1, 3),
         (-5, 3, 5, 3, 3)]
    if f: L += [(0, 1, 0, -7, 1), (-1, -1, 1, -1, 1)]
    return L
S_C = [shape(claw(0)), shape(claw(1)), shape(claw(0), rot=math.pi / 4, scale=0.95), shape(claw(1), rot=math.pi / 4, scale=0.95)]
for k, v in enumerate(S_C): v.into(S, k, 0)

# ---- your shot: a ball of light; and a smaller one (far down the web)
def blob(r, col):
    v = Cv(16, 16)
    v.circle(7.5, 7.5, r, col[2]); v.circle(7.5, 7.5, r * 0.7, col[1]); v.circle(7.5, 7.5, r * 0.4, col[0])
    return v
blob(4.5, [1, 2, 3]).into(S, 4, 0)
blob(2.5, [1, 2, 3]).into(S, 5, 0)

# ---- their bullets (drawn in 1-4: each palette row colours them): a dot, an orb, a needle
blob(2.6, [1, 2, 3]).into(S, 6, 0)
v = Cv(16, 16); v.circle(7.5, 7.5, 4.6, 4); v.circle(7.5, 7.5, 3.6, 3); v.circle(7.5, 7.5, 2.4, 2); v.circle(7.5, 7.5, 1.2, 1); v.into(S, 7, 0)
v = shape([(0, -6, 2, 0, 3), (2, 0, 0, 6, 3), (0, 6, -2, 0, 3), (-2, 0, 0, -6, 3), (0, -4, 0, 4, 1), (-1, 0, 1, 0, 2)]); v.into(S, 8, 0)

# ---- the guard: a ring of light (shown twice the size round the claw)
v = Cv(16, 16)
for a in range(0, 360, 12):
    x = 7.5 + 7 * math.cos(math.radians(a)); y = 7.5 + 7 * math.sin(math.radians(a))
    v.set(round(x), round(y), 8 if (a // 12) % 2 else 1)
v.into(S, 9, 0)

# ---- the pickups (from DEFENDER HELLGATE): P (two frames: turning), big P, a gem, G (a guard),
# N (a nova: the smart bomb)
F = font8x8()
def letter(v, ch, x0, y0, i, w=8):
    g = F[ord(ch)]
    for y in range(8):
        for x in range(8):
            if g[y] & (0x80 >> x):
                v.set(x0 + (x * w) // 8, y0 + y, i)
def badge(ch, ring, fill, ink, w=16):
    v = Cv(16, 16)
    x0 = (16 - w) // 2
    v.rect(x0 + 1, 2, x0 + w - 2, 13, fill)
    for x in range(x0 + 1, x0 + w - 1): v.set(x, 1, ring); v.set(x, 14, ring)
    for y in range(2, 14): v.set(x0, y, ring); v.set(x0 + w - 1, y, ring)
    letter(v, ch, x0 + (w - 8) // 2 + (1 if w < 16 else 4), 4, ink, 8 if w >= 12 else 6)
    return v
badge('P', 8, 7, 1, 12).into(S, 10, 0)
badge('P', 8, 7, 1, 8).into(S, 11, 0)
v = badge('P', 2, 3, 1, 16)
for k in range(16): v.set(k, 0 if k % 3 else 1, 2)
v.into(S, 12, 0)
shape([(0, -7, 6, 0, 8), (6, 0, 0, 7, 8), (0, 7, -6, 0, 8), (-6, 0, 0, -7, 8), (-6, 0, 6, 0, 1), (0, -7, -2, 0, 1), (0, -7, 2, 0, 1), (-2, 0, 0, 7, 9), (2, 0, 0, 7, 9)]).into(S, 13, 0)
badge('G', 9, 12, 10, 14).into(S, 14, 0)
badge('N', 4, 13, 2, 14).into(S, 15, 0)

# ---- the enemies: a far-away one (half size), then two frames close up
def enemy(col, L0, L1):
    shape(L0, scale=0.5).into(S, col, 1)
    shape(L0).into(S, col + 1, 1)
    shape(L1).into(S, col + 2, 1)

# a snapper: the bow tie that flips over and over (red, magenta middle)
snap0 = loop([(-7, -4), (7, 4), (7, -4), (-7, 4)], 4) + [(-2, 0, 2, 0, 5)]
snap1 = loop([(-7, -1), (7, 1), (7, -1), (-7, 1)], 4) + [(0, -3, 0, 3, 5)]
enemy(0, snap0, snap1)
# a pod: carries two snappers (purple, a green middle)
pod0 = loop(ngon(4, 7), 6) + loop(ngon(4, 4, math.pi / 4), 5) + [(-1, 0, 1, 0, 9), (0, -1, 0, 1, 9)]
pod1 = loop(ngon(4, 7), 6) + loop(ngon(4, 4), 5) + [(-1, -1, 1, 1, 9), (-1, 1, 1, -1, 9)]
enemy(3, pod0, pod1)
# a spinner: a spiral that turns, firing as it goes (green)
def spiral(rot):
    pts = [(0.5 * k * math.cos(rot + k * 0.55), 0.5 * k * math.sin(rot + k * 0.55)) for k in range(15)]
    return [(pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1], 9 if k < 10 else 10) for k in range(14)]
enemy(6, spiral(0), spiral(math.pi / 2))
# a pulsar: a zigzag that lights its lane (cyan, white when it pulses)
puls0 = loop([(-7, 0), (-4, -5), (-1, 5), (2, -5), (5, 5), (7, 0)], 8)[:-1]
puls1 = loop([(-7, 0), (-4, -7), (-1, 7), (2, -7), (5, 7), (7, 0)], 1)[:-1] + [(-7, 1, 7, 1, 8)]
enemy(9, puls0, puls1)
# a seeder: sits in its lane spraying rings of bullets (orange, yellow spokes)
seed0 = loop(ngon(8, 7), 3) + [(0, 0, x, y, 2) for x, y in ngon(4, 5)]
seed1 = loop(ngon(8, 7, math.pi / 8), 3) + [(0, 0, x, y, 2) for x, y in ngon(4, 5, math.pi / 4)] + [(-1, 0, 1, 0, 1)]
enemy(12, seed0, seed1)
# a fuse: crackling, jumping lanes (every colour)
fuse0 = [(-7, 0, -3, -3, 4), (-3, -3, 0, 2, 2), (0, 2, 3, -4, 8), (3, -4, 7, 1, 5), (0, -7, -2, -2, 10), (0, 7, 2, 1, 1)]
fuse1 = [(-7, 2, -2, -1, 8), (-2, -1, 1, 4, 5), (1, 4, 4, -2, 2), (4, -2, 7, -1, 4), (-1, -7, 1, -3, 1), (-1, 7, -3, 2, 10)]
shape(fuse0, scale=0.5).into(S, 15, 1)
shape(fuse0).into(S, 0, 2)
shape(fuse1).into(S, 1, 2)

# ---- the core: the boss in the middle of the web, 32 x 32 (shown twice the size), two frames
def core(f):
    v = Cv(32, 32)
    for r, col, rot in ((15, 6, 0), (12, 5, math.pi / 8), (8, 8, 0)):
        pts = ngon(8, r, rot + (math.pi / 16 if f else 0))
        for k in range(8):
            a = pts[k]; b = pts[(k + 1) % 8]
            line(v, a[0] + 15.5, a[1] + 15.5, b[0] + 15.5, b[1] + 15.5, col)
    for k, (x, y) in enumerate(ngon(8, 15, math.pi / 16 if f else 0)):
        line(v, 15.5 + x * 0.55, 15.5 + y * 0.55, 15.5 + x, 15.5 + y, 5 if k % 2 else 6)
    v.circle(15.5, 15.5, 4.5, 4 if f else 13); v.circle(15.5, 15.5, 2.5, 2 if f else 4); v.circle(15.5, 15.5, 1, 1)
    return v
for f in range(2):
    v = core(f)
    for j in range(2):
        for i in range(2):
            cv = Cv(16, 16)
            for y in range(16):
                for x in range(16): cv.p[y][x] = v.p[j * 16 + y][i * 16 + x]
            cv.into(S, 2 + f * 2 + i, 2 + j)

S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# CHAOTIC - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
# sprite palettes (spr_pal.png rows): 0 the art, 1 hit flash, 2 pink, 3 cyan, 4 gold, 5 green
# bullets, 6 7 the enemies' later colours, 8 the core hurt
tile   PANEL    1
tile   PANELB   2         # the panel's bottom edge
tile   LIFE     3         # a claw left
tile   NOVA     4         # a nova left
tile   GUARDT   5         # a guard left
tile   PGAUGE   9 5       # the power gauge: 0, 2, 4, 6, 8 filled
tile   GAUGE    16 9      # the chain gauge: 0-8 filled

sprite CLAW     0 0 2     # you: the claw, pointing in (straight); the second frame firing
sprite CLAWD    2 0 2     # the same, turned 45 degrees
sprite SHOT     4 0 2     # your shot: close, far
sprite BULLET   6 0 3     # their bullets: dot, orb, needle (drawn in 1-4: palettes 2-5)
sprite GUARD    9 0       # the guard's ring (twice the size)
sprite ITEM     10 0 2    # P, turning
sprite BIGP     12 0      # big P
sprite GEM      13 0      # a gem
sprite GITEM    14 0      # G: another guard
sprite NITEM    15 0      # N: another nova
sprite SNAP     0 1 3     # a snapper: far, close (2 frames)
sprite POD      3 1 3     # a pod
sprite SPIN     6 1 3     # a spinner
sprite PULS     9 1 3     # a pulsar
sprite SEED     12 1 3    # a seeder
sprite FUSES    15 1      # a fuse, far
sprite FUSE     0 2 2     # a fuse, close
sprite CORE     2 2 2 2 2 # the core (32 x 32): two frames
''')
print('ok')
