' PI15TILE - NTC PI DEMOS 15: the vdp's tile layer, with the tiles taken from the store. Four
' tiles (8 x 8, 4 bits a pixel, 32 bytes each) are put in the store as GRAPHICS/V9990/TILES,
' the layer's rows are filled, the layer scrolls by itself and a ball with a hit box bounces
' over it. LOOK AT THE PI'S SCREEN: six rows of striped tiles sliding sideways, one ball.
' Uses hwlib's Pi class (copied here unchanged) and Link for the store.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim i As Integer, r As Integer, st As Integer, t As Integer
Dim mp(31) As Integer
Dim tl(127) As Byte
Dim s0 As String Max 80

Mode 2
Link.Title "PI15 TILES - the vdp's tile layer, tiles from the store"
If Not Link.Hello("HWLIB") Then Print Link.Reply : Link.Summary : End
st = Link.Open("store")
Link.Check "OPEN store", st > 0
If st = 0 Then Link.Summary : End
For i = 0 To 127
  r = i \ 32
  If r = 0 Then tl(i) = &H11
  If r = 1 Then tl(i) = &H22
  If r = 2 Then tl(i) = &H33
  If r = 3 Then tl(i) = &H44
Next
Link.Check "4 tiles put in the store as GRAPHICS/V9990/TILES", Link.AskWith(st, "PUT GRAPHICS/V9990/TILES", VarPtr(tl), 128)
Link.Shut st
Pi.Init
Pi.Palette 1, 255, 0, 0 : Pi.Palette 2, 0, 255, 0 : Pi.Palette 3, 0, 0, 255 : Pi.Palette 4, 255, 255, 0
Pi.Palette 5, 224, 80, 56 : Pi.Palette 6, 248, 128, 96 : Pi.Palette 7, 255, 255, 255
Pi.TilesTag "GRAPHICS/V9990/TILES"
For i = 0 To 31 : mp(i) = i Mod 4 : Next
For r = 20 To 25
  Pi.TileRow r, 0, VarPtr(mp), 32
Next
Pi.Tile 3, 3, 2, 2
Pi.ScrollBy 16, 0
For i = 0 To 3
  Pi.Pattern i, Art.Ball() + i * 128
Next
Pi.Bounds 0, 48, 239, 150
Pi.Put 0, 20, 60, 0 : Pi.Move 0, 2, 1 : Pi.Anim 0, 0, 4, 4 : Pi.HitBox 0, 4, 4, 8, 8
t = Ticks
For i = 1 To 100
  Pi.Frame
Next
t = Ticks - t
Print "    100 frames in "; t; " ticks (300 a second)"
Link.Check "STATE 0: the ball is on the Pi", Link.Ask(1, "STATE 0") And Left$(Link.Reply, 5) = "OK 0 "
s0 = Link.Reply
Print "    "; s0
Link.Check "INFO", Link.Ask(1, "INFO")
Print "    "; Link.Reply
For i = 1 To 10
  Pi.Frame
Next
Link.Check "STATE 0 again: it has moved", Link.Ask(1, "STATE 0") And Link.Reply <> s0
Link.Summary
Print "Running on: any key ends it."
Do
  Pi.Frame
Loop While Inkey = 0
