# ESCORT - the sprites and tiles: writes ../gfx/* (run: python3 tools/art_escort.py)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# Every roadside thing is drawn three times, at 1/2, 3/4 and full size, standing on the bottom of
# its 16 x 16 cell; the game shows them at 1x, 2x or 4x for 8, 12, 16, 24, 32, 48 and 64 pixels.
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from artkit import *
from cvkit import Cv

D = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'gfx')
os.makedirs(D, exist_ok=True)
def c(r, g, b): return (r * 255 // 7, g * 255 // 7, b * 255 // 3)

# ---------------------------------------------------------------- tiles: the font and the HUD
TP = [c(0,0,0), c(7,7,3), c(5,5,2), c(2,2,1), c(1,0,1), c(7,1,0), c(7,6,0), c(1,5,0),
      c(0,0,0), c(0,0,0), c(0,0,0), c(0,0,0), c(0,0,0), c(0,0,0), c(0,0,0), MAGENTA]
palette_png(D + '/tile_pal.png', [TP])
T = Sheet(8, 16, TP)
font_into(T, 1, shadow=0, paper=4)
K = {'k': 0, 'w': 1, 'l': 2, 'g': 3, 'N': 4, 'r': 5, 'y': 6, 'e': 7}
T.put(1, 0, ['NNNNNNNN'] * 8, K)                                    # the HUD
for k in range(9):                                                  # the damage bar: 0-8 filled
    rows = []
    for y in range(8):
        if y in (0, 7): rows.append('NNNNNNNN')
        else: rows.append(''.join(('r' if k > 0 else 'g') if x < k else 'g' for x in range(8)))
    T.put(2 + k, 0, rows, K)
T.save(D + '/tiles.png')

# ---------------------------------------------------------------- sprite palettes
# 0 black, 1 white, 2 light grey, 3 grey, 4 dark grey, 5 brown, 6 dark brown, 7 green,
# 8 dark green, 9 the car's colour, 10 its shade, 11 yellow, 12 skin, 13 blonde, 14 pink
P0 = [c(0,0,0), c(7,7,3), c(5,5,2), c(3,3,2), c(2,2,1), c(5,3,0), c(3,1,0), c(2,6,0),
      c(1,3,0), c(7,0,0), c(4,0,0), c(7,7,0), c(7,5,2), c(7,6,1), c(7,2,2), MAGENTA]
def car(col, shade):
    p = P0[:]; p[9] = col; p[10] = shade; return p
P1 = car(c(1,3,3), c(0,1,2))        # blue
P2 = car(c(6,6,3), c(4,4,2))        # white
P3 = car(c(7,6,0), c(5,4,0))        # yellow (a cab)
P4 = car(c(1,1,1), c(0,0,0))        # black: THEM
FL = [c(0,0,0)] + [c(7,7,3)] * 14 + [MAGENTA]
palette_png(D + '/spr_pal.png', [P0, P1, P2, P3, P4, FL])

S = Sheet(16, 6, P0)
names = []
col = [0]
row = [0]
def cell(v):
    v.into(S, col[0], row[0])
    col[0] += 1
    if col[0] == 16: col[0] = 0; row[0] += 1

def sized(draw, k):
    # draw(v, X, Y): X(u) and Y(w) map the full-size design's 16 x 16 (bottom at 16) to this size
    v = Cv(16, 16)
    X = lambda u: 8 + (u - 8) * k
    Y = lambda w: 16 - (16 - w) * k
    draw(v, X, Y, k)
    v.outline(0)
    return v

def room(n):
    if col[0] + n > 16: col[0] = 0; row[0] += 1

def three(name, draw, note):
    room(3)
    names.append('sprite %-8s %d %d 3     # %s: 1/2, 3/4, full size' % (name, col[0], row[0], note))
    for k in (0.5, 0.75, 1.0):
        cell(sized(draw, k))

def P(v, X, Y, pts, i):
    v.poly([(X(x), Y(y)) for (x, y) in pts], i)
def R(v, X, Y, x0, y0, x1, y1, i):
    v.poly([(X(x0), Y(y0)), (X(x1), Y(y0)), (X(x1), Y(y1)), (X(x0), Y(y1))], i)
def C(v, X, Y, k, cx, cy, r, i):
    v.circle(X(cx), Y(cy), max(0.6, r * k), i)

def palm(v, X, Y, k):
    for t in range(12):                      # the trunk, leaning
        f = t / 11
        cx = 8 + 1.5 * math.sin(f * 2.2)
        R(v, X, Y, cx - 1, 16 - f * 11, cx + 0.9, 16 - f * 11 + 1.2, 5 if t % 3 else 6)
    for a in (-2.6, -2.0, -1.2, -0.5, 0.2, 0.9, 1.6):   # the fronds
        pts = [(9.5, 5), (9.5 + 6.5 * math.cos(a - math.pi / 2), 5 + 4.5 * math.sin(a - math.pi / 2) + 2.5),
               (9.5 + 6 * math.cos(a - math.pi / 2) + 0.8, 5 + 4 * math.sin(a - math.pi / 2) + 3.8)]
        P(v, X, Y, pts, 7 if a < 0.5 else 8)
    C(v, X, Y, k, 9.5, 5.5, 1.2, 6)
def bush(v, X, Y, k):
    for (x, y, r, i) in ((5, 13, 4, 8), (11, 13, 4, 8), (8, 11, 4.5, 7), (5.5, 12, 2.5, 7), (10.5, 12, 2.5, 7)):
        C(v, X, Y, k, x, y, r, i)
def pine(v, X, Y, k):
    R(v, X, Y, 7, 13, 9, 16, 6)
    P(v, X, Y, [(8, 0), (13, 14), (3, 14)], 8)
    P(v, X, Y, [(8, 1), (10.5, 9), (5.5, 9)], 7)
def sign(left):
    def d(v, X, Y, k):
        R(v, X, Y, 7, 9, 9, 16, 4)
        R(v, X, Y, 1, 1, 15, 10, 11)
        if left: P(v, X, Y, [(3, 5.5), (7, 2.5), (7, 4.5), (13, 4.5), (13, 6.5), (7, 6.5), (7, 8.5)], 0)
        else: P(v, X, Y, [(13, 5.5), (9, 2.5), (9, 4.5), (3, 4.5), (3, 6.5), (9, 6.5), (9, 8.5)], 0)
    return d
def gore(v, X, Y, k):
    R(v, X, Y, 2, 11, 3, 16, 4); R(v, X, Y, 13, 11, 14, 16, 4)
    R(v, X, Y, 0, 5, 16, 11, 11)
    for x in (-2, 3, 8, 13):
        P(v, X, Y, [(x, 5), (x + 2.5, 5), (x + 5, 8), (x + 2.5, 11), (x, 11), (x + 2.5, 8)], 0)
    R(v, X, Y, -4, 0, -1, 4, 15)
def carback(v, X, Y, k):
    R(v, X, Y, 0, 9, 16, 14, 9)              # the body
    P(v, X, Y, [(2, 9), (4, 5), (12, 5), (14, 9)], 10)   # the roof and back window
    P(v, X, Y, [(4, 9), (5, 6), (11, 6), (12, 9)], 3)
    R(v, X, Y, 1, 10, 3, 11.5, 14); R(v, X, Y, 13, 10, 15, 11.5, 14)   # the lights
    R(v, X, Y, 6, 11.5, 10, 12.5, 1)         # the number plate
    R(v, X, Y, 1, 14, 4, 16, 0); R(v, X, Y, 12, 14, 15, 16, 0)        # the tyres
def truck(v, X, Y, k):
    R(v, X, Y, 0, 1, 16, 13, 2)
    R(v, X, Y, 0, 1, 16, 2, 3)
    R(v, X, Y, 7.5, 2, 8.5, 13, 3)
    R(v, X, Y, 0, 13, 16, 14, 4)
    R(v, X, Y, 1, 11, 2.5, 12.5, 14); R(v, X, Y, 13.5, 11, 15, 12.5, 14)
    R(v, X, Y, 1, 14, 5, 16, 0); R(v, X, Y, 11, 14, 15, 16, 0)
def oil(v, X, Y, k):
    for (x, y, r) in ((5, 14, 3.2), (10, 14.3, 3.5), (8, 13.5, 2.5), (13, 14.6, 2)):
        v.circle(X(x), Y(y), max(0.7, r * k), 0)
    C(v, X, Y, k, 6, 13.5, 0.8, 4)
def log(v, X, Y, k):
    R(v, X, Y, 1, 11, 15, 16, 5)
    R(v, X, Y, 1, 11, 15, 12, 6)
    C(v, X, Y, k, 1.5, 13.5, 2.5, 6); C(v, X, Y, k, 1.5, 13.5, 1.2, 5)
    C(v, X, Y, k, 14.5, 13.5, 2.5, 6); C(v, X, Y, k, 14.5, 13.5, 1.2, 5)
def dest(v, X, Y, k):
    R(v, X, Y, 3, 0, 4, 16, 2)
    for j in range(3):
        for i in range(4):
            R(v, X, Y, 4 + i * 2.5, 1 + j * 2, 6.5 + i * 2.5, 3 + j * 2, 1 if (i + j) % 2 else 0)
def puff(v, X, Y, k):
    for (x, y, r, i) in ((5, 11, 4, 3), (11, 11, 4, 3), (8, 8, 4.5, 2), (8, 12, 3.5, 2)):
        C(v, X, Y, k, x, y, r, i)
def missile(v, X, Y, k):
    C(v, X, Y, k, 8, 12, 2.6, 3)
    C(v, X, Y, k, 8, 12, 1.6, 11)
    C(v, X, Y, k, 8, 12, 0.8, 1)
    R(v, X, Y, 4, 11.5, 12, 12.5, 4)
def girl(wave):
    def d(v, X, Y, k):
        R(v, X, Y, 6.5, 11, 7.5, 16, 12); R(v, X, Y, 8.5, 11, 9.5, 16, 12)   # legs
        P(v, X, Y, [(6, 5), (10, 5), (11.5, 12), (4.5, 12)], 14)             # the dress
        R(v, X, Y, 7.5, 4, 8.5, 5, 12)                                          # neck
        C(v, X, Y, k, 8, 2.6, 2.0, 12)                                          # head
        P(v, X, Y, [(5.8, 1), (10.2, 1), (10.6, 6), (9.5, 4), (6.5, 4), (5.4, 6)], 13)   # hair
        if wave: P(v, X, Y, [(10, 5.5), (13.5, 0.5), (14.5, 1), (11, 6.5)], 12)  # an arm up
        else: P(v, X, Y, [(10, 5.5), (11.5, 10), (10.5, 10), (9.5, 6.5)], 12)
        P(v, X, Y, [(6, 5.5), (4.5, 10), (5.5, 10), (6.5, 6.5)], 12)
    return d

three('PALM', palm, 'a palm')
three('BUSH', bush, 'a bush')
three('PINE', pine, 'a cypress')
three('SIGNL', sign(True), 'a sign: keep left')
three('SIGNR', sign(False), 'a sign: keep right')
three('GORE', gore, 'the barrier between two roads')
three('CAR', carback, 'a car from behind (palette 1-4: blue, white, cab, black)')
three('TRUCK', truck, 'a truck from behind')
three('OIL', oil, 'an oil slick')
three('LOG', log, 'a log')
three('DEST', dest, 'the drop-off flag')
three('PUFF', puff, 'smoke')
three('MISSILE', missile, 'a missile, going away')
room(6)
names.append('sprite GIRL     %d %d 6     # her: 1/2, 3/4, full size, then the same waving' % (col[0], row[0]))
for wave in (0, 1):
    for k in (0.5, 0.75, 1.0):
        cell(sized(girl(wave), k))

# ---- an explosion and a tracer
room(4)
names.append('sprite BOOM     %d %d 4     # an explosion' % (col[0], row[0]))
for f in range(4):
    v = Cv(16, 16)
    r = 3 + f * 1.5
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - 7.5, (y - 9) * 1.2) + (((x * 7 + y * 13) % 5) - 2) * 0.5
            if d < r - 2.5 and f < 3: v.set(x, y, 1)
            elif d < r - 1.2: v.set(x, y, 11)
            elif d < r: v.set(x, y, 9 if f < 2 else 4)
    cell(v)
