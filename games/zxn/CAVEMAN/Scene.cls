' Scene - the picture behind the fighting: the sky on Layer 2 (bands of colour, a sun), the
' scenery and the panel on the tilemap (2 bytes a cell: each cell its own palette row), and the
' copper scrolling the tilemap's bands at their own speeds (parallax).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' The tilemap: 40 x 32 at bank 5 + #2000 (#E000), the tiles (GfxData) at bank 5 + #0000. Its clip
' window keeps to the paper, so the columns being drawn (in the border) don't show.
' The copper, every frame: the panel (paper lines 0-23) not scrolled; the far mountains (24-95)
' at a quarter of the speed, the jungle (96-119) at half, the ground (120-191) at full speed.
Option Explicit

Private sp As Integer, tc As Integer

' Init: the tilemap with attributes (after Tiles.Init and GfxData.Load), Layer 2 on for the sky
Public Sub Init()
  Nx.Reg &H6B, &H81                        ' the tilemap: on, 40 x 32, 2 bytes a cell, 4 bit
  Nx.Reg &H1C, 8
  Nx.Reg &H1B, 16 : Nx.Reg &H1B, 143 : Nx.Reg &H1B, 32 : Nx.Reg &H1B, 223
  Clear
  Nx.Reg &H70, 0                           ' Layer 2: 256 x 192, bank 16
  Nx.Reg &H12, 16
  Nx.Reg &H1C, 1
  Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0
  Out &H123B, 2
End Sub

' Clear: every cell tile 0 (see-through)
Public Sub Clear()
#asm
            ld hl, #E000
            ld de, #E001
            ld bc, 2559
            ld (hl), 0
            ldir
#endasm
End Sub

' Put x, y, t, p: cell x, y shows tile t in palette row p
Public Sub Put(ByVal x As Integer, ByVal y As Integer, ByVal t As Integer, ByVal p As Integer)
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a                 ; DE = #E000 + (y * 40 + x) * 2
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld b, 0
            add hl, bc
            add hl, hl
            ld de, #E000
            add hl, de
            ex de, hl
            pop hl
            ld a, (hl)
            ld (de), a
            inc de
            pop hl
            ld a, (hl)
            rlca
            rlca
            rlca
            rlca
            and #F0
            ld (de), a
#endasm
End Sub

' Text x, y, s, p: a string from cell x, y in palette row p (the font is the tiles 32-95)
Public Sub Text(ByVal x As Integer, ByVal y As Integer, ByVal s As String, ByVal p As Integer)
#asm
            pop hl
            ld c, (hl)
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld b, 0
            add hl, bc
            add hl, hl
            ld de, #E000
            add hl, de
            ex de, hl
            pop hl
            ld ({tc}), hl
            pop hl
            ld a, (hl)
            rlca
            rlca
            rlca
            rlca
            and #F0
            ld c, a
            ld hl, ({tc})
st_lp:
            ld a, (hl)
            or a
            jr z, st_done
            ld (de), a
            inc de
            ld a, c
            ld (de), a
            inc de
            inc hl
            ld a, d
            cp #EA
            jr nc, st_done
            jr st_lp
st_done:
#endasm
End Sub

' Rect x, y, w, h, t, p: a block of one tile
Public Sub Rect(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal t As Integer, ByVal p As Integer)
  Dim i As Integer, j As Integer
  For j = y To y + h - 1
    For i = x To x + w - 1
      Put i, j, t, p
    Next
  Next
End Sub

' Pal row, s: the tilemap's palette row (0-15) from s, 16 colours as hex pairs (RRRGGGBB)
Public Sub Pal(ByVal row As Integer, ByVal s As String)
  Dim k As Integer
  For k = 0 To 15
    Nx.PalEntry Nx.PalTiles, row * 16 + k, Hx(s, k)
  Next
End Sub

