' Cpc - software sprites on the Amstrad CPC (464, 664, 6128; no sprite hardware): mode 0 (160 x
' 200, 16 pens), each sprite masked onto the screen with what was under it kept and put back, on
' two screens (#C000 and #4000, NTC's Graphics double buffering: one shown while the other is
' drawn on, so nothing flickers or tears).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' A sprite is 8 x 16 mode 0 pixels (they're twice as wide as high: it looks square), drawn 5
' bytes (10 pixels) wide: its pattern has each frame twice, on an even pixel and on an odd one
' (shifted right one), each 16 rows of 5 byte pairs (mask: 1 bits keep the screen; data) - 320
' bytes a frame (tools/art.py makes them). Positions are in mode 0 pixels: x 0-150, y 0-184
' keeps a sprite on the screen (Bounds; there's no clipping).
'
' The game library's calls, the same in every chip's class (Zxn, Cpc, Asic, Tms9918, V9938,
' V9990): Init, Pattern, Put, Hide, Anim, Move, Bounds, Frame, X, Y. Cpc's own: Inks.
' Text: the platform's own (Mode, Cls, Print: in pen 1) - print first, then Init (it copies the
' screen to the second one).
' Vectors (mode 0, with Init's two screens): Begin / Keep / Spans / Show fill lines of polygons on the
' screen not shown (PenByte gives a pen's byte), Show swaps the screens at the frame.
Option Explicit

Public Const Slots = 8             ' sprites (each costs time: 8 fit in a frame)

Private sx(7) As Integer, sy(7) As Integer, vx(7) As Integer, vy(7) As Integer
Private pt(7) As Integer, af(7) As Integer, ac(7) As Integer, ad(7) As Integer, at(7) As Integer
Private son(7) As Integer, pat(15) As Integer
Private bx0 As Integer, by0 As Integer, bx1 As Integer, by1 As Integer
Private dn(15) As Integer, dc(1) As Integer       ' what was drawn on each screen: its addresses
Private vx0(1) As Integer, vy0(1) As Integer, vx1(1) As Integer, vy1(1) As Integer   ' vectors drawn on each screen
Private bg(1279) As Byte                           ' and what was under it (80 bytes each)

' Inks a: pens 0-15 from 16 bytes at address a (the gate array's hardware colour numbers); the
' border as pen 0
Public Sub Inks(ByVal a As Integer)
  Dim i As Integer
  For i = 0 To 15
    Out &H7F00, i
    Out &H7F00, &H40 Or Peek(a + i)
  Next
  Out &H7F00, &H10
  Out &H7F00, &H40 Or Peek(a)
End Sub

' Init: double buffering on (what's on the screen copied to the second one), nothing drawn
Public Sub Init()
  Dim i As Integer
  For i = 0 To Slots - 1
    son(i) = 0 : vx(i) = 0 : vy(i) = 0 : ac(i) = 0
  Next
  dc(0) = 0 : dc(1) = 0
  bx0 = 0 : by0 = 0 : bx1 = 150 : by1 = 184
  vx0(0) = 0 : vx1(0) = -1 : vx0(1) = 0 : vx1(1) = -1
  Graphics.DoubleBuffer 1
End Sub

' Pattern n, a: pattern n is the frame at address a (320 bytes: on an even pixel, then an odd one)
Public Sub Pattern(ByVal n As Integer, ByVal a As Integer)
  pat(n) = a
End Sub

Public Sub Put(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal p As Integer)
  sx(n) = x : sy(n) = y : pt(n) = p : son(n) = 1 : ac(n) = 0
End Sub

Public Sub Hide(ByVal n As Integer)
  son(n) = 0
End Sub

Public Sub Anim(ByVal n As Integer, ByVal first As Integer, ByVal count As Integer, ByVal delay As Integer)
  af(n) = first : ac(n) = count : ad(n) = delay : at(n) = delay : pt(n) = first
