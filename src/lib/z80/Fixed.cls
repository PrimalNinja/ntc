' Fixed: fixed point for NTC BASIC - whole numbers with the decimal point implied: with 2 places,
' 1234 means 12.34. A value is an ordinary Integer (16 bit) or Long (32 bit), so adding,
' subtracting and comparing are BASIC's own + - < = (as fast as whole numbers); multiplying and
' dividing need the point put back, which is what this class does (rounded, halves away from 0).
'   Fixed.SetPlaces 2                    ' the places for everything after (0-9; 16 bit: 0-4)
'   x = Fixed.Val32("12.34") : y = Fixed.Val32("0.5")
'   Print Fixed.Text32(Fixed.Mul32(x, y))  ' 6.17
' What fits (the biggest value either way):
'   places   16 bit (Integer)   32 bit (Long)
'   0        32767              2147483647
'   1        3276.7             214748364.7
'   2        327.67             21474836.47
'   3        32.767             2147483.647
'   4        3.2767             214748.3647
'   5-9      (left out)         21474.83647 ... 2.147483647
' 16 bit with 5 places or more has nothing left of the point, so it isn't offered: those calls
' give 0 and Ok() False. Anything that doesn't fit is clamped to the biggest value and Ok() is
' False (until Ok is asked). Mul32 / Div32 work in 64 bits in the middle (Float.MulDiv), so no
' precision is lost on the way. Needs Float.cls in the project.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Dim m_intPlaces As Integer, m_lngScale As Long, m_intBad As Integer, m_intSet As Integer
Dim m_intSg As Integer, m_intLo As Integer      ' <--- NEW (Mul16 / Div16's Z80: the answer's sign, the product's low word)

' ---- the places

Public Sub SetPlaces(ByVal intP_a As Integer)
  Dim intI As Integer
  If intP_a < 0 Then intP_a = 0
  If intP_a > 9 Then intP_a = 9
  m_intPlaces = intP_a
  m_lngScale = 1
  For intI = 1 To intP_a
    m_lngScale = m_lngScale * 10
  Next
  m_intSet = 1
End Sub

Public Function Places() As Integer
  Need
  Places = m_intPlaces
End Function

' 10 ^ places: what 1.0 is
Public Function Scale() As Long
  Need
  Scale = m_lngScale
End Function

' False when something didn't fit (clamped) since Ok was last asked
Public Function Ok() As Integer
  Ok = (m_intBad = 0)
  m_intBad = 0
End Function

' ---- 16 bit (Integer)

' <--- CHANGED (20261114): Add16, Sub16, Mul16 and Div16 are Z80 now (asm keyword functions: called straight from the
' thread, no call stub). The answers, the clamping and Ok() are as the BASIC they replace gave (kept below each as a
' comment); Mul16 / Div16 took about 38000 T-states in BASIC (Long multiply, Long divide, Clamp16), about 3000 now.
' Mul16 and Div16 each carry their own copy of the multiply / divide (a program that uses one doesn't link the other).

