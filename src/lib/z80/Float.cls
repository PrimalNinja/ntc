' Float: floating point for NTC BASIC on the Z80 - IEEE 754 single (32 bit, kept in a Long) and
' half (16 bit, kept in an Integer).
'   single: 1 sign bit, 8 exponent bits (bias 127), 23 mantissa bits (24 with the hidden 1):
'           about 7 significant digits, 1.2E-38 to 3.4E+38
'   half:   1 sign bit, 5 exponent bits (bias 15), 10 mantissa bits (11 with the hidden 1):
'           about 3 significant digits, 6.1E-05 to 65504
' Rounding is to nearest (half up). Too small becomes 0 (no denormals); too big becomes infinity
' and Overflow() is True (until it's asked); 0 / 0 and the like give infinity too (no NaNs).
' A value is only bits: Dim x As Long : x = Float.FromInt(3) : x = Float.Divide(x, Float.FromInt(4))
'
' The shim: every operation goes through one private procedure (Op), which jumps through the
' class's own jump block - a table in RAM, one address per operation, filled once at the first
' call. Each entry is the Z80 engine's routine, or the coprocessor forwarder when one answers:
' in CyborgOS, BDOS 131 op 40 (the vCPC answers it on its host; on a CPC with a Pi, C0 passes it to
' the Pi's float service). No coprocessor: the Z80 engine, unchanged. Programs never change: the
' same .CYB runs either way. UseEngine picks (auto, Z80 only, coprocessor if present); Backend
' says which is in use. IEEE single is what coprocessors and hosts speak: nothing converts.
' Also: Float.MulDiv - a * b / c on Longs with a 64 bit middle (the Fixed class's multiply and
' divide).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Dim m_lngA As Long, m_lngB As Long, m_lngC As Long, m_lngR As Long
Dim m_intOp As Integer, m_intFlag As Integer, m_intRes As Integer
Dim m_byW(95) As Byte                       ' the engine's work: two unpacked numbers, products
Dim m_lngPow(5) As Long, m_lngUp(5) As Long, m_lngDn(5) As Long
Dim m_intInit As Integer
Dim m_arrJt(15) As Integer                  ' the jump block: an address per operation
Dim m_intJtOk As Integer, m_intWant As Integer, m_intCop As Integer
Dim m_byQ(47) As Byte                       ' a coprocessor request (BDOS 131 op 40)
Dim m_intIx As Integer
#If NTC_CYBORGOS
Const FP_COP = 1                            ' (only CyborgOS has BDOS 131: elsewhere never asked)
#Else
Const FP_COP = 0
#End If
Dim m_intPa As Integer, m_intPb As Integer, m_intPd As Integer          ' arrays: where A, B, D start
Dim m_intN As Integer, m_intEs As Integer, m_intEop As Integer, m_intBk As Integer
Dim m_intR As Integer, m_intK As Integer, m_intC As Integer           ' matrix product: R x K times K x C
Dim m_intNa0 As Integer, m_intNa1 As Integer, m_intNb0 As Integer, m_intNb1 As Integer
Dim m_intNd0 As Integer, m_intNd1 As Integer
Dim m_lngK As Long, m_lngScale As Long, m_lngDot As Long
Dim m_intEsD As Integer                    ' the destination's element size (MToBinScaled: 2 or 4)

' ---- single (32 bit, in a Long)

Public Function FromInt(ByVal lngN_a As Long) As Long
  FromInt = Op(5, lngN_a, 0, 0)
End Function

' the whole part, towards zero (past a Long: the biggest Long, Overflow() True)
Public Function ToInt(ByVal lngF_a As Long) As Long
  ToInt = Op(6, lngF_a, 0, 0)
End Function

' the nearest whole number, as a Long (halves away from zero)
Public Function ToIntRound(ByVal lngF_a As Long) As Long
  Dim lngH As Long
  lngH = &H3F000000                         ' 0.5
  If lngF_a < 0 Then lngH = Op(7, lngH, 0, 0)
  ToIntRound = Op(6, Op(1, lngF_a, lngH, 0), 0, 0)
End Function

