' VB self test 9 - ^, IIf, Choose, StrComp, InStrRev, Replace, StrReverse, Oct$, Sqr, Mid$ =, DoEvents
Option Explicit

Dim t As Integer, bad As Integer
Dim i As Integer, n As Integer
Dim s As String
Dim w As Long

Cls
Print "VB self test 9"

' ---- ^ (whole numbers)
Chk 2 ^ 10, 1024
n = 3
Chk n ^ 4, 81
Chk -2 ^ 2, -4
Chk 2 ^ 3 ^ 2, 64
Chk n ^ 0, 1
w = 10
ChkL w ^ 9, 1000000000
ChkL 3& ^ 13, 1594323

' ---- IIf / Choose
n = 5
Chk IIf(n > 3, 100, 200), 100
Chk IIf(n > 9, 100, 200), 200
ChkS IIf(n = 5, "five", "other"), "five"
ChkS "x" & IIf(n < 0, "neg", "pos"), "xpos"
Chk Choose(2, 10, 20, 30), 20
i = 3
Chk Choose(i, 10, 20, 30), 30
i = 7
Chk Choose(i, 10, 20, 30), 0
ChkS Choose(n - 3, "a", "b", "c"), "b"

' ---- strings
Chk StrComp("abc", "abd"), -1
Chk StrComp("abc", "abc"), 0
Chk StrComp("b", "abc"), 1
s = "a,b,c,b"
Chk InStrRev(s, "b"), 7
Chk InStrRev(s, "b", 6), 3
Chk InStrRev(s, "z"), 0
ChkS Replace(s, ",", "; "), "a; b; c; b"
ChkS Replace(s, "b", ""), "a,,c,"
ChkS StrReverse("hello"), "olleh"
s = "abc"
s = StrReverse(s)
ChkS s, "cba"
ChkS Oct$(8), "10"
n = 511
ChkS Oct$(n), "777"
n = -1
ChkS Oct(n), "177777"

' ---- Sqr (whole number)
Chk Sqr(144), 12
n = 150
Chk Sqr(n), 12
Chk Sqr(-4), 0

' ---- Mid$ statement
s = "hello world"
Mid$(s, 1, 1) = "J"
ChkS s, "Jello world"
Mid$(s, 7) = "W0rld!!"
ChkS s, "Jello W0rld"

' ---- DoEvents (a safe point)
For i = 1 To 3
  DoEvents
Next
Chk i, 4

Print
Print t; " tests, "; bad; " failed"
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
