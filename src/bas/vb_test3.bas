Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Enum Colour
  Red
  Green = 5
  Blue
End Enum
Private Enum Size
  Small = 1
  Large = 10
End Enum
Type Box
  w As Integer
  h As Integer
  label As String
End Type
Dim t As Integer, bad As Integer
Dim c As Colour, b As Box, n As Integer, k As String, i As Integer
Dim boxes(2) As Box

Print "VB test 3"
Chk Red, 0
Chk Green, 5
Chk Blue, 6
Chk Colour.Blue + Size.Large, 16
c = Green
Chk c, 5
With b
  .w = 3
  .h = 4
  .label = "box"
  n = .w * .h
End With
Chk n, 12
ChkS b.label, "box"
For i = 0 To 2
  With boxes(i)
    .w = i
    .h = i * 2
  End With
Next
Chk boxes(2).w + boxes(2).h, 6
n = 0
For i = 1 To 3
  On i GoSub one, two, three
Next
Chk n, 321
i = 2
On i GoTo l1, l2
Chk 0, 1
l1:
Chk 0, 1
l2:
Chk 1, 1
k = Inkey$
ChkS k, ""
Print
Print t; " tests, "; bad; " failed"
End
one:
  n = n + 1
  Return
two:
  n = n + 20
  Return
three:
  n = n + 300
  Return

Sub Chk(ByVal got As Integer, ByVal want As Integer)
  t = t + 1
  Print t; ":";
  If got = want Then Print "ok "; Else Print "FAIL("; got; ") "; : bad = bad + 1
End Sub

Sub ChkS(ByVal got As String, ByVal want As String)
  t = t + 1
  Print t; ":";
  If got = want Then Print "ok "; Else Print "FAIL["; got; "] "; : bad = bad + 1
End Sub
