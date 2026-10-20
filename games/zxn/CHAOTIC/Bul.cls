' Bul - CHAOTIC's bullets: 64 enemy bullets as hardware sprites 64-127, moved, checked and
' drawn in Z80 every frame. From IDOL WINGS's (shots, boxes and the beam taken out: CHAOTIC's
' shots fly down the lanes, worked out in BASIC). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Coordinates are Layer 2's (the paper: 0-255 across, 0-191 down); Step puts them on the
' sprites' screen (32 more each way). Positions are centres. Bullets move in 1/256ths of a pixel
' (an angle and a speed: Fire); they go when they leave the paper. Step tells you if one is on
' the player (within r pixels of the claw's middle).
' A frame:  Bul.Step px, py, r   (moves all, writes the sprites' table)
'           Frame : Bul.Show     (the table to the hardware)
Option Explicit

Private eb(639) As Byte           ' 64 bullets x 10: x (lo, hi), y (lo, hi), vx, vy, pattern (255 = none), palette
Private att(319) As Byte          ' 64 sprites x 5
Private hitF As Integer, live As Integer, cnt As Integer, ang As Integer, tmp As Integer
Private vx As Integer, vy As Integer, six As Integer
Private atn(16) As Integer

' Init: everything cleared
Public Sub Init()
  atn(0) = 0 : atn(1) = 3 : atn(2) = 5 : atn(3) = 8 : atn(4) = 10 : atn(5) = 12 : atn(6) = 15 : atn(7) = 17
  atn(8) = 19 : atn(9) = 21 : atn(10) = 23 : atn(11) = 25 : atn(12) = 26 : atn(13) = 28 : atn(14) = 29
  atn(15) = 31 : atn(16) = 32
  tmp = Sines()
  Reset
End Sub

' Reset: no bullets
Public Sub Reset()
#asm
            ld hl, {eb} + 8
            ld de, 10
            ld b, 64
rs_b:
            ld (hl), 255
            add hl, de
            djnz rs_b
            ld hl, {att}
            ld b, 64
rs_a:
            ld (hl), 0
            inc hl
            ld (hl), 0
            inc hl
            ld (hl), 0
            inc hl
            ld (hl), #40
            inc hl
            ld (hl), 0
            inc hl
            djnz rs_a
#endasm
End Sub

' Clear(): every enemy bullet gone (a bomb, a boss beaten): how many there were
Public Function Clear() As Integer
#asm
            ld hl, {eb} + 8
            ld de, 10
            ld bc, 64 * 256
cl_lp:
            ld a, (hl)
            cp 255
            jr z, cl_n
            ld (hl), 255
            inc c
cl_n:
            add hl, de
            djnz cl_lp
            pop hl
            ld (hl), c
            inc hl
            ld (hl), 0
#endasm
End Function

