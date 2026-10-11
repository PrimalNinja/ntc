' 5000 calls of a function with 2 parameters
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
Function Add2(a As Integer, b As Integer) As Integer
  Add2 = a + b
End Function
Sub Bench()
  Dim i As Integer
  s = 0
  For i = 1 To 5000
    s = Add2(i, 3)
  Next
End Sub
