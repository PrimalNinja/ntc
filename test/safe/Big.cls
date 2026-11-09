' a safe class whose procedures are big (thread code), to spread over two Safe ranges
Public Function A(ByVal x As Integer) As Integer
  Dim i As Integer, t As Integer
  t = x
  For i = 1 To 3
    t = t + i * 2 + x * 3 - 1 + i * i - x + 7 - i + 2 * x + 9 - 3 * i + 11
  Next
  t = t + 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20
  t = t + 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20
  A = t
End Function
Public Function B(ByVal x As Integer) As Integer
  Dim i As Integer, t As Integer
  t = x
  For i = 1 To 3
    t = t + i * 2 + x * 3 - 1 + i * i - x + 7 - i + 2 * x + 9 - 3 * i + 11
  Next
  t = t + 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20
  t = t + 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12 + 13 + 14 + 15 + 16 + 17 + 18 + 19 + 20
  B = t
End Function
Public Function C(ByVal x As Integer) As Integer
  C = x + 100
End Function
