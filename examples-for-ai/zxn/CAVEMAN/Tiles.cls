' Tiles - the Next's tilemap as a 4 bit picture: 40 x 32 cells of 8 x 8 pixels over the whole
' 320 x 256 display (the border included), 16 colours (tile_pal.png), colour 15 transparent.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' The map stays where the platform put it (bank 5 + #2000, seen at #E000: one byte a cell, the
' tile number), so Print and Locate still work on it: the font is tiles 32-126 (a character's code
' is its tile). The tile definitions go to bank 5 + #0000 (#C000-#DFFF, 32 bytes a tile): the
' ULA screen's place, so the ULA is turned off. Don't use Mode or Cls after Init (Mode puts the
' platform's own text tiles back; Cls is all right but fills with tile 32).
' Print near the right edge or the last row wraps and scrolls: end prints with ; and keep them
' off row 32 and column 40.
Option Explicit

Public Const Cols = 40
Public Const Rows = 32
Private Const MAPA = &HE000

' Init: the tilemap on, 40 x 32, 4 bit tiles from #C000, no attribute bytes, over the ULA;
' the ULA off; no scroll; the whole picture
Public Sub Init()
  Nx.Reg &H68, Nx.RegGet(&H68) Or &H80     ' the ULA off (its screen's RAM holds the tiles)
  Nx.Reg &H6E, &H20                         ' the map: bank 5 + #2000
  Nx.Reg &H6F, &H0                          ' the tile definitions: bank 5 + #0000
  Nx.Reg &H6C, 0                            ' every cell: palette offset 0, no mirror
  Nx.Reg &H4C, &HF                          ' colour 15 transparent
  Nx.Reg &H2F, 0 : Nx.Reg &H30, 0 : Nx.Reg &H31, 0
  Nx.Reg &H1C, 8                            ' the clip window: all of it
  Nx.Reg &H1B, 0 : Nx.Reg &H1B, 159 : Nx.Reg &H1B, 0 : Nx.Reg &H1B, 255
  Nx.Reg &H6B, &HA1                         ' on, 40 x 32, no attributes, 4 bit, over the ULA
End Sub

' Put x, y, t: cell x (0-39), y (0-31) shows tile t
Public Sub Put(ByVal x As Integer, ByVal y As Integer, ByVal t As Integer)
#asm
            pop hl
            ld c, (hl)              ; x
            pop hl
            ld a, (hl)              ; y
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de              ; y * 40
            ld b, #E0
            add hl, bc
            ex de, hl
            pop hl
            ld a, (hl)
            ld (de), a
#endasm
End Sub

' Get(x, y): the tile in cell x, y
Public Function Get(ByVal x As Integer, ByVal y As Integer) As Integer
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
            ld b, #E0
            add hl, bc
            ld e, (hl)
            pop hl
            ld (hl), e
            inc hl
            ld (hl), 0
#endasm
End Function

' At(px, py): the tile under pixel px, py (0-319, 0-255), 0 off the map
Public Function At(ByVal px As Integer, ByVal py As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; px
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; py
            ld a, b
            or a
            jr nz, at_off
            ld a, d
            cp 2
            jr nc, at_off
            ld hl, -320
            add hl, de
            jr c, at_off
            srl d                   ; px / 8
            rr e
            srl e
            srl e
            ld a, c
            and #F8                 ; (py / 8) * 8
            ld l, a
            ld h, 0
            ld b, h
            ld c, l
            add hl, hl
            add hl, hl
            add hl, bc              ; (py / 8) * 40
            ld d, #E0
            add hl, de
            ld e, (hl)
            jr at_set
at_off:
            ld e, 0
at_set:
            pop hl
            ld (hl), e
            inc hl
            ld (hl), 0
#endasm
End Function

' Fill t: every cell tile t
Public Sub Fill(ByVal t As Integer)
#asm
            pop hl
            ld a, (hl)
            ld hl, #E000
            ld de, #E001
            ld bc, 40 * 32 - 1
            ld (hl), a
            ldir
#endasm
End Sub

' Rect x, y, w, h, t: a block of cells
Public Sub Rect(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal t As Integer)
  Dim i As Integer, j As Integer
  For j = y To y + h - 1
    For i = x To x + w - 1
      Put i, j, t
    Next
  Next
End Sub

' Text x, y, s: text from cell x, y (the font tiles), no wrap, no scroll
Public Sub Text(ByVal x As Integer, ByVal y As Integer, ByVal s As String)
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
            ld b, #E0
            add hl, bc
            ex de, hl
            pop hl
tx_lp:
            ld a, (hl)
            or a
            jr z, tx_done
            ld (de), a
            inc hl
            inc de
            ld a, d
            cp #E5                  ; past the map's end (#E500)
            jr nc, tx_done
            jr tx_lp
tx_done:
#endasm
End Sub

' Scroll x, y: the tilemap moved by x (0-319) and y (0-255) pixels
Public Sub Scroll(ByVal x As Integer, ByVal y As Integer)
  Nx.Reg &H2F, (x \ 256) And 3
  Nx.Reg &H30, x And 255
  Nx.Reg &H31, y And 255
End Sub
