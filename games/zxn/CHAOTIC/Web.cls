' Web - CHAOTIC's Layer 2: the web's lines and the particles, in Z80.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Layer 2 is 256 x 192, one byte a pixel, bank 16 (8K pages 32-37, 32 lines each), put in at
' #C000 through MMU slot 6 while drawing, then bank 5's page 10 back (the tilemap's tiles live
' there). One screen, not two: the web is drawn once a level, so nothing needs clearing each frame.
' The pixels are colour numbers into Layer 2's palette (Main sets it): 0 is see-through (the
' copper's background shows), the web's lines are numbered by lane so Main can light a lane
' up just by changing its colours.
'
' The particles: up to 160 blocks of 2 x 2 pixels (on even x and y, so a block never crosses a
' page), each 32 bytes in pt():
'   0-1 x (1/256ths of a pixel, the pixel in byte 1), 2-3 y, 4-5 x speed, 6-7 y speed (signed,
'   1/256ths of a pixel a frame), 8 life (frames left, 0 = free), 9 its colour ramp (the first of
'   8 palette numbers, brightest first), 10-13 the 4 pixels it covers (top left, top right, bottom
'   left, bottom right), 14-15 the top left's address, 16 its page (0 = covering nothing),
'   17 1 = speeding up (the warp), 18-31 spare.
' Each frame Step first puts back what every particle covered (last to first, so dots on top of
' each other come off in the right order), then moves them all and draws them again, saving
' what's under each. So they fly over the web without spoiling it.
Option Explicit

Const NP = 160
Private pt(5119) As Byte
Private six As Integer, cnt As Integer, rnd As Integer, nxt As Integer, tmp As Integer
Private bx As Integer, by As Integer, bn As Integer, br As Integer, bs As Integer, bm As Integer, bl As Integer
Private ba As Integer, bst As Integer, nlive As Integer

' Init: no particles, the screen cleared
Public Sub Init()
  rnd = 12345
  Kill
  Clear
End Sub

' Clear: the whole screen colour 0 (two frames' work: do it between levels)
Public Sub Clear()
#asm
            ld a, 32
            ld ({tmp}), a
cl_pg:
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, ({tmp})
            out (c), a
            ld hl, #C000
            ld (hl), 0
            ld de, #C001
            ld bc, 8191
            ldir
            ld hl, {tmp}
            inc (hl)
            ld a, (hl)
            cp 38
            jr nz, cl_pg
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
#endasm
End Sub

' Kill: every particle gone (without putting back what they covered: after a Clear)
Public Sub Kill()
#asm
            ld hl, {pt}
            ld de, {pt} + 1
            ld (hl), 0
            ld bc, 5119
            ldir
            xor a
            ld ({nlive}), a
#endasm
End Sub

' Line x0, y0, x1, y1, c: a line in colour c (all on the screen: 0-255, 0-191)
Public Sub Line(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer, ByVal c As Integer)
#asm
            pop hl
            ld e, (hl)              ; x0
            pop hl
            ld d, (hl)              ; y0
            pop hl
            ld a, (hl)
            ld (ln_x1 + 1), a
            pop hl
            ld a, (hl)
            ld (ln_y1 + 1), a
            pop hl
            ld a, (hl)
            ld (ln_c1 + 1), a
            ld (ln_c2 + 1), a
            ld bc, #243B
            ld a, #56
            out (c), a
            ; dx, sx
ln_x1:
            ld a, 0
            sub e
            ld c, 1
            jr nc, ln_dxp
            neg
            ld c, 255
ln_dxp:
            ld (ln_dx1 + 1), a
            ld (ln_dx2 + 1), a
            ld (ln_dxa + 1), a
            ld a, c
            ld (ln_sx1 + 1), a
            ld (ln_sx2 + 1), a
            ; dy, sy
ln_y1:
            ld a, 0
            sub d
            ld c, 1
            jr nc, ln_dyp
            neg
            ld c, 255
ln_dyp:
            ld (ln_dy1 + 1), a
            ld (ln_dy2 + 1), a
            ld (ln_dyb + 1), a
            ld a, c
            ld (ln_sy1 + 1), a
            ld (ln_sy2 + 1), a
ln_dyb:
            ld c, 0                 ; dy
ln_dxa:
            ld a, 0                 ; dx
            cp c
            jp c, ln_ymaj
            ; ---- along x: dx + 1 pixels
            inc a
            ld ({cnt}), a
            ld a, (ln_dx1 + 1)
            srl a
            ld ({tmp}), a           ; err
lx_lp:
            ld a, d
            rlca
            rlca
            rlca
            and 7
            add a, 32
            ld bc, #253B
            out (c), a
            ld a, d
            and 31
            or #C0
            ld h, a
            ld l, e
ln_c1:
            ld (hl), 0
            ld a, e