Public Function Add(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Add = Op(1, lngA_a, lngB_a, 0)
End Function

Public Function Subtract(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Subtract = Op(2, lngA_a, lngB_a, 0)
End Function

Public Function Multiply(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Multiply = Op(3, lngA_a, lngB_a, 0)
End Function

Public Function Divide(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Divide = Op(4, lngA_a, lngB_a, 0)
End Function

Public Function Negate(ByVal lngF_a As Long) As Long
  Negate = Op(7, lngF_a, 0, 0)
End Function

Public Function Absolute(ByVal lngF_a As Long) As Long
  Absolute = Op(8, lngF_a, 0, 0)
End Function

' -1 a < b, 0 equal, 1 a > b (0 and -0 are equal)
Public Function Compare(ByVal lngA_a As Long, ByVal lngB_a As Long) As Integer
  Dim intC As Integer, lngX As Long, lngY As Long
  lngX = lngA_a : lngY = lngB_a
  If Op(8, lngX, 0, 0) = 0 Then lngX = 0        ' (-0 is 0)
  If Op(8, lngY, 0, 0) = 0 Then lngY = 0
  If lngX = lngY Then
    intC = 0
  ElseIf lngX >= 0 And lngY >= 0 Then           ' both positive: the bits order them
    If lngX < lngY Then intC = -1 Else intC = 1
  ElseIf lngX < 0 And lngY < 0 Then             ' both negative: the other way round
    If lngX < lngY Then intC = 1 Else intC = -1
  ElseIf lngX < 0 Then
    intC = -1
  Else
    intC = 1
  End If
  Compare = intC
End Function

Public Function IsZero(ByVal lngF_a As Long) As Integer
  IsZero = (Op(8, lngF_a, 0, 0) = 0)
End Function

' True when an answer didn't fit (infinity, a clamped whole number) since Overflow was last asked
' - it stays set until then, so one look after a calculation covers every step of it
Public Function Overflow() As Integer
  Overflow = (m_intFlag <> 0)
  m_intFlag = 0
End Function

' the text: 6 significant digits, plain from 0.00001 to 999999, else 1.23456E+07
Public Function ToText(ByVal lngF_a As Long) As String
  Dim strT As String Max 24, strD As String Max 12, strS As String Max 1
  Dim lngX As Long, lngN As Long, intE As Integer, intI As Integer, intL As Integer, intD As Integer
  Init
  If Op(8, lngF_a, 0, 0) = 0 Then
    strT = "0"
  ElseIf (Op(8, lngF_a, 0, 0) And &H7F800000) = &H7F800000 Then
    If lngF_a < 0 Then strT = "-INF" Else strT = "INF"
  Else
    If lngF_a < 0 Then strS = "-" Else strS = ""
    lngX = Op(8, lngF_a, 0, 0)
    intE = 0
    For intI = 5 To 0 Step -1                   ' bring it below 1E6 ...
      If Compare(lngX, m_lngUp(intI)) >= 0 Then
        lngX = Op(4, lngX, m_lngPow(intI), 0) : intE = intE + Pow2(intI)
      End If
    Next
    For intI = 5 To 0 Step -1                   ' ... and up to 1E5 or more
      If Compare(lngX, m_lngDn(intI)) < 0 Then
        lngX = Op(3, lngX, m_lngPow(intI), 0) : intE = intE - Pow2(intI)
      End If
    Next
    lngN = Op(6, Op(1, lngX, &H3F000000, 0), 0, 0)   ' 6 digits (rounded)
    If lngN >= 1000000 Then lngN = lngN \ 10 : intE = intE + 1
    strD = CStr(lngN)
    intL = Len(strD)
    Do While intL > 1 And Mid$(strD, intL, 1) = "0"
      intL = intL - 1
    Loop
    strD = Left$(strD, intL)                    ' the significant digits
    intD = intE + 5                             ' the first digit's power of ten
    If intD >= -5 And intD <= 5 Then
      If intD >= 0 Then
        If intL <= intD + 1 Then
          strT = strD + String$(intD + 1 - intL, "0")
        Else
          strT = Left$(strD, intD + 1) + "." + Mid$(strD, intD + 2)
        End If
      Else
        strT = "0." + String$(-intD - 1, "0") + strD
      End If
    Else
      strT = Left$(strD, 1)
      If intL > 1 Then strT = strT + "." + Mid$(strD, 2)
      If intD < 0 Then strT = strT + "E-" Else strT = strT + "E+"
      strT = strT + Right$("0" + CStr(Abs(intD)), 2)
    End If
    strT = strS + strT
  End If
  ToText = strT
End Function

' a number from text: -12.5, 3, .25, 1.5E-3 (what doesn't parse ends it)
Public Function FromText(ByVal strT_a As String) As Long
  Dim lngN As Long, lngF As Long, intI As Integer, intE As Integer, intX As Integer
  Dim intNeg As Integer, intXNeg As Integer, intDot As Integer, intDigits As Integer, intGo As Integer
  Dim strC As String Max 1
  Init
  lngN = 0 : intE = 0 : intX = 0 : intNeg = 0 : intXNeg = 0 : intDot = 0 : intDigits = 0
  intI = 1
  Do While Mid$(strT_a, intI, 1) = " "
    intI = intI + 1
  Loop
  strC = Mid$(strT_a, intI, 1)
  If strC = "-" Then intNeg = 1
  If strC = "-" Or strC = "+" Then intI = intI + 1
  intGo = 1
  Do While intGo
    strC = Mid$(strT_a, intI, 1)
    If strC >= "0" And strC <= "9" Then
      If intDigits < 9 Then
        lngN = lngN * 10 + (Asc(strC) - 48)
        If lngN > 0 Then intDigits = intDigits + 1
        If intDot Then intE = intE - 1
      Else
        If intDot = 0 Then intE = intE + 1     ' (past 9 digits: only the size counts)
      End If
      intI = intI + 1
    ElseIf strC = "." And intDot = 0 Then
      intDot = 1
      intI = intI + 1
    Else
      intGo = 0
    End If
  Loop
  If strC = "E" Or strC = "e" Then
    intI = intI + 1
    strC = Mid$(strT_a, intI, 1)
    If strC = "-" Then intXNeg = 1
    If strC = "-" Or strC = "+" Then intI = intI + 1
    Do While Mid$(strT_a, intI, 1) >= "0" And Mid$(strT_a, intI, 1) <= "9" And intX < 1000
      intX = intX * 10 + (Asc(Mid$(strT_a, intI, 1)) - 48)
      intI = intI + 1
    Loop
    If intXNeg Then intE = intE - intX Else intE = intE + intX
  End If
  lngF = Op(5, lngN, 0, 0)
  If lngN <> 0 Then
    If intE > 63 Then intE = 63
    If intE < -63 Then intE = -63
    For intI = 5 To 0 Step -1
      If Abs(intE) >= Pow2(intI) Then
        If intE > 0 Then lngF = Op(3, lngF, m_lngPow(intI), 0) Else lngF = Op(4, lngF, m_lngPow(intI), 0)
        If intE > 0 Then intE = intE - Pow2(intI) Else intE = intE + Pow2(intI)
      End If
    Next
  End If
  If intNeg Then lngF = Op(7, lngF, 0, 0)
  FromText = lngF
End Function

' ---- half (16 bit, in an Integer): worked as singles, rounded back

Public Function ToHalf(ByVal lngF_a As Long) As Integer
  ToHalf = CInt(Op(10, lngF_a, 0, 0))
End Function

Public Function FromHalf(ByVal intH_a As Integer) As Long
  FromHalf = Op(9, CLng(intH_a), 0, 0)
End Function

Public Function HFromInt(ByVal lngN_a As Long) As Integer
  HFromInt = CInt(Op(10, Op(5, lngN_a, 0, 0), 0, 0))
End Function

Public Function HToInt(ByVal intH_a As Integer) As Long
  HToInt = Op(6, Op(9, CLng(intH_a), 0, 0), 0, 0)
End Function

Public Function HAdd(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
  HAdd = CInt(Op(10, Op(1, Op(9, CLng(intA_a), 0, 0), Op(9, CLng(intB_a), 0, 0), 0), 0, 0))
End Function

Public Function HSubtract(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
  HSubtract = CInt(Op(10, Op(2, Op(9, CLng(intA_a), 0, 0), Op(9, CLng(intB_a), 0, 0), 0), 0, 0))
End Function

Public Function HMultiply(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
  HMultiply = CInt(Op(10, Op(3, Op(9, CLng(intA_a), 0, 0), Op(9, CLng(intB_a), 0, 0), 0), 0, 0))
End Function

Public Function HDivide(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
  HDivide = CInt(Op(10, Op(4, Op(9, CLng(intA_a), 0, 0), Op(9, CLng(intB_a), 0, 0), 0), 0, 0))
End Function

Public Function HToText(ByVal intH_a As Integer) As String
  HToText = ToText(Op(9, CLng(intH_a), 0, 0))
End Function

Public Function HFromText(ByVal strT_a As String) As Integer
  HFromText = CInt(Op(10, FromText(strT_a), 0, 0))
End Function

' ---- a * b / c on Longs, the middle 64 bits, rounded (Overflow() True when it doesn't fit)

Public Function MulDiv(ByVal lngA_a As Long, ByVal lngB_a As Long, ByVal lngC_a As Long) As Long
  MulDiv = Op(11, lngA_a, lngB_a, lngC_a)
End Function

' ---- binary scales (fixed point with the point at a bit: s1.14 is bits 14, 24.8 is bits 8, s.7 is
' bits 7 - E3's formats): a single times 2 ^ bits, rounded to a whole number (halves away from 0),
' and back. Exact: a power of two only moves the exponent

Public Function ToBinScaled(ByVal lngF_a As Long, ByVal intBits_a As Integer) As Long
  ToBinScaled = ToIntRound(Op(3, lngF_a, Pow2F(intBits_a), 0))
End Function

Public Function FromBinScaled(ByVal lngN_a As Long, ByVal intBits_a As Integer) As Long
  FromBinScaled = Op(4, Op(5, lngN_a, 0, 0), Pow2F(intBits_a), 0)
End Function

' a whole array of singles into a binary scale in one call: D (Integer or Long elements) = A * 2 ^
' bits, rounded; an Integer clamps to -32767..32767 (Overflow). D's elements: as many as D has (no
' more than A's). Runs in the Z80 engine (cheap: never sent to a coprocessor)
Public Sub MToBinScaled(intD_a() As Integer, lngA_a() As Long, ByVal intBits_a As Integer)
#asm
            ld hl, ({intD_a})
            ld ({m_intPd}), hl
            ld hl, ({intD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({intD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({lngA_a})
            ld ({m_intPa}), hl
            ld hl, ({lngA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({lngA_a}+8)
            ld ({m_intNa1}), hl
#endasm
  CvtRun 2, intBits_a
End Sub

Public Sub MToBinScaledL(lngD_a() As Long, lngA_a() As Long, ByVal intBits_a As Integer)
#asm
            ld hl, ({lngD_a})
            ld ({m_intPd}), hl
            ld hl, ({lngD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({lngD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({lngA_a})
            ld ({m_intPa}), hl
            ld hl, ({lngA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({lngA_a}+8)
            ld ({m_intNa1}), hl
#endasm
  CvtRun 4, intBits_a
End Sub

' ---- the backend: 0 auto (the coprocessor if one answers, else the Z80 engine), 1 the Z80 engine
' only, 2 the coprocessor if there is one. Takes effect at the next operation
Public Sub UseEngine(ByVal intWhich_a As Integer)
  m_intWant = intWhich_a
  m_intJtOk = 0
End Sub

' 1 the Z80 engine, 2 a coprocessor (as the jump block is now)
Public Function Backend() As Integer
  Dim lngX As Long
  If m_intJtOk = 0 Then lngX = Op(8, 0, 0, 0)        ' (the block filled)
  If m_intCop Then Backend = 2 Else Backend = 1
End Function

' ---- whole arrays in one call (1 or 2 dimensions; the matrix product needs 2)
' Element by element: D(i) = A(i) op B(i), over as many elements as D has (A and B need at least
' as many). D may be A or B. One call loops in Z80: no BASIC call per element.

Public Sub MAdd(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  ArrayOp32 lngD_a, lngA_a, lngB_a, 1, 1
End Sub

Public Sub MSubtract(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  ArrayOp32 lngD_a, lngA_a, lngB_a, 2, 1
End Sub

' element by element (for the matrix product: MatMul)
Public Sub MMultiply(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  ArrayOp32 lngD_a, lngA_a, lngB_a, 3, 1
End Sub

Public Sub MDivide(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  ArrayOp32 lngD_a, lngA_a, lngB_a, 4, 1
End Sub

' D(i) = A(i) * k, D(i) = A(i) + k (k a single)
Public Sub MScale(lngD_a() As Long, lngA_a() As Long, ByVal lngK_a As Long)
  ArrayOpK32 lngD_a, lngA_a, lngK_a, 3, 1
End Sub

Public Sub MOffset(lngD_a() As Long, lngA_a() As Long, ByVal lngK_a As Long)
  ArrayOpK32 lngD_a, lngA_a, lngK_a, 1, 1
End Sub

' the matrix product: D (R x C) = A (R x K) times B (K x C); False when the sizes don't match
Public Function MatMul(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long) As Integer
  MatMul = MatOp32(lngD_a, lngA_a, lngB_a, 3, 1)
End Function

' the sum of A(i) * B(i), over A's elements
Public Function Dot(lngA_a() As Long, lngB_a() As Long) As Long
  Dot = DotOp32(lngA_a, lngB_a, 3, 1)
End Function

' ---- the array engine's entries (Fixed uses them: eop 1-4 single + - * /, 5-8 fixed + - * /
' with scale = 10 ^ places; the 16 versions take Integer arrays, the answers clamped to 16 bits)

Public Sub ArrayOp32(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long, ByVal intEop_a As Integer, ByVal lngScale_a As Long)
#asm
            ld hl, ({lngD_a})
            ld ({m_intPd}), hl
            ld hl, ({lngD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({lngD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({lngA_a})
            ld ({m_intPa}), hl
            ld hl, ({lngA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({lngA_a}+8)
            ld ({m_intNa1}), hl
            ld hl, ({lngB_a})
            ld ({m_intPb}), hl
            ld hl, ({lngB_a}+6)
            ld ({m_intNb0}), hl
            ld hl, ({lngB_a}+8)
            ld ({m_intNb1}), hl
#endasm
  m_intEs = 4 : m_intBk = 0
  ArrayRun intEop_a, lngScale_a
End Sub

Public Sub ArrayOpK32(lngD_a() As Long, lngA_a() As Long, ByVal lngK_a As Long, ByVal intEop_a As Integer, ByVal lngScale_a As Long)
#asm
            ld hl, ({lngD_a})
            ld ({m_intPd}), hl
            ld hl, ({lngD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({lngD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({lngA_a})
            ld ({m_intPa}), hl
            ld hl, ({lngA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({lngA_a}+8)
            ld ({m_intNa1}), hl
#endasm
  m_intNb0 = m_intNa0 : m_intNb1 = m_intNa1
  m_intEs = 4 : m_intBk = 1 : m_lngK = lngK_a
  ArrayRun intEop_a, lngScale_a
End Sub

Public Sub ArrayOp16(intD_a() As Integer, intA_a() As Integer, intB_a() As Integer, ByVal intEop_a As Integer, ByVal lngScale_a As Long)
#asm
            ld hl, ({intD_a})
            ld ({m_intPd}), hl
            ld hl, ({intD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({intD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({intA_a})
            ld ({m_intPa}), hl
            ld hl, ({intA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({intA_a}+8)
            ld ({m_intNa1}), hl
            ld hl, ({intB_a})
            ld ({m_intPb}), hl
            ld hl, ({intB_a}+6)
            ld ({m_intNb0}), hl
            ld hl, ({intB_a}+8)
            ld ({m_intNb1}), hl
#endasm
  m_intEs = 2 : m_intBk = 0
  ArrayRun intEop_a, lngScale_a
End Sub

Public Sub ArrayOpK16(intD_a() As Integer, intA_a() As Integer, ByVal lngK_a As Long, ByVal intEop_a As Integer, ByVal lngScale_a As Long)
#asm
            ld hl, ({intD_a})
            ld ({m_intPd}), hl
            ld hl, ({intD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({intD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({intA_a})
            ld ({m_intPa}), hl
            ld hl, ({intA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({intA_a}+8)
            ld ({m_intNa1}), hl
#endasm
  m_intNb0 = m_intNa0 : m_intNb1 = m_intNa1
  m_intEs = 2 : m_intBk = 1 : m_lngK = lngK_a
  ArrayRun intEop_a, lngScale_a
End Sub

Public Function MatOp32(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long, ByVal intEop_a As Integer, ByVal lngScale_a As Long) As Integer
#asm
            ld hl, ({lngD_a})
            ld ({m_intPd}), hl
            ld hl, ({lngD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({lngD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({lngA_a})
            ld ({m_intPa}), hl
            ld hl, ({lngA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({lngA_a}+8)
            ld ({m_intNa1}), hl
            ld hl, ({lngB_a})
            ld ({m_intPb}), hl
            ld hl, ({lngB_a}+6)
            ld ({m_intNb0}), hl
            ld hl, ({lngB_a}+8)
            ld ({m_intNb1}), hl
#endasm
  m_intEs = 4
  MatOp32 = MatRun(intEop_a, lngScale_a)
End Function

Public Function MatOp16(intD_a() As Integer, intA_a() As Integer, intB_a() As Integer, ByVal intEop_a As Integer, ByVal lngScale_a As Long) As Integer
#asm
            ld hl, ({intD_a})
            ld ({m_intPd}), hl
            ld hl, ({intD_a}+6)
            ld ({m_intNd0}), hl
            ld hl, ({intD_a}+8)
            ld ({m_intNd1}), hl
            ld hl, ({intA_a})
            ld ({m_intPa}), hl
            ld hl, ({intA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({intA_a}+8)
            ld ({m_intNa1}), hl
            ld hl, ({intB_a})
            ld ({m_intPb}), hl
            ld hl, ({intB_a}+6)
            ld ({m_intNb0}), hl
            ld hl, ({intB_a}+8)
            ld ({m_intNb1}), hl
#endasm
  m_intEs = 2
  MatOp16 = MatRun(intEop_a, lngScale_a)
End Function

Public Function DotOp32(lngA_a() As Long, lngB_a() As Long, ByVal intEop_a As Integer, ByVal lngScale_a As Long) As Long
#asm
            ld hl, ({lngA_a})
            ld ({m_intPa}), hl
            ld hl, ({lngA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({lngA_a}+8)
            ld ({m_intNa1}), hl
            ld hl, ({lngB_a})
            ld ({m_intPb}), hl
#endasm
  m_intEs = 4
  DotOp32 = DotRun(intEop_a, lngScale_a)
End Function

Public Function DotOp16(intA_a() As Integer, intB_a() As Integer, ByVal intEop_a As Integer, ByVal lngScale_a As Long) As Integer
#asm
            ld hl, ({intA_a})
            ld ({m_intPa}), hl
            ld hl, ({intA_a}+6)
            ld ({m_intNa0}), hl
            ld hl, ({intA_a}+8)
            ld ({m_intNa1}), hl
            ld hl, ({intB_a})
            ld ({m_intPb}), hl
#endasm
  m_intEs = 2
  DotOp16 = CInt(DotRun(intEop_a, lngScale_a))
End Function

' ---- inside

' element by element: the count is D's, no more than A's (or B's)
Private Sub ArrayRun(ByVal intEop_a As Integer, ByVal lngScale_a As Long)
  Dim intN As Integer
  intN = m_intNd0 * m_intNd1
  If m_intNa0 * m_intNa1 < intN Then intN = m_intNa0 * m_intNa1
  If m_intNb0 * m_intNb1 < intN Then intN = m_intNb0 * m_intNb1
  m_intN = intN : m_intEop = intEop_a : m_lngScale = lngScale_a
  If intN > 0 Then m_lngR = Op(12, 0, 0, 0)
End Sub

' the matrix product's sizes checked (A R x K, B K x C, D R x C), then run
Private Function MatRun(ByVal intEop_a As Integer, ByVal lngScale_a As Long) As Integer
  Dim intOk As Integer
  intOk = 0
  If m_intNa1 = m_intNb0 And m_intNd0 = m_intNa0 And m_intNd1 = m_intNb1 Then
    m_intR = m_intNa0 : m_intK = m_intNa1 : m_intC = m_intNb1
    m_intEop = intEop_a : m_lngScale = lngScale_a
    m_lngR = Op(13, 0, 0, 0)
    intOk = -1
  End If
  MatRun = intOk
End Function

' the dot product: a 1 x N by N x 1 matrix product into m_lngDot
Private Function DotRun(ByVal intEop_a As Integer, ByVal lngScale_a As Long) As Long
  m_lngDot = 0
  m_intR = 1 : m_intK = m_intNa0 * m_intNa1 : m_intC = 1
  m_intPd = VarPtr(m_lngDot)
  m_intEop = intEop_a : m_lngScale = lngScale_a
  m_lngR = Op(13, 0, 0, 0)
  If m_intEs = 2 Then                                ' (a 16 bit answer: sign extended from its 2 bytes)
    If m_lngDot > 32767 Then m_lngDot = m_lngDot - 65536
  End If
  DotRun = m_lngDot
End Function

' the conversion's run (op 14): A's singles, D's size, 2 ^ bits
Private Sub CvtRun(ByVal intEsD_a As Integer, ByVal intBits_a As Integer)
  Dim intN As Integer
  intN = m_intNd0 * m_intNd1
  If m_intNa0 * m_intNa1 < intN Then intN = m_intNa0 * m_intNa1
  m_intN = intN : m_intEs = 4 : m_intEsD = intEsD_a : m_lngK = intBits_a
  If intN > 0 Then m_lngR = Op(14, 0, 0, 0)
  m_intEsD = 0
End Sub

' 2 ^ n as a single (n -126 .. 127): its exponent alone
Private Function Pow2F(ByVal intN_a As Integer) As Long
  Dim lngE As Long
  lngE = intN_a + 127
  If lngE < 1 Then lngE = 1
  If lngE > 254 Then lngE = 254
  Pow2F = lngE * 8388608
End Function

Private Function Pow2(ByVal intI_a As Integer) As Integer
  Dim intP As Integer, intJ As Integer
  intP = 1
  For intJ = 1 To intI_a
    intP = intP * 2
  Next
  Pow2 = intP
End Function

' the powers of ten (10^1, 2, 4, 8, 16, 32) and the text's limits, as singles
Private Sub Init()
  If m_intInit = 0 Then
    m_lngPow(0) = &H41200000 : m_lngPow(1) = &H42C80000 : m_lngPow(2) = &H461C4000
    m_lngPow(3) = &H4CBEBC20 : m_lngPow(4) = &H5A0E1BCA : m_lngPow(5) = &H749DC5AE
    m_lngUp(0) = &H49742400 : m_lngUp(1) = &H4B189680 : m_lngUp(2) = &H4E6E6B28
    m_lngUp(3) = &H551184E7 : m_lngUp(4) = &H6258D727 : m_lngUp(5) = &H7CF0BDC2
    m_lngDn(0) = &H47C35000 : m_lngDn(1) = &H461C4000 : m_lngDn(2) = &H42C80000
    m_lngDn(3) = &H3C23D70A : m_lngDn(4) = &H2EDBE6FF : m_lngDn(5) = &H14461206
    m_intInit = 1
  End If
End Sub

' the engine: op 1 add, 2 subtract, 3 multiply, 4 divide, 5 from a Long, 6 to a Long, 7 negate,
' 8 absolute, 9 half to single, 10 single to half, 11 a * b / c (Longs). The one place a
' coprocessor would go.
Private Function Op(ByVal intOp_a As Integer, ByVal lngA_a As Long, ByVal lngB_a As Long, ByVal lngC_a As Long) As Long
#asm
FPW:           EQU {m_byW}
FA_S:        EQU FPW+0                 ; a number unpacked: its sign (0 / #80), exponent (16 bit),
FA_E:        EQU FPW+1                 ; mantissa (32 bit, the hidden 1 at bit 31, 8 guard bits)
FA_M:        EQU FPW+3
FB_S:        EQU FPW+7
FB_E:        EQU FPW+8
FB_M:        EQU FPW+10
FPP:           EQU FPW+14                ; a product (64 bit)
FPR:           EQU FPW+22                ; a remainder (40 bit)
FPDV:          EQU FPW+27                ; a divisor (32 bit)
FPMA:          EQU FPW+31                ; MulDiv's a, b, c (32 bit each)
FPMB:          EQU FPW+35
FPMC:          EQU FPW+39
FPCNT:         EQU FPW+43
MM_RA:      EQU FPW+44              ; the matrix product: A's row, B's column, the walking pointers,
MM_CB:      EQU FPW+46              ; the counts left, the sum so far
MM_PA:      EQU FPW+48
MM_PB:      EQU FPW+50
MM_PD:      EQU FPW+52
MM_R:       EQU FPW+54
MM_C:       EQU FPW+56
MM_K:       EQU FPW+58
MM_ACC:     EQU FPW+60
MM_A8:      EQU FPW+64              ; a fixed product's exact sum (64 bit)
            pop hl                  ; the op
            ld a, (hl)
            ld ({m_intOp}), a
            pop hl                  ; a
            ld de, {m_lngA}
            ld bc, 4
            ldir
            pop hl                  ; b
            ld de, {m_lngB}
            ld bc, 4
            ldir
            pop hl                  ; c
            ld de, {m_lngC}
            ld bc, 4
            ldir
            pop hl                  ; where the answer goes
            ld ({m_intRes}), hl
            ld (ntc_ip), sp         ; (the thread kept; calls on the real stack)
            ld sp, (ntc_csp)
            call fp_go
            ld sp, (ntc_ip)
            ld hl, {m_lngR}
            ld de, ({m_intRes})
            ld bc, 4
            ldir
            ret

fp_go:      ld a, ({m_intJtOk})        ; the jump block filled at the first call
            or a
            call z, jt_init
            ld a, ({m_intOp})
            cp 15
            jp nc, pk_zero
            add a, a
            ld e, a
            ld d, 0
            ld hl, {m_arrJt}
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            jp (hl)                 ; the operation: the Z80 engine's, or the coprocessor's

; ---- the jump block: the Z80 engine's routines; the coprocessor's forwarder in their place when
; one answers (CyborgOS's BDOS 131 op 40) and isn't refused (UseEngine 1)
jt_init:    ld hl, {m_arrJt}
            ld de, jt_z80
            ex de, hl
            ld bc, 30
            ldir
            xor a
            ld ({m_intCop}), a
            ld ({m_intCop}+1), a
            ld a, 1
            ld ({m_intJtOk}), a
            ld a, {FP_COP}          ; only CyborgOS has BDOS 131
            or a
            ret z
            ld a, ({m_intWant})
            cp 1
            ret z                   ; the Z80 engine asked for
            xor a                   ; asked: op 40, sub 0 - there?
            ld ({m_byQ}+1), a
            call cp_bdos
            or a
            ret nz                  ; 255: no coprocessor
            ld a, 1
            ld ({m_intCop}), a
            ld hl, cp_go            ; the coprocessor for all but negate / absolute (a bit each)
            ld de, {m_arrJt}+2
            ld b, 13
jt_c:       ld a, b                 ; (B counts down from 13 as DE walks up from entry 1: entry
            cp 7                    ; 14 - B; entries 7 and 8 - B 7 and 6 - kept)
            jr z, jt_n
            cp 6
            jr z, jt_n
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            dec hl
            ex de, hl
jt_n:       inc de
            inc de
            djnz jt_c
            ret
jt_z80:     dw pk_zero, f_add, f_sub, f_mul, f_div, f_fint, f_tint, f_neg
            dw f_abs, f_h2s, f_s2h, f_md, f_arr, f_mm, f_cvt

; ---- the coprocessor: the request block (BDOS 131 op 40), its answer back
; +0 40, +1 the operation, +2 A, +6 B, +10 C, +14 the answer, +18 overflow (1); arrays: +19 the
; element size, +20 the element operation, +21 B a single (1), +22 A's address, +24 B's, +26 D's,
; +28 the count, +30 R, +32 K, +34 C (the product's sizes), +36 the single k, +40 the scale
cp_go:      ld a, ({m_intOp})
            ld ({m_byQ}+1), a
            ld hl, {m_lngA}
            ld de, {m_byQ}+2
            ld bc, 4
            ldir
            ld hl, {m_lngB}
            ld bc, 4
            ldir
            ld hl, {m_lngC}
            ld bc, 4
            ldir
            ld a, ({m_intEs})
            ld ({m_byQ}+19), a
            ld a, ({m_intEop})
            ld ({m_byQ}+20), a
            ld a, ({m_intBk})
            ld ({m_byQ}+21), a
            ld hl, ({m_intPa})
            ld ({m_byQ}+22), hl
            ld hl, ({m_intPb})
            ld ({m_byQ}+24), hl
            ld hl, ({m_intPd})
            ld ({m_byQ}+26), hl
            ld hl, ({m_intN})
            ld ({m_byQ}+28), hl
            ld hl, ({m_intR})
            ld ({m_byQ}+30), hl
            ld hl, ({m_intK})
            ld ({m_byQ}+32), hl
            ld hl, ({m_intC})
            ld ({m_byQ}+34), hl
            ld hl, {m_lngK}
            ld de, {m_byQ}+36
            ld bc, 4
            ldir
            ld hl, {m_lngScale}
            ld bc, 4
            ldir
            call cp_bdos
            or a
            jr nz, cp_lost
            ld hl, {m_byQ}+14       ; the answer
            ld de, {m_lngR}
            ld bc, 4
            ldir
            ld a, ({m_byQ}+18)
            or a
            ret z
            ld a, 1
            ld ({m_intFlag}), a
            ret
cp_lost:    xor a                   ; the coprocessor went: the Z80 engine from now on
            ld ({m_intCop}), a
            ld a, 1
            ld ({m_intWant}), a
            xor a
            ld ({m_intJtOk}), a
            jp fp_go
cp_bdos:    ld a, 40                ; BDOS 131 with the request block: A the answer (0 done)
            ld ({m_byQ}), a
            ld ({m_intIx}), ix
            ld c, 131
            ld de, {m_byQ}
            ei
            call 5
            di
            ld ix, ({m_intIx})
            ret

; ---- helpers (HL, DE addresses, B bytes)
shl:        or a                    ; (HL) <<= 1, B bytes from the lowest
sh_l:       rl (hl)
            inc hl
            djnz sh_l
            ret
shr:        or a                    ; (HL) >>= 1, B bytes, HL at the highest
sr_l:       rr (hl)
            dec hl
            djnz sr_l
            ret
addn:       or a                    ; (HL) += (DE), B bytes
an_l:       ld a, (de)
            adc a, (hl)
            ld (hl), a
            inc hl
            inc de
            djnz an_l
            ret
subn:       or a                    ; (HL) -= (DE), B bytes
sn_l:       ld a, (de)
            ld c, a
            ld a, (hl)
            sbc a, c
            ld (hl), a
            inc hl
            inc de
            djnz sn_l
            ret
cmpn:       ld a, (de)              ; (HL) against (DE), B bytes from the highest: Z equal,
            ld c, a                 ; C (HL) smaller
            ld a, (hl)
            cp c
            ret nz
            dec hl
            dec de
            djnz cmpn
            ret
neg4:       ld b, 4                 ; (HL) = -(HL), 4 bytes (negn: B bytes)
negn:       or a
ng_l:       ld a, 0
            sbc a, (hl)
            ld (hl), a
            inc hl
            djnz ng_l
            ret
iszero:     ld a, (hl)              ; Z when the 4 bytes at HL are 0
            inc hl
            or (hl)
            inc hl
            or (hl)
            inc hl
            or (hl)
            ret
cpr:        ld de, {m_lngR}         ; the answer = the 4 bytes at HL
            ld bc, 4
            ldir
            ret

; ---- unpack a single: A into FA, B into FB
upa:        ld hl, {m_lngA}
            ld de, FA_S
            jr up
upb:        ld hl, {m_lngB}
            ld de, FB_S
up:         ld c, (hl)              ; b0
            inc hl
            ld b, (hl)              ; b1
            inc hl
            ld a, (hl)              ; b2
            inc hl
            ld h, (hl)              ; b3
            ld l, a
            ld a, h
            and #80
            ld (de), a              ; the sign
            inc de
            ld a, l
            rlca                    ; (the exponent's low bit into carry)
            ld a, h
            rla                     ; the exponent
            ld (de), a
            inc de
            push af
            xor a
            ld (de), a
            inc de
            pop af
            or a
            jr z, up_z
            xor a
            ld (de), a              ; m0 = 0 (the guard byte)
            inc de
            ld a, c
            ld (de), a
            inc de
            ld a, b
            ld (de), a
            inc de
            ld a, l
            or #80                  ; the hidden 1
            ld (de), a
            ret
up_z:       xor a
            ld (de), a
            inc de
            ld (de), a
            inc de
            ld (de), a
            inc de
            ld (de), a
            ret

; ---- FA normalised: the mantissa shifted up until bit 31 is set (it isn't 0)
nma:        ld a, (FA_M+3)
            or a
            jr nz, nm_l
            ld a, (FA_M+2)          ; a whole byte at a time first
            ld (FA_M+3), a
            ld a, (FA_M+1)
            ld (FA_M+2), a
            ld a, (FA_M)
            ld (FA_M+1), a
            xor a
            ld (FA_M), a
            ld hl, (FA_E)
            ld de, -8
            add hl, de
            ld (FA_E), hl
            jr nma
nm_l:       ld a, (FA_M+3)
            bit 7, a
            ret nz
            ld hl, FA_M
            ld b, 4
            call shl
            ld hl, (FA_E)
            dec hl
            ld (FA_E), hl
            jr nm_l

; ---- FA packed into the answer (rounded at the guard byte)
pka:        ld hl, FA_M
            call iszero
            jp z, pk_zero
            ld hl, FA_M
            ld a, (hl)
            add a, #80
            ld (hl), a
            jr nc, pk_r
            inc hl
            inc (hl)
            jr nz, pk_r
            inc hl
            inc (hl)
            jr nz, pk_r
            inc hl
            inc (hl)
            jr nz, pk_r
            ld (hl), #80            ; rounded up to 2.0: 1.0 and the exponent up
            ld hl, (FA_E)
            inc hl
            ld (FA_E), hl
pk_r:       ld hl, (FA_E)
            bit 7, h
            jr nz, pk_zero          ; below the smallest: 0
            ld a, h
            or l
            jr z, pk_zero
            ld a, h
            or a
            jr nz, pk_inf
            ld a, l
            cp 255
            jr nc, pk_inf
            ld a, (FA_M+1)
            ld ({m_lngR}), a
            ld a, (FA_M+2)
            ld ({m_lngR}+1), a
            ld a, l
            rrca                    ; the exponent's low bit to bit 7
            and #80
            ld b, a
            ld a, (FA_M+3)
            and #7F
            or b
            ld ({m_lngR}+2), a
            ld a, l
            srl a
            ld b, a
            ld a, (FA_S)
            or b
            ld ({m_lngR}+3), a
            ret
pk_zero:    xor a
            ld ({m_lngR}), a
            ld ({m_lngR}+1), a
            ld ({m_lngR}+2), a
            ld ({m_lngR}+3), a
            ret
pk_inf:     ld a, 1
            ld ({m_intFlag}), a
            xor a
            ld ({m_lngR}), a
            ld ({m_lngR}+1), a
            ld a, #80
            ld ({m_lngR}+2), a
            ld a, (FA_S)
            or #7F
            ld ({m_lngR}+3), a
            ret

; ---- add, subtract
f_sub:      ld a, ({m_lngB}+3)
            xor #80
            ld ({m_lngB}+3), a
f_add:      call upa
            call upb
            ld a, (FA_E)
            or a
            jr nz, ad_1
            ld hl, {m_lngB}         ; A is 0: B
            jp cpr
ad_1:       ld a, (FB_E)
            or a
            jr nz, ad_2
            ld hl, {m_lngA}         ; B is 0: A
            jp cpr
ad_2:       ld a, (FB_E)            ; the bigger one in FA
            ld b, a
            ld a, (FA_E)
            cp b
            jr c, ad_sw
            jr nz, ad_ok
            ld hl, FA_M+3
            ld de, FB_M+3
            ld b, 4
            call cmpn
            jr nc, ad_ok
ad_sw:      ld hl, FA_S
            ld de, FB_S
            ld b, 7
ad_x:       ld a, (de)
            ld c, (hl)
            ld (hl), a
            ld a, c
            ld (de), a
            inc hl
            inc de
            djnz ad_x
ad_ok:      ld a, (FB_E)
            ld b, a
            ld a, (FA_E)
            sub b                   ; how far apart
            cp 32
            jp nc, pka              ; too far: B doesn't count
ad_by:      cp 8
            jr c, ad_bi
            ld hl, FB_M+1           ; a byte at a time
            ld de, FB_M
            ld bc, 3
            ldir
            ld hl, FB_M+3
            ld (hl), 0
            sub 8
            jr ad_by
ad_bi:      or a
            jr z, ad_go
            ld c, a
ad_bl:      ld hl, FB_M+3
            ld b, 4
            call shr
            dec c
            jr nz, ad_bl
ad_go:      ld a, (FB_S)
            ld b, a
            ld a, (FA_S)
            cp b
            jr nz, ad_sub
            ld hl, FA_M             ; the same sign: the mantissas added
            ld de, FB_M
            ld b, 4
            call addn
            jp nc, pka
            ld hl, FA_M+3           ; a carry out: shifted back down, the exponent up
            rr (hl)
            dec hl
            rr (hl)
            dec hl
            rr (hl)
            dec hl
            rr (hl)
            ld hl, (FA_E)
            inc hl
            ld (FA_E), hl
            jp pka
ad_sub:     ld hl, FA_M             ; signs differ: the smaller taken from the bigger
            ld de, FB_M
            ld b, 4
            call subn
            ld hl, FA_M
            call iszero
            jp z, pk_zero
            call nma
            jp pka

; ---- multiply
f_mul:      call upa
            call upb
            ld a, (FA_E)
            or a
            jp z, pk_zero
            ld a, (FB_E)
            or a
            jp z, pk_zero
            ld a, (FB_S)
            ld b, a
            ld a, (FA_S)
            xor b
            ld (FA_S), a
            ld hl, (FA_E)
            ld de, (FB_E)
            add hl, de
            ld de, -127
            add hl, de
            ld (FA_E), hl
            ld hl, FPP                ; FPP = FA's 24 bits * FB's 24 bits (48 bits)
            ld b, 6
            xor a
mu_z:       ld (hl), a
            inc hl
            djnz mu_z
            ld a, 24
            ld (FPCNT), a
mu_l:       ld hl, FPP
            ld b, 6
            call shl
            ld hl, FB_M+1           ; the multiplier's next bit
            ld b, 3
            call shl
            jr nc, mu_n
            ld hl, FPP
            ld de, FA_M+1
            ld b, 3
            call addn
            ld hl, FPP+3
            ld b, 3
mu_c:       ld a, (hl)
            adc a, 0
            ld (hl), a
            inc hl
            djnz mu_c
mu_n:       ld hl, FPCNT
            dec (hl)
            jr nz, mu_l
            ld a, (FPP+5)
            bit 7, a
            jr nz, mu_t
            ld hl, FPP                ; 1.x * 1.x below 2: one shift up
            ld b, 6
            call shl
            jr mu_d
mu_t:       ld hl, (FA_E)           ; 2 or more: the exponent up
            inc hl
            ld (FA_E), hl
mu_d:       ld hl, FPP+2
            ld de, FA_M
            ld bc, 4
            ldir
            jp pka

; ---- divide
f_div:      call upa
            call upb
            ld a, (FB_S)
            ld b, a
            ld a, (FA_S)
            xor b
            ld (FA_S), a
            ld a, (FB_E)
            or a
            jp z, pk_inf            ; by 0: infinity
            ld a, (FA_E)
            or a
            jp z, pk_zero
            ld hl, (FA_E)
            ld de, (FB_E)
            or a
            sbc hl, de
            ld de, 127
            add hl, de
            ld (FA_E), hl
            ld a, (FA_M+1)          ; FPR = A's 24 bits, FPDV = B's 24 bits
            ld (FPR), a
            ld a, (FA_M+2)
            ld (FPR+1), a
            ld a, (FA_M+3)
            ld (FPR+2), a
            xor a
            ld (FPR+3), a
            ld a, (FB_M+1)
            ld (FPDV), a
            ld a, (FB_M+2)
            ld (FPDV+1), a
            ld a, (FB_M+3)
            ld (FPDV+2), a
            xor a
            ld (FPDV+3), a
            ld hl, FA_M             ; the quotient builds in FA's mantissa
            ld b, 4
dv_z:       ld (hl), a
            inc hl
            djnz dv_z
            ld a, 32
            ld (FPCNT), a
dv_l:       ld hl, FA_M
            ld b, 4
            call shl
            ld hl, FPR+3
            ld de, FPDV+3
            ld b, 4
            call cmpn
            jr c, dv_n              ; FPR < FPDV
            ld hl, FPR
            ld de, FPDV
            ld b, 4
            call subn
            ld hl, FA_M
            set 0, (hl)
dv_n:       ld hl, FPR
            ld b, 4
            call shl
            ld hl, FPCNT
            dec (hl)
            jr nz, dv_l
            ld a, (FA_M+3)
            bit 7, a
            jp nz, pka
            ld hl, FA_M             ; below 1: one shift up, the exponent down
            ld b, 4
            call shl
            ld hl, (FA_E)
            dec hl
            ld (FA_E), hl
            jp pka

; ---- from a Long
f_fint:     ld hl, {m_lngA}
            ld de, FA_M
            ld bc, 4
            ldir
            xor a
            ld (FA_S), a
            ld a, (FA_M+3)
            bit 7, a
            jr z, fi_p
            ld a, #80
            ld (FA_S), a
            ld hl, FA_M
            call neg4
fi_p:       ld hl, FA_M
            call iszero
            jp z, pk_zero
            ld hl, 158              ; 2^31 at bit 31
            ld (FA_E), hl
            call nma
            jp pka

; ---- to a Long (towards zero)
f_tint:     call upa
            ld a, (FA_E)
            cp 127
            jp c, pk_zero           ; below 1
            cp 158
            jr nc, ti_ov            ; 2^31 or more
            ld b, a
            ld a, 158
            sub b                   ; shift down by 158 - e
ti_by:      cp 8
            jr c, ti_bi
            ld hl, FA_M+1
            ld de, FA_M
            ld bc, 3
            ldir
            ld hl, FA_M+3
            ld (hl), 0
            sub 8
            jr ti_by
ti_bi:      or a
            jr z, ti_d
            ld c, a
ti_bl:      ld hl, FA_M+3
            ld b, 4
            call shr
            dec c
            jr nz, ti_bl
ti_d:       ld a, (FA_S)
            or a
            jr z, ti_w
            ld hl, FA_M
            call neg4
ti_w:       ld hl, FA_M
            jp cpr
ti_ov:      ld a, 1
            ld ({m_intFlag}), a
            ld a, (FA_S)
            or a
            ld hl, #FFFF
            ld de, #7FFF
            jr z, ti_o2
            ld hl, 0
            ld de, #8000
ti_o2:      ld ({m_lngR}), hl
            ld ({m_lngR}+2), de
            ret

; ---- negate, absolute (the sign bit)
f_neg:      ld hl, {m_lngA}
            call cpr
            ld a, ({m_lngR}+3)
            xor #80
            ld ({m_lngR}+3), a
            ret
f_abs:      ld hl, {m_lngA}
            call cpr
            ld a, ({m_lngR}+3)
            and #7F
            ld ({m_lngR}+3), a
            ret

; ---- half to single: s eeeee mmmmmmmmmm -> s, e + 112, m << 13
f_h2s:      ld hl, ({m_lngA})
            ld a, h
            and #80
            ld (FA_S), a
            ld a, h
            and #7C
            rrca
            rrca
            ld c, a                 ; e
            ld a, h
            and 3
            ld h, a                 ; HL = m (10 bits)
            ld a, c
            or a
            jr z, hs_z
            cp 31
            jr z, hs_i
            add a, 112
            ld c, a                 ; the single's exponent
            ld a, l
            and 7
            rrca
            rrca
            rrca
            ld ({m_lngR}+1), a      ; (m & 7) << 13
            xor a
            ld ({m_lngR}), a
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l                    ; m >> 3
            ld a, c
            rrca
            and #80
            or l
            ld ({m_lngR}+2), a
            ld a, c
            srl a
            ld b, a
            ld a, (FA_S)
            or b
            ld ({m_lngR}+3), a
            ret
hs_z:       call pk_zero
            ld a, (FA_S)
            ld ({m_lngR}+3), a
            ret
hs_i:       jp pk_inf

; ---- single to half (rounded): e - 112, the mantissa's top 10 bits
f_s2h:      call upa
            ld a, (FA_E)
            cp 113
            jr c, sh_z              ; too small (or 0)
            cp 143
            jr nc, sh_i             ; too big
            sub 112
            ld c, a                 ; the half's exponent (1-30)
            ld a, (FA_M+3)          ; HL = the top 11 bits (the hidden 1 at bit 10)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, (FA_M+2)
            rlca
            rlca
            rlca
            and 7
            or l
            ld l, a
            ld a, (FA_M+2)
            and #10                 ; rounded
            jr z, sh_r
            inc hl
sh_r:       ld a, h
            cp 8
            jr c, sh_ok
            ld hl, #0400            ; rounded up to 2.0: 1.0 and the exponent up
            inc c
            ld a, c
            cp 31
            jr nc, sh_i
sh_ok:      ld a, h
            and 3
            ld h, a
            ld a, c
            add a, a
            add a, a
            or h
            ld h, a
            ld a, (FA_S)
            or h
            ld h, a
            jr sh_w
sh_z:       ld a, (FA_S)
            ld h, a
            ld l, 0
            jr sh_w
sh_i:       ld a, 1
            ld ({m_intFlag}), a
            ld a, (FA_S)
            or #7C
            ld h, a
            ld l, 0
sh_w:       ld ({m_lngR}), hl       ; the half, sign extended (an Integer)
            ld a, h
            rlca
            sbc a, a
            ld ({m_lngR}+2), a
            ld ({m_lngR}+3), a
            ret

; ---- a * b / c (Longs): the product in 64 bits, rounded, divided; clamped if it doesn't fit
f_md:       xor a
            ld (FA_S), a
            call md_cp
            ld hl, FPMA
            call md_ab
            ld hl, FPMB
            call md_ab
            ld hl, FPMC
            call md_ab
            ld hl, FPMC
            call iszero
            jp z, md_ov             ; by 0
            call md_mul
            jp md_div
md_mul:     ld hl, FPP              ; FPP = FPMA * FPMB (64 bits)
            ld b, 8
            xor a
md_z:       ld (hl), a
            inc hl
            djnz md_z
            ld a, 32
            ld (FPCNT), a
md_ml:      ld hl, FPP
            ld b, 8
            call shl
            ld hl, FPMB
            ld b, 4
            call shl
            jr nc, md_mn
            ld hl, FPP
            ld de, FPMA
            ld b, 4
            call addn
            ld hl, FPP+4
            ld b, 4
md_mc:      ld a, (hl)
            adc a, 0
            ld (hl), a
            inc hl
            djnz md_mc
md_mn:      ld hl, FPCNT
            dec (hl)
            jr nz, md_ml
            ret
md_div:     ld hl, FPMC               ; m_lngR = FPP / FPMC, rounded (+ |c| / 2), FA_S's sign, clamped
            ld de, FPDV
            ld bc, 4
            ldir
            ld hl, FPDV+3
            ld b, 4
            call shr
            ld hl, FPP
            ld de, FPDV
            ld b, 4
            call addn
            ld hl, FPP+4
            ld b, 4
md_rc:      ld a, (hl)
            adc a, 0
            ld (hl), a
            inc hl
            djnz md_rc
            ld hl, FPR                ; FPP / |c|: 64 steps, FPR the remainder (40 bits)
            ld b, 5
            xor a
md_rz:      ld (hl), a
            inc hl
            djnz md_rz
            ld a, 64
            ld (FPCNT), a
md_dl:      ld hl, FPP
            ld b, 13                ; FPP and FPR side by side (FPP then FPR): one shift
            call shl
            ld a, (FPR+4)
            or a
            jr nz, md_ge
            ld hl, FPR+3
            ld de, FPMC+3
            ld b, 4
            call cmpn
            jr c, md_dn
md_ge:      ld hl, FPR
            ld de, FPMC
            ld b, 4
            call subn
            ld a, (FPR+4)
            sbc a, 0
            ld (FPR+4), a
            ld hl, FPP
            set 0, (hl)
md_dn:      ld hl, FPCNT
            dec (hl)
            jr nz, md_dl
            ld a, (FPP+4)             ; fits 31 bits?
            ld hl, FPP+5
            or (hl)
            inc hl
            or (hl)
            inc hl
            or (hl)
            jr nz, md_ov
            ld a, (FPP+3)
            bit 7, a
            jr nz, md_ov
            ld a, (FA_S)
            or a
            jr z, md_w
            ld hl, FPP
            call neg4
md_w:       ld hl, FPP
            jp cpr
md_ov:      ld a, 1
            ld ({m_intFlag}), a
            ld a, (FA_S)
            or a
            ld hl, #FFFF
            ld de, #7FFF
            jr z, md_o2
            ld hl, 1
            ld de, #8000            ; -2147483647
md_o2:      ld ({m_lngR}), hl
            ld ({m_lngR}+2), de
            ret
md_cp:      ld hl, {m_lngA}         ; FPMA, FPMB, FPMC = a, b, c
            ld de, FPMA
            ld bc, 4
            ldir
            ld hl, {m_lngB}
            ld bc, 4
            ldir
            ld hl, {m_lngC}
            ld bc, 4
            ldir
            ret
md_ab:      push hl                 ; (HL) made positive; FA_S flips when it was negative
            inc hl
            inc hl
            inc hl
            bit 7, (hl)
            pop hl
            ret z
            ld a, (FA_S)
            xor #80
            ld (FA_S), a
            jp neg4
; ---- arrays: one operation over whole arrays (op 12), the matrix product (op 13)
; an element: ES bytes (4 a Long, 2 an Integer - read sign extended, written back clamped)
ld_el:      ld a, ({m_intEs})       ; the element at HL into the Long at DE
            cp 2
            jr z, le_2
            ld bc, 4
            ldir
            ret
le_2:       ld a, (hl)
            ld (de), a
            inc hl
            inc de
            ld a, (hl)
            ld (de), a
            inc de
            rlca
            sbc a, a
            ld (de), a
            inc de
            ld (de), a
            ret
st_el:      ld a, ({m_intEsD})      ; the answer into the element at HL (D's size: MToBinScaled's,
            or a                    ; else ES)
            jr nz, st_s
            ld a, ({m_intEs})
st_s:       cp 2
            jr z, se_2
            ex de, hl
            ld hl, {m_lngR}
            ld bc, 4
            ldir
            ret
se_2:       push hl                 ; clamped to -32767 .. 32767
            ld hl, ({m_lngR}+2)
            ld de, ({m_lngR})
            ld a, h
            or l
            jr nz, se_hi
            bit 7, d
            jr z, se_ok
            jr se_cp
se_hi:      ld a, h
            and l
            inc a
            jr nz, se_cl            ; neither 0 nor -1 on top: too big
            bit 7, d
            jr z, se_cn
            ld a, d
            cp #80
            jr nz, se_ok
            ld a, e
            or a
            jr nz, se_ok
            jr se_cn                ; -32768: -32767
se_cl:      bit 7, h
            jr nz, se_cn
se_cp:      ld de, 32767
            jr se_f
se_cn:      ld de, -32767
se_f:       ld a, 1
            ld ({m_intFlag}), a
se_ok:      pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
el_do:      ld a, ({m_intEop})      ; the operation on A and B: 1-4 single + - * /, 5-8 fixed
            dec a
            jp z, f_add
            dec a
            jp z, f_sub
            dec a
            jp z, f_mul
            dec a
            jp z, f_div
            dec a
            jp z, x_add
            dec a
            jp z, x_sub
            dec a
            jp z, x_mul
            dec a
            jp z, x_div
            ret
x_mul:      ld hl, {m_lngScale}     ; fixed: A * B / scale
            ld de, {m_lngC}
            ld bc, 4
            ldir
            jp f_md
x_div:      ld hl, {m_lngB}         ; fixed: A * scale / B
            ld de, {m_lngC}
            ld bc, 4
            ldir
            ld hl, {m_lngScale}
            ld de, {m_lngB}
            ld bc, 4
            ldir
            jp f_md
x_add:      call x_ar               ; fixed: A + B, clamped
            ld hl, {m_lngR}
            ld de, {m_lngB}
            ld b, 4
            call addn
            ld a, ({m_lngB}+3)
            jr x_chk
x_sub:      call x_ar               ; fixed: A - B, clamped
            ld hl, {m_lngR}
            ld de, {m_lngB}
            ld b, 4
            call subn
            ld a, ({m_lngB}+3)
            xor #80
x_chk:      ld b, a                 ; (B's sign, as added)
            ld a, ({m_lngA}+3)
            xor b
            ret m                   ; signs differ: it can't overflow
            ld a, ({m_lngR}+3)
            xor b
            ret p                   ; the answer kept the sign: fine
            ld a, 1
            ld ({m_intFlag}), a
            ld a, ({m_lngA}+3)
            bit 7, a
            ld hl, #FFFF
            ld de, #7FFF
            jr z, x_c2
            ld hl, 1
            ld de, #8000
x_c2:       ld ({m_lngR}), hl
            ld ({m_lngR}+2), de
            ret
x_ar:       ld hl, {m_lngA}
            ld de, {m_lngR}
            ld bc, 4
            ldir
            ret
adv:        ld e, (hl)              ; the word at HL += the element size
            inc hl
            ld d, (hl)
            push hl
            ld hl, ({m_intEs})
            add hl, de
            ex de, hl
            pop hl
            ld (hl), d
            dec hl
            ld (hl), e
            ret

f_arr:      ld hl, ({m_intPa})      ; D(i) = A(i) op B(i) (or op the single k)
            ld de, {m_lngA}
            call ld_el
            ld a, ({m_intBk})
            or a
            jr nz, ar_k
            ld hl, ({m_intPb})
            ld de, {m_lngB}
            call ld_el
            jr ar_do
ar_k:       ld hl, {m_lngK}
            ld de, {m_lngB}
            ld bc, 4
            ldir
ar_do:      call el_do
            ld hl, ({m_intPd})
            call st_el
            ld hl, {m_intPa}
            call adv
            ld hl, {m_intPb}
            call adv
            ld hl, {m_intPd}
            call adv
            ld hl, ({m_intN})
            dec hl
            ld ({m_intN}), hl
            ld a, h
            or l
            jp nz, f_arr
            ret

f_mm:       ld hl, ({m_intPa})      ; D (R x C) = A (R x K) times B (K x C)
            ld (MM_RA), hl
            ld hl, ({m_intPd})
            ld (MM_PD), hl
            ld hl, ({m_intR})
            ld (MM_R), hl
mm_r:       ld hl, ({m_intPb})      ; each row of A
            ld (MM_CB), hl
            ld hl, ({m_intC})
            ld (MM_C), hl
mm_c:       ld hl, 0                ; each column of B: the sum from 0
            ld (MM_ACC), hl
            ld (MM_ACC+2), hl
            ld (MM_A8), hl
            ld (MM_A8+2), hl
            ld (MM_A8+4), hl
            ld (MM_A8+6), hl
            ld hl, (MM_RA)
            ld (MM_PA), hl
            ld hl, (MM_CB)
            ld (MM_PB), hl
            ld hl, ({m_intK})
            ld (MM_K), hl
mm_k:       ld hl, (MM_PA)          ; A(r, k) * B(k, c)
            ld de, {m_lngA}
            call ld_el
            ld hl, (MM_PB)
            ld de, {m_lngB}
            call ld_el
            ld a, ({m_intEop})
            cp 5
            jr nc, mm_fx
            call el_do
            ld hl, MM_ACC           ; added to the sum
            ld de, {m_lngA}
            ld bc, 4
            ldir
            ld hl, {m_lngR}
            ld de, {m_lngB}
            ld bc, 4
            ldir
            call f_add
            ld hl, {m_lngR}
            ld de, MM_ACC
            ld bc, 4
            ldir
            jr mm_nx
mm_fx:      xor a                   ; fixed: the exact product added to a 64 bit sum
            ld (FA_S), a
            ld hl, {m_lngA}
            ld de, FPMA
            ld bc, 4
            ldir
            ld hl, {m_lngB}
            ld de, FPMB
            ld bc, 4
            ldir
            ld hl, FPMA
            call md_ab
            ld hl, FPMB
            call md_ab
            call md_mul
            ld a, (FA_S)
            or a
            jr z, mm_fp
            ld hl, FPP
            ld b, 8
            call negn
mm_fp:      ld hl, MM_A8
            ld de, FPP
            ld b, 8
            call addn
mm_nx:      ld hl, MM_PA            ; along A's row
            call adv
            ld hl, (MM_PB)          ; down B's column: C elements on
            ld de, ({m_intC})
            ld a, ({m_intEs})
mm_st:      add hl, de
            dec a
            jr nz, mm_st
            ld (MM_PB), hl
            ld hl, (MM_K)
            dec hl
            ld (MM_K), hl
            ld a, h
            or l
            jp nz, mm_k
            ld a, ({m_intEop})
            cp 5
            jr nc, mm_f
            ld hl, MM_ACC           ; the sum into D(r, c)
            ld de, {m_lngR}
            ld bc, 4
            ldir
            jr mm_w
mm_f:       xor a                   ; fixed: the sum rounded to the places once (/ scale)
            ld (FA_S), a
            ld a, (MM_A8+7)
            bit 7, a
            jr z, mm_f1
            ld a, #80
            ld (FA_S), a
            ld hl, MM_A8
            ld b, 8
            call negn
mm_f1:      ld hl, MM_A8
            ld de, FPP
            ld bc, 8
            ldir
            ld hl, {m_lngScale}
            ld de, FPMC
            ld bc, 4
            ldir
            call md_div
mm_w:       ld hl, (MM_PD)
            call st_el
            ld hl, MM_PD
            call adv
            ld hl, MM_CB            ; the next column of B
            call adv
            ld hl, (MM_C)
            dec hl
            ld (MM_C), hl
            ld a, h
            or l
            jp nz, mm_c
            ld hl, (MM_RA)          ; the next row of A: K elements on
            ld de, ({m_intK})
            ld a, ({m_intEs})
mm_ra:      add hl, de
            dec a
            jr nz, mm_ra
            ld (MM_RA), hl
            ld hl, (MM_R)
            dec hl
            ld (MM_R), hl
            ld a, h
            or l
            jp nz, mm_r
            ret
; ---- op 14: D(i) = round(A(i) * 2 ^ k) - the exponent moved, then rounded to a whole number
f_cvt:      ld hl, ({m_intPa})
            ld de, {m_lngA}
            call ld_el
            call upa
            ld a, (FA_E)
            or a
            jr z, cv_z              ; 0 stays 0
            ld hl, (FA_E)
            ld de, ({m_lngK})
            add hl, de
            ld (FA_E), hl
            call pka                ; the scaled single
            ld hl, {m_lngR}
            ld de, {m_lngA}
            ld bc, 4
            ldir
            ld hl, #0000            ; + 0.5, its sign A's (halves away from 0)
            ld ({m_lngB}), hl
            ld a, ({m_lngA}+3)
            and #80
            or #3F
            ld h, a
            ld l, 0
            ld ({m_lngB}+2), hl
            call f_add
            ld hl, {m_lngR}
            ld de, {m_lngA}
            ld bc, 4
            ldir
            call f_tint
            jr cv_w
cv_z:       call pk_zero
cv_w:       ld hl, ({m_intPd})
            call st_el
            ld hl, {m_intPa}
            call adv
            ld hl, ({m_intPd})      ; D on by its own size
            ld de, ({m_intEsD})
            add hl, de
            ld ({m_intPd}), hl
            ld hl, ({m_intN})
            dec hl
            ld ({m_intN}), hl
            ld a, h
            or l
            jp nz, f_cvt
            ret
#endasm
End Function
