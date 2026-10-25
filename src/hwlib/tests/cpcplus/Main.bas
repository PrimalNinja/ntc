' HWTEST - Amstrad CPC Plus (Asic): a screen mode, the screen cleared, some text, and bouncing
' balls - the ASIC's hardware sprites in 15 colours of their own, each moving and animating on
' its own. RUN"CPCPLUS. UNTESTED on the hardware (no CPC Plus emulator here).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Reserve &H4000, &H4000             ' the ASIC's registers are paged in there
Option Turbo
Option Explicit
Dim i As Integer

Mode 1                                   ' 320 x 200, 40 x 25 text
Cls
Print "HWTEST - AMSTRAD CPC PLUS"
Print "Asic: 16 hardware sprites, 16x16,"
Print "15 colours of their own"
Print "12 balls, each moving and spinning"
Print "on its own"

Asic.Init
Asic.Palette Art.SprPal()
For i = 0 To 3
  Asic.Pattern i, Art.Ball() + i * 256
Next
Asic.Bounds 0, 48, 303, 183              ' below the text
For i = 0 To 11
  Asic.Put i, 8 + i * 24, 52 + (i * 23) Mod 120, 0
  Asic.Move i, 1 + (i Mod 3), 1 + ((i + 1) Mod 2)
  Asic.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
Do
  Asic.Frame
Loop
