' C64 + REU: a dungeon of 128 x 128 tiles to scroll round, a pixel at a time.
' A tile is 16 x 16 pixels: 2 x 2 characters in multicolour (8 x 16 double width pixels). The
' screen shows about 19 x 12 of them, so a level is some 70 screens.
' The level is made once and kept in the REU three ways:
'   bank 1: the tiles, a byte each (128 x 128: what the game would look at)
'   bank 2: the same as characters, as the screen wants them (256 x 256)
'   bank 3: their colours (256 x 256)
' Scrolling: the VIC moves the picture 0-7 pixels; every 8th pixel the whole 40 x 25 view comes
' out of banks 2 and 3 again (Reu.FetchRect, twice: 6,300 cycles, done while the border is
' being drawn). No screen shifting, no edge column to paint.
' Q up, A down, O left, P right, or a joystick in port 2. Space or fire: twice as fast.
' (An REU of 256K or more.)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const TILES = 128               ' the level's width and height in tiles
Const FLOOR = 0
Const WALL = 1
Const WATER = 2
Const MOSS = 3
Const PILLAR = 4
Const CHEST = 5
Const STAIRS = 6
Const RUG = 7
Const FIRSTCHAR = 128           ' tile t is characters 128 + t * 4 .. + 3
Const MAXX = 1728               ' the view's top left corner goes this far, in pixels
Const MAXY = 1848

Dim px As Integer, py As Integer        ' the view's top left corner in the level, in pixels
Dim cx As Integer, cy As Integer, ocx As Integer, ocy As Integer
Dim sx As Integer, sy As Integer, a As Integer, moved As Integer
Dim k As Integer, v As Integer, i As Integer, j As Integer, n As Integer
Dim x As Integer, y As Integer, w As Integer, h As Integer, lx As Integer, ly As Integer
Dim artrow As Integer, sprow As Integer
Dim own(7) As Byte                      ' each tile's own colour (0-7)
Dim tl(127) As Byte                     ' a row of tiles
Dim top(255) As Byte, bot(255) As Byte, col(255) As Byte    ' the same as characters, colours
Dim two(1) As Byte
Dim psrc As Integer, ptop As Integer, pbot As Integer, pcol As Integer, pown As Integer

' ---- the tiles' pictures: 16 rows of 8 double width pixels each. 0 the paper, 1 and 2 the two
' colours every tile shares (dark grey, grey), 3 the tile's own colour
Sub T(ByVal s As String)
  Dim c As Integer, p As Integer, b As Integer, half As Integer
  c = Vic.CharAddr(FIRSTCHAR + (artrow \ 16) * 4 + ((artrow \ 8) And 1) * 2) + (artrow And 7)
  For half = 0 To 1
    b = 0
    For p = 1 To 4
      b = b * 4 + Asc(Mid$(s, half * 4 + p, 1)) - 48
    Next
    Poke c + half * 8, b
  Next
  artrow = artrow + 1
End Sub

' ---- the sprite's picture: 21 rows of 16 pixels, X = on
Sub S(ByVal s As String)
  Dim p As Integer, b As Integer, half As Integer
  For half = 0 To 1
    b = 0
    For p = 1 To 8
      b = b * 2
      If Mid$(s, half * 8 + p, 1) = "X" Then b = b + 1
    Next
    Poke Vic.ShapeAddr(0) + sprow * 3 + half, b
  Next
  Poke Vic.ShapeAddr(0) + sprow * 3 + 2, 0
  sprow = sprow + 1
End Sub

' ---- a row of 128 tiles (tl) to two rows of 256 characters (top, bot) and their colours (col).
' The one place machine code earns its keep: 16,384 tiles, about a second in all
Sub Expand()
#asm
            lda {psrc}
            sta z_p0
            lda {psrc}+1
            sta z_p0+1
            lda {ptop}
            sta z_p1
            lda {ptop}+1
            sta z_p1+1
            lda {pbot}
            sta z_p2
            lda {pbot}+1
            sta z_p2+1
            lda {pcol}
            sta z_p3
            lda {pcol}+1
            sta z_p3+1
            lda {pown}
            sta z_p4
            lda {pown}+1
            sta z_p4+1
            ldx #0                      ; the tile
            stx z_t0                    ; where its characters go (0, 2, 4 ...)
