' Vector3D - 3D wireframe shapes on the CPC screen (mode 1, pen 1): points in 8.8 fixed
' point (256 = 1.0), turned round the X, Y and Z axes and drawn in perspective as lines.
' Turn and Draw are Z80 (#asm): the maths and the line drawing run at machine code speed,
' on the real stack, with interrupts let in during the work (in turbo mode too: the
' interrupt only counts Ticks then - hooks and interrupt classes wait for normal mode). Lines are drawn with XOR, so drawing the same lines again takes them off and
' leaves what was under them (text) as it was.
' Based on B. Chiha's 3D frame demo for the TEC-1 (MIT licence, 2023), itself a Z80 version
' of a BASIC program in The Amstrad User, issue 69 (October 1990).
' Platforms: cpc, cpcmin, cpcfw and cpm on an Amstrad CPC (the Graphics class).
Option Explicit
Public Const MAXPOINTS = 24
Public Const MAXEDGES = 40

Private px(23) As Integer, py(23) As Integer, pz(23) As Integer   ' the shape, 8.8
Private sx(23) As Integer, sy(23) As Integer                      ' turned and projected: pixels
Private ox(23) As Integer, oy(23) As Integer                      ' what is on the screen at #C000
Private qx(23) As Integer, qy(23) As Integer                      ' ... and at #4000 (double buffering)
Private ea(39) As Integer, eb(39) As Integer                      ' edges: point numbers
Private np As Integer, ne As Integer, shown As Integer, shown2 As Integer
Private cx As Integer, cy As Integer, scl As Integer, dst As Integer
' working space for the Z80 code
Private spsave As Integer, vis As Integer, pk As Integer, pn As Integer, td As Integer
Private tx As Integer, ty As Integer, tz As Integer
Private sinx As Integer, cosx As Integer, siny As Integer, cosy As Integer, sinz As Integer, cosz As Integer
Private xs As Integer, ys As Integer, ek As Integer, en As Integer, ia As Integer, ib As Integer
Private xo As Integer, yo As Integer, dm As Integer                 ' Draw: this screen's old lines, d_change

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
  If Graphics.Buffering() Then
    Graphics.Flip
    Draw 0
  End If
End Sub

' Forget: the screen was cleared (Cls, Mode, double buffering switched): nothing to take off
Public Sub Forget()
  shown = 0
  shown2 = 0
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
            ei                      ; interrupts in while it works, in both modes (the
                                    ; real stack): Ticks keeps counting in turbo too
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

' Draw visible: with visible 0 the lines on the screen being drawn on go (each screen keeps
' its own, with double buffering); with visible not 0 the shape at its last Turn takes their
' place - only the edges that moved are drawn again (old line off, new line on, edge by
' edge), so a shape that hasn't moved a pixel doesn't flash - and with double buffering that
' screen is then shown (Graphics.Flip)
Public Sub Draw(ByVal visible As Integer)
#asm
            ld a, ({visible})
            ld ({vis}), a
            ld ({spsave}), sp
            ld sp, (ntc_csp)
            ei
            ld a, (gfx_base)        ; this screen's old lines: ox / oy (#C000) or qx / qy (#4000)
            cp #40
            jr z, d_b1
            ld hl, {ox}
            ld de, {oy}
            ld bc, {shown}
            jr d_b
d_b1:
            ld hl, {qx}
            ld de, {qy}
            ld bc, {shown2}
d_b:
            ld ({xo}), hl
            ld ({yo}), de
            ld ({ek}), bc
            ld a, ({vis})
            or a
            jr z, d_off
            ld a, (bc)
            or a
            jr z, d_all
            call d_change           ; only the edges that moved: old line off, new on
            jr d_keep
d_all:
            ld hl, {sx}             ; nothing on this screen yet: every edge
            ld ({xs}), hl
            ld hl, {sy}
            ld ({ys}), hl
            call d_edges
d_keep:
            ld hl, {sx}             ; what is on this screen now
            ld de, ({xo})
            ld bc, {MAXPOINTS} * 2
            ldir
            ld hl, {sy}
            ld de, ({yo})
            ld bc, {MAXPOINTS} * 2
            ldir
            ld hl, ({ek})
            ld (hl), 1
            call gfx_flip
            jr d_end
d_off:
            ld a, (bc)              ; the shape off this screen (XOR again)
            or a
            jr z, d_end
            ld hl, ({xo})
            ld ({xs}), hl
            ld hl, ({yo})
            ld ({ys}), hl
            call d_edges
            ld hl, ({ek})
            ld (hl), 0
d_end:
            di
            ld sp, ({spsave})
            ret
; d_same - A = a point's offset: Z when it is where it was (x and y, old and new)
d_same:
            ld c, a
            ld hl, ({xo})
            call d_word
            ex de, hl
            ld hl, {sx}
            ld a, c
            call d_word
            or a
            sbc hl, de
            ret nz
            ld hl, ({yo})
            ld a, c
            call d_word
            ex de, hl
            ld hl, {sy}
            ld a, c
            call d_word
            or a
            sbc hl, de
            ret
; d_one - the line of edge ia - ib from the arrays at xs / ys
d_one:
            ld hl, ({xs})
            ld a, ({ia})
            call d_word
            call d_mx
            ld (gfx_x0), hl
            ld hl, ({ys})
            ld a, ({ia})
            call d_word
            ld (gfx_y0), hl
            ld hl, ({xs})
            ld a, ({ib})
            call d_word
            call d_mx
            ld (gfx_x1), hl
            ld hl, ({ys})
            ld a, ({ib})
            call d_word
            ld (gfx_y1), hl
            jp gfx_line
; every edge, from the point arrays at xs / ys (pixels of mode 1: halved for mode 0,
; doubled for mode 2)
d_edges:
            xor a
            jr d_eg
; d_change - each edge whose ends moved since this screen's last Show: its old line off
; and its new one on, one edge after another (an edge that hasn't moved isn't touched, so
; it doesn't flash; a moving one is gone only for its own two lines)
d_change:
            ld a, 1
d_eg:
            ld ({dm}), a
            ld a, ({ne})
            or a
            ret z
            ld ({en}), a
            ld hl, 0
            ld ({pk}), hl
            call gfx_begin
d_elp:
            ld de, ({pk})
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
            ld a, ({dm})
            or a
            jr z, d_eone            ; every edge from xs / ys
            ld a, ({ia})            ; the same ends, old and new: nothing to do
            call d_same
            jr nz, d_cmove
            ld a, ({ib})
            call d_same
            jr z, d_enext
d_cmove:
            ld hl, ({xo})
            ld ({xs}), hl
            ld hl, ({yo})
            ld ({ys}), hl
            call d_one              ; the old line off
            ld hl, {sx}
            ld ({xs}), hl
            ld hl, {sy}
            ld ({ys}), hl
d_eone:
            call d_one
d_enext:
            ld hl, ({pk})
            inc hl
            inc hl
            ld ({pk}), hl
            ld hl, {en}
            dec (hl)
            jr nz, d_elp
            jp gfx_end
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
; HL = x in mode 1 pixels: in this mode's
d_mx:
            ld a, (ntc_smode)
            cp 1
            ret z
            jr c, d_m0
            add hl, hl
            ret
d_m0:
            sra h
            rr l
            ret
#endasm
End Sub
