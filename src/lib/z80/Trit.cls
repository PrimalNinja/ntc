' Trit: ternary values for NTC BASIC - a trit is -1, 0 or 1 (inhibit / neutral / active; false /
' unknown / true; a wall / ground / a signal). 0 is the absorbing value: anything gated by a 0 is
' never evaluated, which is the short-circuit a Z80 does best ("or a / jr z").
'   One a byte when live: 0, 1 or 255 (-1). Four a byte when stored: 2 bits each, trit 0 in bits
'   0-1 ... trit 3 in bits 6-7, 00 = 0, 01 = 1, 11 = -1 (10 is spare: read as 0). A trit is taken
'   out with an AND and put back with an OR - nothing moves - and the packed byte is a lookup
'   table's index (four neighbours in one byte).
'   Trit.Tand(a, b) / Tor / Tnot / Tmul / Tmaj(a, b, c)   Kleene and (min), or (max), not, the
'                                                         sign product, majority (the sign of a+b+c)
'   Trit.Gate(t, x)                 x if t = 1, -x if t = -1, 0 if t = 0 (a ternary weight)
'   Trit.Pack addr, paddr, n        n trits (bytes at addr) packed 4 a byte at paddr (n a multiple of 4)
'   Trit.Unpack paddr, addr, n      the other way
'   Trit.Get4(paddr, i) / Set4 paddr, i, t      trit i (0-3) of the packed byte at paddr
'   Trit.Scan(paddr, n)             n packed bytes looked at: bit 0 set when any trit is 1, bit 1
'                                   when any is -1 - 0 means all neutral: skip the lot
'   Trit.Dot(paddr, xaddr, n)       sum of w(i) * x(i): w n packed trits at paddr, x n signed bytes
'                                   at xaddr (n a multiple of 4) - the ternary multiply-accumulate,
'                                   16 bits, adds and subtracts only
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Dim m_intAcc As Integer, m_intN As Integer, m_intX As Integer, m_intW As Integer

' ---- the logic (a trit in an Integer: -1, 0, 1)

Public Function Tand(ByVal a As Integer, ByVal b As Integer) As Integer
  If a < b Then Tand = a Else Tand = b
End Function

Public Function Tor(ByVal a As Integer, ByVal b As Integer) As Integer
  If a > b Then Tor = a Else Tor = b
End Function

Public Function Tnot(ByVal a As Integer) As Integer
  Tnot = -a
End Function

' the sign product: 0 if either is 0
Public Function Tmul(ByVal a As Integer, ByVal b As Integer) As Integer
  Tmul = a * b
End Function

' the majority: the sign of a + b + c (two agreeing win; 0 when they cancel)
Public Function Tmaj(ByVal a As Integer, ByVal b As Integer, ByVal c As Integer) As Integer
  Dim s As Integer
  s = a + b + c
  If s > 0 Then
    Tmaj = 1
  ElseIf s < 0 Then
    Tmaj = -1
  Else
    Tmaj = 0
  End If
End Function

' x gated by t: x, -x or 0
Public Function Gate(ByVal t As Integer, ByVal x As Integer) As Integer
  If t = 0 Then
    Gate = 0
  ElseIf t > 0 Then
    Gate = x
  Else
    Gate = -x
  End If
End Function

' a byte (0, 1, 255) as a trit (-1, 0, 1), and back
Public Function FromByte(ByVal b As Integer) As Integer
  If b = 0 Then
    FromByte = 0
  ElseIf b = 1 Then
    FromByte = 1
  Else
    FromByte = -1
  End If
End Function

Public Function ToByte(ByVal t As Integer) As Integer
  If t = 0 Then
    ToByte = 0
  ElseIf t > 0 Then
    ToByte = 1
  Else
    ToByte = 255
  End If
End Function

' ---- packed: 4 a byte

' trit i (0-3) of the packed byte at paddr
Public Function Get4(ByVal paddr As Integer, ByVal i As Integer) As Integer
  Dim b As Integer
  b = Peek(paddr)
  If i = 1 Then
    b = b \ 4
  ElseIf i = 2 Then
    b = b \ 16
  ElseIf i = 3 Then
    b = b \ 64
  End If
  b = b And 3
  If b = 1 Then
    Get4 = 1
  ElseIf b = 3 Then
    Get4 = -1
  Else
    Get4 = 0
  End If
End Function

' trit i (0-3) of the packed byte at paddr set to t (the other three kept)
Public Sub Set4(ByVal paddr As Integer, ByVal i As Integer, ByVal t As Integer)
  Dim b As Integer, m As Integer, v As Integer
  If t = 0 Then
    v = 0
  ElseIf t > 0 Then
    v = 1
  Else
    v = 3
  End If
  m = 3
  If i = 1 Then
    v = v * 4 : m = 12
  ElseIf i = 2 Then
    v = v * 16 : m = 48
  ElseIf i = 3 Then
    v = v * 64 : m = 192
  End If
  b = Peek(paddr)
  Poke paddr, (b And (255 - m)) Or v
End Sub

