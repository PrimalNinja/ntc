' E3W - NTC3D's wireframe: E3's objects, quads, discs and polygons drawn as their outlines
' instead of filled. The same models, the same calls, the same camera: only the last step differs.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Every polygon E3 draws goes through one of three entries: fill (pvx, pvy, pn: 16 bit screen
' points), ffi (a face's points wholly on the screen, as bytes in vpage) and poly3 (a face crossing
' the view's edges, in the view, before its 3D clipper). E3W.On writes a jump to E3W's outline
' routines over the first three bytes of each (kept first); E3W.Off puts them back. So with it off, E3 runs its own code untouched - no
' test, no extra jump - and with it on, everything that would be filled is outlined:
'   - an object's faces: the ones turned away are still left out (E3 does it before the filler),
'     so a convex model shows only its front edges; an edge between two front faces is drawn
'     twice (once a face);
'   - the outline's colour is the face's shaded colour (the low byte of E3's pc), so the lit side
'     is brighter;
'   - a face crossing the view's edges (E3's 3D path, poly3) has each edge cut to the view on its
'     own, so the edges E3's polygon clipper makes along the view's edges aren't drawn;
'   - Moon (discs), Quad3, HQuad, VQuad, HPlane, Skyline and Poly come out as outlines too;
'   - Box stays filled (the HUD's bars): its call is told by the code after it and sent to E3's
'     own filler.
'
' Lines are cut to the screen (Cohen-Sutherland) and drawn by Bresenham, a 64 row third of the
' buffer at a time in slots 6 and 7 as E3 does; E3's vpoll is called every eighth line, so the
' frame count and its hook keep time.
'
'   E3W.On      ' wireframe
'   E3W.Off     ' solid (E3 as it was)
'   E3W.won     ' 1 while on
'
' In a game built with tools/build.js: "extras": ["E3W.cls"] in its game.json.
Option Explicit

Public won As Integer                            ' 1: wireframe on

' On: E3's polygons outlined from now on
Public Sub On()
  Lib
  If won = 0 Then
    Hook 1
    won = 1
  End If
End Sub

' Off: E3's polygons filled again (its own code, as it was)
Public Sub Off()
  If won Then
    Hook 0
    won = 0
  End If
End Sub

' Hook hk: 1: the jumps over E3's filler's two entries (their first three bytes kept); 0: the
' kept bytes back
Private Sub Hook(ByVal hk As Integer)
#asm
            pop hl
            ld a, (hl)
            or a
            jr z, hk_off
            ld hl, fn_e3_lib_fill
            ld de, ew_kfill
            ld bc, 3
            ldir
            ld hl, fn_e3_lib_ffi
            ld de, ew_kffi
            ld bc, 3
            ldir
            ld hl, fn_e3_lib_poly3  ; <--- NEW (the 3D path: its edges cut one by one)
            ld de, ew_kp3
            ld bc, 3
            ldir
            ld a, #C3               ; jp
            ld (fn_e3_lib_fill), a
            ld (fn_e3_lib_ffi), a
            ld (fn_e3_lib_poly3), a
            ld hl, ew_fill
            ld (fn_e3_lib_fill + 1), hl
            ld hl, ew_ffi
            ld (fn_e3_lib_ffi + 1), hl
            ld hl, ew_poly3
            ld (fn_e3_lib_poly3 + 1), hl
            jr hk_end
hk_off:
            ld hl, ew_kfill
            ld de, fn_e3_lib_fill
            ld bc, 3
            ldir
            ld hl, ew_kffi
            ld de, fn_e3_lib_ffi
            ld bc, 3
            ldir
            ld hl, ew_kp3
            ld de, fn_e3_lib_poly3
            ld bc, 3
            ldir
hk_end:
#endasm
End Sub

' Lib: the Z80 (On calls it, so it's linked: it does nothing)
Private Sub Lib()
#asm
            ret
