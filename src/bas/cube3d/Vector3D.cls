' Vector3D - 3D wireframe shapes on the CPC screen (mode 1, pen 1): points in 8.8 fixed
' point (256 = 1.0), turned round the X, Y and Z axes and drawn in perspective as lines.
' Turn and Draw are Z80 (#asm): the maths and the line drawing run at machine code speed,
' on the real stack, with interrupts let in during the work in normal mode. Lines are drawn with XOR, so drawing the same lines again takes them off and
' leaves what was under them (text) as it was.
' Based on B. Chiha's 3D frame demo for the TEC-1 (MIT licence, 2023), itself a Z80 version
' of a BASIC program in The Amstrad User, issue 69 (October 1990).
' Platforms: cpc and cpcmin (the screen at #C000, as the program sets it up).
Option Explicit
Public Const MAXPOINTS = 32
Public Const MAXEDGES = 64

Private px(31) As Integer, py(31) As Integer, pz(31) As Integer   ' the shape, 8.8
Private sx(31) As Integer, sy(31) As Integer                      ' turned and projected: pixels
Private ox(31) As Integer, oy(31) As Integer                      ' what is on the screen now
Private ea(63) As Integer, eb(63) As Integer                      ' edges: point numbers
Private np As Integer, ne As Integer, shown As Integer
Private cx As Integer, cy As Integer, scl As Integer, dst As Integer
' working space for the Z80 code
Private spsave As Integer, vis As Integer, pk As Integer, pn As Integer, td As Integer
Private tx As Integer, ty As Integer, tz As Integer
Private sinx As Integer, cosx As Integer, siny As Integer, cosy As Integer, sinz As Integer, cosz As Integer
Private xs As Integer, ys As Integer, ek As Integer, en As Integer, ia As Integer, ib As Integer
Private lx0 As Integer, ly0 As Integer, lx1 As Integer, ly1 As Integer, ldx As Integer, ldy As Integer, lout As Integer, lsy As Integer

' Clear: no points, no edges (take the shape off the screen first with Hide)
Public Sub Clear()
  np = 0
  ne = 0
End Sub

