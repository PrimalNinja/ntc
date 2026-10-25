' 45GS02 self test (m65 platform): every kind of BASIC statement, then the 45GS02's own #asm and
' the MEGA65's classes. An ok is a dot; a failure prints its number and what it got.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const MAXN = 10
Const BIG = MAXN * 100 + 1
Const HELLO = "Hello"

Enum Colour
  Red = 1
  Green
  Blue = 10
End Enum

Type Point
  x As Integer
  y As Integer
  nm As String
End Type

Dim t As Integer, bad As Integer
Dim i As Integer, j As Integer, k As Integer, n As Integer, v As Integer
Dim s As String, s2 As String, w As String * 6, sm As String Max 8
Dim lg As Long, lg2 As Long
Dim a(10) As Integer, b(4) As Byte, la(3) As Long, sa(3) As String
Dim g(2, 3) As Integer
Dim dyn() As Integer, parts() As String
Dim p As Point, pts(2) As Point
Dim c As Counter
Dim fn As Integer, tk As Integer, tk2 As Integer, vp As Integer

Cls
Print "45GS02 SELF TEST"

' ---- constants, Enum
Section "CONST"
Chk BIG, 1001
ChkS HELLO & "!", "Hello!"
Chk Green, 2
Chk Blue, 10

' ---- arithmetic (16 bit, wrapping)
Section "MATHS"
Chk 7 + 3 * 2, 13
Chk (7 + 3) * 2, 20
Chk 7 - 10, -3
Chk 7 / 2, 3
Chk -7 \ 2, -3
Chk 17 Mod 5, 2
Chk -7 Mod 2, -1
Chk 2 ^ 10, 1024
Chk -2 ^ 2, -4
i = 32767: i = i + 1
Chk i, -32768
i = 300: j = 0
Chk i \ j, 0                ' divide by 0: 0
Chk i Mod j, 300
i = -32768: j = -1
Chk i \ j, -32768
Chk Abs(-37), 37
Chk Sgn(-9) + Sgn(0) * 10 + Sgn(5) * 100, 99
Chk Sqr(17), 4
Chk Sqr(-4), 0
i = 6: j = 7
Chk i * j, 42
Chk -i, -6
Chk i * -j, -42
Chk 1000 * 100, -31072      ' (16 bits)

' ---- logic and compares
Section "LOGIC"
Chk (5 > 3), -1
Chk (5 < 3), 0
Chk (5 >= 5) And (4 <= 4), -1
Chk (3 <> 3), 0
Chk 12 And 10, 8
Chk 12 Or 10, 14
Chk 12 Xor 10, 6
Chk Not 0, -1
i = -5
Chk (i < 3), -1             ' signed
Chk IIf(i < 0, 1, 2), 1
Chk Choose(2, 10, 20, 30), 20
Chk ("cat" Like "[bc]at"), -1
Chk ("dog" Like "c*"), 0
Chk ("a5" Like "a#"), -1

' ---- Long (32 bit)
Section "LONG"
lg = 100000
lg2 = lg * 3
ChkL lg2, 300000
ChkL lg2 \ 7, 42857
ChkL lg2 Mod 7, 1
ChkL -lg2, -300000
ChkL lg2 - 1000000, -700000
lg = 2147483647
lg = lg + 1
ChkL lg, -2147483648&
i = 1000
lg = CLng(i) * 1000
ChkL lg, 1000000
Chk (lg > 999999), -1
Chk (lg < 0), 0
ChkS Str$(lg), " 1000000"
ChkS Hex$(255&), "FF"
lg = 65536
i = lg
Chk i, 0                    ' low 16 bits
lg = &H12345678&
ChkS Hex$(lg), "12345678"

' ---- strings
Section "STRINGS"
s = "Hello, World"
Chk Len(s), 12
ChkS Left$(s, 5), "Hello"
ChkS Right$(s, 5), "World"
ChkS Mid$(s, 8, 3), "Wor"
ChkS Mid$(s, 8), "World"
Chk InStr(s, "o"), 5
Chk InStr(6, s, "o"), 9
Chk InStrRev(s, "o"), 9
ChkS UCase$(s), "HELLO, WORLD"
ChkS LCase$("ABC"), "abc"
ChkS Trim$("  ab  "), "ab"
ChkS LTrim$("  ab"), "ab"
ChkS RTrim$("ab  ") & "|", "ab|"
ChkS Space$(3) & "x", "   x"
ChkS String$(4, 42), "****"
ChkS Chr$(65) & Chr$(66), "AB"
Chk Asc("A"), 65
ChkS Str$(42), " 42"
ChkS Str$(-42), "-42"
ChkS CStr(42), "42"
Chk Val("123"), 123
Chk Val("&HFF"), 255
Chk Val(" -7x"), -7
ChkS Hex$(4095), "FFF"
ChkS Oct$(8), "10"
ChkS Replace("a-b-c", "-", "+"), "a+b+c"
ChkS StrReverse("abc"), "cba"
Chk StrComp("abc", "abd"), -1
ChkS Format$(42, "0000"), "0042"
ChkS Format$(1234567&, "#,##0"), "1,234,567"
s = "abc"
s = s & "def" & 1
ChkS s, "abcdef1"
Chk (s = "abcdef1"), -1
Chk ("abc" < "abd"), -1
Chk ("b" > "abc"), -1
s = "Hello"
Mid$(s, 1, 1) = "J"
ChkS s, "Jello"
w = "ab"
ChkS w & "|", "ab    |"   ' String * 6: padded
LSet w = "xy"
ChkS w, "xy    "
RSet w = "xy"
ChkS w, "    xy"
sm = "123456789012"
ChkS sm, "12345678"     ' String Max 8: cut
parts = Split("x,yy,,z", ",")
Chk UBound(parts), 3
ChkS parts(1), "yy"
ChkS Join(parts, "-"), "x-yy--z"