names.append('sprite SHOT     %d %d       # your tracer' % (col[0], row[0]))
v = Cv(16, 16); v.rect(7, 6, 8, 9, 11); v.rect(7, 7, 8, 8, 1); cell(v)

# ---- your car: 32 x 16 (two cells), from behind: straight, leaning left, leaning right; each
# without her, then with her
room(12)
names.append('sprite PCAR     %d %d 6 2 1 # your car: straight, left, right; then the same with her' % (col[0], row[0]))
for her in (0, 1):
    for lean in (0, -1, 1):
        B = Cv(32, 16)
        dx = lean * 1
        B.poly([(1, 8), (31, 8), (31, 13), (1, 13)], 9)                  # the body
        B.poly([(3 + dx, 8), (6 + dx, 4), (26 + dx, 4), (29 + dx, 8)], 10)   # the back of the cabin
        B.rect(2, 9, 5, 10, 14); B.rect(27, 9, 30, 10, 14)                   # the lights
        B.rect(13, 10, 19, 11, 1)                                            # the plate
        B.rect(1, 13, 7, 15, 0); B.rect(25, 13, 31, 15, 0)                   # the tyres
        B.rect(7 + dx, 4, 25 + dx, 5, 3)                                     # the windscreen top
        B.circle(11.5 + dx, 4.5, 3, 0)                                       # you (dark hair)
        B.circle(11.5 + dx, 5.5, 2.2, 6)
        if her:
            B.circle(20.5 + dx, 4.0, 3.2, 13)                                # her (blonde)
            B.poly([(17.5 + dx, 4), (23.5 + dx, 4), (24 + dx, 8), (17 + dx, 8)], 13)
        B.outline(0)
        for i in range(2):
            v = Cv(16, 16)
            for y in range(16):
                for x in range(16): v.p[y][x] = B.p[y][i * 16 + x]
            cell(v)
S.save(D + '/sprites.png')

open(D + '/layout.txt', 'w').write('''# ESCORT - names for the cells of tiles.png (8 x 8) and sprites.png (16 x 16)
# (the road and the sky are Layer 2: Road.cls draws the road, tools/scenery.py the sky)
# tile   NAME   index [count]
# sprite NAME   column row [frames [w h]]
# sprite palettes (spr_pal.png rows): 0 everything (your car red), 1 blue, 2 white, 3 yellow,
# 4 black (their cars), 5 the hit flash
tile   HUD      1
tile   DMG      2 9       # the damage bar: 0-8 filled

''' + '\n'.join(names) + '\n')
print('ok', col[0], row[0])
