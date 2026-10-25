' Vec - a solid cube in 3D for the vector tests, the same on every machine: it turns the cube,
' puts it in perspective, drops the faces turned away, lights the rest, and makes each face's
' outline into a left and a right edge for each line (Edge, in asm). Each chip's class fills those
' lines its own way (Spans) - this class draws nothing.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
'   Vec.Setup size, distance, focal, cx, cy, narrow     ' narrow 1: x halved (the CPC's mode 0)
'   Do
'     <chip>.Begin                                         ' the old picture's box cleared
'     Vec.Turn 2, 3, 1 : Vec.Project
'     <chip>.Keep Vec.Bx0, Vec.By0, Vec.Bx1, Vec.By1       ' (this one's, to clear next time)
'     For f = 0 To 5
'       b = Vec.Face(f)                                    ' 0: turned away; 17-65: how lit
'       If b Then <chip>.Spans Vec.Y0, Vec.Y1, <colour for b>, Vec.L(), Vec.R()
'     Next
'     <chip>.Show
'   Loop
' Each chip's Spans fills a line from its left to its right (it skips a line whose left is past
' its right).
' Numbers are whole: sines times 64 (a turn is 256), the light from up, left and in front.
' Screen coordinates must stay 0-255 (each edge table has a byte for each line, a byte each).
Option Explicit

Public Y0 As Integer, Y1 As Integer                          ' the face's top and bottom line
Public Bx0 As Integer, By0 As Integer, Bx1 As Integer, By1 As Integer   ' the cube's box
Private px(7) As Integer, py(7) As Integer, bx(3) As Integer
Private m(8) As Integer                                      ' the turn, times 64
Private ra As Integer, rb As Integer, rc As Integer
Private sz As Integer, dist As Integer, foc As Integer, ox As Integer, oy As Integer, nar As Integer
Private xl(255) As Byte, xr(255) As Byte


Public Sub Setup(ByVal size As Integer, ByVal distance As Integer, ByVal focal As Integer, ByVal cx As Integer, ByVal cy As Integer, ByVal narrow As Integer)
  sz = size : dist = distance : foc = focal : ox = cx : oy = cy : nar = narrow
End Sub

' L(), R(): the edge tables' addresses (a byte for each line)
Public Function L() As Integer
  L = VarPtr(xl)
End Function

Public Function R() As Integer
  R = VarPtr(xr)
End Function

' Turn da, db, dc: the cube turned on by these (around x, y, z; 256 a turn)
Public Sub Turn(ByVal da As Integer, ByVal db As Integer, ByVal dc As Integer)
  ra = (ra + da) And 255 : rb = (rb + db) And 255 : rc = (rc + dc) And 255
End Sub

' Sn(a): the sine of a (256 a turn), times 64
Public Function Sn(ByVal a As Integer) As Integer
  Dim v As Integer
  v = Peek(SinTab() + (a And 255))
  If v > 127 Then v = v - 256
  Sn = v
End Function

' Project: the turn worked out, the 8 corners turned and put in perspective, the box round them
' (CornersA, in asm)
Public Sub Project()
  CornersA ra, rb, rc, SinTab(), VarPtr(m), sz, dist, foc, ox, oy, nar, VarPtr(px), VarPtr(py), VarPtr(bx)
  Bx0 = bx(0) : By0 = bx(1) : Bx1 = bx(2) : By1 = bx(3)
End Sub


' Face(f): face f (0-5) - 0 if it's turned away, else how lit (1-65), with Y0, Y1 and the edge
' tables filled for its lines
Public Function Face(ByVal f As Integer) As Integer
  Face = FaceA(f, VarPtr(px), VarPtr(py), VarPtr(m), VarPtr(xl), VarPtr(xr), VarPtr(Y0), VarPtr(Y1))
End Function

' Edge x0, y0, x1, y1, tl, tr: a polygon edge into the tables: going down (on the screen) it's the
' left edge (tl), going up the right (tr), flat nothing - right for the faces turned to you, which
' go round anticlockwise on the screen. An x for each line, stepped with a whole part and a
' remainder, so no division per line
Public Sub Edge(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer, ByVal tl As Integer, ByVal tr As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (eg_x0), a
            pop hl
            ld a, (hl)
            ld (eg_y0), a
            pop hl
            ld a, (hl)
            ld (eg_x1), a
            pop hl
            ld a, (hl)
            ld (eg_y1), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (eg_tl), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; (the right table: for going up)
            ld hl, (eg_tl)
            ld (eg_tl), de
            ex de, hl               ; de: the left table, for going down
            ld a, (eg_y0)
            ld b, a
            ld a, (eg_y1)
            cp b
            ret z                   ; flat
            jr nc, eg_down          ; going down: the left edge
            ld c, a                 ; going up: the ends swapped, the right edge
            ld a, b
            ld (eg_y1), a
            ld a, c
            ld (eg_y0), a
            ld a, (eg_x0)
            ld c, a
            ld a, (eg_x1)
            ld (eg_x0), a
            ld a, c
            ld (eg_x1), a
            ld de, (eg_tl)
eg_down:    ld a, (eg_y0)
            ld l, a
            ld h, 0
            add hl, de
            ld (eg_ptr), hl         ; the table at y0
            ld a, (eg_y0)
            ld c, a
            ld a, (eg_y1)
            sub c                   ; dy
            ld (eg_cp + 1), a
            ld (eg_sd + 1), a
            ld e, a                 ; e: dy
            inc a
            ld b, a                 ; b: lines, dy + 1
            ld a, (eg_x0)
            ld c, a
            ld a, (eg_x1)
            sub c                   ; dx
            jr nc, eg_right
            neg                     ; going left: sub d, dec c
            ld c, a
            ld a, #92
            ld (eg_q), a
            ld a, #0D
            ld (eg_step), a
            ld a, c
            jr eg_dv
eg_right:   ld c, a                 ; going right: add a, d, inc c
            ld a, #82
            ld (eg_q), a
            ld a, #0C
            ld (eg_step), a
            ld a, c
eg_dv:      ld d, 0                 ; dx / dy: d the whole part, the remainder patched in
eg_div:     cp e
            jr c, eg_divd
            sub e
            inc d
            jr eg_div
eg_divd:    ld (eg_ar + 1), a
            ld a, (eg_x0)
            ld c, a                 ; c: x
            ld hl, (eg_ptr)
            ld e, 0                 ; e: the remainder so far
eg_row:     ld (hl), c
            inc hl
            ld a, c
eg_q:       add a, d                ; (or sub d)
            ld c, a
            ld a, e
eg_ar:      add a, 0                ; + the remainder (patched)
            jr c, eg_over
eg_cp:      cp 0                    ; dy (patched)
            jr c, eg_keep
eg_over:
eg_sd:      sub 0                   ; - dy (patched)
            ld e, a
eg_step:    inc c                   ; (or dec c)
            djnz eg_row
            ret
eg_keep:    ld e, a
            djnz eg_row
            ret
eg_x0:      db 0
eg_y0:      db 0
eg_x1:      db 0
eg_y1:      db 0
eg_tl:      dw 0
eg_ptr:     dw 0
#endasm
End Sub

' SinTab(): the sines, a byte each (times 64, signed), 256 a turn
Private Function SinTab() As Integer
#asm
            pop hl
            ld de, vec_sin
            ld (hl), e
            inc hl
            ld (hl), d
            ret
vec_sin:
            db #00, #02, #03, #05, #06, #08, #09, #0B, #0C, #0E, #10, #11, #13, #14, #16, #17
            db #18, #1A, #1B, #1D, #1E, #20, #21, #22, #24, #25, #26, #27, #29, #2A, #2B, #2C
            db #2D, #2E, #2F, #30, #31, #32, #33, #34, #35, #36, #37, #38, #38, #39, #3A, #3B
            db #3B, #3C, #3C, #3D, #3D, #3E, #3E, #3E, #3F, #3F, #3F, #40, #40, #40, #40, #40
            db #40, #40, #40, #40, #40, #40, #3F, #3F, #3F, #3E, #3E, #3E, #3D, #3D, #3C, #3C
            db #3B, #3B, #3A, #39, #38, #38, #37, #36, #35, #34, #33, #32, #31, #30, #2F, #2E
            db #2D, #2C, #2B, #2A, #29, #27, #26, #25, #24, #22, #21, #20, #1E, #1D, #1B, #1A
            db #18, #17, #16, #14, #13, #11, #10, #0E, #0C, #0B, #09, #08, #06, #05, #03, #02
            db #00, #FE, #FD, #FB, #FA, #F8, #F7, #F5, #F4, #F2, #F0, #EF, #ED, #EC, #EA, #E9
            db #E8, #E6, #E5, #E3, #E2, #E0, #DF, #DE, #DC, #DB, #DA, #D9, #D7, #D6, #D5, #D4
            db #D3, #D2, #D1, #D0, #CF, #CE, #CD, #CC, #CB, #CA, #C9, #C8, #C8, #C7, #C6, #C5
            db #C5, #C4, #C4, #C3, #C3, #C2, #C2, #C2, #C1, #C1, #C1, #C0, #C0, #C0, #C0, #C0
            db #C0, #C0, #C0, #C0, #C0, #C0, #C1, #C1, #C1, #C2, #C2, #C2, #C3, #C3, #C4, #C4
            db #C5, #C5, #C6, #C7, #C8, #C8, #C9, #CA, #CB, #CC, #CD, #CE, #CF, #D0, #D1, #D2
            db #D3, #D4, #D5, #D6, #D7, #D9, #DA, #DB, #DC, #DE, #DF, #E0, #E2, #E3, #E5, #E6
            db #E8, #E9, #EA, #EC, #ED, #EF, #F0, #F2, #F4, #F5, #F7, #F8, #FA, #FB, #FD, #FE
#endasm
End Function

' FaceTab(): the 6 faces: 4 corners each (round the way that's anticlockwise on the screen when
' it faces you), then the axis of its normal (0 x, 1 y, 2 z) and its side (1 +, 0 -)
Private Function FaceTab() As Integer
#asm
            pop hl
            ld de, vec_faces
            ld (hl), e
            inc hl
            ld (hl), d
            ret
vec_faces:
            db 1, 3, 7, 5, 0, 1
            db 4, 6, 2, 0, 0, 0
            db 2, 6, 7, 3, 1, 1
            db 1, 5, 4, 0, 1, 0
            db 4, 5, 7, 6, 2, 1
            db 2, 3, 1, 0, 2, 0
#endasm
End Function

' CornersA a, b, c, sines, m, size, distance, focal, cx, cy, narrow, px, py, box: the turn (angles
' a, b, c round x, y, z) worked out into m (times 64); the 8 corners (the turn scaled by size; each corner the turn's columns added or taken away) put in perspective
' (x * focal / (z + distance)) into px, py; the box round them into box (x0, y0, x1, y1)
Private Sub CornersA(ByVal a1 As Integer, ByVal a2 As Integer, ByVal a3 As Integer, ByVal st As Integer, ByVal ma As Integer, ByVal size As Integer, ByVal dst As Integer, ByVal fc As Integer, ByVal cx As Integer, ByVal cy As Integer, ByVal nw As Integer, ByVal pxa As Integer, ByVal pya As Integer, ByVal bxa As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (cr_a1), a
            pop hl
            ld a, (hl)
            ld (cr_a2), a
            pop hl
            ld a, (hl)
            ld (cr_a3), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_st), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_m), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_sz), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_dist), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_foc), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_ox), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_oy), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_nar), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_px), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_py), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (cr_box), de
            ld (cr_ix), ix
            ld a, (cr_a1)
            add a, 0
            ld e, a
            ld d, 0
            ld hl, (cr_st)
            add hl, de
            ld a, (hl)
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld (cr_qsa), hl
            ld a, (cr_a1)
            add a, 64
            ld e, a
            ld d, 0
            ld hl, (cr_st)
            add hl, de
            ld a, (hl)
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld (cr_qca), hl
            ld a, (cr_a2)
            add a, 0
            ld e, a
            ld d, 0
            ld hl, (cr_st)
            add hl, de
            ld a, (hl)
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld (cr_qsb), hl
            ld a, (cr_a2)
            add a, 64
            ld e, a
            ld d, 0
            ld hl, (cr_st)
            add hl, de
            ld a, (hl)
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld (cr_qcb), hl
            ld a, (cr_a3)
            add a, 0
            ld e, a
            ld d, 0
            ld hl, (cr_st)
            add hl, de
            ld a, (hl)
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld (cr_qsc), hl
            ld a, (cr_a3)
            add a, 64
            ld e, a
            ld d, 0
            ld hl, (cr_st)
            add hl, de
            ld a, (hl)
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld (cr_qcc), hl
            ld hl, (cr_qcb)
            ld de, (cr_qcc)
            ld ix, cr_mb1
            jp cr_mm
