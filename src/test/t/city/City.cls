' City: a wireframe city to fly through - Freescape-style lines, no filled faces, no hidden
' line removal. 64 x 64 cells of 256 units (16384 x 16384, repeating for ever): streets on
' every 4th row and column, buildings of 1-7 storeys (72 units each), taller in the middle,
' two footprint sizes, a few empty lots. About 2000 units are seen ahead.
' The camera moves and turns in all directions (right / up / forward vectors, 2.14 fixed
' point, kept square and of length 1 every frame). Render does the frame: the turns and the
' move asked for with Steer, then every building in view as 12 lines (clipped against the
' near plane and the four sides of the view, so lines into the screen edge and past the
' camera are cut, not dropped), drawn with the Graphics class on the screen not shown.
' All the work is Z80 (#asm). The map and the tables are at #8000-#93FF (Option Reserve).
' Platforms: cpc, cpcmin, cpcfw (the Graphics class).
Option Explicit
Private bas(8) As Integer                     ' right (0-2), up (3-5), forward (6-8): 16384 = 1.0
Private qx As Long, qy As Long, qz As Long    ' where the camera is: world units * 16384
Private camx As Integer, camy As Integer, camz As Integer
Private rp As Integer, rr As Integer, ry As Integer, spd As Integer
Private sps As Integer
Private Const COLT = &H9000         ' 17 columns x 4 edges: camera X, Y, Z of each edge's x
Private Const ROWT = &H9198         ' 17 rows x 4 edges: ... of each edge's z
Private Const HGTT = &H9330         ' 9 heights: ... of each height's y
Private Const VTX = &H9366          ' a building's 8 corners: X Y Z, outcode, -, sx, sy

' Init: the map made, the camera in an avenue near the middle, looking along it
Public Sub Init()
  bas(0) = 16384 : bas(4) = 16384 : bas(8) = 16384
  qx = CLng(8320) * 16384
  qy = CLng(150) * 16384
  qz = CLng(6000) * 16384
  MakeMap
End Sub

' Steer pitch, roll, yaw, speed: for the next Render. pitch 1 = climb, -1 = dive; roll 1 =
' right wing down; yaw 1 = right (each 2 degrees a frame, 0 = none); speed in units a frame
Public Sub Steer(ByVal pitch As Integer, ByVal roll As Integer, ByVal yaw As Integer, ByVal speed As Integer)
  rp = pitch : rr = roll : ry = yaw : spd = speed
End Sub

Public Function Altitude() As Integer
  Altitude = camy
End Function

' Buildings(): how many cells of the map have a building (after Init)
Public Function Buildings() As Integer
#asm
            ld hl, #8000
            ld de, 0
            ld bc, 4096
bd_lp:
            ld a, (hl)
            and 7
            jr z, bd_n
            inc de
bd_n:
            inc hl
            dec bc
            ld a, b
            or c
            jr nz, bd_lp
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' ProgramEnd(): the first byte after the program and its variables
Public Function ProgramEnd() As Integer
#asm
            pop hl
            ld de, ntc_free
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' the map: a byte a cell at #8000 (z * 64 + x): bits 0-2 storeys (0 = none), bit 3 the
' narrow footprint
Private Sub MakeMap()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, #8000
            ld c, 0                 ; z
mm_z:
            ld b, 0                 ; x
mm_x:
            ld (hl), 0
            ld a, b
            and 3
            jr z, mm_nx             ; a street: every 4th column
            ld a, c
            and 3
            jr z, mm_nx             ; and row
            push hl
            push bc
            call mm_rnd
            ld a, l
            and 15
            cp 2
            jr c, mm_park           ; an empty lot
            ld a, l
            rrca
            rrca
            rrca
            rrca
            and 3
            inc a
            ld e, a                 ; 1-4 storeys
            ld a, l
            and #40
            rrca
            rrca
            rrca
            ld d, a                 ; bit 3: narrow
            pop bc
            push bc
            ld a, b                 ; taller near the middle (32, 32)
            sub 32
            jr nc, mm_d1
            neg
mm_d1:
            ld h, a
            ld a, c
            sub 32
            jr nc, mm_d2
            neg
mm_d2:
            cp h
            jr nc, mm_d3
            ld a, h
