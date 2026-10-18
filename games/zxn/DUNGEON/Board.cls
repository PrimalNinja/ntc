' Board - the card table on the Next's tilemap: 40 x 32 cells, 2 bytes each (the tile, its palette
' row), so each card can be in its own colours. The tiles (GfxData) at bank 5 + #0000, the map at
' bank 5 + #2000 (#E000).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private tc As Integer

' Init: the tilemap with attributes (after Tiles.Init and GfxData.Load)
Public Sub Init()
  Nx.Reg &H6B, &H81                        ' the tilemap: on, 40 x 32, 2 bytes a cell, 4 bit
  Clear
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