cr_mb1:     ld (cr_m0), hl
            ld hl, (cr_qsa)
            ld de, (cr_qsb)
            ld ix, cr_mb2
            jp cr_mm
cr_mb2:     ld (cr_t), hl
            ld hl, (cr_t)
            ld de, (cr_qcc)
            ld ix, cr_mb3
            jp cr_mm
cr_mb3:     ld (cr_u), hl
            ld hl, (cr_qca)
            ld de, (cr_qsc)
            ld ix, cr_mb4
            jp cr_mm
cr_mb4:     ld (cr_w), hl
            ld hl, (cr_u)
            ld de, (cr_w)
            or a
            sbc hl, de
            ld (cr_m1), hl
            ld hl, (cr_t)
            ld de, (cr_qsc)
            ld ix, cr_mb5
            jp cr_mm
cr_mb5:     ld (cr_u), hl
            ld hl, (cr_qca)
            ld de, (cr_qcc)
            ld ix, cr_mb6
            jp cr_mm
cr_mb6:     ld (cr_w), hl
            ld hl, (cr_u)
            ld de, (cr_w)
            add hl, de
            ld (cr_m4), hl
            ld hl, (cr_qca)
            ld de, (cr_qsb)
            ld ix, cr_mb7
            jp cr_mm
cr_mb7:     ld (cr_t), hl
            ld hl, (cr_t)
            ld de, (cr_qcc)
            ld ix, cr_mb8
            jp cr_mm