mm_d3:
            cp 6
            jr nc, mm_d4
            inc e
mm_d4:
            cp 12
            jr nc, mm_d5
            inc e
mm_d5:
            cp 20
            jr nc, mm_d6
            inc e
mm_d6:
            ld a, e
            cp 8
            jr c, mm_d7
            ld a, 7
mm_d7:
            or d
            pop bc
            pop hl
            ld (hl), a
            jr mm_nx
mm_park:
            pop bc
            pop hl
mm_nx:
            inc hl
            inc b
            ld a, b
            cp 64
            jr nz, mm_x
            inc c
            ld a, c
            cp 64
            jr nz, mm_z
            ld sp, ({sps})
            ret
; mm_rnd - HL = the next number of a 16 bit xorshift
mm_rnd:
            ld hl, (mm_seed)
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
            ld (mm_seed), hl
            ret
mm_seed:    dw 12345
#endasm
End Sub

' Render: turn, move, then the city drawn on the screen not shown (Graphics.Flip shows it)
Public Sub Render()
#asm
; the small helpers written in where they are used (no call / ret, no labels: $ jumps)
; CMPS: carry when HL < DE, signed (HL, A lost)
  MACRO CMPS
            ld a, h
            xor d                   ; (clears carry)
            jp p, $ + 7             ; same signs: HL - DE
            ld a, h
            rla                     ; signs differ: carry = HL negative
            jr $ + 4
            sbc hl, de
  ENDM
; HNEG: HL = -HL (A lost)
  MACRO HNEG
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
  ENDM
; HABS: HL = |HL| (A lost)
  MACRO HABS
            bit 7, h
            jr z, $ + 8
            HNEG
  ENDM
; UCAP: HL = the smaller of HL and DE, unsigned
  MACRO UCAP
            or a
            sbc hl, de
            add hl, de
            jr c, $ + 4
            ld h, d
            ld l, e
  ENDM
; X6: HL = A * 6 (DE lost)
  MACRO X6
            ld l, a
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
  ENDM
; MIDC o: HL = half the sum at offset o of IX's, IX + 6's, IY's, IY + 6's, HGTT's numbers and
; BC's (BC moves on 2)
  MACRO MIDC o
            ld l, (ix + o)
            ld h, (ix + o + 1)
            ld e, (ix + o + 6)
            ld d, (ix + o + 7)
            add hl, de
            ld e, (iy + o)
            ld d, (iy + o + 1)
            add hl, de
            ld e, (iy + o + 6)
            ld d, (iy + o + 7)
            add hl, de
            ld de, ({HGTT} + o)
            add hl, de
            ld a, (bc)
            ld e, a
            inc bc
            ld a, (bc)
            ld d, a
            inc bc
            add hl, de
            sra h
            rr l
  ENDM
; VSUM o: HL = IY's number at o + DE's + BC's (DE, BC move on 2)
  MACRO VSUM o
            ld l, (iy + o)
            ld h, (iy + o + 1)
            ld a, (de)
            add a, l
            ld l, a
            inc de
            ld a, (de)
            adc a, h
            ld h, a
            inc de
            ld a, (bc)
            add a, l
            ld l, a
            inc bc
            ld a, (bc)
            adc a, h
            ld h, a
            inc bc
  ENDM
; PJDIV: L = C:HL / DE, H = 0 (the quotient is under 256: C:HL < DE * 256; DE < 32768). Eight
; steps, unrolled; the quotient's bits go into C inverted (carry = a borrow), turned at the end
  MACRO PJDIVSTEP
            sla b
            adc hl, hl              ; (no carry out: HL < DE < 32768)
            sbc hl, de
            jr nc, $ + 3
            add hl, de              ; (carry: the borrow put back, carry stays set)
            rl c
  ENDM
  MACRO PJDIV
            ld b, l
            ld l, h
            ld h, c
            PJDIVSTEP
            PJDIVSTEP
            PJDIVSTEP
            PJDIVSTEP
            PJDIVSTEP
            PJDIVSTEP
            PJDIVSTEP
            PJDIVSTEP
            ld a, c
            cpl
            ld l, a
            ld h, 0
  ENDM
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ei                      ; interrupts in while it works (the real stack): the
                                    ; clock keeps counting, in turbo too
            call r_turn
            call r_tidy
            call r_fly
            call r_terms
            call r_clear
            call r_cells
            di
            ld sp, ({sps})
            ret

