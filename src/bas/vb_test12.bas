' VB self test 12 - string lengths: String (40), String * n (fixed, padded, up to 255),
' String Max n (at most n, not padded, up to 255); every store cuts at its capacity
Option Explicit

Type Rec
  nm As String Max 8
  code As String * 4
End Type

Dim t As Integer, bad As Integer
Dim s As String
Dim big As String Max 100
Dim short As String Max 5
Dim n2 As String Max 2
Dim f As String * 200
Dim f3 As String * 3
Dim w As String Max 255
Dim names(9) As String Max 12
Dim wide(2) As String Max 100
Dim huge(2) As String Max 255
Dim d() As String Max 10
Dim parts() As String Max 6
Dim r As Rec
Dim i As Integer, k As Integer
Dim v As String

Cls
Print "VB self test 12"

' ---- the default String: 40
s = String$(60, "a")
Chk Len(s), 40

' ---- String Max n: longer, and shorter
big = String$(30, "a") & String$(30, "b") & String$(30, "c")
Chk Len(big), 90
Chk Asc(Right$(big, 1)), 99
short = "abcdefgh"
Chk Len(short), 5
short = "x" & "yyyyyyy"
Chk Len(short), 5
n2 = 12345
Chk Val(n2), 12
w = String$(255, "w")
Chk Len(w), 255

' ---- String * n: fixed length, padded with spaces
f = "hi"
Chk Len(f), 200
Chk Asc(Mid$(f, 3, 1)), 32
Mid$(f, 199, 2) = "ZZ"
Chk Asc(Right$(f, 1)), 90
f3 = "abcdef"
Chk Len(f3), 3

' ---- functions on long strings
Chk Len(Space$(150)), 150
Chk Len(Left$(big, 95)), 90
Chk Len(UCase$(big)), 90
Chk Len(Replace(big, "a", "")), 60
Chk Len(Rep("q", 90)), 90
Chk LenOf(big), 90

' ---- ByRef: cut at the caller's string
Fill short
Chk Len(short), 5
Fill big
Chk Len(big), 50

' ---- arrays: element size = capacity + 1
names(3) = "abcdefghijklmnop"
Chk Len(names(3)), 12
For i = 0 To 9
  names(i) = String$(i + 10, "n")
Next
Chk Len(names(1)), 11
Chk Len(names(9)), 12
wide(1) = String$(80, "z")
i = 1
Chk Len(wide(i)), 80
huge(2) = String$(200, "h")
i = 2
Chk Len(huge(i)), 200
huge(i) = huge(i) & String$(100, "j")
Chk Len(huge(2)), 255

' ---- a String array parameter: cut at the element
SetEl names
Chk Len(names(1)), 12

' ---- a Type field
r.nm = "abcdefghij"
Chk Len(r.nm), 8
r.code = "x"
Chk Len(r.code), 4

' ---- dynamic arrays, Split
ReDim d(1 To 3)
d(2) = String$(20, "k")
Chk Len(d(2)), 10
parts = Split("abcdefgh,ij", ",")
Chk Len(parts(0)), 6
Chk UBound(parts), 1

' ---- For Each: the loop variable (40) gets the element cut to 40
k = 0
For Each v In wide
  k = k + Len(v)
Next
Chk k, 40

' ---- Input cuts at the variable (String Max 5): type more than 5 letters to see it cut
Input "Type 8 letters (only 5 fit)"; short
Chk (Len(short) <= 5), -1
Print "["; short; "]"

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

Function Rep(ByVal c As String, ByVal n As Integer) As String
  Rep = String$(n, c)
End Function

Function LenOf(ByVal x As String) As Integer
  LenOf = Len(x)
End Function

Sub Fill(x As String)
  x = String$(50, "m")
End Sub

Sub SetEl(a() As String)
  a(1) = "1234567890123456"
End Sub