cr_mb8:     ld (cr_u), hl
            ld hl, (cr_qsa)
            ld de, (cr_qsc)
            ld ix, cr_mb9
            jp cr_mm
cr_mb9:     ld (cr_w), hl
            ld hl, (cr_u)
            ld de, (cr_w)
            add hl, de
            ld (cr_m2), hl
            ld hl, (cr_t)
            ld de, (cr_qsc)
            ld ix, cr_mb10
            jp cr_mm
cr_mb10:     ld (cr_u), hl
            ld hl, (cr_qsa)
            ld de, (cr_qcc)
            ld ix, cr_mb11
            jp cr_mm
cr_mb11:     ld (cr_w), hl
            ld hl, (cr_u)
            ld de, (cr_w)
            or a
            sbc hl, de
            ld (cr_m5), hl
            ld hl, (cr_qcb)
            ld de, (cr_qsc)
            ld ix, cr_mb12
            jp cr_mm
cr_mb12:     ld (cr_m3), hl
            ld hl, (cr_qsb)
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
            ld (cr_m6), hl
            ld hl, (cr_qsa)
            ld de, (cr_qcb)
            ld ix, cr_mb13
            jp cr_mm
cr_mb13:     ld (cr_m7), hl
            ld hl, (cr_qca)
            ld de, (cr_qcb)
            ld ix, cr_mb14
            jp cr_mm
