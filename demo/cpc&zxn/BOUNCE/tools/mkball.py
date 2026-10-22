# mkball.py - BOUNCE's ball: draws gfx/ball.png (16 x 16, if it isn't there), then makes
# BallGfx.cls from it - the same picture two ways:
#   the Next: a hardware sprite pattern (256 bytes, 8 bits a pixel, #E3 see-through)
#   the CPC:  a COMPILED sprite - Z80 code that writes the ball's bytes straight into the screen
#             (mode 2), no loops, no data read, no masks. It is "plain + border": the ball with
#             a border of paper round it, as wide as the ball moves in two frames (two frames:
#             each of the two screens last saw it two frames ago), so drawing it wipes where it
#             was - no clearing at all. (Fine while nothing is behind the balls.)
#   python3 tools/mkball.py         (run it after changing gfx/ball.png)
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
PNG = os.path.join(ROOT, 'gfx', 'ball.png')
BX, BY = 2, 4          # the border: 2 bytes (16 mode 2 pixels = 8 logical) each side, 4 lines above / below

if not os.path.exists(PNG):
    # the art, drawn in code: a ball, a shine on it
    im = Image.new('RGBA', (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((0, 0, 15, 15), fill=(40, 120, 255, 255))
    d.ellipse((2, 2, 13, 13), fill=(80, 170, 255, 255))
    d.ellipse((4, 3, 7, 6), fill=(255, 255, 255, 255))
    im.save(PNG)

im = Image.open(PNG).convert('RGBA')
assert im.size == (16, 16), 'ball.png must be 16 x 16'
px = im.load()

def rgb332(r, g, b):
    return (r * 7 // 255) << 5 | (g * 7 // 255) << 2 | (b * 3 // 255)

# ---- the Next: 8 bit pattern (the colour IS the RRRGGGBB value: the sprite palette entries for
# the colours used are set to themselves, so no palette file is needed)
pat = []
for y in range(16):
    for x in range(16):
        r, g, b, a = px[x, y]
        c = 0xE3 if a < 128 else rgb332(r, g, b)
        if c == 0xE3 and a >= 128: c = 0xE2           # (a real colour that happens to be #E3)
        pat.append(c)
cols = sorted(set(c for c in pat if c != 0xE3))

# ---- the CPC: mode 2 (1 bit a pixel, the left pixel bit 7); a logical pixel is 2 mode 2 pixels,
# so 16 logical pixels are 4 bytes. Ink where the ball isn't see-through, but the shine (white)
# left as paper so it looks round in one colour
rows = []
for y in range(16):
    line = []
    for xb in range(4):
        v = 0
        for k in range(4):                  # 4 logical pixels a byte
            r, g, b, a = px[xb * 4 + k, y]
            on = a >= 128 and not (r > 200 and g > 200 and b > 200)
            if on: v |= 3 << (6 - k * 2)
        line.append(v)
    rows.append(line)
W = 4 + BX * 2
H = 16 + BY * 2
grid = [[0] * W for _ in range(H)]
for y in range(16):
    for x in range(4):
        grid[y + BY][x + BX] = rows[y][x]

A = []      # the compiled code (assembler lines, in the #E200 block)
A.append('@cb_draw:                ; HL = the top left byte (border included), in the #4000 window')
A.append('            ld bc, (cs_win)         ; the back screen into #4000-#7FFF (C1 or C3)')
A.append('            out (c), c')
A.append('            ld bc, #FF00            ; B = all ink, C = all paper (the commonest bytes)')
for y in range(H):
    A.append('            ld d, h                 ; line %d' % y)
    A.append('            ld e, l')
    for x in range(W):
        v = grid[y][x]
        if v == 0: A.append('            ld (hl), c')
        elif v == 0xFF: A.append('            ld (hl), b')
        else: A.append('            ld (hl), #%02X' % v)
        if x < W - 1: A.append('            inc hl')
    A.append('            ex de, hl')
    if y < H - 1:
        # the next pixel line: +#800; past the 8th line of a character row (bits 11-13 back to
        # 0): back #4000 and on 80 bytes (#50) - the next character row
        A.append('            ld a, h')
        A.append('            add a, 8')
        A.append('            ld h, a')
        A.append('            and #38')
        A.append('            jr nz, $ + 10')
        A.append('            ld a, l')
        A.append('            add a, #50')
        A.append('            ld l, a')
        A.append('            ld a, h')
        A.append('            adc a, #C0')
        A.append('            ld h, a')
A.append('            ld bc, (cs_own)         ; the slot\'s own bank back (C2)')
A.append('            out (c), c')
A.append('            ret')

L = []
L.append("' BallGfx - BOUNCE's ball, made by tools/mkball.py from gfx/ball.png: don't edit, run the tool.")
L.append("' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License")
L.append("' ZxnLoad: the Next's sprite pattern 0 and the sprite palette entries it uses.")
L.append("' CpcInstall: the CPC's compiled ball copied to #E200 (CpcScr calls it there: see CpcScr.cls).")
L.append("Option Explicit")
L.append("Public Const W = %d          ' the CPC drawing's size: bytes across, lines (the border in)" % W)
L.append("Public Const H = %d" % H)
L.append("Public Const BX = %d         ' its border: bytes left, lines above" % BX)
L.append("Public Const BY = %d" % BY)
L.append("Private hsp As Integer")
L.append("")
L.append("Public Sub ZxnLoad()")
L.append("#asm")
L.append("            ld ({hsp}), sp")
L.append("            ld sp, (ntc_csp)")
L.append("            ld bc, #303B            ; pattern 0")
L.append("            xor a")
L.append("            out (c), a")
L.append("            ld hl, bg_pat")
L.append("            ld bc, #005B            ; 256 bytes to port #5B (B = 0: 256 times)")
L.append("            otir")
L.append("            ld bc, #243B            ; the sprite palette entries: each colour used = itself")
L.append("            ld a, #43")
L.append("            out (c), a")
L.append("            inc b")
L.append("            in a, (c)")
L.append("            ld (bg_43), a           ; (the palette control as it was: put back after)")
L.append("            and #8F")
L.append("            or #20                  ; the first sprite palette, for writing")
L.append("            out (c), a")
L.append("            ld hl, bg_cols")
L.append("@bg_lp:")
L.append("            ld a, (hl)")
L.append("            or a")
L.append("            jr z, bg_done")
L.append("            ld bc, #243B")
L.append("            ld e, #40")
L.append("            out (c), e")
L.append("            inc b")
L.append("            out (c), a              ; the index")
L.append("            dec b")
L.append("            ld e, #41")
L.append("            out (c), e")
L.append("            inc b")
L.append("            out (c), a              ; its colour: itself")
L.append("            inc hl")
L.append("            jr bg_lp")
L.append("@bg_done:")
L.append("            ld bc, #243B")
L.append("            ld a, #43")
L.append("            out (c), a")
L.append("            inc b")
L.append("            ld a, (bg_43)")
L.append("            out (c), a")
L.append("            ld sp, ({hsp})")
L.append("            jp bg_end")
L.append("@bg_43:      db 0")
L.append("@bg_cols:    db " + ', '.join('#%02X' % c for c in cols if c) + ', 0')
L.append("@bg_pat:")
for k in range(0, 256, 16):
    L.append("            db " + ', '.join('#%02X' % v for v in pat[k:k + 16]))
L.append("@bg_end:")
L.append("#endasm")
L.append("End Sub")
L.append("")
L.append("Public Sub CpcInstall()")
L.append("#asm")
L.append("            ld hl, cb_src")
L.append("            ld de, #E200")
L.append("            ld bc, cb_after - cb_src")
L.append("            ldir")
L.append("            jp cb_end")
L.append("@cb_src:")
L.append("            DISP #E200              ; assembled for #E200, where it runs")
L.extend(A)
L.append("            ENT")
L.append("@cb_after:")
L.append("            ASSERT #E200 + (cb_after - cb_src) <= #EF00, \"the compiled ball must end below the stub (#EF00)\"")
L.append("@cb_end:")
L.append("#endasm")
L.append("End Sub")
open(os.path.join(ROOT, 'BallGfx.cls'), 'w').write('\n'.join(L) + '\n')
print('BallGfx.cls: Next pattern (%d colours), CPC compiled ball %d x %d bytes, %d lines of code' % (len(cols), W, H, len(A)))
