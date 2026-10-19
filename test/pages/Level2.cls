Public Function Play(ByVal n As Integer) As Integer
  Dim s As Integer
  s = Shared.Sum(n) + Shared.Odd(n) + Counter.Bump() * 100 + Counter.Bump() * 1000
  Play = s + Twice(5) + Shared.Ext(1) + Helper(3)
End Function
Private Function Twice(ByVal x As Integer) As Integer
  Twice = x * 2
End Function
