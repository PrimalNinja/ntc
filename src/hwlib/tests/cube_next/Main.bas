' CUBE - ZX Spectrum Next (Zxn): a solid cube turning, lit, faces turned away dropped - Layer 2
' (256 x 192, a byte a pixel), 32 shades set in the palette from 512 colours, each face filled a
' line at a time on the screen not shown, the screens swapped at the frame. 28MHz.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Turbo
Option Explicit
Dim f As Integer, b As Integer

Mode 2                                   ' Layer 2: 256 x 192, 256 colours, 2 screens
Cls
Print "CUBE - ZX SPECTRUM NEXT"
Print "Layer 2, 32 shades from 512,"
Print "2 screens, 28MHz"
For f = 0 To 31                          ' colours 16-47: the cube, dark to light gold
  Zxn.Palette 16 + f, 1 + f * 6 \ 31, f * 6 \ 31, f * 3 \ 31
Next
Vec.Setup 50, 400, 256, 128, 116, 0
Do
  Zxn.Begin                              ' the old picture's box cleared
  Vec.Turn 2, 3, 1
  Vec.Project
  Zxn.Keep Vec.Bx0, Vec.By0, Vec.Bx1, Vec.By1
  For f = 0 To 5
    b = Vec.Face(f)
    If b Then Zxn.Spans Vec.Y0, Vec.Y1, 16 + (b - 1) * 32 \ 65, Vec.L(), Vec.R()
  Next
  Zxn.Show
Loop
