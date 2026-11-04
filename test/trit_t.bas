' Trit (lib/z80/Trit.cls) self test: the logic, packing 4 a byte, Get4 / Set4, Scan, Dot against
' a BASIC sum. "TRIT bad 0" when everything matched.
Option Explicit
Dim t(63) As Byte, p(15) As Byte, u(63) As Byte, x(63) As Byte
Dim i As Integer, j As Integer, bad As Integer, s As Integer, d As Integer, v As Integer, w As Integer
Dim seed As Integer

Sub Chk(ByVal name As String, ByVal got As Integer, ByVal want As Integer)
  If got <> want Then Print "FAIL "; name; " got"; got; " want"; want : bad = bad + 1
End Sub

' the logic
Chk "and", Trit.Tand(1, -1), -1
Chk "and0", Trit.Tand(1, 0), 0
Chk "or", Trit.Tor(-1, 0), 0
Chk "or1", Trit.Tor(-1, 1), 1
Chk "not", Trit.Tnot(1), -1
Chk "mul", Trit.Tmul(-1, -1), 1
Chk "mul0", Trit.Tmul(-1, 0), 0
Chk "maj", Trit.Tmaj(1, 1, -1), 1
Chk "maj0", Trit.Tmaj(1, -1, 0), 0
Chk "gate", Trit.Gate(-1, 37), -37
Chk "gate0", Trit.Gate(0, 37), 0
Chk "frombyte", Trit.FromByte(255), -1
Chk "tobyte", Trit.ToByte(-1), 255

' 64 trits in a pattern, packed and unpacked
seed = 7
For i = 0 To 63
  seed = (seed * 13 + 5) Mod 97
  v = seed Mod 3
  If v = 2 Then v = 255
  t(i) = v
Next
Trit.Pack VarPtr(t(0)), VarPtr(p(0)), 64
Trit.Unpack VarPtr(p(0)), VarPtr(u(0)), 64
d = 0
For i = 0 To 63
  If t(i) <> u(i) Then d = d + 1
Next
Chk "pack roundtrip", d, 0
' the first byte by hand: trit 0 in bits 0-1
w = 0
For i = 3 To 0 Step -1
  w = w * 4
  If t(i) = 1 Then
    w = w + 1
  ElseIf t(i) = 255 Then
    w = w + 3
  End If
Next
Chk "pack byte 0", p(0), w
' Get4 / Set4
For i = 0 To 3
  Chk "get4 " + Str$(i), Trit.Get4(VarPtr(p(0)), i), Trit.FromByte(t(i))
Next
Trit.Set4 VarPtr(p(0)), 2, 1
Chk "set4", Trit.Get4(VarPtr(p(0)), 2), 1
Chk "set4 keeps 1", Trit.Get4(VarPtr(p(0)), 1), Trit.FromByte(t(1))
Chk "set4 keeps 3", Trit.Get4(VarPtr(p(0)), 3), Trit.FromByte(t(3))
Trit.Set4 VarPtr(p(0)), 2, Trit.FromByte(t(2))
' Scan
Chk "scan mixed", Trit.Scan(VarPtr(p(0)), 16), 3
For i = 0 To 15
  p(i) = 0
Next
Chk "scan zero", Trit.Scan(VarPtr(p(0)), 16), 0
p(9) = &H10                                   ' trit 2 of byte 9 is 1
Chk "scan one pos", Trit.Scan(VarPtr(p(0)), 16), 1
p(9) = &HC0                                   ' trit 3 is -1
Chk "scan one neg", Trit.Scan(VarPtr(p(0)), 16), 2
p(9) = &H80                                   ' the spare code 10: neutral
Chk "scan spare", Trit.Scan(VarPtr(p(0)), 16), 0
' Dot against BASIC
Trit.Pack VarPtr(t(0)), VarPtr(p(0)), 64
seed = 3
s = 0
For i = 0 To 63
  seed = (seed * 11 + 7) Mod 251
  x(i) = seed
  v = seed
  If v > 127 Then v = v - 256
  s = s + Trit.Gate(Trit.FromByte(t(i)), v)
Next
Chk "dot", Trit.Dot(VarPtr(p(0)), VarPtr(x(0)), 64), s
' Dot with a zero weight byte in the middle (the skip-four path)
p(5) = 0
s = 0
For i = 0 To 63
  v = x(i)
  If v > 127 Then v = v - 256
  If i < 20 Or i > 23 Then s = s + Trit.Gate(Trit.FromByte(t(i)), v)
Next
Chk "dot skip", Trit.Dot(VarPtr(p(0)), VarPtr(x(0)), 64), s
Print "TRIT bad"; bad
