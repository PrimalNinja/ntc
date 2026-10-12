' Function calls inside expressions keep the caller's temps (regress.sh): each Function
' uses temps of its own kind, so a second call used to overwrite the first one's value
Dim t As Integer, r As Long, s As String
t = &HA600
r = U(t) - U(&H8000)
Print "long"; r
s = Tag$("a") + Tag$("b") + Tag$("c")
Print "str "; s
Print "int"; (Sq(3) + 1) * (Sq(4) + 1); Sq(Sq(2) + Sq(1))
Print "mix"; Len(Tag$("x") + Tag$("yy")) + U(-1) - U(-2)
Print "deep"; Outer(2)
Function U(ByVal x As Integer) As Long
  If x < 0 Then U = CLng(x) + 65536 Else U = x
End Function
Function Tag$(ByVal a As String)
  Tag$ = "<" + UCase$(a) + "-" + a + ">"
End Function
Function Sq(ByVal n As Integer) As Integer
  Sq = (n + 0) * (n + 0)
End Function
Function Outer(ByVal n As Integer) As Long
  Outer = U(-n) * 2 - U(-n - 1) + Sq(n + 1) * Sq(n)
End Function
