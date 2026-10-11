' VB self test 10 - For Each, Property with arguments, local arrays cleared, #asm jump to a label
Option Explicit

Type Pt
  x As Integer
  name As String
End Type

Dim t As Integer, bad As Integer
Dim i As Integer, x As Integer, sum As Integer
Dim a(4) As Integer
Dim s(2) As String, w As String
Dim d() As Long
Dim e As Long
Dim pts(3) As Pt
Dim fx As String * 5
Dim parts() As String

Cls
Print "VB self test 10"

' ---- For Each over arrays
For i = 0 To 4
  a(i) = i * 3
Next
sum = 0
For Each x In a
  sum = sum + x
Next x
Chk sum, 30
s(0) = "a"
s(1) = "b"
s(2) = "c"
w = ""
Dim one As String
For Each one In s
  w = w & one
Next
ChkS w, "abc"
Chk SumOf(a), 30
ReDim d(1 To 3)
d(1) = 100000
d(3) = 5
e = 0
For Each e In d
  sum = sum + 1
Next
Chk sum, 33
Chk (e = 5), -1

' ---- Property Get / Let with arguments
Bag.Item(3) = 42
Bag.Item(4) = Bag.Item(3) + 1
Chk Bag.Item(3), 42
Chk Bag.Item(4), 43

' ---- local arrays start cleared on every call
Chk Fresh(), 5
Chk Fresh(), 5
Chk Kept(), 5
Chk Kept(), 10

' ---- #asm jumping to a BASIC label
x = 1
#asm
            ld sp, {skip}
            ret
#endasm
x = 2
skip:
Chk x, 1

' ---- an array of a Type as a parameter
For i = 0 To 3
  pts(i).x = i * 10
  pts(i).name = "n" & i
Next
Chk TotalX(pts), 60
ChkS Names(pts), "n1n3"
BumpX pts
Chk pts(2).x, 21

' ---- Like
w = "hello.bas"
Chk (w Like "*.bas"), -1
Chk (w Like "*.cls"), 0
Chk ("cat" Like "[bc]at"), -1
Chk ("rat" Like "[!bc]at"), -1
Chk ("a5" Like "a#"), -1
Chk ("aXbXc" Like "*X*c"), -1

' ---- LSet / RSet, String * n
w = Space$(6)
LSet w = "ab"
ChkS w, "ab    "
RSet w = "ab"
ChkS w, "    ab"
fx = "ab"
ChkS fx, "ab   "
fx = "abcdefgh"
ChkS fx, "abcde"
Chk Len(fx), 5

' ---- Format$, Join, Split
i = 42
ChkS Format$(i, "0000"), "0042"
e = 1234567
ChkS Format$(e, "#,##0"), "1,234,567"
ChkS Format$(-i, "$0.00"), "-$42.00"
ChkS Join(s, "-"), "a-b-c"
parts = Split("x,yy,,z", ",")
Chk UBound(parts), 3
ChkS parts(1) & parts(3), "yyz"
ChkS Join(parts, "/"), "x/yy//z"

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

Sub ChkS(ByVal got As String, ByVal want As String)
  t = t + 1
  Print t; ":";
  If got = want Then
    Print "ok ";
  Else
    Print "FAIL["; got; "] ";
    bad = bad + 1
  End If
End Sub

Function SumOf(v() As Integer) As Integer
  Dim n As Integer
  SumOf = 0
  For Each n In v
    SumOf = SumOf + n
  Next
End Function

Function Fresh() As Integer
  Dim b(3) As Integer
  b(1) = b(1) + 5
  Fresh = b(1)
End Function

Function Kept() As Integer
  Static c(3) As Integer
  c(1) = c(1) + 5
  Kept = c(1)
End Function

Function TotalX(a() As Pt) As Integer
  Dim k As Integer
  For k = LBound(a) To UBound(a)
    TotalX = TotalX + a(k).x
  Next
End Function

Function Names(a() As Pt) As String
  Names = a(1).name & a(3).name
End Function

Sub BumpX(a() As Pt)
  a(2).x = a(2).x + 1
End Sub
