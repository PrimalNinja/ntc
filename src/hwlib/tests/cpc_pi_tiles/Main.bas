' HWTEST - CPC + the Pi's VDP (v9990): the layers. The tiles come from the store (an installer put
' GRAPHICS/V9990/TILES there - here the test writes it), a level's rows go up as TileRow, the layer
' scrolls by itself, a sprite with a hit box bounces over it. Build: Pi.cls and Art.cls.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim i As Integer, r As Integer
Dim mp(31) As Integer
Print "HWTEST - CPC + the Pi's VDP: tiles"
Pi.Init
Pi.TilesTag "GRAPHICS/V9990/TILES"
For i = 0 To 31 : mp(i) = i Mod 4 : Next
For r = 20 To 25
  Pi.TileRow r, 0, VarPtr(mp(0)), 32
Next
Pi.Tile 3, 3, 2, 2                       ' one cell mirrored Y
Pi.ScrollBy 16, 0                        ' a pixel a frame, by itself
For i = 0 To 3
  Pi.Pattern i, Art.Ball() + i * 128
Next
Pi.Bounds 0, 48, 239, 150
Pi.Put 0, 20, 60, 0 : Pi.Move 0, 2, 1 : Pi.Anim 0, 0, 4, 4 : Pi.HitBox 0, 4, 4, 8, 8
Do
  Pi.Frame
Loop
