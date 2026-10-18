' CKEY - a KEYMAN client: write a message, ask KEYMAN to encode it, read it back, ask to decode,
' check the round-trip. The data moves through the kernel (KEYMAN reads / writes this slot).
Option Explicit
Dim msg(63) As Byte, enc(2047) As Byte, dec(63) As Byte
Dim i As Integer, el As Integer, dl As Integer, ok As Integer
Dim s As String Max 64, rep As String Max 128
s = "KEYMAN test - hello from the client slot!"
For i = 1 To Len(s)
  msg(i - 1) = Asc(Mid$(s, i, 1))
Next
rep = CybSys.PortCall("KEYMAN", "E mu:TK " + Hex4(Len(s)) + " " + Hex4(VarPtr(msg(0))) + " " + Hex4(VarPtr(enc(0))))
Print "E -> "; rep
If Left$(rep, 2) <> "ok" Then End
el = HexV(Trim$(Mid$(rep, 3)))
rep = CybSys.PortCall("KEYMAN", "D mu:TK " + Hex4(el) + " " + Hex4(VarPtr(enc(0))) + " " + Hex4(VarPtr(dec(0))))
Print "D -> "; rep
dl = HexV(Trim$(Mid$(rep, 3)))
ok = 1
If dl <> Len(s) Then ok = 0
For i = 0 To Len(s) - 1
  If dec(i) <> msg(i) Then ok = 0
Next
If ok = 1 Then Print "ROUNDTRIP ok enc "; el; " bytes" Else Print "ROUNDTRIP FAIL dl "; dl
End

Function HexV(ByVal h As String) As Integer
  Dim q As Integer, c As Integer, v As Integer
  v = 0
  For q = 1 To Len(h)
    c = Asc(UCase$(Mid$(h, q, 1)))
    If c >= 65 Then c = c - 55 Else c = c - 48
    v = v * 16 + c
  Next
  HexV = v
End Function
Function Hex4(ByVal n As Integer) As String
  Dim s2 As String Max 4, i As Integer, d As Integer, v As Long
  v = n And &HFFFF
  s2 = ""
  For i = 0 To 3
    d = (v \ (16 ^ (3 - i))) And 15
    s2 = s2 + Mid$("0123456789ABCDEF", d + 1, 1)
  Next
  Hex4 = s2
End Function
