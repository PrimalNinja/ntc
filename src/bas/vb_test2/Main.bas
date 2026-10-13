Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option Base 1
#Const DEBUGMODE = 1
Const SEP = "-"
Type Person
  name As String
  age As Integer
End Type
Dim t As Integer, bad As Integer
Dim i As Integer, j As Integer, k As Integer, s As String, n As Integer
Dim v(5) As Integer
Dim w(0 To 4) As Integer
Dim folk(2) As Person

Print "VB test 2"
' colon separated, comments with quotes
n = 1: n = n + 1 ' it's a comment
Chk n, 2
ChkS "it's" & SEP, "it's-"
REM a rem line
#If DEBUGMODE Then
  n = 10
#Else
  n = 20
#End If
Chk n, 10
' option base 1
For i = 1 To 5: v(i) = i * 2: Next
Chk v(1) + v(5), 12
For i = 0 To 4: w(i) = i: Next
Chk w(0) + w(4), 4
' line continuation
n = 1 + _
    2 + _
    3
Chk n, 6
' optional params
Chk Area(3), 9
Chk Area(3, 4), 12
' byref string
s = "abc"
Shout s
ChkS s, "ABC!"
' nested string functions
ChkS Left$(UCase$("hello"), 2), "HE"
n = 0
s = "banana"
For i = 1 To Len(s)
  If Mid$(s, i, 1) = "a" Then n = n + 1
Next
Chk n, 3
' unary
n = 5
Chk -n, -5
Chk Not 0, -1
Chk (n > 3) And (n < 10), -1
' exit sub from nested loops
Chk FindPair(7), 25
' gosub inside a sub
Chk Inner(), 111
' public var from module 2
Shared = 41
BumpShared
Chk Shared, 42
' same private name in two modules
Chk Helper(), 1
Chk Mod2Helper(), 2
' type with string
folk(1).name = "Ann"
folk(1).age = 30
folk(2).name = "Bob"
folk(2).age = folk(1).age + 5
ChkS folk(1).name & folk(2).name, "AnnBob"
Chk folk(2).age, 35
' do loop forms
n = 0
Do
  n = n + 1
Loop While n < 5
Chk n, 5
n = 0
Do Until n >= 3
  n = n + 1
Loop
Chk n, 3
' step down
k = 0
For i = 10 To 1 Step -1: k = k + i: Next
Chk k, 55
' single line if with several statements and else
n = 0: k = 0
If n = 0 Then n = 1: k = 2 Else n = 9: k = 9
Chk n * 10 + k, 12
' call without parens and with Call
Call Nothing
Nothing
Chk GetSeven(), 7
Chk GetSeven + 1, 8
' select with strings and Is
ChkS Sz(5), "small"
ChkS Sz(50), "mid"
ChkS Sz(500), "big"
Print
Print t; " tests, "; bad; " failed"
End

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

Function Area(ByVal a As Integer, Optional ByVal b As Integer = -1) As Integer
  If b = -1 Then b = a
  Area = a * b
End Function

Sub Shout(txt As String)
  txt = UCase$(txt) & "!"
End Sub

Function FindPair(ByVal target As Integer) As Integer
  Dim x As Integer, y As Integer
  For x = 1 To 5
    For y = 1 To 5
      If x + y = target Then
        FindPair = x * 10 + y
        Exit Function
      End If
    Next
  Next
  FindPair = -1
End Function

Function Inner() As Integer
  Dim r As Integer
  GoSub addone
  GoSub addten
  r = r + 100
  Inner = r
  Exit Function
addone:
  r = r + 1
  Return
addten:
  r = r + 10
  Return
End Function

Private Function Helper() As Integer
  Helper = 1
End Function

Sub Nothing()
End Sub

Function GetSeven() As Integer
  GetSeven = 7
End Function

Function Sz(ByVal n As Integer) As String
  Select Case n
    Case Is < 10
      Sz = "small"
    Case 10 To 99
      Sz = "mid"
    Case Else
      Sz = "big"
  End Select
End Function