ln_sx1:
            add a, 1
            ld e, a
            ld a, ({tmp})
ln_dy1:
            sub 0
            jr nc, lx_ok
ln_dx1:
            add a, 0
            ld ({tmp}), a
            ld a, d
ln_sy1:
            add a, 1
            ld d, a
            jr lx_nx
lx_ok:
            ld ({tmp}), a
lx_nx:
            ld hl, {cnt}
            dec (hl)
            jr nz, lx_lp
            jp ln_done
ln_ymaj:
            ; ---- along y: dy + 1 pixels
            ld a, c
            inc a
            ld ({cnt}), a
            ld a, c
            srl a
            ld ({tmp}), a
ly_lp:
            ld a, d
            rlca
            rlca
            rlca
            and 7
            add a, 32
            ld bc, #253B
            out (c), a
            ld a, d
            and 31
            or #C0
            ld h, a
            ld l, e
ln_c2:
            ld (hl), 0
            ld a, d
ln_sy2:
            add a, 1
            ld d, a
            ld a, ({tmp})
ln_dx2:
            sub 0
            jr nc, ly_ok
ln_dy2:
            add a, 0
            ld ({tmp}), a
            ld a, e
ln_sx2:
            add a, 1
            ld e, a
            jr ly_nx
ly_ok:
            ld ({tmp}), a
ly_nx:
            ld hl, {cnt}
            dec (hl)
            jr nz, ly_lp
ln_done:
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
#endasm
End Sub

' Burst x, y, n, ramp, spd, mode, life: n particles from x, y (pixels). ramp: the palette
' number of their brightest colour (8 in a row, fading). spd: how fast (1-64: 64 is 4 pixels a
' frame at most). mode: 0 any way at any speed up to spd, 1 a ring (evenly round, all at spd),
' 2 speeding up (the warp's stars), 3 both. life: about how many frames they last (+ up to 15);
' they're brightest until their last 32 frames, then fade through the ramp.
Public Sub Burst(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer, ByVal ramp As Integer, ByVal spd As Integer, ByVal mode As Integer, ByVal life As Integer)
  If n < 1 Then Exit Sub
  bx = x : by = y : bn = n : br = ramp : bs = spd : bm = mode : bl = life
  bst = 256 \ n
  ba = Rnd(256)
  Spawn
End Sub

Private Sub Spawn()
#asm
            ld ({six}), ix
bu_lp:
            ; a free one, from where the last search stopped
            ld a, 160
            ld ({cnt}), a
bu_find:
            ld a, ({nxt})
            inc a
            cp 160
            jr c, bu_n1
            xor a
bu_n1:
            ld ({nxt}), a
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ex de, hl
            ld ix, {pt}
            add ix, de
            ld a, (ix + 8)
            or a
            jr z, bu_got
            ld hl, {cnt}
            dec (hl)
            jr nz, bu_find
            jp bu_done
bu_got:
            ; the random number (xorshift)
            ld hl, ({rnd})
            ld a, h
            rra
            ld a, l
            rra
            xor h
            ld h, a
            ld a, l
            rra
            ld a, h
            rra
            xor l
            ld l, a
            xor h
            ld h, a
            ld ({rnd}), hl
            ; the speed: spd (a ring) or random up to spd
            ld a, ({bm})
            and 1
            ld a, ({bs})
            jr nz, bu_sp
            ld d, a
            ld e, l
bu_zm0:
            db #ED, #30             ; mul d, e
            ld a, d
            inc a
bu_sp:
            ld (bu_s1 + 1), a
            ld (bu_s2 + 1), a
            ; the way: random, or the ring's next
            ld a, ({bm})
            and 1
            jr z, bu_rw
            ld a, ({ba})
            ld c, a
            ld a, ({bst})
            add a, c
            ld ({ba}), a
            ld a, c
            jr bu_wy
bu_rw:
            ld a, h
bu_wy:
            ld ({tmp}), a
            ; vx = sin(a) * s / 8
            ld hl, fn_bul_sines_sn_data
            add a, l
            ld l, a
            jr nc, bu_h1
            inc h
bu_h1:
            ld a, (hl)
            ld c, a
            bit 7, a
            jr z, bu_p1
            neg
bu_p1:
            ld d, a
bu_s1:
            ld e, 0
bu_zm1:
            db #ED, #30
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            bit 7, c
            jr z, bu_v1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
bu_v1:
            ld (ix + 4), e
            ld (ix + 5), d
            ld a, ({tmp})           ; vy = sin(a + 64) * s / 8
            add a, 64
            ld hl, fn_bul_sines_sn_data
            add a, l
            ld l, a
            jr nc, bu_h2
            inc h
bu_h2:
            ld a, (hl)
            ld c, a
            bit 7, a
            jr z, bu_p2
            neg
