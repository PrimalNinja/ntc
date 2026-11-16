# DEFENDER HYPERSPACE - the sprites and the tiles: writes ../gfx/* (the planet: land.py)
# (run: python3 tools/art_defhyper.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
from cvkit import Cv

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# ---------------------------------------------------------------- tiles
# 0 black, 1 white, 2 the HUD (black), 3 the scanner's frame (blue), 4 the scanner, 5 its edge,
# 6 its ground (orange), 7 red, 8 green, 9 yellow, 10 cyan, 11 orange, 12 purple, 13 white dot,
# 14 the font's shadow
TP = [c(0,0,0), c(7,7,3), c(0,0,0), c(1,2,3), c(0,0,0), c(1,2,3), c(6,3,0), c(7,1,0),
      c(1,7,0), c(7,7,0), c(2,7,3), c(7,4,0), c(4,0,3), c(7,7,3), c(1,1,1), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=14, paper=2, chars=range(32, 96))
K = {('%x' % i): i for i in range(16)}; K['.'] = 15
def tile(n, rows): T.put(n % 16, n // 16, rows, K)
tile(1, ['22222222'] * 8)                                                   # HUD
tile(2, ['44444444'] * 8)                                                   # the scanner
tile(3, ['55555555'] + ['44444444'] * 7)                                    # its top edge
tile(4, ['44444444'] * 6 + ['66666666', '55555555'])                        # its bottom (the ground)
tile(5, ['22222222', '22222222', '22222222', '22d22222', '2dddddd2', '2c77ddd2', '22222222', '22222222'])  # a ship left
tile(6, ['22222222', '22222222', '22999222', '29111922', '29111922', '22999222', '22222222', '22222222'])  # a smart bomb
tile(7, ['00000000'] * 8)
tile(8, ['22222222', '2aaaaaaa', '2aaaaaaa', '2aaaaaaa', '2aaaaaaa', '2aaaaaaa', '2aaaaaaa', '22222222'])  # inviso, full
tile(9, ['22222222', '23333333', '23333333', '23333333', '23333333', '23333333', '23333333', '22222222'])  # inviso, empty
tile(10, ['55555555'] * 8)                                                  # the scanner's sides
# scanner dots: 96 + colour * 12 + row * 4 + across (2 x 2 pixels)
# colours: 0 enemy (red), 1 lander (green), 2 you (white), 3 humanoid (purple), 4 the Stargate (yellow)
for ci, col_ in enumerate(('7', '8', 'd', 'c', '9')):
    for sy in range(3):
        for sx in range(4):
            rows = []
            for y in range(8):
                rows.append(''.join(col_ if (sx * 2 <= x < sx * 2 + 2 and 1 + sy * 2 <= y < 3 + sy * 2) else '4' for x in range(8)))
            if sy == 2: rows[6] = ''.join('6' if ch == '4' else ch for ch in rows[6])
            tile(96 + ci * 12 + sy * 4 + sx, rows)
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprites
# 0 black, 1 white, 2 light grey, 3 grey, 4 red, 5 orange, 6 yellow, 7 green, 8 dark green,
# 9 cyan, 10 blue, 11 purple, 12 magenta, 13 pink, 14 brown
SP0 = [c(0,0,0), c(7,7,3), c(5,5,2), c(3,3,1), c(7,0,0), c(7,4,0), c(7,7,0), c(1,7,0),
       c(0,4,0), c(0,7,3), c(1,2,3), c(5,0,3), c(7,2,2), c(7,5,2), c(4,2,0), MAGENTA]
def swap(p, pairs):
    q = p[:]
    for a, b in pairs: q[a], q[b] = p[b], p[a]
    return q
FLASH = [c(7,7,3)] * 15 + [MAGENTA]
PINKB = [c(0,0,0), c(7,7,3)] + [c(7,2,3)] * 13 + [MAGENTA]        # bullets in pink
BLUEB = [c(0,0,0), c(7,7,3)] + [c(2,4,3)] * 13 + [MAGENTA]        # bullets in blue
INVISO = [c(0,0,0)] + [c(0,1,2)] * 3 + [c(1,2,3)] * 11 + [MAGENTA]  # the cloaked ship: a shimmer
MUT2 = swap(SP0, [(7, 11), (8, 12)])                              # a mutant's other colours
RED = SP0[:]; RED[11] = c(7,0,0); RED[12] = c(7,4,0)              # Big Red (Phred, in red)
GATE2 = swap(SP0, [(6, 9), (4, 10)])                              # the Stargate's other colours
palette_png(D + '/spr_pal.png', [SP0, FLASH, PINKB, BLUEB, INVISO, MUT2, RED, GATE2])
S = Sheet(16, 4, SP0)
names = []
KEY = {'.': None, ' ': None}
for i in range(15): KEY['0123456789abcde'[i]] = i

def art(rows, w=16, h=16, ox=None, oy=None):
    v = Cv(w, h)
    aw = max(len(r) for r in rows); ah = len(rows)
    if ox is None: ox = (w - aw) // 2
    if oy is None: oy = (h - ah) // 2
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if KEY.get(ch) is not None: v.set(ox + x, oy + y, KEY[ch])
    return v

def put2(v, col, row):
    for i in range(v.w // 16):
        cv = Cv(16, 16)
        for y in range(16):
            for x in range(16): cv.p[y][x] = v.p[y][i * 16 + x]
        cv.into(S, col + i, row)

# ---- row 0: the ship (32 x 16 facing right; no flame, then two flames), the laser, a humanoid,
# the Stargate, the hyperspace twinkle, the scanner's window, a mine
SHIP = [
    '..........................     ',
    '....11.........................',
    '....111.......99999............',
    '....1111....999999911..........',
    '..33111111111111111111111......',
    '..3311111111111111111111111111.',
    '..33111111111111111111111111...',
    '..334444444444444444444444.....',
    '....cccccccc...................',
]
FLAMES = [[], ['ccc', 'c6c'], ['6cc6', 'cccc']]
for f in range(3):
    v = Cv(32, 16)
    for y, r in enumerate(SHIP):
        for x, ch in enumerate(r):
            if KEY.get(ch) is not None: v.set(x, 3 + y + 1, KEY[ch])
    for y, r in enumerate(FLAMES[f]):
        for x, ch in enumerate(r): v.set(x, 8 + y, KEY[ch])
    put2(v, f * 2, 0)
names.append('sprite SHIP     0 0 3 2 1 # you: 32 x 16 facing right (mirrored for left): no flame, two flames')
v = Cv(16, 16)
for x in range(16): v.set(x, 7, [1, 1, 1, 1, 6, 6, 5, 5, 12, 12, 11, 11, 10, 10, 9, 9][15 - x])
v.into(S, 6, 0)
names.append('sprite LASER    6 0       # your laser: a streak, white at the front')
HUM = [['..dd..', '..dd..', '.cccc.', 'c.cc.c', '..cc..', '..88..', '.8..8.', '.8..8.'],
       ['..dd..', '..dd..', '.cccc.', 'c.cc.c', '..cc..', '..88..', '..88..', '..8.8.'],
       ['c.dd.c', 'c.dd.c', '.cccc.', '..cc..', '..cc..', '..88..', '.8..8.', '8....8']]
for f in range(3): art(HUM[f], oy=7).into(S, 7 + f, 0)
names.append('sprite HUMAN    7 0 3     # a humanoid: walking x2, arms up (carried, falling)')
for f in range(2):
    v = Cv(16, 16)
    o, i_ = (6, 4) if f == 0 else (9, 10)
    v.rect(0, 0, 15, 1, o); v.rect(0, 14, 15, 15, o); v.rect(0, 0, 1, 15, o); v.rect(14, 0, 15, 15, o)
    v.rect(3, 3, 12, 3, i_); v.rect(3, 12, 12, 12, i_); v.rect(3, 3, 3, 12, i_); v.rect(12, 3, 12, 12, i_)
    for k in range(0, 16, 4): v.set(k + f * 2, 0, 1); v.set(15 - k - f * 2, 15, 1)
    v.into(S, 10 + f, 0)
names.append('sprite GATE     10 0 2    # the Stargate (drawn 2x: 32 x 32)')
v = Cv(16, 16)
for k, (x, y) in enumerate(((2, 2), (6, 1), (10, 3), (13, 6), (3, 9), (8, 12), (12, 13), (1, 14))): v.set(x, y, 6 if k % 2 else 1)
v.into(S, 12, 0)
names.append('sprite STARS    12 0      # a hyperspace twinkle')
v = Cv(16, 16)
for y in range(16): v.set(0, y, 1); v.set(15, y, 1)
v.set(1, 0, 1); v.set(14, 0, 1); v.set(1, 15, 1); v.set(14, 15, 1)
v.into(S, 13, 0)
names.append('sprite WINDOW   13 0      # the scanner: what\'s on screen (drawn 2x across)')
art(['.1.', '161', '.1.']).into(S, 14, 0)
names.append('sprite MINE     14 0      # a bomber\'s mine')

# ---- row 1: the Defender crew (2 frames each)
LANDER = [
    ['....7777....', '..77777777..', '.7766766677.', '777777777777', '.8.8.88.8.8.', '.8..8..8..8.', '8...8..8...8', '8...8..8...8'],
    ['....7777....', '..77777777..', '.7676676767.', '777777777777', '.8.8.88.8.8.', '.8..8..8..8.', '.8..8..8..8.', '8....88....8'],
]
MUTANT = [
    ['..b77b..', '.7bb7bb7', 'b7b77b7b', '7bbbbbb7', 'b77bb77b', '.b7..7b.', 'b7....7b', '7......7'],
    ['..7bb7..', '.b77b77b', '7b7bb7b7', 'b777777b', '7bb77bb7', '.7b..b7.', '.7b..b7.', '7b....b7'],
]
BOMBER = [
    ['abbbbbba', 'b111111b', 'b1baab1b', 'b1aaaa1b', 'b1aaaa1b', 'b1baab1b', 'b111111b', 'abbbbbba'],
    ['abbbbbba', 'b111111b', 'b1abba1b', 'b1bbbb1b', 'b1bbbb1b', 'b1abba1b', 'b111111b', 'abbbbbba'],
]
POD = [
    ['b...b...b', '.b..b..b.', '..bb4bb..', '..b464b..', 'bb46664bb', '..b464b..', '..bb4bb..', '.b..b..b.', 'b...b...b'],
    ['....b....', '.b..b..b.', '..bb4bb..', '..b464b..', 'bbb666bbb', '..b464b..', '..bb4bb..', '.b..b..b.', '....b....'],
]
SWARM = [['.44.', '4664', '4664', '.44.'], ['4..4', '.66.', '.66.', '4..4']]
BAITER = [
    ['....7777777....', '.77777777777777.', '7787787787787787', '.77777777777777.'],
    ['....7777777....', '.77777777777777.', '7877877877877877', '.77777777777777.'],
]
FIREB = [
    ['....5....', '....5....', '...565...', '..56165..', '55611165.5', '..56165..', '...565...', '....5....', '....5....'],
    ['5.......5', '.5.....5.', '..5...5..', '...616...', '...111...', '...616...', '..5...5..', '.5.....5.', '5.......5'],
]
FIREB[0][4] = '556111655'
FIREBALL = [['.565.', '56165', '61116', '56165', '.565.'], ['5.6.5', '.616.', '61116', '.616.', '5.6.5']]
for k, (fr, oy) in enumerate(((LANDER, None), (MUTANT, None), (BOMBER, None), (POD, None), (SWARM, None),
                              (BAITER, None), (FIREB, None), (FIREBALL, None))):
    art(fr[0], oy=oy).into(S, k * 2, 1); art(fr[1], oy=oy).into(S, k * 2 + 1, 1)
names.append('sprite LANDER   0 1 2     # 150: takes humanoids up; at the top it turns mutant')
names.append('sprite MUTANT   2 1 2     # 150: fast, mad, shoots')
names.append('sprite BOMBER   4 1 2     # 250: drifts, lays mines')
names.append('sprite POD      6 1 2     # 1000: bursts into swarmers when shot')
names.append('sprite SWARMER  8 1 2     # 150: small and fast')
names.append('sprite BAITER   10 1 2    # 200: turns up when you take too long')
names.append('sprite FIREB    12 1 2    # 250: a firebomber: spins, throws fireballs')
names.append('sprite FIREBALL 14 1 2    # 100: a firebomber\'s fireball')

# ---- row 2: the Stargate crew, bullets
DYNAMO = [
    ['....a....', '...a9a...', '..a.1.a..', '.a.919.a.', 'a91111.9a', '.a.919.a.', '..a.1.a..', '...a9a...', '....a....'],
    ['....9....', '...9a9...', '..9.1.9..', '.9.a1a.9.', '9a.111.a9', '.9.a1a.9.', '..9.1.9..', '...9a9...', '....9....'],
]
DYNAMO[0][4] = 'a9.111.9a'
HUM_ = [['.9.', '919', '.9.'], ['9.9', '.1.', '9.9']]
GUPPY = [
    ['a.....555...', 'aa..55665..', '.aa556616 5.', '..a5555555 5', '.aa5566665.', 'aa..5555...', 'a...........'],
    ['............', 'a....555....', '.a.55665....', '.aa5566165.', '.aa5555555.', '.a.5566665..', 'a....555....'],
]
GUPPY[0] = ['a.....555...', 'aa..556665..', '.aa55661655.', '..a55555555.', '.aa55666655.', 'aa..55555...', 'a...........']
GUPPY[1] = ['............', 'a....555....', '.a.5566655..', '.aa55661655.', '.aa55555555.', '.a.5566665..', 'a....555....']
PHRED = [
    ['.bbbbbbbb.', 'bbbbbbbbbb', 'bb11bbbbbb', 'bb10bbbbbb', 'bbbbbbbbbb', 'bbbbbb....', 'bbbbbbbbbb', 'bbbbbbbbbb', 'bbbbbbbbbb', '.bbbbbbbb.'],
    ['.bbbbbbbb.', 'bbbbbbbbbb', 'bb11bbbbbb', 'bb10bbbbbb', 'bbbbbb....', 'bbbb......', 'bbbbbb....', 'bbbbbbbbbb', 'bbbbbbbbbb', '.bbbbbbbb.'],
]
PHRED[0][5] = 'bbbb1.1.1.'
PHRED[1][4] = 'bbbb1.1.1.'; PHRED[1][6] = 'bbbb1.1.1.'
MUNCH = [['.777.', '77177', '777..', '77777', '.777.'], ['.777.', '77177', '77...', '777..', '.777.']]
for k, fr in enumerate((DYNAMO, HUM_, GUPPY, PHRED, MUNCH)):
    art(fr[0]).into(S, k * 2, 2); art(fr[1]).into(S, k * 2 + 1, 2)
names.append('sprite DYNAMO   0 2 2     # 200: a diamond of space hums that break off')
names.append('sprite HUM      2 2 2     # 100: a space hum')
names.append('sprite GUPPY    4 2 2     # 200: a Yllabian space guppy: swarms, wiggles, homes in')
names.append('sprite PHRED    6 2 2     # 200: Phred (purple) and Big Red (palette 6): chase you, spit munchies')
names.append('sprite MUNCHIE  8 2 2     # 50: a munchie')
v = Cv(16, 16); v.rect(7, 7, 8, 8, 1); v.into(S, 10, 2)
v = Cv(16, 16); v.rect(6, 6, 9, 9, 2); v.rect(7, 7, 8, 8, 1); v.into(S, 11, 2)
names.append('sprite BULLET   10 2 2    # small, big (pink: palette 2, blue: 3)')

# ---- row 3: explosions: sprays of bits flying out
random.seed(7)
bits = [(random.uniform(0, 2 * math.pi), random.uniform(0.5, 1.0), random.choice((1, 6, 5, 4, 12, 9))) for _ in range(26)]
for f in range(4):
    v = Cv(16, 16)
    r = 1.5 + f * 2.1
    if f == 0: v.rect(6, 6, 9, 9, 1); v.rect(7, 5, 8, 10, 6); v.rect(5, 7, 10, 8, 6)
    for a, s, col_ in bits:
        x = 7.5 + math.cos(a) * r * s; y = 7.5 + math.sin(a) * r * s
        if f == 3 and random.random() < 0.4: continue
        v.set(x, y, 3 if f == 3 else col_)
    v.into(S, f, 3)
names.append('sprite BOOM     0 3 4     # an explosion: bits flying out')
S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# DEFENDER HYPERSPACE - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# (the planet is Layer 2: tools/land.py)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
# sprite palettes (spr_pal.png rows): 0 everything, 1 a hit flash, 2 pink bullets, 3 blue bullets,
# 4 the cloaked ship, 5 a mutant's other colours, 6 Big Red, 7 the Stargate's other colours
tile   HUD      1
tile   SCAN     2         # the scanner
tile   SCANT    3         # its top edge
tile   SCANG    4         # its bottom row, the ground along it
tile   LIFE     5         # a ship left
tile   SMART    6         # a smart bomb left
tile   BLACK    7
tile   INV      8         # the inviso bar: full
tile   INVE     9         # and empty
tile   SCANS    10        # the scanner's sides
tile   DOT      96 60     # scanner dots: 96 + colour (0 enemy, 1 lander, 2 you, 3 humanoid, 4 gate) * 12 + row * 4 + across

''' + '\n'.join(names) + '\n')
im = S.img.convert('RGB').resize((S.w * 3, S.h * 3), Image.NEAREST)
im.save(os.path.join(HERE, 'sprites_preview.png'))
print('ok')
