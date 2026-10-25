' HWTEST - MSX2 (V9938): a screen mode, the screen cleared, some text, and bouncing balls -
' hardware sprites with a colour for each line (shaded), each moving and animating on its own.
' A cartridge: build.js puts a stub in front that copies the program to RAM at #C000 and runs it.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Org &HC000
Option Stack &HFFF0                       ' (all the RAM: no BIOS is used. Not at the very top: #FFFF is the MSX2's sub-slot switch)
Option Turbo
Option Explicit
Dim i As Integer

Mode 1                                   ' Graphic 3: 32 x 24 text, sprites with a colour a line
Cls
Print "HWTEST - MSX2"
Print "V9938: 32 sprites, 16x16,"
Print "a colour a line, 8 on a line"
Print "8 balls, each moving and"
Print "spinning on its own"

For i = 0 To 5                           ' palette 8-13: the ball's shades, dark to light red
  V9938.Palette 8 + i, 2 + i, i \ 2, i \ 2
Next
For i = 0 To 3
  V9938.Pattern i, Art.Ball() + i * 32
Next
V9938.Bounds 0, 48, 239, 175             ' below the text
For i = 0 To 7
  V9938.Put i, 8 + i * 28, 56 + (i * 23) Mod 100, 0
  V9938.Lines i, Art.BallLines()
  V9938.Move i, 1 + (i Mod 3), 1 + ((i + 1) Mod 2)
  V9938.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
Do
  V9938.Frame
Loop
