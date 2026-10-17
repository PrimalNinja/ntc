# bgart.py - DANMAKU's backgrounds: 24 blocks of 16 x 16 Layer 2 pixels and the five stages'
# colours. Writes ../BgData.cls (and bg_preview.png: every stage's look, for checking).
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#
# A block's pixels are colour numbers 0-47: six ramps of 8 shades (0 darkest - 7 lightest):
#   0-7 ground, 8-15 the path (river / road / lava / energy / vein), 16-23 buildings and metal,
#   24-31 lights, 32-39 plants and rocks, 40-47 shadow.
# Each stage gives the ramps their own colours, so one set of blocks makes five places.
# Run:  python3 tools/bgart.py
import math, random, os

HERE = os.path.dirname(os.path.abspath(__file__))
G, P, M, A, V, K = 0, 8, 16, 24, 32, 40

# ---------------------------------------------------------------- the blocks
def blank(): return [[0] * 16 for _ in range(16)]

def ground(seed, base=3, spread=1, ramp=G):
    r = random.Random(seed); b = blank()
    for y in range(16):
        for x in range(16):
            b[y][x] = ramp + max(0, min(7, base + r.choice((0, 0, 0, 1, -1)) * spread))
    for _ in range(6):                     # some lighter and darker flecks
        x, y = r.randrange(16), r.randrange(16)
        b[y][x] = ramp + min(7, base + 2); b[(y + 1) % 16][x] = ramp + max(0, base - 1)
    return b

def path(kind, seed):
    b = ground(seed)
    for y in range(16):
        for x in range(16):
            px, py = x + 0.5, y + 0.5
            if kind == 'V': d = abs(px - 8)
            elif kind == 'H': d = abs(py - 8)
            else:
                cx = 16 if 'E' in kind else 0
                cy = 16 if 'S' in kind else 0
                d = abs(math.hypot(px - cx, py - cy) - 8)
            if d < 5.5:
                if d > 4.5: b[y][x] = K + 1             # its edge
                elif d > 3.5: b[y][x] = P + 2
                else: b[y][x] = P + 4 + (1 if d < 1.2 else 0)
    # a dashed line down the middle (road markings / ripples)
    if kind == 'V':
        for y in range(16):
            if y % 8 < 4: b[y][7] = b[y][8] = P + 7
    if kind == 'H':
        for x in range(16):
            if x % 8 < 4: b[7][x] = b[8][x] = P + 7
    return b

