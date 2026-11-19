' X68000: the supervisor call (trap #1), and the Keys, Opm and Vdp classes (x68regress.sh)
Option Explicit
Dim k As Integer, j As Integer, n As Integer, seen As Integer
If Sup.Mode() = &H2000 Then Print "super ok" Else Print "super BAD"
If Keys.Joystick(0) = 0 And Not Keys.Down(Keys.KeyQ) Then Print "idle ok" Else Print "idle BAD"
Opm.Quiet
Print "opm ok"
Print "key?"
Do
  Frame
  If Keys.Down(Keys.KeyQ) Then seen = 1
  n = n + 1
Loop Until seen <> 0 Or n > 20000
Print "held"; seen
Vdp.Init
Vdp.HideAll
Vdp.Update
Print "vdp ok"
Print "end"
End
