' CUBE - Amstrad CPC (Cpc): a solid cube turning, lit, faces turned away dropped - mode 0 (pixels
' twice as wide as high: the cube is drawn half as wide to stay square), each face filled a line
' at a time with whole bytes in the middle and the end pixels masked, on the screen not shown
' (#C000 / #4000), the screens swapped at the frame. RUN"CUBECPC.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Turbo
Option Explicit
Dim f As Integer, b As Integer

Mode 0                                   ' 160 x 200, 16 pens
Cpc.Inks Art.Inks()
Cls
Print "CUBE - CPC"
Print "mode 0, 6 shades,"
Print "byte fills,"
Print "2 screens"
Cpc.Init                                 ' (after the text: it copies the screen to the second)
Vec.Setup 50, 400, 256, 80, 124, 1
Do
  Cpc.Begin                              ' the old picture's box cleared
  Vec.Turn 2, 3, 1
  Vec.Project
  Cpc.Keep Vec.Bx0, Vec.By0, Vec.Bx1, Vec.By1
  For f = 0 To 5
    b = Vec.Face(f)
    If b Then Cpc.Spans Vec.Y0, Vec.Y1, Cpc.PenByte(2 + (b - 1) * 6 \ 65), Vec.L(), Vec.R()
  Next
  Cpc.Show
Loop
