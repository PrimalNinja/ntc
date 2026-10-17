# world.py - THE GHOST's sea floor (16 x 16 x 16 blocks), the block colours (in 4 shades of murk)
# and the water behind: writes ../World.cls.   (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
#   python3 world.py [out.cls]
import math, random

N = 16
AIR, SAND, ROCK, DARKROCK, KELP, CORAL, HULL, DECK, METAL, CABLE = range(10)
NAMES = ['water', 'sand', 'rock', 'dark rock', 'kelp', 'coral', 'hull', 'deck', 'metal', 'cable']

def idx(x, y, z): return x + z * 16 + y * 256

def make():
    rnd = random.Random(7)
    b = bytearray(4096)
    def put(x, y, z, t):
        if 0 <= x < N and 0 <= y < N and 0 <= z < N: b[idx(x, y, z)] = t
    def get(x, y, z):
        return b[idx(x, y, z)] if (0 <= x < N and 0 <= y < N and 0 <= z < N) else 0
    # the sea floor: sand, a little roll to it
    for x in range(N):
        for z in range(N):
            h = 1 + int(round(0.8 + 0.7 * math.sin(x * 0.7) + 0.6 * math.cos(z * 0.5 + 1)))
            for y in range(h + 1): put(x, y, z, ROCK if y < h else SAND)
    # a ridge of rock across the middle (z 7 - 9), up to 11 high, with a tunnel through it
    for x in range(N):
        top = 7 + int(round(3 * math.sin(x * 0.45 + 0.3) + 1.5 * math.cos(x * 1.3)))
        if 5 <= x <= 10: top = max(top, 8)          # (a roof over the tunnel)
        for z in range(6, 11):
            t = top - (2 if z in (6, 10) else 0)
            for y in range(t + 1): put(x, y, z, DARKROCK if (x + y + z) % 5 else ROCK)
    for z in range(5, 12):
        for x in (7, 8):
            for y in (3, 4): put(x, y, z, AIR)
    # the wreck: a hull lying on the floor at the far corner (x 10 - 14, z 12 - 14), broken open
    for x in range(10, 15):
        for z in range(12, 15):
            for y in range(2, 5):
                edge = z in (12, 14) or y == 2 or x in (10, 14)
                if edge: put(x, y, z, HULL)
            put(x, 5, 13, DECK)
    put(12, 3, 12, AIR); put(12, 4, 12, AIR); put(13, 4, 12, AIR)   # the hole in her side
    put(11, 6, 13, METAL); put(11, 7, 13, METAL)                     # what's left of the mast
    # the cable along the floor
    for x in range(N):
        z = 3
        y = 1
        while get(x, y, z): y += 1
        put(x, y, z, CABLE)
    # kelp and coral
    for _ in range(26):
        x, z = rnd.randrange(N), rnd.randrange(N)
        y = 1
        while get(x, y, z): y += 1
        if y > 8: continue
        if rnd.random() < 0.6:
            for k in range(rnd.randrange(2, 5)): put(x, y + k, z, KELP)
        else:
            put(x, y, z, CORAL)
    return b

def rgb(r, g, bb):   # 0-255 each -> RGB332
    r, g, bb = max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, bb))
    return (min(7, r * 8 // 256) << 5) | (min(7, g * 8 // 256) << 2) | min(3, bb * 4 // 256)

WATER = (10, 60, 110)            # what the far ones fade to
BASE = {SAND: (200, 180, 110), ROCK: (110, 110, 120), DARKROCK: (70, 70, 90), KELP: (40, 150, 60),
        CORAL: (230, 90, 110), HULL: (160, 70, 40), DECK: (110, 80, 50), METAL: (150, 160, 170),
        CABLE: (30, 30, 30)}
# faces: 0 -X, 1 +X, 2 -Y (bottom), 3 +Y (top), 4 -Z, 5 +Z, 6 top (the other checker square)
SH = [0.62, 0.78, 0.40, 1.0, 0.70, 0.86, 0.90]
FOG = [0.0, 0.35, 0.6, 0.8]      # how much of the murk at each fog level

def colours():
    t = bytearray(16 * 8 * 4)
    for lev, k_fog in enumerate(FOG):
        for k, c in BASE.items():
            for f in range(7):
                m = SH[f]
                r, g, bb = c[0] * m, c[1] * m, c[2] * m
                r = r + (WATER[0] - r) * k_fog; g = g + (WATER[1] - g) * k_fog; bb = bb + (WATER[2] - bb) * k_fog
                v = rgb(int(r), int(g), int(bb))
                t[lev * 128 + k * 8 + f] = 0xE2 if v == 0xE3 else v   # (#E3 is see-through)
    return t

def sky():
    # the water behind: lighter near the surface (the top rows), dark below
    out = []
    for r in range(80):
        f = r / 79
        v = rgb(int(30 - 20 * f), int(110 - 70 * f), int(170 - 100 * f))
        out.append(0xE2 if v == 0xE3 else v)
    return out

def bytes_(label, vals, per=16):
    out = [label + ':']
    for i in range(0, len(vals), per):
        out.append('            db ' + ', '.join(str(v) for v in vals[i:i + per]))
    return '\n'.join(out) + '\n'

def rle(blk):
    out = []
    i = 0
    while i < 4096:
        j = i
        while j < 4096 and blk[j] == blk[i] and j - i < 256: j += 1
        out += [(j - i) & 255, blk[i]]
        i = j
    return out

def write(path, blk, cols, skyc):
    w = """' World - THE GHOST's sea floor (16 x 16 x 16 blocks) and its colours, for Vox.Load and
' Vox.Colours. Made by tools/world.py: change the map or the colours there and run it again.
' Blocks: 0 water, 1 sand, 2 rock, 3 dark rock, 4 kelp, 5 coral, 6 hull, 7 deck, 8 metal, 9 cable
' Colours are Layer 2's (RRRGGGBB), 8 a block (-X, +X, bottom, top, -Z, +Z, the top's other
' square, spare), 16 blocks a set, 4 sets (near to far, fading into the murk); then 80 for the
' water behind, top row first.
Option Explicit

' Base(): the map, run-length (count (0 = 256), block; x + 16 z + 256 y order)
Public Function Base() As Integer
#asm
            pop hl
            ld de, wd_data
            ld (hl), e
            inc hl
            ld (hl), d
            ret
""" + bytes_('wd_data', rle(blk)) + """#endasm
End Function

' Colours(): the block colours (4 x 16 x 8) then the water (80)
Public Function Colours() As Integer
#asm
            pop hl
            ld de, wc_data
            ld (hl), e
            inc hl
            ld (hl), d
            ret
""" + bytes_('wc_data', list(cols) + list(skyc)) + """#endasm
End Function
"""
    open(path, 'w').write(w)

if __name__ == '__main__':
    import os, sys
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'World.cls')
    write(out, make(), colours(), sky())
    print(out)
