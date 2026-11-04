' Tiny: 8-bit scaled numbers for NTC BASIC - a byte holds -2.0 .. 1.98 in steps of 1/64 (1.0 is
' 64), with every operation saturating at the ends instead of wrapping. The tiny-float idea: a
' value between -1 and 1 doesn't need a Float; a byte is 4 x smaller, an add is one instruction and
' a multiply a short shift-add - and tanh, a sigmoid and a reciprocal are 256-byte tables (made by
' tools/tiny/mktables.js, carried here as #asm data). For weights, activations, velocities,
' anything normalised; not for positions, money or time (use Integer, Long or Fixed).
'   A value is an Integer in -128 .. 127 (a Byte array holds them as 0-255: see FromByte / ToByte).
'   Tiny.One                        64
'   Tiny.Add(a, b) / Sub(a, b)      saturated
'   Tiny.Mul(a, b)                  a * b / 64, rounded (a half up), saturated
'   Tiny.Div(a, b)                  a * 64 / b, saturated (b = 0: the sign's end)
'   Tiny.Sat(n)                     an Integer clamped to -128 .. 127
'   Tiny.Tanh(a) / Sigm(a)          tanh (-64 .. 64), the logistic sigmoid (0 .. 64)
'   Tiny.Dot(waddr, xaddr, n)       sum of w(i) * x(i) / 64 over n byte pairs, saturated (8-bit weights)
'   Tiny.FromByte(b) / ToByte(a)    0-255 <-> -128..127
'   Tiny.Text(a)                    "-0.75" (two places)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Public Const One = 64

Dim m_intAcc As Integer, m_intN As Integer, m_intW As Integer, m_intX As Integer

Public Function Sat(ByVal n As Integer) As Integer
  If n > 127 Then
    Sat = 127
  ElseIf n < -128 Then
    Sat = -128
  Else
    Sat = n
  End If
End Function

Public Function FromByte(ByVal b As Integer) As Integer
  If b > 127 Then FromByte = b - 256 Else FromByte = b
End Function

Public Function ToByte(ByVal a As Integer) As Integer
  If a < 0 Then ToByte = a + 256 Else ToByte = a
End Function

Public Function Add(ByVal a As Integer, ByVal b As Integer) As Integer
  Add = Sat(a + b)
End Function

Public Function Subtract(ByVal a As Integer, ByVal b As Integer) As Integer
  Subtract = Sat(a - b)
End Function

' a * b / 64 rounded (a half rounds up: floor((a * b + 32) / 64), what the PC reference does),
' saturated - an 8 x 8 shift-add in the Z80
Public Function Mul(ByVal a As Integer, ByVal b As Integer) As Integer
#asm
            pop hl
            ld c, (hl)              ; a (the low byte: the value)
            pop hl
            ld e, (hl)              ; b
            pop hl
            ld ({m_intAcc}), hl     ; the result's place
            ld a, c
            xor e
            ld ({m_intW}), a        ; bit 7: the product's sign
            ld a, c
            or a
            jp p, tm_a
            neg
tm_a:       ld c, a                 ; |a|
            ld a, e
            or a
            jp p, tm_b
            neg
tm_b:       ld e, a                 ; |b| (128 stays 128: fine, unsigned here)
            ld hl, 0
            ld d, 0
            ld b, 8
tm_loop:    srl c
            jr nc, tm_no
            add hl, de
tm_no:      sla e
            rl d
            djnz tm_loop            ; HL = |a| * |b|
            ld a, ({m_intW})
            or a
            jp p, tm_pos
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de              ; HL = the signed product
tm_pos:     ld de, 32
            add hl, de              ; + 32, then / 64 with the sign kept (floor)
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld a, h
            or a
            jr z, tm_ok
            inc a
            jr z, tm_neg
            bit 7, h
            jr nz, tm_lo
            ld hl, 127
            jr tm_put
tm_lo:      ld hl, -128
            jr tm_put
tm_neg:     ld a, l                 ; H = -1: fits when L >= 128
            cp 128
            jr nc, tm_put
            ld hl, -128
            jr tm_put
tm_ok:      ld a, l                 ; H = 0: fits when L < 128
            cp 128
            jr c, tm_put
            ld hl, 127
tm_put:     ld de, ({m_intAcc})
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' a * 64 / b, saturated; b = 0 gives the end a's sign points at (0 stays 0)
Public Function Div(ByVal a As Integer, ByVal b As Integer) As Integer
  Dim l As Long
  If b = 0 Then
    If a > 0 Then
      Div = 127
    ElseIf a < 0 Then
      Div = -128
    Else
      Div = 0
    End If
    Exit Function
  End If
  l = CLng(a) * 128 \ b                     ' twice the answer, for the rounding
  If l < 0 Then l = l - 1 Else l = l + 1
  l = l \ 2
  If l > 127 Then
    Div = 127
  ElseIf l < -128 Then
    Div = -128
  Else
    Div = l
  End If
End Function