' AddPoint(x, y, z): a point, 8.8 (keep them within -1.0 .. 1.0: -256 .. 256); its number,
' -1 when MAXPOINTS are in
Public Function AddPoint(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
  If np >= MAXPOINTS Then AddPoint = -1 : Exit Function
  px(np) = x : py(np) = y : pz(np) = z
  AddPoint = np
  np = np + 1
End Function

' AddEdge a, b: a line from point a to point b
Public Sub AddEdge(ByVal a As Integer, ByVal b As Integer)
  If ne >= MAXEDGES Then Exit Sub
  ea(ne) = a : eb(ne) = b
  ne = ne + 1
End Sub

' View x, y, scale, distance: the screen centre (pixels), the size, and how far away the
' shape is (8.8: 768 = 3.0; nearer is more perspective)
Public Sub View(ByVal x As Integer, ByVal y As Integer, ByVal scale As Integer, ByVal distance As Integer)
  cx = x : cy = y : scl = scale : dst = distance
End Sub

Public Function Points() As Integer
  Points = np
End Function

Public Function Edges() As Integer
  Edges = ne
End Function

' ScreenX(i), ScreenY(i): where point i is on the screen after the last Turn (pixels)
Public Function ScreenX(ByVal i As Integer) As Integer
  ScreenX = sx(i)
End Function

Public Function ScreenY(ByVal i As Integer) As Integer
  ScreenY = sy(i)
End Function

' Show: the shape at its last Turn on the screen (the one shown before goes). Hide: off
Public Sub Show()
  Draw 1
End Sub

Public Sub Hide()
  Draw 0
End Sub

' Turn ax, ay, az: the shape turned round X, then Y, then Z (0-255 = a full turn), and
' projected into screen pixels for the next Show
Public Sub Turn(ByVal ax As Integer, ByVal ay As Integer, ByVal az As Integer)
#asm
            ld a, ({ax})
            ld c, a
            ld a, ({ay})
            ld b, a
            ld a, ({az})
            ld e, a
            ld ({spsave}), sp       ; the real stack for the work (calls, pushes)
            ld sp, (ntc_csp)
            ld a, (ntc_nmode)       ; normal mode: interrupts in while it works
            or a
            jr z, t_di
            ei
t_di:
            push de
            push bc
            ld a, c
            call t_sc
            ld ({sinx}), de
            ld ({cosx}), hl
            pop bc
            ld a, b
            call t_sc
            ld ({siny}), de
            ld ({cosy}), hl
            pop de
            ld a, e
            call t_sc
            ld ({sinz}), de
            ld ({cosz}), hl
            ld hl, 0
            ld ({pk}), hl
            ld a, ({np})
            or a
            jp z, t_done
            ld ({pn}), a
t_pt:
            ld de, ({pk})
            ld hl, {px}
            call t_get
            ld ({tx}), hl
            ld hl, {py}
            call t_get
            ld ({ty}), hl
            ld hl, {pz}
            call t_get
            ld ({tz}), hl
            ; round X: y' = y cos - z sin, z' = y sin + z cos
            ld hl, ({ty})
            ld de, ({cosx})
            call t_mul
            push hl
            ld hl, ({tz})
            ld de, ({sinx})
            call t_mul
            ex de, hl
            pop hl
            or a
            sbc hl, de
            push hl
            ld hl, ({ty})
            ld de, ({sinx})
            call t_mul
            push hl
            ld hl, ({tz})
            ld de, ({cosx})
            call t_mul
            pop de
            add hl, de
            ld ({tz}), hl
            pop hl
            ld ({ty}), hl
            ; round Y: x' = x cos + z sin, z' = z cos - x sin
            ld hl, ({tx})
            ld de, ({cosy})
            call t_mul
            push hl
            ld hl, ({tz})
            ld de, ({siny})
            call t_mul
            pop de
            add hl, de
            push hl
            ld hl, ({tz})
            ld de, ({cosy})
            call t_mul
            push hl
            ld hl, ({tx})
            ld de, ({siny})
            call t_mul
            ex de, hl
            pop hl
            or a
            sbc hl, de
            ld ({tz}), hl
            pop hl
            ld ({tx}), hl
            ; round Z: x' = x cos - y sin, y' = x sin + y cos
            ld hl, ({tx})
            ld de, ({cosz})
            call t_mul
            push hl
            ld hl, ({ty})
            ld de, ({sinz})
            call t_mul
            ex de, hl
            pop hl
            or a
            sbc hl, de
            push hl
            ld hl, ({tx})
            ld de, ({sinz})
            call t_mul
            push hl
            ld hl, ({ty})
            ld de, ({cosz})
            call t_mul
            pop de
            add hl, de
            ld ({ty}), hl
            pop hl
            ld ({tx}), hl
            ; perspective: d = z + distance, at least 0.25
            ld hl, ({tz})
            ld de, ({dst})
            add hl, de
            bit 7, h
            jr nz, t_dmin
            ld a, h
            or a
            jr nz, t_dok
            ld a, l
            cp 64
            jr nc, t_dok
t_dmin:
            ld hl, 64
t_dok:
            ld ({td}), hl
            ld hl, ({tx})
            call t_prj
            ld de, ({cx})
            add hl, de
            ex de, hl
            ld hl, {sx}
            call t_put
            ld hl, ({ty})
            call t_prj
            ex de, hl
            ld hl, ({cy})
            or a
            sbc hl, de
            ex de, hl
            ld hl, {sy}
            call t_put
            ld hl, ({pk})
            inc hl
            inc hl
            ld ({pk}), hl
            ld hl, {pn}
            dec (hl)
            jp nz, t_pt
t_done:
            di
            ld sp, ({spsave})
            ret

; HL = an array, DE = offset: HL = the word there
t_get:
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret
; HL = an array, DE = the word for point pk
t_put:
            push de
            ld de, ({pk})
            add hl, de
            pop de
            ld (hl), e
            inc hl
            ld (hl), d
            ret
; A = angle: DE = sin, HL = cos (8.8)
t_sc:
            push af
            call t_tab
            ex de, hl
            pop af
            add a, 64
t_tab:
            ld l, a
            ld h, 0
            add hl, hl
            ld bc, t_sin
            add hl, bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret
; HL = a coordinate (8.8, signed), DE = sin / cos (-256 .. 256): HL = HL * DE / 256
t_mul:
            ld a, h
            xor d
            push af
            bit 7, h
            jr z, t_m1
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
t_m1:
            bit 7, d
            jr z, t_m2
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
t_m2:
            ld a, d
            or a
            jr nz, t_m9             ; 256: times 1
            ld a, e
            ex de, hl
            ld hl, 0
            ld c, l
            ld b, 8
t_mlp:
            add hl, hl
            rl c
            add a, a
            jr nc, t_mnx
            add hl, de
            jr nc, t_mnx
            inc c
t_mnx:
            djnz t_mlp
            ld l, h
            ld h, c
t_m9:
            pop af
            rla
            ret nc
t_neg:
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
; HL = a coordinate (8.8, signed): HL = pixels = HL * scale / td
t_prj:
            ld a, h
            push af
            bit 7, h
            call nz, t_neg
            ld de, ({scl})
            ld b, h                 ; DE:HL = HL * DE
            ld c, l
            ld hl, 0
            ld a, 16
t_pml:
            add hl, hl
            rl e
            rl d
            jr nc, t_pmn
            add hl, bc
            jr nc, t_pmn
            inc de
t_pmn:
            dec a
            jr nz, t_pml
            ld bc, ({td})           ; HL = DE:HL / BC (DE < BC)
            ld a, 16
t_dlp:
            add hl, hl
            ex de, hl
            adc hl, hl
            jr c, t_dsb
            or a
            sbc hl, bc
            jr nc, t_d1
            add hl, bc
            ex de, hl
            dec a
            jr nz, t_dlp
            jr t_dend
t_dsb:
            or a
            sbc hl, bc
t_d1:
            ex de, hl
            inc l
            dec a
            jr nz, t_dlp
t_dend:
            pop af
            rla
            ret nc
            jr t_neg
t_sin:
            dw 0, 6, 13, 19, 25, 31, 38, 44, 50, 56, 62, 68, 74, 80, 86, 92
            dw 98, 104, 109, 115, 121, 126, 132, 137, 142, 147, 152, 157, 162, 167, 172, 177
            dw 181, 185, 190, 194, 198, 202, 206, 209, 213, 216, 220, 223, 226, 229, 231, 234
            dw 237, 239, 241, 243, 245, 247, 248, 250, 251, 252, 253, 254, 255, 255, 256, 256
            dw 256, 256, 256, 255, 255, 254, 253, 252, 251, 250, 248, 247, 245, 243, 241, 239
            dw 237, 234, 231, 229, 226, 223, 220, 216, 213, 209, 206, 202, 198, 194, 190, 185
            dw 181, 177, 172, 167, 162, 157, 152, 147, 142, 137, 132, 126, 121, 115, 109, 104
            dw 98, 92, 86, 80, 74, 68, 62, 56, 50, 44, 38, 31, 25, 19, 13, 6
            dw 0, -6, -13, -19, -25, -31, -38, -44, -50, -56, -62, -68, -74, -80, -86, -92
            dw -98, -104, -109, -115, -121, -126, -132, -137, -142, -147, -152, -157, -162, -167, -172, -177
            dw -181, -185, -190, -194, -198, -202, -206, -209, -213, -216, -220, -223, -226, -229, -231, -234
            dw -237, -239, -241, -243, -245, -247, -248, -250, -251, -252, -253, -254, -255, -255, -256, -256
            dw -256, -256, -256, -255, -255, -254, -253, -252, -251, -250, -248, -247, -245, -243, -241, -239
            dw -237, -234, -231, -229, -226, -223, -220, -216, -213, -209, -206, -202, -198, -194, -190, -185
            dw -181, -177, -172, -167, -162, -157, -152, -147, -142, -137, -132, -126, -121, -115, -109, -104
            dw -98, -92, -86, -80, -74, -68, -62, -56, -50, -44, -38, -31, -25, -19, -13, -6
#endasm
End Sub

' Draw visible: what is on the screen goes; with visible not 0 the shape at its last Turn
' is drawn
Public Sub Draw(ByVal visible As Integer)
#asm
            ld a, ({visible})
            ld ({vis}), a
            ld ({spsave}), sp
            ld sp, (ntc_csp)
            ld a, (ntc_nmode)
            or a
            jr z, d_di
            ei
d_di:
            ld a, ({shown})
            or a
            jr z, d_new
            ld hl, {ox}             ; take the old lines off (XOR again)
            ld ({xs}), hl
            ld hl, {oy}
            ld ({ys}), hl
            call d_edges
d_new:
            xor a
            ld ({shown}), a
            ld a, ({vis})
            or a
            jr z, d_end
            ld hl, {sx}
            ld ({xs}), hl
            ld hl, {sy}
            ld ({ys}), hl
            call d_edges
            ld hl, {sx}             ; what is shown now
            ld de, {ox}
            ld bc, 64
            ldir
            ld hl, {sy}
            ld de, {oy}
            ld bc, 64
            ldir
            ld a, 1
            ld ({shown}), a
d_end:
            di
            ld sp, ({spsave})
            ret

; every edge, from the point arrays at xs / ys
d_edges:
            ld a, ({ne})
            or a
            ret z
            ld ({en}), a
            ld hl, 0
            ld ({ek}), hl
d_elp:
            ld de, ({ek})
            ld hl, {ea}
            add hl, de
            ld a, (hl)
            and 31
            add a, a
            ld ({ia}), a
            ld hl, {eb}
            add hl, de
            ld a, (hl)
            and 31
            add a, a
            ld ({ib}), a
            ld hl, ({xs})
            ld a, ({ia})
            call d_word
            ld ({lx0}), hl
            ld hl, ({ys})
            ld a, ({ia})
            call d_word
            ld ({ly0}), hl
            ld hl, ({xs})
            ld a, ({ib})
            call d_word
            ld ({lx1}), hl
            ld hl, ({ys})
            ld a, ({ib})
            call d_word
            ld ({ly1}), hl
            call d_line
            ld hl, ({ek})
            inc hl
            inc hl
            ld ({ek}), hl
            ld hl, {en}
            dec (hl)
            jr nz, d_elp
            ret
d_word:
            add a, l
            ld l, a
            adc a, h
            sub l
            ld h, a
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ret
; HL = x: carry when it is off the screen (not 0 .. 319)
d_cx:
            bit 7, h
            scf
            ret nz
            ld de, 320
            or a
            sbc hl, de
            ccf
            ret
; HL = y: carry when not 0 .. 199
d_cy:
            bit 7, h
            scf
            ret nz
            ld de, 200
            or a
            sbc hl, de
            ccf
            ret
; a line from (lx0, ly0) to (lx1, ly1), XOR, pen 1; off the screen: not drawn
d_line:
            ld hl, ({lx0})
            call d_cx
            ret c
            ld hl, ({lx1})
            call d_cx
            ret c
            ld hl, ({ly0})
            call d_cy
            ret c
            ld hl, ({ly1})
            call d_cy
            ret c
            ld hl, ({lx1})          ; left to right
            ld de, ({lx0})
            or a
            sbc hl, de
            jr nc, d_lr
            ld hl, ({lx0})
            ld de, ({lx1})
            ld ({lx0}), de
            ld ({lx1}), hl
            ld hl, ({ly0})
            ld de, ({ly1})
            ld ({ly0}), de
            ld ({ly1}), hl
            ld hl, ({lx1})
            ld de, ({lx0})
            or a
            sbc hl, de
d_lr:
            ld ({ldx}), hl
            ld hl, ({ly1})
            ld de, ({ly0})
            or a
            sbc hl, de
            ld b, 0                 ; B = 0: down, 1: up
            jr nc, d_dy
            inc b
            call d_neg
d_dy:
            ld ({ldy}), hl
            ld a, b
            ld ({lsy}), a
            ld a, ({ly0})           ; HL = the address of (x0, y0)
            ld c, a
            and #F8
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de              ; (y / 8) * 80
            ld a, c
            and 7
            add a, a
            add a, a
            add a, a
            add a, #C0
            add a, h
            ld h, a
            ld de, ({lx0})
            srl d
            rr e
            srl d
            rr e
            add hl, de
            ld a, ({lx0})           ; C = the pixel's bit
            and 3
            ld b, a
            ld a, #80
            jr z, d_mk
d_mlp:
            rrca
            djnz d_mlp
d_mk:
            ld c, a
            ld a, (hl)              ; the first pixel
            xor c
            ld (hl), a
            push hl
            ld hl, ({ldx})
            ld de, ({ldy})
            or a
            sbc hl, de
            pop hl
            jp c, d_ymaj
            ; x major: count dx, error dx / 2, IX = dy
            ld de, ({ldy})
            push de
            pop ix
            ld de, ({ldx})
            call d_cnt
            ret z
            ld de, ({ldx})
            srl d
            rr e
            ld a, ({lsy})
            or a
            jp nz, d_xu
d_xd:
            srl c                   ; x + 1
            bit 3, c
            jr z, d_xd1
            ld c, #80
            inc hl
d_xd1:
            ld a, e                 ; error - dy
            sub ixl
            ld e, a
            ld a, d
            sbc a, ixh
            ld d, a
            jp p, d_xd2
            push hl                 ; error + dx, y + 1
            ld hl, ({ldx})
            add hl, de
            ex de, hl
            pop hl
            ld a, h
            add a, 8
            ld h, a
            jr nc, d_xd2
            push de
            ld de, #C050
            add hl, de
            pop de
d_xd2:
            ld a, (hl)
            xor c
            ld (hl), a
            djnz d_xd
            ld a, ({lout})
            dec a
            ld ({lout}), a
            jr nz, d_xd
            ret
d_xu:
            srl c
            bit 3, c
            jr z, d_xu1
            ld c, #80
            inc hl
d_xu1:
            ld a, e
            sub ixl
            ld e, a
            ld a, d
            sbc a, ixh
            ld d, a
            jp p, d_xu2
            push hl                 ; error + dx, y - 1
            ld hl, ({ldx})
            add hl, de
            ex de, hl
            pop hl
            ld a, h
            sub 8
            ld h, a
            cp #C0
            jr nc, d_xu2
            push de
            ld de, #3FB0
            add hl, de
            pop de
d_xu2:
            ld a, (hl)
            xor c
            ld (hl), a
            djnz d_xu
            ld a, ({lout})
            dec a
            ld ({lout}), a
            jr nz, d_xu
            ret
d_ymaj:
            ; y major: count dy, error dy / 2, IX = dx
            ld de, ({ldx})
            push de
            pop ix
            ld de, ({ldy})
            call d_cnt
            ret z
            ld de, ({ldy})
            srl d
            rr e
            ld a, ({lsy})
            or a
            jp nz, d_yu
d_yd:
            ld a, h                 ; y + 1
            add a, 8
            ld h, a
            jr nc, d_yd1
            push de
            ld de, #C050
            add hl, de
            pop de
d_yd1:
            ld a, e                 ; error - dx
            sub ixl
            ld e, a
            ld a, d
            sbc a, ixh
            ld d, a
            jp p, d_yd2
            push hl                 ; error + dy, x + 1
            ld hl, ({ldy})
            add hl, de
            ex de, hl
            pop hl
            srl c
            bit 3, c
            jr z, d_yd2
            ld c, #80
            inc hl
d_yd2:
            ld a, (hl)
            xor c
            ld (hl), a
            djnz d_yd
            ld a, ({lout})
            dec a
            ld ({lout}), a
            jr nz, d_yd
            ret
d_yu:
            ld a, h                 ; y - 1
            sub 8
            ld h, a
            cp #C0
            jr nc, d_yu1
            push de
            ld de, #3FB0
            add hl, de
            pop de
d_yu1:
            ld a, e
            sub ixl
            ld e, a
            ld a, d
            sbc a, ixh
            ld d, a
            jp p, d_yu2
            push hl
            ld hl, ({ldy})
            add hl, de
            ex de, hl
            pop hl
            srl c
            bit 3, c
            jr z, d_yu2
            ld c, #80
            inc hl
d_yu2:
            ld a, (hl)
            xor c
            ld (hl), a
            djnz d_yu
            ld a, ({lout})
            dec a
            ld ({lout}), a
            jr nz, d_yu
            ret
; DE = the count: B = its low byte (0 = 256), lout = the rounds of B; Z when DE = 0
d_cnt:
            ld a, d
            or e
            ret z
            ld b, e
            ld a, e
            or a
            jr z, d_cn1
            inc d
d_cn1:
            ld a, d
            ld ({lout}), a
            or 1                    ; NZ
            ret
d_neg:
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
#endasm
End Sub
