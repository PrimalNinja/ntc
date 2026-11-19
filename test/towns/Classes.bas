' FM Towns: the Memory and Keys classes, and a high data file (townsregress.sh: the pad is pressed by
' the runner's --pad, which needs Tsugaru with test/tsugaru-padset.patch)
Option Explicit
Dim a As Long, b As Long, f As Long, j As Integer, k As Integer, t As Integer
f = Memory.Free()
a = Memory.Alloc(100000)
b = Memory.Alloc(40)
If a >= 65536 And b = a + 100000 And Memory.Free() = f - 100040 Then Print "low ok" Else Print "low BAD"
If Memory.Alloc(2000000) = 0 Then Print "none ok" Else Print "none BAD"
a = Memory.AllocHigh(4096)
If a >= 1048576 And Memory.FreeHigh() > 0 Then Print "high ok" Else Print "high BAD"
If Dat.Byte(0) = 78 And Dat.Byte(4) = 49 And Dat.Where() >= 1048576 Then Print "file ok" Else Print "file BAD"
Print "pad?"
t = 0
Do
  Frame
  j = Keys.Joystick(0)
  If Keys.Down(Keys.KeyQ) Then k = 1
  t = t + 1
Loop Until j <> 0 Or t > 30000
Print "pad"; j
Print "key?"
Do
  k = Inkey
  j = Keys.Down(Keys.KeyZ)
Loop Until k <> 0
Print "key"; k
Print "end"
End
