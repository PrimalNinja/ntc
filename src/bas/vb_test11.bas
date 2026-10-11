' VB self test 11 - asm keyword procedures: a Sub / Function whose body is only
' #asm (no {param} / {result}) is called directly: dw fn_name, args..., result
Option Explicit

Const STEP3 = 3

Dim t As Integer, bad As Integer
Dim a As Integer, b As Integer, c As Integer
Dim s As String
Dim n As Long
Dim i As Integer

Cls
Print "VB self test 11"

' ---- Function, ByVal, literal and variable arguments
Chk Add3(10), 13
a = 20
Chk Add3(a), 23
Chk Add3(a * 2) + Add3(1), 47
Chk Add3(Add3(Add3(0))), 9

' ---- straight into the variable, and into a variable that is also the argument
a = Add3(5)
Chk a, 8
a = Add3(a)
Chk a, 11

' ---- two arguments, result used in an expression
Chk AddXY(7, 8), 15
b = AddXY(a, 5) * 2
Chk b, 32

' ---- Sub, ByRef: written through the address
c = 41
Inc c
Chk c, 42
Inc c
Inc c
Chk c, 44

' ---- Sub, ByRef String: the address of the string
s = "hello"
UpFirst s
Chk Asc(s), 72
Chk Len(s), 5

' ---- Function As Long: the result address is 4 bytes
n = Big(3)
Chk n \ 65536, 3
Chk n Mod 65536, 0

' ---- a {Const} in the block is still allowed
Chk AddC(1), 4

' ---- old style: body only #asm but reads {x} / {result} - stays a procedure
Chk Twice(21), 42

' ---- in a loop (normal mode: the keyword counts toward the safe point)
c = 0
For i = 1 To 50
  Inc c
Next
Chk c, 50

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

Function Add3(ByVal x As Integer) As Integer
#asm
    pop hl          ; address of x
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc de
    inc de
    inc de
    pop hl          ; address of the result
    ld (hl),e
    inc hl
    ld (hl),d
#endasm
End Function

Function AddXY(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
    pop hl          ; x
    ld e,(hl)
    inc hl
    ld d,(hl)
    pop hl          ; y
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
    add hl,de
    ex de,hl
    pop hl          ; result
    ld (hl),e
    inc hl
    ld (hl),d
#endasm
End Function

Sub Inc(v As Integer)
#asm
    pop hl          ; address of v (ByRef: write through it)
    inc (hl)
    jr nz,done
    inc hl
    inc (hl)
done:
#endasm
End Sub

Sub UpFirst(txt As String)
#asm
    pop hl          ; the string itself (0 terminated)
    ld a,(hl)
    cp 'a'
    ret c
    cp 'z'+1
    ret nc
    sub 32
    ld (hl),a
#endasm
End Sub

Function Big(ByVal hi As Integer) As Long
#asm
    pop hl          ; hi
    ld e,(hl)
    inc hl
    ld d,(hl)
    pop hl          ; result: 4 bytes, low word first
    xor a
    ld (hl),a
    inc hl
    ld (hl),a
    inc hl
    ld (hl),e
    inc hl
    ld (hl),d
#endasm
End Function

Function AddC(ByVal x As Integer) As Integer
#asm
    pop hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld hl,{STEP3}
    add hl,de
    ex de,hl
    pop hl
    ld (hl),e
    inc hl
    ld (hl),d
#endasm
End Function

Function Twice(ByVal x As Integer) As Integer
#asm
    ld hl,({x})
    add hl,hl
    ld ({result}),hl
#endasm
End Function