' Add16 = Clamp16(CLng(intA_a) + CLng(intB_a))
Public Function Add16(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
#asm
            pop hl                  ; a
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl                  ; b
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            or a
            adc hl, de
            jp pe, fa_ov            ; past 16 bits: the sign is the wrong way round
            ld a, h
            cp #80
            jr nz, fa_ok
            ld a, l
            or a
            jr nz, fa_ok
            ld hl, -32767           ; -32768: clamped
            jr fa_bad
fa_ov:      bit 7, h
            ld hl, 32767
            jr nz, fa_bad
            ld hl, -32767
fa_bad:     ld a, 1
            ld ({m_intBad}), a
fa_ok:      ex de, hl
            pop hl                  ; the answer's address
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' Sub16 = Clamp16(CLng(intA_a) - CLng(intB_a))
Public Function Sub16(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
#asm
            pop hl                  ; a
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl                  ; b
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ex de, hl
            or a
            sbc hl, de
            jp pe, fs_ov
            ld a, h
            cp #80
            jr nz, fs_ok
            ld a, l
            or a
            jr nz, fs_ok
            ld hl, -32767
            jr fs_bad
fs_ov:      bit 7, h
            ld hl, 32767
            jr nz, fs_bad
            ld hl, -32767
fs_bad:     ld a, 1
            ld ({m_intBad}), a
fs_ok:      ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' If Fits16() Then lngR = Rescale(CLng(intA_a) * CLng(intB_a), m_lngScale) : Mul16 = Clamp16(lngR)
Public Function Mul16(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
#asm
            pop hl                  ; a
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl                  ; b
            ld c, (hl)
            inc hl
            ld b, (hl)
            pop hl                  ; the answer's address
            ld (ntc_ip), sp         ; (the thread kept; calls on the real stack)
            ld sp, (ntc_csp)
            push hl
            push de
            push bc
            call fm_nd
            pop de                  ; b
            pop hl                  ; a
            ld bc, 0
            jr nc, fm_st            ; 5 places or more: 0
            ld bc, ({m_lngScale})
            call fm_mdr
            ld b, h
            ld c, l
fm_st:      pop hl
            ld (hl), c
            inc hl
            ld (hl), b
            ld sp, (ntc_ip)
            ret
; ---- HL = a, DE = b, BC = c (signed): HL = a * b / c rounded (halves away from 0), clamped to
; -32767 .. 32767 (m_intBad set). c isn't 0. 16 x 16 -> 32 unsigned, + |c| / 2, 32 / 16.
fm_mdr:  ld a, h
            xor d
            xor b
            ld ({m_intSg}), a           ; bit 7: the answer's sign
            bit 7, h
            jr z, fm_a1
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
fm_a1:   bit 7, d
            jr z, fm_a2
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
fm_a2:   bit 7, b
            jr z, fm_a3
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
fm_a3:   push bc                 ; |c|
            ld b, h                 ; DE:HL = |a| * |b| (DE the multiplier, its top bit each turn)
            ld c, l
            ld hl, 0
            ld a, 16
fm_ml:   add hl, hl
            rl e
            rl d
            jr nc, fm_mn
            add hl, bc
            jr nc, fm_mn
            inc de
fm_mn:   dec a
            jr nz, fm_ml
            pop bc
            push bc
            srl b                   ; + |c| / 2
            rr c
            add hl, bc
            jr nc, fm_r1
            inc de
fm_r1:   pop bc
            ld ({m_intLo}), hl          ; DE:HL / BC, a word at a time: the top word first (skipped when 0)
            ld hl, 0
            ld a, d
            or e
            call nz, fm_dv
            push de                 ; the quotient's top word
            ld de, ({m_intLo})
            call fm_dv
            pop hl
            ld a, h
            or l
            jr nz, fm_cl            ; over 16 bits
            ex de, hl
            bit 7, h
            jr nz, fm_cl            ; over 32767
            jr fm_sn
fm_cl:   ld hl, 32767
            ld a, 1
            ld ({m_intBad}), a
fm_sn:   ld a, ({m_intSg})
            rla
            ret nc
            xor a                   ; negative
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; HL (the remainder so far, under BC) and the 16 bits in DE, by BC: DE = the quotient's 16 bits,
; HL = the remainder (BC is 32768 at most, so the remainder shifted fits 16 bits)
fm_dv:   ld a, 16
fm_dl:   sla e
            rl d
            adc hl, hl
            sbc hl, bc
            jr nc, fm_d1
            add hl, bc
            dec a
            jr nz, fm_dl
            ret
fm_d1:   inc e
            dec a
            jr nz, fm_dl
            ret
; the places set (2 when never set)? 16 bit offered with them (0-4)? Carry: yes
fm_nd:   ld a, ({m_intSet})
            or a
            jr nz, fm_n1
            ld hl, 2
            ld ({m_intPlaces}), hl
            ld hl, 100
            ld ({m_lngScale}), hl
            ld hl, 0
            ld ({m_lngScale}+2), hl
            ld hl, 1
            ld ({m_intSet}), hl
fm_n1:   ld a, ({m_intPlaces})
            cp 5
            ret c
            ld a, 1
            ld ({m_intBad}), a
            or a
            ret
#endasm
End Function

' If Fits16(): intB_a = 0: m_intBad = 1, -32767 (intA_a < 0) or 32767; else Rescale(CLng(intA_a) * m_lngScale, CLng(intB_a)) : Div16 = Clamp16(lngR)
Public Function Div16(ByVal intA_a As Integer, ByVal intB_a As Integer) As Integer
#asm
            pop hl                  ; a
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl                  ; b
            ld c, (hl)
            inc hl
            ld b, (hl)
            pop hl                  ; the answer's address
            ld (ntc_ip), sp
            ld sp, (ntc_csp)
            push hl
            push de
            push bc
            call fd_nd
            pop bc                  ; b
            pop hl                  ; a
            ld de, 0
            jr nc, fd_st            ; 5 places or more: 0
            ld a, b
            or c
            jr nz, fd_go
            ld a, 1                 ; by 0: the biggest value, a's sign
            ld ({m_intBad}), a
            ld de, 32767
            bit 7, h
            jr z, fd_st
            ld de, -32767
            jr fd_st
fd_go:      ld de, ({m_lngScale})
            call fd_mdr
            ex de, hl
fd_st:      pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ld sp, (ntc_ip)
            ret
; ---- HL = a, DE = b, BC = c (signed): HL = a * b / c rounded (halves away from 0), clamped to
; -32767 .. 32767 (m_intBad set). c isn't 0. 16 x 16 -> 32 unsigned, + |c| / 2, 32 / 16.
fd_mdr:  ld a, h
            xor d
            xor b
            ld ({m_intSg}), a           ; bit 7: the answer's sign
            bit 7, h
            jr z, fd_a1
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
fd_a1:   bit 7, d
            jr z, fd_a2
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
fd_a2:   bit 7, b
            jr z, fd_a3
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
fd_a3:   push bc                 ; |c|
            ld b, h                 ; DE:HL = |a| * |b| (DE the multiplier, its top bit each turn)
            ld c, l
            ld hl, 0
            ld a, 16
fd_ml:   add hl, hl
            rl e
            rl d
            jr nc, fd_mn
            add hl, bc
            jr nc, fd_mn
            inc de
fd_mn:   dec a
            jr nz, fd_ml
            pop bc
            push bc
            srl b                   ; + |c| / 2
            rr c
            add hl, bc
            jr nc, fd_r1
            inc de
fd_r1:   pop bc
            ld ({m_intLo}), hl          ; DE:HL / BC, a word at a time: the top word first (skipped when 0)
            ld hl, 0
            ld a, d
            or e
            call nz, fd_dv
            push de                 ; the quotient's top word
            ld de, ({m_intLo})
            call fd_dv
            pop hl
            ld a, h
            or l
            jr nz, fd_cl            ; over 16 bits
            ex de, hl
            bit 7, h
            jr nz, fd_cl            ; over 32767
            jr fd_sn
fd_cl:   ld hl, 32767
            ld a, 1
            ld ({m_intBad}), a
fd_sn:   ld a, ({m_intSg})
            rla
            ret nc
            xor a                   ; negative
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; HL (the remainder so far, under BC) and the 16 bits in DE, by BC: DE = the quotient's 16 bits,
; HL = the remainder (BC is 32768 at most, so the remainder shifted fits 16 bits)
fd_dv:   ld a, 16
fd_dl:   sla e
            rl d
            adc hl, hl
            sbc hl, bc
            jr nc, fd_d1
            add hl, bc
            dec a
            jr nz, fd_dl
            ret
fd_d1:   inc e
            dec a
            jr nz, fd_dl
            ret
; the places set (2 when never set)? 16 bit offered with them (0-4)? Carry: yes
fd_nd:   ld a, ({m_intSet})
            or a
            jr nz, fd_n1
            ld hl, 2
            ld ({m_intPlaces}), hl
            ld hl, 100
            ld ({m_lngScale}), hl
            ld hl, 0
            ld ({m_lngScale}+2), hl
            ld hl, 1
            ld ({m_intSet}), hl
fd_n1:   ld a, ({m_intPlaces})
            cp 5
            ret c
            ld a, 1
            ld ({m_intBad}), a
            or a
            ret
#endasm
End Function

' a whole number as a 16 bit fixed value (5 -> 500 with 2 places)
Public Function FromInt16(ByVal lngN_a As Long) As Integer
  Dim lngR As Long
  lngR = 0
  If Fits16() Then
    If Abs(lngN_a) > 32767 \ m_lngScale Then
      m_intBad = 1
      If lngN_a < 0 Then lngR = -32767 Else lngR = 32767
    Else
      lngR = lngN_a * m_lngScale
    End If
  End If
  FromInt16 = Clamp16(lngR)
End Function

' the whole part (towards zero)
Public Function ToInt16(ByVal intV_a As Integer) As Integer
  Need
  ToInt16 = CInt(Quot(CLng(intV_a), m_lngScale))
End Function

' the nearest whole number (halves away from zero)
Public Function Round16(ByVal intV_a As Integer) As Integer
  Need
  Round16 = CInt(Rescale(CLng(intV_a), m_lngScale))
End Function

Public Function Text16(ByVal intV_a As Integer) As String
  Need
  Text16 = TextOf(CLng(intV_a))
End Function

Public Function Val16(ByVal strT_a As String) As Integer
  Dim lngR As Long
  lngR = 0
  If Fits16() Then lngR = ValOf(strT_a)
  Val16 = Clamp16(lngR)
End Function

' to a Float single, and from one (rounded)
Public Function Float16(ByVal intV_a As Integer) As Long
  Need
  Float16 = Float.Divide(Float.FromInt(CLng(intV_a)), Float.FromInt(m_lngScale))
End Function

Public Function FromFloat16(ByVal lngF_a As Long) As Integer
  Dim lngR As Long
  lngR = 0
  If Fits16() Then
    lngR = Float.ToIntRound(Float.Multiply(lngF_a, Float.FromInt(m_lngScale)))
    If Float.Overflow() Then m_intBad = 1
  End If
  FromFloat16 = Clamp16(lngR)
End Function

' ---- 32 bit (Long)

Public Function Add32(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Dim lngR As Long
  lngR = lngA_a + lngB_a
  If lngA_a > 0 And lngB_a > 0 And lngR < 0 Then
    m_intBad = 1 : lngR = 2147483647
  ElseIf lngA_a < 0 And lngB_a < 0 And lngR >= 0 Then
    m_intBad = 1 : lngR = -2147483647
  End If
  Add32 = lngR
End Function

Public Function Sub32(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Dim lngR As Long
  lngR = lngA_a - lngB_a
  If lngA_a >= 0 And lngB_a < 0 And lngR < 0 Then
    m_intBad = 1 : lngR = 2147483647
  ElseIf lngA_a < 0 And lngB_a > 0 And lngR >= 0 Then
    m_intBad = 1 : lngR = -2147483647
  End If
  Sub32 = lngR
End Function

Public Function Mul32(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Need
  Mul32 = Float.MulDiv(lngA_a, lngB_a, m_lngScale)
  If Float.Overflow() Then m_intBad = 1
End Function

Public Function Div32(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Need
  Div32 = Float.MulDiv(lngA_a, m_lngScale, lngB_a)
  If Float.Overflow() Then m_intBad = 1
End Function

Public Function FromInt32(ByVal lngN_a As Long) As Long
  Dim lngR As Long
  Need
  If Abs(lngN_a) > 2147483647 \ m_lngScale Then
    m_intBad = 1
    If lngN_a < 0 Then lngR = -2147483647 Else lngR = 2147483647
  Else
    lngR = lngN_a * m_lngScale
  End If
  FromInt32 = lngR
End Function

Public Function ToInt32(ByVal lngV_a As Long) As Long
  Need
  ToInt32 = Quot(lngV_a, m_lngScale)
End Function

Public Function Round32(ByVal lngV_a As Long) As Long
  Need
  Round32 = Rescale(lngV_a, m_lngScale)
End Function

Public Function Text32(ByVal lngV_a As Long) As String
  Need
  Text32 = TextOf(lngV_a)
End Function

Public Function Val32(ByVal strT_a As String) As Long
  Need
  Val32 = ValOf(strT_a)
End Function

Public Function Float32(ByVal lngV_a As Long) As Long
  Need
  Float32 = Float.Divide(Float.FromInt(lngV_a), Float.FromInt(m_lngScale))
End Function

Public Function FromFloat32(ByVal lngF_a As Long) As Long
  Need
  FromFloat32 = Float.ToIntRound(Float.Multiply(lngF_a, Float.FromInt(m_lngScale)))
  If Float.Overflow() Then m_intBad = 1
End Function

' ---- whole arrays in one call (Float's array engine). With SetPlaces 0 these are plain integer
' matrix maths. Element by element: D(i) = A(i) op B(i), over D's elements; the product needs 2
' dimensions. Results that don't fit are clamped (Ok() False).

Public Sub MAdd32(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  Need
  Float.ArrayOp32 lngD_a, lngA_a, lngB_a, 5, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MSub32(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  Need
  Float.ArrayOp32 lngD_a, lngA_a, lngB_a, 6, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MMul32(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  Need
  Float.ArrayOp32 lngD_a, lngA_a, lngB_a, 7, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MDiv32(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long)
  Need
  Float.ArrayOp32 lngD_a, lngA_a, lngB_a, 8, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

' D(i) = A(i) * k, D(i) = A(i) + k (k a fixed value)
Public Sub MScale32(lngD_a() As Long, lngA_a() As Long, ByVal lngK_a As Long)
  Need
  Float.ArrayOpK32 lngD_a, lngA_a, lngK_a, 7, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MOffset32(lngD_a() As Long, lngA_a() As Long, ByVal lngK_a As Long)
  Need
  Float.ArrayOpK32 lngD_a, lngA_a, lngK_a, 5, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

' D (R x C) = A (R x K) times B (K x C); False when the sizes don't match
Public Function MatMul32(lngD_a() As Long, lngA_a() As Long, lngB_a() As Long) As Integer
  Need
  MatMul32 = Float.MatOp32(lngD_a, lngA_a, lngB_a, 7, m_lngScale)
  If Float.Overflow() Then m_intBad = 1
End Function

Public Function Dot32(lngA_a() As Long, lngB_a() As Long) As Long
  Need
  Dot32 = Float.DotOp32(lngA_a, lngB_a, 7, m_lngScale)
  If Float.Overflow() Then m_intBad = 1
End Function

Public Sub MAdd16(intD_a() As Integer, intA_a() As Integer, intB_a() As Integer)
  If Fits16() Then Float.ArrayOp16 intD_a, intA_a, intB_a, 5, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MSub16(intD_a() As Integer, intA_a() As Integer, intB_a() As Integer)
  If Fits16() Then Float.ArrayOp16 intD_a, intA_a, intB_a, 6, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MMul16(intD_a() As Integer, intA_a() As Integer, intB_a() As Integer)
  If Fits16() Then Float.ArrayOp16 intD_a, intA_a, intB_a, 7, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MDiv16(intD_a() As Integer, intA_a() As Integer, intB_a() As Integer)
  If Fits16() Then Float.ArrayOp16 intD_a, intA_a, intB_a, 8, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MScale16(intD_a() As Integer, intA_a() As Integer, ByVal intK_a As Integer)
  If Fits16() Then Float.ArrayOpK16 intD_a, intA_a, CLng(intK_a), 7, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Sub MOffset16(intD_a() As Integer, intA_a() As Integer, ByVal intK_a As Integer)
  If Fits16() Then Float.ArrayOpK16 intD_a, intA_a, CLng(intK_a), 5, m_lngScale
  If Float.Overflow() Then m_intBad = 1
End Sub

Public Function MatMul16(intD_a() As Integer, intA_a() As Integer, intB_a() As Integer) As Integer
  Dim intOk As Integer
  intOk = 0
  If Fits16() Then intOk = Float.MatOp16(intD_a, intA_a, intB_a, 7, m_lngScale)
  If Float.Overflow() Then m_intBad = 1
  MatMul16 = intOk
End Function

Public Function Dot16(intA_a() As Integer, intB_a() As Integer) As Integer
  Dim intR As Integer
  intR = 0
  If Fits16() Then intR = Float.DotOp16(intA_a, intB_a, 7, m_lngScale)
  If Float.Overflow() Then m_intBad = 1
  Dot16 = intR
End Function

' ---- inside

' the places not set yet: 2 (money)
Private Sub Need()
  If m_intSet = 0 Then SetPlaces 2
End Sub

' 16 bit offered with these places? (5 or more: nothing left of the point)
Private Function Fits16() As Integer
  Dim intF As Integer
  Need
  intF = -1
  If m_intPlaces > 4 Then
    m_intBad = 1
    intF = 0
  End If
  Fits16 = intF
End Function

Private Function Clamp16(ByVal lngV_a As Long) As Integer
  Dim lngR As Long
  lngR = lngV_a
  If lngR > 32767 Then
    lngR = 32767 : m_intBad = 1
  ElseIf lngR < -32767 Then
    lngR = -32767 : m_intBad = 1
  End If
  Clamp16 = CInt(lngR)
End Function

' a / b towards zero, whatever the signs
Private Function Quot(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Dim lngQ As Long
  lngQ = Abs(lngA_a) \ Abs(lngB_a)
  If (lngA_a < 0) <> (lngB_a < 0) Then lngQ = -lngQ
  Quot = lngQ
End Function

' a / b rounded (halves away from zero), whatever the signs
Private Function Rescale(ByVal lngA_a As Long, ByVal lngB_a As Long) As Long
  Dim lngQ As Long
  lngQ = (Abs(lngA_a) + Abs(lngB_a) \ 2) \ Abs(lngB_a)
  If (lngA_a < 0) <> (lngB_a < 0) Then lngQ = -lngQ
  Rescale = lngQ
End Function

' a fixed value as text: -12.34 (the places always shown)
Private Function TextOf(ByVal lngV_a As Long) As String
  Dim strT As String Max 24, strF As String Max 12, lngA As Long
  lngA = lngV_a
  If lngA = -2147483647 - 1 Then lngA = -2147483647
  strT = ""
  If lngA < 0 Then strT = "-" : lngA = -lngA
  strT = strT + CStr(lngA \ m_lngScale)
  If m_intPlaces > 0 Then
    strF = CStr(lngA - (lngA \ m_lngScale) * m_lngScale)
    strT = strT + "." + String$(m_intPlaces - Len(strF), "0") + strF
  End If
  TextOf = strT
End Function

' text as a fixed value: "12.345" with 2 places is 1235 (rounded); clamped to a Long
Private Function ValOf(ByVal strT_a As String) As Long
  Dim lngW As Long, lngF As Long, intI As Integer, intN As Integer, intNeg As Integer, intGo As Integer
  Dim intRound As Integer, intDot As Integer
  Dim strC As String Max 1
  lngW = 0 : lngF = 0 : intN = 0 : intNeg = 0 : intRound = 0 : intDot = 0
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
      If intDot = 0 Then
        If lngW > 214748363 Then
          m_intBad = 1                         ' (too many digits: kept at the top)
        Else
          lngW = lngW * 10 + (Asc(strC) - 48)
        End If
      ElseIf intN < m_intPlaces Then
        lngF = lngF * 10 + (Asc(strC) - 48)
        intN = intN + 1
      ElseIf intN = m_intPlaces Then
        If strC >= "5" Then intRound = 1       ' the first digit past the places rounds
        intN = intN + 1
      End If
      intI = intI + 1
    ElseIf strC = "." And intDot = 0 Then
      intDot = 1
      intI = intI + 1
    Else
      intGo = 0
    End If
  Loop
  Do While intN < m_intPlaces
    lngF = lngF * 10
    intN = intN + 1
  Loop
  ValOf = FromParts(lngW, lngF + intRound, intNeg)
End Function

' whole and fraction (already in places) put together, checked against a Long
Private Function FromParts(ByVal lngW_a As Long, ByVal lngF_a As Long, ByVal intNeg_a As Integer) As Long
  Dim lngR As Long
  If lngW_a > (2147483647 - lngF_a) \ m_lngScale Then
    m_intBad = 1
    lngR = 2147483647
  Else
    lngR = lngW_a * m_lngScale + lngF_a
  End If
  If intNeg_a Then lngR = -lngR
  FromParts = lngR
End Function
