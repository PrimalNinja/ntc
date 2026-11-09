' Rng - the random numbers of INTRODUCTION TO ZOSCII: the ZX Spectrum Next version of CyborgUnicorn.ZOSCII's ROMGenerator.
'   Seed (the "entropy sugar"): every change in the keyboard, each frame (Frame, called by Vid.Sync) - the tick it happened on,
'   the ticks since the last change (debounce / hold time), the keys that are down, and the count of changes - is mixed
'   into a 64 bit pool. Play also mixes in the typed message.
'   Source: the memory the demo is made of - INTRO.DAT's data blocks 0-24 - in 1KB chunks, put in a random order from the seed
'   (the order is kept in the scratch block, 2 bytes a chunk). Five readers each start at a random place in a random chunk, each
'   goes forward or backward and steps 1-5 bytes; the output byte is the XOR of the five (as ROMGenerator does with 5 MP3s).
'   The calls the program uses are only Rb (a byte), Pick (0 to n-1), Mix (add to the seed), Reseed and Frame: to run from
'   files (real MP3s, as CyborgOS does) replace this class with one with the same public calls.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Private Const NCH = 400, ORD = 2560
Private sps As Integer
Private p0 As Integer, p1 As Integer, p2 As Integer, p3 As Integer       ' the pool: 64 bits
Private c0 As Integer, c1 As Integer, c2 As Integer, c3 As Integer, chg As Integer   ' keys down now (8 half rows, 5 bits each, 1 = down)
Private tk As Integer, lt As Integer, nev As Integer
Private built As Integer, fromPool As Integer

' Round: one round of a 4 x 16 bit add-rotate-xor mix (the shape of SipHash's round) on the pool
Private Sub Round()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, ({p0})
            ld de, ({p1})
            add hl, de
            ld ({p0}), hl
            ex de, hl
            ld b, 5
            call rg_rol
            call rg_xor
            ld ({p1}), hl
            ex de, hl
            ld a, h
            ld h, l
            ld l, a
            ld ({p0}), hl
            ld hl, ({p2})
            ld de, ({p3})
            add hl, de
            ld ({p2}), hl
            ex de, hl
            ld b, 4
            call rg_rol
            call rg_xor
            ld ({p3}), hl
            ld hl, ({p0})
            ld de, ({p3})
            add hl, de
            ld ({p0}), hl
            ex de, hl
            ld b, 3
            call rg_rol
            call rg_xor
            ld ({p3}), hl
            ld hl, ({p2})
            ld de, ({p1})
            add hl, de
            ld ({p2}), hl
            ex de, hl
            ld b, 7
            call rg_rol
            call rg_xor
            ld ({p1}), hl
            ex de, hl
            ld a, h
            ld h, l
            ld l, a
            ld ({p2}), hl
            jp rg_done
rg_rol:     add hl, hl
            jr nc, rg_rn
            inc l
rg_rn:      djnz rg_rol
            ret
rg_xor:     ld a, h
            xor d
            ld h, a
            ld a, l
            xor e
            ld l, a
            ret
rg_done:    ld sp, ({sps})
#endasm
End Sub

' Scan: the 8 half rows of the keyboard (5 bits each, 1 = a key down) into c0-c3; Chg <> 0 if any differs from the last Scan
Private Sub Scan()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, rg_kb
            ld bc, #FEFE
            ld d, 8
rg_k:       in a, (c)
            cpl
            and #1F
            ld (hl), a
            inc hl
            rlc b
            dec d
            jr nz, rg_k
            ld hl, rg_kb
            ld de, rg_pv
            ld b, 8
            ld c, 0
rg_c:       ld a, (de)
            xor (hl)
            or c
            ld c, a
            ld a, (hl)
            ld (de), a
            inc hl
            inc de
            djnz rg_c
            ld a, c
            ld ({chg}), a
            ld hl, (rg_kb)
            ld ({c0}), hl
            ld hl, (rg_kb + 2)
            ld ({c1}), hl
            ld hl, (rg_kb + 4)
            ld ({c2}), hl
            ld hl, (rg_kb + 6)
            ld ({c3}), hl
            jp rg_sd
