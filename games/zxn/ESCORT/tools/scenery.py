# scenery.py - the sky for ESCORT: the top 80 rows of Layer 2 (sky, clouds, mountains, the far
# hills down to the horizon), 256 wide and joining up end to end (the hardware scrolls it round as
# the road bends), packed in runs. Writes ../Scenery.cls and scenery_preview.png.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# Run: python3 tools/scenery.py
# The colours are the Layer 2 palette's own (RRRGGGBB), all 32 or more: 0-31 are the road's.
import math, random, os

HERE = os.path.dirname(os.path.abspath(__file__))
W, H = 256, 80

def col(r, g, b):
    r = max(1, min(7, int(round(r))))          # red at least 1: the values under 32 are the road's
    v = (r << 5) | (max(0, min(7, int(round(g)))) << 2) | max(0, min(3, int(round(b))))
    return 0xE2 if v == 0xE3 else v            # (#E3 is see-through)

img = [[0] * W for _ in range(H)]
rnd = random.Random(7)

# the sky: deep blue at the top, pale at the horizon
for y in range(H):
    t = y / (H - 1)
    c = col(1 + 3 * t, 2 + 4 * t, 3)
    for x in range(W): img[y][x] = c
# clouds
for (cx, cy, n) in ((30, 14, 5), (110, 24, 4), (170, 10, 6), (225, 28, 3)):
    for k in range(n):
        x0 = cx + k * 7 + rnd.randrange(-2, 3); y0 = cy + rnd.randrange(-2, 2); r = 5 + rnd.randrange(0, 4)
        for y in range(y0 - r, y0 + r):
            for x in range(x0 - 2 * r, x0 + 2 * r):
                if ((x - x0) / 2.0) ** 2 + (y - y0) ** 2 < r * r and 0 <= y < H:
                    img[y][x % W] = col(7, 7, 3) if y < y0 else col(5, 6, 3)

def ridge(base, amp, waves, colour, cap=None):
    for x in range(W):
        h = base
        for (a, f, p) in waves:
            h += amp * a * math.sin(2 * math.pi * (f * x / W) + p)
        top = int(round(H - h))
        for y in range(max(0, top), H):
            img[y][x] = colour
        if cap and h > cap[0]:
            for y in range(max(0, top), min(H, top + int((h - cap[0]) * 0.6) + 1)):
                img[y][x] = cap[1]

# far mountains (with snow), nearer blue hills, then green hills to the horizon
ridge(34, 10, ((1.0, 3, 0.3), (0.5, 7, 1.1), (0.3, 13, 2.0)), col(3, 3, 3), (36, col(7, 7, 3)))
ridge(22, 6, ((1.0, 4, 2.0), (0.6, 9, 0.4), (0.3, 17, 1.0)), col(2, 3, 2))
ridge(10, 3, ((1.0, 5, 1.0), (0.5, 11, 2.5)), col(1, 4, 1))
for x in range(W): img[H - 1][x] = col(1, 3, 0)

# the runs, row by row (a run never crosses a row's end: up to 255 long)
data = []
for y in range(H):
    x = 0
    while x < W:
        c = img[y][x]; n = 1
        while x + n < W and img[y][x + n] == c and n < 255: n += 1
        data += [n, c]; x += n

def dbs(d, per=16):
    return '\n'.join('            db ' + ', '.join(str(v) for v in d[i:i + per]) for i in range(0, len(d), per))

cls = """' Scenery - the sky for ESCORT: the top 80 rows of Layer 2 (sky, clouds, mountains, the far
' hills), made by tools/scenery.py (don't edit: change that and run it).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' Draw: the runs unpacked into rows 0-79 of Layer 2 (bank 16, pages 32-34, through MMU slot 6).
Option Explicit

Private pg As Integer

Public Sub Draw()
#asm
            ld hl, up_data
            ld a, 32
            ld ({pg}), a
up_page:
            ld bc, #243B            ; this page into slot 6
            ld a, #56
            out (c), a
            inc b
            ld a, ({pg})
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
            ld a, ({pg})
            cp 34                   ; the third page: only its first 16 rows (64-79)
            jr nz, up_full
            ld a, d
            cp #D0
            jr z, up_end
            jr up_run
up_full:
            ld a, d
            cp #E0                  ; the page is full (32 rows)
            jr nz, up_run
            ld a, ({pg})
            inc a
            ld ({pg}), a
            jr up_page
up_end:
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
open(os.path.join(HERE, '..', 'Scenery.cls'), 'w').write(cls)

try:
    from PIL import Image
    def rgb(v): return ((v >> 5) * 255 // 7, ((v >> 2) & 7) * 255 // 7, (v & 3) * 255 // 3)
    im = Image.new('RGB', (W * 2, H))
    for y in range(H):
        for x in range(W * 2): im.putpixel((x, y), rgb(img[y][x % W]))
    im.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(HERE, 'scenery_preview.png'))
except ImportError:
    pass
print('Scenery.cls: %d bytes of runs' % len(data))
