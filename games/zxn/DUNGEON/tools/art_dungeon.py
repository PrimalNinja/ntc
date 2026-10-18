# DUNGEON - the monsters, the heroes' faces, the things and the tiles: writes ../gfx/*
# (run: python3 tools/art_dungeon.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# The monsters are 12 shapes (32 x 32), each drawn in colour numbers and coloured by a palette
# row (a colour scheme), so one shape makes several monsters (a goblin and a hobgoblin):
#   0 outline, 1 white, 2-4 the body light / mid / dark, 5 the eyes, 6-7 cloth or a weapon
#   light / dark, 8 steel, 9 bone, 10 red, 11 gold, 12-14 spare (row 0's own colours)
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
from cvkit import Cv

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# ---------------------------------------------------------------- tiles: the panels, bars, font
# 0 black, 1 white, 2 the panel (dark slate), 3 its edge, 4 parchment, 5 red (HP), 6 blue (MP),
# 7 gold, 8 green, 9 grey, 10 dark red, 11 dark blue, 12 the map's wall, 13 the map's floor,
# 14 the font's shadow
TP = [c(0,0,0), c(7,7,3), c(1,1,1), c(4,3,1), c(6,5,2), c(7,1,0), c(2,4,3), c(7,6,0),
      c(2,6,0), c(4,4,2), c(2,0,0), c(0,1,1), c(5,4,2), c(1,1,0), c(0,0,0), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=14, paper=2, chars=range(32, 96))