rg_kb:      ds 8
rg_pv:      ds 8
rg_sd:      ld sp, ({sps})
#endasm
End Sub

' Mix v: v goes into the pool
Public Sub Mix(ByVal v As Integer)
  p0 = p0 Xor v
  Round
  Round
End Sub

' Frame: once a frame (Vid.Sync calls it): a change in the keyboard goes into the pool, with when it happened
Public Sub Frame()
  Scan
  tk = tk + 1
  If chg <> 0 Then
    nev = nev + 1
    Mix tk
    Mix tk - lt
    Mix c0
    Mix c1
    Mix c2
    Mix c3
    Mix nev
    lt = tk
  End If
End Sub

' Pw: a 16 bit value from the pool; Pick(n): 0 to n-1 from the pool, every value as likely as any other
Private Function Pw() As Integer
  Round
  Pw = p0 Xor p1 Xor p2 Xor p3
End Function

' Chunk i of the order (scratch block must be in): Ord / PutOrd
Private Function GetOrd(ByVal i As Integer) As Integer
  GetOrd = Peek(&H4000 + ORD + i * 2) + Peek(&H4000 + ORD + i * 2 + 1) * 256
End Function

Private Sub PutOrd(ByVal i As Integer, ByVal v As Integer)
  Poke &H4000 + ORD + i * 2, v And 255
  Poke &H4000 + ORD + i * 2 + 1, v \ 256
End Sub

' Reseed: the seed is the pool now; the chunks are put in a new order and the five readers are placed
Public Sub Reseed()
  Dim i As Integer, j As Integer, t As Integer, r As Integer, cp As Integer, co As Integer, ch As Integer, u As Integer
  fromPool = 1
  Vid.SelBlock Data.SCRB
  For i = 0 To NCH - 1
    PutOrd i, i
  Next
  For i = NCH - 1 To 1 Step -1
    j = Pick(i + 1)
    t = GetOrd(i)
    PutOrd i, GetOrd(j)
    PutOrd j, t
  Next
  For r = 0 To 4
    cp = Pick(NCH)
    co = Pick(1024)
    j = Pick(2) * 2 - 1
    t = 2 + Pick(99)
    u = 2 + Pick(99)
    ch = GetOrd(cp)
    Place r, ch \ 16, ch And 15, co, j * t, cp, j * u
  Next
  Vid.SelBlock -1
  fromPool = 0
  built = 1
End Sub

