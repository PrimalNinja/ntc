' HWTEST - Amstrad CPC (Cpc): a screen mode, the screen cleared, some text, and bouncing balls -
' software sprites (masked, what's under them put back), double buffered, each moving and
' animating on its own. Load at #40 and CALL &40 (or run the snapshot).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Turbo
Option Explicit
Dim i As Integer

Mode 0                                   ' 160 x 200, 16 pens, 20 x 25 text
Cpc.Inks Art.Inks()
Cls
Print "HWTEST - CPC"
Print "Cpc: software"
Print "sprites, mode 0,"
Print "masked, double"
Print "buffered: 8 balls"

Cpc.Init                                 ' (after the text: it copies the screen to the second)
For i = 0 To 3
  Cpc.Pattern i, Art.Ball() + i * 320
Next
Cpc.Bounds 0, 48, 150, 184               ' below the text
For i = 0 To 7
  Cpc.Put i, 4 + i * 18, 52 + (i * 23) Mod 120, 0
  Cpc.Move i, 1 + (i Mod 2), 1 + ((i + 1) Mod 3)
  Cpc.Anim i, 0, 4, 4 + (i Mod 3) * 2
Next
Do
  Cpc.Frame
Loop