; ---- the camera

; r_turn - the turns asked for (rp, rr, ry: -1, 0, 1), 2 degrees each
r_turn:
            ld a, ({rp})
            or a
            jr z, rt_r
            ld ix, {bas} + 12       ; climb: forward towards up
            ld iy, {bas} + 6
            call rt_s
            call r_pair
rt_r:
            ld a, ({rr})
            or a
            jr z, rt_y
            ld ix, {bas} + 6        ; roll right: up towards right
            ld iy, {bas}
            call rt_s
            call r_pair
rt_y:
            ld a, ({ry})
            or a
            ret z
            ld ix, {bas} + 12       ; yaw right: forward towards right
            ld iy, {bas}
            call rt_s
            jp r_pair
rt_s:
            ld hl, 572              ; sin 2 degrees
            bit 7, a
            jr z, rt_s1
            ld hl, -572
rt_s1:
            ld (w_rs), hl
            ret
; r_pair - IX = A, IY = B (vectors): A = A cos + B sin, B = B cos - A sin
r_pair:
            ld b, 3
rp_lp:
            push bc
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld (w_a), de
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld (w_b), de
            ld de, (w_a)
            ld bc, 16374            ; cos 2 degrees
            call mulfix
            ld (w_t), hl
            ld de, (w_b)
            ld bc, (w_rs)
            call mulfix
            ld de, (w_t)
            add hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            ld de, (w_b)
            ld bc, 16374
            call mulfix
            ld (w_t), hl
            ld de, (w_a)
            ld bc, (w_rs)
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld (iy + 0), l
            ld (iy + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz rp_lp
            ret

; r_tidy - forward of length 1, right square to it and of length 1, up = forward x right
r_tidy:
            ld ix, {bas} + 12
            call r_unit
            ld ix, {bas}
            ld iy, {bas} + 12
            call r_dot
            ld (w_t), hl            ; right . forward
            ld b, 3
td_lp:
            push bc
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (w_t)
            call mulfix
            ex de, hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            or a
            sbc hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz td_lp
            ld ix, {bas}
            call r_unit
            ld de, ({bas} + 14)     ; up x = Fy Rz - Fz Ry
            ld bc, ({bas} + 4)
            call mulfix
            ld (w_t), hl
            ld de, ({bas} + 16)
            ld bc, ({bas} + 2)
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld ({bas} + 6), hl
            ld de, ({bas} + 16)     ; up y = Fz Rx - Fx Rz
            ld bc, ({bas})
            call mulfix
            ld (w_t), hl
            ld de, ({bas} + 12)
            ld bc, ({bas} + 4)
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld ({bas} + 8), hl
            ld de, ({bas} + 12)     ; up z = Fx Ry - Fy Rx
            ld bc, ({bas} + 2)
            call mulfix
            ld (w_t), hl
            ld de, ({bas} + 14)
            ld bc, ({bas})
            call mulfix
            ex de, hl
            ld hl, (w_t)
            or a
            sbc hl, de
            ld ({bas} + 10), hl
            ret
; r_dot - HL = (IX) . (IY), vectors of 3
r_dot:
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld c, (iy + 0)
            ld b, (iy + 1)
            call mulfix
            ld (w_d), hl
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld c, (iy + 2)
            ld b, (iy + 3)
            call mulfix
            ld de, (w_d)
            add hl, de
            ld (w_d), hl
            ld e, (ix + 4)
            ld d, (ix + 5)
            ld c, (iy + 4)
            ld b, (iy + 5)
            call mulfix
            ld de, (w_d)
            add hl, de
            ret
; r_unit - (IX) scaled to length 1: times (3 - |v|^2) / 2 (close to 1 already)
r_unit:
            push ix
            pop iy
            call r_dot
            sra h
            rr l
            ex de, hl
            ld hl, 24576
            or a
            sbc hl, de
            ld (w_k), hl
            ld b, 3
ru_lp:
            push bc
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld bc, (w_k)
            call mulfix
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            pop bc
            djnz ru_lp
            ret

; r_fly - the camera moved forward by spd; x, z wrap round the world, y kept 16 - 3000
r_fly:
            ld ix, {qx}
            ld de, ({bas} + 12)
            call fl_add
            ld ix, {qy}
            ld de, ({bas} + 14)
            call fl_add
            ld ix, {qz}
            ld de, ({bas} + 16)
            call fl_add
            ld a, ({qx} + 3)
            and #0F
            ld ({qx} + 3), a
            ld a, ({qz} + 3)
            and #0F
            ld ({qz} + 3), a
            ld hl, ({qy} + 2)       ; y / 4
            ld de, 4
            CMPS
            jr nc, fl_y1
            ld hl, 0
            ld ({qy}), hl
            ld hl, 4
            ld ({qy} + 2), hl
fl_y1:
            ld hl, ({qy} + 2)
            ld de, 750
            CMPS
            jr c, fl_y2
            ld hl, 0
            ld ({qy}), hl
            ld hl, 750
            ld ({qy} + 2), hl
fl_y2:
            ld ix, {qx}
            call fl_w
            ld ({camx}), de
            ld ix, {qy}
            call fl_w
            ld ({camy}), de
            ld ix, {qz}
            call fl_w
            ld ({camz}), de
            ret
; fl_add - (IX), a Long, + DE * spd
fl_add:
            ld bc, ({spd})
            call mul16s
            ld a, (ix + 0)
            add a, l
            ld (ix + 0), a
            ld a, (ix + 1)
            adc a, h
            ld (ix + 1), a
            ld a, (ix + 2)
            adc a, e
            ld (ix + 2), a
            ld a, (ix + 3)
            adc a, d
            ld (ix + 3), a
            ret
; fl_w - DE = (IX), a Long, / 16384
fl_w:
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ret

; ---- the frame's tables: each column's / row's edges and each height, in camera space
; (a building's corner is then three additions)

r_terms:
            ld a, ({camx} + 1)
            ld (w_cbx), a
            ld a, ({camz} + 1)
            ld (w_cbz), a
            ld ix, {COLT}
            ld iy, {bas}            ; x: R.x U.x F.x
            ld a, ({camx})
            call tm_axis
            ld ix, {ROWT}
            ld iy, {bas} + 4        ; z: R.z U.z F.z
            ld a, ({camz})
            call tm_axis
            ld ix, {HGTT}
            ld iy, {bas} + 2        ; y: R.y U.y F.y
            ld hl, ({camy})
            HNEG
            ld b, 9
tm_h:
            push bc
            push hl
            call tm_vec
            pop hl
            ld de, 72               ; a storey
            add hl, de
            pop bc
            djnz tm_h
            ret
; tm_axis - A = the camera's place in its cell: 17 cells from 8 before, 4 edges each
; (40, 216: wide; 72, 184: narrow)
tm_axis:
            ld e, a
            ld d, 0
            ld hl, -8 * 256
            or a
            sbc hl, de
            ld b, 17
ta_lp:
            push bc
            push hl
            ld de, 40
            add hl, de
            call tm_vec
            pop hl
            push hl
            ld de, 216
            add hl, de
            call tm_vec
            pop hl
            push hl
            ld de, 72
            add hl, de
            call tm_vec
            pop hl
            push hl
            ld de, 184
            add hl, de
            call tm_vec
            pop hl
            inc h
            pop bc
            djnz ta_lp
            ret
; tm_vec - (IX) = HL times the basis numbers at IY, IY + 6, IY + 12; IX + 6
tm_vec:
            ld (w_d), hl
            ex de, hl
            ld c, (iy + 0)
            ld b, (iy + 1)
            call mulfix
            ld (ix + 0), l
            ld (ix + 1), h
            ld de, (w_d)
            ld c, (iy + 6)
            ld b, (iy + 7)
            call mulfix
            ld (ix + 2), l
            ld (ix + 3), h
            ld de, (w_d)
            ld c, (iy + 12)
            ld b, (iy + 13)
            call mulfix
            ld (ix + 4), l
            ld (ix + 5), h
            ld de, 6
            add ix, de
            ret

; r_clear - rows 1-24 of the screen being drawn on cleared (row 0 is the text line)
r_clear:
            di                      ; SP goes through the screen: no interrupts meanwhile
            call gfx_begin
            ld (w_csp), sp
            ld a, (gfx_base)
            add a, #3F
            ld h, a
            ld l, #D0               ; the end of the last 2K block's 25 rows
            ld c, 8
cl_blk:
            ld (w_crp), hl
            ld sp, (w_crp)
            ld de, 0
            ld b, 60                ; 60 x 32 bytes = 1920: rows 1-24
cl_lp:
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            push de
            djnz cl_lp
            ld a, h
            sub 8
            ld h, a
            dec c
            jr nz, cl_blk
            ld sp, (w_csp)
            call gfx_end
            ei
            ret

; ---- the buildings

r_cells:
            xor a
            ld (w_cj), a
ce_row:
            xor a
            ld (w_ci), a
ce_col:
            call ce_one
            ld a, (w_ci)
            inc a
            ld (w_ci), a
            cp 17
            jr nz, ce_col
            ld a, (w_cj)
            inc a
            ld (w_cj), a
            cp 17
            jr nz, ce_row
            ret
; ce_one - the cell (w_ci, w_cj) of the 17 x 17 round the camera
ce_one:
            ld a, (w_cj)
            ld hl, w_cbz
            add a, (hl)
            sub 8
            and 63
            rrca
            rrca
            ld c, a
            and #C0
            ld l, a
            ld a, c
            and #0F
            or #80                  ; CMAP + row * 64
            ld h, a
            ld a, (w_ci)
            ld de, w_cbx
            ex de, hl
            add a, (hl)
            ex de, hl
            sub 8
            and 63
            or l
            ld l, a
            ld a, (hl)
            and 7
            ret z                   ; no building
            ld (w_lvl), a
            ld a, (hl)
            and 8
            rrca
            rrca
            ld (w_var), a           ; 0 wide, 2 narrow
            ld a, (w_ci)            ; the tables' entries for its edges
            add a, a
            add a, a
            ld hl, w_var
            add a, (hl)
            X6
            ld de, {COLT}
            add hl, de
            ld (w_px0), hl
            ld de, 6
            add hl, de
            ld (w_px1), hl
            ld a, (w_cj)
            add a, a
            add a, a
            ld hl, w_var
            add a, (hl)
            X6
            ld de, {ROWT}
            add hl, de
            ld (w_pz0), hl
            ld de, 6
            add hl, de
            ld (w_pz1), hl
            ld a, (w_lvl)
            X6
            ld de, {HGTT}
            add hl, de
            ld (w_phl), hl
            ld ix, (w_px0)          ; its middle, to see if it is in view: half the sum of the
            ld iy, (w_pz0)          ; six tables' numbers (X1 = X0 + 6, Z1 = Z0 + 6)
            ld bc, (w_phl)
            MIDC 0
            ld (w_cx), hl
            MIDC 2
            ld (w_cy), hl
            MIDC 4
            ld (w_cz), hl
            ld de, -310             ; behind
            CMPS
            ret c
            ld hl, (w_cz)
            ld de, 2048 + 310       ; too far
            CMPS
            ret nc
            ld hl, (w_cx)           ; off to the side: |X| - Z > 310 * 1.41
            HABS
            ld de, (w_cz)
            or a
            sbc hl, de
            ld de, 438
            CMPS
            ret nc
            ld hl, (w_cy)           ; above / below: 4|Y| - 3Z > 310 * 5
            HABS
            add hl, hl
            add hl, hl
            push hl
            ld hl, (w_cz)
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ex de, hl
            pop hl
            or a
            sbc hl, de
            ld de, 1550
            CMPS
            ret nc
            ld ix, {VTX}              ; its 8 corners
            xor a
            ld (w_vk), a
ve_lp:
            ld a, (w_vk)            ; the corner's three table entries: IY (x), DE (z), BC (height)
            ld iy, (w_px0)
            rrca
            jr nc, ve1
            ld iy, (w_px1)
ve1:
            ld de, (w_pz0)
            rrca
            jr nc, ve2
            ld de, (w_pz1)
ve2:
            ld bc, {HGTT}
            rrca
            jr nc, ve3
            ld bc, (w_phl)
ve3:
            VSUM 0                  ; X, Y, Z: the three entries added
            ld (ix + 0), l
            ld (ix + 1), h
            VSUM 2
            ld (ix + 2), l
            ld (ix + 3), h
            VSUM 4
            ld (ix + 4), l
            ld (ix + 5), h
            ; its outcode (HL = Z), into B a bit at a time from bit 4: 4 below (-4Y > 3Z),
            ; 3 above (4Y > 3Z), 2 left (-X > Z), 1 right (X > Z), 0 nearer than 16
            ld b, 0
            push hl                 ; Z (for bits 0, 1, 2)
            push hl
            push hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            push hl
            pop iy                  ; IY = 3Z
            ld l, (ix + 2)
            ld h, (ix + 3)
            add hl, hl
            add hl, hl
            push hl                 ; 4Y
            HNEG
            ex de, hl               ; DE = -4Y
            push iy
            pop hl
            CMPS                    ; 3Z < -4Y
            rl b
            pop de                  ; DE = 4Y
            push iy
            pop hl
            CMPS                    ; 3Z < 4Y
            rl b
            ld l, (ix + 0)
            ld h, (ix + 1)
            HNEG
            ex de, hl               ; DE = -X
            pop hl
            CMPS                    ; Z < -X
            rl b
            ld e, (ix + 0)
            ld d, (ix + 1)
            pop hl
            CMPS                    ; Z < X
            rl b
            ld de, 16
            pop hl
            CMPS                    ; Z < 16
            rl b
            ld (ix + 6), b
            ld a, b
            or a
            call z, ve_proj
            ld de, 12
            add ix, de
            ld a, (w_vk)
            inc a
            ld (w_vk), a
            cp 8
            jp nz, ve_lp
            ld hl, ce_edges         ; its 12 edges: the two corners' addresses
            ld b, 12
ed_lp:
            push bc
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push de
            pop ix
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push de
            pop iy
            push hl
            call ed_one
            pop hl
            pop bc
            djnz ed_lp
            ret
; ve_proj - the corner at IX onto the screen: sx = 160 + X * 160 / Z (0-319),
; sy = 100 - Y * 133 / Z (0-199), at IX + 8, IX + 10. Z (at least 1) and the signs on the stack
ve_proj:
            ld l, (ix + 4)
            ld h, (ix + 5)
            bit 7, h
            jr nz, pj_z1
            ld a, h
            or l
            jr nz, pj_z
pj_z1:
            ld hl, 1
pj_z:
            push hl                 ; Z
            ex de, hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld a, h
            push af                 ; X's sign
            HABS
            UCAP                    ; |X|, Z at most
            call pj_160
            pop af
            pop de                  ; Z
            push de
            push af
            PJDIV
            ex de, hl
            ld hl, 160
            pop af
            bit 7, a
            jr nz, pj_xn
            add hl, de
            jr pj_xs
pj_xn:
            or a
            sbc hl, de
pj_xs:
            ld de, 319
            UCAP
            ld (ix + 8), l
            ld (ix + 9), h
            pop de                  ; Z
            ld l, (ix + 2)
            ld h, (ix + 3)
            ld a, h
            push af                 ; Y's sign
            push de                 ; Z
            HABS
            push hl
            ld l, e
            ld h, d
            add hl, hl
            add hl, de
            srl h
            rr l
            srl h
            rr l
            ex de, hl
            pop hl
            UCAP                    ; |Y|, 3Z / 4 at most
            call pj_133
            pop de                  ; Z
            PJDIV
            ex de, hl
            ld hl, 100
            pop af
            bit 7, a
            jr nz, pj_yn
            or a
            sbc hl, de
            jr pj_ys
pj_yn:
            add hl, de
pj_ys:
            ld de, 199
            UCAP
            ld (ix + 10), l
            ld (ix + 11), h
            ret
; pj_160 / pj_133 - C:HL = HL * 160 / * 133 (24 bits), by shifts
pj_160:
            ld c, 0
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 32
            ld d, h
            ld e, l
            ld b, c
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 128
            add hl, de
            ld a, c
            adc a, b
            ld c, a                 ; * 160
            ret
pj_133:
            ld c, 0
            push hl                 ; n
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 4
            ld d, h
            ld e, l
            ld b, c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c
            add hl, hl
            rl c                    ; * 128
            add hl, de
            ld a, c
            adc a, b
            ld c, a                 ; * 132
            pop de
            add hl, de
            ld a, c
            adc a, 0
            ld c, a                 ; * 133
            ret
; ed_one - the edge IX - IY (two corners): drawn as it is, clipped, or not at all
ed_one:
            ld a, (ix + 6)
            and (iy + 6)
            ret nz                  ; both ends outside the same side
            ld a, (ix + 6)
            or (iy + 6)
            jr z, ed_set
            ld (w_mask), a
            push ix
            pop hl
            ld de, w_e0
            ld bc, 6
            ldir
            push iy
            pop hl
            ld de, w_e1
            ld bc, 6
            ldir
            call clip3d
            ret nc                  ; nothing of it in view
            ld ix, w_e0
            call ve_proj
            ld ix, w_e1
            call ve_proj
            ld ix, w_e0
            ld iy, w_e1
ed_set:
            ld l, (ix + 8)
            ld h, (ix + 9)
            ld (gfx_x0), hl
            ld l, (ix + 10)
            ld h, (ix + 11)
            ld (gfx_y0), hl
            ld l, (iy + 8)
            ld h, (iy + 9)
            ld (gfx_x1), hl
            ld l, (iy + 10)
            ld h, (iy + 11)
            ld (gfx_y1), hl
            jp gfx_line
; clip3d - w_e0 - w_e1 cut against the sides in w_mask (near, right, left, top, bottom);
; carry: something is left
clip3d:
            xor a
            ld (w_pl), a
cp_lp:
            ld a, (w_mask)
            rrca
            ld (w_mask), a
            jr nc, cp_next
            ld ix, w_e0
            call cp_dist
            ld (w_d0), hl
            ld ix, w_e1
            call cp_dist
            ld (w_d1), hl
            ld a, (w_d0 + 1)
            ld b, a
            ld a, (w_d1 + 1)
            and b
            jp m, cp_rej            ; both outside
            bit 7, b
            jr z, cp_e1
            ld ix, w_e0             ; end 0 outside: moved to the side
            ld iy, w_e1
            ld hl, (w_d0)
            ld (w_dn), hl
            ld de, (w_d1)
            or a
            sbc hl, de
            ld (w_dd), hl
            call cp_lerp
            jr cp_next
cp_e1:
            ld a, (w_d1 + 1)
            bit 7, a
            jr z, cp_next
            ld ix, w_e1             ; end 1 outside
            ld iy, w_e0
            ld hl, (w_d1)
            ld (w_dn), hl
            ld de, (w_d0)
            or a
            sbc hl, de
            ld (w_dd), hl
            call cp_lerp
cp_next:
            ld a, (w_pl)
            inc a
            ld (w_pl), a
            cp 5
            jr nz, cp_lp
            scf
            ret
cp_rej:
            or a
            ret
; cp_dist - HL = how far the point at IX is inside side w_pl (negative: outside)
cp_dist:
            ld e, (ix + 4)
            ld d, (ix + 5)
            ld a, (w_pl)
            or a
            jr nz, cd1
            ld hl, -16
            add hl, de              ; Z - 16
            ret
cd1:
            dec a
            jr nz, cd2
            ld l, (ix + 0)
            ld h, (ix + 1)
            ex de, hl
            or a
            sbc hl, de              ; Z - X
            ret
cd2:
            dec a
            jr nz, cd3
            ld l, (ix + 0)
            ld h, (ix + 1)
            add hl, de              ; Z + X
            ret
cd3:
            push af
            ld l, e
            ld h, d
            add hl, hl
            add hl, de
            ex de, hl               ; DE = 3Z
            ld l, (ix + 2)
            ld h, (ix + 3)
            add hl, hl
            add hl, hl              ; HL = 4Y
            pop af
            dec a
            jr nz, cd4
            ex de, hl
            or a
            sbc hl, de              ; (3Z - 4Y) / 2
            sra h
            rr l
            ret
cd4:
            add hl, de              ; (3Z + 4Y) / 2
            sra h
            rr l
            ret
; cp_lerp - the point at IX moved towards IY's: + (IY - IX) * w_dn / w_dd
cp_lerp:
            ld b, 3
cl_lp2:
            push bc
            ld l, (iy + 0)
            ld h, (iy + 1)
            ld e, (ix + 0)
            ld d, (ix + 1)
            or a
            sbc hl, de
            ex de, hl
            ld bc, (w_dn)
            call mul16s
            ld bc, (w_dd)
            call div32s16
            ld e, (ix + 0)
            ld d, (ix + 1)
            add hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz cl_lp2
            ret

; ---- arithmetic

; mulfix - HL = DE * BC / 16384, signed
mulfix:
            call mul16s
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; mul16s - DEHL = DE * BC, signed
mul16s:
            ld a, d
            xor b
            push af
            bit 7, d
            jr z, ms1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
ms1:
            bit 7, b
            jr z, ms2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
ms2:
            call mulu16
            pop af
            ret p
neg32:
            xor a
            sub l
            ld l, a
            ld a, 0
            sbc a, h
            ld h, a
            ld a, 0
            sbc a, e
            ld e, a
            ld a, 0
            sbc a, d
            ld d, a
            ret
; mulu16 - DEHL = DE * BC, unsigned
mulu16:
            ld hl, 0
            ld a, 16
mu_lp:
            add hl, hl
            rl e
            rl d
            jr nc, mu_n
            add hl, bc
            jr nc, mu_n
            inc de
mu_n:
            dec a
            jr nz, mu_lp
            ret
; div32s16 - HL = DEHL / BC, signed (kept to 32767 if it would be more)
div32s16:
            ld a, d
            xor b
            push af
            bit 7, d
            call nz, neg32
            bit 7, b
            jr z, ds1
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
ds1:
            ex de, hl
            or a
            sbc hl, bc
            add hl, bc
            jr c, ds2
            ld de, #7FFF
            jr ds3
ds2:
            call divu
ds3:
            ex de, hl
            pop af
            ret p
hneg:
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; divu - DE = HL:DE / BC, unsigned, HL < BC (HL = the remainder)
divu:
            ld a, 16
dv_lp:
            sla e
            rl d
            adc hl, hl
            jr c, dv_s
            sbc hl, bc
            jr nc, dv_ok
            add hl, bc
            dec a
            jr nz, dv_lp
            ret
dv_s:
            or a
            sbc hl, bc
dv_ok:
            inc e
            dec a
            jr nz, dv_lp
            ret
; habs - HL = |HL|
habs:
            bit 7, h
            ret z
            jr hneg
; ucap - HL = the smaller of HL and DE, unsigned
ucap:
            or a
            sbc hl, de
            add hl, de
            ret c
            ld h, d
            ld l, e
            ret
; cmps - carry when HL < DE, signed (HL lost)
cmps:
            ld a, h
            xor d
            jp m, cm_d
            or a
            sbc hl, de
            ret
cm_d:
            bit 7, h
            scf
            ret nz
            or a
            ret
; x6 - HL = A * 6
x6:
            ld l, a
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de
            ret

ce_edges:   dw {VTX} + 0, {VTX} + 12, {VTX} + 24, {VTX} + 36, {VTX} + 0, {VTX} + 24, {VTX} + 12, {VTX} + 36, {VTX} + 48, {VTX} + 60, {VTX} + 72, {VTX} + 84
            dw {VTX} + 48, {VTX} + 72, {VTX} + 60, {VTX} + 84, {VTX} + 0, {VTX} + 48, {VTX} + 12, {VTX} + 60, {VTX} + 24, {VTX} + 72, {VTX} + 36, {VTX} + 84
w_rs:       dw 0
w_a:        dw 0
w_b:        dw 0
w_t:        dw 0
w_d:        dw 0
w_k:        dw 0
w_cbx:      db 0
w_cbz:      db 0
w_ci:       db 0
w_cj:       db 0
w_lvl:      db 0
w_var:      db 0
w_vk:       db 0
w_mask:     db 0
w_pl:       db 0
w_px0:      dw 0
w_px1:      dw 0
w_pz0:      dw 0
w_pz1:      dw 0
w_phl:      dw 0
w_cx:       dw 0
w_cy:       dw 0
w_cz:       dw 0
w_d0:       dw 0
w_d1:       dw 0
w_dn:       dw 0
w_dd:       dw 0
w_csp:      dw 0
w_crp:      dw 0
w_e0:       ds 12
w_e1:       ds 12
#endasm
End Sub
