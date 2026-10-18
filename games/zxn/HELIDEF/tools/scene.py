# scene.py - the landscape: a 256 x 192 Layer 2 picture that joins up end to end (the hardware
# scrolls it round), packed in runs. Writes ../Scene.cls and scene_preview.png.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# Run: python3 tools/scene.py
import math, random, os

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 256, 192
HUD = 32          # rows under the HUD (not seen)
HORIZON = 140     # the horizon
GROUND = 176      # where feet touch

def col(r, g, b):
    v = (max(0, min(7, int(round(r)))) << 5) | (max(0, min(7, int(round(g)))) << 2) | max(0, min(3, int(round(b))))
    return 0xE2 if v == 0xE3 else v            # (#E3 is see-through)

img = [[0] * W for _ in range(H)]
rnd = random.Random(11)

# the night sky: near black at the top to deep teal at the horizon
for y in range(H):
    t = max(0.0, min(1.0, (y - HUD) / (HORIZON - HUD)))
    c = col(0, 1.2 * t, 1 + 1.6 * t)
    for x in range(W): img[y][x] = c
# stars
for _ in range(80):
    x, y = rnd.randrange(W), rnd.randrange(HUD + 2, HUD + 70)
    img[y][x] = col(7, 7, 3) if rnd.random() < 0.3 else col(4, 4, 2)
# far mountains (repeat every 256)
def ridge(base, amp, waves, colour):
    for x in range(W):
        h = 0
        for (k, a, p) in waves: h += a * math.sin(2 * math.pi * k * x / W + p)
        top = int(base - amp - h)
        for y in range(max(HUD, top), HORIZON): img[y][x] = colour
ridge(HORIZON - 16, 12, [(2, 9, 0.9), (5, 4, 2.1), (11, 2, 0.4)], col(0, 1, 1))
# the city: blocks of towers with lit windows
x = 0
while x < W:
    w = rnd.randrange(10, 22); h = rnd.randrange(14, 46)
    top = HORIZON - h
    shade = col(0, 0, 1) if rnd.random() < 0.5 else col(1, 1, 1)
    for yy in range(top, HORIZON):
        for xx in range(x, min(W, x + w)): img[yy][xx] = shade
    # a spire now and then
    if rnd.random() < 0.3:
        for yy in range(top - 6, top): img[yy][x + w // 2] = shade
        img[top - 7][x + w // 2] = col(7, 0, 0)
    for yy in range(top + 3, HORIZON - 2, 4):
        for xx in range(x + 2, min(W, x + w) - 2, 3):
            if rnd.random() < 0.45: img[yy][xx] = col(7, 6, 0) if rnd.random() < 0.7 else col(3, 6, 3)
    x += w + rnd.randrange(0, 4)
# the horizon line
for x in range(W): img[HORIZON][x] = col(1, 4, 3)
# the ground: dark grass, a road with dashes, the ground line
for y in range(HORIZON + 1, H):
    for x in range(W): img[y][x] = col(0, 1, 0)
for y in range(HORIZON + 8, HORIZON + 16):
    for x in range(W): img[y][x] = col(1, 1, 1)
for x in range(0, W, 16):
    for xx in range(x, x + 8): img[HORIZON + 12][xx] = col(6, 6, 2)
for _ in range(120):
    x, y = rnd.randrange(W), rnd.randrange(HORIZON + 18, H)
    img[y][x] = col(0, 2, 0)
for x in range(W): img[GROUND][x] = col(1, 5, 1)

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

cls = """' Scene - the landscape on Layer 2: one 256 x 192 picture that joins up end to end, scrolled
' round by the hardware (NextReg #16). Made by tools/scene.py (don't edit: change that and run it).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' Init: Layer 2 on (256 x 192, 16K bank 16), the picture unpacked into it. Scroll x: shows the
' picture from column x (0-255) at the left edge.
Option Explicit

Public Const HORIZON = %d
Public Const GROUND = %d

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

Public Sub Scroll(ByVal x As Integer)
  Nx.Reg &H16, x And 255
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
""" % (HORIZON, GROUND)
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
open(os.path.join(HERE, '..', 'Scene.cls'), 'w').write(cls)

try:
    from PIL import Image
    def rgb(v): return ((v >> 5) * 255 // 7, ((v >> 2) & 7) * 255 // 7, (v & 3) * 255 // 3)
    im = Image.new('RGB', (W * 2, H))
    for y in range(H):
        for x in range(W * 2): im.putpixel((x, y), rgb(img[y][x % W]))
    im.resize((W * 4, H * 2), Image.NEAREST).save(os.path.join(HERE, 'scene_preview.png'))
except ImportError:
    pass
print('Scene.cls: %d bytes of runs' % len(data))
