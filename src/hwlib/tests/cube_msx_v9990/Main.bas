' CUBE - MSX + V9990 (GFX9000): a solid cube turning, lit, faces turned away dropped - B1 (256 x
' 212, a byte a pixel), each face filled by the chip's own command (LMMV) a line at a time, on
' the screen not shown, the screens swapped at the frame. A cartridge (copied to RAM at #C000).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Org &HC000
Option Stack &HFFF0                       ' (all the RAM: no BIOS is used. Not at the very top: #FFFF is the MSX2's sub-slot switch)
Option Turbo
Option Explicit
Dim f As Integer, b As Integer

Mode 2                                   ' B1: 256 x 212, a byte a pixel, 2 screens
Cls
Print "CUBE - MSX + V9990 (GFX9000)"
Print "B1, 32 shades, filled by the"
Print "V9990 (LMMV), 2 screens"
For f = 0 To 31                          ' colours 2-33: the cube, dark to light gold
  V9990.Palette 2 + f, 3 + f * 28 \ 31, f * 27 \ 31, f * 12 \ 31
Next
Vec.Setup 50, 400, 256, 128, 126, 0
Do
  V9990.Begin                              ' the old picture's box cleared by the chip ...
  Vec.Turn 2, 3, 1                       ' ... while the cube is worked out
  Vec.Project
  V9990.Keep Vec.Bx0, Vec.By0, Vec.Bx1, Vec.By1
  For f = 0 To 5
    b = Vec.Face(f)
    If b Then V9990.Spans Vec.Y0, Vec.Y1, 2 + (b - 1) * 32 \ 65, Vec.L(), Vec.R()
  Next
  V9990.Show
Loop