exp_l:
            txa
            tay
            lda (z_p0),y                ; the tile's number
            sta z_t1
            tay
            lda (z_p4),y                ; its own colour, + 8: multicolour
            ora #8
            sta z_t2
            lda z_t1
            asl
            asl
            ora #$80                    ; its first character
            ldy z_t0
            sta (z_p1),y
            clc
            adc #2
            sta (z_p2),y
            lda z_t2
            sta (z_p3),y
            iny
            lda z_t1
            asl
            asl
            ora #$81
            sta (z_p1),y
            clc
            adc #2
            sta (z_p2),y
            lda z_t2
            sta (z_p3),y
            iny
            sty z_t0
            inx
            cpx #128
            bne exp_l
#endasm
End Sub

' the tile at x, y set
Sub Put(ByVal x As Integer, ByVal y As Integer, ByVal t As Integer)
  Reu.Poke 1, y * TILES + x, t
End Sub

' a block of tiles w wide and h high
Sub Block(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal t As Integer)
  two(0) = t : two(1) = t
  If w > 2 Then
    Dim r As Integer
    For r = 0 To h - 1
      Reu.Fill 1, (y + r) * TILES + x, t, w
    Next
  Else
    Reu.StashRect 1, y * TILES + x, TILES, VarPtr(two(0)), 0, w, h
  End If
End Sub

StdIO.Border 0
Cls
If Reu.Banks() < 4 Then
  Print "this needs an REU of 256K or more"
  End
End If
Print "c64 + reu: a dungeon of 128 x 128 tiles"
Print
Print "drawing the tiles..."

' floor
T "00000000" : T "00010000" : T "00000000" : T "00000000"
T "00000001" : T "00000000" : T "01000000" : T "00000000"
T "00000000" : T "00000100" : T "00000000" : T "10000000"
T "00000000" : T "00000000" : T "00100000" : T "00000000"
' wall
T "22222212" : T "22222212" : T "22222212" : T "11111111"
T "22122222" : T "22122222" : T "22122222" : T "11111111"
T "22222212" : T "22222212" : T "22222212" : T "11111111"
T "22122222" : T "22122222" : T "22122222" : T "11111111"
' water
T "33333333" : T "33223333" : T "32332333" : T "33333333"
T "33333322" : T "33333233" : T "33333333" : T "23333333"
T "33333333" : T "33322333" : T "33233233" : T "33333333"
T "32233333" : T "23333333" : T "33333333" : T "33333223"
' moss
T "00000000" : T "00300000" : T "03030000" : T "00000000"
T "00000300" : T "00003030" : T "00000000" : T "01000000"
T "00000000" : T "00000003" : T "30000030" : T "03000000"
T "00000000" : T "00030000" : T "00303000" : T "00000000"
' pillar
T "00000000" : T "00122100" : T "01233210" : T "01233210"
T "01233210" : T "01233210" : T "01233210" : T "01233210"
T "01233210" : T "01233210" : T "01233210" : T "01233210"
T "01233210" : T "00122100" : T "00011000" : T "00000000"
' chest
T "00000000" : T "00000000" : T "00000000" : T "01111110"
T "13333331" : T "13333331" : T "11122111" : T "13322331"
T "13333331" : T "13333331" : T "01111110" : T "00111100"
T "00000000" : T "00000000" : T "00000000" : T "00000000"
' stairs
T "22222222" : T "22222222" : T "11111111" : T "03333333"
T "02222222" : T "01111111" : T "00333333" : T "00222222"
T "00111111" : T "00033333" : T "00022222" : T "00011111"
T "00003333" : T "00002222" : T "00001111" : T "00000000"
' rug
T "33333333" : T "32222223" : T "32333323" : T "32322323"
T "32322323" : T "32333323" : T "32222223" : T "33333333"
T "33333333" : T "32222223" : T "32333323" : T "32322323"
T "32322323" : T "32333323" : T "32222223" : T "33333333"

own(FLOOR) = 0 : own(WALL) = 0 : own(WATER) = 6 : own(MOSS) = 5
own(PILLAR) = 1 : own(CHEST) = 7 : own(STAIRS) = 1 : own(RUG) = 2

S "......XXXX......"
S ".....XXXXXX....."
S ".....XXXXXX....."
S ".....XXXXXX....."
S "......XXXX......"
S "...XXXXXXXXXX..."
S "..XXXXXXXXXXXX.."
S "..XX.XXXXXX.XX.."
S "..XX.XXXXXX.XX.."
S "..XX.XXXXXX.XX.."
S "..XX.XXXXXX.XX.."
S ".....XXXXXX....."
S ".....XXXXXX....."
S ".....XXX.XXX...."
S ".....XXX.XXX...."
S ".....XXX.XXX...."
S ".....XXX.XXX...."
S ".....XXX.XXX...."
S ".....XXX.XXX...."
S "....XXXX.XXXX..."
S "....XXXX.XXXX..."