def building():          # 32 x 32, split into four blocks
    r = random.Random(7)
    big = [[G + 3] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            big[y][x] = G + 3 + r.choice((0, 0, 1, -1))
    for y in range(2, 30):
        for x in range(2, 30):
            big[y][x] = M + 4
    for y in range(4, 32):                  # its shadow, down and to the right
        for x in range(30, 32): big[y][x] = K + 1
    for x in range(4, 32):
        for y in range(30, 32): big[y][x] = K + 1
    for x in range(2, 30): big[2][x] = M + 7; big[29][x] = M + 1
    for y in range(2, 30): big[y][2] = M + 6; big[y][29] = M + 2
    for y in range(6, 14):                  # a roof unit
        for x in range(6, 16): big[y][x] = M + 2 if (y == 13 or x == 15) else M + 5
    for y in range(18, 26):                 # vents
        for x in range(6, 26): big[y][x] = M + 1 if x % 3 == 0 else M + 3
    for (x, y) in ((22, 7), (25, 7), (22, 11), (25, 11)):   # lights
        big[y][x] = A + 7; big[y][x + 1] = A + 5
    return [[[big[j * 16 + y][i * 16 + x] for x in range(16)] for y in range(16)] for j in (0, 1) for i in (0, 1)]

def pad():
    b = ground(31)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if d < 7.5: b[y][x] = M + (2 if d > 6.5 else 4)
            if d < 5.5 and d > 4.5: b[y][x] = A + 6
    for y in range(5, 11):
        b[y][6] = A + 7; b[y][9] = A + 7
    b[8][7] = b[8][8] = A + 7
    return b

def crater():
    b = ground(41)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if d < 6.5:
                b[y][x] = K + 1 if d < 4.5 else (G + 6 if (x + y) < 16 else G + 1)
            if d < 3: b[y][x] = K + 0
    return b

def vent():
    b = ground(51)
    for y in range(3, 13):
        for x in range(3, 13):
            b[y][x] = M + (6 if y == 3 or x == 3 else 2 if y == 12 or x == 12 else 4)
    for y in range(5, 11, 2):
        for x in range(5, 11): b[y][x] = K + 0
    for y in range(4, 14): b[y][13] = K + 1
    for x in range(4, 14): b[13][x] = K + 1
    return b

def tower():
    b = ground(61)
    for y in range(2, 14):
        for x in range(2, 14):
            b[y][x] = M + (7 if y == 2 or x == 2 else 1 if y == 13 or x == 13 else 3)
    for y in range(5, 11):
        for x in range(5, 11): b[y][x] = M + 5
    for (x, y) in ((4, 4), (11, 4), (4, 11), (11, 11)): b[y][x] = A + 7
    b[7][7] = b[8][8] = A + 6; b[7][8] = b[8][7] = A + 4
    return b

def plate(rivets):
    b = blank()
    for y in range(16):
        for x in range(16):
            b[y][x] = M + 3
            if y == 0 or x == 0: b[y][x] = M + 5
            if y == 15 or x == 15: b[y][x] = M + 1
    if rivets:
        for (x, y) in ((3, 3), (12, 3), (3, 12), (12, 12)): b[y][x] = M + 6; b[y + 1][x + 1] = M + 1
        for k in range(4, 12): b[k][k] = M + 2
    else:
        for y in range(4, 12):
            for x in range(4, 12): b[y][x] = M + 4
    return b

def stripe():
    b = blank()
    for y in range(16):
        for x in range(16):
            b[y][x] = A + 5 if ((x + y) // 4) % 2 == 0 else K + 1
    for x in range(16): b[0][x] = M + 5; b[15][x] = M + 1
    return b

def dark(seed):
    r = random.Random(seed); b = blank()
    for y in range(16):
        for x in range(16): b[y][x] = K + 0
    for _ in range(3):
        x, y = r.randrange(16), r.randrange(16)
        b[y][x] = K + 7 if r.random() < 0.5 else K + 4
    return b

def trees():
    b = ground(71)
    r = random.Random(72)
    for (cx, cy, rad) in ((5, 5, 4), (11, 6, 3.5), (7, 11, 4), (13, 12, 2.5)):
        for y in range(16):
            for x in range(16):
                d = math.hypot(x + 0.5 - cx - 1, y + 0.5 - cy - 1)
                if d < rad and b[y][x] < V: b[y][x] = K + 1        # shadow
        for y in range(16):
            for x in range(16):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d < rad:
                    lit = (x - cx) + (y - cy) < -1
                    b[y][x] = V + (6 if lit and d < rad * 0.6 else 4 if d < rad * 0.8 else 2) + r.choice((0, 0, -1))
    return b

def tanks():
    b = ground(81)
    for (cx, cy) in ((5, 8), (11.5, 8)):
        for y in range(16):
            for x in range(16):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d < 4.2:
                    b[y][x] = M + (6 if (x - cx + y - cy) < -2 else 4 if d < 3.4 else 2)
        b[int(cy)][int(cx)] = A + 6
    return b

def grille():
    b = blank()
    for y in range(16):
        for x in range(16):
            b[y][x] = M + 2 if (y % 4) in (1, 2) else M + 4
            if (y % 4) == 2 and 2 < x < 13: b[y][x] = K + 0
    for y in range(16): b[y][0] = M + 5; b[y][15] = M + 1
    return b

BLOCKS = [
    ('G1', ground(1)), ('G2', ground(2, base=2)), ('G3', ground(3, base=4)),
    ('PV', path('V', 11)), ('PH', path('H', 12)),
    ('PSE', path('SE', 13)), ('PSW', path('SW', 14)), ('PNE', path('NE', 15)), ('PNW', path('NW', 16)),
]
bld = building()
BLOCKS += [('BTL', bld[0]), ('BTR', bld[1]), ('BBL', bld[2]), ('BBR', bld[3])]
BLOCKS += [('PAD', pad()), ('CRATER', crater()), ('VENT', vent()), ('TOWER', tower()),
           ('PLATE', plate(False)), ('PLATE2', plate(True)), ('STRIPE', stripe()), ('DARK', dark(91)),
           ('TREES', trees()), ('TANKS', tanks()), ('GRILLE', grille())]
assert len(BLOCKS) == 24

# ---------------------------------------------------------------- the stages' colours
# each ramp: (dark, light) as (r 0-7, g 0-7, b 0-3)
THEMES = [
    ('COAST',    [(0, 2, 0), (3, 6, 1)], [(0, 1, 1), (2, 5, 3)], [(1, 1, 1), (6, 6, 3)], [(3, 2, 0), (7, 7, 1)], [(0, 1, 0), (2, 5, 0)], [(0, 0, 0), (1, 2, 1)]),
    ('DESERT',   [(3, 2, 0), (7, 6, 1)], [(1, 1, 0), (4, 4, 2)], [(2, 2, 0), (6, 6, 2)], [(2, 0, 0), (7, 2, 0)], [(2, 1, 0), (5, 4, 1)], [(1, 0, 0), (2, 1, 0)]),
    ('FORTRESS', [(1, 1, 1), (4, 4, 2)], [(2, 0, 0), (7, 6, 0)], [(1, 1, 1), (4, 4, 2)], [(0, 2, 1), (3, 7, 3)], [(1, 1, 0), (4, 3, 1)], [(0, 0, 0), (1, 1, 1)]),
    ('ORBIT',    [(1, 0, 1), (4, 3, 2)], [(0, 1, 2), (4, 7, 3)], [(1, 1, 1), (6, 6, 3)], [(2, 0, 1), (7, 3, 2)], [(0, 0, 1), (2, 2, 2)], [(0, 0, 0), (5, 5, 2)]),
    ('HIVE',     [(2, 0, 0), (6, 3, 1)], [(1, 0, 0), (6, 1, 1)], [(2, 2, 1), (7, 7, 2)], [(0, 2, 0), (3, 7, 1)], [(1, 0, 1), (5, 2, 2)], [(0, 0, 0), (2, 0, 0)]),
    ('FLASH',    [(5, 5, 2), (7, 7, 3)], [(5, 5, 2), (7, 7, 3)], [(5, 5, 2), (7, 7, 3)], [(6, 6, 2), (7, 7, 3)], [(5, 5, 2), (7, 7, 3)], [(4, 4, 2), (7, 7, 3)]),
]

def ramp(lo, hi):
    out = []
    for k in range(8):
        t = k / 7
        r = round(lo[0] + (hi[0] - lo[0]) * t); g = round(lo[1] + (hi[1] - lo[1]) * t); b = round(lo[2] + (hi[2] - lo[2]) * t)
        v = (r << 5) | (g << 2) | b
        if v == 0xE3: v = 0xE2              # (#E3 is see-through)
        out.append(v)
    return out

def pal(theme):
    out = []
    for lohi in theme[1:]: out += ramp(*lohi)
    return out

# ---------------------------------------------------------------- BgData.cls
def dbs(data, per=16):
    lines = []
    for k in range(0, len(data), per):
        lines.append('            db ' + ', '.join(str(v) for v in data[k:k + per]))
    return '\n'.join(lines)

blockbytes = []
for name, b in BLOCKS:
    for row in b: blockbytes += row
palbytes = []
for t in THEMES: palbytes += pal(t)

consts = '\n'.join('Public Const %s = %d' % ('B_' + n, k) for k, (n, _) in enumerate(BLOCKS))
cls = """' BgData - DANMAKU's background blocks and the stages' colours, made by tools/bgart.py.
' Don't edit: change tools/bgart.py and run  python3 tools/bgart.py
' Blocks(): the address of 24 blocks of 16 x 16 Layer 2 pixels (256 bytes each, row by row);
' their pixels are colour numbers 0-47. Colours(): the address of six sets of 48 Layer 2 colours
' (RRRGGGBB): the five stages and the bomb's flash.
Option Explicit

%s

Public Function Blocks() As Integer
#asm
            pop hl
            ld de, bd_data
            ld (hl), e
            inc hl
            ld (hl), d
            ret
bd_data:
%s
#endasm
End Function

Public Function Colours() As Integer
#asm
            pop hl
            ld de, cd_data
            ld (hl), e
            inc hl
            ld (hl), d
            ret
cd_data:
%s
#endasm
End Function
""" % (consts, dbs(blockbytes), dbs(palbytes))
open(os.path.join(HERE, '..', 'BgData.cls'), 'w').write(cls)

# ---------------------------------------------------------------- a preview: each stage's blocks
try:
    from PIL import Image
    def rgb(v): return ((v >> 5) * 255 // 7, ((v >> 2) & 7) * 255 // 7, (v & 3) * 255 // 3)
    img = Image.new('RGB', (24 * 17, 6 * 17))
    for t in range(6):
        p = pal(THEMES[t])
        for k, (n, b) in enumerate(BLOCKS):
            for y in range(16):
                for x in range(16):
                    img.putpixel((k * 17 + x, t * 17 + y), rgb(p[b[y][x]]))
    img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(os.path.join(HERE, 'bg_preview.png'))
except ImportError:
    pass
print('BgData.cls: %d blocks, %d colours' % (len(BLOCKS), len(palbytes)))