' n trits (bytes 0 / 1 / 255 at addr) packed at paddr, 4 a byte - n a multiple of 4
Public Sub Pack(ByVal addr As Integer, ByVal paddr As Integer, ByVal n As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; DE = the trits
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; BC = where they go
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a                 ; HL = n
            srl h
            rr l
            srl h
            rr l                    ; HL = n / 4 bytes
            ld a, h
            or l
            ret z
            ld ({m_intN}), hl
            ex de, hl               ; HL = the trits, BC = the packed bytes
tp_byte:    ld e, 0                 ; E: the byte being built
            ld d, 4
tp_trit:    ld a, (hl)
            inc hl
            and 3                   ; 0 -> 00, 1 -> 01, 255 -> 11 (and 3 of 255 is 3)
            rrca
            rrca                    ; the field to bits 6-7
            srl e
            srl e                   ; the byte down 2: the first trit ends in bits 0-1
            or e
            ld e, a
            dec d
            jr nz, tp_trit
            ld a, e
            ld (bc), a
            inc bc
            ex de, hl
            ld hl, ({m_intN})
            dec hl
            ld ({m_intN}), hl
            ld a, h
            or l
            ex de, hl
            jr nz, tp_byte
#endasm
End Sub

' n trits unpacked from paddr (4 a byte) to bytes 0 / 1 / 255 at addr - n a multiple of 4
Public Sub Unpack(ByVal paddr As Integer, ByVal addr As Integer, ByVal n As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; DE = the packed bytes
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; BC = the trits
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a                 ; HL = n
            srl h
            rr l
            srl h
            rr l
            ld a, h
            or l
            ret z
            ld ({m_intN}), hl
            ex de, hl               ; HL = the packed bytes, BC = the trits
tu_byte:    ld e, (hl)
            inc hl
            ld d, 4
tu_trit:    ld a, e
            and 3
            cp 3
            jr nz, tu_put           ; 00 -> 0, 01 -> 1, 10 (spare) -> 2: made 0 below
            ld a, 255
tu_put:     cp 2
            jr nz, tu_ok
            xor a                   ; the spare code reads as 0
tu_ok:      ld (bc), a
            inc bc
            srl e
            srl e
            dec d
            jr nz, tu_trit
            ex de, hl
            ld hl, ({m_intN})
            dec hl
            ld ({m_intN}), hl
            ld a, h
            or l
            ex de, hl
            jr nz, tu_byte
#endasm
End Sub

' n packed bytes at paddr looked at: bit 0 set when some trit is 1, bit 1 when some is -1
' (0: every trit is neutral - nothing to do). and #55 / and #AA on each byte: no unpacking
Public Function Scan(ByVal paddr As Integer, ByVal n As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; DE = the bytes
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; BC = n
            pop hl
            ld ({m_intAcc}), hl     ; where the answer goes
            ex de, hl               ; HL = the bytes
            ld e, 0                 ; E: bit 0 any 1, bit 1 any -1
ts_loop:    ld a, b
            or c
            jr z, ts_done
            dec bc
            ld a, (hl)
            inc hl
            ld d, a
            and #55                 ; the low bits of the four fields: set where the trit isn't 0
            jr z, ts_loop
            ld a, d
            rrca                    ; the high bits down over the low ones
            and d
            and #55                 ; set where a field is 11 (-1)
            jr z, ts_pos
            set 1, e
            ld a, d
            rrca
            cpl
            and d
            and #55                 ; set where a field is 01 (1)
            jr z, ts_loop
            set 0, e
            ld a, e
            cp 3
            jr nz, ts_loop
            jr ts_done              ; both seen: no need to look further
ts_pos:     set 0, e
            jr ts_loop
ts_done:    ld hl, ({m_intAcc})
            ld (hl), e
            inc hl
            ld (hl), 0
#endasm
End Function

' sum of w(i) * x(i), i < n: w n trits packed at paddr, x n signed bytes at xaddr - adds and
' subtracts only (a 0 weight costs a test and a jump). n a multiple of 4. 16 bits, wraps.
Public Function Dot(ByVal paddr As Integer, ByVal xaddr As Integer, ByVal n As Integer) As Integer
#asm
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; BC = the weights
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({m_intW}), de
            ld ix, ({m_intW})       ; IX = x (no push: SP is the thread)
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            srl h
            rr l
            srl h
            rr l
            ld ({m_intN}), hl       ; n / 4 weight bytes
            pop hl
            ld ({m_intX}), hl       ; where the answer goes
            ld hl, 0                ; HL: the sum
            ld de, ({m_intN})
            ld a, d
            or e
            jr z, td_done
td_byte:    ld a, (bc)
            inc bc
            or a
            jr nz, td_four
            ld de, 4                ; four zero weights: x skipped whole
            add ix, de
            jr td_next
td_four:    ld d, a                 ; D = the four fields, used up from the low end
            ld e, 4
td_field:   ld a, d
            srl d
            srl d
            and 3
            jr z, td_skip           ; 00: nothing
            cp 2
            jr z, td_skip           ; 10 (the spare code): nothing
            ld ({m_intW}), bc
            ld c, (ix+0)            ; x(i), sign-extended into BC
            ld b, 0
            bit 7, c
            jr z, td_pos
            dec b
td_pos:     cp 1
            jr nz, td_sub
            add hl, bc
            jr td_acc
td_sub:     or a
            sbc hl, bc
td_acc:     ld bc, ({m_intW})
td_skip:    inc ix
            dec e
            jr nz, td_field
td_next:    ld de, ({m_intN})
            dec de
            ld ({m_intN}), de
            ld a, d
            or e
            jr nz, td_byte
td_done:    ld de, ({m_intX})
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
