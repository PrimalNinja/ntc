# land.py - the planet: the mountains' line for all 2048 pixels of the world (jagged, Defender
# style: straight slopes up and down), and the stars. Writes ../Land.cls and land_preview.png.
# (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
# Run: python3 tools/land.py
import random, os

HERE = os.path.dirname(os.path.abspath(__file__))
WORLD = 2048
TOP, LOW = 132, 184           # the peaks can reach row 132; the valleys go down to row 184
MCOL = 0xC8                   # the mountains' colour (RRRGGGBB): orange-brown
STARC = (0x49, 0x6D, 0xB6)    # the stars' three colours (Land.Twinkle changes them)
rnd = random.Random(1981)

# ---------------------------------------------------------------- the mountains
h = []
y = 176
way = 1
while len(h) < WORLD:
    n = rnd.randrange(6, 34)
    way = -way                                # up, down, up, down: peaks and valleys
    s = way
    if rnd.random() < 0.12: s, n, way = 0, rnd.randrange(2, 6), -way
    elif rnd.random() < 0.3: n //= 3
    if y < TOP + 10: s = 1
    if y > LOW - 6: s = -1
    for _ in range(n):
        if len(h) >= WORLD: break
        y = max(TOP, min(LOW, y + s))
        h.append(y)
# join the end to the start: a slope from where it got to back to the first height
k = WORLD - 1
target = h[0]
while abs(h[k] - target) > (WORLD - 1 - k) and k > 0: k -= 1
for x in range(k, WORLD):
    d = target - h[x - 1]
    h[x] = h[x - 1] + (1 if d > 0 else -1 if d < 0 else 0)
assert abs(h[-1] - h[0]) <= 1

# ---------------------------------------------------------------- the stars (rows 34-110)
stars = []
seen = set()
while len(stars) < 70:
    x, yy = rnd.randrange(256), rnd.randrange(34, 111)
    if (x, yy) in seen: continue
    seen.add((x, yy))
    stars.append((x, yy, STARC[len(stars) % 3]))

def dbs(d, per=16):
    return '\n'.join('            db ' + ', '.join(str(v) for v in d[k:k + per]) for k in range(0, len(d), per))

