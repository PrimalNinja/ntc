' CUBE - SEGA SC-3000 (Tms9918): a solid cube turning, lit, faces turned away dropped - Graphic 2, the
' faces shaded by dither patterns (2 colours in each 8 pixels: no colour clash this way), drawn
' in RAM and copied to the character set not shown, the sets swapped at the frame. A cartridge
' (copied to a 32K RAM cartridge at #8000).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Org &H8000
Option Turbo
Option Explicit
Dim f As Integer, b As Integer

Mode 2                                   ' Graphic 2: text above, a 120 x 128 picture below
Cls
Print "CUBE - SEGA SC-3000 (Tms9918)"
Print "Graphic 2, 8 dither shades,"
Print "drawn in RAM, 2 character sets"
Vec.Setup 42, 400, 256, 60, 64, 0
Do
  Tms9918.Begin                              ' the old picture's box cleared
  Vec.Turn 2, 3, 1
  Vec.Project
  Tms9918.Keep Vec.Bx0, Vec.By0, Vec.Bx1, Vec.By1
  For f = 0 To 5
    b = Vec.Face(f)
    If b Then Tms9918.Spans Vec.Y0, Vec.Y1, Art.Dither() + ((b - 1) * 8 \ 65) * 4, Vec.L(), Vec.R()
  Next
  Tms9918.Show
Loop
