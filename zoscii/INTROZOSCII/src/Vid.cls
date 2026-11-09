' Vid - the Next's video for INTRODUCTION TO ZOSCII: Layer 2 at 320 x 256 (8 bit, a column a time: x * 256 + y), filled
' rectangles and a 5 x 7 text font. The data blocks (INTRO.DAT) come into the window at #4000 one at a time (SelBlock).
' Colours 0-15 are the program's: see Pal.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Private sps As Integer
Private fa As Integer

Public Sub NReg(ByVal r As Integer, ByVal v As Integer)
  Out &H243B, r : Out &H253B, v
End Sub

' Col i, r, g, b: Layer 2 palette entry i from r, g, b (0-7 each)
Public Sub Col(ByVal i As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
  NReg &H43, &H10
  NReg &H40, i
  NReg &H44, r * 32 + g * 4 + b \ 2
  NReg &H44, b And 1
End Sub

' Init: 28MHz, Layer 2 320 x 256 shown, everything else off, the 16 colours
Public Sub Init()
  Cur = -1
  Dim i As Integer
  NReg 7, 3
  NReg &H70, &H10
  NReg &H12, 12
  NReg &H1C, 1
  NReg &H18, 0 : NReg &H18, 255 : NReg &H18, 0 : NReg &H18, 255
  NReg &H16, 0 : NReg &H17, 0 : NReg &H71, 0
  NReg &H15, 0
  NReg &H68, &H80
  NReg &H6B, 0
  NReg &H69, &H80
  fa = &H4000 + Data.T_FONT
  Col 0, 0, 0, 0
  Col 1, 7, 7, 7
  Col 2, 6, 6, 7
  Col 3, 4, 5, 5
  Col 4, 2, 3, 3
  Col 5, 0, 1, 1
  Col 6, 1, 2, 3
  Col 7, 2, 3, 4
  Col 8, 2, 7, 7
  Col 9, 2, 7, 3
  Col 10, 7, 6, 2
  Col 11, 7, 4, 1
  Col 12, 7, 1, 1
  Col 13, 7, 3, 5
  Col 14, 2, 4, 7
  Col 15, 0, 3, 4
End Sub

' SelBlock b: data block b of VOYAGE.DAT (Option NexData) in the window #4000-#7FFF; -1: the
' program's own pages back
Public Cur As Integer                    ' the data block in the window now (-1 none): SelBlock keeps it

Public Sub SelBlock(ByVal b As Integer)
  Cur = b
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, ({b})
            bit 7, h
            jr nz, sb_back
            ld de, ntc_nexdata + 1
            add hl, de
            ld l, (hl)
            ld h, 0
            jr sb_go
sb_back:
            ld bc, (ntc_rampt)
            call nxt_win
            ld a, #FF
            ld (zxn_selb), a
            jr sb_end
sb_go:
            call zxn_sel
sb_end:
            ld sp, ({sps})
#endasm
End Sub

' Pe blk, off / Pk blk, off, v: a byte of data block blk (the window comes back to the caller's own page after). Code in a page runs in the
' window, so it can't select a block itself: it calls these.
Public Function Pe(ByVal blk As Integer, ByVal off As Integer) As Integer
  Dim r As Integer
  SelBlock blk
  r = Peek(&H4000 + off)
  SelBlock -1
  Pe = r
End Function

Public Sub Pk(ByVal blk As Integer, ByVal off As Integer, ByVal v As Integer)
  SelBlock blk
  Poke &H4000 + off, v
  SelBlock -1
End Sub

' TabB(off): a byte of the tables block (Data.T_ROOM ...)
Public Function TabB(ByVal off As Integer) As Integer
  Dim r As Integer
  If off >= 16384 Then
    SelBlock Data.TAB2
    r = Peek(&H4000 + off - 16384)
  Else
    SelBlock Data.TABB
    r = Peek(&H4000 + off)
  End If
  SelBlock -1
  TabB = r
End Function

' Sync: wait for raster line 224 (the start of the vertical blank, under the 200 row room and HUD)
Public Sub Sync()
#asm
sy_w:       ld bc, #243B
            ld a, #1F
            out (c), a
            inc b
            in a, (c)
            cp 224
            jr nz, sy_w
            ld bc, #243B
            ld a, #1E
            out (c), a
            inc b
            in a, (c)
            and 1
            jr nz, sy_w
#endasm
  Rng.Frame
End Sub

