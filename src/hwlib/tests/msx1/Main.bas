' HWTEST - MSX1 (Tms9918): a screen mode, the screen cleared, some text, and bouncing balls -
' hardware sprites, each moving and animating on its own. A cartridge: build.js puts a stub in
' front that copies the program to RAM at #C000 and runs it.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Org &HC000
Option Stack &HFFF0                       ' (all the RAM: no BIOS is used. Not at the very top: #FFFF is the MSX2's sub-slot switch)
Option Turbo
Option Explicit
Dim i As Integer

Mode 1                                   ' Graphic 1: 32 x 24 text, sprites
Cls
Print "HWTEST - MSX1"
Print "Tms9918: 32 sprites, 16x16,"
Print "1 colour, 4 on a line"
Print "6 balls, each moving and"
Print "spinning on its own"

For i = 0 To 3
  Tms9918.Pattern i, Art.Ball() + i * 32
Next
Tms9918.Bounds 0, 48, 239, 175           ' below the text
For i = 0 To 5
  Tms9918.Put i, 10 + i * 36, 56 + (i * 23) Mod 100, 0
  Tms9918.Colour i, Choose(i + 1, 8, 11, 9, 2, 7, 13)
  Tms9918.Move i, 1 + (i Mod 3), 1 + ((i + 1) Mod 2)
  Tms9918.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
Do
  Tms9918.Frame
Loop
