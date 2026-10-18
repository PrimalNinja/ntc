# world.py - ZX Craft's test chunk (16 x 16 x 16), the block colours and the sky: writes ../World.cls
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License.   python3 world.py [out.cls]
import math

N = 16
AIR, GRASS, DIRT, STONE, SAND, WATER, WOOD, LEAVES, BRICK = range(9)
NAMES = ['air', 'grass', 'dirt', 'stone', 'sand', 'water', 'wood', 'leaves', 'brick']

def idx(x, y, z): return x + z * 16 + y * 256

def make():
    b = bytearray(4096)
    def h(x, z):
        v = 6 + 2.2 * math.sin(x * 0.45 + 0.6) + 1.8 * math.cos(z * 0.38 - 0.4) + 1.2 * math.sin((x + z) * 0.3)
        return max(2, min(12, int(round(v))))
    water = 5
    for x in range(N):
        for z in range(N):
            top = h(x, z)
            for y in range(top + 1):
                if y == top: t = SAND if top <= water + 1 and top <= water + 1 and abs(top - water) <= 1 else GRASS
                elif y >= top - 2: t = DIRT
                else: t = STONE
                b[idx(x, y, z)] = t
            for y in range(top + 1, water + 1):
                b[idx(x, y, z)] = WATER
    def tree(x, z):
        top = h(x, z)
        if top <= water: return
        for y in range(top + 1, top + 5): b[idx(x, y, z)] = WOOD
        for dx in range(-2, 3):
            for dz in range(-2, 3):
                for dy in range(3, 6):
                    X, Y, Z = x + dx, top + dy, z + dz
                    if abs(dx) + abs(dz) + max(0, dy - 4) * 2 > 3: continue
                    if 0 <= X < N and 0 <= Z < N and Y < N and b[idx(X, Y, Z)] == AIR: b[idx(X, Y, Z)] = LEAVES
    tree(3, 11); tree(12, 4)
    # a little brick hut
    hx, hz = 9, 10
    base = max(h(x, z) for x in range(hx, hx + 4) for z in range(hz, hz + 4))
    for x in range(hx, hx + 4):
        for z in range(hz, hz + 4):
            for y in range(base + 1, base + 4):
                edge = x in (hx, hx + 3) or z in (hz, hz + 3)
                door = (x == hx + 1 and z == hz and y < base + 3)
                b[idx(x, y, z)] = BRICK if edge and not door else AIR
            b[idx(x, base + 4, z)] = WOOD
            for y in range(h(x, z) + 1, base + 1): b[idx(x, y, z)] = DIRT
    return b

def rgb(r, g, bb):   # 0-255 each -> RGB332
    return (min(7, r * 8 // 256) << 5) | (min(7, g * 8 // 256) << 2) | min(3, bb * 4 // 256)

# faces: 0 -X, 1 +X, 2 -Y (bottom), 3 +Y (top), 4 -Z, 5 +Z, 6 top (the other checker square)
BASE = {GRASS: (60, 200, 40), DIRT: (150, 100, 50), STONE: (140, 140, 150), SAND: (230, 210, 120),
        WATER: (40, 90, 230), WOOD: (130, 85, 40), LEAVES: (30, 140, 30), BRICK: (190, 60, 40)}
SIDE = {GRASS: (120, 150, 60)}   # grass sides: earthier
def colours():
    t = bytearray(16 * 8)
    for k, c in BASE.items():
        side = SIDE.get(k, c)
        sh = [0.62, 0.78, 0.40, 1.0, 0.70, 0.86, 0.90]
        for f in range(7):
            base = c if f in (3, 6) or f == 2 else side
            m = sh[f]
            t[k * 8 + f] = rgb(int(base[0] * m), int(base[1] * m), int(base[2] * m))
    return t

def sky():
    out = []
    for r in range(80):
        f = r / 79
        out.append(rgb(int(70 + 120 * f), int(120 + 100 * f), 255))
    return out


# ---- World.cls: the chunk (run-length), the block colours and the sky, for Vox.Load / Colours
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
    w = """' World - ZX Craft's test chunk (16 x 16 x 16 blocks) and its colours, for Vox.Load and
' Vox.Colours. Made by tools/world.py: change the world or the colours there and run it again.
' Blocks: 0 air, 1 grass, 2 dirt, 3 stone, 4 sand, 5 water, 6 wood, 7 leaves, 8 brick
' Colours are Layer 2's (RRRGGGBB), 8 a block: -X, +X, bottom, top, -Z, +Z, the top's other
' square (a checker on the tops), spare; then 80 for the sky, top row first.
Option Explicit

' Base(): the chunk, run-length (count (0 = 256), block; x + 16 z + 256 y order)
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

' Colours(): the block colours (16 x 8) then the sky (80)
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
