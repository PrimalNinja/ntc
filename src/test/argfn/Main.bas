Dim a As Integer
A2.Show 1, 2, F(3), F(4), 5, 6, F(7), F(8)
A2.Show 1, 2, 3, 4, 5, 6, 7, 8
Show2 1, 2, F(3), F(4), 5, 6, F(7), F(8)
Function F(ByVal x As Integer) As Integer
  F = x * 10
End Function
Sub Show2(ByVal a As Integer, ByVal b As Integer, ByVal c As Integer, ByVal d As Integer, ByVal e As Integer, ByVal f As Integer, ByVal g As Integer, ByVal h As Integer)
  Print a; b; c; d; e; f; g; h
End Sub