' Fire x, y, a, spd, pat, pal: an enemy bullet from x, y going way a (0-255: 0 down, 64 right,
' 128 up, 192 left) at spd sixteenths of a pixel a frame, sprite pattern pat in palette pal
Public Sub Fire(ByVal x As Integer, ByVal y As Integer, ByVal a As Integer, ByVal spd As Integer, ByVal pat As Integer, ByVal pal As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (fi_x + 1), a
            pop hl
            ld a, (hl)
            ld (fi_y + 1), a
            pop hl
            ld a, (hl)
            ld ({ang}), a
            pop hl
            ld a, (hl)
            ld (fi_s1 + 1), a
            ld (fi_s2 + 1), a
            pop hl
            ld a, (hl)
            ld (fi_p + 1), a
            pop hl
            ld a, (hl)
            rlca
            rlca
            rlca
            rlca
            and #F0
            ld (fi_c + 1), a
            ld hl, {eb} + 8         ; a free one
            ld de, 10
            ld b, 64
fi_find:
            ld a, (hl)
            cp 255
            jr z, fi_got
            add hl, de
            djnz fi_find
            jp fi_done
fi_got:
            ld de, -8
            add hl, de
            ld ({tmp}), hl
            ld a, ({ang})           ; vx = sin(a) * spd / 8
            ld hl, fn_bul_sines_sn_data
            add a, l
            ld l, a
            jr nc, fi_n1
            inc h
fi_n1:
            ld a, (hl)
            ld c, a
            bit 7, a
            jr z, fi_p1
            neg
fi_p1:
            ld d, a
fi_s1:
            ld e, 0
fi_zm1:
            db #ED, #30             ; mul d, e
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            bit 7, c
            jr z, fi_v1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
fi_v1:
            ld ({vx}), de
            ld a, ({ang})           ; vy = sin(a + 64) * spd / 8
            add a, 64
            ld hl, fn_bul_sines_sn_data
            add a, l
            ld l, a
            jr nc, fi_n2
            inc h
fi_n2:
            ld a, (hl)
            ld c, a
            bit 7, a
            jr z, fi_p2
            neg
fi_p2:
            ld d, a
fi_s2:
            ld e, 0
fi_zm2:
            db #ED, #30
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            bit 7, c
            jr z, fi_v2
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
fi_v2:
            ld ({vy}), de
            ld hl, ({tmp})
            ld (hl), 128
            inc hl
fi_x:
            ld (hl), 0
            inc hl
            ld (hl), 128
            inc hl
fi_y:
            ld (hl), 0
            inc hl
            ld de, ({vx})
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, ({vy})
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
fi_p:
            ld (hl), 0
            inc hl
fi_c:
            ld (hl), 0
fi_done:
#endasm
End Sub

' Step px, py, r: every bullet moved; Hit() true if one is within r pixels (across and down) of
' px, py
Public Sub Step(ByVal px As Integer, ByVal py As Integer, ByVal r As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (st_px + 1), a
            pop hl
            ld a, (hl)
            ld (st_py + 1), a
            pop hl
            ld a, (hl)
            ld (st_r1 + 1), a
            ld (st_r2 + 1), a
            add a, a
            inc a
            ld (st_d1 + 1), a
            ld (st_d2 + 1), a
            ld ({six}), ix
            xor a
            ld ({hitF}), a
            ld ({live}), a
            ld ix, {eb}
            ld de, {att}
            ld a, 64
            ld ({cnt}), a
st_lp:
            ld a, (ix + 8)
            cp 255
            jp z, st_free
            ld c, a                 ; the pattern
            ld a, (ix + 1)
            ld b, a                 ; the old x
            ld a, (ix + 0)          ; x += vx
            add a, (ix + 4)
            ld (ix + 0), a
            ld a, (ix + 1)
            adc a, (ix + 5)
            ld (ix + 1), a
            sub b                   ; off the side: it jumped across (wrapped)
            add a, 16
            cp 32
            jr nc, st_kill
            ld a, (ix + 1)
            cp 2
            jr c, st_kill
            cp 254
            jr nc, st_kill
            ld a, (ix + 2)          ; y += vy
            add a, (ix + 6)
            ld (ix + 2), a
            ld a, (ix + 3)
            adc a, (ix + 7)
            ld (ix + 3), a
            cp 190
            jr nc, st_kill
st_py:
            sub 0                   ; on the player: within r both ways
st_r1:
            add a, 3
st_d1:
            cp 7
            jr nc, st_nohit
            ld a, (ix + 1)
st_px:
            sub 0
st_r2:
            add a, 3
st_d2:
            cp 7
            jr nc, st_nohit
            ld a, 1
            ld ({hitF}), a
st_nohit:
            ld hl, {live}
            inc (hl)
            ld a, (ix + 1)          ; sprite x = x + 24 (9 bits)
            add a, 24
            ld (de), a
            inc de
            ld b, 0
            jr nc, st_x8
            inc b
st_x8:
            ld a, (ix + 3)
            add a, 24
            ld (de), a
            inc de
            ld a, (ix + 9)
            or b
            ld (de), a
            inc de
            ld a, c
            srl a
            or #C0
            ld (de), a
            inc de
            ld a, c
            and 1
            rrca
            rrca
            or #80
            ld (de), a
            inc de
            jr st_next
st_kill:
            ld (ix + 8), 255
st_free:
            xor a
            ld (de), a
            inc de
            ld (de), a
            inc de
            ld (de), a
            inc de
            ld a, #40
            ld (de), a
            inc de
            xor a
            ld (de), a
            inc de
st_next:
            ld bc, 10
            add ix, bc
            ld hl, {cnt}
            dec (hl)
            jp nz, st_lp
            ld ix, ({six})
#endasm
End Sub

' Show: the table to sprites 64-127 (straight after Frame)
Public Sub Show()
#asm
            ld bc, #303B
            ld a, 64
            out (c), a
            ld hl, {att}
            ld bc, 160 * 256 + #57
            otir
            ld b, 160
            otir
#endasm
End Sub

' Hit(): True when a bullet was on the player in the last Step
Public Function Hit() As Integer
  Hit = hitF
End Function

' Count(): the enemy bullets flying
Public Function Count() As Integer
  Count = live
End Function

' Aim(x, y, tx, ty): the way (0-255, as Fire's) from x, y to tx, ty
Public Function Aim(ByVal x As Integer, ByVal y As Integer, ByVal tx As Integer, ByVal ty As Integer) As Integer
  Dim dx As Integer, dy As Integer, ax As Integer, ay As Integer, t As Integer
  dx = tx - x : dy = ty - y
  ax = Abs(dx) : ay = Abs(dy)
  If ax = 0 And ay = 0 Then
    Aim = 0
    Exit Function
  End If
  If ax <= ay Then
    t = atn(ax * 16 \ ay)
  Else
    t = 64 - atn(ay * 16 \ ax)
  End If
  If dy >= 0 Then
    If dx >= 0 Then Aim = t Else Aim = (256 - t) And 255
  Else
    If dx >= 0 Then Aim = 128 - t Else Aim = 128 + t
  End If
End Function

' the sines: 256 steps round, x 127 (signed bytes)
Public Function Sines() As Integer
#asm
            pop hl
            ld de, sn_data
            ld (hl), e
            inc hl
            ld (hl), d
            ret
sn_data:
            db 0, 3, 6, 9, 12, 16, 19, 22, 25, 28, 31, 34, 37, 40, 43, 46
            db 49, 51, 54, 57, 60, 63, 65, 68, 71, 73, 76, 78, 81, 83, 85, 88
            db 90, 92, 94, 96, 98, 100, 102, 104, 106, 107, 109, 111, 112, 113, 115, 116
            db 117, 118, 120, 121, 122, 122, 123, 124, 125, 125, 126, 126, 126, 127, 127, 127
            db 127, 127, 127, 127, 126, 126, 126, 125, 125, 124, 123, 122, 122, 121, 120, 118
            db 117, 116, 115, 113, 112, 111, 109, 107, 106, 104, 102, 100, 98, 96, 94, 92
            db 90, 88, 85, 83, 81, 78, 76, 73, 71, 68, 65, 63, 60, 57, 54, 51
            db 49, 46, 43, 40, 37, 34, 31, 28, 25, 22, 19, 16, 12, 9, 6, 3
            db 0, 253, 250, 247, 244, 240, 237, 234, 231, 228, 225, 222, 219, 216, 213, 210
            db 207, 205, 202, 199, 196, 193, 191, 188, 185, 183, 180, 178, 175, 173, 171, 168
            db 166, 164, 162, 160, 158, 156, 154, 152, 150, 149, 147, 145, 144, 143, 141, 140
            db 139, 138, 136, 135, 134, 134, 133, 132, 131, 131, 130, 130, 130, 129, 129, 129
            db 129, 129, 129, 129, 130, 130, 130, 131, 131, 132, 133, 134, 134, 135, 136, 138
            db 139, 140, 141, 143, 144, 145, 147, 149, 150, 152, 154, 156, 158, 160, 162, 164
            db 166, 168, 171, 173, 175, 178, 180, 183, 185, 188, 191, 193, 196, 199, 202, 205
            db 207, 210, 213, 216, 219, 222, 225, 228, 231, 234, 237, 240, 244, 247, 250, 253
#endasm
End Function
