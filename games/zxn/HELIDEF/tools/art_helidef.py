# HELI ATTACK - the sprites and the tiles: writes ../gfx/* (the landscape: scene.py)
# (run: python3 tools/art_helidef.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
from cvkit import Cv

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# ---------------------------------------------------------------- tiles
# 0 black, 1 white, 2 the HUD, 3 its line, 4 the scanner, 5 its edge, 6 its ground, 7 red (UFO
# dots), 8 green (people), 9 yellow, 10 cyan, 11 orange, 12-13 spare, 14 the font's shadow
TP = [c(0,0,0), c(7,7,3), c(0,0,1), c(1,3,3), c(0,0,0), c(1,4,3), c(1,4,1), c(7,1,0),
      c(2,7,0), c(7,7,0), c(2,7,3), c(7,4,0), c(4,4,2), c(2,2,1), c(0,0,0), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=14, paper=2, chars=range(32, 96))
K = {('%x' % i): i for i in range(16)}; K['.'] = 15
def tile(n, rows): T.put(n % 16, n // 16, rows, K)
tile(1, ['22222222'] * 8)                                                   # HUD
tile(2, ['44444444'] * 8)                                                   # the scanner
tile(3, ['55555555'] + ['44444444'] * 7)                                    # its top edge
tile(4, ['44444444'] * 6 + ['66666666', '55555555'])                        # its bottom (the ground)
tile(5, ['22222222', '22222222', '22922222', '29992222', '29999992', '22222922', '22222222', '22222222'])  # a heli left
tile(6, ['22222222', '22777222', '27777722', '27777722', '27777722', '22777222', '22222222', '22222222'])  # a smart bomb
tile(7, ['00000000'] * 8)
# scanner dots: 96 + colour * 12 + row * 4 + across (2 x 2 pixels); colours: UFO, person, you
for ci, col_ in enumerate(('7', '8', '1')):
    for sy in range(3):
        for sx in range(4):
            rows = []
            for y in range(8):
                rows.append(''.join(col_ if (sx * 2 <= x < sx * 2 + 2 and 1 + sy * 2 <= y < 3 + sy * 2) else '4' for x in range(8)))
            if sy == 2: rows[6] = ''.join('6' if ch == '4' else ch for ch in rows[6])
            tile(96 + ci * 12 + sy * 4 + sx, rows)
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprites
# 0 outline, 1 white, 2 light grey, 3 grey, 4 dark grey, 5 olive light, 6 olive, 7 cyan glass,
# 8 red, 9 yellow, 10 green, 11 orange, 12 purple, 13 skin, 14 blue
SP0 = [c(0,0,0), c(7,7,3), c(5,5,2), c(3,3,2), c(1,1,1), c(4,5,1), c(2,3,0), c(3,7,3),
       c(7,1,0), c(7,7,0), c(2,7,0), c(7,4,0), c(5,1,3), c(7,5,2), c(1,2,3), MAGENTA]
FLASH = [c(7,7,3)] * 15 + [MAGENTA]
PINKB = [c(0,0,0), c(7,7,3)] + [c(7,2,3)] * 13 + [MAGENTA]        # bullets in pink
BLUEB = [c(0,0,0), c(7,7,3)] + [c(2,4,3)] * 13 + [MAGENTA]        # bullets in blue
MUT = [SP0[0], SP0[1], c(2,7,1), c(1,5,0), c(0,3,0)] + SP0[5:]    # a mutant's greys turned green
palette_png(D + '/spr_pal.png', [SP0, FLASH, PINKB, BLUEB, MUT])
S = Sheet(16, 3, SP0)
names = []
def ell(v, cx, cy, rx, ry, i):
    for y in range(v.h):
        for x in range(v.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1: v.set(x, y, i)
def put2(v, col, row):
    for i in range(v.w // 16):
        cv = Cv(16, 16)
        for y in range(16):
            for x in range(16): cv.p[y][x] = v.p[y][i * 16 + x]
        cv.into(S, col + i, row)

# ---- the helicopter: 32 x 16 facing right, 2 frames (the rotors)
def heli(f):
    v = Cv(32, 16)
    v.rect(2, 7, 14, 8, 6)                        # the tail boom
    v.rect(0, 4, 3, 9, 6)                         # the fin
    if f == 0: v.rect(0, 3, 0, 11, 2)              # the tail rotor
    else: v.rect(1, 2, 2, 2, 2); v.rect(1, 11, 2, 11, 2)
    ell(v, 20, 8.5, 9, 4.5, 6)                    # the body
    v.shade(6, 5, lambda x, y: y <= 6)
    v.poly([(22, 5), (29, 8), (29, 9), (22, 9)], 7)   # the cockpit glass
    v.set(24, 6, 1)
    v.rect(26, 10, 31, 11, 4); v.set(31, 10, 9)    # the gun
    v.rect(13, 14, 26, 14, 3); v.set(15, 13, 3); v.set(24, 13, 3)   # the skids
    v.rect(19, 2, 20, 3, 4)                        # the mast
    if f == 0: v.rect(6, 1, 31, 1, 2)              # the main rotor: long, then short (it spins)
    else: v.rect(14, 1, 25, 1, 2); v.set(13, 1, 3); v.set(26, 1, 3)
    v.outline(0)
    return v
put2(heli(0), 0, 0); put2(heli(1), 2, 0)
names.append('sprite HELI     0 0 2 2 1 # you: 32 x 16 facing right (mirrored for left), the rotors in two frames')
v = Cv(16, 16); v.rect(0, 7, 15, 8, 9); v.rect(8, 7, 15, 8, 1); v.into(S, 4, 0)
names.append('sprite SHOT     4 0       # your tracer')
# ---- the UFOs (16 x 16)
def lander(f):
    v = Cv(16, 16)
    ell(v, 7.5, 6, 3.5, 3, 7); v.set(6, 5, 1)          # the dome
    ell(v, 7.5, 9, 7.5, 2.6, 3); v.rect(1, 9, 14, 9, 2)
    for k, x in enumerate((3, 7, 11)): v.set(x + (k % 2) * 0 + (1 if f else 0), 10, 10 if (k + f) % 2 else 9)
    v.rect(4, 12, 5, 14, 4); v.rect(10, 12, 11, 14, 4)  # legs
    v.outline(0)
    return v
def mutant(f):
    v = Cv(16, 16)
    ell(v, 7.5, 8, 6.5, 5.5, 3); ell(v, 7.5, 7, 4.5, 3.5, 2)
    v.set(5, 6, 8); v.set(10, 6, 8)
    for x in range(2, 14, 3): v.set(x + f, 13 + (x % 2), 3)
    v.outline(0)
    return v
def bomber(f):
    v = Cv(16, 16)
    v.poly([(1, 13), (14, 13), (7.5, 2)], 12); v.poly([(4, 12), (11, 12), (7.5, 5)], 0 if f else 8)
    v.outline(0)
    return v
def pod(f):
    v = Cv(16, 16)
    for a in range(8):
        t = a * math.pi / 4 + (0.3 if f else 0)
        v.rect(7.5 + math.cos(t) * 6 - 0.5, 7.5 + math.sin(t) * 6 - 0.5, 7.5 + math.cos(t) * 6 + 0.5, 7.5 + math.sin(t) * 6 + 0.5, 11)
    ell(v, 7.5, 7.5, 4.5, 4.5, 8); ell(v, 6.5, 6.5, 1.6, 1.6, 9)
    v.outline(0)
    return v
def swarmer(f):
    v = Cv(16, 16)
    v.poly([(3, 8), (12, 5), (12, 11)], 11); v.set(11, 8, 9 if f else 8)
    v.outline(0)
    return v
def baiter(f):
    v = Cv(16, 16)
    ell(v, 7.5, 8, 7.5, 2.4, 4); v.rect(1, 8, 14, 8, 3)
    for x in range(2, 14, 3): v.set(x + f, 8, 8)
    ell(v, 7.5, 6, 3, 1.6, 7)
    v.outline(0)
    return v
for k, fn in enumerate((lander, mutant, bomber, pod, swarmer, baiter)):
    fn(0).into(S, k * 2, 1); fn(1).into(S, k * 2 + 1, 1)
names.append('sprite LANDER   0 1 2     # takes people up; at the top they turn into mutants')
names.append('sprite MUTANT   2 1 2     # fast, mad, shoots')
names.append('sprite BOMBER   4 1 2     # drifts, drops mines')
names.append('sprite POD      6 1 2     # bursts into swarmers when shot')
names.append('sprite SWARMER  8 1 2     # small and fast')
names.append('sprite BAITER   10 1 2    # turns up when you take too long')
# ---- people, the tractor beam, mines, bullets, bangs (row 2)
def person(f):
    v = Cv(16, 16)
    ell(v, 7.5, 4, 2, 2, 13); v.rect(6, 1, 9, 2, 4)
    v.rect(6, 6, 9, 10, 14)
    if f == 2:   # arms up (being carried / falling)
        v.rect(4, 3, 5, 7, 13); v.rect(10, 3, 11, 7, 13)
        v.rect(6, 11, 7, 14, 4); v.rect(8, 11, 9, 14, 4)
    else:
        v.rect(5, 7, 5, 9, 13); v.rect(10, 7, 10, 9, 13)
        if f: v.rect(6, 11, 7, 15, 4); v.rect(8, 11, 9, 14, 4)
        else: v.rect(6, 11, 7, 14, 4); v.rect(8, 11, 9, 15, 4)
    v.outline(0)
    return v
for f in range(3): person(f).into(S, f, 2)
names.append('sprite PERSON   0 2 3     # someone on the ground: walking x2, arms up')
v = Cv(16, 16)
for y in range(0, 16, 2):
    for x in range(3 + (y % 4) // 2, 13, 2): v.set(x, y, 10)
v.into(S, 3, 2)
names.append('sprite BEAM     3 2       # a lander\'s pull')
v = Cv(16, 16)
for k in range(-3, 4): v.set(7 + k, 7 + k, 8); v.set(7 + k, 7 - k, 8)
v.set(7, 7, 9); v.into(S, 4, 2)
names.append('sprite MINE     4 2       # a bomber\'s mine')
v = Cv(16, 16); ell(v, 7.5, 7.5, 2.4, 2.4, 2); ell(v, 7.5, 7.5, 1.2, 1.2, 1); v.outline(0); v.into(S, 5, 2)
v = Cv(16, 16); ell(v, 7.5, 7.5, 3.6, 3.6, 2); ell(v, 7, 7, 1.8, 1.8, 1); v.outline(0); v.into(S, 6, 2)
names.append('sprite BULLET   5 2 2     # small, big (pink: palette 2, blue: 3)')
random.seed(5)
for f in range(4):
    v = Cv(16, 16)
    r = 2.5 + f * 1.7
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, y - 7.5) + random.uniform(-1.2, 1.2)
            if f == 3:
                if r - 2.5 < d < r: v.set(x, y, 3 if random.random() < 0.6 else 4)
            elif d < r * 0.35: v.set(x, y, 1)
            elif d < r * 0.65: v.set(x, y, 9)
            elif d < r * 0.9: v.set(x, y, 11)
            elif d < r: v.set(x, y, 8)
    v.into(S, 7 + f, 2)
names.append('sprite BOOM     7 2 4     # an explosion')
v = Cv(16, 16)
for y in range(16): v.set(0, y, 9); v.set(15, y, 9)
v.set(1, 0, 9); v.set(14, 0, 9); v.set(1, 15, 9); v.set(14, 15, 9)
v.into(S, 11, 2)
names.append('sprite WINDOW   11 2      # the scanner: what\'s on screen (drawn 2x across, 1.5 high)')
v = Cv(16, 16)
for k, (x, y) in enumerate(((2, 2), (6, 1), (10, 3), (13, 6), (3, 9), (8, 12))): v.set(x, y, 9 if k % 2 else 1)
v.into(S, 12, 2)
names.append('sprite STARS    12 2      # a hyperspace twinkle')
S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# HELI ATTACK - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# (the landscape is Layer 2: tools/scene.py)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
# sprite palettes (spr_pal.png rows): 0 everything, 1 a hit flash, 2 pink bullets, 3 blue bullets,
# 4 a mutant (a lander's greys turned green)
tile   HUD      1
tile   SCAN     2         # the scanner
tile   SCANT    3         # its top edge
tile   SCANG    4         # its bottom row, the ground along it
tile   LIFE     5         # a helicopter left
tile   SMART    6         # a smart bomb left
tile   BLACK    7
tile   DOT      96 36     # scanner dots: 96 + colour (0 UFO, 1 person, 2 you) * 12 + row * 4 + across

''' + '\n'.join(names) + '\n')
im = S.img.convert('RGB').resize((S.w * 3, S.h * 3), Image.NEAREST)
im.save(os.path.join(HERE, 'sprites_preview.png'))
print('ok')
