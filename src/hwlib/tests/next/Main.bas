' HWTEST - ZX Spectrum Next (Zxn): a screen mode, the screen cleared, some text, and bouncing
' balls - hardware sprites, each moving and animating on its own.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim i As Integer

Mode 1                                   ' the tilemap, 40 x 32
Cls
Print "HWTEST - ZX SPECTRUM NEXT"
Print "Zxn: 128 hardware sprites, 8 bit"
Print "8 balls, each moving and spinning"
Print "on its own (Move, Anim)"

Zxn.Init
For i = 0 To 3
  Zxn.Pattern i, Art.Ball() + i * 256
Next
Zxn.Bounds 32, 72, 271, 207              ' the paper below the text
For i = 0 To 7
  Zxn.Put i, 40 + i * 26, 80 + (i * 17) Mod 100, 0
  Zxn.Move i, 1 + (i Mod 3), 1 + ((i + 1) Mod 2)
  Zxn.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
Do
  Zxn.Frame
Loop