cr_mb14:     ld (cr_m8), hl
            ld hl, cr_m0        ; the turn out to m (Face uses it for the light)
            ld de, (cr_m)
            ld bc, 18
            ldir
            ld hl, (cr_m)       ; the turn scaled: ms(k) = m(k) * size / 64
            ld (cr_p), hl
            ld hl, cr_ms
            ld (cr_q), hl
            ld a, 9
            ld (cr_k), a
cr_sc:      ld hl, (cr_p)
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld (cr_p), hl
            ld hl, (cr_sz)
            ld ix, cr_sc1
            jp cr_mul
cr_sc1:
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
            ex de, hl
            ld hl, (cr_q)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (cr_q), hl
            ld a, (cr_k)
            dec a
            ld (cr_k), a
            jr nz, cr_sc
            ld hl, 255
            ld (cr_bx0), hl
            ld (cr_by0), hl
            ld hl, 0
            ld (cr_bx1), hl
            ld (cr_by1), hl
            xor a
            ld (cr_i), a
cr_corner:  ld hl, cr_ms        ; x, y, z: the rows
            ld ix, cr_c1
            jp cr_row
cr_c1:      ld (cr_x), hl
            ld hl, cr_ms + 6
            ld ix, cr_c2
            jp cr_row
cr_c2:      ld (cr_y), hl
            ld hl, cr_ms + 12
            ld ix, cr_c3
            jp cr_row
cr_c3:      ld de, (cr_dist)
            add hl, de
            ld (cr_d), hl       ; z + distance
            ld hl, (cr_x)
            ld de, (cr_foc)
            ld a, d             ; (focal 256: a shift, not a multiply)
            dec a
            or e
            jr nz, cr_c4m
            ld h, l
            ld l, 0
            jr cr_c4
cr_c4m:     ld ix, cr_c4
            jp cr_mul
cr_c4:      ld de, (cr_d)
            ld ix, cr_c5
            jp cr_sdiv
