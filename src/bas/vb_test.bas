' VB style self test - each check prints its number and ok or FAIL
Option Explicit

Const MAXN = 10
Const GREETING = "Hi"
Const BIG = MAXN * 100 + 1

Type Point
  x As Integer
  y As Integer
End Type

Dim t As Integer, bad As Integer
Dim i As Integer, j As Integer, s As Integer, n As Integer
Dim a$, b As String, c As String
Dim p As Point, q As Point
Dim pts(3) As Point
Dim names(4) As String
Dim grid(2, 3) As Integer
Dim tk As Integer

Cls
Print "VB self test"

' ---- constants
Chk BIG, 1001
ChkS GREETING & "!", "Hi!"

' ---- functions and subs
Chk Add(2, 3), 5
Chk Add(Add(1, 2), Add(3, 4)), 10
Chk Twice(21), 42
n = 5
Bump n
Chk n, 6
Bump n
Chk n, 7
n = 5
NoBump n
Chk n, 5
Chk Fact(7), 5040
Chk Counter(), 1
Chk Counter(), 2
Chk Fresh(), 1
Chk Fresh(), 1
Chk Clamp(50), 10
Chk Clamp(-4), 0
Chk Clamp(7), 7

' ---- select case
Chk Grade(95), 1
Chk Grade(85), 2
Chk Grade(70), 3
Chk Grade(3), 4
Chk Kind("apple"), 1
Chk Kind("pear"), 2
Chk Kind("zzz"), 0

' ---- strings
a$ = "Hello"
b = "World"
c = a$ & ", " & b & "!"
ChkS c, "Hello, World!"
Chk Len(c), 13
ChkS Left$(c, 5), "Hello"
ChkS Right$(c, 6), "World!"
ChkS Mid$(c, 8, 5), "World"
ChkS Mid$(c, 8), "World!"
ChkS UCase$(a$), "HELLO"
ChkS LCase(b), "world"
ChkS Chr$(65) & Chr$(66), "AB"
Chk Asc("A"), 65
ChkS Str$(42), " 42"
ChkS Str$(-7), "-7"
ChkS "n=" & 12, "n=12"
Chk Val("123"), 123
Chk Val(" -45"), -45
Chk Val("&HFF"), 255
Chk InStr(c, "World"), 8
Chk InStr(c, "xyz"), 0
Chk InStr(9, c, "o"), 9
ChkS Trim$("  ab  "), "ab"
ChkS LTrim$("  ab"), "ab"
ChkS RTrim$("ab  ") & "|", "ab|"
ChkS Space$(3) & "x", "   x"
ChkS String$(4, "*"), "****"
ChkS Hex$(255), "FF"
n = 4096
ChkS Hex$(n), "1000"
c = "abc"
c = c & c
ChkS c, "abcabc"
Chk ("abc" < "abd"), -1
Chk ("b" > "abc"), -1
Chk ("abc" <= "abc"), -1
n = 9
ChkS "x" & n & "y", "x9y"

' ---- types and arrays
p.x = 3
p.y = 4
q = p
Chk q.x + q.y, 7
For i = 0 To 3
  pts(i).x = i
  pts(i).y = i * 10
Next
s = 0
For i = 0 To 3
  s = s + pts(i).x + pts(i).y
Next
Chk s, 66
names(0) = "zero"
names(2) = "two"
i = 2
ChkS names(i) & names(0), "twozero"
names(i) = names(i) & "!"
ChkS names(2), "two!"
For i = 0 To 2
  For j = 0 To 3
    grid(i, j) = i * 10 + j
  Next
Next
Chk grid(2, 3), 23
i = 1
j = 2
Chk grid(i, j), 12

' ---- turbo switching
Turbo On
s = 0
For i = 1 To 100
  s = s + i
Next
Turbo Off
Chk s, 5050
tk = Ticks
For i = 1 To 2000
  s = s + 1
Next
Chk (Ticks > tk), -1
Chk Sum3(1, 2, 3), 6
Turbo On
Chk Sum3(4, 5, 6), 15
Turbo Off

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

Function Add(ByVal x As Integer, ByVal y As Integer) As Integer
  Add = x + y
End Function

Function Twice(v As Integer) As Integer
  Twice = Add(v, v)
End Function

Sub Bump(v As Integer)
  v = v + 1
End Sub

Sub NoBump(ByVal v As Integer)
  v = v + 1
End Sub

Function Fact(ByVal k As Integer) As Integer
  Dim r As Integer
  r = 1
  Do While k > 1
    r = r * k
    k = k - 1
  Loop
  Fact = r
End Function

Function Counter() As Integer
  Static calls As Integer
  calls = calls + 1
  Counter = calls
End Function

Function Fresh() As Integer
  Dim calls As Integer
  calls = calls + 1
  Fresh = calls
End Function

Function Clamp(ByVal v As Integer) As Integer
  Clamp = v
  If v > MAXN Then
    Clamp = MAXN
    Exit Function
  End If
  If v < 0 Then Clamp = 0
End Function

Function Grade(ByVal score As Integer) As Integer
  Select Case score
    Case Is >= 90
      Grade = 1
    Case 80 To 89
      Grade = 2
    Case 60, 65, 70, 75
      Grade = 3
    Case Else
      Grade = 4
  End Select
End Function

Function Kind(ByVal f As String) As Integer
  Select Case f
    Case "apple", "banana"
      Kind = 1
    Case "pear"
      Kind = 2
  End Select
End Function

Function Sum3(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
  Sum3 = x + y + z
End Function