bu_p2:
            ld d, a
bu_s2:
            ld e, 0
bu_zm2:
            db #ED, #30
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            bit 7, c
            jr z, bu_v2
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
bu_v2:
            ld (ix + 6), e
            ld (ix + 7), d
            ld (ix + 0), 128
            ld a, ({bx})
            ld (ix + 1), a
            ld (ix + 2), 128
            ld a, ({by})
            ld (ix + 3), a
            ld a, ({rnd})
            and 15
            ld c, a
            ld a, ({bl})
            add a, c
            jr nz, bu_lf
            inc a
bu_lf:
            ld (ix + 8), a
            ld a, ({br})
            ld (ix + 9), a
            ld (ix + 16), 0
            ld a, ({bm})
            srl a
            and 1
            ld (ix + 17), a
            ld hl, {bn}
            dec (hl)
            jp nz, bu_lp
bu_done:
            ld ix, ({six})
#endasm
End Sub

' Step: every particle: what it covered put back, moved, drawn again (once a frame)
Public Sub Step()
#asm
            ld ({six}), ix
            ld bc, #243B
            ld a, #56
            out (c), a
            ; ---- put back what they covered, the last first
            ld ix, {pt} + 5088
            ld a, 160
            ld ({cnt}), a
            ld de, -32
ps_un:
            ld a, (ix + 16)
            or a
            jr z, ps_un_n
            ld bc, #253B
            out (c), a
            ld l, (ix + 14)
            ld h, (ix + 15)
            ld a, (ix + 10)
            ld (hl), a
            inc l
            ld a, (ix + 11)
            ld (hl), a
            inc h
            ld a, (ix + 13)
            ld (hl), a
            dec l
            ld a, (ix + 12)
            ld (hl), a
            ld (ix + 16), 0
ps_un_n:
            add ix, de
            ld hl, {cnt}
            dec (hl)
            jr nz, ps_un
            ; ---- move and draw, the first first
            ld ix, {pt}
            ld a, 160
            ld ({cnt}), a
            xor a
            ld ({nlive}), a
ps_lp:
            ld a, (ix + 8)
            or a
            jp z, ps_next
            dec a
            ld (ix + 8), a
            jp z, ps_next
            ld a, (ix + 17)
            or a
            jr z, ps_mv
            ; speeding up: v += v / 16
            ld l, (ix + 4)
            ld h, (ix + 5)
            ld e, l
            ld d, h
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            add hl, de
            ld (ix + 4), l
            ld (ix + 5), h
            ld l, (ix + 6)
            ld h, (ix + 7)
            ld e, l
            ld d, h
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            add hl, de
            ld (ix + 6), l
            ld (ix + 7), h
ps_mv:
            ld a, (ix + 0)
            add a, (ix + 4)
            ld (ix + 0), a
            ld a, (ix + 1)
            adc a, (ix + 5)
            ld (ix + 1), a
            cp 4
            jp c, ps_kill
            cp 252
            jp nc, ps_kill
            and #FE                 ; 2 x 2 blocks: x and y even
            ld e, a
            ld a, (ix + 2)
            add a, (ix + 6)
            ld (ix + 2), a
            ld a, (ix + 3)
            adc a, (ix + 7)
            ld (ix + 3), a
            cp 190
            jp nc, ps_kill
            and #FE
            ld d, a
            ld a, d
            and 31
            or #C0
            ld h, a
            ld l, e                 ; HL = #C000 + (y And 31) * 256 + x
            ld (ix + 14), l
            ld (ix + 15), h
            ld a, d
            rlca
            rlca
            rlca
            and 7
            add a, 32               ; the page: 32 + y / 32
            ld (ix + 16), a
            ld bc, #253B
            out (c), a
            ; the colour: the ramp's brightest while life >= 32, then a step darker each 4
            ld a, (ix + 8)
            cp 32
            jr c, ps_f
            xor a
            jr ps_c7
ps_f:
            neg
            add a, 32
            srl a
            srl a
ps_c7:
            add a, (ix + 9)
            ld d, a
            ld a, (hl)
            ld (ix + 10), a
            ld (hl), d
            inc l
            ld a, (hl)
            ld (ix + 11), a
            ld (hl), d
            inc h
            ld a, (hl)
            ld (ix + 13), a
            ld (hl), d
            dec l
            ld a, (hl)
            ld (ix + 12), a
            ld (hl), d
            ld hl, {nlive}
            inc (hl)
            jr ps_next
ps_kill:
            ld (ix + 8), 0
ps_next:
            ld de, 32
            add ix, de
            ld hl, {cnt}
            dec (hl)
            jp nz, ps_lp
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ld ix, ({six})
#endasm
End Sub

' Live(): how many particles are flying
Public Function Live() As Integer
  Live = nlive And 255
End Function
