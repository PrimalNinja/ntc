' AUCKLINK: AUCKLAND with a coprocessor card holding the data (tools/s3dpi: the card's C, the
' protocol). The CPC sends the keys, the card makes the frame as a list of lines, the CPC draws
' it. No RAM expansion needed. With no card: FRAME.LST drawn (a list tools/s3dpi/sim wrote).
' Keys as AUCKLAND's: cursors turn / dive, climb; < > roll; X climb; Space ? faster / slower;
' S frame skip 0 / 4 / 8; 1-9 views; B detail; Q quit.
' The card's ports in Link.cls are a stand-in until the CPC-CPLINK2's are known; its ROM: CROM.
Option PressAnyKeyOnEnd "Press a key"
Option Explicit
Option RomEnable All
Option Reserve &H4000, &H4000     ' main RAM's #4000-#7FFF: the second screen
Const CROM = 6                    ' the card's ROM number (stand-in)
Dim k As Integer, p As Integer, r As Integer, y As Integer, spd As Integer, skip As Integer
Dim bud As Integer, sq As Integer, frames As Integer, t As Integer, n As Integer, nv As Integer
Dim dx As Integer, dz As Integer

Mode 1
Link.Inks
Link.Setup CROM
If Not Link.Hello() Then
  Print "No card (ROM"; CROM; ") - drawing FRAME.LST"
  If Link.Load("FRAME.LST") <= 0 Then Print "No FRAME.LST either" : End
  Graphics.DoubleBuffer 1
  Link.Draw
  Graphics.Flip
  k = Inkey : Do : Loop Until Inkey <> 0
  Graphics.DoubleBuffer 0
  End
End If
Print "AUCKLAND (card)"
Print "cursors  turn, dive / climb"
Print "< >      roll    X climb"
Print "Space ?  faster / slower"
Print "S        frame skip 0 / 4 / 8"
Print "1-9      views   B detail   Q quit"
Print
Print "Map data (c) OpenStreetMap contributors"
Print : Print "Press a key"
Do : Loop Until Inkey <> 0
Cls
Graphics.DoubleBuffer 1
spd = 8 : bud = 1200
Link.View 0
sq = Link.Seq()
Link.Frame 0, 0, 0, 0, 0, bud                     ' the first frame
t = Ticks
Do
  sq = Link.Wait(sq)                              ' the card's next list
  Link.Fetch
  p = 0 : r = 0 : y = 0
  If Keys.Down(Keys.KeyUp) Then p = -1
  If Keys.Down(Keys.KeyX) Or Keys.Down(Keys.KeyDown) Then p = 1
  If Keys.Down(39) Then r = -1
  If Keys.Down(31) Then r = 1
  If Keys.Down(Keys.KeyLeft) Then y = -1
  If Keys.Down(Keys.KeyRight) Then y = 1
  If Keys.Down(Keys.KeySpace) And spd < 64 Then spd = spd + 1
  If Keys.Down(30) And spd > 0 Then spd = spd - 1
  k = Inkey
  If k >= 49 And k <= 57 Then
    Link.View k - 49
  ElseIf k = 83 Or k = 115 Then
    skip = skip + 4 : If skip > 8 Then skip = 0
  ElseIf k = 66 Or k = 98 Then
    bud = bud * 2 : If bud > 2400 Then bud = 600
  End If
  Link.Frame p, r, y, spd, skip, bud              ' the card makes the next one while this is drawn
  Link.Draw
  dx = Link.CompassX() : dz = Link.CompassY()
  Graphics.Pen 3
  Graphics.Line 296 - dx \ 2, 182 - dz \ 2, 296 + dx, 182 + dz
  frames = frames + 1
  If frames = 8 Then
    n = 8 * System.TicksPerSecond * 10 \ (Ticks - t + 1)
    Locate 1, 1 : Print Left$("FPS " + Str$(n \ 10) + "." + Str$(n Mod 10) + "  HEIGHT" + Str$(Link.Altitude()) + "M  LINES" + Str$(Link.Lines()) + Space$(40), 40);
    Graphics.CopyText 1
    frames = 0 : t = Ticks
  End If
  Graphics.Flip
Loop Until Keys.Down(Keys.KeyQ)
Graphics.DoubleBuffer 0
Mode 1
End
