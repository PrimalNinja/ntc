# DEFENDER - the sprites (16 x 16, 8 bits a pixel) and their 9-bit palette: writes ../SprData.cls
# and sprites_preview.png. The same bytes, saved as DEFENDER.SPR (512 bytes of palette, then the
# patterns), replace them where files work.   (run: python3 tools/sprites.py)
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cvkit import Cv
HERE = os.path.dirname(os.path.abspath(__file__))

# the palette: (r, g, b) 0-7 each; 0 is see-through
PAL = [(0,0,0), (7,7,7), (5,5,5), (3,3,3), (1,1,2), (0,6,7), (1,3,7), (0,0,4),
       (7,7,0), (7,4,0), (7,0,0), (4,0,0), (0,7,0), (0,4,0), (4,7,1), (7,0,7),
       (4,0,6), (7,4,6), (7,5,3), (4,2,0), (4,6,7), (7,7,4), (0,5,4), (2,2,2)]
N = {'w': 1, 'L': 2, 'g': 3, 'k': 4, 'c': 5, 'b': 6, 'B': 7, 'y': 8, 'o': 9, 'r': 10, 'R': 11,
     'G': 12, 'D': 13, 'l': 14, 'm': 15, 'p': 16, 'P': 17, 's': 18, 'n': 19, 'u': 20, 'W': 21, 't': 22, 'K': 23}
pats = []
def add(v):
    pats.append(v); return len(pats) - 1
def art(rows):
    v = Cv(16, 16)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch not in ' .': v.set(x, y, N[ch])
    return v

def ship(f):
    rows = ['................',
            '................',
            '................',
            '....ww..........',
            '....wLww........',
            '...ccwLLwww.....',
            '..cccLLLLLLwww..',
            'XXbbbLLLLLLLLLLw',
            'XXbbbgggggggggw.',
            '..Bbbggg........',
            '...BB...........',
            '................',
            '................',
            '................',
            '................',
            '................']
    fl = [['o', 'y'], ['r', 'o']][f]
    rows = [r.replace('XX', ('.' + fl[0]) if f == 0 else (fl[0] + fl[1])) for r in rows]
    return art(rows)
def lander(f):
    rows = ['................',
            '.....DDDDDD.....',
            '....DGGGGGGD....',
            '...DGlGGGGlGD...',
            '...DGGGyyGGGD...',
            '..yDDDDDDDDDDy..',
            '..DGGlGGGGlGGD..',
            '...DDDDDDDDDD...',
            '....D..DD..D....',
            '...D...DD...D...',
            '..DD........DD..',
            '................',
            '................',
            '................',
            '................',
            '................']
    v = art(rows)
    if f:
        v.set(2, 5, 9); v.set(13, 5, 9); v.set(7, 4, 10); v.set(8, 4, 10)
    return v
def mutant(f):
    a, b = ('p', 'G') if f == 0 else ('G', 'p')
    rows = ['................',
            '..A....A....A...',
            '...A..AAA..A....',
            '....AAAAAAA.....',
            '..AAABBBBBAAA...',
            '.A.ABwRBwRBA.A..',
            '...ABBBBBBBA....',
            '..AABBrrrBBAA...',
            '.A..ABBBBBA..A..',
            '...A..AAA..A....',
            '..A....A....A...',
            '................',
            '................',
            '................',
            '................',
            '................']
    rows = [r.replace('A', a).replace('B', b) for r in rows]
    return art(rows)
def human(f):
    rows = ['................',
            '................',
            '......ss........',
            '......ss........',
            '.....PPPP.......',
            '....P.PP.P......',
            '......PP........',
            '......pp........',
            '.....p..p.......' if f == 0 else '......pp........',
            '.....p..p.......' if f == 0 else '......p.p.......',
            '................',
            '................',
            '................',
            '................',
            '................',
            '................']
    return art(rows)
def bolt():
    v = Cv(16, 16)
    for x in range(16):
        c = 'w' if x > 9 else ('W' if x > 5 else ('y' if x > 2 else 'o'))
        v.set(x, 7, N[c])
        if x > 5: v.set(x, 8, N['y' if x > 9 else 'o'])
    return v
def shot():
    v = Cv(16, 16); v.circle(7.5, 7.5, 2.6, N['o']); v.circle(7.5, 7.5, 1.6, N['y']); v.set(7, 7, 1)
    return v
