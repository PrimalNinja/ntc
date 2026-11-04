' Tiny (lib/z80/Tiny.cls) self test: Mul against Long arithmetic over every sign and the ends,
' Div, Tanh / Sigm against their definitions' shape, Dot against a BASIC sum, Text.
' "TINY bad 0" when everything matched.
Option Explicit
Dim bad As Integer, a As Integer, b As Integer, w As Integer, e As Integer, i As Integer
Dim l As Long, seed As Integer, s As Long
Dim wb(31) As Byte, xb(31) As Byte

Sub Chk(ByVal name As String, ByVal got As Integer, ByVal want As Integer)
  If got <> want Then Print "FAIL "; name; " got"; got; " want"; want : bad = bad + 1
End Sub

' floor((a * b + 32) / 64), saturated - the reference (a half rounds up)
Function RefMul(ByVal a As Integer, ByVal b As Integer) As Integer
  Dim p As Long, q As Long, ng As Integer
  p = CLng(a) * b + 32
  If p < 0 Then q = -((-p + 63) \ 64) Else q = p \ 64      ' floor(p / 64)
  If q > 127 Then q = 127
  If q < -128 Then q = -128
  RefMul = q
End Function

Chk "sat hi", Tiny.Sat(300), 127
Chk "sat lo", Tiny.Sat(-300), -128
Chk "add", Tiny.Add(100, 50), 127
Chk "sub", Tiny.Subtract(-100, 50), -128
Chk "add2", Tiny.Add(30, -50), -20
Chk "frombyte", Tiny.FromByte(200), -56
Chk "tobyte", Tiny.ToByte(-56), 200
' Mul: a grid of signs and sizes, then the ends
seed = 11
For i = 1 To 60
  seed = (seed * 7 + 3) Mod 211
  a = seed - 105
  seed = (seed * 5 + 1) Mod 199
  b = seed - 99
  If a > 127 Then a = 127
  If a < -128 Then a = -128
  If b > 127 Then b = 127
  If b < -128 Then b = -128
  Chk "mul " + Str$(a) + "," + Str$(b), Tiny.Mul(a, b), RefMul(a, b)
Next
Chk "mul one", Tiny.Mul(64, 64), 64
Chk "mul half", Tiny.Mul(64, 32), 32
Chk "mul max", Tiny.Mul(127, 127), 127
Chk "mul min", Tiny.Mul(-128, -128), 127
Chk "mul minmax", Tiny.Mul(-128, 127), -128
Chk "mul zero", Tiny.Mul(0, -77), 0
Chk "mul negzero", Tiny.Mul(-1, 1), 0
Chk "mul round", Tiny.Mul(1, 32), 1
Chk "mul round-", Tiny.Mul(-1, 32), 0
' Div
Chk "div one", Tiny.Div(32, 64), 32
Chk "div two", Tiny.Div(64, 32), 127
Chk "div ng", Tiny.Div(-32, 64), -32
Chk "div zero", Tiny.Div(5, 0), 127
Chk "div zero-", Tiny.Div(-5, 0), -128
Chk "div 0/0", Tiny.Div(0, 0), 0
Chk "div third", Tiny.Div(21, 64), 21
' Tanh and the sigmoid: the shape
Chk "tanh 0", Tiny.Tanh(0), 0
Chk "tanh 1", Tiny.Tanh(64), 49
Chk "tanh -1", Tiny.Tanh(-64), -49
Chk "tanh big", Tiny.Tanh(127), 62
Chk "tanh -big", Tiny.Tanh(-128), -62
Chk "sigm 0", Tiny.Sigm(0), 32
Chk "sigm 1", Tiny.Sigm(64), 47
Chk "sigm -1", Tiny.Sigm(-64), 17
Chk "sigm -big", Tiny.Sigm(-128), 8
' Dot against a Long sum
seed = 5
s = 0
For i = 0 To 31
  seed = (seed * 13 + 7) Mod 251
  w = seed - 125
  seed = (seed * 3 + 11) Mod 241
  e = seed - 120
  wb(i) = Tiny.ToByte(w)
  xb(i) = Tiny.ToByte(e)
  s = s + CLng(w) * e
Next
l = s + 32
If l < 0 Then l = -((-l + 63) \ 64) Else l = l \ 64
If l > 127 Then l = 127
If l < -128 Then l = -128
Chk "dot", Tiny.Dot(VarPtr(wb(0)), VarPtr(xb(0)), 32), l
wb(3) = 0 : xb(7) = 0
s = 0
For i = 0 To 31
  s = s + CLng(Tiny.FromByte(wb(i))) * Tiny.FromByte(xb(i))
Next
l = s + 32
If l < 0 Then l = -((-l + 63) \ 64) Else l = l \ 64
If l > 127 Then l = 127
If l < -128 Then l = -128
Chk "dot zeros", Tiny.Dot(VarPtr(wb(0)), VarPtr(xb(0)), 32), l
' Text
If Tiny.Text(-48) <> "-0.75" Then Print "FAIL text "; Tiny.Text(-48) : bad = bad + 1
If Tiny.Text(64) <> "1.00" Then Print "FAIL text1 "; Tiny.Text(64) : bad = bad + 1
If Tiny.Text(5) <> "0.07" Then Print "FAIL text5 "; Tiny.Text(5) : bad = bad + 1
Print "TINY bad"; bad