' Fill x, y, w, h, c: a box of colour c in Layer 2 (x 0-319, y 0-255)
Public Sub Fill(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal c As Integer)
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld de, ({x})
            ld hl, ({w})
            add hl, de
            ld (fl_w), hl
fl_col:     ld hl, (fl_w)
            or a
            sbc hl, de
            jp z, fl_end
            call fl_setpg            ; hl = the column's top
            ld a, ({y})
            ld l, a
            ld a, ({h})
            ld b, a
            ld a, ({c})
fl_row:     ld (hl), a
            inc l
            djnz fl_row
            inc de
            jp fl_col
; DE = x: slot 6 gets x's page; HL = #C000 + (x and 31) * 256
fl_setpg:
            ld h, d
            ld l, e
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l                     ; l = x / 32
            ld a, l
            add a, 24
            ld bc, #243B
            ld l, #56
            out (c), l
            inc b
            out (c), a
            ld a, e
            and 31
            or #C0
            ld h, a
            ld l, 0
            ret
fl_w:       dw 0
fl_end:
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ld sp, ({sps})
#endasm
End Sub

' Glyph x, y, ch, c: one 5 x 7 character (ASCII 32-90, and 128-151: the Spanish / Russian glyphs after Z) in colour c, on what is there
Public Sub Glyph(ByVal x As Integer, ByVal y As Integer, ByVal ch As Integer, ByVal c As Integer)
  If ch >= 97 And ch <= 122 Then ch = ch - 32
  If ch >= 128 And ch <= 151 Then ch = ch - 37
  If ch < 32 Or ch > 114 Then Exit Sub
  SelBlock Data.TABB
#asm
            ld hl, ({ch})
            ld de, -32
            add hl, de
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de               ; * 5
            ld de, ({fa})
            add hl, de
            ld (gl_p), hl
            ld de, ({x})
            ld a, 5
            ld (gl_n), a
gl_col:     ld hl, (gl_p)
            ld a, (hl)
            inc hl
            ld (gl_p), hl
            ld (gl_b), a
            ld (gl_x), de
            ld h, d
            ld l, e
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ld a, l
            add a, 24
            ld bc, #243B
            ld l, #56
            out (c), l
            inc b
            out (c), a
            ld de, (gl_x)
            ld a, e
            and 31
            or #C0
            ld h, a
            ld a, ({y})
            ld l, a
            ld a, ({c})
            ld (gl_c), a
            ld a, (gl_b)
            ld b, 7
gl_row:     rrca
            jr nc, gl_no
            ld c, a
            ld a, (gl_c)
            ld (hl), a
            ld a, c
gl_no:      inc l
            djnz gl_row
            inc de
            ld a, (gl_n)
            dec a
            ld (gl_n), a
            jr nz, gl_col
            jr gl_end
gl_p:       dw 0
gl_n:       db 0
gl_b:       db 0
gl_c:       db 0
gl_x:       dw 0
gl_end:
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
#endasm
  SelBlock -1
End Sub

' Txt x, y, a, c: text from a 0 ended string in the tables block, 6 pixels a character; a line feed (10) starts the next
' line 10 pixels down at x again. Returns nothing; Ty is the y of the line after the last one.
Public Ty As Integer
Public Sub Txt(ByVal x As Integer, ByVal y As Integer, ByVal a As Integer, ByVal c As Integer)
  Dim b As Integer, x0 As Integer
  x0 = x
  b = TabB(a)
  Do While b <> 0
    If b = 10 Then
      x = x0
      y = y + 10
    Else
      Glyph x, y, b, c
      x = x + 6
    End If
    a = a + 1
    b = TabB(a)
  Loop
  Ty = y + 10
End Sub

' TxtC y, a, c: one line centred
Public Sub TxtC(ByVal y As Integer, ByVal a As Integer, ByVal c As Integer)
  Dim n As Integer
  n = 0
  Do While TabB(a + n) <> 0
    n = n + 1
  Loop
  Txt 160 - n * 3, y, a, c
End Sub

' Num x, y, n, digits, c: n as digits characters (zero padded)
Public Sub Num(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer, ByVal d As Integer, ByVal c As Integer)
  Dim i As Integer, p As Integer, k As Integer
  p = 1
  For i = 2 To d
    p = p * 10
  Next
  For i = 1 To d
    k = (n \ p) Mod 10
    Glyph x, y, 48 + k, c
    x = x + 6
    p = p \ 10
  Next
End Sub