K = {('%x' % i): i for i in range(16)}; K['.'] = 15
def tile(n, rows): T.put(n % 16, n // 16, rows, K)
tile(1, ['22222222'] * 8)                                                   # PANEL
tile(2, ['33333333', '32222222', '32222222', '32222222', '32222222', '32222222', '32222222', '32222222'])  # frame TL
tile(3, ['33333333'] + ['22222222'] * 7)                                    # T
tile(4, ['33333333', '22222223', '22222223', '22222223', '22222223', '22222223', '22222223', '22222223'])  # TR
tile(5, ['32222222'] * 8)                                                   # L
tile(6, ['22222223'] * 8)                                                   # R
tile(7, ['32222222'] * 7 + ['33333333'])                                    # BL
tile(8, ['22222222'] * 7 + ['33333333'])                                    # B
tile(9, ['22222223'] * 7 + ['33333333'])                                    # BR
tile(10, ['00000000'] * 8)                                                  # BLACK
tile(11, ['22222222', '22277222', '22722722', '22277222', '22227222', '22227722', '22227222', '22222222'])  # a key
tile(12, ['22222222', '22277722', '27777772', '27277272', '27777772', '22777722', '22222222', '22222222'])  # gold
tile(13, ['22222222', '22299222', '22255222', '22555522', '25555552', '25555552', '22555522', '22222222'])  # a potion
# bars: 112-120 red (HP), 121-129 blue (MP)
for k in range(9):
    for base, f, e in ((112, '5', 'a'), (121, '6', 'b')):
        tile(base + k, ['22222222'] + [''.join(f if x < k else e for x in range(8)) for _ in range(5)] + ['22222222', '22222222'])
# the map: a wall, a floor, you (4 ways), stairs, a door, a monster
tile(96, ['cccccccc'] * 8)
tile(97, ['dddddddd'] * 8)
tile(98, ['ddd11ddd', 'dd1111dd', 'd111111d', 'ddd11ddd', 'ddd11ddd', 'ddd11ddd', 'dddddddd', 'dddddddd'])   # you, facing north
tile(99, ['dddddddd', 'dddd1ddd', 'dddd11dd', '1111111d', '1111111d', 'dddd11dd', 'dddd1ddd', 'dddddddd'])   # east
tile(100, ['dddddddd', 'dddddddd', 'ddd11ddd', 'ddd11ddd', 'ddd11ddd', 'd111111d', 'dd1111dd', 'ddd11ddd'])  # south
tile(101, ['dddddddd', 'ddd1dddd', 'dd11dddd', 'd1111111', 'd1111111', 'dd11dddd', 'ddd1dddd', 'dddddddd'])  # west
tile(102, ['dddddddd', 'd7777777', 'd7dddddd', 'd7777777', 'd7dddddd', 'd7777777', 'd7dddddd', 'dddddddd'])  # stairs
tile(103, ['cccccccc', 'c333333c', 'c3dddd3c', 'c3dddd3c', 'c3dd773c', 'c3dddd3c', 'c3dddd3c', 'cccccccc'])  # a door
tile(104, ['dddddddd', 'dd5dd5dd', 'd555555d', 'd5155155', 'd555555d', 'dd5dd5dd', 'dddddddd', 'dddddddd'])  # monsters
tile(105, ['dddddddd', 'd777777d', 'd7dddd7d', 'd777777d', 'd7d77d7d', 'd777777d', 'dddddddd', 'dddddddd'])  # a chest
tile(106, ['00000000'] * 8)                                                 # not seen yet
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprite palettes
# row 0: the heroes and the things (natural colours); rows 1-9 the monsters' schemes; 10 a flash
SP0 = [c(0,0,0), c(7,7,3), c(7,5,2), c(6,4,1), c(4,2,0), c(2,7,3), c(5,1,3), c(2,0,1),
       c(5,5,2), c(7,7,2), c(7,1,0), c(7,6,0), c(1,2,3), c(2,5,1), c(4,3,1), MAGENTA]
def scheme(l, m, d, eye, cl, cd):
    r = SP0[:]; r[2], r[3], r[4], r[5], r[6], r[7] = l, m, d, eye, cl, cd; return r
ROWS = [SP0,
        scheme(c(3,6,1), c(2,4,0), c(1,2,0), c(7,7,0), c(5,3,1), c(3,1,0)),    # 1 green (goblin, slime, troll)
        scheme(c(7,3,1), c(5,1,0), c(3,0,0), c(7,7,0), c(3,3,1), c(1,1,0)),    # 2 red (hobgoblin, demon, lava slime)
        scheme(c(7,7,2), c(6,6,2), c(4,4,1), c(7,0,0), c(4,3,1), c(2,1,0)),    # 3 bone (skeleton, mummy)
        scheme(c(5,4,1), c(4,2,0), c(2,1,0), c(7,0,0), c(6,5,2), c(3,2,1)),    # 4 brown (rat, spider, orc)
        scheme(c(3,3,3), c(2,2,2), c(1,1,1), c(7,0,0), c(4,4,3), c(2,2,2)),    # 5 grey / black (bat, spider)
        scheme(c(6,4,3), c(4,2,3), c(2,0,2), c(3,7,3), c(5,2,3), c(2,0,1)),    # 6 purple (wraith, phase spider)
        scheme(c(6,7,3), c(4,6,3), c(2,4,3), c(7,7,3), c(5,7,3), c(2,4,3)),    # 7 ghostly blue-white
        scheme(c(7,6,0), c(6,4,0), c(4,2,0), c(7,0,0), c(7,7,1), c(5,3,0)),    # 8 gold (the dragon)
        scheme(c(2,5,3), c(1,3,2), c(0,1,1), c(7,7,0), c(3,6,3), c(1,2,2)),    # 9 teal (lich, water)
        [c(7,7,3)] * 15 + [MAGENTA]]                                         # 10 a hit flash
palette_png(D + '/spr_pal.png', ROWS)
S = Sheet(16, 6, SP0)
names = []

def ell(v, cx, cy, rx, ry, i):
    for y in range(v.h):
        for x in range(v.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1: v.set(x, y, i)
def line(v, x0, y0, x1, y1, i, w=0.6):
    n = int(max(abs(x1 - x0), abs(y1 - y0)) * 3) + 1
    for k in range(n + 1):
        x = x0 + (x1 - x0) * k / n; y = y0 + (y1 - y0) * k / n
        if w <= 0.6: v.set(x, y, i)
        else: ell(v, x, y, w, w, i)
def shadeb(v):
    # light from the top left on the body colours: 3 -> 2 near the top-left edge, -> 4 at the bottom right
    q = [r[:] for r in v.p]
    for y in range(v.h):
        for x in range(v.w):
            if v.p[y][x] == 3:
                if v.get(x - 1, y - 1) is None or v.get(x, y - 2) is None: q[y][x] = 2
                elif v.get(x + 1, y + 1) is None or v.get(x + 2, y) is None: q[y][x] = 4
    v.p = q
def place(v, col, row):
    for j in range(2):
        for i in range(2):
            cv = Cv(16, 16)
            for y in range(16):
                for x in range(16): cv.p[y][x] = v.p[j * 16 + y][i * 16 + x]
            cv.into(S, col + i, row + j)

# ---------------------------------------------------------------- the monsters
def rat():
    v = Cv(32, 32)
    ell(v, 18, 22, 10, 6.5, 3)                      # body
    ell(v, 8, 20, 5.5, 4.5, 3)                      # head
    v.poly([(1, 21), (5, 18), (5, 23)], 3)          # snout
    ell(v, 9, 15.5, 2.2, 2.6, 3); ell(v, 9, 15.8, 1.2, 1.5, 6)   # ear
    v.set(6, 19, 5); v.set(7, 19, 5)                # eye
    for x in (10, 14, 21, 25): v.rect(x, 27, x + 1, 30, 4)
    for k in range(12): v.set(28 + k * 0.3, 22 - k * 0.9 + (k * k) * 0.05, 6)  # tail
    v.set(1, 21, 0)
    shadeb(v); v.outline(0)
    return v
def bat():
    v = Cv(32, 32)
    ell(v, 16, 15, 4.5, 6, 3)
    for s in (-1, 1):
        pts = [(16 + s * 3, 12), (16 + s * 15, 6), (16 + s * 14, 15), (16 + s * 11, 13), (16 + s * 9, 19), (16 + s * 6, 16), (16 + s * 4, 19)]
        v.poly(pts, 4)
    v.poly([(13, 10), (14, 6), (15, 10)], 3); v.poly([(17, 10), (18, 6), (19, 10)], 3)   # ears
    v.set(14, 13, 5); v.set(18, 13, 5)
    v.set(15, 18, 1); v.set(17, 18, 1)              # fangs
    shadeb(v); v.outline(0)
    return v
def goblin():
    v = Cv(32, 32)
    v.rect(11, 15, 20, 25, 6); v.rect(11, 22, 20, 25, 7)   # tunic
    ell(v, 15.5, 10, 6, 5.5, 3)                     # head
    v.poly([(9, 8), (2, 5), (9, 12)], 3); v.poly([(22, 8), (29, 5), (22, 12)], 3)   # ears
    v.set(13, 9, 5); v.set(18, 9, 5); v.rect(13, 13, 18, 13, 0); v.set(14, 14, 1); v.set(17, 14, 1)
    v.rect(12, 26, 14, 30, 3); v.rect(17, 26, 19, 30, 3)  # legs
    v.rect(8, 16, 10, 22, 3); v.rect(21, 16, 23, 21, 3)   # arms
    line(v, 23, 22, 28, 9, 7, 1.0); ell(v, 28, 8, 2.2, 2.2, 7)   # a club
    shadeb(v); v.outline(0)
    return v
def skeleton():
    v = Cv(32, 32)
    ell(v, 15.5, 7.5, 5, 5, 9); v.rect(13, 11, 18, 13, 9)   # skull, jaw
    v.rect(12, 6, 14, 8, 0); v.rect(17, 6, 19, 8, 0); v.set(13, 7, 5); v.set(18, 7, 5)
    for x in range(13, 19, 2): v.set(x, 12, 0)
    v.rect(15, 14, 16, 24, 9)                       # spine
    for y in (16, 18, 20): v.rect(11, y, 20, y, 9)  # ribs
    v.rect(12, 24, 19, 25, 9)                       # hips
    line(v, 13, 25, 11, 31, 9); line(v, 18, 25, 20, 31, 9)
    line(v, 11, 15, 7, 22, 9); line(v, 20, 15, 24, 22, 9)
    line(v, 24, 22, 29, 6, 8); v.rect(22, 20, 26, 20, 8)   # a sword
    v.outline(0)
    return v
def spider():
    v = Cv(32, 32)
    for s in (-1, 1):
        for k in range(4):
            a = -0.9 + k * 0.6
            x1, y1 = 16 + s * 9, 17 + a * 4
            x2, y2 = 16 + s * 15, 13 + k * 5
            line(v, 16 + s * 4, 18, x1, y1 - 4, 4, 0.7); line(v, x1, y1 - 4, x2, y2 + 4, 4, 0.7)
    ell(v, 16, 22, 7, 6, 3); ell(v, 16, 14, 5, 4, 3)
    for x in (13, 15, 17, 19): v.set(x, 13, 5)
    v.set(14, 18, 1); v.set(18, 18, 1)
    shadeb(v); v.outline(0)
    return v
def ogre():
    v = Cv(32, 32)
    ell(v, 16, 18, 11, 9, 3)                        # bulk
    ell(v, 16, 8, 6, 5.5, 3)                        # head
    v.set(13, 7, 5); v.set(18, 7, 5); v.rect(13, 11, 19, 11, 0)
    v.set(13, 12, 1); v.set(19, 12, 1)              # tusks
    v.rect(5, 15, 8, 26, 3); v.rect(24, 15, 27, 26, 3)   # arms
    ell(v, 6.5, 27, 2.5, 2.5, 3); ell(v, 25.5, 27, 2.5, 2.5, 3)
    v.rect(10, 22, 22, 25, 6)                       # a belt / loincloth
    v.rect(10, 26, 14, 31, 4); v.rect(18, 26, 22, 31, 4)
    shadeb(v); v.outline(0)
    return v
def ghost():
    v = Cv(32, 32)
    ell(v, 16, 12, 9, 9, 3)
    v.rect(7, 12, 25, 24, 3)
    for k in range(5):
        x = 7 + k * 4
        v.poly([(x, 24), (x + 4, 24), (x + 2, 29 + (k % 2) * 2)], 3)
    ell(v, 12.5, 11, 2, 2.8, 0); ell(v, 19.5, 11, 2, 2.8, 0); v.set(12, 11, 5); v.set(19, 11, 5)
    ell(v, 16, 18, 2.5, 3, 0)
    line(v, 7, 16, 1, 22, 3, 1.2); line(v, 25, 16, 31, 20, 3, 1.2)
    shadeb(v); v.outline(0)
    return v
def slime():
    v = Cv(32, 32)
    for y in range(32):
        for x in range(32):
            w = 13 - max(0, (14 - y)) * 0.9
            if 12 <= y <= 30 and abs(x + 0.5 - 16) <= w + math.sin(y * 0.7) * 1.2: v.set(x, y, 3)
    ell(v, 16, 12, 6, 4, 3)
    ell(v, 12, 18, 2.2, 2.6, 1); ell(v, 20, 18, 2.2, 2.6, 1); v.set(12, 18, 0); v.set(20, 18, 0)
    v.rect(13, 24, 19, 24, 4)
    for (x, y) in ((9, 14), (22, 22), (11, 27)): v.set(x, y, 1)
    shadeb(v); v.outline(0)
    return v
def demon():
    v = Cv(32, 32)
    for s in (-1, 1):
        v.poly([(16 + s * 5, 12), (16 + s * 15, 3), (16 + s * 15, 16), (16 + s * 11, 13), (16 + s * 9, 20)], 4)   # wings
    ell(v, 16, 18, 6, 7, 3)
    ell(v, 16, 9, 4.5, 4.5, 3)
    v.poly([(12, 7), (10, 1), (14, 6)], 9); v.poly([(20, 7), (22, 1), (18, 6)], 9)   # horns
    v.set(14, 9, 5); v.set(18, 9, 5); v.rect(14, 12, 18, 12, 0)
    v.rect(12, 25, 14, 31, 4); v.rect(18, 25, 20, 31, 4)
    line(v, 22, 20, 28, 30, 8); v.poly([(27, 30), (31, 27), (29, 31)], 8)   # a trident's end
    shadeb(v); v.outline(0)
    return v
def mummy():
    v = Cv(32, 32)
    ell(v, 16, 8, 5, 5.5, 3)
    v.rect(11, 13, 21, 25, 3)
    v.rect(4, 14, 11, 17, 3); v.rect(21, 14, 28, 17, 3)   # arms out
    v.rect(12, 26, 15, 31, 3); v.rect(17, 26, 20, 31, 3)
    for y in range(3, 31, 3):
        for x in range(32):
            if v.get(x, y) == 3 and (x + y) % 5: v.set(x, y, 4)
    v.rect(13, 7, 19, 8, 0); v.set(14, 7, 5); v.set(18, 7, 5)
    for (x, y) in ((28, 18), (29, 20), (22, 27)): v.set(x, y, 3)   # trailing wraps
    shadeb(v); v.outline(0)
    return v
def lich():
    v = Cv(32, 32)
    v.poly([(16, 9), (6, 31), (26, 31)], 6)         # robe
    v.poly([(16, 12), (11, 31), (21, 31)], 7)
    ell(v, 16, 8, 4.5, 5, 9); v.rect(13, 7, 15, 8, 0); v.rect(17, 7, 19, 8, 0); v.set(14, 7, 5); v.set(18, 7, 5)
    v.poly([(10, 4), (16, 0), (22, 4), (21, 6), (11, 6)], 11)   # a crown
    line(v, 26, 31, 27, 4, 8, 0.7); ell(v, 27, 4, 2.6, 2.6, 5); v.set(26, 3, 1)   # a staff with a gem
    v.rect(22, 14, 26, 15, 9)
    v.outline(0)
    return v
def dragon():
    v = Cv(32, 32)
    ell(v, 16, 14, 11, 9, 3)                        # the head
    v.poly([(8, 18), (24, 18), (22, 30), (10, 30)], 3)   # the jaw
    v.rect(10, 23, 22, 24, 0)                       # the mouth
    for x in range(11, 22, 2): v.set(x, 22, 1); v.set(x + 1, 25, 1)
    v.poly([(7, 8), (1, 0), (10, 6)], 9); v.poly([(25, 8), (31, 0), (22, 6)], 9)   # horns
    ell(v, 11, 13, 2.4, 2, 5); ell(v, 21, 13, 2.4, 2, 5); v.set(11, 13, 0); v.set(21, 13, 0)
    v.set(13, 19, 0); v.set(19, 19, 0)              # nostrils
    for (x, y) in ((6, 16), (26, 16), (5, 12), (27, 12)): v.poly([(x, y), (x + (2 if x < 16 else -2), y - 3), (x + (3 if x < 16 else -3), y + 1)], 4)
    v.rect(13, 27, 19, 29, 10); v.set(16, 30, 11)   # flame in the throat
    shadeb(v); v.outline(0)
    return v
MON = [('RAT', rat), ('BAT', bat), ('GOBLIN', goblin), ('SKELETON', skeleton), ('SPIDER', spider),
       ('OGRE', ogre), ('GHOST', ghost), ('SLIME', slime), ('DEMON', demon), ('MUMMY', mummy),
       ('LICH', lich), ('DRAGON', dragon)]
for k, (nm, fn) in enumerate(MON):
    place(fn(), (k % 8) * 2, (k // 8) * 2)
names.append('sprite MON      0 0 8 2 2 # the monsters (32 x 32): rat, bat, goblin, skeleton, spider, ogre, ghost, slime')
names.append('sprite MON2     0 2 4 2 2 # demon, mummy, lich, dragon (shape n is MON + n * 4)')

# ---------------------------------------------------------------- the heroes' faces (row 0)
# 2-4 skin, 6 purple, 8 steel, 9 cream, 10 red, 11 gold, 12 navy, 13 green, 14 brown
def hero(k):
    v = Cv(32, 32)
    v.poly([(3, 31), (7, 24), (25, 24), (29, 31)], [8, 12, 9, 6][k])          # shoulders
    ell(v, 16, 15, 7, 8.5, 3)                                                  # face
    v.set(13, 14, 0); v.set(19, 14, 0); v.rect(14, 19, 18, 19, 4)
    v.shade(3, 4, lambda x, y: x > 19)
    if k == 0:   # BRAN, the fighter: a steel helm, a red beard
        v.poly([(8, 13), (9, 5), (16, 2), (23, 5), (24, 13), (21, 11), (11, 11)], 8)
        v.rect(15, 3, 16, 13, 1)
        ell(v, 16, 21, 6, 4, 10); v.rect(14, 19, 18, 19, 4)
    elif k == 1: # KIRA, the ninja: a mask, dark hair
        v.poly([(8, 12), (10, 4), (16, 2), (22, 4), (24, 12)], 12)
        v.rect(9, 16, 23, 23, 12)
        v.set(13, 14, 0); v.set(19, 14, 0)
        line(v, 24, 6, 30, 2, 12, 0.6)
    elif k == 2: # OSWIN, the priest: a hood, white hair
        v.poly([(5, 26), (6, 9), (16, 2), (26, 9), (27, 26), (23, 24), (23, 10), (9, 10), (9, 24)], 9)
        v.rect(10, 9, 22, 10, 1)
        v.rect(15, 26, 16, 31, 11); v.rect(13, 28, 18, 28, 11)
    else:        # MAEVE, the wizard: a pointed hat, red hair
        v.poly([(4, 12), (28, 12), (20, 9), (16, 0), (12, 9)], 6)
        v.rect(8, 12, 9, 22, 10); v.rect(23, 12, 24, 22, 10)
        v.set(16, 4, 11)
    v.outline(0)
    return v
for k in range(4): place(hero(k), 8 + k * 2, 2)
names.append('sprite HERO     8 2 4 2 2 # the heroes: Bran, Kira, Oswin, Maeve')

# ---------------------------------------------------------------- things (16 x 16) and effects
def thing(k):
    v = Cv(16, 16)
    if k == 0:   # a chest
        v.rect(2, 6, 13, 13, 14); v.rect(2, 4, 13, 6, 4); v.rect(2, 8, 13, 8, 11); v.rect(7, 7, 8, 10, 11)
    elif k == 1: # a potion
        ell(v, 7.5, 10, 4.5, 4.5, 10); v.rect(6, 2, 9, 6, 1); v.rect(5, 1, 10, 2, 14); v.set(5, 8, 1)
    elif k == 2: # a key
        ell(v, 4.5, 7.5, 3, 3, 11); ell(v, 4.5, 7.5, 1.2, 1.2, None); v.rect(7, 7, 14, 8, 11); v.rect(12, 9, 12, 11, 11); v.rect(10, 9, 10, 10, 11)
    elif k == 3: # gold
        for (x, y) in ((4, 10), (8, 10), (12, 10), (6, 7), (10, 7), (8, 4)):
            ell(v, x, y, 2.4, 1.6, 11); v.set(x - 1, y - 1, 1)
    elif k == 4: # a slash
        for t in range(12): v.set(2 + t, 13 - t, 1); v.set(3 + t, 13 - t, 9); v.set(2 + t, 12 - t, 1)
    elif k == 5: # fire
        for y in range(16):
            for x in range(16):
                d = math.hypot((x - 7.5) * 1.2, y - 9)
                if d < 6 - (8 - y) * 0.3 and y > 2: v.set(x, y, 11 if d < 3 else 10)
    elif k == 6: # a healing sparkle
        v.rect(7, 2, 8, 13, 5); v.rect(2, 7, 13, 8, 5); v.set(7, 7, 1); v.set(8, 8, 1)
    elif k == 7: # lightning
        pts = [(9, 0), (4, 8), (8, 8), (5, 15), (12, 6), (8, 6), (11, 0)]
        v.poly(pts, 11); v.set(8, 5, 1)
    elif k == 8: # stairs down (the view's floor)
        for s in range(4): v.rect(2 + s, 4 + s * 3, 13 - s, 5 + s * 3, 14 - (s % 2) * 10)
    elif k == 9: # the pointer
        v.poly([(2, 2), (13, 8), (8, 9), (11, 14), (9, 15), (6, 10), (2, 13)], 1)
    if k not in (4, 6): v.outline(0)
    return v
for k in range(10): thing(k).into(S, k, 4)
names.append('sprite THING    0 4 4     # a chest, a potion, a key, gold')
names.append('sprite FX       4 4 4     # a slash, fire, a healing sparkle, lightning')
names.append('sprite STAIRS   8 4       # stairs down')
names.append('sprite POINT    9 4       # the pointer')
S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# DUNGEON - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# (the view is drawn on Layer 2 by the game)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
# sprite palettes (spr_pal.png rows): 0 the heroes and things, 1-9 the monsters' colour schemes
# (green, red, bone, brown, grey, purple, ghostly, gold, teal), 10 a hit flash
tile   PANEL    1
tile   FTL      2
tile   FT       3
tile   FTR      4
tile   FL       5
tile   FR       6
tile   FBL      7
tile   FB       8
tile   FBR      9
tile   BLACK    10
tile   KEY      11
tile   GOLD     12
tile   POTION   13
tile   BARH     112 9      # a red (HP) bar cell: 0-8 filled
tile   BARM     121 9      # a blue (MP) one
tile   MWALL    96        # the map: a wall
tile   MFLOOR   97        # a floor
tile   MYOU     98 4      # you, facing north, east, south, west
tile   MSTAIRS  102
tile   MDOOR    103
tile   MMON     104       # monsters
tile   MCHEST   105
tile   MDARK    106       # not seen yet

''' + '\n'.join(names) + '\n')
im = S.img.convert('RGB').resize((S.w * 3, S.h * 3), Image.NEAREST)
im.save(os.path.join(HERE, 'sprites_preview.png'))
# the monsters in their colours, for a look
pv = Image.new('RGB', (12 * 40, 3 * 40), (20, 20, 20))
def draw(vv, row, ox, oy):
    for y in range(32):
        for x in range(32):
            q = vv.p[y][x]
            if q is not None: pv.putpixel((ox + x, oy + y), ROWS[row][q])
for k, (nm, fn) in enumerate(MON):
    vv = fn()
    for j, row in enumerate((1, 2, 3)):
        draw(vv, row, k * 40 + 4, j * 40 + 4)
pv.resize((pv.width * 3, pv.height * 3), Image.NEAREST).save(os.path.join(HERE, 'monsters_preview.png'))
print('ok')
