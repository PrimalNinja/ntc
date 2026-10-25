' Zxn - the ZX Spectrum Next's own video (its FPGA, no named chip): 128 hardware sprites,
' 16 x 16, 8 bit patterns (#E3 see-through), over the tilemap the zxn platform prints on.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The game library's calls, the same in every chip's class (Zxn, Cpc, Asic, Tms9918, V9938,
' V9990): Init, Pattern, Put, Hide, Anim, Move, Bounds, Frame, X, Y. A sprite does what it does
' on its own: Anim gives it a run of patterns to step through, Move a speed (it bounces inside
' Bounds); Frame waits for the frame, sends every sprite to the hardware, then moves them on.
' Text, Cls and Mode are the zxn platform's own (Print, Cls, Mode 1 = 40 x 32, 2 = 80 x 32).
'
' Coordinates are the Next's sprite ones: 0, 0 is the top left of the whole 320 x 256 picture
' (the border included); the 256 x 192 paper is 32 - 287 across, 32 - 223 down.
'
' Vectors: Layer 2, 256 x 192, a byte a pixel (256 colours: the default palette is RGB332, and
' Palette sets any entry from 512), two screens (16K banks 12 and 15: NTC's program has 8-10)
' shown in turn. Mode 2 sets it up (with the build's StdIO_Zxn.cls, Print, Cls, Locate and Mode
' come here and the text is drawn on both screens, white on dark blue); Spans / Show
' fill lines of polygons on the screen not shown, mapping its 8K pages in at #C000 (slot 6)
' while they draw.
Option Explicit

Public Const Slots = 16            ' sprites this class keeps (the hardware has 128)

Private sx(15) As Integer, sy(15) As Integer, vx(15) As Integer, vy(15) As Integer
Private pt(15) As Integer, af(15) As Integer, ac(15) As Integer, ad(15) As Integer, at(15) As Integer
Private son(15) As Integer
Private bx0 As Integer, by0 As Integer, bx1 As Integer, by1 As Integer
Private bk As Integer, cx As Integer, cy As Integer, fontAt As Integer   ' Layer 2: the screen drawn on
Private ex0(1) As Integer, ey0(1) As Integer, ex1(1) As Integer, ey1(1) As Integer   ' drawn on each

' Init: every sprite hidden, sprites on (over the border too, on top of the other layers)
Public Sub Init()
  Dim i As Integer
  For i = 0 To 127
    Out &H303B, i
    Out &H57, 0 : Out &H57, 0 : Out &H57, 0 : Out &H57, 0
  Next
  For i = 0 To Slots - 1
    son(i) = 0 : vx(i) = 0 : vy(i) = 0 : ac(i) = 0
  Next
  Out &H243B, &H15 : Out &H253B, 3          ' sprites on, over the border, S L U order
  Out &H243B, &H4B : Out &H253B, &HE3       ' the see-through colour
  bx0 = 32 : by0 = 32 : bx1 = 271 : by1 = 207
End Sub

' Pattern n: 256 bytes (16 x 16, a byte a pixel) from address a into the sprite RAM
Public Sub Pattern(ByVal n As Integer, ByVal a As Integer)
#asm
            pop hl              ; n
            ld a, (hl)
            pop hl              ; a
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            ld bc, #303B
            out (c), a          ; the pattern slot to write
            ld bc, #005B        ; B = 0: 256 bytes
            otir
#endasm
End Sub

' Put n, x, y, p: sprite n shown at x, y with pattern p
Public Sub Put(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal p As Integer)
  sx(n) = x : sy(n) = y : pt(n) = p : son(n) = 1 : ac(n) = 0
End Sub

Public Sub Hide(ByVal n As Integer)
  son(n) = 0
End Sub

' Anim n, first, count, delay: sprite n steps through patterns first .. first + count - 1, one
' every delay frames, round and round
Public Sub Anim(ByVal n As Integer, ByVal first As Integer, ByVal count As Integer, ByVal delay As Integer)
  af(n) = first : ac(n) = count : ad(n) = delay : at(n) = delay : pt(n) = first
End Sub

' Move n, dx, dy: sprite n moves that much every frame, bouncing off the Bounds
Public Sub Move(ByVal n As Integer, ByVal dx As Integer, ByVal dy As Integer)
  vx(n) = dx : vy(n) = dy
End Sub