' ---- arrays
Section "ARRAYS"
For i = 0 To 10
  a(i) = i * i
Next
Chk a(10), 100
Chk a(3) + a(4), 25
b(1) = 300
Chk b(1), 44                ' a Byte element: 8 bits
la(2) = 123456
ChkL la(2), 123456
sa(1) = "one"
ChkS sa(1) & sa(0), "one"
g(1, 2) = 5: g(2, 3) = 7
Chk g(1, 2) + g(2, 3), 12
Chk UBound(g, 2), 3
Chk SumArr(a), 385
ReDim dyn(5)
dyn(5) = 9
ReDim Preserve dyn(8)
Chk dyn(5), 9
Chk UBound(dyn), 8
ReDim dyn(2 To 4)
Chk LBound(dyn), 2
Chk dyn(3), 0
Erase dyn
Chk UBound(dyn), -1
k = 0
For Each v In a
  k = k + v
Next
Chk k, 385

' ---- Type, With
Section "TYPES"
p.x = 3: p.y = 4: p.nm = "pt"
Chk p.x * p.y, 12
ChkS p.nm, "pt"
With pts(1)
  .x = 10
  .y = 20
End With
Chk pts(1).x + pts(1).y, 30
Chk Dist2(p), 25
MovePt p
Chk p.x, 4

' ---- flow
Section "FLOW"
i = 5
If i > 3 Then j = 1 Else j = 2
Chk j, 1
If i < 3 Then
  j = 1
ElseIf i < 6 Then
  j = 2
Else
  j = 3
End If
Chk j, 2
Chk Kind(7), 3
Chk Kind(15), 4
Chk Kind(1), 1
Chk Kind(100), 9
k = 0
For i = 10 To 1 Step -3
  k = k + i
Next
Chk k, 22                   ' 10 + 7 + 4 + 1
k = 0
For i = 1 To 100
  If i = 5 Then Exit For
  k = k + 1
Next
Chk k, 4
k = 0
i = 0
While i < 5
  i = i + 1
  k = k + i
Wend
Chk k, 15
i = 0
Do
  i = i + 1
Loop Until i >= 7
Chk i, 7
i = 0
Do While i < 3
  i = i + 1
Loop
Chk i, 3
i = 0
Do
  i = i + 1
  If i = 4 Then Exit Do
Loop
Chk i, 4
k = 0
GoSub addten
GoSub addten
Chk k, 20
i = 2
On i GoSub onone, ontwo
Chk k, 22
i = 1
On i GoTo l1, l2
l1:
k = 100
GoTo l3
l2:
k = 200
l3:
Chk k, 100

' ---- procedures
Section "PROCS"
Chk Add(2, 3), 5
Chk Add(Add(1, 2), Add(3, 4)), 10
n = 5
Bump n
Chk n, 6
NoBump n
Chk n, 6
Chk Opt(1), 11
Chk Opt(1, 2), 3
Chk Counted(), 1
Chk Counted(), 2            ' Static
ChkS Greet("Ann"), "Hi Ann"
s = "abc"
Upper s
ChkS s, "ABC"
Chk EarlyOut(5), 1
Chk EarlyOut(-5), -1

' ---- a class
Section "CLASS"
Counter.Reset
Counter.Add 5
Counter.Add 7
Chk Counter.Total, 12
Counter.Limit = 3
Chk Counter.Limit, 3
Chk Counter.Count, 2

' ---- AddressOf, VarPtr, Peek / Poke
Section "MEMORY"
fn = AddressOf AddOne
k = 0
CallAddr fn
CallAddr fn
Chk k, 2
vp = VarPtr(n)
n = 1234
Chk Deek(vp), 1234
Doke vp, 4321
Chk n, 4321
Poke vp, 7                  ' little endian: the low byte is the first
Chk n And 255, 7
Chk Peek(vp), 7
Chk Peek(vp + 1), 4321 \ 256

