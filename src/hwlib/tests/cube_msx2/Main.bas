' CUBE - MSX2 (V9938): a solid cube turning, lit, faces turned away dropped - Graphic 4 (256 x
' 212, 16 colours), each face filled by the chip's own command (LMMV) a line at a time, on the
' page not shown, the pages swapped at the frame. A cartridge (copied to RAM at #C000).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Org &HC000
Option Stack &HFFF0                       ' (all the RAM: no BIOS is used. Not at the very top: #FFFF is the MSX2's sub-slot switch)
Option Turbo
Option Explicit
Dim f As Integer, b As Integer

Mode 3                                   ' Graphic 4: 256 x 212, 16 colours, 2 pages
Cls
Print "CUBE - MSX2 (V9938)"
Print "Graphic 4, 12 shades, filled by"
Print "the VDP (LMMV), 2 pages"
For f = 0 To 11                          ' colours 2-13: the cube, dark to light gold
  V9938.Palette 2 + f, 1 + f * 6 \ 11, f * 6 \ 11, f * 3 \ 11
Next
Vec.Setup 50, 400, 256, 128, 126, 0
Do
  V9938.Begin                              ' the old picture's box cleared by the chip ...
  Vec.Turn 2, 3, 1                       ' ... while the cube is worked out
  Vec.Project
  V9938.Keep Vec.Bx0, Vec.By0, Vec.Bx1, Vec.By1
  For f = 0 To 5
    b = Vec.Face(f)
    If b Then V9938.Spans Vec.Y0, Vec.Y1, 2 + (b - 1) * 12 \ 65, Vec.L(), Vec.R()
  Next
  V9938.Show
Loop
