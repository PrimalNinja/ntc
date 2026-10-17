# arena.py - the arena: a 256 x 192 Layer 2 picture (the floor, the circle, the rails the guns
# run on), packed in runs. Writes ../Arena.cls and arena_preview.png.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# Run: python3 tools/scene.py
import math, random, os

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 256, 192

def col(r, g, b):
    v = (max(0, min(7, int(round(r)))) << 5) | (max(0, min(7, int(round(g)))) << 2) | max(0, min(3, int(round(b))))
    return 0xE2 if v == 0xE3 else v            # (#E3 is see-through)

img = [[0] * W for _ in range(H)]
rnd = random.Random(7)
TOP, BOT, LEFT, RIGHT = 32, 175, 16, 239        # the arena inside the rails
# the floor: dark stone flags with mortar between, a little noise
for y in range(H):
    for x in range(W):
        fx, fy = x // 16, (y + 8 * ((x // 16) % 2)) // 16
        n = (fx * 7 + fy * 13) % 3                  # each flag its own shade
        img[y][x] = [col(1, 0, 0), col(2, 0, 0), col(2, 1, 0)][n]
        if x % 16 == 0 or (y + 8 * ((x // 16) % 2)) % 16 == 0: img[y][x] = col(0, 0, 0)
# cracks with lava in them
for k in range(9):
    x, y = rnd.randrange(LEFT + 10, RIGHT - 10), rnd.randrange(TOP + 10, BOT - 10)
    for s in range(rnd.randrange(14, 30)):
        x += rnd.choice((-1, 0, 1)); y += rnd.choice((-1, 0, 1, 1))
        if LEFT < x < RIGHT and TOP < y < BOT:
            img[y][x] = col(7, 3, 0)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if img[y + dy][x + dx] != col(7, 3, 0): img[y + dy][x + dx] = col(4, 0, 0)
# the summoning circle in the middle
cx, cy = 128, 104
for y in range(TOP, BOT + 1):
    for x in range(LEFT, RIGHT + 1):
        d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
        if 52 < d < 54 or 38 < d < 39.2: img[y][x] = col(5, 0, 1)
        elif 54 <= d < 55: img[y][x] = col(2, 0, 0)
for k in range(12):
    a = k * math.pi / 6
    rx, ry = cx + math.cos(a) * 46, cy + math.sin(a) * 46
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if abs(dx) + abs(dy) <= 2: img[int(ry) + dy][int(rx) + dx] = col(6, 1, 1) if (dx, dy) != (0, 0) else col(7, 5, 1)
# the rails the guns run on
def rail(x0, y0, x1, y1, across):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            t = (y - y0) if across else (x - x0)
            img[y][x] = col(2, 2, 1) if t in (0, 15) else col(1, 1, 1) if t not in (7, 8) else col(4, 4, 2)
rail(0, 16, W - 1, 31, True)
rail(0, 176, W - 1, 191, True)
rail(0, 16, 15, 191, False)
rail(240, 16, 255, 191, False)
for (x0, y0) in ((0, 16), (240, 16), (0, 176), (240, 176)):     # the corner blocks
    for y in range(y0, y0 + 16):
        for x in range(x0, x0 + 16):
            img[y][x] = col(3, 0, 0) if (x - x0) in (0, 15) or (y - y0) in (0, 15) else col(2, 0, 0)
    img[y0 + 7][x0 + 7] = img[y0 + 8][x0 + 8] = col(7, 4, 0)
for y in range(16):
    for x in range(W): img[y][x] = col(0, 0, 0)
# ---------------------------------------------------------------- packed: per row, (count, colour)
data = []
for y in range(H):
    x = 0
    while x < W:
        c = img[y][x]; n = 1
        while x + n < W and img[y][x + n] == c and n < 255: n += 1
        data += [n, c]; x += n

def dbs(d, per=16):
    return '\n'.join('            db ' + ', '.join(str(v) for v in d[k:k + per]) for k in range(0, len(d), per))

cls = """' Arena - the arena on Layer 2: one 256 x 192 picture. Made by tools/arena.py (don't edit:
' change that and run it).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' Init: Layer 2 on (256 x 192, 16K bank 16), the picture unpacked into it.
Option Explicit

Private sps As Integer

Public Sub Init()
  Nx.Reg &H70, 0
  Nx.Reg &H12, 16
  Nx.Reg &H1C, 1
  Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0
  Unpack
  Out &H123B, 2
End Sub

' the runs into bank 16 (pages 32-37), each 8K page through MMU slot 6
Private Sub Unpack()
#asm
            ld hl, up_data
            ld b, 32                ; the page
up_page:
            push_no:
            ld a, b
            ld (up_pg + 1), a
            push hl
            pop hl
#endasm
End Sub
"""
# (the real Unpack below replaces the placeholder)
unpack = """Private Sub Unpack()
#asm
            ld hl, up_data
            ld a, 32
            ld ({sps}), a
up_page:
            ld bc, #243B            ; this page into slot 6
            ld a, #56
            out (c), a
            inc b
            ld a, ({sps})
            out (c), a
            ld de, #C000
up_run:
            ld b, (hl)              ; a run: count, colour
            inc hl
            ld a, (hl)
            inc hl
up_put:
            ld (de), a
            inc de
            djnz up_put
            ld a, d
            cp #E0                  ; the page is full (32 rows)
            jr nz, up_run
            ld a, ({sps})
            inc a
            ld ({sps}), a
            cp 38
            jr nz, up_page
            ld bc, #243B            ; slot 6 back to bank 5's first half
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            jp up_done
up_data:
%s
up_done:
#endasm
End Sub
""" % dbs(data)
cls = cls[:cls.index("' the runs into bank 16")] + "' the runs into bank 16 (pages 32-37), each 8K page through MMU slot 6\n" + unpack
open(os.path.join(HERE, '..', 'Arena.cls'), 'w').write(cls)

try:
    from PIL import Image
    def rgb(v): return ((v >> 5) * 255 // 7, ((v >> 2) & 7) * 255 // 7, (v & 3) * 255 // 3)
    im = Image.new('RGB', (W, H))
    for y in range(H):
        for x in range(W): im.putpixel((x, y), rgb(img[y][x]))
    im.resize((W * 2, H * 2), Image.NEAREST).save(os.path.join(HERE, 'arena_preview.png'))
except ImportError:
    pass
print('Arena.cls: %d bytes of runs' % len(data))
