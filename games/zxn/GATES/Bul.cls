' Bul - the bullet engine: 60 enemy bullets and 18 player shots as hardware sprites 50-127,
' moved, checked and drawn in Z80 every frame. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' This copy is for GATES OF DOOM: the play area is the whole 256 x 192 paper (under a 16 pixel
' HUD); shots fly any of the four ways (the pan is 0). Coordinates are the paper's (0-255 across, 0-191 down; Show adds 24 to put
' them on the sprites' screen). Positions are centres.
' Enemy bullets move in 1/256ths of a pixel (an angle and a speed: Fire); they go when they leave
' the play area (rows 20-187 - the HUD is above). Step tells you if one is on the player (within
' 5 pixels of the centre).
' Shots fly vx across and vy down a frame and hit boxes: up to 24
' targets Main puts down each frame (Box n, x, y, half width, half height), each counting its hits
' until Hits(n) reads them.
' Step's pan is how far the view moved this frame (pixels, + right): everything flying moves the
' other way with the ground.
' A frame:  Bul.Step px, py, pan  (moves all, writes the sprites' table)
'           Frame : Bul.Show (the table to the hardware)
Option Explicit

Private eb(599) As Byte           ' 60 bullets x 10: x (lo, hi), y (lo, hi), vx, vy, pattern (255 = none), palette
Private sh(89) As Byte            ' 18 shots x 5: x, y, vx, vy, on
Private bx(143) As Byte           ' 24 boxes x 6: on, x, y, half width, half height, hits
Private att(389) As Byte          ' 78 sprites x 5
Private hitF As Integer, live As Integer, spk As Integer, spkX As Integer, spkY As Integer
Private cnt As Integer, ang As Integer, tmp As Integer, vx As Integer, vy As Integer
Private sa3 As Integer, sa4 As Integer, six As Integer
Private atn(16) As Integer

' Init shotPattern: everything cleared, the shots' sprite pattern
Public Sub Init(ByVal shotPattern As Integer)
  Dim k As Integer
  sa3 = &HC0 Or (shotPattern \ 2)
  sa4 = &H80 Or ((shotPattern And 1) * 64)
  ' atan(k / 16) in 256ths of a turn
  atn(0) = 0 : atn(1) = 3 : atn(2) = 5 : atn(3) = 8 : atn(4) = 10 : atn(5) = 12 : atn(6) = 15 : atn(7) = 17
  atn(8) = 19 : atn(9) = 21 : atn(10) = 23 : atn(11) = 25 : atn(12) = 26 : atn(13) = 28 : atn(14) = 29
  atn(15) = 31 : atn(16) = 32
  tmp = Sines()
  Reset
End Sub

' Reset: no bullets, no shots, no boxes
Public Sub Reset()
#asm
            ld hl, {eb} + 8
            ld de, 10
            ld b, 60
rs_b:
            ld (hl), 255
            add hl, de
            djnz rs_b
            ld hl, {sh}
            ld b, 90
rs_s:
            ld (hl), 0
            inc hl
            djnz rs_s
            ld hl, {bx}
            ld b, 144
rs_x:
            ld (hl), 0
            inc hl
            djnz rs_x
            ld hl, {att}
            ld b, 78
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
            ld bc, 60 * 256
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
            ld b, 60
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