cr_c5:      ld a, (cr_nar)
            or a
            jr z, cr_c6
            sra h
            rr l
cr_c6:      ld de, (cr_ox)
            add hl, de
            ex de, hl
            ld hl, (cr_px)
            ld a, (cr_i)
            add a, a
            ld c, a
            ld b, 0
            add hl, bc
            ld (hl), e
            inc hl
            ld (hl), d
            ld hl, (cr_bx0)
            or a
            sbc hl, de
            jr c, cr_c7
            ld (cr_bx0), de
cr_c7:      ld hl, (cr_bx1)
            or a
            sbc hl, de
            jr nc, cr_c8
            ld (cr_bx1), de
cr_c8:      ld hl, (cr_y)
            ld de, (cr_foc)
            ld a, d             ; (focal 256: a shift, not a multiply)
            dec a
            or e
            jr nz, cr_c9m
            ld h, l
            ld l, 0
            jr cr_c9
cr_c9m:     ld ix, cr_c9
            jp cr_mul
cr_c9:      ld de, (cr_d)
            ld ix, cr_c10
            jp cr_sdiv
cr_c10:     ld de, (cr_oy)
            add hl, de
            ex de, hl
            ld hl, (cr_py)
            ld a, (cr_i)
            add a, a
            ld c, a
            ld b, 0
            add hl, bc
            ld (hl), e
            inc hl
            ld (hl), d
            ld hl, (cr_by0)
            or a
            sbc hl, de
            jr c, cr_c11
            ld (cr_by0), de
cr_c11:     ld hl, (cr_by1)
            or a
            sbc hl, de
            jr nc, cr_c12
            ld (cr_by1), de
cr_c12:     ld a, (cr_i)
            inc a
            ld (cr_i), a
            cp 8
            jp nz, cr_corner
            ld hl, (cr_box)     ; the box out
            ld de, (cr_bx0)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (cr_by0)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (cr_bx1)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (cr_by1)
            ld (hl), e
            inc hl
            ld (hl), d
            ld ix, (cr_ix)
            ret
