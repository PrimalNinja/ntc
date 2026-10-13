' Long (32 bit) self test - each check prints its number and ok or FAIL
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit

Const BIG = 100000
Const MEGA = BIG * 10

Type Account
  id As Integer
  balance As Long
End Type

Dim t As Integer, bad As Integer
Dim a As Long, b As Long, c As Long
Dim i As Integer, n As Integer
Dim s As String
Dim arr(4) As Long
Dim acc As Account
Dim total&

Cls
Print "Long self test"

' ---- literals and constants
a = 100000
ChkL a, 100000
ChkL BIG, 100000
ChkL MEGA, 1000000
a = -40000
ChkL a, -40000
ChkS Str$(2147483647), " 2147483647"
a = &H7FFFFFFF
ChkL a, 2147483647

' ---- arithmetic
a = 70000
b = 30000
ChkL a + b, 100000
ChkL a - b, 40000
ChkL b - a, -40000
ChkL a * 3, 210000
ChkL a \ 7, 10000
ChkL a / 7, 10000
ChkL a Mod 9, 7
ChkL -a Mod 9, -7
ChkL a * -2, -140000
c = a * 300
ChkL c \ a, 300
ChkL -a, -70000
ChkL Abs(-a), 70000
Chk Sgn(-a), -1
Chk Sgn(a), 1
c = 0
Chk Sgn(c), 0
ChkL (a And &HFFFF&), 4464
ChkL a Or 1, 70001
ChkL a Xor a, 0
ChkL Not c, -1

' ---- Integer and Long mixed
n = 1000
a = n
ChkL a, 1000
a = n * 1000&
ChkL a, 1000000
a = CLng(n) * n
ChkL a, 1000000
n = 300
a = CLng(n) * n + n
ChkL a, 90300
a = 65537
n = a
Chk n, 1
Chk CInt(a), 1

' ---- compares
a = 100000
b = 99999
Chk (a > b), -1
Chk (a < b), 0
Chk (a = 100000), -1
Chk (a <> b), -1
Chk (b <= a), -1
Chk (b >= a), 0
c = -5
Chk (c < 3), -1
If a > 50000 Then n = 1 Else n = 2
Chk n, 1
c = 0
If c Then n = 3 Else n = 4
Chk n, 4

' ---- strings
a = 123456
ChkS CStr(a), "123456"
ChkS Str$(a), " 123456"
ChkS "a=" & a, "a=123456"
a = -987654
ChkS CStr(a), "-987654"
s = a
ChkS s, "-987654"
a = Val("1234567")
ChkL a, 1234567
a = CLng("-200000")
ChkL a, -200000
s = "45000"
a = s
ChkL a, 45000

' ---- arrays, Types, procedures
For i = 0 To 4
  arr(i) = CLng(i) * 100000
Next
ChkL arr(4), 400000
i = 3
ChkL arr(i), 300000
arr(i) = arr(i) + 1
ChkL arr(3), 300001
acc.id = 7
acc.balance = 250000
acc.balance = acc.balance * 2
ChkL acc.balance, 500000
ChkL Twice(123456), 246912
a = 5
AddTo a, 99995
ChkL a, 100000
ChkL Fact(12), 479001600

' ---- For with a Long counter
total = 0
For a = 99998 To 100002
  total = total + a
Next
ChkL total, 500000
total = 0
For a = 300000 To 100000 Step -100000
  total = total + a
Next
ChkL total, 600000

' ---- Select Case on a Long
a = 150000
Select Case a
  Case Is < 100000
    n = 1
  Case 100000 To 199999
    n = 2
  Case Else
    n = 3
End Select
Chk n, 2

Print
Print t; " tests, "; bad; " failed"
End

Sub ChkL(ByVal got As Long, ByVal want As Long)
  t = t + 1
  Print t; ":";
  If got = want Then
    Print "ok ";
  Else
    Print "FAIL("; got; ") ";
    bad = bad + 1
  End If
End Sub

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

Function Twice(ByVal v As Long) As Long
  Twice = v + v
End Function

Sub AddTo(x As Long, ByVal y As Long)
  x = x + y
End Sub

Function Fact(ByVal k As Integer) As Long
  Dim r As Long
  r = 1
  Do While k > 1
    r = r * k
    k = k - 1
  Loop
  Fact = r
End Function