def boom(f):
    v = Cv(16, 16); r2 = random.Random(9 + f)
    cols = [['w', 'W', 'y'], ['y', 'o', 'W'], ['o', 'r', 'y'], ['R', 'K', 'r']][f]
    for k in range(16):
        a = r2.uniform(0, 2 * math.pi); d = 1.5 + f * 1.8 + r2.uniform(-1, 1)
        x, y = 7.5 + d * math.cos(a), 7.5 + d * math.sin(a)
        v.set(x, y, N[cols[k % 3]])
        if f < 2: v.set(x + 1, y, N[cols[(k + 1) % 3]])
    if f == 0: v.circle(7.5, 7.5, 2.5, N['w'])
    return v
def baiter(f):
    rows = ['................',
            '................',
            '................',
            '................',
            '.....llllll.....',
            '..lllGGGGGGlll..',
            'llGGGwGwGwGwGGll',
            '..lllGGGGGGlll..',
            '.....llllll.....',
            '................',
            '................',
            '................',
            '................',
            '................',
            '................',
            '................']
    v = art(rows)
    if f:
        for x in (5, 7, 9, 11): v.set(x, 6, N['G'])
        for x in (6, 8, 10): v.set(x, 6, 1)
    return v

# 0-4 as the original: ship, lander, mutant, human, bolt
add(ship(0)); add(lander(0)); add(mutant(0)); add(human(0)); add(bolt())
add(ship(1)); add(lander(1)); add(mutant(1)); add(human(1))      # 5-8: their second frames
add(shot())                                                         # 9: an enemy's shot
for f in range(4): add(boom(f))                                     # 10-13: an explosion
add(baiter(0)); add(baiter(1))                                      # 14-15: the baiter

pal = []
for (r, g, b) in PAL + [(0, 0, 0)] * (256 - len(PAL)):
    pal += [r << 5 | g << 2 | b >> 1, b & 1]
data = []
for v in pats:
    for y in range(16):
        for x in range(16):
            p = v.p[y][x]
            data.append(0 if p is None else p)
open(os.path.join(HERE, '..', 'DEFENDER.SPR'), 'wb').write(bytes(pal + data))

L = ["' SprData - the sprites built in (made by tools/sprites.py: don't edit): a 9-bit palette (2 bytes",
     "' a colour, 256 colours) and %d patterns of 16 x 16, a byte a pixel. Upload puts them in the" % len(pats),
     "' Next (the sprites' first palette, patterns from 0).",
     "' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License",
     "Option Explicit", "",
     "Public Const Patterns = %d" % len(pats), "",
     "Public Sub Upload()", "#asm",
     "            ld bc, #243B",
     "            ld a, #43",
     "            out (c), a",
     "            inc b",
     "            ld a, #20               ; the sprites' first palette",
     "            out (c), a",
     "            dec b",
     "            ld a, #40",
     "            out (c), a",
     "            inc b",
     "            xor a",
     "            out (c), a              ; from colour 0",
     "            dec b",
     "            ld a, #44",
     "            out (c), a",
     "            inc b",
     "            ld hl, sd_pal",
     "            ld de, 512",
     "sd_pl:",
     "            ld a, (hl)",
     "            out (c), a",
     "            inc hl",
     "            dec de",
     "            ld a, d",
     "            or e",
     "            jr nz, sd_pl",
     "            ld bc, #303B",
     "            xor a",
     "            out (c), a              ; patterns from 0",
     "            ld hl, sd_pat",
     "            ld de, %d" % len(data),
     "            ld bc, #5B",
     "sd_pp:",
     "            ld a, (hl)",
     "            out (c), a",
     "            inc hl",
     "            dec de",
     "            ld a, d",
     "            or e",
     "            jr nz, sd_pp",
     "            jp sd_end",
     "sd_pal:"]
for k in range(0, 512, 32): L.append("            db " + ", ".join(str(b) for b in pal[k:k + 32]))
L.append("sd_pat:")
for k in range(0, len(data), 32): L.append("            db " + ", ".join(str(b) for b in data[k:k + 32]))
L += ["sd_end:", "#endasm", "End Sub"]
open(os.path.join(HERE, '..', 'SprData.cls'), 'w').write('\n'.join(L) + '\n')

from PIL import Image
im = Image.new('RGB', (len(pats) * 18 * 4, 18 * 4), (20, 20, 30))
for k, v in enumerate(pats):
    for y in range(16):
        for x in range(16):
            p = v.p[y][x]
            if p:
                r, g, b = PAL[p]
                for a in range(4):
                    for c in range(4): im.putpixel((k * 72 + 4 + x * 4 + a, 4 + y * 4 + c), (r * 36, g * 36, b * 36))
im.save(os.path.join(HERE, 'sprites_preview.png'))
print(len(pats), 'patterns')
