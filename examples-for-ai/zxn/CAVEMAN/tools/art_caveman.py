# CAVEMAN ANTICS - the sprites and the tiles: writes ../gfx/*
# (run: python3 tools/art_caveman.py)   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# The tiles are drawn in colour numbers; the game gives each band of the scenery its own palette
# row, and each stage its own colours (Main: the stages' palettes):
#   row 0 (the panel, the font): see TP below
#   row 1 (far mountains 0-7, the jungle in the middle distance 8-14)
#   row 2 (the ground 0-6, bones 7-8, stones 9-10, puddles 11-12, plants 13-14)
# The sprites are drawn in one scheme (SP0 below) and recoloured by palette rows.
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
from cvkit import Cv

HERE = os.path.dirname(os.path.abspath(__file__))
D = os.path.join(HERE, '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# ---------------------------------------------------------------- tiles
TP = [c(0,0,0), c(7,7,3), c(4,4,2), c(2,2,1), c(2,6,0), c(0,3,0), c(7,1,0), c(3,0,0),
      c(7,7,0), c(7,4,0), c(4,2,0), c(1,2,3), c(6,5,2), c(2,1,0), c(5,0,3), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=0, paper=15, chars=range(32, 96))
K = {str(i) if i < 10 else 'abcde'[i - 10]: i for i in range(15)}
K['.'] = 15
T.put(1, 0, ['00000000'] * 8, K)                          # 1: the panel (black)
for k in range(9):                                        # 16-24: a bar, 0-8 filled
    rows = []
    for y in range(8):
        if y in (0, 7): rows.append('00000000')
        else: rows.append(''.join(('4' if y < 4 else '5') if x < k else '3' for x in range(8)))
    T.put((16 + k) % 16, (16 + k) // 16, rows, K)
T.put(2, 0, ['........', '..1111..', '.111111.', '.1.11.1.', '.111111.', '..1..1..', '..1111..', '........'], K)  # a life: a skull

rnd = random.Random(3)
tiles = {}
def tile(name, n, rows):
    tiles[name] = n
    T.put(n % 16, n // 16, rows, K)
def gen(f):
    return [''.join(f(x, y) for x in range(8)) for y in range(8)]
# ---- far mountains (row 1: 0 light .. 3 dark, 4 snow / highlight, 5-6 lava, 7 smoke)
def mfill(x, y, seed):
    r = random.Random(seed * 100 + y * 8 + x)
    v = 1 + (r.random() < 0.25) + (r.random() < 0.1)
    return str(min(3, v))
tile('MT_FILL', 96, gen(lambda x, y: mfill(x, y, 1)))
tile('MT_FILL2', 97, gen(lambda x, y: '2' if (x + y * 3) % 7 == 0 else mfill(x, y, 2)))
tile('MT_SL', 98, gen(lambda x, y: '.' if x + y < 7 else ('4' if x + y == 7 else mfill(x, y, 3))))       # rising to the right
tile('MT_SR', 99, gen(lambda x, y: '.' if (7 - x) + y < 7 else ('3' if (7 - x) + y == 7 else mfill(x, y, 4))))
tile('MT_TOP', 100, gen(lambda x, y: '.' if y < 3 else ('4' if y == 3 else mfill(x, y, 5))))
tile('MT_CRATER', 101, gen(lambda x, y: '.' if y < 2 else ('7' if y == 2 and x % 3 else ('5' if y < 5 and 1 < x < 6 else ('6' if y < 5 else mfill(x, y, 6))))))
tile('MT_SMOKE', 102, gen(lambda x, y: '7' if math.hypot(x - 3.5 - math.sin(y) * 1.2, y - 4) < 3 else '.'))
tile('MT_LAVA', 103, gen(lambda x, y: '5' if abs(x - 3.5 - math.sin(y * 0.9)) < 1.2 else mfill(x, y, 7)))
# ---- the jungle in the middle distance (row 1: 8 light .. 11 dark, 12 highlight, 13 trunks)
def cfill(x, y, seed):
    r = random.Random(seed * 77 + y * 8 + x)
    d = r.random()
    return '9' if d < 0.45 else 'a' if d < 0.8 else '8' if d < 0.92 else 'b'
for k in range(3):
    def top(x, y, k=k):
        h = 3 + 2 * math.sin((x + k * 3) * 0.9) + math.sin((x + k) * 2.1)
        if y < h: return '.'
        if y < h + 1: return 'c'
        return cfill(x, y, 10 + k)
    tile('CAN_TOP%d' % k, 104 + k, gen(top))
tile('CAN_FILL', 107, gen(lambda x, y: cfill(x, y, 20)))
tile('CAN_FILL2', 108, gen(lambda x, y: 'd' if x in (2, 3) and y > 2 else cfill(x, y, 21)))
tile('CAN_PALM', 109, gen(lambda x, y: 'c' if abs(y - 2 - abs(x - 3.5) * 0.6) < 0.8 else ('d' if x in (3, 4) and y > 2 else '.')))
# ---- the ground (row 2: 0 light .. 4 dark, 5-6 grass, 7-8 bone, 9-10 stone, 11-12 puddle, 13-14 plants)
def gfill(x, y, seed):
    r = random.Random(seed * 31 + y * 8 + x)
    d = r.random()
    return '2' if d < 0.55 else '1' if d < 0.75 else '3' if d < 0.95 else '0'
tile('GR_EDGE', 110, gen(lambda x, y: ('5' if y < 2 or (y < 4 and (x * 5 + y) % 3 == 0) else '6') if y < 4 else gfill(x, y, 1)))
tile('GR_EDGE2', 111, gen(lambda x, y: ('5' if (x % 3 == 1 and y < 3) else '6' if y < 3 else ('6' if (x + y) % 4 == 0 and y < 5 else gfill(x, y, 2))) if y < 5 else gfill(x, y, 2)))
tile('GR_FILL', 112, gen(lambda x, y: gfill(x, y, 3)))
tile('GR_FILL2', 113, gen(lambda x, y: gfill(x, y, 4)))
tile('GR_FILL3', 114, gen(lambda x, y: '3' if (x - y) % 8 == 0 else gfill(x, y, 5)))
tile('GR_ROCK', 115, gen(lambda x, y: ('9' if (x + y) < 6 else 'a') if math.hypot(x - 3.5, (y - 4.5) * 1.3) < 3.4 else ('4' if y == 7 and 1 < x < 7 else gfill(x, y, 6))))
tile('GR_SKULL', 116, ['22222222', '22777722', '27777772', '27877872', '27777772', '22787822', '22277222', '22222222'])
tile('GR_BONEL', 117, gen(lambda x, y: ('7' if y in (3, 4) and x > 2 else '7' if x < 3 and abs(y - 3.5) < 2.5 and math.hypot(x - 1.5, y - (2 if y < 4 else 5)) < 1.6 else ('8' if y == 5 and x > 2 else gfill(x, y, 7)))))
tile('GR_BONER', 118, gen(lambda x, y: ('7' if y in (3, 4) and x < 5 else '7' if x > 4 and math.hypot(x - 5.5, y - (2 if y < 4 else 5)) < 1.6 else ('8' if y == 5 and x < 5 else gfill(x, y, 8)))))
tile('GR_PUDL', 119, gen(lambda x, y: ('b' if y == 3 else 'c') if 2 < y < 7 and x > 1 else gfill(x, y, 9)))
tile('GR_PUDR', 120, gen(lambda x, y: ('b' if y == 3 else 'c') if 2 < y < 7 and x < 6 else gfill(x, y, 10)))
tile('GR_FERN', 121, gen(lambda x, y: 'd' if (abs(x - 3.5) < 0.6 + y * 0.45 and (x + y) % 2 == 0) else ('e' if abs(x - 3.5) < 0.5 + y * 0.45 else gfill(x, y, 11))))
tile('GR_STONES', 122, gen(lambda x, y: '9' if (x, y) in ((1, 2), (2, 2), (5, 5), (6, 5), (3, 6)) else 'a' if (x, y) in ((1, 3), (2, 3), (5, 6), (6, 6)) else gfill(x, y, 12)))
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprites
# 0 outline, 1 white, 2 skin, 3 skin dark, 4 fur light, 5 fur, 6 fur dark, 7 hair, 8 wood,
# 9 wood dark, 10 grey (bone, stone), 11 red, 12 spots, 13 dark spots, 14 yellow
SP0 = [c(0,0,0), c(7,7,3), c(7,5,2), c(5,3,1), c(7,5,0), c(5,3,0), c(3,1,0), c(1,0,0),
       c(6,4,1), c(3,2,1), c(4,4,2), c(7,1,0), c(4,2,0), c(2,2,1), c(7,7,0), MAGENTA]
def recol(**kw):
    p = SP0[:]
    for k, v in kw.items(): p[int(k[1:])] = v
    return p
FLASH = [c(7,7,3)] * 15 + [MAGENTA]
BOG = recol(i4=c(3,6,0), i5=c(1,4,0), i6=c(0,2,0), i7=c(2,1,0))                       # green furs
THUD = recol(i4=c(3,4,3), i5=c(1,2,3), i6=c(0,1,2), i7=c(6,1,0), i2=c(6,4,2))         # blue, red hair
ROCKY = recol(i4=c(6,3,3), i5=c(4,1,2), i6=c(2,0,1), i7=c(5,5,2))                      # purple, grey hair
RAPT = recol(i4=c(4,6,1), i5=c(2,4,0), i6=c(1,2,0), i12=c(5,3,0), i13=c(3,1,0), i2=c(6,6,2), i3=c(4,4,1))
RAPT2 = recol(i4=c(6,4,1), i5=c(4,2,0), i6=c(2,1,0), i12=c(1,2,0), i13=c(0,1,0), i2=c(7,6,2), i3=c(5,4,1))
PTERO = recol(i4=c(6,3,1), i5=c(4,2,1), i6=c(2,1,0), i2=c(7,5,2), i3=c(5,3,1), i12=c(7,2,0))
TRIKE = recol(i4=c(4,5,2), i5=c(2,3,1), i6=c(1,1,1), i2=c(6,6,2), i3=c(4,4,1), i12=c(6,2,0))
TREX = recol(i4=c(5,4,0), i5=c(3,3,0), i6=c(1,1,0), i2=c(6,6,2), i3=c(4,4,1), i12=c(4,1,0), i13=c(2,0,0))
BRONTO = recol(i4=c(3,5,3), i5=c(2,3,2), i6=c(1,1,1), i2=c(5,6,3), i3=c(3,4,2), i12=c(1,3,1))
OOLA = recol(i4=c(7,6,1), i5=c(6,4,0), i6=c(4,2,0), i7=c(7,6,0), i12=c(2,1,0))
BIGBOG = recol(i4=c(2,4,0), i5=c(1,2,0), i6=c(0,1,0), i7=c(0,0,0), i2=c(5,4,1), i3=c(3,2,1))
KING = recol(i4=c(7,2,0), i5=c(5,0,0), i6=c(3,0,0), i7=c(7,6,0), i8=c(7,6,0), i9=c(5,3,0))
PALS = [SP0, FLASH, BOG, THUD, ROCKY, RAPT, RAPT2, PTERO, TRIKE, TREX, BRONTO, OOLA, BIGBOG, KING]
palette_png(D + '/spr_pal.png', PALS)

S = Sheet(16, 9, SP0)
names = []
def cells(v, col, row):
    for j in range(v.h // 16):
        for i in range(v.w // 16):
            cv = Cv(16, 16)
            for y in range(16):
                for x in range(16): cv.p[y][x] = v.p[j * 16 + y][i * 16 + x]
            cv.into(S, col + i, row + j)
def ell(v, cx, cy, rx, ry, i):
    for y in range(v.h):
        for x in range(v.w):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1: v.set(x, y, i)
def limb(v, x0, y0, a, l, w0, w1, ci):
    # a tapering limb from x0, y0 at angle a (0 down, + forward), length l; returns its end
    n = int(l * 3) + 1
    for t in range(n + 1):
        f = t / n
        x = x0 + math.sin(a) * l * f; y = y0 + math.cos(a) * l * f
        w = w0 + (w1 - w0) * f
        ell(v, x, y, w / 2, w / 2, ci)
    return x0 + math.sin(a) * l, y0 + math.cos(a) * l
def shade_side(v, frm, to, cx):
    v.shade(frm, to, lambda x, y: x < cx)

# ---- a caveman: 32 x 48, facing right. A pose: lean, the legs (thigh, shin each), the arms
# (upper, fore each), the club's angle (or None: no club), crouch, the head's tilt
def caveman(lean=0.1, tf=0.2, sf=0.0, tb=-0.2, sb=0.1, uf=0.6, ff=1.6, ub=-0.3, fb=0.4, club=None, crouch=0, mouth=0, fist=False):
    v = Cv(32, 48)
    hx, hy = 14, 30 + crouch
    sx, sy = hx + math.sin(lean) * 12, hy - math.cos(lean) * 12
    # the back leg, the back arm
    kx, ky = limb(v, hx - 1, hy, tb, 8, 6, 5, 3)
    fx, fy = limb(v, kx, ky, sb, 8, 5, 4, 3)
    v.rect(fx - 2, fy - 1, fx + 3, fy + 1, 3)
    ex, ey = limb(v, sx - 2, sy + 1, ub, 7, 5, 4, 3)
    limb(v, ex, ey, fb, 6, 4, 4, 3)
    # the body: a fur tunic over one shoulder
    for t in range(13):
        f = t / 12
        x = hx + (sx - hx) * f; y = hy + (sy - hy) * f
        ell(v, x, y, 6 - f * 0.5, 2.5, 5)
    v.poly([(hx - 7, hy + 4), (hx + 7, hy + 4), (hx + 6, hy - 3), (hx - 6, hy - 3)], 5)
    for k in range(5):
        v.set(hx - 6 + k * 3, hy + 5, 6); v.set(hx - 5 + k * 3, hy + 4, 6)
    v.set(hx - 2, hy - 4, 12); v.set(hx + 3, hy - 1, 12); v.set(hx, hy + 1, 12); v.set(hx - 4, hy, 12)
    # the bare chest and shoulder
    ell(v, sx + 2, sy + 2, 3.5, 3, 2)
    # the front leg
    kx, ky = limb(v, hx + 1, hy + 1, tf, 8, 6.5, 5, 2)
    fx, fy = limb(v, kx, ky, sf, 8, 5, 4, 2)
    v.rect(fx - 2, fy - 1, fx + 3, fy + 1, 9)
    # the head: big jaw, a brow, bushy hair
    hdx, hdy = sx + 2 + math.sin(lean) * 4, sy - 5
    ell(v, hdx, hdy, 4.6, 5, 2)
    v.rect(hdx - 1, hdy + 2, hdx + 4, hdy + 4, 2)                 # the jaw
    v.rect(hdx + 1, hdy - 2, hdx + 4, hdy - 2, 7)                 # the brow
    v.set(hdx + 2, hdy - 1, 1); v.set(hdx + 3, hdy - 1, 0)        # the eye
    v.set(hdx + 4, hdy, 3)                                         # the nose
    if mouth: v.rect(hdx + 2, hdy + 2, hdx + 4, hdy + 3, 11); v.set(hdx + 3, hdy + 2, 1)
    else: v.rect(hdx + 2, hdy + 2, hdx + 4, hdy + 2, 3)
    for a in range(9):                                             # the hair
        an = -math.pi * 0.9 + a * 0.32
        ell(v, hdx - 1 + math.cos(an) * 4.2, hdy - 1 + math.sin(an) * 4.4, 2, 2, 7)
    ell(v, hdx - 4, hdy + 2, 2, 3, 7)
    # the front arm (and the club in its hand)
    ex, ey = limb(v, sx + 1, sy + 1, uf, 7, 5.5, 4.5, 2)
    wx, wy = limb(v, ex, ey, ff, 6, 4.5, 4, 2)
    ell(v, wx, wy, 2.4, 2.4, 3 if fist else 2)
    if club is not None:
        # the club: a handle from the fist, swelling to a knobbly end
        for t in range(16):
            f = t / 15
            x = wx + math.sin(club) * 15 * f; y = wy - math.cos(club) * 15 * f
            r = 1.2 + f * f * 2.6
            ell(v, x, y, r, r, 8 if f < 0.95 else 9)
        x = wx + math.sin(club) * 14; y = wy - math.cos(club) * 14
        v.set(x + 1, y - 1, 9); v.set(x - 2, y, 9)
        ell(v, wx, wy, 2.2, 2.2, 2)
    # shading: the skin's back edges darker
    q = [r[:] for r in v.p]
    for y in range(48):
        for x in range(32):
            p = v.p[y][x]
            if p in (2, 5, 8) and (v.get(x + 1, y) not in (p, None) or v.get(x, y + 1) is None):
                q[y][x] = p + 1
            elif p in (2, 4, 5) and (v.get(x - 1, y) is None or v.get(x, y - 1) is None) and p != 4:
                q[y][x] = 4 if p == 5 else 1 if False else p
    v.p = q
    v.outline(0)
    return v

POSES = [
    ('STAND',  dict(club=-0.5, uf=0.2, ff=-2.6)),
    ('WALK1',  dict(club=-0.6, uf=0.3, ff=-2.5, tf=0.5, sf=0.1, tb=-0.5, sb=0.2, ub=0.3, fb=0.8)),
    ('WALK2',  dict(club=-0.4, uf=0.1, ff=-2.7, tf=-0.3, sf=0.0, tb=0.3, sb=0.4, ub=-0.6, fb=0.0)),
    ('JAB',    dict(club=-1.2, uf=0.4, ff=-2.2, ub=1.6, fb=1.6, lean=0.25, tf=0.5, tb=-0.4, mouth=1, fist=True)),
    ('WINDUP', dict(club=-0.6, uf=-2.7, ff=-3.1, lean=-0.15, ub=-0.6, fb=0.3, tf=0.3, tb=-0.3)),
    ('SMASH',  dict(club=2.2, uf=1.5, ff=1.6, lean=0.45, ub=0.6, fb=1.2, tf=0.7, sf=-0.1, tb=-0.6, sb=0.3, crouch=2, mouth=1)),
    ('JUMP',   dict(club=-0.3, uf=-0.5, ff=-2.4, tf=1.5, sf=-0.6, tb=0.6, sb=-0.9, ub=-1.0, fb=-0.3, crouch=-2)),
    ('KICK',   dict(club=-0.9, uf=-0.6, ff=-2.3, tf=1.7, sf=1.6, tb=-0.4, sb=-0.6, lean=-0.3, ub=-1.6, fb=-1.0, mouth=1)),
]
for k, (n, p) in enumerate(POSES):
    cells(caveman(**p), k * 2, 0)
names.append('sprite MAN      0 0 8 2 3 # a caveman (32 x 48): stand, walk 1, 2, jab, wind up, smash, jump, kick')
cells(caveman(club=-1.8, uf=-0.6, ff=-1.4, lean=-0.4, tf=0.2, tb=-0.5, sb=0.3, ub=-1.3, fb=-0.6, mouth=1), 0, 3)
names.append('sprite HURT     0 3 1 2 3 # hit')
# ---- Oola: 32 x 48, waving
def oola():
    v = Cv(32, 48)
    hx, hy = 15, 31
    limb(v, hx - 2, hy, -0.1, 8, 4.5, 3.5, 3); limb(v, hx - 3, hy + 8, 0.05, 8, 3.5, 3, 3)
    limb(v, hx + 2, hy, 0.15, 8, 5, 3.5, 2); limb(v, hx + 3, hy + 8, -0.05, 8, 3.5, 3, 2)
    v.rect(hx - 6, hy + 15, hx - 2, hy + 16, 9); v.rect(hx + 1, hy + 15, hx + 5, hy + 16, 9)
    ell(v, hx, hy - 6, 4, 6, 2)                                  # the body
    v.poly([(hx - 6, hy + 5), (hx + 6, hy + 5), (hx + 4, hy - 2), (hx - 4, hy - 2)], 5)   # the skirt
    v.poly([(hx - 4, hy - 7), (hx + 4, hy - 7), (hx + 4, hy - 3), (hx - 4, hy - 3)], 5)   # the top
    for (x, y) in ((hx - 3, hy), (hx + 2, hy + 2), (hx - 1, hy + 3), (hx + 1, hy - 5), (hx - 2, hy - 6)): v.set(x, y, 12)
    limb(v, hx + 3, hy - 9, -2.6, 7, 3.5, 3, 2); limb(v, hx + 6, hy - 15, -3.0, 5, 3, 3, 2)   # waving
    limb(v, hx - 3, hy - 9, 0.3, 9, 3.5, 3, 3)
    ell(v, hx + 1, hy - 17, 4, 4.5, 2)                           # the head
    v.set(hx + 3, hy - 18, 0); v.rect(hx + 2, hy - 15, hx + 3, hy - 15, 11)
    for a in range(10):
        an = -math.pi + a * 0.35
        ell(v, hx + math.cos(an) * 4.5, hy - 18 + math.sin(an) * 4.5, 2.2, 2.2, 7)
    ell(v, hx - 4, hy - 13, 2, 5, 7)
    v.set(hx - 2, hy - 22, 1); v.set(hx - 1, hy - 23, 11)       # a flower in her hair
    v.outline(0)
    return v
cells(oola(), 2, 3)
names.append('sprite OOLA     2 3 1 2 3 # Oola (32 x 48)')

# ---- dinosaurs, facing right
def trex(f):
    v = Cv(48, 48)
    # the tail, the body, the legs, the little arms, the big head
    v.poly([(2, 20), (14, 18), (24, 22), (22, 30), (10, 26)], 5)
    ell(v, 24, 25, 11, 9, 5)
    ell(v, 25, 29, 8, 5, 2)                                      # the belly
    o = 3 if f else 0
    limb(v, 20, 30, -0.3 + o * 0.1, 10, 7, 5, 6); limb(v, 17 + o, 39, 0.2, 8, 5, 4, 6)
    v.rect(15 + o, 46, 23 + o, 47, 6)
    limb(v, 27, 30, 0.3 - o * 0.1, 10, 8, 6, 5); limb(v, 30 - o, 39, -0.1, 8, 6, 5, 5)
    v.rect(28 - o, 46, 36 - o, 47, 5)
    limb(v, 33, 27, 1.2, 4, 2.5, 2, 3); v.set(37, 29, 1)
    # the neck and head
    ell(v, 32, 17, 6, 7, 5)
    jaw = 6 if f else 1
    v.poly([(32, 6), (46, 7), (47, 13), (40, 14), (32, 16)], 5)          # the top of the head
    v.poly([(34, 14), (46, 14 + jaw), (44, 18 + jaw), (34, 19)], 5)      # the lower jaw
    if f:
        v.poly([(38, 14), (46, 14), (46, 15 + jaw), (38, 16)], 11)
        for x in range(38, 47, 2): v.set(x, 14, 1); v.set(x + 1, 13 + jaw, 1)
    else:
        for x in range(37, 46, 2): v.set(x, 14, 1)
    ell(v, 39, 9, 1.8, 1.8, 14); v.set(40, 9, 0)
    v.rect(36, 7, 41, 7, 6)
    for (x, y) in ((20, 19), (26, 18), (14, 21), (30, 20), (23, 22), (9, 22)): v.rect(x, y, x + 1, y, 13)
    v.shade(5, 4, lambda x, y: v.get(x, y - 1) is None or v.get(x, y - 2) is None)
    v.outline(0)
    return v
cells(trex(0), 4, 3); cells(trex(1), 7, 3)
names.append('sprite TREX     4 3 2 3 3 # the T-rex (48 x 48): walking, biting')
def bronto():
    v = Cv(48, 48)
    ell(v, 18, 32, 14, 8, 5)                                     # the body
    ell(v, 18, 36, 11, 4, 2)
    v.poly([(4, 30), (0, 38), (2, 39), (8, 34)], 5)               # the tail
    for (x, s) in ((8, 6), (13, 5), (23, 6), (28, 5)):           # the legs
        v.rect(x - 2, 36, x + 2, 46, s); v.rect(x - 3, 46, x + 3, 47, 6)
    for t in range(24):                                          # the long neck
        f = t / 23
        x = 28 + f * 14; y = 30 - math.sin(f * 1.6) * 24
        ell(v, x, y, 3.2 - f * 0.8, 3.2 - f * 0.8, 5)
    ell(v, 44, 7, 3.5, 3, 5)                                     # the head
    v.set(45, 6, 0); v.rect(45, 9, 47, 9, 3)
    for (x, y) in ((12, 28), (18, 26), (24, 28), (15, 31), (21, 30)): v.rect(x, y, x + 1, y, 12)
    v.shade(5, 4, lambda x, y: v.get(x, y - 1) is None)
    v.outline(0)
    return v
cells(bronto(), 10, 3)
names.append('sprite BRONTO   10 3 1 3 3 # Bronty (48 x 48): the ride home')
# a caveman knocked down: 48 x 32, lying on his back (head to the left)
def down():
    v = Cv(48, 32)
    ell(v, 22, 24, 11, 5, 5)
    for k in range(6): v.set(13 + k * 3, 28, 6)
    limb(v, 30, 25, 1.7, 9, 6, 5, 2); limb(v, 38, 25, 1.4, 8, 5, 4, 2)   # the legs
    v.rect(44, 21, 46, 26, 9)
    ell(v, 11, 23, 5, 4.5, 2)                                    # the head
    for a in range(7): ell(v, 7 + a * 0.3, 18 + a * 1.4, 2, 2, 7)
    v.set(12, 21, 0); v.set(13, 21, 0); v.rect(14, 24, 15, 25, 11)
    limb(v, 18, 21, -2.4, 7, 4.5, 4, 2)                          # an arm flung up
    for k in range(3): v.set(6 + k * 4, 12 - (k % 2) * 2, 14)    # stars
    v.outline(0)
    return v
cells(down(), 0, 6)
names.append('sprite DOWN     0 6 1 3 2 # knocked down (48 x 32)')
def raptor(f):
    v = Cv(32, 32)
    v.poly([(0, 12), (10, 13), (14, 17), (8, 18)], 5)            # the tail
    ell(v, 15, 17, 7, 5, 5); ell(v, 16, 19, 5, 3, 2)
    o = (0, 1, 2)[f]
    if f < 2:
        limb(v, 13, 20, (-0.6, 0.5)[f], 7, 4, 3, 6); limb(v, 17, 20, (0.6, -0.4)[f], 7, 4, 3, 5)
    else:
        limb(v, 13, 20, -0.3, 7, 4, 3, 6); limb(v, 17, 20, 0.2, 7, 4, 3, 5)
    for (x, y) in ((10, 27), (19, 27)) if f == 2 else ():
        pass
    limb(v, 20, 15, 1.0, 7, 4, 3, 5)                             # the neck
    jaw = 3 if f == 2 else 0
    v.poly([(24, 8), (31, 10), (31, 12), (24, 13)], 5)          # the head
    v.poly([(25, 12), (31, 12 + jaw), (30, 14 + jaw), (25, 14)], 5)
    if jaw: v.poly([(26, 12), (31, 12), (31, 13 + jaw), (26, 13)], 11)
    v.set(26, 9, 14); v.set(27, 9, 0)
    for (x, y) in ((12, 14), (16, 13), (19, 15), (8, 14)): v.set(x, y, 13)
    limb(v, 21, 17, 1.2, 4, 2, 1.5, 3)
    v.shade(5, 4, lambda x, y: v.get(x, y - 1) is None)
    v.outline(0)
    return v
for f in range(3): cells(raptor(f), 3 + f * 2, 6)
names.append('sprite RAPTOR   3 6 3 2 2 # a raptor (32 x 32): running 1, 2, biting')
def trike(f):
    v = Cv(48, 32)
    v.poly([(0, 14), (8, 13), (12, 18), (4, 19)], 5)
    ell(v, 20, 17, 13, 9, 5); ell(v, 20, 21, 10, 4, 2)
    o = 2 if f else 0
    for (x, s, d) in ((10, 6, o), (16, 5, -o), (26, 6, -o), (31, 5, o)):
        v.rect(x - 2 + d, 22, x + 2 + d, 30, s); v.rect(x - 3 + d, 30, x + 3 + d, 31, 6)
    v.poly([(30, 4), (38, 6), (40, 18), (32, 22)], 12)           # the frill
    for k in range(4): v.set(30 + k * 2, 4 + k, 13)
    ell(v, 40, 17, 6, 5, 5)                                      # the head
    v.poly([(44, 18), (47, 20), (44, 22)], 10)                   # the beak
    v.poly([(39, 12), (47, 6), (41, 14)], 1)                     # the horns
    v.poly([(36, 12), (44, 5), (38, 14)], 1)
    v.poly([(44, 15), (47, 13), (45, 17)], 1)
    v.set(41, 15, 14); v.set(42, 15, 0)
    for (x, y) in ((14, 12), (20, 11), (25, 13), (17, 15)): v.rect(x, y, x + 1, y, 13)
    v.shade(5, 4, lambda x, y: v.get(x, y - 1) is None)
    v.outline(0)
    return v
cells(trike(0), 9, 6); cells(trike(1), 12, 6)
names.append('sprite TRIKE    9 6 2 3 2 # the triceratops (48 x 32): walking')
v = Cv(16, 16); ell(v, 8, 12, 7, 2.5, 0); v.into(S, 15, 6)
names.append('sprite SHADOW   15 6      # a shadow (palette: drawn in black)')
v = Cv(16, 16)
for k in range(8):
    a = k * math.pi / 4
    for t in range(1, 7 if k % 2 == 0 else 4): v.set(7.5 + math.cos(a) * t, 7.5 + math.sin(a) * t, 1 if t < 3 else 14)
v.into(S, 15, 7)
names.append('sprite SPARK    15 7      # a hit')
def ptero(f):
    v = Cv(32, 16)
    ell(v, 15, 9, 6, 2.5, 5)
    up = f == 0
    v.poly([(10, 8), (0, 2 if up else 13), (6, 6 if up else 12), (20, 8)], 4)
    v.poly([(12, 9), (22, 1 if up else 15), (26, 3 if up else 13), (20, 9)], 6)
    v.poly([(20, 7), (27, 6), (31, 9), (27, 10), (20, 10)], 5)   # the head and beak
    v.poly([(21, 6), (18, 2), (23, 6)], 12)                      # the crest
    v.set(25, 7, 14)
    v.outline(0)
    return v
cells(ptero(0), 0, 8); cells(ptero(1), 2, 8)
names.append('sprite PTERO    0 8 2 2 1 # a pterodactyl (32 x 16): wings up, down')
v = Cv(16, 16)
for k in range(6): ell(v, 4 + k * 1.6, 11 - abs(k - 2.5), 2.4, 2, 10 if k % 2 else 1)
v.into(S, 4, 8)
names.append('sprite DUST     4 8       # dust')
v = Cv(16, 16)                                                   # meat on the bone
ell(v, 9, 7, 5, 4.2, 11); ell(v, 8, 6, 3, 2, 12); v.rect(2, 9, 6, 10, 1); ell(v, 2, 9, 1.5, 1.5, 1); ell(v, 2, 11, 1.5, 1.5, 1)
v.outline(0); v.into(S, 5, 8)
names.append('sprite MEAT     5 8       # meat (life back)')
v = Cv(16, 16); ell(v, 8, 8, 4, 3.5, 10); v.set(6, 6, 1); v.rect(9, 9, 10, 10, 13); v.outline(0); v.into(S, 6, 8)
names.append('sprite ROCK     6 8       # a thrown rock')
v = Cv(16, 16); v.poly([(1, 5), (9, 5), (9, 1), (15, 8), (9, 15), (9, 11), (1, 11)], 14); v.outline(0); v.into(S, 7, 8)
names.append('sprite ARROW    7 8       # GO this way')
v = Cv(16, 16); ell(v, 5, 6, 3.5, 3.5, 11); ell(v, 11, 6, 3.5, 3.5, 11); v.poly([(1.5, 7), (14.5, 7), (8, 14)], 11); v.set(4, 5, 1); v.outline(0); v.into(S, 8, 8)
names.append('sprite HEART    8 8       # a heart')
S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# CAVEMAN ANTICS - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
# sprite palettes (spr_pal.png rows): 0 Grog, 1 a hit flash, 2 Bog, 3 Thud, 4 Rocky (the cavemen),
# 5-6 raptors, 7 pterodactyls, 8 the triceratops, 9 the T-rex, 10 Bronty, 11 Oola, 12 Big Bog,
# 13 King Thud
tile   PANEL    1
tile   LIFE     2
tile   BAR      16 9      # 0-8 filled
''' + '\n'.join('tile   %-8s %d' % (k, v) for k, v in tiles.items()) + '\n\n' + '\n'.join(names) + '\n')
print('ok', len(tiles))