' Hx(s, k): the k-th hex pair in s
Private Function Hx(ByVal s As String, ByVal k As Integer) As Integer
  Dim a As Integer, b As Integer
  a = Asc(Mid$(s, k * 2 + 1, 1)) : b = Asc(Mid$(s, k * 2 + 2, 1))
  If a > 57 Then a = a - 55 Else a = a - 48
  If b > 57 Then b = b - 55 Else b = b - 48
  Hx = a * 16 + b
End Function

' Sky s, sun: Layer 2's sky: 12 bands of colour from s (hex pairs) down paper lines 24-119, the
' rest black; a sun (sun 1) in colour 12
Public Sub Sky(ByVal s As String, ByVal sun As Integer)
  Dim k As Integer, y As Integer, dy As Integer, w As Integer
  For k = 0 To 11
    Nx.PalEntry Nx.PalLayer2, k, Hx(s, k)
  Next
  Nx.PalEntry Nx.PalLayer2, 12, &HFD
  Nx.PalEntry Nx.PalLayer2, 13, 0
  Nx.PalEntry Nx.PalLayer2, 14, &HF9
  Band 0, 24, 13
  For k = 0 To 11
    Band 24 + k * 8, 8, k
  Next
  Band 120, 72, 13
  If sun Then
    For y = -13 To 13
      dy = y * y
      w = 0
      Do While w * w + dy < 170
        w = w + 1
      Loop
      Span 70 + y, 190 - w, 190 + w, 12
      If w > 2 And (y And 3) = 0 And y > 0 Then Span 70 + y, 190 - w, 190 + w, 14
    Next
  End If
End Sub

' Band y, n, c: Layer 2's lines y to y + n - 1 all colour c
Public Sub Band(ByVal y As Integer, ByVal n As Integer, ByVal c As Integer)
  Dim k As Integer
  For k = y To y + n - 1
    Span k, 0, 255, c
  Next
End Sub

' Span y, x0, x1, c: Layer 2's line y from x0 to x1, colour c
Public Sub Span(ByVal y As Integer, ByVal x0 As Integer, ByVal x1 As Integer, ByVal c As Integer)
#asm
            pop hl
            ld a, (hl)
            ld ({tc}), a            ; y
            pop hl
            ld e, (hl)              ; x0
            pop hl
            ld a, (hl)
            sub e
            ld b, a
            inc b                   ; the count (x1 - x0 + 1; 0 = 256)
            pop hl
            ld c, (hl)              ; the colour
            ld a, c
            ld ({sp}), a            ; the colour, the count kept
            ld a, b
            ld ({sp} + 1), a
            ld a, ({tc})
            rlca
            rlca
            rlca
            and 7
            add a, 32               ; its page into slot 6
            ld d, a
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            out (c), d
            ld a, ({tc})
            and 31
            or #C0
            ld h, a
            ld l, e
            ld a, ({sp} + 1)
            ld b, a
            ld a, ({sp})
sn_lp:
            ld (hl), a
            inc l
            djnz sn_lp
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
#endasm
End Sub

' Copper far, mid, near: the bands' scrolls (0-319) for the copper from now on
Public Sub Copper(ByVal far As Integer, ByVal mid As Integer, ByVal near As Integer)
  Nx.Reg &H61, 0
  Nx.Reg &H62, 0                           ' stopped, from 0
  Op &H80, 0                               ' WAIT line 0: the panel
  Op &H2F, 0 : Op &H30, 0
  Op &H80, 24                              ' WAIT line 24: the mountains
  Op &H2F, far \ 256 : Op &H30, far And 255
  Op &H80, 96                              ' WAIT line 96: the jungle
  Op &H2F, mid \ 256 : Op &H30, mid And 255
  Op &H80, 120                             ' WAIT line 120: the ground
  Op &H2F, near \ 256 : Op &H30, near And 255
  Op &HFF, &HFF                            ' HALT
  Nx.Reg &H62, &HC0                        ' run, again from the top each frame
End Sub

Private Sub Op(ByVal a As Integer, ByVal b As Integer)
  Nx.Reg &H60, a
  Nx.Reg &H60, b
End Sub
