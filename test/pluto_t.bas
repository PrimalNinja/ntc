' Pluto engine (apps/pluto/Zc.cls) self test: each of the six layers encodes and decodes several
' message lengths; "PLUTO bad 0" when every round-trip matched. The CPC output is also checked
' byte for byte against the PC (tools/pluto/pluto.py) outside the harness.
Option Explicit
Dim bkey(4095) As Byte, mkey(127) As Byte, msg(199) As Byte, enc(8191) As Byte, dec(199) As Byte
Dim i As Integer, el As Integer, dl As Integer, m As Integer, ml As Integer, ok As Integer, bad As Integer
Dim t As Integer, kl As Integer, kp As Integer
Randomize 2
For i = 0 To 4095
  bkey(i) = (i * 37 + 5) And 255
Next
For i = 0 To 127
  mkey(i) = (i * 7 + 11) And 255
Next
bad = 0
For t = 0 To 2
  ml = 1 + t * 50
  For i = 0 To ml - 1
    msg(i) = 32 + ((i * 13 + t * 7) And 90)
  Next
  For m = 0 To 5
    If m < 3 Then kp = VarPtr(bkey(0)) : kl = 4096 Else kp = VarPtr(mkey(0)) : kl = 128
    If Zc.Open(kp, kl, m) <> 0 Then bad = bad + 1
    Zc.Pad 0
    el = Zc.Encode(VarPtr(msg(0)), ml, VarPtr(enc(0)), 8192)
    dl = -1
    If el >= 0 Then dl = Zc.Decode(VarPtr(enc(0)), el, VarPtr(dec(0)), 200)
    ok = 1
    If dl <> ml Then ok = 0
    For i = 0 To ml - 1
      If dec(i) <> msg(i) Then ok = 0
    Next
    If ok = 0 Then bad = bad + 1 : Print "FAIL m"; m; " ml"; ml; " el"; el; " dl"; dl
  Next
Next
' alignment: u and b with Pad 128 give a multiple of 128 that still round-trips
For m = 1 To 2
  Zc.Open VarPtr(bkey(0)), 4096, m
  Zc.Pad 128
  el = Zc.Encode(VarPtr(msg(0)), 60, VarPtr(enc(0)), 8192)
  If el < 0 Or (el And 127) <> 0 Then bad = bad + 1 : Print "FAIL align m"; m; " el"; el
  Zc.Pad 0
  dl = Zc.Decode(VarPtr(enc(0)), el, VarPtr(dec(0)), 200)
  If dl <> 60 Then bad = bad + 1 : Print "FAIL align rt m"; m; " dl"; dl
Next
Print "PLUTO bad "; bad
End