' Hex2 x, y, v, c: a byte as two hex digits
Public Sub Hex2(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer, ByVal c As Integer)
  Dim d As Integer
  d = (v \ 16) And 15
  If d > 9 Then d = d + 7
  Glyph x, y, 48 + d, c
  d = v And 15
  If d > 9 Then d = d + 7
  Glyph x + 6, y, 48 + d, c
End Sub

' Hex4 x, y, hi, lo, c: a 16 bit value from its two bytes
Public Sub Hex4(ByVal x As Integer, ByVal y As Integer, ByVal h As Integer, ByVal l As Integer, ByVal c As Integer)
  Hex2 x, y, h, c
  Hex2 x + 12, y, l, c
End Sub

' Ch x, y, v, c: a byte as a character (. if it isn't one the font has)
Public Sub Ch(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer, ByVal c As Integer)
  If (v >= 32 And v <= 90) Or (v >= 97 And v <= 122) Then
    Glyph x, y, v, c
  Else
    Glyph x, y, 46, c
  End If
End Sub

' Big x, y, ch, c, s: a character scaled s times
Public Sub Big(ByVal x As Integer, ByVal y As Integer, ByVal ch As Integer, ByVal c As Integer, ByVal s As Integer)
  Dim col As Integer, row As Integer, b As Integer, p As Integer
  If ch >= 97 And ch <= 122 Then ch = ch - 32
  If ch >= 128 And ch <= 151 Then ch = ch - 37
  If ch < 32 Or ch > 114 Then Exit Sub
  For col = 0 To 4
    b = TabB(Data.T_FONT + (ch - 32) * 5 + col)
    p = 1
    For row = 0 To 6
      If (b And p) <> 0 Then Fill x + col * s, y + row * s, s, s, c
      p = p + p
    Next
  Next
End Sub

' BigTxt x, y, a, c, k: text from the tables block scaled k times, 6 * k pixels a character
Public Sub BigTxt(ByVal x As Integer, ByVal y As Integer, ByVal a As Integer, ByVal c As Integer, ByVal k As Integer)
  Dim b As Integer
  b = TabB(a)
  Do While b <> 0
    Big x, y, b, c, k
    x = x + 6 * k
    a = a + 1
    b = TabB(a)
  Loop
End Sub

' BigC y, a, c, k: BigTxt centred
Public Sub BigC(ByVal y As Integer, ByVal a As Integer, ByVal c As Integer, ByVal k As Integer)
  Dim n As Integer
  n = 0
  Do While TabB(a + n) <> 0
    n = n + 1
  Loop
  BigTxt 160 - n * 3 * k, y, a, c, k
End Sub

' Edge(): the keys newly pressed since the last call, as bits: 1 Q, 2 A, 4 O, 8 P, 16 Space, 32 Z, 64 W, 128 S
Private lastK As Integer
Public Function Edge() As Integer
  Dim k As Integer, e As Integer
  k = 0
  If Keys.Down(Keys.KeyQ) Then k = k Or 1
  If Keys.Down(Keys.KeyA) Then k = k Or 2
  If Keys.Down(Keys.KeyO) Then k = k Or 4
  If Keys.Down(Keys.KeyP) Then k = k Or 8
  If Keys.Down(Keys.KeySpace) Then k = k Or 16
  If Keys.Down(Keys.KeyZ) Then k = k Or 32
  If Keys.Down(Keys.KeyW) Then k = k Or 64
  If Keys.Down(Keys.KeyS) Then k = k Or 128
  e = k And (Not lastK)
  lastK = k
  Edge = e
End Function

' Page t, k: clears the screen, draws the title (text offset t) and the key line (text offset k)
Public Sub Page(ByVal t As Integer, ByVal k As Integer)
  Fill 0, 0, 320, 256, 5
  Fill 0, 0, 320, 22, 6
  Fill 0, 22, 320, 1, 8
  Txt 8, 7, t, 10
  Fill 0, 238, 320, 18, 6
  Txt 8, 244, k, 3
End Sub

' PageNo p, n: PAGE p OF n at the right of the title band
Public Sub PageNo(ByVal p As Integer, ByVal n As Integer)
  Dim d As Integer
  d = 0
  If n > 9 Then d = 1
  Txt 246 - d * 12, 7, Data.TX_F_PAGE, 3
  Num 276 - d * 12, 7, p, 1 + d, 3
  Txt 288 - d * 6, 7, Data.TX_OF, 3
  Num 306 - d * 6, 7, n, 1 + d, 3
End Sub

