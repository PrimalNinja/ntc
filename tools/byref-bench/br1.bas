Dim i As Integer, a As Integer, b As Integer, c As Integer, s As String, n As Integer
s = "the quick brown fox jumps over"
For i = 1 To 1000
  Work a, b, c
Next
Print a; b; c
For i = 1 To 1000
  n = n + Cnt(s)
Next
Print n
For i = 1 To 1000
  One a
Next
Print a
End
Sub Work(x As Integer, y As Integer, z As Integer)
  x = x + 1
  y = y + x
  z = z + y
  If z > 1000 Then z = z - 1000
  y = y And 255
  x = x And 127
End Sub
Function Cnt(t As String) As Integer
  Cnt = Len(t)
End Function
Sub One(x As Integer)
  x = x + 1
End Sub