; E3's entries' first three bytes, kept while on. Each is one whole instruction (fill's is ld a,
; (pn)), so kept bytes and a jump on past them run E3's own code: ew_kfill is E3's filler itself,
; for Box (the HUD's bars stay filled)
@ew_kfill:  ds 3
            jp fn_e3_lib_fill + 3
@ew_kffi:   ds 3
@ew_kp3:    ds 3
; ============================================================================ the two entries
; ew_fill: (E3's fill) the polygon var_e3_pn points at arr_e3_pvx (x words; the y's 96 bytes on),
; outlined in the low byte of var_e3_pc
@ew_fill:
            pop hl                  ; called from Box (the HUD)? Its call is followed by ED 7B
            push hl                 ; nn nn (SP back) and 18 04 (jr over its two words): E3's own
            ld a, (hl)              ; filler, untouched
            cp #ED
            jr nz, ewf_go
            inc hl
            ld a, (hl)
            cp #7B
            jr nz, ewf_go
            inc hl
            inc hl
            inc hl
            ld a, (hl)
            cp #18
            jr nz, ewf_go
            inc hl
            ld a, (hl)
            cp 4
            jp z, ew_kfill
ewf_go:
            push iy
            push ix
            ld a, (var_e3_pn)
            cp 2
            jr c, ewf_end
            ld (ew_k), a
            call ew_start
            ld ix, arr_e3_pvx       ; the last point first: the closing edge
            ld a, (ew_k)
            dec a
            add a, a
            ld e, a
            ld d, 0
            add ix, de
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld (ew_px), hl
            ld l, (ix + 96)
            ld h, (ix + 97)
            ld (ew_py), hl
            ld ix, arr_e3_pvx
ewf_lp:
            ld hl, (ew_px)
            ld (ew_ax), hl
            ld hl, (ew_py)
            ld (ew_ay), hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld (ew_bx), hl
            ld (ew_px), hl
            ld l, (ix + 96)
            ld h, (ix + 97)
            ld (ew_by), hl
            ld (ew_py), hl
            push ix
            call ew_line2
            pop ix
            inc ix
            inc ix
            ld hl, ew_k
            dec (hl)
            jr nz, ewf_lp
ewf_end:
            call ew_done
            pop ix
            pop iy
            ret
; ew_ffi: (E3's ffi) the polygon of the B points listed at HL, all on the screen: point i's x at
; vpage + 64 + i, its y at vpage + 128 + i (bytes), outlined as ew_fill does
@ew_ffi:
            push iy
            push ix
            ld a, b
            cp 2
            jr c, ewi_end
            ld (ew_k), a
            ld de, ew_lst           ; the list copied first: it's in the model's data, in slots 6 and
            ld c, b                 ; 7 (E3's data pages), where the screen goes while drawing
            ld b, 0
            ldir
            ld hl, ew_lst
            ld (ew_ip), hl
            call ew_start
            ld hl, (ew_ip)          ; the last point first
            ld a, (ew_k)
            dec a
            ld e, a
            ld d, 0
            add hl, de
            ld a, (hl)
            call ewi_pt
            ld (ew_lx1), a
            ld a, e
            ld (ew_ly1), a
            ld hl, (ew_ip)
ewi_lp:
            ld a, (ew_lx1)          ; from the previous
            ld (ew_lx0), a
            ld a, (ew_ly1)
            ld (ew_ly0), a
            ld a, (hl)
            inc hl
            push hl
            call ewi_pt
            ld (ew_lx1), a
            ld a, e
            ld (ew_ly1), a
            ld hl, ew_pc            ; (the frame count, every eighth line)
            dec (hl)
            jr nz, ewi_np
            ld (hl), 8
            call fn_e3_lib_vpoll
ewi_np:
            call ew_draw
            pop hl
            ld a, (ew_k)
            dec a
            ld (ew_k), a
            jr nz, ewi_lp
ewi_end:
            call ew_done
            pop ix
            pop iy
            ret
; ewi_pt: A = a point's number -> A = its x, E = its y (191 at most: E3's fast range reaches 192)
ewi_pt:
            or #40
            ld l, a
            ld h, fn_e3_lib_vpage >> 8
            ld d, (hl)
            ld a, l
            xor #C0
            ld l, a
            ld e, (hl)
            ld a, e
            cp 192
            jr c, ewp_y
            ld e, 191
ewp_y:
            ld a, d
            ret
; ew_poly3: (E3's poly3) the polygon in E3's cla (cn records of x, y, z in the view, 6 bytes)
; crossing the planes in cmask: each edge cut to them on its own (so the polygon's cut edges,
; which aren't the model's, aren't drawn), projected by E3's proj, then cut to the screen and drawn
@ew_poly3:
            push iy
            push ix
            ld a, (var_e3_cn)
            cp 2
            jp c, ewp_end
            ld (ew_k), a
            call ew_start
            ld a, (var_e3_cn)       ; the last record first: the closing edge
            dec a
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, arr_e3_cla
            add hl, de
            ld (ew_ip), hl
            ld de, arr_e3_cla
ewp_lp:
            push de
            ld hl, (ew_ip)          ; the edge: ew_p (the previous) to ew_q (this one)
            ld de, ew_p
            ld bc, 6
            ldir
            pop hl
            push hl
            ld de, ew_q
            ld bc, 6
            ldir
            call ew_cut3
            jr c, ewp_nx            ; wholly outside
            ld ix, ew_p
            call ewp_pj
            ld (ew_ax), hl
            ld (ew_ay), de
            ld ix, ew_q
            call ewp_pj
            ld (ew_bx), hl
            ld (ew_by), de
            call ew_line2
ewp_nx:
            pop de
            ld (ew_ip), de
            ld hl, 6
            add hl, de
            ex de, hl
            ld hl, ew_k
            dec (hl)
            jr nz, ewp_lp
ewp_end:
            call ew_done
            pop ix
            pop iy
            ret
ewp_pj:                             ; the record at IX on the screen: HL = x, DE = y
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld c, (ix + 4)
            ld b, (ix + 5)
            jp fn_e3_lib_proj
; ew_cut3: the edge ew_p - ew_q cut to the planes in E3's cmask (as its clipper's: 0 z >= 16, 1
; z >= x / 4... the guard band) -> carry: wholly outside one
ew_cut3:
            ld a, (var_e3_cmask)
            ld (ew_m), a
            xor a
            ld (ew_pl), a
ec_pl:
            ld a, (ew_m)
            srl a
            ld (ew_m), a
            jr nc, ec_nx
            ld ix, ew_p
            call ec_dist
            ld (ew_dp), hl
            ld ix, ew_q
            call ec_dist
            ld (ew_dq), hl
            ld a, (ew_dp + 1)
            and h
            rlca
            ret c                   ; both outside: carry
            ld a, (ew_dp + 1)
            rlca
            jr nc, ec_q
            ld hl, ew_p             ; p outside: p moved to where it crosses
            ld de, ew_q
            ld bc, (ew_dp)
            ld ix, (ew_dq)
            call ec_cut
            jr ec_nx
ec_q:
            bit 7, h
            jr z, ec_nx
            ld hl, ew_q             ; q outside
            ld de, ew_p
            ld bc, (ew_dq)
            ld ix, (ew_dp)
            call ec_cut
ec_nx:
            ld a, (ew_pl)
            inc a
            ld (ew_pl), a
            cp 5
            jr c, ec_pl
            or a
            ret
; ec_dist: the record at IX's distance inside plane ew_pl (< 0: outside) -> HL (E3's cdist's)
ec_dist:
            ld a, (ew_pl)
            or a
            jr nz, ecd_1
            ld l, (ix + 4)
            ld h, (ix + 5)
            ld de, -16
            add hl, de
            ret
ecd_1:
            ld e, (ix + 0)
            ld d, (ix + 1)
            cp 3
            jr c, ecd_x
            ld e, (ix + 2)
            ld d, (ix + 3)
ecd_x:
            sra d
            rr e
            sra d
            rr e
            ld l, (ix + 4)
            ld h, (ix + 5)
            bit 0, a
            jr z, ecd_add
            or a
            sbc hl, de
            ret
ecd_add:
            add hl, de
            ret
; ec_cut: the record at HL (outside, its distance BC) moved toward the one at DE (inside, its
; distance IX) to where the edge crosses: t = |out| / (|out| + |in|) (E3's udivf), each part
; out + (in - out) t (E3's smul)
ec_cut:
            ld (ec_o), hl
            ld (ec_i), de
            ld h, b
            ld l, c
            call fn_e3_lib_absh
            push hl
            push ix
            pop hl
            call fn_e3_lib_absh
            pop de
            add hl, de
            ex de, hl               ; HL = |out|, DE = the sum
            call fn_e3_lib_udivf
            ld (ec_t), hl
            ld b, 3
ecc_lp:
            push bc
            ld hl, (ec_o)
            ld e, (hl)
            inc hl
            ld d, (hl)              ; out
            ld hl, (ec_i)
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a                 ; in
            push de
            or a
            sbc hl, de
            ld b, h
            ld c, l
            ld de, (ec_t)
            call fn_e3_lib_smul
            pop de
            add hl, de
            ex de, hl
            ld hl, (ec_o)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (ec_o), hl
            ld hl, (ec_i)
            inc hl
            inc hl
            ld (ec_i), hl
            pop bc
            djnz ecc_lp
            ret
ec_o:       dw 0
ec_i:       dw 0
ec_t:       dw 0
ew_m:       db 0
ew_pl:      db 0
ew_dp:      dw 0
ew_dq:      dw 0
ew_p:       ds 6
ew_q:       ds 6
; ew_start: the colour (the low byte of E3's pc), no third mapped yet
ew_start:
            ld a, (var_e3_pc)
            ld (ew_col), a
            ld a, 255
            ld (ew_cur3), a
            ret
; ew_done: E3's data pages back in slots 6 and 7, as its filler leaves them
ew_done:
            ld a, (fn_e3_lib_dpage)
            db #ED, #92, #56
            inc a
            db #ED, #92, #57
            ret
; ew_map: A = a third (0-2) of the buffer being drawn (E3's back): its two pages to slots 6, 7
ew_map:
            ld (ew_cur3), a
            push bc
            add a, a
            ld b, a
            ld a, (var_e3_back)
            add a, a
            add a, b
            db #ED, #92, #56
            inc a
            db #ED, #92, #57
            pop bc
            ret
ew_k:       db 0
ew_ip:      dw 0
ew_lst:     ds 64                   ; ew_ffi's list of points, copied
ew_px:      dw 0
ew_py:      dw 0
ew_ax:      dw 0                    ; a line: from
ew_ay:      dw 0
ew_bx:      dw 0                    ; to
ew_by:      dw 0
ew_lx0:     db 0                    ; the line cut to the screen (bytes)
ew_ly0:     db 0
ew_lx1:     db 0
ew_ly1:     db 0
ew_col:     db 0
ew_cur3:    db 255
ew_pc:      db 8
ew_full:    db 1                    ; (the box is the whole screen)
ew_wx0:     dw 0                    ; the box: the screen
ew_wy0:     dw 0
ew_wx1:     dw 255
ew_wy1:     dw 191
ew_tmp:     ds 4
; ============================================================================ the arithmetic and
; the lines (BASTION RUN's line engine's)
ew_neghl:
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; umul16x8: HL x A (unsigned) -> A:HL (24 bits; uses DE)
; um16: HL x DE (unsigned) -> HL:DE (32 bits; uses BC, A)
ew_um16:
            ld b, h
            ld c, l                 ; BC = x
            ld a, e
            ld l, d                 ; a = y0, l = y1
            ld d, c
            ld e, a
            mul d, e                ; x0 y0
            push de
            ld d, b
            ld e, a
            mul d, e                ; x1 y0
            ld a, l                 ; y1
            ld h, d
            ld l, e                 ; HL = x1 y0
            ld d, c
            ld e, a
            mul d, e                ; x0 y1
            add hl, de              ; the middle (17 bits)
            push af                 ; its carry
            ld d, b
            ld e, a
            mul d, e                ; x1 y1
            pop af
            jr nc, wum16a
            inc d
wum16a:
            ld a, h                 ; the middle's high byte
            ld b, l                 ; its low byte
            ex de, hl               ; HL = x1 y1 (+ the middle's carry << 8)
            ld e, a
            ld d, 0
            add hl, de              ; + the middle >> 8
            pop de                  ; x0 y0
            ld a, d
            add a, b                ; + the middle's low byte << 8
            ld d, a
            ret nc
            inc hl
            ret
; udiv: HL:DE / BC (unsigned, HL < BC) -> DE (the quotient), HL (what's left)
; udiv: HL:DE / BC (unsigned, HL < BC) -> DE (the quotient), HL (what's left)
ew_udiv:
            ld a, 16
wud_lp:
            sla e
            rl d
            adc hl, hl
            jr c, wud_sub
            sbc hl, bc
            jr nc, wud_one
            add hl, bc
            dec a
            jr nz, wud_lp
            ret
wud_sub:
            or a
            sbc hl, bc
wud_one:
            inc e
            dec a
            jr nz, wud_lp
            ret
; muldiv: HL = HL x DE / BC (signed; |DE| <= |BC| so it fits)
ew_muldiv:
            ld a, h
            xor d
            xor b
            push af                 ; the sign
            bit 7, h
            call nz, ew_neghl
            bit 7, d
            jr z, wmd1
            ex de, hl
            call ew_neghl
            ex de, hl
wmd1:
            bit 7, b
            jr z, wmd2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
wmd2:
            push bc
            call ew_um16             ; HL:DE
            pop bc
            ld a, h
            or l
            jr z, wmd3
            or a
            sbc hl, bc
            add hl, bc
            jr nc, wmd_big           ; (shouldn't: |DE| <= |BC|)
wmd3:
            call ew_udiv
            ex de, hl
            pop af
            bit 7, a
            ret z
            jp ew_neghl
wmd_big:
            ld hl, 32767
            pop af
            bit 7, a
            ret z
            jp ew_neghl
; ew_code: HL = x, DE = y -> A = the box's outcode: 1 left, 2 right, 4 above, 8 below (HL, DE
; kept; B used)
ew_code:
            push hl
            push de
            ld b, 0
            push hl
            ld de, (ew_wx0)
            or a
            sbc hl, de
            pop hl
            jp p, wvco1
            set 0, b
            jr wvco2
wvco1:
            ex de, hl
            ld hl, (ew_wx1)
            or a
            sbc hl, de
            jp p, wvco2
            set 1, b
wvco2:
            pop hl                  ; y
            push hl
            ld de, (ew_wy0)
            or a
            sbc hl, de
            jp p, wvco3
            set 2, b
            jr wvco4
wvco3:
            pop de
            push de
            ld hl, (ew_wy1)
            or a
            sbc hl, de
            jp p, wvco4
            set 3, b
wvco4:
            pop de
            pop hl
            ld a, b
            ret
; ew_line2: the line ew_ax, ew_ay - ew_bx, ew_by (16 bit) in ew_col, cut to the box
ew_line2:
            ld hl, ew_pc
            dec (hl)
            jr nz, wvl2_np
            ld (hl), 8
            call fn_e3_lib_vpoll
wvl2_np:
            ; all four in 0 - 255 and the y's under 192 (the box being the whole screen): no cutting
            ld a, (ew_full)
            or a
            jr z, wvl2_lp
            ld a, (ew_ax + 1)
            ld hl, ew_ay + 1
            or (hl)
            ld hl, ew_bx + 1
            or (hl)
            ld hl, ew_by + 1
            or (hl)
            jr nz, wvl2_lp
            ld a, (ew_ay)
            cp 192
            jr nc, wvl2_lp
            ld a, (ew_by)
            cp 192
            jp c, wvl2_in
wvl2_lp:
            ld hl, (ew_ax)
            ld de, (ew_ay)
            call ew_code
            ld (ew_tmp), a
            ld hl, (ew_bx)
            ld de, (ew_by)
            call ew_code
            ld (ew_tmp + 1), a
            ld b, a
            ld a, (ew_tmp)
            ld c, a
            or b
            jp z, wvl2_in
            ld a, c
            and b
            ret nz                  ; both off the same side
            ; cut the end that's out: A's if it is, else B's
            ld a, c
            or a
            jr nz, wvl2_a
            call wvl2_swap
            ld a, b
wvl2_a:
            ld (ew_tmp + 2), a
            bit 0, a
            jr nz, wvl2_l
            bit 1, a
            jr nz, wvl2_r
            bit 2, a
            jr nz, wvl2_t
            ; below: y = wy1, x = ax + (bx - ax) (wy1 - ay) / (by - ay)
            ld hl, (ew_wy1)
            jr wvl2_ty
wvl2_t:
            ld hl, (ew_wy0)
wvl2_ty:
            push hl
            ld de, (ew_ay)
            or a
            sbc hl, de
            ex de, hl               ; DE = y edge - ay
            ld hl, (ew_by)
            ld bc, (ew_ay)
            or a
            sbc hl, bc
            ld b, h
            ld c, l                 ; BC = by - ay
            ld hl, (ew_bx)
            push de
            ld de, (ew_ax)
            or a
            sbc hl, de              ; HL = bx - ax
            pop de
            call ew_muldiv
            ld de, (ew_ax)
            add hl, de
            ld (ew_ax), hl
            pop hl
            ld (ew_ay), hl
            jr wvl2_back
wvl2_l:
            ld hl, (ew_wx0)
            jr wvl2_lx
wvl2_r:
            ld hl, (ew_wx1)
wvl2_lx:
            push hl
            ld de, (ew_ax)
            or a
            sbc hl, de
            ex de, hl               ; DE = x edge - ax
            ld hl, (ew_bx)
            ld bc, (ew_ax)
            or a
            sbc hl, bc
            ld b, h
            ld c, l                 ; BC = bx - ax
            ld hl, (ew_by)
            push de
            ld de, (ew_ay)
            or a
            sbc hl, de              ; HL = by - ay
            pop de
            call ew_muldiv
            ld de, (ew_ay)
            add hl, de
            ld (ew_ay), hl
            pop hl
            ld (ew_ax), hl
wvl2_back:
            ld a, (ew_tmp)
            or a
            jp nz, wvl2_lp           ; A was cut: round again
            call wvl2_swap           ; B was (swapped to A): back
            jp wvl2_lp
wvl2_swap:
            ld hl, (ew_ax)
            ld de, (ew_bx)
            ld (ew_ax), de
            ld (ew_bx), hl
            ld hl, (ew_ay)
            ld de, (ew_by)
            ld (ew_ay), de
            ld (ew_by), hl
            ret
wvl2_in:
            ld a, (ew_ax)
            ld (ew_lx0), a
            ld a, (ew_ay)
            ld (ew_ly0), a
            ld a, (ew_bx)
            ld (ew_lx1), a
            ld a, (ew_by)
            ld (ew_ly1), a
            ; (fall into ew_draw)
; ew_draw: the line ew_lx0, ew_ly0 - ew_lx1, ew_ly1 (on the screen) in ew_col
ew_draw:
            ld a, (ew_lx1)
            ld hl, ew_lx0
            sub (hl)
            ld c, #2C               ; inc l
            jr nc, wvd_dxp
            neg
            ld c, #2D               ; dec l
wvd_dxp:
            ld e, a                 ; |dx|
            ld a, c
            ld (wvd_xs1), a
            ld (wvd_xs2), a
            ld a, (ew_ly1)
            ld hl, ew_ly0
            sub (hl)
            ld c, #24               ; inc h
            jr nc, wvd_dyp
            neg
            ld c, #25               ; dec h
wvd_dyp:
            ld d, a                 ; |dy|
            ld a, c
            ld (wvd_ys1), a
            ld (wvd_ys2), a
            ld a, (ew_ly0)
            rlca
            rlca
            and 3
            ld hl, ew_cur3
            cp (hl)
            call nz, ew_map
            ld a, (ew_ly0)
            and 63
            or #C0
            ld h, a
            ld a, (ew_lx0)
            ld l, a
            ld a, (ew_col)
            ld c, a
            ld a, e
            cp d
            jr c, wvd_ymaj
            ld b, e
            inc b                   ; dx + 1 (256: 0)
            ld a, e
            srl a                   ; the error: dx / 2
wvd_xl:
            ld (hl), c
wvd_xs1:
            inc l
            sub d
            jr nc, wvd_xn
            add a, e
wvd_ys1:
            inc h
            bit 6, h
            jr z, wvd_xw
wvd_xn:
            djnz wvd_xl
            ret
wvd_xw:
            call ew_wrap
            djnz wvd_xl
            ret
wvd_ymaj:
            ld b, d
            inc b
            ld a, d
            srl a
wvd_yl:
            ld (hl), c
wvd_ys2:
            inc h
            bit 6, h
            jr z, wvd_yw
wvd_yb:
            sub e
            jr nc, wvd_yn
            add a, d
wvd_xs2:
            inc l
wvd_yn:
            djnz wvd_yl
            ret
wvd_yw:
            call ew_wrap
            jr wvd_yb
; ew_wrap: H went past the third's end (#00: down, #BF: up): the next third in, H to its row
ew_wrap:
            push af
            ld a, h
            or a
            jr nz, wvwr_up
            ld a, (ew_cur3)
            inc a
            call ew_map
            ld h, #C0
            pop af
            ret
wvwr_up:
            ld a, (ew_cur3)
            dec a
            call ew_map
            ld h, #FF
            pop af
            ret
#endasm
End Sub