' Bounds x0, y0, x1, y1: the box the moving sprites bounce in (their top left corner's range)
Public Sub Bounds(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  bx0 = x0 : by0 = y0 : bx1 = x1 : by1 = y1
End Sub

Public Function X(ByVal n As Integer) As Integer
  X = sx(n)
End Function

Public Function Y(ByVal n As Integer) As Integer
  Y = sy(n)
End Function

' Frame: wait for the frame, every sprite to the hardware, then each moves and animates on
Public Sub Frame()
  Dim i As Integer, b As Integer
  WaitFrame
  For i = 0 To Slots - 1
    Out &H303B, i
    If son(i) Then
      Out &H57, sx(i) And 255
      Out &H57, sy(i)
      Out &H57, (sx(i) \ 256) And 1          ' palette offset 0, no mirror, X bit 8
      Out &H57, &H80 Or pt(i)                ' visible, the pattern
    Else
      Out &H57, 0 : Out &H57, 0 : Out &H57, 0 : Out &H57, 0
    End If
  Next
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
    End If
  Next
End Sub

' (the platform's frame wait: the Frame statement's)
Private Sub WaitFrame()
#asm
            jp kw_frame
#endasm
End Sub

' ---- Layer 2: vectors

Private Sub NReg(ByVal r As Integer, ByVal v As Integer)
  Out &H243B, r : Out &H253B, v
End Sub

' Page(b): the first 8K page of screen b (0: bank 12, 1: bank 15)
Private Function Page(ByVal b As Integer) As Integer
  If b Then Page = 30 Else Page = 24
End Function

' Mode m: 2 Layer 2, 256 x 192, 256 colours, two screens; both cleared (the only mode here: the
' text modes are the platform's own)
Public Sub Mode(ByVal m As Integer)
  If fontAt = 0 Then fontAt = Art.Font()
  NReg 7, 3                      ' 28MHz
  NReg &H70, 0                   ' Layer 2 256 x 192
  NReg &H16, 0 : NReg &H17, 0    ' no scroll
  NReg &H1C, 1                   ' the Layer 2 clip window: all of it
  NReg &H18, 0 : NReg &H18, 255 : NReg &H18, 0 : NReg &H18, 191
  NReg &H15, 0                   ' sprites, Layer 2, ULA (and tilemap): Layer 2 covers the text
  NReg &H12, 12                  ' screen 0 shown
  Out &H123B, 2                  ' Layer 2 on
  bk = 1
  ex0(0) = 0 : ex1(0) = -1 : ex0(1) = 0 : ex1(1) = -1
  Cls
End Sub

' Palette n, r, g, b: Layer 2's colour n from 512 (each part 0-7)
Public Sub Palette(ByVal n As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
  NReg &H43, &H10                ' Layer 2's first palette
  NReg &H40, n
  NReg &H44, r * 32 + g * 4 + b \ 2
  NReg &H44, b And 1
End Sub

Public Sub Cls()
  BoxP 0, 0, 127, 191, 2, Page(0)          ' (in halves: a line's fill takes up to 255)
  BoxP 128, 0, 255, 191, 2, Page(0)
  BoxP 0, 0, 127, 191, 2, Page(1)
  BoxP 128, 0, 255, 191, 2, Page(1)
  cx = 0 : cy = 0
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  cx = x - 1 : cy = y - 1
End Sub

Public Sub PutStr(ByVal s As String Max 255)
  Dim i As Integer, c As Integer
  For i = 1 To Len(s)
    If cx >= 32 Then NewLine
    c = Asc(Mid$(s, i, 1))
    If c < 32 Or c > 126 Then c = 32
    GlyphP Page(0) + cy \ 4, (cy And 3) * 2048 + cx * 8, fontAt + (c - 32) * 8
    GlyphP Page(1) + cy \ 4, (cy And 3) * 2048 + cx * 8, fontAt + (c - 32) * 8
    cx = cx + 1
  Next
End Sub

Public Sub NewLine()
  cx = 0
  cy = cy + 1
  If cy > 23 Then cy = 23
End Sub

' Back(): the screen being drawn on (0 or 1)
Public Function Back() As Integer
  Back = bk
End Function

' Begin: drawing starts on the screen not shown: the box kept for it last time cleared
Public Sub Begin()
  If ex1(bk) >= ex0(bk) Then BoxP ex0(bk), ey0(bk), ex1(bk), ey1(bk), 2, Page(bk)
End Sub