' Shot x, y, vx, vy: a player shot from x, y, flying vx across and vy down a frame (-20 .. 20)
Public Sub Shot(ByVal x As Integer, ByVal y As Integer, ByVal sx As Integer, ByVal sy As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (so_x + 1), a
            pop hl
            ld a, (hl)
            ld (so_y + 1), a
            pop hl
            ld a, (hl)
            ld (so_v + 1), a
            pop hl
            ld a, (hl)
            ld (so_w + 1), a
            ld hl, {sh} + 4
            ld de, 5
            ld b, 18
so_find:
            ld a, (hl)
            or a
            jr z, so_got
            add hl, de
            djnz so_find
            jr so_done
so_got:
            ld (hl), 1
            dec hl
so_w:
            ld (hl), 0
            dec hl
so_v:
            ld (hl), 0
            dec hl
so_y:
            ld (hl), 0
            dec hl
so_x:
            ld (hl), 0
so_done:
#endasm
End Sub

' Box n, x, y, hw, hh: target n (0-23) this frame, centred at x, y, hw across and hh down from
' the centre to its edges
Public Sub Box(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal hw As Integer, ByVal hh As Integer)
#asm
            pop hl
            ld a, (hl)
            ld l, a                 ; HL = bx + n * 6
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, {bx}
            add hl, de
            ld (hl), 1
            inc hl
            ex de, hl
            pop hl
            ld a, (hl)
            ld (de), a
            inc de
            pop hl
            ld a, (hl)
            ld (de), a
            inc de
            pop hl
            ld a, (hl)
            ld (de), a
            inc de
            pop hl
            ld a, (hl)
            ld (de), a
#endasm
End Sub

' Off n: target n gone (its hits kept until Hits reads them)
Public Sub Off(ByVal n As Integer)
#asm
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, {bx}
            add hl, de
            ld (hl), 0
#endasm
End Sub

' Hits(n): the shots that hit target n since the last Hits(n)
Public Function Hits(ByVal n As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, {bx} + 5
            add hl, de
            ld a, (hl)
            ld (hl), 0
            pop hl
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

' Step px, py, pan: every bullet and shot moved (the view moved pan pixels), checked, put in the
' sprites' table
Public Sub Step(ByVal px As Integer, ByVal py As Integer, ByVal pan As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (st_px + 1), a
            pop hl
            ld a, (hl)
            ld (st_py + 1), a
            pop hl
            ld a, (hl)
            ld (st_pan + 1), a
            ld (ss_pan + 1), a
            ld ({six}), ix
            xor a
            ld ({hitF}), a
            ld ({live}), a
            ld ({spk}), a
            ld ix, {eb}
            ld de, {att}
            ld a, 60
            ld ({cnt}), a
st_lp:
            ld a, (ix + 8)
            cp 255
            jp z, st_free
            ld c, a                 ; the pattern
            ld a, (ix + 0)          ; x += vx - pan
            add a, (ix + 4)
            ld (ix + 0), a
            ld a, (ix + 1)
            adc a, (ix + 5)
st_pan:
            sub 0
            ld (ix + 1), a
            cp 4
            jr c, st_kill
            cp 252
            jr nc, st_kill
            ld a, (ix + 2)          ; y += vy
            add a, (ix + 6)
            ld (ix + 2), a
            ld a, (ix + 3)
            adc a, (ix + 7)
            ld (ix + 3), a
            cp 20
            jr c, st_kill
            cp 188
            jr nc, st_kill
st_py:
            sub 0                   ; on the player: within 5 both ways
            add a, 5
            cp 11
            jr nc, st_nohit
            ld a, (ix + 1)
st_px:
            sub 0
            add a, 5
            cp 11
            jr nc, st_nohit
            ld a, 1
            ld ({hitF}), a
st_nohit:
            ld hl, {live}
            inc (hl)
            ld a, (ix + 1)          ; the sprite: x + 24 (9 bits), y + 24
            add a, 24
            ld (de), a
            inc de
            sbc a, a
            and 1
            ld b, a
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
            ; ---- the shots
            ld ix, {sh}
            ld a, 18
            ld ({cnt}), a
ss_lp:
            ld a, (ix + 4)
            or a
            jp z, ss_free
            ld a, (ix + 2)          ; x += vx - pan (it goes when it wraps or leaves)
ss_pan:
            sub 0
            ld c, a
            ld a, (ix + 0)
            add a, c
            ld (ix + 0), a
            bit 7, c
            jr nz, ss_neg
            jp c, ss_kill
            jr ss_chk
ss_neg:
            jp nc, ss_kill
ss_chk:
            cp 4
            jp c, ss_kill
            cp 252
            jp nc, ss_kill
            ld c, (ix + 3)          ; y += vy
            ld a, (ix + 1)
            add a, c
            ld (ix + 1), a
            bit 7, c
            jr nz, ss_negy
            jp c, ss_kill
            jr ss_chky
ss_negy:
            jp nc, ss_kill
ss_chky:
            cp 20
            jp c, ss_kill
            cp 188
            jp nc, ss_kill
            ld hl, {bx}             ; the targets
            ld b, 24
ss_box:
            ld a, (hl)
            or a
            jr z, ss_skip6
            inc hl
            ld a, (ix + 0)
            sub (hl)
            jr nc, ss_ax
            neg
ss_ax:
            inc hl
            inc hl
            cp (hl)
            jr nc, ss_skip3
            dec hl
            ld a, (ix + 1)
            sub (hl)
            jr nc, ss_ay
            neg
ss_ay:
            inc hl
            inc hl
            cp (hl)
            jr nc, ss_skip4
            inc hl
            inc (hl)                ; a hit
            jr nz, ss_hc
            dec (hl)
ss_hc:
            ld a, (ix + 0)
            ld ({spkX}), a
            ld a, (ix + 1)
            ld ({spkY}), a
            ld a, 1
            ld ({spk}), a
            jr ss_kill
ss_skip3:
            inc hl
            inc hl
            inc hl
            djnz ss_box
            jr ss_draw
ss_skip4:
            inc hl
            inc hl
            djnz ss_box
            jr ss_draw
ss_skip6:
            ld a, l
            add a, 6
            ld l, a
            jr nc, ss_nc
            inc h
ss_nc:
            djnz ss_box
ss_draw:
            ld a, (ix + 0)
            add a, 24
            ld (de), a
            inc de
            sbc a, a
            and 1
            ld b, a
            ld a, (ix + 1)
            add a, 24
            ld (de), a
            inc de
            ld a, (ix + 2)          ; flying left: mirrored; up or down: turned
            and #80
            rrca
            rrca
            rrca
            rrca
            or b
            ld b, a
            ld a, (ix + 3)
            or a
            ld a, b
            jr z, ss_flat
            or 2
ss_flat:
            ld (de), a
            inc de
            ld a, ({sa3})
            ld (de), a
            inc de
            ld a, ({sa4})
            ld (de), a
            inc de
            jr ss_next
ss_kill:
            ld (ix + 4), 0
ss_free:
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
ss_next:
            inc ix
            inc ix
            inc ix
            inc ix
            inc ix
            ld hl, {cnt}
            dec (hl)
            jp nz, ss_lp
            ld ix, ({six})
#endasm
End Sub

' Near(x, y): how many enemy bullets are within 7 pixels of x, y - they go (a gun hit)
Public Function Near(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            ld (nr_x + 1), a
            pop hl
            ld a, (hl)
            ld (nr_y + 1), a
            ld ({six}), ix
            ld ix, {eb}
            ld b, 60
            ld c, 0
nr_lp:
            ld a, (ix + 8)
            cp 255
            jr z, nr_next
            ld a, (ix + 1)
nr_x:
            sub 0
            add a, 7
            cp 15
            jr nc, nr_next
            ld a, (ix + 3)
nr_y:
            sub 0
            add a, 7
            cp 15
            jr nc, nr_next
            ld (ix + 8), 255
            inc c
nr_next:
            ld de, 10
            add ix, de
            djnz nr_lp
            ld ix, ({six})
            pop hl
            ld (hl), c
            inc hl
            ld (hl), 0
#endasm
End Function

' Show: the table to sprites 50-127 (straight after Frame)
Public Sub Show()
#asm
            ld bc, #303B
            ld a, 50
            out (c), a
            ld hl, {att}
            ld bc, 195 * 256 + #57
            otir
            ld b, 195
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

' Sparked(): True when a shot hit something in the last Step (SparkX / SparkY: the last one)
Public Function Sparked() As Integer
  Sparked = spk
End Function

Public Function SparkX() As Integer
  SparkX = spkX
End Function

Public Function SparkY() As Integer
  SparkY = spkY
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
