' VB self test 7 - Types as parameters, 2 dimension array parameters, Long extras
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit

Type Point
  x As Integer
  y As Integer
End Type

Type Box
  name As String
  topleft As Point
  size As Point
  area As Long
End Type

Dim t As Integer, bad As Integer
Dim i As Integer, j As Integer
Dim p As Point, q As Point
Dim b As Box
Dim grid(2, 3) As Integer
Dim w As Long

Cls
Print "VB self test 7"

' ---- Types as parameters
p.x = 3
p.y = 4
Chk Dist2(p), 25
Grow p, 10
Chk p.x, 13
Chk p.y, 14
q = p
NoGrow q
Chk q.x, 13
b.name = "box"
b.size.x = 300
b.size.y = 400
b.topleft.x = 1
SetArea b
Chk b.area \ 1000, 120
ChkS b.name, "box!"
Chk b.topleft.x, 2
Chk Twice2(p), 49

' ---- 2 dimension arrays as parameters
For i = 0 To 2
  For j = 0 To 3
    grid(i, j) = i * 10 + j
  Next
Next
Chk Corner(grid), 23
Chk Sum2(grid), 0 + 1 + 2 + 3 + 10 + 11 + 12 + 13 + 20 + 21 + 22 + 23
Chk Cols(grid), 3
Clear2 grid
Chk grid(2, 3), 0

' ---- Long extras: Hex$ of a Long, For with a variable Step
w = &H12345678
ChkS Hex$(w), "12345678"
w = -1
ChkS Hex$(w), "FFFFFFFF"
w = 0
i = 2
Dim k As Long
For k = 1 To 10 Step i
  w = w + k
Next
Chk w, 25
For k = 10 To 1 Step -i
  w = w + k
Next
Chk w, 55

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

Function Dist2(ByVal a As Point) As Integer
  Dist2 = a.x * a.x + a.y * a.y
End Function

Sub Grow(a As Point, ByVal n As Integer)
  a.x = a.x + n
  a.y = a.y + n
End Sub

Sub NoGrow(ByVal a As Point)
  a.x = 0
End Sub

' a Type with a String, nested Types and a Long
Sub SetArea(bx As Box)
  bx.area = CLng(bx.size.x) * bx.size.y
  bx.name = bx.name & "!"
  Grow bx.topleft, 1
End Sub

' passes its Type parameter on
Function Twice2(a As Point) As Integer
  Twice2 = Dist2(a) \ 10 + a.x
End Function

Function Corner(g() As Integer) As Integer
  Corner = g(2, 3)
End Function

Function Sum2(g() As Integer) As Integer
  Dim r As Integer, c As Integer
  Sum2 = 0
  For r = LBound(g, 1) To UBound(g, 1)
    For c = LBound(g, 2) To UBound(g, 2)
      Sum2 = Sum2 + g(r, c)
    Next
  Next
End Function

Function Cols(g() As Integer) As Integer
  Cols = UBound(g, 2)
End Function

Sub Clear2(g() As Integer)
  Dim r As Integer, c As Integer
  For r = 0 To UBound(g, 1)
    For c = 0 To UBound(g, 2)
      g(r, c) = 0
    Next
  Next
End Sub