cr_row:     ld (cr_rp), hl      ; hl = +-a +-b +-c (the 3 words at hl; corner i's bits 0-2: + or -)
            ld hl, 0
            ld (cr_acc), hl
            ld b, 1
            ld c, 3
cr_rl:      ld hl, (cr_rp)
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld (cr_rp), hl
            ld a, (cr_i)
            and b
            jr nz, cr_rpos
            ld a, e
            cpl
            ld e, a
            ld a, d
            cpl
            ld d, a
            inc de
cr_rpos:    ld hl, (cr_acc)
            add hl, de
            ld (cr_acc), hl
            sla b
            dec c
            jr nz, cr_rl
            ld hl, (cr_acc)
            jp (ix)
cr_mul:     ld a, h             ; hl = hl * de, signed (8 steps when one of them is under 256)
            xor d
            ld (cr_sg2), a
            bit 7, h
            jr z, cr_p1
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
cr_p1:      bit 7, d
            jr z, cr_p2
            ld a, e
            cpl
            ld e, a
            ld a, d
            cpl
            ld d, a
            inc de
cr_p2:      ld a, d
            or a
            jr z, cr_sm
            ld a, h
            or a
            jr nz, cr_bg
            ex de, hl
cr_sm:      ld b, h
            ld c, l
            ld a, e
            ld hl, 0
            ld d, 8
cr_sl:      add hl, hl
            rla
            jr nc, cr_sn
            add hl, bc
cr_sn:      dec d
            jr nz, cr_sl
            jr cr_dn
cr_bg:      ld a, 16
            ld b, h
            ld c, l
            ld hl, 0
cr_ml:      add hl, hl
            sla e
            rl d
            jr nc, cr_mn
            add hl, bc
cr_mn:      dec a
            jr nz, cr_ml
cr_dn:      ld a, (cr_sg2)
            bit 7, a
            jr z, cr_mo
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
cr_mo:      jp (ix)
cr_sg2:     db 0
cr_mm:      ld (cr_mmix), ix    ; hl = hl * de / 64
            ld ix, cr_mm1
            jp cr_mul
cr_mm1:
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
            ld ix, (cr_mmix)
            jp (ix)
cr_sdiv:    ld a, h             ; hl = hl / de (de above 0)
            ld (cr_sg), a
            bit 7, h
            jr z, cr_dp
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
cr_dp:      ld b, h
            ld c, l
            ld hl, 0
            ld a, b
            ld b, 16
cr_d1:      rl c
            rla
            adc hl, hl
            sbc hl, de
            jr nc, cr_d2
            add hl, de
cr_d2:      djnz cr_d1
            rl c
            rla
            cpl
            ld h, a
            ld a, c
            cpl
            ld l, a
            ld a, (cr_sg)
            bit 7, a
            jr z, cr_d3
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
cr_d3:      jp (ix)
cr_m:       dw 0
cr_sz:      dw 0
cr_dist:    dw 0
cr_foc:     dw 0
cr_ox:      dw 0
cr_oy:      dw 0
cr_nar:     dw 0
cr_px:      dw 0
cr_py:      dw 0
cr_box:     dw 0
cr_ix:      dw 0
cr_p:       dw 0
cr_q:       dw 0
cr_k:       db 0
cr_i:       db 0
cr_sg:      db 0
cr_x:       dw 0
cr_y:       dw 0
cr_d:       dw 0
cr_rp:      dw 0
cr_acc:     dw 0
cr_bx0:     dw 0
cr_by0:     dw 0
cr_bx1:     dw 0
cr_by1:     dw 0
cr_ms:      ds 18
cr_a1:      db 0
cr_a2:      db 0
cr_a3:      db 0
cr_st:      dw 0
cr_mmix:    dw 0
cr_qsa:     dw 0
cr_qca:     dw 0
cr_qsb:     dw 0
cr_qcb:     dw 0
cr_qsc:     dw 0
cr_qcc:     dw 0
cr_t:       dw 0
cr_u:       dw 0
cr_w:       dw 0
cr_m0:      dw 0
cr_m1:      dw 0
cr_m2:      dw 0
cr_m3:      dw 0
cr_m4:      dw 0
cr_m5:      dw 0
cr_m6:      dw 0
cr_m7:      dw 0
cr_m8:      dw 0
#endasm
End Sub

' FaceA(f, px, py, m, tl, tr, y0, y1): Face, in asm: 0 if face f is turned away; else the edges
' into the tables tl, tr, its top and bottom line into y0, y1, and how lit it is (17-65)
Private Function FaceA(ByVal f As Integer, ByVal pxa As Integer, ByVal pya As Integer, ByVal ma As Integer, ByVal tla As Integer, ByVal tra As Integer, ByVal y0a As Integer, ByVal y1a As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            ld (fa_f), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fa_px), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fa_py), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fa_m), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fa_tl), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fa_tr), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fa_y0a), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (fa_y1a), de
            pop hl
            ld (fa_res), hl     ; the result's address
            ld (fa_ix), ix
            ld a, (fa_f)        ; the face's 6 bytes
            ld l, a
            add a, a
            add a, l
            add a, a
            ld e, a
            ld d, 0
            ld hl, fa_tab
            add hl, de
            ld de, fa_i
            ld bc, 6
            ldir
            xor a               ; its 4 corners' x, y
            ld (fa_k), a
fa_get:     ld a, (fa_k)
            ld e, a
            ld d, 0
            ld hl, fa_i
            add hl, de
            ld a, (hl)
            add a, a
            ld e, a             ; de: corner * 2
            ld hl, (fa_px)
            add hl, de
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld a, (fa_k)
            add a, a
            ld e, a             ; de: k * 2 (d still 0)
            ld hl, fa_x
            add hl, de
            ld (hl), c
            inc hl
            ld (hl), b
            ld a, (fa_k)
            ld e, a
            ld hl, fa_i
            add hl, de
            ld a, (hl)
            add a, a
            ld e, a
            ld hl, (fa_py)
            add hl, de
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld a, (fa_k)
            add a, a
            ld e, a
            ld hl, fa_y
            add hl, de
            ld (hl), c
            inc hl
            ld (hl), b
            ld a, (fa_k)
            inc a
            ld (fa_k), a
            cp 4
            jr nz, fa_get
            ld hl, (fa_x + 2)   ; a = (x1 - x0) * (y2 - y0)
            ld de, (fa_x)
            or a
            sbc hl, de
            ld (fa_t), hl       ; x1 - x0
            ld hl, (fa_y + 4)
            ld de, (fa_y)
            or a
            sbc hl, de          ; y2 - y0
            ex de, hl
            ld hl, (fa_t)
            ld ix, fa_v1
            jp fa_mul