' Rb: a random byte: the XOR of the five readers. Each reader's record (8 bytes at rg_st): +0 block, +1 sub-chunk (1KB in the 16K
' block), +2/+3 offset in the chunk, +4 the step to take now and +7 the other step (signed, they swap each byte: A, B, A, B...), +5/+6 place in the order. Past the chunk's end (or start) it goes on into the
' next (or last) chunk of the order, which is read from the scratch block (2 bytes a chunk, from byte ORD).
Public Function Rb() As Integer
#asm
            pop hl
            ld (rg_ra), hl
            ld (rg_sp), sp
            ld sp, (ntc_csp)
            ld ix, rg_st
            ld b, 5
            ld c, 0
rg_r:       ld l, (ix+0)
            ld h, 0
            ld de, ntc_nexdata + 1
            add hl, de
            ld l, (hl)
            ld h, 0
            call zxn_sel
            ld a, (ix+1)
            add a, a
            add a, a
            or #40
            or (ix+3)
            ld h, a
            ld l, (ix+2)
            ld a, (hl)
            xor c
            ld c, a
            ld e, (ix+4)
            ld a, (ix+7)
            ld (ix+4), a
            ld (ix+7), e
            ld d, 0
            bit 7, e
            jr z, rg_p
            dec d
rg_p:       ld l, (ix+2)
            ld h, (ix+3)
            add hl, de
            bit 7, h
            jr nz, rg_bk
            ld a, h
            cp 4
            jr c, rg_ok
            sub 4
            ld h, a
            ld (ix+2), l
            ld (ix+3), h
            ld l, (ix+5)
            ld h, (ix+6)
            inc hl
            ld de, 400
            or a
            sbc hl, de
            jr nc, rg_w0
            add hl, de
            jr rg_cs
rg_w0:      ld hl, 0
            jr rg_cs
rg_bk:      ld a, h
            add a, 4
            ld h, a
            ld (ix+2), l
            ld (ix+3), h
            ld l, (ix+5)
            ld h, (ix+6)
            ld a, h
            or l
            jr nz, rg_d
            ld hl, 400
rg_d:       dec hl
rg_cs:      ld (ix+5), l
            ld (ix+6), h
            add hl, hl
            ld de, #4000 + {ORD}
            add hl, de
            push hl
            ld hl, {Data.SCRB}
            ld de, ntc_nexdata + 1
            add hl, de
            ld l, (hl)
            ld h, 0
            call zxn_sel
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld a, e
            and 15
            ld (ix+1), a
            ld a, e
            rrca
            rrca
            rrca
            rrca
            and 15
            ld e, a
            ld a, d
            rlca
            rlca
            rlca
            rlca
            and #F0
            or e
            ld (ix+0), a
            jr rg_nx
rg_ok:      ld (ix+2), l
            ld (ix+3), h
rg_nx:      ld de, 8
            add ix, de
            dec b
            jp nz, rg_r
            push af
            push bc
            ld bc, (ntc_rampt)
            call nxt_win
            ld a, #FF
            ld (zxn_selb), a
            pop bc
            pop af
            ld hl, (rg_ra)
            ld (hl), c
            inc hl
            ld (hl), 0
            ld sp, (rg_sp)
            jp rg_end
rg_ra:      dw 0
rg_sp:      dw 0
@rg_st:     ds 40
rg_end:
#endasm
End Function

' Place r, blk, sub, co, sd, cp, sd2: reader r starts in sub-chunk sub of block blk at offset co, steps sd, sd2, sd, sd2... and is at place cp of the order
Private Sub Place(ByVal r As Integer, ByVal blk As Integer, ByVal sb As Integer, ByVal co As Integer, ByVal sd As Integer, ByVal cp As Integer, ByVal sd2 As Integer)
#asm
            pop hl
            ld e, (hl)
            ld d, 0
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, rg_st
            add hl, de
            ld a, h
            ld ixh, a
            ld a, l
            ld ixl, a
            pop hl
            ld a, (hl)
            ld (ix+0), a
            pop hl
            ld a, (hl)
            ld (ix+1), a
            pop hl
            ld a, (hl)
            ld (ix+2), a
            inc hl
            ld a, (hl)
            ld (ix+3), a
            pop hl
            ld a, (hl)
            ld (ix+4), a
            pop hl
            ld a, (hl)
            ld (ix+5), a
            inc hl
            ld a, (hl)
            ld (ix+6), a
            pop hl
            ld a, (hl)
            ld (ix+7), a
#endasm
End Sub

' Pick n: a random number 0 to n-1 (0 if n < 2), every value as likely as any other. (Reseed uses it with the pool, as the readers
' aren't placed yet.)
Public Function Pick(ByVal n As Integer) As Integer
  Dim m As Integer, v As Integer
  Pick = 0
  If n <= 1 Then Exit Function
  m = 1
  Do While m < n - 1
    m = m * 2 + 1
  Loop
  Do
    If fromPool <> 0 Then
      v = Pw()
    ElseIf m > 255 Then
      v = Rb()
      v = v * 256 + Rb()
    Else
      v = Rb()
    End If
    v = v And m
  Loop Until v < n
  Pick = v
End Function

' Start a, b, c, d: the pool begins as these 64 bits (the program passes the digits of pi: the first events have something to mix
' into; tests pass their own, to repeat a run from its seed)
Public Sub Start(ByVal a As Integer, ByVal b As Integer, ByVal c As Integer, ByVal d As Integer)
  p0 = a : p1 = b : p2 = c : p3 = d
  built = 0
End Sub
