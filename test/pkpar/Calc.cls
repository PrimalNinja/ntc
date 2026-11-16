Public Function Add(ByVal x As Integer, ByVal y As Integer) As Integer
  Add = x + y
End Function
Public Function Mix(ByVal x As Integer, ByVal t As String, ByVal y As Integer, ByVal k As Long, ByRef o As Integer) As Integer
  o = x + y
  Mix = Len(t) + x + y + (k \ 1000)
End Function
Public Function One(ByVal x As Integer) As Integer
  x = x + 1
  One = x
End Function
Public Function Chain(ByVal x As Integer, ByVal y As Integer) As Integer
  Chain = Add(x, y) + Other.Twice(x) + x + y
End Function
Public Function None() As Integer
  None = 9
End Function
Private Paged pgv As Integer
Public Function Up(ByVal x As Integer) As Integer
  Other.Inc x
  Up = x
End Function
Public Function Pv() As Integer
  pgv = 40
  Other.Inc pgv
  Pv = pgv
End Function
Private Function Sq(ByVal x As Integer, ByVal y As Integer) As Integer
  Sq = x * y
End Function
Public Function Loc(ByVal x As Integer) As Integer
  Loc = Sq(x, x + 1) + Sq(2, 3)
End Function
Public Function Opt(ByVal x As Integer, Optional ByVal y As Integer = 9) As Integer
  Opt = x + y
End Function
Public Function Lng(ByVal x As Long, ByVal y As Long) As Long
  Lng = x + y
End Function
Public Function Byt(ByVal x As Byte, ByVal y As Byte) As Integer
  Byt = x + y
End Function