Print "digging 40 rooms..."
' rock everywhere, then rooms cut out of it, each joined to the one before by a passage two
' tiles wide: along, then up or down
Randomize 64
Reu.Fill 1, 0, WALL, TILES * TILES
For i = 1 To 40
  w = 6 + Rnd(12) : h = 5 + Rnd(8)
  x = 2 + Rnd(TILES - w - 4) : y = 2 + Rnd(TILES - h - 4)
  If i = 1 Then x = 4 : y = 4
  Block x, y, w, h, FLOOR
  If i > 1 Then
    If x + w \ 2 > lx Then
      Block lx, ly, x + w \ 2 - lx + 2, 2, FLOOR
    Else
      Block x + w \ 2, ly, lx - x - w \ 2 + 2, 2, FLOOR
    End If
    If y + h \ 2 > ly Then
      Block x + w \ 2, ly, 2, y + h \ 2 - ly + 2, FLOOR
    Else
      Block x + w \ 2, y + h \ 2, 2, ly - y - h \ 2 + 2, FLOOR
    End If
  End If
  ' things in the room, so a big one does not look the same all over
  Select Case i Mod 5
    Case 0
      Block x + 2, y + 2, w - 4, h - 3, WATER
    Case 1
      Block x + w \ 2 - 2, y + h \ 2 - 1, 4, 2, RUG
      Put x + 1, y + 1, CHEST
    Case 2
      Put x + 1, y + 1, PILLAR : Put x + w - 2, y + 1, PILLAR
      Put x + 1, y + h - 2, PILLAR : Put x + w - 2, y + h - 2, PILLAR
    Case 3
      For j = 1 To 12
        Put x + Rnd(w), y + Rnd(h), MOSS
      Next
    Case 4
      Put x + w \ 2, y + h \ 2, STAIRS
      Put x + 1, y + h - 2, CHEST
  End Select
  lx = x + w \ 2 : ly = y + h \ 2
Next

Print "making the level's characters..."
psrc = VarPtr(tl(0)) : ptop = VarPtr(top(0)) : pbot = VarPtr(bot(0))
pcol = VarPtr(col(0)) : pown = VarPtr(own(0))
For y = 0 To TILES - 1
  Reu.Fetch 1, y * TILES, psrc, TILES
  Expand
  Reu.Stash 2, y * 512, ptop, 256
  Reu.Stash 2, y * 512 + 256, pbot, 256
  Reu.Stash 3, y * 512, pcol, 256
  Reu.Stash 3, y * 512 + 256, pcol, 256
Next

' the screen: multicolour text on black, the sprite in the middle
StdIO.Paper 0
Vic.MultiText 1, 11, 12
Vic.Shape 0, 0
Vic.Colour 0, 7
Vic.Sprite 0, 176, 138

px = 0 : py = 0 : ocx = -1
Do
  ' all worked out before the frame ends, so what follows it is quick
  cx = px \ 8 : cy = py \ 8
  sx = px And 7 : sy = py And 7
  moved = (cx <> ocx) Or (cy <> ocy)
  a = cy * 256 + cx
  Frame
  Vic.Scroll sx, sy
  If moved Then
    Reu.FetchRect 2, a, 256, &HE000, 40, 40, 25
    Reu.FetchRect 3, a, 256, &HD800, 40, 40, 25
    ocx = cx : ocy = cy
  End If
  k = Joy.Read(2)
  v = 2
  If (k And Joy.Fire) Or Keys.Down(Keys.KeySpace) Then v = 4
  If (k And Joy.Up) Or Keys.Down(Keys.KeyQ) Then py = py - v
  If (k And Joy.Down) Or Keys.Down(Keys.KeyA) Then py = py + v
  If (k And Joy.Left) Or Keys.Down(Keys.KeyO) Then px = px - v
  If (k And Joy.Right) Or Keys.Down(Keys.KeyP) Then px = px + v
  If px < 0 Then px = 0
  If px > MAXX Then px = MAXX
  If py < 0 Then py = 0
  If py > MAXY Then py = MAXY
Loop