' tanh(a), -64 .. 64
Public Function Tanh(ByVal a As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            pop hl
            ld ({m_intAcc}), hl   ; the result's place
            ld d, 0
            ld hl, tb_tanh
            add hl, de
            ld a, (hl)
            ld l, a
            rla
            sbc a, a
            ld h, a                 ; sign-extended
            ld de, ({m_intAcc})
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
tb_tanh:    db 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
                        db 16,17,18,18,19,20,21,22,23,24,25,26,26,27,28,29
                        db 30,30,31,32,33,33,34,35,35,36,37,38,38,39,39,40
                        db 41,41,42,42,43,43,44,45,45,46,46,47,47,47,48,48
                        db 49,49,50,50,50,51,51,51,52,52,52,53,53,53,54,54
                        db 54,55,55,55,55,56,56,56,56,57,57,57,57,57,58,58
                        db 58,58,58,58,59,59,59,59,59,59,60,60,60,60,60,60
                        db 60,60,60,61,61,61,61,61,61,61,61,61,61,61,62,62
                        db 194,194,194,195,195,195,195,195,195,195,195,195,195,195,196,196
                        db 196,196,196,196,196,196,196,197,197,197,197,197,197,198,198,198
                        db 198,198,198,199,199,199,199,199,200,200,200,200,201,201,201,201
                        db 202,202,202,203,203,203,204,204,204,205,205,205,206,206,206,207
                        db 207,208,208,209,209,209,210,210,211,211,212,213,213,214,214,215
                        db 215,216,217,217,218,218,219,220,221,221,222,223,223,224,225,226
                        db 226,227,228,229,230,230,231,232,233,234,235,236,237,238,238,239
                        db 240,241,242,243,244,245,246,247,248,249,250,251,252,253,254,255
#endasm
End Function

' the logistic sigmoid of a, 0 .. 64
Public Function Sigm(ByVal a As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            pop hl
            ld ({m_intAcc}), hl   ; the result's place
            ld d, 0
            ld hl, tb_sigm
            add hl, de
            ld a, (hl)
            ld l, a
            ld h, 0
            ld de, ({m_intAcc})
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
tb_sigm:    db 32,32,32,33,33,33,33,34,34,34,34,35,35,35,35,36
                        db 36,36,36,37,37,37,37,38,38,38,38,39,39,39,39,40
                        db 40,40,40,41,41,41,41,41,42,42,42,42,43,43,43,43
                        db 43,44,44,44,44,45,45,45,45,45,46,46,46,46,46,47
                        db 47,47,47,47,48,48,48,48,48,48,49,49,49,49,49,50
                        db 50,50,50,50,50,51,51,51,51,51,51,52,52,52,52,52
                        db 52,52,53,53,53,53,53,53,53,54,54,54,54,54,54,54
                        db 55,55,55,55,55,55,55,55,55,56,56,56,56,56,56,56
                        db 8,8,8,8,8,8,8,8,9,9,9,9,9,9,9,9
                        db 9,10,10,10,10,10,10,10,11,11,11,11,11,11,11,12
                        db 12,12,12,12,12,12,13,13,13,13,13,13,14,14,14,14
                        db 14,14,15,15,15,15,15,16,16,16,16,16,16,17,17,17
                        db 17,17,18,18,18,18,18,19,19,19,19,19,20,20,20,20
                        db 21,21,21,21,21,22,22,22,22,23,23,23,23,23,24,24
                        db 24,24,25,25,25,25,26,26,26,26,27,27,27,27,28,28
                        db 28,28,29,29,29,29,30,30,30,30,31,31,31,31,32,32
#endasm
End Function

' sum over n of w(i) * x(i) / 64: w and x signed bytes at waddr / xaddr; the sum kept in 16 bits
' (the products summed whole, divided once at the end), then saturated to a byte's range
Public Function Dot(ByVal waddr As Integer, ByVal xaddr As Integer, ByVal n As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({m_intW}), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({m_intX}), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({m_intN}), de
            pop hl
            ld ({m_intAcc}), hl     ; the result's place
            ld ix, ({m_intW})
            ld iy, ({m_intX})
            ld hl, 0                ; the sum (16 bits: 64 products of 127 x 127 would not fit -
tdot_loop:  ld de, ({m_intN})       ; a caller keeps n x |w| x |x| under 32767, as a net's layers do)
            ld a, d
            or e
            jr z, tdot_done
            dec de
            ld ({m_intN}), de
            ld a, (ix+0)
            inc ix
            ld e, (iy+0)
            inc iy
            or a
            jr z, tdot_loop         ; w = 0: nothing
            ld d, a
            ld a, e
            or a
            jr z, tdot_loop         ; x = 0: nothing
            xor d
            ld c, a                 ; C bit 7: the product's sign
            ld a, d
            or a
            jp p, tdot_a
            neg
tdot_a:     ld d, a                 ; D = |w|
            ld a, e
            or a
            jp p, tdot_b
            neg
tdot_b:     ld e, a                 ; E = |x|
            ld a, d
            ld d, 0                 ; DE = |x|, shifted up as A's bits are used
tdot_m:     srl a
            jr nc, tdot_n
            bit 7, c
            jr nz, tdot_s
            add hl, de
            jr tdot_n
tdot_s:     scf
            ccf
            sbc hl, de
tdot_n:     sla e
            rl d
            or a
            jr nz, tdot_m
            jr tdot_loop
tdot_done:  ld de, 32
            add hl, de              ; rounded, / 64
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            sra h
            rr l
            ld a, h
            or a
            jr z, tdot_ok
            inc a
            jr z, tdot_neg
            bit 7, h
            jr nz, tdot_lo
            ld hl, 127
            jr tdot_put
tdot_lo:    ld hl, -128
            jr tdot_put
tdot_neg:   ld a, l                 ; H = -1: fits when L >= 128
            cp 128
            jr nc, tdot_put
            ld hl, -128
            jr tdot_put
tdot_ok:    ld a, l                 ; H = 0: fits when L < 128
            cp 128
            jr c, tdot_put
            ld hl, 127
tdot_put:   ld de, ({m_intAcc})
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' "-0.75": the value with two places
Public Function Text(ByVal a As Integer) As String
  Dim s As String Max 8, v As Integer, f As Integer
  v = a
  If v < 0 Then s = "-" : v = -v Else s = ""
  s = s + Trim$(Str$(v \ 64)) + "."
  f = (v And 63) * 100 \ 64
  If f < 10 Then s = s + "0"
  Text = s + Trim$(Str$(f))
End Function
