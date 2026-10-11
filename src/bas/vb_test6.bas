' VB self test 6 - Byte arrays, dynamic arrays (ReDim / Preserve / Erase)
Option Explicit

Const BIGN = 20

Type Rec
  n As Integer
  nm As String
End Type

Dim t As Integer, bad As Integer
Dim i As Integer, s As Integer
Dim buf(9) As Byte
Dim dyn() As Integer
Dim names() As String
Dim big() As Long
Dim fixed(4) As Integer
Dim recs() As Rec

Cls
Print "VB self test 6"

' ---- Byte arrays: 1 byte per element, 0 .. 255
For i = 0 To 9
  buf(i) = i * 30
Next
Chk buf(9), 14          ' 270 And 255
Chk buf(2), 60
i = 3
Chk buf(i), 90
buf(0) = 255
Chk buf(0), 255
Chk ByteSum(buf), 255 + 30 + 60 + 90 + 120 + 150 + 180 + 210 + 240 + 14

' ---- dynamic arrays
ReDim dyn(5)
Chk UBound(dyn), 5
Chk LBound(dyn), 0
For i = 0 To 5
  dyn(i) = i * i
Next
Chk dyn(5), 25
ReDim Preserve dyn(BIGN)
Chk UBound(dyn), 20
Chk dyn(4), 16
dyn(20) = 7
Chk dyn(20), 7
ReDim dyn(1 To 3)
Chk LBound(dyn), 1
Chk dyn(1), 0           ' cleared without Preserve
dyn(3) = 9
Chk Total(dyn), 9
Erase dyn
Chk UBound(dyn), -1

ReDim names(2)
names(1) = "dyn"
Chk Len(names(1)), 3
ReDim big(1)
big(1) = 100000
Chk big(1) \ 1000, 100

' ---- Erase a fixed array clears it
fixed(2) = 5
Erase fixed
Chk fixed(2), 0

' ---- a dynamic array of a Type
ReDim recs(2)
For i = 0 To 2
  recs(i).n = i * 5
  recs(i).nm = "r" & i
Next
Chk UBound(recs), 2
Chk Len(recs(1).nm) + recs(2).n, 12
ReDim Preserve recs(4)
Chk recs(2).n, 10
Erase recs
Chk UBound(recs), -1

Print
Print t; " tests, "; bad; " failed"
Print "Press a key";
Do : Frame : Loop Until Inkey <> 0
Print
End

Sub Chk(ByVal got As Integer, ByVal want As Integer)
  t = t + 1
  Print t; ":";
  If got = want Then
    Print "ok ";
  Else
    Print "FAIL("; got; ") ";
    bad = bad + 1
  End If
End Sub

Function ByteSum(b() As Byte) As Integer
  Dim k As Integer
  ByteSum = 0
  For k = LBound(b) To UBound(b)
    ByteSum = ByteSum + b(k)
  Next
End Function

Function Total(a() As Integer) As Integer
  Dim k As Integer
  Total = 0
  For k = LBound(a) To UBound(a)
    Total = Total + a(k)
  Next
End Function
