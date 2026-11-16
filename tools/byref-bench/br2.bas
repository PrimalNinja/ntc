Dim i As Integer, a As Integer, b As Integer, c As Integer
For i = 1 To 1000
  Work a, b, c
Next
Print a; b; c
End
Sub Work(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer)
  x = x + 1
  y = y + x
  z = z + y
  If z > 1000 Then z = z - 1000
  y = y And 255
  x = x And 127
End Sub
