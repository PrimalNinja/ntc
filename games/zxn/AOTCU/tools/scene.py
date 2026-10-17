# scene.py - the landscape: a 256 x 192 Layer 2 picture that joins up end to end (the hardware
# scrolls it round), packed in runs. Writes ../Scene.cls and scene_preview.png.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# Run: python3 tools/scene.py
import math, random, os

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 256, 192
HUD = 32          # rows under the HUD (not seen)
HORIZON = 132     # the horizon
GROUND = 170      # where feet and wheels touch

def col(r, g, b):
    v = (max(0, min(7, int(round(r)))) << 5) | (max(0, min(7, int(round(g)))) << 2) | max(0, min(3, int(round(b))))
    return 0xE2 if v == 0xE3 else v            # (#E3 is see-through)

img = [[0] * W for _ in range(H)]
rnd = random.Random(3)

# the sky: deep purple at the top to orange at the horizon
for y in range(H):
    t = max(0.0, min(1.0, (y - HUD) / (HORIZON - HUD)))
    if t < 0.6:
        u = t / 0.6; c = col(1 + 3 * u, 0, 1 + 1 * u)
    else:
        u = (t - 0.6) / 0.4; c = col(4 + 3 * u, 0 + 3 * u, 2 - 1 * u)
    for x in range(W): img[y][x] = c
# stars in the upper sky
for _ in range(70):
    x, y = rnd.randrange(W), rnd.randrange(HUD + 2, HUD + 60)
    img[y][x] = col(7, 7, 3) if rnd.random() < 0.3 else col(5, 5, 3)
# the sun: a striped disc, cut by the mountains
sx, sy, sr = 168, 112, 36
for y in range(H):
    for x in range(W):
        d = math.hypot(x + 0.5 - sx, y + 0.5 - sy)
        if d < sr and y < HORIZON:
            gap = y > sy - 6 and ((y - (sy - 6)) % 7) < 1 + (y - (sy - 6)) // 9
            if not gap:
                u = (y - (sy - sr)) / (2 * sr)
                img[y][x] = col(7, 7 - 5 * u, 1 - u)
# two ridges of mountains (their shapes repeat every 256 pixels)
def ridge(base, amp, waves, colour):
    for x in range(W):
        h = 0
        for (k, a, p) in waves: h += a * math.sin(2 * math.pi * k * x / W + p)
        top = int(base - amp - h)
        for y in range(max(HUD, top), HORIZON): img[y][x] = colour
ridge(HORIZON - 14, 10, [(2, 8, 0.3), (5, 4, 1.1), (9, 2, 2.0)], col(2, 0, 2))
ridge(HORIZON - 4, 4, [(3, 6, 2.2), (7, 3, 0.7), (13, 1.5, 1.4)], col(1, 0, 1))
# the horizon line
for x in range(W): img[HORIZON][x] = col(2, 7, 3)
# the ground: dark, with glowing lines further apart nearer to you, and posts every 32 pixels
for y in range(HORIZON + 1, H):
    for x in range(W): img[y][x] = col(1, 0, 1)
y = HORIZON + 1; gap = 2
while y < H:
    for x in range(W): img[y][x] = col(4, 0, 3) if y < GROUND else col(5, 1, 3)
    y += gap; gap += 1
for x0 in range(0, W, 32):
    for y in range(HORIZON + 1, H):
        dx = (y - HORIZON) * (x0 - 128) // 128 // 4   # leaning out a little: a hint of depth
        x = (x0 + dx) % W
        img[y][x] = col(3, 0, 3)
for x in range(W): img[GROUND][x] = col(2, 6, 3)

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