cls = r"""' Land - the planet on Layer 2. Made by tools/land.py (don't edit: change that and run it).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The mountains are a line, 2048 pixels long, round the whole planet. Layer 2's column (x And 255)
' holds world x; only the columns that come into view are drawn (View), and the copper scrolls the
' bottom of the screen (from line 112) by the view's x, the stars (from line 32) by a quarter of
' it. Kill 1: the planet's gone (no mountains); Kill 0: back.
' A frame:  Land.View camX ... Frame : Land.Upload
Option Explicit

Public Const MTOP = 112           ' the mountains' rows: 112-191

Private dead As Integer, ready As Integer, tcam As Integer
Private cop(15) As Byte

Public Sub Init()
  Nx.Reg &H70, 0
  Nx.Reg &H12, 16
  Nx.Reg &H1C, 1
  Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0
  Wipe
  Stars
  Out &H123B, 2
  dead = 0 : ready = 0
End Sub

Public Sub Kill(ByVal d As Integer)
  dead = d : ready = 0
End Sub

' the mountains' row at world x
Public Function Height(ByVal wx As Integer) As Integer
  Height = Peek(LandH() + (wx And 2047))
End Function

' the view's left edge is world x cx: the new columns drawn, the copper told
Public Sub View(ByVal cx As Integer)
  Dim d As Integer, k As Integer
  If ready = 0 Then
    For k = 0 To 255
      Col cx + k
    Next
  Else
    d = (cx - tcam) And 2047
    If d >= 1024 Then d = d - 2048
    If d >= 256 Or d <= -256 Then
      For k = 0 To 255
        Col cx + k
      Next
    ElseIf d > 0 Then
      For k = 256 - d To 255
        Col cx + k
      Next
    ElseIf d < 0 Then
      For k = 0 To -d - 1
        Col cx + k
      Next
    End If
  End If
  ready = 1 : tcam = cx
  cop(0) = &H80 : cop(1) = 0                ' line 0 (the scanner): no scroll
  cop(2) = &H16 : cop(3) = 0
  cop(4) = &H80 : cop(5) = 32               ' line 32: the stars, a quarter as fast
  cop(6) = &H16 : cop(7) = (cx \ 4) And 255
  cop(8) = &H80 : cop(9) = MTOP             ' line 112: the mountains
  cop(10) = &H16 : cop(11) = cx And 255
  cop(12) = &HFF : cop(13) = &HFF
End Sub

' the copper list to the hardware (straight after Frame)
Public Sub Upload()
#asm
            ld bc, #243B
            ld a, #61
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #62
            out (c), a
            inc b
            xor a
            out (c), a              ; stopped, index 0
            dec b
            ld a, #60
            out (c), a
            inc b
            ld hl, {cop}
            ld e, 14
ln_cop:
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, ln_cop
            dec b
            ld a, #62
            out (c), a
            inc b
            ld a, #C0
            out (c), a              ; start: from 0, again at each frame
#endasm
End Sub

' the stars twinkle: t picks which of the three colours is bright
Public Sub Twinkle(ByVal t As Integer)
  Nx.PalEntry 1, %(s0)d, &H6D
  Nx.PalEntry 1, %(s1)d, &H6D
  Nx.PalEntry 1, %(s2)d, &H6D
  Select Case t Mod 3
    Case 0
      Nx.PalEntry 1, %(s0)d, &HFF
    Case 1
      Nx.PalEntry 1, %(s1)d, &HB6
    Case Else
      Nx.PalEntry 1, %(s2)d, &HDB
  End Select
End Sub

' the address of the heights
Private Function LandH() As Integer
#asm
            pop hl
            ld de, fn_land_stars_ln_h
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' one column: world x wx into Layer 2's column (wx And 255), rows 112-191: the line between this
' x's height and the next's (2 pixels thick), the rest black
Private Sub Col(ByVal wx As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld a, (hl)
            and 7
            ld d, a                 ; DE = wx And 2047
            ld a, e
            ld (ln_x + 1), a        ; the column
            ld hl, fn_land_stars_ln_h      ; (the heights, in Stars)
            add hl, de
            ld b, (hl)              ; this height
            inc de
            ld a, d
            and 7
            ld d, a
            ld hl, fn_land_stars_ln_h      ; (the heights, in Stars)
            add hl, de
            ld c, (hl)              ; the next
            ld a, b
            cp c
            jr c, ln_ord
            ld b, c
            ld c, a                 ; B = the higher (smaller y), C = the lower
ln_ord:
            inc c
            inc c                   ; the line: rows B .. C + 1
            ld a, ({dead})
            or a
            jr z, ln_alive
            ld b, 255
            ld c, 0                 ; no planet: nothing
ln_alive:
            ld a, b
            ld (ln_lo + 1), a
            ld a, c
            ld (ln_hi + 1), a
            ld e, 128               ; the row (the peaks never reach above 132)
ln_page:
            ld a, e
            rlca
            rlca
            rlca
            and 7
            add a, 32
            ld (ln_pg + 1), a
            ld bc, #243B            ; its 8K page into slot 6 (no push: SP is NTC's thread)
            ld a, #56
            out (c), a
            inc b
ln_pg:
            ld a, 0
            out (c), a
            ld a, e
            and 31
            or #C0
            ld h, a
ln_x:
            ld l, 0
ln_row:
            ld a, e
ln_lo:
            cp 0
            jr c, ln_blank
ln_hi:
            cp 0
            jr nc, ln_blank
            ld (hl), %(mcol)d
            jr ln_next
ln_blank:
            ld (hl), 0
ln_next:
            inc h
            inc e
            ld a, e
            cp 192
            jr z, ln_done
            and 31
            jr nz, ln_row
            jr ln_page
ln_done:
            ld bc, #243B            ; slot 6 back to bank 5's first half
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
#endasm
End Sub

' all of Layer 2 black
Private Sub Wipe()
#asm
            ld a, 32
ln_wp:
            ld (ln_wpg + 1), a
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
ln_wpg:
            ld a, 0
            out (c), a
            ld hl, #C000
            ld de, #C001
            ld bc, 8191
            ld (hl), 0
            ldir
            ld a, (ln_wpg + 1)
            inc a
            cp 38
            jr nz, ln_wp
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
#endasm
End Sub

' the stars in (x, y, colour)
Private Sub Stars()
#asm
            ld hl, ln_st
            ld a, %(nst)d
ln_sl:
            ld (ln_cnt + 1), a
            ld e, (hl)              ; x
            inc hl
            ld d, (hl)              ; y
            inc hl
            ld a, d
            rlca
            rlca
            rlca
            and 7
            add a, 32
            ld (ln_spg + 1), a
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
ln_spg:
            ld a, 0
            out (c), a
            ld a, d
            and 31
            or #C0
            ld d, a
            ld a, (hl)
            inc hl
            ld (de), a
ln_cnt:
            ld a, 0
            dec a
            jr nz, ln_sl
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            jp ln_end
ln_st:
%(stars)s
ln_h:
%(heights)s
ln_end:
#endasm
End Sub
""" % {'mtop': 112, 'mcol': MCOL, 'nst': len(stars), 's0': STARC[0], 's1': STARC[1], 's2': STARC[2],
       'stars': dbs([v for s in stars for v in s], 15), 'heights': dbs(h)}
open(os.path.join(HERE, '..', 'Land.cls'), 'w').write(cls)

try:
    from PIL import Image
    im = Image.new('RGB', (WORLD, 192))
    for x in range(WORLD):
        for yy in range(min(h[x], h[(x + 1) % WORLD]), max(h[x], h[(x + 1) % WORLD]) + 2):
            if yy < 192: im.putpixel((x, yy), (200, 80, 0))
    for (x, yy, cc) in stars:
        for k in range(8): im.putpixel((x + k * 256, yy), (200, 200, 200))
    im.save(os.path.join(HERE, 'land_preview.png'))
except ImportError:
    pass
print('Land.cls: %d heights, %d stars' % (len(h), len(stars)))