fa_v1:      ld (fa_a), hl
            ld hl, (fa_y + 2)
            ld de, (fa_y)
            or a
            sbc hl, de          ; y1 - y0
            ld (fa_t), hl
            ld hl, (fa_x + 4)
            ld de, (fa_x)
            or a
            sbc hl, de          ; x2 - x0
            ex de, hl
            ld hl, (fa_t)
            ld ix, fa_v2
            jp fa_mul
fa_v2:      ex de, hl           ; de: b = (y1 - y0) * (x2 - x0)
            ld hl, (fa_a)
            or a
            sbc hl, de          ; a - b
            jp po, fa_nov
            jp m, fa_hide       ; (overflowed: the sign is the other way)
            jp fa_show
fa_nov:     jp p, fa_hide       ; a >= b: turned away
fa_show:    ld a, (fa_ax)       ; lit: (m(ax) * -26 + m(ax + 3) * -38 + m(ax + 6) * -45) / 64
            add a, a
            ld e, a
            ld d, 0
            ld hl, (fa_m)
            add hl, de
            ld (fa_p), hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, -26
            ld ix, fa_l1
            jp fa_mul
fa_l1:      ld (fa_acc), hl
            ld hl, (fa_p)
            ld de, 6
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, -38
            ld ix, fa_l2
            jp fa_mul
fa_l2:      ld de, (fa_acc)
            add hl, de
            ld (fa_acc), hl
            ld hl, (fa_p)
            ld de, 12
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, -45
            ld ix, fa_l3
            jp fa_mul
fa_l3:      ld de, (fa_acc)
            add hl, de
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
            ld a, (fa_side)
            or a
            jr nz, fa_l4
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
fa_l4:      bit 7, h
            jr z, fa_l5
            ld hl, 0
fa_l5:      ld d, h             ; 17 + lit * 3 / 4 (a quarter of the light everywhere)
            ld e, l
            add hl, hl
            add hl, de
            sra h
            rr l
            sra h
            rr l
            ld de, 17
            add hl, de
            ld (fa_v), hl
            ld a, (fa_y)        ; its top and bottom line
            ld b, a
            ld c, a
            ld a, (fa_y + 2)
            cp b
            jr nc, fa_mn2
            ld b, a
fa_mn2:    cp c
            jr c, fa_mx2
            ld c, a
fa_mx2:
            ld a, (fa_y + 4)
            cp b
            jr nc, fa_mn4
            ld b, a
fa_mn4:    cp c
            jr c, fa_mx4
            ld c, a
fa_mx4:
            ld a, (fa_y + 6)
            cp b
            jr nc, fa_mn6
            ld b, a
fa_mn6:    cp c
            jr c, fa_mx6
            ld c, a
fa_mx6:
            ld hl, (fa_y0a)
            ld (hl), b
            inc hl
            ld (hl), 0
            ld hl, (fa_y1a)
            ld (hl), c
            inc hl
            ld (hl), 0
            xor a               ; the 4 edges
            ld (fa_k), a
fa_e:       ld a, (fa_k)
            add a, a
            ld e, a
            ld d, 0
            ld hl, fa_x
            add hl, de
            ld a, (hl)
            ld (eg_x0), a
            ld hl, fa_y
            add hl, de
            ld a, (hl)
            ld (eg_y0), a
            ld a, (fa_k)
            inc a
            and 3
            add a, a
            ld e, a
            ld hl, fa_x
            add hl, de
            ld a, (hl)
            ld (eg_x1), a
            ld hl, fa_y
            add hl, de
            ld a, (hl)
            ld (eg_y1), a
            ld de, (fa_tr)      ; (going up: the right edge; going down: the left)
            ld (eg_tl), de
            ld de, (fa_tl)
            jp fe_edge
fa_eb:      ld a, (fa_k)
            inc a
            ld (fa_k), a
            cp 4
            jr nz, fa_e
            ld hl, (fa_v)
            jr fa_out
fa_hide:    ld hl, 0
fa_out:     ex de, hl
            ld hl, (fa_res)
            ld (hl), e
            inc hl
            ld (hl), d
            ld ix, (fa_ix)
            ret
fe_edge:
            ld a, (eg_y0)
            ld b, a
            ld a, (eg_y1)
            cp b
            jp z, fa_eb             ; flat
            jr nc, eg_down          ; going down: the left edge
            ld c, a                 ; going up: the ends swapped, the right edge
            ld a, b
            ld (eg_y1), a
            ld a, c
            ld (eg_y0), a
            ld a, (eg_x0)
            ld c, a
            ld a, (eg_x1)
            ld (eg_x0), a
            ld a, c
            ld (eg_x1), a
            ld de, (eg_tl)
