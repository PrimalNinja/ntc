' Mega Drive: the Vdp class's calls for games, and the Z80 and Keys classes (mdregress.sh)
Option Explicit
Dim a As Long, i As Integer
a = Vdp.Sat()
If a <> 0 Then Print "sat ok" Else Print "sat BAD"
Vdp.Display 0
Vdp.ScrollMode Vdp.ScrollCell
For i = 0 To 27
  Vdp.ScrollRow Vdp.PlaneB, i, i
Next
Vdp.ScrollMode Vdp.ScrollLine
Vdp.ScrollLineX Vdp.PlaneB, 100, 5
Vdp.ScrollMode Vdp.ScrollWhole
Vdp.Copy a, &HE000, 16
Vdp.Fill Vdp.PlaneB, 0, 0, 64, 32, 0
Vdp.Display 1
Print "vdp ok"
Z80.Load Prog.Where(), 8
For i = 1 To 5
  Frame
Next
If Z80.Peek(&H1000) = 85 Then Print "z80 ok" Else Print "z80 BAD"; Z80.Peek(&H1000)
Z80.Poke &H1001, 123
If Z80.Peek(&H1001) = 123 Then Print "poke ok" Else Print "poke BAD"
Z80.Stop
If Keys.Joystick(0) = 0 And Keys.Down(Keys.KeyQ) = 0 Then Print "keys ok" Else Print "keys BAD"
Print "end"
End
