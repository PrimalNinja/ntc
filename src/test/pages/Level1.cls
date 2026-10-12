Public Function Play(ByVal n As Integer) As Integer
  Dim s As Integer
  s = Shared.Sum(n) + Counter.Bump() * 100 + Counter.Bump() * 1000
  Play = s + Twice(1) + Shared.Ext(2)
End Function
Private Function Twice(ByVal x As Integer) As Integer
  Twice = x * 2
End Function