' Keep x0, y0, x1, y1: the box about to be drawn on this screen, to clear next time
Public Sub Keep(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  ex0(bk) = x0 : ey0(bk) = y0 : ex1(bk) = x1 : ey1(bk) = y1
End Sub

' Spans y0, y1, colour, tl, tr: lines y0-y1 filled from the left table's x to the right's (a byte
' for each line), on the screen not shown
Public Sub Spans(ByVal y0 As Integer, ByVal y1 As Integer, ByVal c As Integer, ByVal tl As Integer, ByVal tr As Integer)
  SpansP y0, y1, c, tl, tr, Page(bk)
End Sub

' Show: at the frame, the screen just drawn shown; drawing goes to the other
Public Sub Show()
  WaitFrame
  If bk Then NReg &H12, 15 Else NReg &H12, 12
  bk = 1 - bk
End Sub

' GlyphP page, offset, src: a character (8 rows of 1 bit at src) as Layer 2 bytes (white on dark
' blue) at offset in 8K page page
Private Sub GlyphP(ByVal pg As Integer, ByVal off As Integer, ByVal src As Integer)
#asm
            pop hl
            ld a, (hl)
            ld bc, #243B
            ld e, #56
            out (c), e
            inc b
            out (c), a          ; the page in at #C000
            pop hl
            ld e, (hl)
            inc hl
            ld a, (hl)
            or #C0
            ld d, a             ; de: where
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a             ; hl: the font
            ld c, 8
gl_row:     ld b, 8
            ld a, (hl)
            inc hl
            ld (gl_bits), a
gl_px:      ld a, (gl_bits)
            rlca
            ld (gl_bits), a
            ld a, 2             ; dark blue ...
            jr nc, gl_bg
            ld a, #FF           ; ... or white
gl_bg:      ld (de), a
            inc e
            djnz gl_px
            ld a, e             ; the next row: 256 on, back 8
            sub 8
            ld e, a
            inc d
            dec c
            jr nz, gl_row
            ld bc, #243B        ; the screen's page back
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ret
gl_bits:    db 0
#endasm
End Sub

' BoxP x0, y0, x1, y1, colour, page: a box filled on the screen whose first page is page
Private Sub BoxP(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer, ByVal c As Integer, ByVal pg As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (bx_x0), a
            pop hl
            ld a, (hl)
            ld (bx_y), a
            pop hl
            ld a, (hl)
            ld (bx_x1), a
            pop hl
            ld a, (hl)
            ld (bx_y1), a
            pop hl
            ld a, (hl)
            ld (bx_c), a
            pop hl
            ld a, (hl)
            ld (bx_pg), a
bx_line:    ld a, (bx_y)        ; the line's page in at #C000
            rlca
            rlca
            rlca
            and 7
            ld e, a
            ld a, (bx_pg)
            add a, e
            ld bc, #243B
            ld e, #56
            out (c), e
            inc b
            out (c), a
            ld a, (bx_y)
            and 31
            or #C0
            ld h, a
            ld a, (bx_x0)
            ld l, a
            ld a, (bx_x1)
            sub l
            inc a
            ld b, a             ; (1-255)
            ld a, (bx_c)
            ld c, a
            ld a, b             ; (8 at a time, the rest first)
            and 7
            jr z, bx_u8
bx_u1:     ld (hl), c
            inc l
            dec a
            jr nz, bx_u1
bx_u8:     srl b
            srl b
            srl b
            jr z, bx_ud
bx_ul:
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            djnz bx_ul
bx_ud:
            ld a, (bx_y1)
            ld e, a
            ld a, (bx_y)
            cp e
            jr z, bx_done
            inc a
            ld (bx_y), a
            jr bx_line
bx_done:    ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ret
bx_x0:      db 0
bx_y:       db 0
bx_x1:      db 0
bx_y1:      db 0
bx_c:       db 0
bx_pg:      db 0
#endasm
End Sub

Private Sub SpansP(ByVal y0 As Integer, ByVal y1 As Integer, ByVal c As Integer, ByVal tl As Integer, ByVal tr As Integer, ByVal pg As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (sz_y), a
            pop hl
            ld a, (hl)
            ld (sz_y1), a
            pop hl
            ld a, (hl)
            ld (sz_c), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sz_tl), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (sz_tr), de
            pop hl
            ld a, (hl)
            ld (sz_pg), a
sz_line:    ld a, (sz_y)        ; the line's page in at #C000
            rlca
            rlca
            rlca
            and 7
            ld e, a
            ld a, (sz_pg)
            add a, e
            ld bc, #243B
            ld e, #56
            out (c), e
            inc b
            out (c), a
            ld a, (sz_y)
            ld e, a
            ld d, 0
            ld hl, (sz_tl)
            add hl, de
            ld b, (hl)          ; b: left x
            ld hl, (sz_tr)
            add hl, de
            ld c, (hl)          ; c: right x
            ld a, c
            cp b
            jr c, sz_skip       ; (left past right: nothing)
sz_ok:      ld a, e
            and 31
            or #C0
            ld h, a
            ld l, b
            ld a, c
            sub b
            inc a
            ld b, a             ; (1-255)
            ld a, (sz_c)
            ld c, a
            ld a, b             ; (8 at a time, the rest first)
            and 7
            jr z, sz_u8
sz_u1:     ld (hl), c
            inc l
            dec a
            jr nz, sz_u1
sz_u8:     srl b
            srl b
            srl b
            jr z, sz_ud
sz_ul:
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            ld (hl), c
            inc l
            djnz sz_ul
sz_ud:
sz_skip:    ld a, (sz_y1)
            ld e, a
            ld a, (sz_y)
            cp e
            jr z, sz_done
            inc a
            ld (sz_y), a
            jr sz_line
sz_done:    ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ret
sz_y:       db 0
sz_y1:      db 0
sz_c:       db 0
sz_pg:      db 0
sz_tl:      dw 0
sz_tr:      dw 0
#endasm
End Sub