eg_down:    ld a, (eg_y0)
            ld l, a
            ld h, 0
            add hl, de
            ld (eg_ptr), hl         ; the table at y0
            ld a, (eg_y0)
            ld c, a
            ld a, (eg_y1)
            sub c                   ; dy
            ld (eg_cp + 1), a
            ld (eg_sd + 1), a
            ld e, a                 ; e: dy
            inc a
            ld b, a                 ; b: lines, dy + 1
            ld a, (eg_x0)
            ld c, a
            ld a, (eg_x1)
            sub c                   ; dx
            jr nc, eg_right
            neg                     ; going left: sub d, dec c
            ld c, a
            ld a, #92
            ld (eg_q), a
            ld a, #0D
            ld (eg_step), a
            ld a, c
            jr eg_dv
eg_right:   ld c, a                 ; going right: add a, d, inc c
            ld a, #82
            ld (eg_q), a
            ld a, #0C
            ld (eg_step), a
            ld a, c
eg_dv:      ld d, 0                 ; dx / dy: d the whole part, the remainder patched in
eg_div:     cp e
            jr c, eg_divd
            sub e
            inc d
            jr eg_div
eg_divd:    ld (eg_ar + 1), a
            ld a, (eg_x0)
            ld c, a                 ; c: x
            ld hl, (eg_ptr)
            ld e, 0                 ; e: the remainder so far
eg_row:     ld (hl), c
            inc hl
            ld a, c
eg_q:       add a, d                ; (or sub d)
            ld c, a
            ld a, e
eg_ar:      add a, 0                ; + the remainder (patched)
            jr c, eg_over
eg_cp:      cp 0                    ; dy (patched)
            jr c, eg_keep
eg_over:
eg_sd:      sub 0                   ; - dy (patched)
            ld e, a
eg_step:    inc c                   ; (or dec c)
            djnz eg_row
            jp fa_eb
eg_keep:    ld e, a
            djnz eg_row
            jp fa_eb
fa_mul:     ld a, h             ; hl = hl * de, signed (8 steps when one of them is under 256)
            xor d
            ld (fa_sg2), a
            bit 7, h
            jr z, fa_p1
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
fa_p1:      bit 7, d
            jr z, fa_p2
            ld a, e
            cpl
            ld e, a
            ld a, d
            cpl
            ld d, a
            inc de
fa_p2:      ld a, d
            or a
            jr z, fa_sm
            ld a, h
            or a
            jr nz, fa_bg
            ex de, hl
fa_sm:      ld b, h
            ld c, l
            ld a, e
            ld hl, 0
            ld d, 8
fa_sl:      add hl, hl
            rla
            jr nc, fa_sn
            add hl, bc
fa_sn:      dec d
            jr nz, fa_sl
            jr fa_dn
fa_bg:      ld a, 16
            ld b, h
            ld c, l
            ld hl, 0
fa_ml:      add hl, hl
            sla e
            rl d
            jr nc, fa_mn
            add hl, bc
fa_mn:      dec a
            jr nz, fa_ml
fa_dn:      ld a, (fa_sg2)
            bit 7, a
            jr z, fa_mo
            ld a, l
            cpl
            ld l, a
            ld a, h
            cpl
            ld h, a
            inc hl
fa_mo:      jp (ix)
fa_sg2:     db 0
eg_x0:      db 0
eg_y0:      db 0
eg_x1:      db 0
eg_y1:      db 0
eg_tl:      dw 0
eg_ptr:     dw 0
fa_f:       db 0
fa_k:       db 0
fa_px:      dw 0
fa_py:      dw 0
fa_m:       dw 0
fa_tl:      dw 0
fa_tr:      dw 0
fa_y0a:     dw 0
fa_y1a:     dw 0
fa_res:     dw 0
fa_ix:      dw 0
fa_t:       dw 0
fa_a:       dw 0
fa_p:       dw 0
fa_acc:     dw 0
fa_v:       dw 0
fa_i:       ds 4
fa_ax:      db 0
fa_side:    db 0
fa_x:       ds 8
fa_y:       ds 8
fa_tab:     db 1, 3, 7, 5, 0, 1
            db 4, 6, 2, 0, 0, 0
            db 2, 6, 7, 3, 1, 1
            db 1, 5, 4, 0, 1, 0
            db 4, 5, 7, 6, 2, 1
            db 2, 3, 1, 0, 2, 0
#endasm
End Function