' ---- the 45GS02's own code
Section "45GS02"
k = 5
#asm
            lda {k}
            asl
            clc
            adc {k}
            sta {k}
            lda #0
            sta {k}+1
#endasm
Chk k, 15
Chk Swap16(&H1234), &H3412
Chk AddAsm(40, 2), 42
Chk Mul3(-7), -21

' ---- the MEGA65
Section "M65"
tk = Ticks
For i = 1 To 5
  Frame
Next
tk2 = Ticks
Chk (tk2 - tk >= 5) And (tk2 - tk <= 6), -1
Chk System.TicksPerSecond, 50
Chk Len(System.Platform), 3
Chk System.HasCapability("clock"), -1
Chk System.HasCapability("files"), 0
Out &H20, 5                 ' the border colour ($D020)
Chk Inp(&H20) And 15, 5
Poke &HD020, 0
Chk Peek(&HD020) And 15, 0
Chk Peek(&HD012) <> Peek(&HD012) Or True, -1
Locate 1, 25
Print "COLUMN"; Tab(20); "X";
Chk StdIO.Column(), 21
Chk StdIO.Cols(), 80

Print
Print t; " tests, "; bad; " failed"
End

' ============================================================
Sub Section(ByVal nm As String)
  Print
  Print nm; " ";
End Sub

Sub Chk(ByVal got As Integer, ByVal want As Integer)
  t = t + 1
  If got = want Then
    Print ".";
  Else
    Print
    Print t; ":FAIL("; got; ") ";
    bad = bad + 1
  End If
End Sub

Sub ChkL(ByVal got As Long, ByVal want As Long)
  t = t + 1
  If got = want Then
    Print ".";
  Else
    Print
    Print t; ":FAIL("; got; ") ";
    bad = bad + 1
  End If
End Sub

Sub ChkS(ByVal got As String, ByVal want As String)
  t = t + 1
  If got = want Then
    Print ".";
  Else
    Print
    Print t; ":FAIL["; got; "] ";
    bad = bad + 1
  End If
End Sub

addten:
  k = k + 10
  Return
onone:
  k = k + 1
  Return
ontwo:
  k = k + 2
  Return

Function Add(ByVal x As Integer, ByVal y As Integer) As Integer
  Add = x + y
End Function

Sub Bump(n As Integer)
  n = n + 1
End Sub

Sub NoBump(ByVal n As Integer)
  n = n + 1
End Sub

Function Opt(ByVal x As Integer, Optional ByVal y As Integer = 10) As Integer
  Opt = x + y
End Function

Function Counted() As Integer
  Static calls As Integer
  calls = calls + 1
  Counted = calls
End Function

Function Greet(ByVal nm As String) As String
  Greet = "Hi " & nm
End Function

Sub Upper(s As String)
  s = UCase$(s)
End Sub

Function EarlyOut(ByVal x As Integer) As Integer
  EarlyOut = 1
  If x > 0 Then Exit Function
  EarlyOut = -1
End Function

Function Kind(ByVal x As Integer) As Integer
  Select Case x
    Case 1, 2
      Kind = 1
    Case 3 To 9
      Kind = 3
    Case Is > 50
      Kind = 9
    Case Else
      Kind = 4
  End Select
End Function

Function SumArr(arr() As Integer) As Integer
  Dim q As Integer, tot As Integer
  For q = LBound(arr) To UBound(arr)
    tot = tot + arr(q)
  Next
  SumArr = tot
End Function

Function Dist2(pt As Point) As Integer
  Dist2 = pt.x * pt.x + pt.y * pt.y
End Function

Sub MovePt(pt As Point)
  pt.x = pt.x + 1
End Sub

Sub AddOne()
  k = k + 1
End Sub

' asm keyword functions: the arguments' addresses off the thread, the result's address last
Function Swap16(ByVal x As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            iny
            sta (z_p1),y
            lda (z_p0),y
            dey
            sta (z_p1),y
#endasm
End Function

Function AddAsm(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            NTC_POP z_p2
            ldy #0
            lda (z_p0),y
            clc
            adc (z_p1),y
            sta (z_p2),y
            iny
            lda (z_p0),y
            adc (z_p1),y
            sta (z_p2),y
#endasm
End Function

' the hardware multiplier ($D770 A, $D774 B, $D778 the product)
Function Mul3(ByVal x As Integer) As Integer
#asm
            NTC_POP z_p0
            NTC_POP z_p1
            ldy #0
            lda (z_p0),y
            sta $D770
            iny
            lda (z_p0),y
            sta $D771
            lda #0
            sta $D772
            sta $D773
            sta $D775
            sta $D776
            sta $D777
            lda #3
            sta $D774
            ldy #0
            lda $D778
            sta (z_p1),y
            iny
            lda $D779
            sta (z_p1),y
#endasm
End Function
