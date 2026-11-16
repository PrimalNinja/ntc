' regress.sh: ByRef in place (20261116-2). A ByRef parameter is the caller's variable itself: the call
' puts the argument's address into the body's operands; nothing is copied in or back. A value (an
' expression, a constant the procedure writes, another type) goes in the parameter's own variable.
Option Explicit
Type Pt
  x As Integer
  y As Integer
  n As String
End Type
Dim a As Integer, b As Integer, s As String, l As Long, g As Integer
Dim p As Pt, q As Pt
a = 3 : b = 4
Add2 a, b
Print "a"; a; b
Twice a
Print "b"; a
l = 100000
LAdd l, 5
Print "c"; l
s = "hello"
Show s
Show "lit"
Show s + "!"
Print "g"; Sum(a, 7)
Nest a
Print "h"; a
' an expression and a constant given to a parameter the procedure writes: the caller's are untouched
b = 10
Bump b + 1
Bump 5
Print "i"; b
Bump b
Print "j"; b
' a Type: its fields are the caller's
p.x = 1 : p.y = 2 : p.n = "pt"
Move p, 10
Print "k"; p.x; p.y; p.n
q = p
Move q, 1
Print "l"; q.x; p.x
' the caller's variable changed while the procedure runs is seen at once (it is the same variable)
g = 1
Watch g
' a String the procedure writes keeps a variable of its own (copied back), the caller's capacity kept
s = "abc"
Up s
Print "n"; s
' ByVal is a copy
b = 7
Val b
Print "o"; b
' a parameter named by #asm keeps a variable
Print "p"; Asm3(a)
' a Byte and an Integer given to a Long parameter: a value
Print "q"; LSum(b, 2)
End

Sub Add2(x As Integer, y As Integer)
  x = x + y
  y = y + 1
End Sub

Sub Twice(x As Integer)
  Dim i As Integer
  For i = 1 To 2
    x = x + x
  Next
End Sub

Sub LAdd(v As Long, ByVal n As Integer)
  v = v + n
End Sub

Sub Show(t As String)
  Print "s"; t; Len(t)
End Sub

Function Sum(x As Integer, y As Integer) As Integer
  Sum = x + y
End Function

Sub Nest(z As Integer)
  Add2 z, z
  Twice z
End Sub

Sub Bump(x As Integer)
  x = x + 1
End Sub

Sub Move(t As Pt, ByVal d As Integer)
  t.x = t.x + d
  t.y = t.y + d
  t.n = t.n + "!"
End Sub

Sub Watch(x As Integer)
  g = 99
  Print "m"; x
End Sub

Sub Up(t As String)
  t = t + "def"
End Sub

Sub Val(ByVal x As Integer)
  x = x + 100
End Sub

Function Asm3(x As Integer) As Integer
  Dim r As Integer
#asm
        ld hl, ({x})
        ld de, 3
        add hl, de
        ld ({r}), hl
#endasm
  Asm3 = r
End Function

Function LSum(v As Long, w As Long) As Long
  LSum = v + w
End Function
