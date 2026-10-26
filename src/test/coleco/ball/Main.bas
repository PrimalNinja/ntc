' Ball - move a ball around the screen with the controller 1 joystick. ColecoVision, NTC BASIC.
' Built by tools/coleco/build.js (bare metal platform with the ColecoVision's ROM keys).
' Graphics 1 (32 x 24 tiles), a 16 x 16 sprite for the ball, a border of tiles. The frame is polled
' (the VDP's NMI is off: SP is the thread and an NMI would push on it).
Const MinX = 8
Const MaxX = 232
Const MinY = 8
Const MaxY = 168
Const Speed = 2

Dim x As Integer, y As Integer, j As Integer, r As Integer

' the chip: Graphics 1, 16K, display off while the screen is made
Coleco.Reg 1, &H80
Coleco.Reg 0, 0
Coleco.Reg 2, 6          ' name table   VRAM &H1800
Coleco.Reg 3, &H80       ' colour table VRAM &H2000
Coleco.Reg 4, 0          ' patterns     VRAM &H0000
Coleco.Reg 5, &H36       ' sprites      VRAM &H1B00
Coleco.Reg 6, 7          ' sprite patterns VRAM &H3800
Coleco.Reg 7, &HF4       ' the backdrop: dark blue

Coleco.Fill 0, 16384, 0
Coleco.Gfx
Coleco.Fill &H1800, 768, 2          ' dots everywhere
Coleco.Fill &H1800, 32, 1           ' the border: top row
Coleco.Fill &H1800 + 736, 32, 1     ' bottom row
For r = 1 To 22
  Coleco.VPoke &H1800 + r * 32, 1       ' left column
  Coleco.VPoke &H1800 + r * 32 + 31, 1  ' right column
Next

x = 120
y = 88
Coleco.Sprite x, y
Coleco.Reg 1, &HC2                  ' display on, 16 x 16 sprites, NMI off

Do
  Coleco.Frame
  j = Coleco.Joy
  If (j And 1) <> 0 Then y = y - Speed
  If (j And 4) <> 0 Then y = y + Speed
  If (j And 8) <> 0 Then x = x - Speed
  If (j And 2) <> 0 Then x = x + Speed
  If x < MinX Then x = MinX
  If x > MaxX Then x = MaxX
  If y < MinY Then y = MinY
  If y > MaxY Then y = MaxY
  Coleco.Sprite x, y
Loop
