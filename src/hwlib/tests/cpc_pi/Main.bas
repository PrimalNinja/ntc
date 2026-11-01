' HWTEST - AMSTRAD CPC + the Pi's VDP (profile v9990): the balls of the V9990 test, on the Pi's
' HDMI through a CPC-CPLink. The CPC's screen says what it is; the Pi draws. Build: Pi.cls and
' the V9990 test's Art.cls (its 16 x 16 4-bit ball patterns are the Pi's v9990 format).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit
Dim i As Integer
Print "HWTEST - CPC + the Pi's VDP (v9990)"
Pi.Init
Pi.Palette 1, 56, 0, 0 : Pi.Palette 2, 96, 0, 16 : Pi.Palette 3, 144, 16, 24 : Pi.Palette 4, 192, 40, 40
Pi.Palette 5, 224, 80, 56 : Pi.Palette 6, 248, 128, 96 : Pi.Palette 7, 255, 255, 255
Pi.Palette 8, 160, 160, 0 : Pi.Palette 9, 216, 216, 0 : Pi.Palette 10, 255, 255, 120
For i = 0 To 3
  Pi.Pattern i, Art.Ball() + i * 128
Next
Pi.Bounds 0, 48, 239, 195
For i = 0 To 11
  Pi.Put i, 6 + i * 19, 56 + (i * 23) Mod 120, 0
  Pi.Move i, 1 + (i Mod 3), 1 + ((i + 1) Mod 2)
  Pi.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
Do
  Pi.Frame
Loop
