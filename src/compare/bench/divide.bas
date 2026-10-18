' multiply, divide and remainder, 5000 times
Option Explicit
Dim s As Integer
Print "go"
Turbo On
Bench
Turbo Off
Print "turbo "; s
Print "go"
Bench
Print "normal "; s
End
Sub Bench()
  Dim i As Integer, x As Integer
  s = 0
  For i = 1 To 5000
    x = (i * 5) \ 3 + i Mod 13
    s = s Xor x
  Next
End Sub
