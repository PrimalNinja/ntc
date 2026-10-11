' VB self test 5 - #asm, Inp / Out, Debug.Assert, classes as libraries (handles)
Option Explicit

Const BASE = 100

Dim t As Integer, bad As Integer
Dim i As Integer, n As Integer, h1 As Integer, h2 As Integer
Dim v As Integer
Dim w As Long
Dim tbl(3) As Integer

Cls
Print "VB self test 5"

' ---- #asm in the main program: local labels, {Const}, {variable}
v = 5
#asm
            ld hl, ({v})
            ld de, {BASE}
            add hl, de
            ld ({v}), hl        ; v = v + BASE
#endasm
Chk v, 105

' ---- #asm functions with parameters and a result
Chk AddAsm(30, 12), 42
Chk Times3(7), 21
Chk CountBits(255), 8
Chk CountBits(&H8001), 2
n = 9
Twice n
Chk n, 18
tbl(2) = 77
Chk ThirdOf(tbl), 77

' ---- Inp / Out
v = Inp(&HF500)
Chk (v >= 0) And (v <= 255), -1
Out &H7F00, &H10

' ---- Debug.Assert that holds
Debug.Assert v >= 0

' ---- classes as libraries: handles, class arrays, Const, a Type array
h1 = Pool.Open(10)
h2 = Pool.Open(20)
Chk h1, 0
Chk h2, 1
Pool.Add h1, 5
Pool.Add h2, 7
Pool.Add h1, 1
Chk Pool.Value(h1), 16
Chk Pool.Value(h2), 27
Chk Pool.Uses(h1), 2
Chk Pool.MAXSLOTS, 4
Pool.Close h1
Chk Pool.Open(30), 0
Chk Pool.Open(1), 2
Chk Pool.Open(1), 3
Chk Pool.Open(1), -1

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

Function AddAsm(ByVal a As Integer, ByVal b As Integer) As Integer
  #asm
            ld hl, ({a})
            ld de, ({b})
            add hl, de
            ld ({result}), hl
  #endasm
End Function

Function Times3(ByVal x As Integer) As Integer
  Times3 = x
  #asm
            ld hl, ({result})
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld ({result}), hl
  #endasm
End Function

' local labels: the same label name in two blocks does not clash
Function CountBits(ByVal x As Integer) As Integer
  #asm
            ld hl, ({x})
            ld b, 16
            ld c, 0
loop:
            add hl, hl
            jr nc, skip
            inc c
skip:
            djnz loop
            ld a, c
            ld ({result}), a
            xor a
            ld ({result}+1), a
  #endasm
End Function

' ByRef parameter written by #asm is copied back
Sub Twice(n As Integer)
  #asm
            ld hl, ({n})
            add hl, hl
            ld ({n}), hl
loop:
  #endasm
End Sub

' an array parameter: {a} is its descriptor (base, lower bound, size, count)
Function ThirdOf(a() As Integer) As Integer
  #asm
            ld hl, ({a})        ; base
            ld de, 4
            add hl, de          ; element 2
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({result}), de
  #endasm
End Function