End Sub

Public Sub Move(ByVal n As Integer, ByVal dx As Integer, ByVal dy As Integer)
  vx(n) = dx : vy(n) = dy
End Sub

Public Sub Bounds(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  bx0 = x0 : by0 = y0 : bx1 = x1 : by1 = y1
End Sub

Public Function X(ByVal n As Integer) As Integer
  X = sx(n)
End Function

Public Function Y(ByVal n As Integer) As Integer
  Y = sy(n)
End Function

' Frame: show the screen drawn last time (at the frame flyback), then on the other one: the
' sprites drawn there before taken off (what was under them put back, last first), each sprite
' moved and animated on, and drawn again
Public Sub Frame()
  Dim i As Integer, k As Integer, b As Integer, base As Integer, a As Integer
  Graphics.Flip
  b = Graphics.Back()
  For k = dc(b) - 1 To 0 Step -1
    Restore dn(b * 8 + k), VarPtr(bg) + (b * 8 + k) * 80
  Next
  If b Then base = &H4000 Else base = &HC000
  k = 0
  For i = 0 To Slots - 1
    If son(i) Then
      sx(i) = sx(i) + vx(i)
      If sx(i) < bx0 Then sx(i) = bx0 : vx(i) = -vx(i)
      If sx(i) > bx1 Then sx(i) = bx1 : vx(i) = -vx(i)
      sy(i) = sy(i) + vy(i)
      If sy(i) < by0 Then sy(i) = by0 : vy(i) = -vy(i)
      If sy(i) > by1 Then sy(i) = by1 : vy(i) = -vy(i)
      If ac(i) Then
        at(i) = at(i) - 1
        If at(i) <= 0 Then
          at(i) = ad(i)
          pt(i) = pt(i) + 1
          If pt(i) >= af(i) + ac(i) Then pt(i) = af(i)
        End If
      End If
      a = base + (sy(i) \ 8) * 80 + (sy(i) And 7) * 2048 + sx(i) \ 2
      Draw a, pat(pt(i)) + (sx(i) And 1) * 160, VarPtr(bg) + (b * 8 + k) * 80
      dn(b * 8 + k) = a
      k = k + 1
    End If
  Next
  dc(b) = k
End Sub

' Draw scr, src, save: a 5 x 16 byte sprite (mask, data pairs) at screen address scr, what was
' under it to save
Private Sub Draw(ByVal scr As Integer, ByVal src As Integer, ByVal save As Integer)
#asm
            pop hl              ; scr
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; src (its address: read below)
            pop bc              ; save: kept in IX
            ld (dr_ix), ix
            ld a, (bc)
            ld ixl, a
            inc bc
            ld a, (bc)
            ld ixh, a
            ld a, (hl)          ; src
            inc hl
            ld h, (hl)
            ld l, a
            ld c, 16
dr_row:     ld (dr_line), de
            ld b, 5
dr_byte:    ld a, (de)
            ld (ix+0), a
            inc ix
            and (hl)            ; the mask
            inc hl
            or (hl)             ; the sprite
            inc hl
            ld (de), a
            inc de
            djnz dr_byte
            ld de, (dr_line)
            ld a, d             ; the next line: + #800, past the 16K: + #C050 more
            add a, 8
            ld d, a
            and #38
            jr nz, dr_next
            ld a, e
            add a, #50
            ld e, a
            ld a, d
            adc a, #C0
            ld d, a
dr_next:    dec c
            jr nz, dr_row
            ld ix, (dr_ix)
            ret
dr_ix:      dw 0
dr_line:    dw 0
#endasm
End Sub

' Restore scr, save: what was under a sprite put back
Private Sub Restore(ByVal scr As Integer, ByVal save As Integer)
#asm
            pop hl              ; scr
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; save
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld c, 16
rs_row:     ld (rs_line), de
            ld b, 5
rs_byte:    ld a, (hl)
            ld (de), a
            inc hl
            inc de
            djnz rs_byte
            ld de, (rs_line)
            ld a, d
            add a, 8
            ld d, a
            and #38
            jr nz, rs_next
            ld a, e
            add a, #50
            ld e, a
            ld a, d
            adc a, #C0
            ld d, a
rs_next:    dec c
            jr nz, rs_row
            ret
rs_line:    dw 0
#endasm
End Sub

' ---- vectors (mode 0)

' PenByte(p): a mode 0 byte with both pixels pen p
Public Function PenByte(ByVal p As Integer) As Integer
  Dim r As Integer
  If p And 1 Then r = r Or &HC0
  If p And 2 Then r = r Or &H0C
  If p And 4 Then r = r Or &H30
  If p And 8 Then r = r Or &H03
  PenByte = r
End Function

' Back(): the screen being drawn on (0: #C000, 1: #4000)
Public Function Back() As Integer
  Back = Graphics.Back()
End Function

' Begin: drawing starts on the screen not shown: the box kept for it last time cleared (pen 0)
Public Sub Begin()
  Dim b As Integer, hb As Integer
  b = Graphics.Back()
  If b Then hb = &H40 Else hb = &HC0
  If vx1(b) >= vx0(b) Then ClearBox hb, vx0(b) \ 2, vy0(b), vx1(b) \ 2 - vx0(b) \ 2 + 1, vy1(b) - vy0(b) + 1
End Sub

' Keep x0, y0, x1, y1: the box about to be drawn on this screen (mode 0 pixels), to clear next time
Public Sub Keep(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  Dim b As Integer
  b = Graphics.Back()
  vx0(b) = x0 : vy0(b) = y0 : vx1(b) = x1 : vy1(b) = y1
End Sub

' ClearBox hb, bx, y, nb, ny: nb bytes from byte bx on ny lines from y set to 0, on the screen at
' hb * 256
Private Sub ClearBox(ByVal hb As Integer, ByVal bx As Integer, ByVal y As Integer, ByVal nb As Integer, ByVal ny As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (cb_hb), a
            pop hl
            ld a, (hl)
            ld (cb_bx), a
            pop hl
            ld a, (hl)
            ld (cb_y), a
            pop hl
            ld a, (hl)
            ld (cb_nb), a
            pop hl
            ld a, (hl)
            ld (cb_ny), a
cb_line:    ld a, (cb_y)
            ld c, a
            rrca
            rrca
            rrca
            and #1F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de          ; (y \ 8) * 80
            ld a, c
            and 7
            add a, a
            add a, a
            add a, a
            ld e, a
            ld a, (cb_hb)
            add a, e
            add a, h
            ld h, a             ; + (y and 7) * #800 + the screen
            ld a, (cb_bx)
            ld e, a
            ld d, 0
            add hl, de
            ld a, (cb_nb)
            ld b, a
            ld c, 0
            ld a, b             ; (8 at a time, the rest first)
            and 7
            jr z, cb_u8
cb_u1:     ld (hl), c
            inc hl
            dec a
            jr nz, cb_u1
cb_u8:     srl b
            srl b
            srl b
            jr z, cb_ud
cb_ul:
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            djnz cb_ul
cb_ud:
            ld hl, cb_y
            inc (hl)
            ld hl, cb_ny
            dec (hl)
            jr nz, cb_line
            ret
cb_hb:      db 0
cb_bx:      db 0
cb_y:       db 0
cb_nb:      db 0
cb_ny:      db 0
#endasm
End Sub

' Spans y0, y1, pb, tl, tr: lines y0-y1 filled from the left table's x to the right's (mode 0
' pixels, a byte for each line) with pen byte pb, on the screen not shown
Public Sub Spans(ByVal y0 As Integer, ByVal y1 As Integer, ByVal pb As Integer, ByVal tl As Integer, ByVal tr As Integer)
  If Graphics.Back() Then SpansP y0, y1, pb, tl, tr, &H40 Else SpansP y0, y1, pb, tl, tr, &HC0
End Sub

' Show: the screen just drawn shown at the frame; drawing goes to the other
Public Sub Show()
  Graphics.Flip
End Sub

Private Sub SpansP(ByVal y0 As Integer, ByVal y1 As Integer, ByVal pb As Integer, ByVal tl As Integer, ByVal tr As Integer, ByVal hb As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (sp_y), a
            pop hl
            ld a, (hl)
            ld (sp_y1), a
            pop hl
            ld a, (hl)
            ld (sp_pb), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sp_tl), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sp_tr), de
            pop hl
            ld a, (hl)
            ld (sp_hb), a
sp_line:    ld a, (sp_y)
            ld e, a
            ld d, 0
            ld hl, (sp_tl)
            add hl, de
            ld b, (hl)          ; b: left x
            ld hl, (sp_tr)
            add hl, de
            ld c, (hl)          ; c: right x
            ld a, c
            cp b
            jp c, sp_next       ; (left past right: nothing)
sp_ok:      ld a, e             ; hl: the line on the screen
            rrca
            rrca
            rrca
            and #1F
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de          ; (y \ 8) * 80
            ld a, (sp_y)
            and 7
            add a, a
            add a, a
            add a, a
            ld e, a
            ld a, (sp_hb)
            add a, e
            add a, h
            ld h, a             ; + (y and 7) * #800 + the screen
            ld (sp_line_at), hl
            ld a, (sp_pb)
            ld d, a             ; d: the pen byte
            bit 0, b            ; the left end on an odd pixel: that byte's right pixel only
            jr z, sp_le
            ld hl, (sp_line_at)
            ld e, b
            srl e
            ld a, l
            add a, e
            ld l, a
            jr nc, sp_c1
            inc h
sp_c1:      ld a, (hl)
            xor d
            and #55
            xor (hl)
            ld (hl), a
            inc b
sp_le:      ld a, c
            cp b
            jr c, sp_next       ; nothing left
            bit 0, c            ; the right end on an even pixel: that byte's left pixel only
            jr nz, sp_mid
            ld hl, (sp_line_at)
            ld e, c
            srl e
            ld a, l
            add a, e
            ld l, a
            jr nc, sp_c2
            inc h
sp_c2:      ld a, (hl)
            xor d
            and #AA
            xor (hl)
            ld (hl), a
            ld a, c
            or a
            jr z, sp_next
            dec c
            ld a, c
            cp b
            jr c, sp_next
sp_mid:     ld hl, (sp_line_at) ; whole bytes: from b (even) to c (odd)
            ld e, b
            srl e
            ld a, l
            add a, e
            ld l, a
            jr nc, sp_c3
            inc h
sp_c3:      ld a, c
            srl a
            sub e
            inc a
            ld b, a
            ld a, b             ; (8 at a time, the rest first)
            and 7
            jr z, sp_u8
sp_u1:     ld (hl), d
            inc hl
            dec a
            jr nz, sp_u1
sp_u8:     srl b
            srl b
            srl b
            jr z, sp_ud
sp_ul:
            ld (hl), d
            inc hl
            ld (hl), d
            inc hl
            ld (hl), d
            inc hl
            ld (hl), d
            inc hl
            ld (hl), d
            inc hl
            ld (hl), d
            inc hl
            ld (hl), d
            inc hl
            ld (hl), d
            inc hl
            djnz sp_ul
sp_ud:
sp_next:    ld a, (sp_y1)
            ld e, a
            ld a, (sp_y)
            cp e
            ret z
            inc a
            ld (sp_y), a
            jp sp_line
sp_y:       db 0
sp_y1:      db 0
sp_pb:      db 0
sp_hb:      db 0
sp_tl:      dw 0
sp_tr:      dw 0
sp_line_at: dw 0
#endasm
End Sub
