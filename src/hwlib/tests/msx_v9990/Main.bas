' HWTEST - MSX + V9990 (GFX9000): a screen mode, the screen cleared, some text, and bouncing balls -
' hardware sprites in 16 colours, each moving and animating on its own. A cartridge: build.js puts
' a stub in front that copies the program to RAM at #C000 and runs it.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Org &HC000
Option Stack &HFFF0                       ' (all the RAM: no BIOS is used. Not at the very top: #FFFF is the MSX2's sub-slot switch)
Option Turbo
Option Explicit
Dim i As Integer

Mode 1                                   ' P1: 256 x 212, 32 x 26 text, sprites
Cls
Print "HWTEST - MSX + V9990 (GFX9000)"
Print "V9990 P1: 125 sprites, 16x16,"
Print "16 colours, 16 on a line"
Print "12 balls, each moving and"
Print "spinning on its own"

V9990.Palette 1, 7, 0, 0                 ' the ball: 1-6 dark to light red, 7 white, 8-10 yellows
V9990.Palette 2, 12, 0, 2
V9990.Palette 3, 18, 2, 3
V9990.Palette 4, 24, 5, 5
V9990.Palette 5, 28, 10, 7
V9990.Palette 6, 31, 16, 12
V9990.Palette 7, 31, 31, 31
V9990.Palette 8, 20, 20, 0
V9990.Palette 9, 27, 27, 0
V9990.Palette 10, 31, 31, 15
For i = 0 To 3
  V9990.Pattern i, Art.Ball() + i * 128
Next
V9990.Bounds 0, 48, 239, 195             ' below the text
For i = 0 To 11
  V9990.Put i, 6 + i * 19, 56 + (i * 23) Mod 120, 0
  V9990.Move i, 1 + (i Mod 3), 1 + ((i + 1) Mod 2)
  V9990.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
Do
  V9990.Frame
Loop
