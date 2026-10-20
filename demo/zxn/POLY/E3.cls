' E3 - POLY's 3D engine, in Z80: filled, shaded polygons on Layer 2 (256 x 192, 256 colours, two
' buffers), objects turned and moved by a camera, cut to the view, hidden faces removed.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The screen: Layer 2 has two buffers, 16K banks 12-14 and 15-17 (pages 24-29, 30-35). One is shown
' (NextReg #12) while the other is drawn: Begin clears it (the zxnDMA filling it 16K at a time), Flip
' shows it. Drawing maps the buffer 64 rows at a time into MMU slots 6 and 7 (#C000-#FFFF) and puts
' slots 6 and 7 back (pages 10, 11) when it's done.
'
' The camera: cm(0-8), its right, up and forward in the world (s1.14: 16384 is 1), and cp, where it
' is (24.8 bits each way). The view: x right, y up, z ahead; the screen x = 128 + x * 128 / z,
' y = 96 - y * 128 / z (90 degrees across).
'
' An object: a model (E3Data: int8 vertices, convex faces with their normals), where it is (op,
' world units), how it's turned (oa about y, then ob about x: 256 to the turn) and its size (osc:
' a model unit is 2^osc world units, osc 0-6).
' ObjPrep says where it is in the view (oc) and whether it's seen (ovis); ObjDraw draws it: its
' faces turned away are left out (convex), the rest shaded by the sun (sun, s1.14 in the world) in
' 31 steps (16 shades and the 15 between, dithered), cut to the view where they cross its edges.
' Objects are drawn far to near (the caller sorts them by oc(2)).
'
' A polygon (2D): Poly n, c fills pvx(0..n-1), pvy(0..n-1) (clockwise on the screen; any size: it's
' cut to the screen). Each row's span is filled by pushing two pixels at a time with the stack (2
' pixels in 11 T). NTC runs with interrupts off.
'
' The Z80 lives in Lib (one block: its labels are fn_e3_lib_...): the multiplies, the polygon
' filler, the projection, the 3D clipper and the object pipeline. The Subs BASIC calls are thin.
Option Explicit

Public pvx(47) As Integer, pvy(47) As Integer   ' a polygon's screen vertices
Public cm(8) As Integer                          ' the camera: right, up, forward (s1.14)
Public cp(5) As Integer                          ' the camera's position: 3 x 32 bits (24.8)
Public sun(2) As Integer                         ' the sun's direction in the world (s1.14)
Public op(2) As Integer, oa As Integer, ob As Integer   ' an object: position, turned by oa (about y), ob (about x)
Public omod As Integer, osc As Integer, orad As Integer
Public oc(2) As Integer, ovis As Integer         ' ObjPrep: the object in the view, seen (0, 1, 2)
Public pn As Integer, pc As Integer              ' Fill: the vertices, the colours (low: even pixels)
Public obj(511) As Integer, nobj As Integer      ' the scene: 64 objects of 8 words (Scene)
Public nstar As Integer                          ' how many stars (Stars: E3Data's, up to NStars)
Public ppos(2) As Integer, prad As Integer, pcol As Integer   ' the planet: middle, radius (/ 256), ramp
Public palt As Integer                           ' Planet: the height over it (world units, to 32767)
Public aimp(2) As Integer, aimv(2) As Integer, aimk As Integer   ' Aim: a point (/ 256), in the view
Public pup(2) As Integer                         ' Planet: up (away from its middle) in the view (s1.14)
Private back As Integer, front As Integer, sps As Integer, six As Integer
Private pgw As Integer
Private suc(2) As Integer                        ' the sun in the view
Private od(2) As Integer                         ' the object from the camera (world)
Private ccl(8) As Integer                        ' C's columns
Private oe(2) As Integer, osn(2) As Integer      ' the camera and the sun in the model
Private ov(191) As Integer                       ' the vertices in the view (64 x x, y, z)
Private osx(63) As Integer, osy(63) As Integer   ' and on the screen
Private cla(143) As Integer, clb(143) As Integer ' the clipper's lists (48 x x, y, z)
Private cn As Integer, cmask As Integer
Private ta As Integer

' Init: Layer 2 on, its palette (E3Data's ramps), both buffers cleared, buffer 12 shown, the
' camera at 0, 0, 0 facing +z
Public Sub Init()
  back = 15 : front = 12
  Nx.Reg &H12, front
  Nx.Reg &H70, 0                         ' 256 x 192
  Nx.Reg &H1C, 1
  Nx.Reg &H18, 1 : Nx.Reg &H18, 254 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191   ' (columns 0 and 255 hidden: polygons are cut to 1..255)
  Nx.Reg &H14, &HE3                      ' (nothing see-through but colour #E3's)
  Nx.Reg &H15, 0                         ' sprites over Layer 2 over the ULA
  Out &H123B, 2
  Palette E3Data.Pal()
  ta = E3Data.REdge() : ta = E3Data.RProj() : ta = E3Data.SqrtT() : ta = E3Data.Sines() : ta = E3Data.ModelTab() : ta = E3Data.ModelData() : ta = E3Data.Stars() : ta = E3Data.CitySite() : ta = E3Data.CityMap() : ta = E3Data.CityBlocks() : ta = E3Data.Font() : ta = E3Data.FontIx()   ' (linked: the Z80 reads them)
  Lib
  CamReset
  sun(0) = -6000 : sun(1) = 12000 : sun(2) = -9000
  nstar = E3Data.NStars
  Begin 0 : Flip
  Begin 0 : Flip
End Sub

' CamReset: the camera at 0, 0, 0, facing +z, up +y
Public Sub CamReset()
  Dim k As Integer
  For k = 0 To 8
    cm(k) = 0
  Next
  cm(0) = 16384 : cm(4) = 16384 : cm(8) = 16384
  For k = 0 To 5
    cp(k) = 0
  Next
End Sub

' Palette a: Layer 2's first palette from the 512 bytes at a (9 bit colours)
Private Sub Palette(ByVal a As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld bc, #243B
            ld a, #43
            out (c), a
            inc b
            ld a, %00010000         ; Layer 2's first palette, auto increment
            out (c), a
            dec b
            ld a, #40
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #44
            out (c), a
            inc b
            ld d, 0                 ; 256 colours, 2 bytes each
pl_lp:
            ld a, (hl)
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            dec d
            jr nz, pl_lp
#endasm
End Sub

' Begin c: start a frame in the hidden buffer, filled with colour c (c < 0: left as it is)
Public Sub Begin(ByVal c As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld ({sps}), sp
            ld sp, (ntc_csp)
            bit 7, h
            jr nz, bg_end
            ld a, l
            ld (bg_src), a
            ld a, ({back})
            add a, a
            ld e, a                 ; the buffer's first page
            ld b, 3
bg_bank:
            ld a, e
            db #ED, #92, #56
            inc a
            db #ED, #92, #57
            push bc
            ld hl, bg_prog
            ld bc, 14 * 256 + #6B
            otir
            pop bc
            inc e
            inc e
            djnz bg_bank
            ld a, 10
            db #ED, #92, #56
            ld a, 11
            db #ED, #92, #57
            jr bg_end
bg_prog:
            db #83, #7D
            dw bg_src
            dw #4000
            db #24, #10, #AD
            dw #C000
            db #82, #CF, #87
bg_src:     db 0
bg_end:
            ld sp, ({sps})
#endasm
End Sub

' Flip: the buffer just drawn shown (call it straight after Frame), the other one to draw next
Public Sub Flip()
  Dim t As Integer
  Nx.Reg &H12, back
  t = front : front = back : back = t
End Sub

' Poly n, c: the convex polygon pvx(0..n-1), pvy(0..n-1) (clockwise on the screen) in colour c
Public Sub Poly(ByVal n As Integer, ByVal c As Integer)
  pn = n : pc = (c And 255) * 257
  Fill
End Sub

' Fill: the polygon pvx, pvy (pn vertices) in the colours pc (low byte: the even pixels of the even
' rows, high byte: the odd ones; swapped on odd rows - the same twice is a plain colour)
Public Sub Fill()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            call fn_e3_lib_fill
            ld sp, ({sps})
#endasm
End Sub

' CamPos x, y, z: the camera to x, y, z (world units)
Public Sub CamPos(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer)
#asm
            ld de, {cp}
            ld b, 3
cps_lp:
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a                 ; the value
            xor a
            ld (de), a              ; the fraction
            inc de
            ld a, l
            ld (de), a
            inc de
            ld a, h
            ld (de), a
            inc de
            rla
            sbc a, a
            ld (de), a              ; the sign
            inc de
            djnz cps_lp
#endasm
End Sub

' CamAt k, a, b: the camera's position k (0 x, 1 y, 2 z) to a * 256 + b (b 0..255): to 8 million
' each way
Public Sub CamAt(ByVal k As Integer, ByVal a As Integer, ByVal b As Integer)
#asm
            pop hl
            ld a, (hl)              ; k
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, {cp}
            add hl, de
            ex de, hl               ; DE: the position
            pop hl
            ld c, (hl)              ; a
            inc hl
            ld b, (hl)
            pop hl
            ld a, (hl)              ; b
            ex de, hl
            ld (hl), 0
            inc hl
            ld (hl), a
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
#endasm
End Sub

' CamGet(k): the camera's position k (0 x, 1 y, 2 z): the low 16 bits of its whole units
Public Function CamGet(ByVal k As Integer) As Integer
#asm
            pop hl
            ld a, (hl)              ; k
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, {cp} + 1
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' CamTurn p, y, r: the camera turned about its own right (p: up), up (y: right) and forward
' (r: clockwise) axes by p, y, r / 16384 radians (small: under 3000), then squared up again
Public Sub CamTurn(ByVal p As Integer, ByVal y As Integer, ByVal r As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (ct_p), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (ct_y), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (ct_r), de
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            ld hl, (ct_p)           ; pitch: F toward U
            ld ix, {cm} + 12
            ld iy, {cm} + 6
            call fn_e3_lib_rotp
            ld hl, (ct_y)           ; yaw: F toward R
            ld ix, {cm} + 12
            ld iy, {cm}
            call fn_e3_lib_rotp
            ld hl, (ct_r)           ; roll: U toward R
            ld ix, {cm} + 6
            ld iy, {cm}
            call fn_e3_lib_rotp
            call fn_e3_lib_renorm
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
            jr ct_end
ct_p:       dw 0
ct_y:       dw 0
ct_r:       dw 0
ct_end:
#endasm
End Sub

' CamMove s: the camera moved forward s / 16 world units
Public Sub CamMove(ByVal s As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            ld (cmv_s), de
            ld ix, {cm} + 12
            ld iy, {cp}
            ld b, 3
cmv_lp:
            push bc
            ld c, (ix + 0)
            ld b, (ix + 1)
            ld de, (cmv_s)
            call fn_e3_lib_ssmul    ; HL:DE = F * s (s1.14 x 12.4) - the move is that >> 10 (24.8)
            ld b, 2
cmv_sh:
            sra h
            rr l
            rr d
            rr e
            djnz cmv_sh             ; >> 2, then the top 3 bytes are >> 10
            ld a, h                 ; (the sign)
            rla
            sbc a, a
            ld c, a
            ld a, (iy + 0)
            add a, d
            ld (iy + 0), a
            ld a, (iy + 1)
            adc a, l
            ld (iy + 1), a
            ld a, (iy + 2)
            adc a, h
            ld (iy + 2), a
            ld a, (iy + 3)
            adc a, c
            ld (iy + 3), a
            inc ix
            inc ix
            ld de, 4
            add iy, de
            pop bc
            djnz cmv_lp
            ld ix, ({six})
            ld sp, ({sps})
            jr cmv_end
cmv_s:      dw 0
cmv_end:
#endasm
End Sub

' Stars: the stars (nstar of E3Data's) in the view, a pixel each
Public Sub Stars()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_stars
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' Planet: the planet (ppos, prad, pcol) drawn: a lit disc, or near it the ground below the horizon
Public Sub Planet()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_planet
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' City: the city (E3Data CitySite, CityMap) drawn when the camera is near it
Public Sub City()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_city
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' Aim: the point aimp (x, y, z / 256 in the world) in the view: aimv, shifted right by aimk
Public Sub Aim()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_aim
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' Char x, y, c, col: character c (ASCII 32..95) at pixel x, y (its 5 x 7 set pixels) in colour col
Public Sub Char(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer, ByVal col As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (fn_e3_lib_tx_x), a
            pop hl
            ld a, (hl)
            ld (fn_e3_lib_tx_y), a
            pop hl
            ld a, (hl)
            ld (ch_c), a
            pop hl
            ld a, (hl)
            ld (fn_e3_lib_tx_c), a
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld a, (ch_c)
            call fn_e3_lib_chr
            ld sp, ({sps})
            jr ch_e
ch_c:       db 0
ch_e:
#endasm
End Sub

' Text x, y, s, col: s at pixel x, y (6 pixels a character) in colour col
Public Sub Text(ByVal x As Integer, ByVal y As Integer, ByVal s As String, ByVal col As Integer)
  Dim k As Integer
  For k = 1 To Len(s)
    Char x, y, Asc(Mid$(s, k, 1)), col
    x = x + 6
  Next
End Sub

' Num x, y, v, n, col: v (0..32767) in n digits at pixel x, y in colour col (leading 0s as spaces)
Public Sub Num(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer, ByVal n As Integer, ByVal col As Integer)
  Dim k As Integer, d As Integer, p As Integer
  If v < 0 Then v = 0
  x = x + (n - 1) * 6
  For k = 1 To n
    d = v Mod 10 : v = v \ 10
    If d > 0 Or v > 0 Or k = 1 Then Char x, y, 48 + d, col
    x = x - 6
  Next
End Sub

' Scene: the objects in obj (nobj of them: ObjSet) turned, sorted far to near and drawn
Public Sub Scene()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_scene
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' ObjSet k, x, y, z, kind, osc, rad, da, db, dc: scene object k: at x, y, z (world), of kind
' (E3Data's ModelTab: its near and far models), size osc, radius rad (world units), turning by da,
' db (256 to the turn) each frame, a dot of colour dc when tiny
Public Sub ObjSet(ByVal k As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal kind As Integer, ByVal sc As Integer, ByVal rad As Integer, ByVal da As Integer, ByVal db As Integer, ByVal dc As Integer)
  Dim p As Integer
  p = k * 8
  obj(p) = x : obj(p + 1) = y : obj(p + 2) = z
  obj(p + 3) = 0
  obj(p + 4) = (da And 255) + (db And 255) * 256
  obj(p + 5) = kind + sc * 256
  obj(p + 6) = rad
  obj(p + 7) = dc
End Sub

' ObjCull: as ObjPrep, by the camera to 1/128 (for sorting and leaving out: cheap)
Public Sub ObjCull()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_oprep8
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' ObjPrep: the object op (its radius orad, world units, under 4000) in the view: oc, and ovis 0 (not
' seen: behind, outside the view or too far), 1 (all in the view), 2 (crossing its edges)
Public Sub ObjPrep()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_oprep
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' ObjDraw: the object op, oa, ob, omod, osc (orad) drawn
Public Sub ObjDraw()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld ({six}), ix
            push iy
            call fn_e3_lib_odraw
            pop iy
            ld ix, ({six})
            ld sp, ({sps})
#endasm
End Sub

' Lib: the Z80 the rest calls (called once by Init so it's linked: it does nothing)
Private Sub Lib()
#asm
            ret
; ============================================================================ the multiplies
; umul: BC x DE (unsigned) -> HL:DE
umul:
            ld a, e
            ld l, d                 ; (d0 kept in L)
            ld d, c
            mul d, e                ; c * e0
            push de
            ld d, b
            ld e, a
            mul d, e                ; b * e0
            ld a, l
            ld h, d
            ld l, e
            ld d, c
            ld e, a
            mul d, e                ; c * d0
            add hl, de              ; the middle (17 bits)
            ld c, 0
            rl c
            ld d, b
            ld e, a
            mul d, e                ; b * d0
            ld a, h
            ld b, l
            ex de, hl               ; HL = b * d0
            ld e, a
            ld d, c
            add hl, de              ; + the middle's top
            pop de                  ; c * e0
            ld a, d
            add a, b                ; + the middle's bottom
            ld d, a
            ret nc
            inc hl
            ret
; smul: BC (signed) x DE (unsigned) -> HL:DE (signed)
smul:
            bit 7, b
            jp z, umul
            push de
            call umul
            ex (sp), hl
            ex de, hl
            ex (sp), hl
            or a
            sbc hl, de
            pop de
            ret
; ssmul: BC x DE (both signed) -> HL:DE
ssmul:
            push bc
            push de
            call umul
            ld (ss_lo), de
            pop de
            pop bc
            bit 7, b
            jr z, ss_1
            or a
            sbc hl, de
ss_1:
            bit 7, d
            jr z, ss_2
            or a
            sbc hl, bc
ss_2:
            ld de, (ss_lo)
            ret
ss_lo:      dw 0
; m14: (BC x DE) >> 14 -> HL (s1.14 products)
m14:
            call ssmul
            ld a, d
            add a, a
            adc hl, hl
            add a, a
            adc hl, hl
            ret
; m816: A (signed) x DE (signed) -> A:HL (24 bits signed)
m816:
            ld c, a
            xor d
            ld (m8_sg), a
            ld a, c
            or a
            jp p, m8_1
            neg
m8_1:
            ld c, a                 ; |a|
            bit 7, d
            jr z, m8_2
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a                 ; |de|
m8_2:
            ld a, d
            ld d, c
            mul d, e                ; |a| * e
            ld h, d
            ld l, e
            ld e, a
            ld d, c
            mul d, e                ; |a| * d
            ld a, e
            add a, h
            ld h, a
            ld a, d
            adc a, 0
            ld c, a
            ld a, (m8_sg)
            or a
            ld a, c
            ret p
            ld c, a
            xor a
            sub l
            ld l, a
            ld a, 0
            sbc a, h
            ld h, a
            ld a, 0
            sbc a, c
            ret
m8_sg:      db 0
; udivf: HL / DE (unsigned, HL < DE) -> HL = HL * 65536 / DE (HL >= DE: 65535)
udivf:
            push hl
            or a
            sbc hl, de
            pop hl
            jr c, ud_go
            ld hl, 65535
            ret
ud_go:
            ld bc, 0
            ld a, 16
ud_lp:
            add hl, hl
            jr c, ud_sub
            or a
            sbc hl, de
            jr nc, ud_one
            add hl, de
            sla c
            rl b
            dec a
            jr nz, ud_lp
            jr ud_end
ud_sub:
            or a
            sbc hl, de
ud_one:
            scf
            rl c
            rl b
            dec a
            jr nz, ud_lp
ud_end:
            ld h, b
            ld l, c
            ret
; absh: HL = |HL|
absh:
            bit 7, h
            ret z
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ret
; mrow: (IX: 3 words) . (IY: 3 words) >> 14 -> HL (32 bit sum)
mrow:
            ld c, (ix + 0)
            ld b, (ix + 1)
            ld e, (iy + 0)
            ld d, (iy + 1)
            call ssmul
            ld (mr_l), de
            ld (mr_h), hl
            ld c, (ix + 2)
            ld b, (ix + 3)
            ld e, (iy + 2)
            ld d, (iy + 3)
            call ssmul
            call mr_add
            ld c, (ix + 4)
            ld b, (ix + 5)
            ld e, (iy + 4)
            ld d, (iy + 5)
            call ssmul
            call mr_add
            ld hl, (mr_h)
            ld a, (mr_l + 1)
            add a, a
            adc hl, hl
            add a, a
            adc hl, hl
            ret
mr_add:
            push hl
            ld hl, (mr_l)
            add hl, de
            ld (mr_l), hl
            pop de
            ld hl, (mr_h)
            adc hl, de
            ld (mr_h), hl
            ret
mr_l:       dw 0
mr_h:       dw 0
; ============================================================================ the camera
; rotp: rows IX (A) and IY (B) of the camera turned by HL / 16384 radians: A = A c + B s,
; B = B c - A s (s = a, c = 1 - a^2 / 2)
rotp:
            ld a, h
            or l
            ret z
            ld (rp_s), hl
            ld b, h
            ld c, l
            ld d, h
            ld e, l
            call ssmul              ; a^2 (s2.28) -> a^2 / 2 in s1.14 is HL:DE >> 15
            ld a, d
            add a, a
            adc hl, hl              ; HL = a^2 >> 15
            ex de, hl
            ld hl, 16384
            or a
            sbc hl, de
            ld (rp_c), hl
            ld b, 3
rp_lp:
            push bc
            ld c, (ix + 0)          ; A c
            ld b, (ix + 1)
            ld de, (rp_c)
            call m14
            ld (rp_t), hl
            ld c, (iy + 0)          ; + B s
            ld b, (iy + 1)
            ld de, (rp_s)
            call m14
            ld de, (rp_t)
            add hl, de
            ld (rp_na), hl
            ld c, (iy + 0)          ; B c
            ld b, (iy + 1)
            ld de, (rp_c)
            call m14
            ld (rp_t), hl
            ld c, (ix + 0)          ; - A s
            ld b, (ix + 1)
            ld de, (rp_s)
            call m14
            ex de, hl
            ld hl, (rp_t)
            or a
            sbc hl, de
            ld (iy + 0), l
            ld (iy + 1), h
            ld hl, (rp_na)
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz rp_lp
            ret
rp_s:       dw 0
rp_c:       dw 0
rp_t:       dw 0
rp_na:      dw 0
; renorm: F unit length, U square to F and unit, R = U x F; then the sun in the view
renorm:
            ld ix, {cm} + 12
            call rn_unit
            ld ix, {cm} + 6         ; U -= (U . F) F
            ld iy, {cm} + 12
            call mrow
            ld (rn_d), hl
            ld b, 3
rn_lp:
            push bc
            ld c, (iy + 0)
            ld b, (iy + 1)
            ld de, (rn_d)
            call m14
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
            djnz rn_lp
            ld ix, {cm} + 6
            call rn_unit
            ; R = U x F: Rx = Uy Fz - Uz Fy, Ry = Uz Fx - Ux Fz, Rz = Ux Fy - Uy Fx
            ld hl, {cm} + 8
            ld de, {cm} + 16
            ld bc, {cm} + 10
            ld ix, {cm} + 14
            call rn_cross
            ld ({cm}), hl
            ld hl, {cm} + 10
            ld de, {cm} + 12
            ld bc, {cm} + 6
            ld ix, {cm} + 16
            call rn_cross
            ld ({cm} + 2), hl
            ld hl, {cm} + 6
            ld de, {cm} + 14
            ld bc, {cm} + 8
            ld ix, {cm} + 12
            call rn_cross
            ld ({cm} + 4), hl
sunv:
            ld iy, {sun}            ; the sun in the view
            ld ix, {cm}
            call mrow
            ld ({suc}), hl
            ld ix, {cm} + 6
            call mrow
            ld ({suc} + 2), hl
            ld ix, {cm} + 12
            call mrow
            ld ({suc} + 4), hl
            ld hl, {cm}             ; the camera >> k (k 0..6, rounded): cms + 18 k
            ld de, cms
            ld bc, 18
            ldir
            ld ix, cms
            ld b, 6 * 9
cs_lp:
            ld l, (ix + 0)
            ld h, (ix + 1)
            sra h
            rr l
            ld de, 0
            adc hl, de              ; (rounded: the bit shifted out added back)
            ld (ix + 18), l
            ld (ix + 19), h
            inc ix
            inc ix
            djnz cs_lp
            ld hl, {cm}             ; 8 bit copies (>> 7, to +-127): the camera, the sun in the view
            ld de, cm8
            ld b, 9
s8_lp:
            call s8_one
            djnz s8_lp
            ld hl, {suc}
            ld de, suc8
            ld b, 3
s8_l2:
            call s8_one
            djnz s8_l2
            ld hl, {sun}
            ld de, sunw8
            ld b, 3
s8_l3:
            call s8_one
            djnz s8_l3
            ret
s8_one:
            ld a, (hl)
            inc hl
            push hl
            ld h, (hl)
            ld l, a
            push de
            ld de, 64
            add hl, de
            pop de
            add hl, hl
            ld a, h
            jr c, s8_neg
            cp 128
            jr c, s8_st
            ld a, 127
            jr s8_st
s8_neg:
            cp 129
            jr nc, s8_st
            ld a, 129
s8_st:
            ld (de), a
            inc de
            pop hl
            inc hl
            ret
rn_d:       dw 0
; rn_cross: (HL) x (DE) - (BC) x (IX) (words; s1.14 products) -> HL
rn_cross:
            ld (rc_b), bc
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ex de, hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld b, d
            ld c, e
            ex de, hl
            call m14
            ld (rc_t), hl
            ld hl, (rc_b)
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld e, (ix + 0)
            ld d, (ix + 1)
            call m14
            ex de, hl
            ld hl, (rc_t)
            or a
            sbc hl, de
            ret
rc_b:       dw 0
rc_t:       dw 0
; rn_unit: the vector at IX (3 words, near unit length) scaled by (3 - |v|^2) / 2
rn_unit:
            push ix
            pop iy
            call mrow               ; |v|^2 (s1.14)
            ex de, hl
            ld hl, 49152
            or a
            sbc hl, de
            srl h
            rr l                    ; (3 - k) / 2
            ld (rn_k), hl
            ld b, 3
ru_lp:
            push bc
            ld c, (ix + 0)
            ld b, (ix + 1)
            ld de, (rn_k)
            call m14
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            pop bc
            djnz ru_lp
            ret
rn_k:       dw 0
; ============================================================================ the polygon filler
; fill: pvx, pvy (pn vertices, clockwise on the screen) in the colours pc
fill:
            ld a, ({pn})
            cp 3
            ret c
            push iy
            push ix
            ld (fl_ssp), sp
            ; all on the screen (x 1..255, y 0..192)? Then the fast way, the points as bytes
            cp 49
            jp nc, fl_exit
            ld b, a
            ld hl, {pvx}
            ld de, {pvy}
            ld ix, ff_v
            ld c, 0
            ld a, 255
            ld (ff_ytop), a
            xor a
            ld (ff_ybot), a
fs_lp:
            ld a, (hl)
            inc hl
            or a
            jp z, fl_slow           ; x = 0
            ld (ix + 0), a
            ld a, (hl)
            inc hl
            or a
            jp nz, fl_slow          ; x < 0 or over 255
            ld a, (de)
            inc de
            ld (ix + 1), a
            cp 193
            jp nc, fl_slow
            ld a, (de)
            inc de
            or a
            jp nz, fl_slow          ; y < 0 or over 192
            ld a, (ix + 1)          ; the top (the first), the bottom
            push hl
            ld hl, ff_ytop
            cp (hl)
            jr nc, fs_1
            ld (hl), a
            ld a, c
            ld (ff_top), a
            ld a, (ix + 1)
fs_1:
            ld hl, ff_ybot
            cp (hl)
            jr c, fs_2
            ld (hl), a
fs_2:
            pop hl
            inc ix
            inc ix
            inc c
            djnz fs_lp
            jp ff
fl_exit:
            ld sp, (fl_ssp)
            ld a, 10
            db #ED, #92, #56
            ld a, 11
            db #ED, #92, #57
            pop ix
            pop iy
            ret
fl_slow:
            ; not all on the screen: the sides crossed (x < 1, x > 255, y < 0, y > 192); all off one
            ; side: nothing; else cut to them into ff_v, then the fast way
            ld a, ({pn})
            cp 49
            jp nc, fl_exit
            ld b, a
            ld hl, {pvx}
            ld de, {pvy}
            ld c, 0
            ld a, #0F
            ld (c2_and), a
fo_lp:
            push bc
            ld c, (hl)
            inc hl
            ld b, (hl)
            inc hl
            push hl
            ld l, 0
            bit 7, b
            jr nz, fo_x0
            ld a, b
            or a
            jr nz, fo_x1
            ld a, c
            or a
            jr nz, fo_y
fo_x0:
            set 0, l
            jr fo_y
fo_x1:
            set 1, l
fo_y:
            ld a, (de)
            ld c, a
            inc de
            ld a, (de)
            inc de
            ld b, a
            bit 7, b
            jr nz, fo_y0
            or a
            jr nz, fo_y1
            ld a, c
            cp 193
            jr c, fo_ok
fo_y1:
            set 3, l
            jr fo_ok
fo_y0:
            set 2, l
fo_ok:
            ld a, (c2_and)
            and l
            ld (c2_and), a
            ld a, l
            pop hl
            pop bc
            or c
            ld c, a
            djnz fo_lp
            ld a, (c2_and)
            or a
            jp nz, fl_exit
            ld a, c
            ld (c2_mask), a
            call clip2
            ld a, ({pn})
            cp 3
            jp c, fl_exit
            jp ff
; ---- the fast way: both sides stepped in registers (8.8), no tables. The left side: HL' x,
; DE' its step; the right: IX x (the last pixel), BC' its step; IYH the row's address (high),
; IYL the rows to go; DE the colours
ff:
            ld a, (ff_ytop)
            ld b, a
            ld a, (ff_ybot)
            cp b
            jp z, fl_exit           ; (flat)
            ld a, b
            ld (ff_y), a
            ld a, ({pn})            ; the points' ends (for going round them)
            add a, a
            sub 2
            ld (ff_lend), a         ; the last one's (low byte)
            add a, 2
            ld (ff_rend), a         ; one past it
            ld a, (ff_top)
            add a, a
            ld l, a
            ld h, ffpage >> 8
            ld (ff_pl), hl
            ld (ff_pr), hl
            ld hl, ff_advl          ; (the events: going round the points)
            ld (ff_cl + 1), hl
            ld hl, ff_advr
            ld (ff_cr + 1), hl
            call ff_advl
            call ff_advr
ff_run:
            ld hl, ({pc})           ; the colours: swapped on odd rows
            ld a, (ff_y)
            rra
            jr nc, ff_c0
            ld a, h
            ld h, l
            ld l, a
ff_c0:
            ld (ff_de), hl
            ld a, 255
            ld (ff_w), a
ff_chunk:
            ld a, (ff_y)            ; n = min(the left's end, the right's, the window's) - y
            or 63
            inc a
            ld b, a
            ld a, (ff_yl)
            cp b
            jr nc, ff_n1
            ld b, a
ff_n1:
            ld a, (ff_yr)
            cp b
            jr nc, ff_n2
            ld b, a
ff_n2:
            ld a, (ff_y)
            ld c, a
            ld a, b
            sub c
            jr z, ff_ev
            ld (ff_n), a
            ld iyl, a
            ld a, c                 ; the window
            and #C0
            ld b, a
            ld a, (ff_w)
            cp b
            jr z, ff_wok
            ld a, b
            ld (ff_w), a
            rlca
            rlca
            rlca
            and 6
            ld c, a
            ld a, ({back})
            add a, a
            add a, c
            db #ED, #92, #56
            inc a
            db #ED, #92, #57
ff_wok:
            ld a, (ff_y)
            and 63
            or #C0
            ld iyh, a
            ld de, (ff_de)
            jp fr_row
ff_after:
            ld sp, (fl_ssp)
            ld (ff_de), de
            ld a, (ff_n)
            ld b, a
            ld a, (ff_y)
            add a, b
            ld (ff_y), a
ff_ev:
            ld a, (ff_y)
            ld b, a
            ld a, (ff_ybot)
            cp b
            jp z, fl_exit
            jp c, fl_exit
            ld a, (ff_yl)
            cp b
ff_cl:
            call z, ff_advl
            ld a, (ff_y)
            ld b, a
            ld a, (ff_yr)
            cp b
ff_cr:
            call z, ff_advr
            jp ff_chunk
; ff_advl, ff_advr: a side's next edge going down (left: back round the points, right: on). The
; points are ff_v's (x, y) bytes; ff_pl, ff_pr point at each side's current one
ff_advl:
            ld a, (ff_ybot)         ; (none found: to the bottom)
            ld (ff_yl), a
            ld a, ({pn})
            ld b, a                 ; (a guard)
            ld hl, (ff_pl)
al_lp:
            ld a, l
            or a
            jr nz, al_1
            ld a, (ff_lend)
            jr al_2
al_1:
            sub 2
al_2:
            ld e, a
            ld d, h
            inc l
            inc e
            ld a, (de)
            sub (hl)
            ld c, a
            dec l                   ; (inc and dec keep the carry, not the zero)
            dec e
            ret c                   ; (going up: none)
            ld a, c
            or a
            jr z, al_flat
            ld (ff_pl), de
            xor a
            call edge88
            ld (ff_yl), a
            push hl
            push bc
            exx
            pop de
            pop hl
            exx
            ret
al_flat:
            ex de, hl
            djnz al_lp
            ret
ff_advr:
            ld a, (ff_ybot)
            ld (ff_yr), a
            ld a, ({pn})
            ld b, a
            ld hl, (ff_pr)
ar_lp:
            ld a, (ff_rend)
            ld e, a
            ld a, l
            add a, 2
            cp e
            jr nz, ar_1
            xor a
ar_1:
            ld e, a
            ld d, h
            inc l
            inc e
            ld a, (de)
            sub (hl)
            ld c, a
            dec l
            dec e
            ret c
            ld a, c
            or a
            jr z, ar_flat
            ld (ff_pr), de
            ld a, 1
            call edge88
            ld (ff_yr), a
            push hl
            pop ix
            push bc
            exx
            pop bc
            exx
            ret
ar_flat:
            ex de, hl
            djnz ar_lp
            ret
; edge88: the edge from point (HL) to point (DE) (both x, y; going down); A = 1: the right side ->
; HL = x (8.8, from a pixel's middle; the right side's - 1: its last pixel), BC = the step (mod
; 65536: x stays on the screen), A = the end's y
edge88:
            ld (e8_rt), a
            ld a, (de)              ; dx = xb - xa: |dx| in C, its sign in B
            sub (hl)
            ld b, 0
            jr nc, e8_p
            neg
            dec b
e8_p:
            ld c, a
            ld a, (hl)
            ld (e8_xa), a
            inc l
            inc e
            ld a, (de)
            ld (e8_yb), a
            sub (hl)                ; dy
            ld l, a
            ld h, 0
            add hl, hl
            ld de, fn_e3data_redge_redge_d
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)              ; R = 65536 / dy
            ld a, d
            ld d, c
            mul d, e                ; |dx| R low
            ld l, d
            ld e, a
            ld d, c
            mul d, e                ; |dx| R high
            ld h, 0
            add hl, de              ; |the step| (8.8)
            ld a, b
            or a
            jr z, e8_s
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
e8_s:
            ld b, h
            ld c, l
            ld a, (e8_xa)
            ld h, a
            ld l, #80
            ld a, (e8_rt)
            or a
            jr z, e8_l
            dec h
e8_l:
            ld a, (e8_yb)
            ret
e8_rt:      db 0
e8_xa:      db 0
e8_yb:      db 0
; ftri: the triangle of the 3 points listed at HL (in the fast range) filled in pc: its points by
; a pointer into a doubled list (the top first, clockwise), its second edge kept for the event
ftri:
            push iy
            push ix
            ld (fl_ssp), sp
            ld de, ff_v
            ld b, 3
tr_ld:
            ld a, (hl)
            inc hl
            push hl
            or #40
            ld l, a
            ld h, vpage >> 8
            ld a, (hl)
            ld (de), a
            inc de
            ld a, l
            xor #C0
            ld l, a
            ld a, (hl)
            ld (de), a
            inc de
            pop hl
            djnz tr_ld
            ld hl, ff_v             ; doubled: v0, v1 again after v2
            ld bc, 4
            ldir
            ld hl, ff_v             ; the top
            ld a, (ff_v + 1)
            ld b, a
            ld a, (ff_v + 3)
            cp b
            jr nc, tr_t1
            ld b, a
            ld hl, ff_v + 2
tr_t1:
            ld a, (ff_v + 5)
            cp b
            jr nc, tr_t2
            ld hl, ff_v + 4
tr_t2:
            ld (tr_a), hl           ; A (the top), B, C: tr_a, + 2, + 4
            inc l
            inc l
            ld (tr_b), hl
            inc l
            inc l
            ld (tr_c), hl
            ld a, (tr_a)
            ld l, a
            inc l
            ld a, (hl)              ; ya
            ld (ff_y), a
            ld e, a
            ld hl, (tr_b)
            inc l
            ld b, (hl)              ; yb
            ld hl, (tr_c)
            inc l
            ld c, (hl)              ; yc
            ld a, b
            cp c
            jr nc, tr_bt
            ld a, c
tr_bt:
            ld (ff_ybot), a
            cp e
            jp z, fl_exit           ; (flat)
            xor a
            ld (tr_l2), a
            ld (tr_r2), a
            ld hl, tr_al            ; (the events: the second edges)
            ld (ff_cl + 1), hl
            ld hl, tr_ar
            ld (ff_cr + 1), hl
            ld a, e
            cp b
            jr z, tr_ftr
            cp c
            jr z, tr_ftl
            ld a, b                 ; left A to C, right A to B, then B to C (yb < yc) on the right or C
            cp c                    ; to B (yc < yb) on the left
            jr z, tr_g
            jr nc, tr_gl
            ld a, 1
            ld (tr_r2), a
            jr tr_g
tr_gl:
            ld a, 1
            ld (tr_l2), a
tr_g:
            ld hl, (tr_a)
            ld de, (tr_c)
            call tr_left
            ld hl, (tr_a)
            ld de, (tr_b)
            call tr_right
            jp ff_run
tr_ftr:                             ; flat top, B at its right: left A to C, right B to C
            ld hl, (tr_a)
            ld de, (tr_c)
            call tr_left
            ld hl, (tr_b)
            ld de, (tr_c)
            call tr_right
            jp ff_run
tr_ftl:                             ; flat top, C at its left: left C to B, right A to B
            ld hl, (tr_c)
            ld de, (tr_b)
            call tr_left
            ld hl, (tr_a)
            ld de, (tr_b)
            call tr_right
            jp ff_run
tr_al:                              ; the left's event: C to B if kept, else to the bottom
            ld a, (tr_l2)
            or a
            jr z, tr_none_l
            xor a
            ld (tr_l2), a
            ld hl, (tr_c)
            ld de, (tr_b)
tr_left:
            xor a
            call edge88
            ld (ff_yl), a
            push hl
            push bc
            exx
            pop de
            pop hl
            exx
            ret
tr_none_l:
            ld a, (ff_ybot)
            ld (ff_yl), a
            ret
tr_ar:                              ; the right's event: B to C if kept
            ld a, (tr_r2)
            or a
            jr z, tr_none_r
            xor a
            ld (tr_r2), a
            ld hl, (tr_b)
            ld de, (tr_c)
tr_right:
            ld a, 1
            call edge88
            ld (ff_yr), a
            push hl
            pop ix
            push bc
            exx
            pop bc
            exx
            ret
tr_none_r:
            ld a, (ff_ybot)
            ld (ff_yr), a
            ret
tr_a:       dw 0
tr_b:       dw 0
tr_c:       dw 0
tr_l2:      db 0
tr_r2:      db 0
; ffi: the polygon of the points listed at HL (B of them, all in the fast range: their bytes in
; vpage) filled in pc
ffi:
            ld a, b
            cp 3
            jp z, ftri
            push iy
            push ix
            ld (fl_ssp), sp
            ld a, b
            ld ({pn}), a
            ld ix, ff_v
            ld c, 0
            ld a, 255
            ld (ff_ytop), a
            xor a
            ld (ff_ybot), a
fi_lp:
            ld a, (hl)
            inc hl
            push hl
            or #40
            ld l, a
            ld h, vpage >> 8
            ld a, (hl)
            ld (ix + 0), a
            ld a, l
            xor #C0
            ld l, a
            ld a, (hl)
            ld (ix + 1), a
            ld hl, ff_ytop
            cp (hl)
            jr nc, fi_1
            ld (hl), a
            ld e, a
            ld a, c
            ld (ff_top), a
            ld a, e
fi_1:
            ld hl, ff_ybot
            cp (hl)
            jr c, fi_2
            ld (hl), a
fi_2:
            pop hl
            inc ix
            inc ix
            inc c
            djnz fi_lp
            jp ff
ff_v:       equ ffpage
ff_top:     db 0
ff_ytop:    db 0
ff_ybot:    db 0
ff_y:       db 0
ff_yl:      db 0
ff_yr:      db 0
ff_pl:      dw 0
ff_pr:      dw 0
ff_lend:    db 0
ff_rend:    db 0
ff_n:       db 0
ff_w:       db 0
ff_de:      dw 0
; fr_row: the fast way's rows (aligned: the pushes end on a 256 byte boundary, so where to jump in
; is the step count negated)
            ALIGN 256
vpage:      ds 256                  ; per vertex i: +i its code, +64 + i its x, +128 + i its y (bytes,
                                    ; in the fast range)
ffpage:     ds 256                  ; ff_v: the fast fill's points (x, y bytes; up to 128)
fr_row:
            exx
            ld a, h                 ; x0
            add hl, de
            db #08                  ; ex af, af
            ld a, ixh               ; x1
            add ix, bc
            exx
            ld b, a
            db #08
            ld c, a
            ld a, iyh
            ld h, a
            inc iyh
            ld a, b
            cp c
            jp c, fr_cont           ; x1 < x0: none
            bit 0, c                ; odd start: one byte (an odd pixel: D)
            jr z, fr_a
            ld l, c
            ld (hl), d
            cp c
            jp z, fr_cont
            inc c
fr_a:
            bit 0, b                ; even end: one byte (E)
            jr nz, fr_b
            ld l, b
            ld (hl), e
            ld a, b
            cp c
            jp z, fr_cont
            dec b
fr_b:
            ld a, b                 ; pairs
            sub c
            add a, 1
            rra
            ld l, b
            inc hl
            db #F9                  ; ld sp, hl
            neg
            ld l, a
            ld h, (fr_pend >> 8) - 1
            jp (hl)
            ALIGN 128
            REPT 128
            push de
            ENDR
fr_pend:
fr_cont:
            ld a, d
            ld d, e
            ld e, a
            dec iyl
            jp nz, fr_row
            jp ff_after
fl_ssp:     dw 0
; clip2: the polygon pvx, pvy (pn points) cut to x 1..255, y 0..192 (Sutherland-Hodgman, one
; side at a time) -> ff_v (bytes), ff_top, ff_ytop, ff_ybot, pn (under 3: nothing left)
clip2:
            ld a, ({pn})
            ld (c2_n), a
            ld b, a
            ld hl, {pvx}
            ld de, {pvy}
            ld ix, c2_a
c2_cp:
            ld a, (hl)
            ld (ix + 0), a
            inc hl
            ld a, (hl)
            ld (ix + 1), a
            inc hl
            ld a, (de)
            ld (ix + 2), a
            inc de
            ld a, (de)
            ld (ix + 3), a
            inc de
            inc ix
            inc ix
            inc ix
            inc ix
            djnz c2_cp
            ld hl, c2_a
            ld (c2_src), hl
            ld hl, c2_b
            ld (c2_dst), hl
            xor a
            ld (c2_bd), a
c2_pass:
            ld a, (c2_bd)           ; (only the sides crossed)
            inc a
            ld b, a
            ld a, (c2_mask)
c2_mb:
            rrca
            djnz c2_mb
            jr nc, c2_skip
            call c2_one
            ld a, (c2_n)
            cp 3
            jr c, c2_none
            ld hl, (c2_src)
            ld de, (c2_dst)
            ld (c2_src), de
            ld (c2_dst), hl
c2_skip:
            ld a, (c2_bd)
            inc a
            ld (c2_bd), a
            cp 4
            jr c, c2_pass
            ld a, (c2_n)            ; to bytes, the top and the bottom found
            cp 100
            jr nc, c2_none
            ld ({pn}), a
            ld b, a
            ld ix, (c2_src)
            ld hl, ff_v
            ld c, 0
            ld a, 255
            ld (ff_ytop), a
            xor a
            ld (ff_ybot), a
c2_bt:
            ld a, (ix + 0)
            ld (hl), a
            inc hl
            ld a, (ix + 2)
            ld (hl), a
            inc hl
            push hl
            ld hl, ff_ytop
            cp (hl)
            jr nc, c2_b1
            ld (hl), a
            ld e, a
            ld a, c
            ld (ff_top), a
            ld a, e
c2_b1:
            ld hl, ff_ybot
            cp (hl)
            jr c, c2_b2
            ld (hl), a
c2_b2:
            pop hl
            ld de, 4
            add ix, de
            inc c
            djnz c2_bt
            ret
c2_none:
            xor a
            ld ({pn}), a
            ret
; c2_one: the list at c2_src (c2_n points) cut by side c2_bd into c2_dst
c2_one:
            ld a, (c2_n)
            ld (c2_k), a
            xor a
            ld (c2_out), a
            ld hl, (c2_dst)
            ld (c2_d), hl
            ld a, (c2_n)            ; the previous: the last
            dec a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, (c2_src)
            add hl, de
            ld (c2_pp), hl
            push hl
            pop ix
            call c2_dist
            ld (c2_dp), hl
            ld ix, (c2_src)
c2_lp:
            call c2_dist
            ld (c2_dc), hl
            ld a, (c2_dp + 1)
            bit 7, a
            jr nz, c2_pout
            bit 7, h
            jr nz, c2_inout
            call c2_emit
            jr c2_nx
c2_inout:
            call c2_isect
            jr c2_nx
c2_pout:
            bit 7, h
            jr nz, c2_nx
            call c2_isect
            call c2_emit
c2_nx:
            ld (c2_pp), ix
            ld hl, (c2_dc)
            ld (c2_dp), hl
            ld de, 4
            add ix, de
            ld a, (c2_k)
            dec a
            ld (c2_k), a
            jr nz, c2_lp
            ld a, (c2_out)
            ld (c2_n), a
            ret
c2_emit:
            push ix
            pop hl
            ld de, (c2_d)
            ld bc, 4
            ldir
            ld (c2_d), de
            ld hl, c2_out
            inc (hl)
            ret
; c2_dist: (IX)'s distance inside side c2_bd: x - 1, 255 - x, y, 192 - y
c2_dist:
            ld a, (c2_bd)
            or a
            jr nz, c2d_1
            ld l, (ix + 0)
            ld h, (ix + 1)
            dec hl
            ret
c2d_1:
            dec a
            jr nz, c2d_2
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld hl, 255
            or a
            sbc hl, de
            ret
c2d_2:
            dec a
            jr nz, c2d_3
            ld l, (ix + 2)
            ld h, (ix + 3)
            ret
c2d_3:
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld hl, 192
            or a
            sbc hl, de
            ret
; c2_isect: where the edge from the previous point to (IX) crosses the side: t = |dp| / (|dp| +
; |dc|) (65536 / that from REdge; under 1024 - halved together till it is)
c2_isect:
            ld hl, (c2_dp)
            call absh
            ld (c2_ap), hl
            ld hl, (c2_dc)
            call absh
            ld de, (c2_ap)
            add hl, de              ; the sum
c2_sh:
            ld a, h
            and #FC
            jr z, c2_r
            srl h
            rr l
            srl d
            rr e
            jr c2_sh
c2_r:
            add hl, hl
            push de
            ld de, fn_e3data_redge_redge_d
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop bc                  ; |dp| (halved as the sum)
            call umul               ; t = |dp| R (the low word)
            ld (c2_t), de
            ld hl, (c2_pp)
            ld (c2_pa), hl
            ld a, (c2_bd)
            cp 2
            jr nc, c2_hz
            ; x = the side; y = yp + (yc - yp) t
            ld hl, 1
            or a
            jr z, c2_x1
            ld hl, 255
c2_x1:
            ld (c2_nx_), hl
            ld hl, (c2_pa)
            inc hl
            inc hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; yp
            ld l, (ix + 2)
            ld h, (ix + 3)
            call c2_lerp
            ld (c2_ny), hl
            jr c2_put
c2_hz:
            ld hl, 0
            jr z, c2_y0
            ld hl, 192
c2_y0:
            ld (c2_ny), hl
            ld hl, (c2_pa)
            ld e, (hl)
            inc hl
            ld d, (hl)              ; xp
            ld l, (ix + 0)
            ld h, (ix + 1)
            call c2_lerp
            ld (c2_nx_), hl
c2_put:
            ld hl, (c2_d)
            ld de, (c2_nx_)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (c2_ny)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (c2_d), hl
            ld hl, c2_out
            inc (hl)
            ret
c2_lerp:                            ; DE + (HL - DE) t (rounded) -> HL
            push de
            or a
            sbc hl, de
            ld b, h
            ld c, l
            ld de, (c2_t)
            call smul
            ld bc, #8000
            ex de, hl
            add hl, bc
            ex de, hl
            ld bc, 0
            adc hl, bc
            pop de
            add hl, de
            ret
c2_n:       db 0
c2_and:     db 0
c2_mask:    db 0
c2_k:       db 0
c2_out:     db 0
c2_bd:      db 0
c2_src:     dw 0
c2_dst:     dw 0
c2_d:       dw 0
c2_pp:      dw 0
c2_pa:      dw 0
c2_dp:      dw 0
c2_dc:      dw 0
c2_ap:      dw 0
c2_t:       dw 0
c2_nx_:     dw 0
c2_ny:      dw 0
c2_a:       ds 4 * 60
c2_b:       ds 4 * 60
; ============================================================================ the projection
; proj: HL = x, DE = y, BC = z (> 0) in the view, |x| and |y| at most 2z (about) -> HL = the screen
; x, DE = the screen y. z = n 2^k (n 256..4095; x, y shifted by k too), R = 2^24 / n; then
; x R / 2^17 by three multiplies (the low bytes' product left out: under half a pixel)
proj:
            ld a, b
            and #F0
            jr z, pj_lo
pj_rs:
            srl b                   ; z over 4095: all >> 1
            rr c
            sra h
            rr l
            sra d
            rr e
            ld a, b
            and #F0
            jr nz, pj_rs
            jr pj_n
pj_lo:
            ld a, b
            or a
            jr nz, pj_n
            or c                    ; (z 0: as 1, not forever)
            jr nz, pj_ls
            inc c
pj_ls:
            sla c                   ; z under 256: all << 1
            rl b
            add hl, hl
            sla e
            rl d
            ld a, b
            or a
            jr z, pj_ls
pj_n:
            ld (pj_y), de
            push hl
            ld h, b
            ld l, c
            dec h
            add hl, hl
            ld de, fn_e3data_rproj_rproj_d
            add hl, de
            ld a, (hl)
            ld (pj_rl), a
            inc hl
            ld a, (hl)
            ld (pj_rh), a
            pop hl
            call pj_m
            ld de, 128
            add hl, de
            push hl
            ld hl, (pj_y)
            call pj_m
            ex de, hl
            ld hl, 96
            or a
            sbc hl, de
            ex de, hl
            pop hl
            ret
pj_m:                               ; HL (signed) x R >> 17 -> HL
            ld a, h
            ld (pj_sg), a
            bit 7, h
            jr z, pm_1
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
pm_1:
            ld b, h                 ; xh
            ld c, l                 ; xl
            ld a, (pj_rl)
            ld e, a
            ld d, b
            mul d, e                ; xh rl
            push de
            ld a, (pj_rh)
            ld e, a
            ld d, c
            mul d, e                ; xl rh
            pop hl
            add hl, de              ; m (carry: its bit 16)
            ld l, h
            ld h, 0
            rl h                    ; m >> 8
            ld a, (pj_rh)
            ld e, a
            ld d, b
            mul d, e                ; xh rh
            add hl, de
            srl h                   ; >> 1
            rr l
            ld a, (pj_sg)
            or a
            ret p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ret
pj_y:       dw 0
pj_rl:      db 0
pj_rh:      db 0
pj_sg:      db 0
; vcode: HL = x, DE = y, BC = z in the view (under 16384 each way) -> A: bit 0 z < 16 (the near
; plane), bit 1 x > 4z, bit 2 -x > 4z, bit 3 y > 4z, bit 4 -y > 4z (a wide guard band: the 2D
; clipper cuts the rest)
vcode:
            ld (vc_x), hl
            ld (vc_y), de
            ld h, b
            ld l, c
            ld de, -16
            add hl, de
            ld a, h
            rlca
            and 1
            ld (vc_c), a
            ld hl, (vc_x)
            sra h
            rr l
            sra h
            rr l
            ex de, hl
            ld h, b
            ld l, c
            or a
            sbc hl, de
            jp p, vc_1
            ld a, (vc_c)
            or 2
            ld (vc_c), a
vc_1:
            ld h, b
            ld l, c
            or a
            adc hl, de
            jp p, vc_2
            ld a, (vc_c)
            or 4
            ld (vc_c), a
vc_2:
            ld hl, (vc_y)
            sra h
            rr l
            sra h
            rr l
            ex de, hl
            ld h, b
            ld l, c
            or a
            sbc hl, de
            jp p, vc_3
            ld a, (vc_c)
            or 8
            ld (vc_c), a
vc_3:
            ld h, b
            ld l, c
            or a
            adc hl, de
            jp p, vc_4
            ld a, (vc_c)
            or 16
            ld (vc_c), a
vc_4:
            ld a, (vc_c)
            ret
vc_x:       dw 0
vc_y:       dw 0
vc_c:       db 0
; ============================================================================ the 3D clipper
; poly3: the polygon in cla (cn records of x, y, z in the view) cut by the planes in cmask (the
; vcode bits), projected and filled in pc
poly3:
            ld a, ({cmask})
            ld (p3_m), a
            ld hl, {cla}
            ld (p3_src), hl
            ld hl, {clb}
            ld (p3_dst), hl
            xor a
            ld (p3_p), a
p3_pl:
            ld a, (p3_m)
            srl a
            ld (p3_m), a
            jr nc, p3_nx
            call clip1
            ld a, ({cn})
            cp 3
            ret c
            ld hl, (p3_src)
            ld de, (p3_dst)
            ld (p3_src), de
            ld (p3_dst), hl
p3_nx:
            ld a, (p3_p)
            inc a
            ld (p3_p), a
            cp 5
            jr c, p3_pl
            ld a, ({cn})            ; projected into pvx, pvy
            ld ({pn}), a
            ld b, a
            ld ix, (p3_src)
            ld hl, {pvx}
            ld (p3_px), hl
            ld hl, {pvy}
            ld (p3_py), hl
p3_pj:
            push bc
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld c, (ix + 4)
            ld b, (ix + 5)
            call proj
            push de
            ex de, hl
            ld hl, (p3_px)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (p3_px), hl
            pop de
            ld hl, (p3_py)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (p3_py), hl
            ld de, 6
            add ix, de
            pop bc
            djnz p3_pj
            jp fill
p3_m:       db 0
p3_p:       db 0
p3_src:     dw 0
p3_dst:     dw 0
p3_px:      dw 0
p3_py:      dw 0
; clip1: the list at p3_src (cn records) cut by plane p3_p into p3_dst (cn: how many now)
clip1:
            ld a, ({cn})
            ld (c1_k), a
            xor a
            ld (c1_out), a
            ld hl, (p3_dst)
            ld (c1_d), hl
            ld a, ({cn})            ; the previous: the last
            dec a
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, (p3_src)
            add hl, de
            ld (c1_pp), hl
            push hl
            pop ix
            call cdist
            ld (c1_dp), hl
            ld ix, (p3_src)
c1_lp:
            call cdist
            ld (c1_dc), hl
            ld a, (c1_dp + 1)
            bit 7, a
            jr nz, c1_pout
            bit 7, h
            jr nz, c1_inout
            call c1_emit            ; in, in: the current
            jr c1_nx
c1_inout:
            call c1_isect           ; in, out: where it leaves
            jr c1_nx
c1_pout:
            bit 7, h
            jr nz, c1_nx            ; out, out: nothing
            call c1_isect           ; out, in: where it comes in, the current
            call c1_emit
c1_nx:
            ld (c1_pp), ix
            ld hl, (c1_dc)
            ld (c1_dp), hl
            ld de, 6
            add ix, de
            ld a, (c1_k)
            dec a
            ld (c1_k), a
            jr nz, c1_lp
            ld a, (c1_out)
            ld ({cn}), a
            ret
c1_emit:
            push ix
            pop hl
            ld de, (c1_d)
            ld bc, 6
            ldir
            ld (c1_d), de
            ld hl, c1_out
            inc (hl)
            ret
c1_isect:                           ; t = |dp| / (|dp| + |dc|): p + (c - p) t
            ld hl, (c1_dp)
            call absh
            push hl
            ld hl, (c1_dc)
            call absh
            pop de
            add hl, de
            ex de, hl
            call udivf
            ld (c1_t), hl
            ld hl, (c1_pp)
            ld (c1_a), hl
            push ix
            pop hl
            ld (c1_b), hl
            ld b, 3
c1_ic:
            push bc
            ld hl, (c1_a)
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld (c1_a), hl
            push de
            ld hl, (c1_b)
            ld a, (hl)
            inc hl
            ld b, (hl)
            inc hl
            ld (c1_b), hl
            ld h, b
            ld l, a
            or a
            sbc hl, de
            ld b, h
            ld c, l
            ld de, (c1_t)
            call smul
            pop de
            add hl, de
            ex de, hl
            ld hl, (c1_d)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (c1_d), hl
            pop bc
            djnz c1_ic
            ld hl, c1_out
            inc (hl)
            ret
c1_k:       db 0
c1_out:     db 0
c1_d:       dw 0
c1_pp:      dw 0
c1_dp:      dw 0
c1_dc:      dw 0
c1_t:       dw 0
c1_a:       dw 0
c1_b:       dw 0
; cdist: the record at IX's distance inside plane p3_p (< 0: outside) -> HL
cdist:
            ld a, (p3_p)
            or a
            jr nz, cd_1
            ld l, (ix + 4)
            ld h, (ix + 5)
            ld de, -16
            add hl, de
            ret
cd_1:
            ld e, (ix + 0)
            ld d, (ix + 1)
            cp 3
            jr c, cd_x
            ld e, (ix + 2)
            ld d, (ix + 3)
cd_x:
            sra d
            rr e
            sra d
            rr e
            ld l, (ix + 4)
            ld h, (ix + 5)
            bit 0, a
            jr z, cd_add
            or a
            sbc hl, de
            ret
cd_add:
            add hl, de
            ret
; ============================================================================ the planet
; planet: the planet drawn (ppos: its middle in the world / 256; prad: its radius / 256; pcol: its
; ramp). The view's directions touching it make a cone; 32 of them (the generators) round its edge,
; cut to the view like a face, are its outline. All in the view: the disc, lit toward the point under
; the sun (bands shrunk toward it), an atmosphere's rim; else (near: the horizon) the ground below.
; palt: the height over it (world units, to 32767)
planet:
            ld ix, {cp}             ; d = ppos * 256 - the camera (24 bits each way)
            ld iy, {ppos}
            ld hl, pl_d
            ld b, 3
pl_dl:
            xor a
            sub (ix + 1)
            ld (hl), a
            inc hl
            ld a, (iy + 0)
            sbc a, (ix + 2)
            ld (hl), a
            inc hl
            ld a, (iy + 1)
            sbc a, (ix + 3)
            ld (hl), a
            inc hl
            ld de, 4
            add ix, de
            inc iy
            inc iy
            djnz pl_dl
            xor a                   ; shifted till each fits -16384..16383: k
            ld (pl_k), a
            call pl_fit
            jp pl_fdone
pl_fit:
            ld hl, pl_d
            ld b, 3
pl_fc:
            inc hl
            ld a, (hl)              ; middle byte
            inc hl
            ld c, (hl)              ; top
            inc hl
            ld e, a
            and #C0
            jr z, pl_fp
            cp #C0
            jr nz, pl_fsh
            ld a, c                 ; negative: top FF
            inc a
            jr nz, pl_fsh
            jr pl_fn
pl_fp:
            ld a, c
            or a
            jr nz, pl_fsh
pl_fn:
            djnz pl_fc
            jr pl_fok
pl_fsh:
            ld hl, pl_d + 8
            ld b, 3
pl_sh:
            sra (hl)
            dec hl
            rr (hl)
            dec hl
            rr (hl)
            dec hl
            djnz pl_sh
            ld hl, pl_k
            inc (hl)
            jr pl_fit
pl_fok:
            ld hl, (pl_d)           ; d as words
            ld (pl_w), hl
            ld hl, (pl_d + 3)
            ld (pl_w + 2), hl
            ld hl, (pl_d + 6)
            ld (pl_w + 4), hl
            ret
pl_fdone:
            ld iy, pl_w             ; a = M d
            ld ix, {cm}
            call mrow
            ld (pl_a), hl
            ld ix, {cm} + 6
            call mrow
            ld (pl_a + 2), hl
            ld ix, {cm} + 12
            call mrow
            ld (pl_a + 4), hl
            ld hl, pl_a             ; D = |a|
            call len3
            ld (pl_dd), hl
            ; r = prad * 256 >> k (24 bits), then the height: (D - r) << k
            ld hl, ({prad})
            ld (pl_r), hl
            xor a
            ld (pl_r + 2), a
            ld a, (pl_r + 1)        ; r = prad * 256: bytes 0, prad lo, prad hi
            ld (pl_r + 2), a
            ld a, (pl_r)
            ld (pl_r + 1), a
            xor a
            ld (pl_r), a
            ld a, (pl_k)
            or a
            jr z, pl_r0
            ld b, a
pl_rs:
            ld hl, pl_r + 2
            srl (hl)
            dec hl
            rr (hl)
            dec hl
            rr (hl)
            djnz pl_rs
pl_r0:
            ld a, (pl_r + 2)        ; r over 65535: inside it
            or a
            jp nz, pl_in
            ld hl, (pl_dd)
            ld de, (pl_r)
            or a
            sbc hl, de
            jp c, pl_in
            jp z, pl_in
            ld a, (pl_k)            ; the height, to 32767
            or a
            jr z, pl_h0
            ld b, a
pl_hs:
            add hl, hl
            jr c, pl_hmax
            djnz pl_hs
pl_h0:
            bit 7, h
            jr z, pl_hok
pl_hmax:
            ld hl, 32767
pl_hok:
            ld ({palt}), hl
            ; the axis (unit): a / D; sin = r / D, cos = sqrt(1 - sin^2) (s1.14)
            ld ix, pl_a
            ld iy, pl_u
            ld b, 3
pl_ax:
            push bc
            ld l, (ix + 0)
            ld h, (ix + 1)
            call div14
            ld (iy + 0), l
            ld (iy + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz pl_ax
            ld hl, (pl_u)           ; (up in the view: -u)
            call oe_neg
            ld ({pup}), de
            ld hl, (pl_u + 2)
            call oe_neg
            ld ({pup} + 2), de
            ld hl, (pl_u + 4)
            call oe_neg
            ld ({pup} + 4), de
            ld hl, (pl_r)
            call div14
            ld (pl_sn), hl
            ld b, h
            ld c, l
            ld d, h
            ld e, l
            call ssmul              ; sin^2 (s2.28)
            xor a                   ; 2^28 - sin^2
            sub e
            ld e, a
            ld a, 0
            sbc a, d
            ld d, a
            ld a, 0
            sbc a, l
            ld l, a
            ld a, #10
            sbc a, h
            ld h, a
            call isqrt
            ld (pl_cs), hl
            ; two directions square to the axis: v (by the axis x up, or x when the axis is near up)
            ; and w = axis x v
            ld hl, (pl_u + 2)
            call absh
            ld de, 14000
            or a
            sbc hl, de
            jr nc, pl_vx
            ld hl, (pl_u + 4)       ; v = (-az, 0, ax) / |..|
            call oe_neg
            ld (pl_v), de
            ld hl, 0
            ld (pl_v + 2), hl
            ld hl, (pl_u)
            ld (pl_v + 4), hl
            jr pl_vn
pl_vx:
            ld hl, 0                ; v = (0, az, -ay) / |..|
            ld (pl_v), hl
            ld hl, (pl_u + 4)
            ld (pl_v + 2), hl
            ld hl, (pl_u + 2)
            call oe_neg
            ld (pl_v + 4), de
pl_vn:
            ld hl, pl_v             ; normalised
            call len3
            ld (pl_dd), hl
            ld ix, pl_v
            ld b, 3
pl_vnl:
            push bc
            ld l, (ix + 0)
            ld h, (ix + 1)
            call div14
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            pop bc
            djnz pl_vnl
            ld hl, pl_u + 2         ; w = u x v: wx = uy vz - uz vy, wy = uz vx - ux vz, wz = ux vy - uy vx
            ld de, pl_v + 4
            ld bc, pl_u + 4
            ld ix, pl_v + 2
            call rn_cross
            ld (pl_wv), hl
            ld hl, pl_u + 4
            ld de, pl_v
            ld bc, pl_u
            ld ix, pl_v + 4
            call rn_cross
            ld (pl_wv + 2), hl
            ld hl, pl_u
            ld de, pl_v + 2
            ld bc, pl_u + 2
            ld ix, pl_v
            call rn_cross
            ld (pl_wv + 4), hl
            ; the cone's parts: A = cos u (x 63/64: as the 8 bit products' 127 x 127), V8 = sin v,
            ; W8 = sin w (bytes, x 127)
            ld bc, (pl_u + 0)
            ld de, (pl_cs)
            call m14
            call pl_a63
            ld (pl_ca + 0), hl
            ld bc, (pl_v + 0)
            ld de, (pl_sn)
            call m14
            call pl_b8
            ld (pl_v8 + 0), a
            ld bc, (pl_wv + 0)
            ld de, (pl_sn)
            call m14
            call pl_b8
            ld (pl_w8 + 0), a
            ld bc, (pl_u + 2)
            ld de, (pl_cs)
            call m14
            call pl_a63
            ld (pl_ca + 2), hl
            ld bc, (pl_v + 2)
            ld de, (pl_sn)
            call m14
            call pl_b8
            ld (pl_v8 + 1), a
            ld bc, (pl_wv + 2)
            ld de, (pl_sn)
            call m14
            call pl_b8
            ld (pl_w8 + 1), a
            ld bc, (pl_u + 4)
            ld de, (pl_cs)
            call m14
            call pl_a63
            ld (pl_ca + 4), hl
            ld bc, (pl_v + 4)
            ld de, (pl_sn)
            call m14
            call pl_b8
            ld (pl_v8 + 2), a
            ld bc, (pl_wv + 4)
            ld de, (pl_sn)
            call m14
            call pl_b8
            ld (pl_w8 + 2), a
            ; the generators: g = A + cos(f) V8 + sin(f) W8, f = 0, 8, .. 248 (into cla, codes)
            ld hl, {cla}
            ld (pl_gp), hl
            xor a
            ld (pl_f), a
            ld (pl_and), a
            dec a
            ld (pl_and), a
            xor a
            ld (pl_or), a
            ld b, 32
pl_gl:
            push bc
            ld a, (pl_f)
            call trig
            ld (pl_sf), a
            ld a, c
            ld (pl_cf), a
            ld a, (pl_cf)
            ld d, a
            ld a, (pl_v8 + 0)
            ld e, a
            call mul8s
            push de
            ld a, (pl_sf)
            ld d, a
            ld a, (pl_w8 + 0)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            ld de, (pl_ca + 0)
            add hl, de
            ex de, hl
            ld hl, (pl_gp)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (pl_gp), hl
            ld a, (pl_cf)
            ld d, a
            ld a, (pl_v8 + 1)
            ld e, a
            call mul8s
            push de
            ld a, (pl_sf)
            ld d, a
            ld a, (pl_w8 + 1)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            ld de, (pl_ca + 2)
            add hl, de
            ex de, hl
            ld hl, (pl_gp)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (pl_gp), hl
            ld a, (pl_cf)
            ld d, a
            ld a, (pl_v8 + 2)
            ld e, a
            call mul8s
            push de
            ld a, (pl_sf)
            ld d, a
            ld a, (pl_w8 + 2)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            ld de, (pl_ca + 4)
            add hl, de
            ex de, hl
            ld hl, (pl_gp)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (pl_gp), hl
            ld hl, (pl_gp)          ; its code
            ld de, -6
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push de
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld c, (hl)
            inc hl
            ld b, (hl)
            pop hl
            call vcode
            ld b, a
            ld a, (pl_or)
            or b
            ld (pl_or), a
            ld a, (pl_and)
            and b
            ld (pl_and), a
            ld hl, pl_f             ; (backwards round: clockwise on the screen)
            ld a, (hl)
            sub 8
            ld (hl), a
            pop bc
            dec b
            jp nz, pl_gl
            ld a, (pl_and)
            or a
            ret nz                  ; all outside one side: not seen
            ld a, (pl_or)
            or a
            jp nz, pl_near
            ; ---- all in the view: the disc. The generators on the screen (kept: pl_sx, pl_sy)
            ld ix, {cla}
            ld hl, pl_sx
            ld b, 32
pl_pj:
            push bc
            push hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld c, (ix + 4)
            ld b, (ix + 5)
            call proj
            ld b, h
            ld c, l
            pop hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            push hl
            ld bc, 62               ; (pl_sy: 64 bytes on)
            add hl, bc
            ld (hl), e
            inc hl
            ld (hl), d
            pop hl
            ld de, 6
            add ix, de
            pop bc
            djnz pl_pj
            ; how big on the screen: the width across (the generators' x)
            ld ix, pl_sx
            ld hl, 32767
            ld (pl_x0), hl
            ld hl, -32768
            ld (pl_x1), hl
            ld b, 32
pl_wd:
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld hl, (pl_x0)
            or a
            sbc hl, de
            jp m, pl_w1
            ld (pl_x0), de
pl_w1:
            ld hl, (pl_x1)
            or a
            sbc hl, de
            jp p, pl_w2
            ld (pl_x1), de
pl_w2:
            inc ix
            inc ix
            djnz pl_wd
            ld hl, (pl_x1)
            ld de, (pl_x0)
            or a
            sbc hl, de
            ld (pl_wid), hl
            ; its middle on the screen (the axis)
            ld hl, (pl_a)
            ld de, (pl_a + 2)
            ld bc, (pl_a + 4)
            call proj
            ld (pl_mx), hl
            ld (pl_my), de
            ; the atmosphere: the disc x 17/16 about its middle, the haze ramp
            ld a, 17
            ld (pl_hf), a
            ld hl, (pl_mx)
            ld (pl_hx), hl
            ld hl, (pl_my)
            ld (pl_hy), hl
            ld a, ({pcol})
            cp 15                   ; (pcol 15: no atmosphere; none either when big: over 200 across)
            jr z, pl_noat
            ld hl, (pl_wid)
            ld de, 200
            or a
            sbc hl, de
            jr nc, pl_noat
            ld hl, 10 * 16 + 4 + (10 * 16 + 5) * 256
            ld ({pc}), hl
            call pl_hom
pl_noat:
            ; the disc, dark
            ld a, 16
            ld (pl_hf), a
            ld a, ({pcol})
            add a, a
            add a, a
            add a, a
            add a, a
            add a, 2
            ld l, a
            inc a
            ld h, a
            ld ({pc}), hl
            call pl_hom
            ; the lit side: the point under the sun, S = a + r sun (in the view): seen when S . sun < 0
            ld ix, pl_s
            ld iy, {suc}
            ld hl, pl_a
            ld b, 3
pl_sp:
            push bc
            push hl
            ld c, (iy + 0)
            ld b, (iy + 1)
            ld de, (pl_r)
            call m14
            pop de
            push de
            ex de, hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            add hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            pop hl
            inc hl
            inc hl
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz pl_sp
            ld ix, pl_s             ; S . sun
            ld iy, {suc}
            call mrow
            bit 7, h
            jr z, pl_back
            ld hl, (pl_s + 4)       ; (S in front)
            bit 7, h
            jr nz, pl_back
            ld a, h
            or a
            jr nz, pl_sf1
            ld a, l
            cp 16
            jr c, pl_back
pl_sf1:
            ld hl, (pl_s)
            ld de, (pl_s + 2)
            ld bc, (pl_s + 4)
            call proj
            ld (pl_hx), hl
            ld (pl_hy), de
            ld a, 16
            ld (pl_bt), a           ; all the bands
            jr pl_bands
pl_back:
            ; S hidden (lit from behind): toward the edge's point nearest the sun, the bands thinner by
            ; how far behind (q = u . sun: 0 side-lit .. 1 behind)
            ld ix, {cla}
            ld b, 32
            ld hl, -32768
            ld (pl_bd), hl
            ld c, 0
pl_bk:
            push bc
            push ix
            ld iy, {suc}
            call mrow
            pop ix
            pop bc
            push hl
            ld de, (pl_bd)
            or a
            sbc hl, de
            pop hl
            jp m, pl_bk1
            ld (pl_bd), hl
            ld a, c
            ld (pl_bi), a
pl_bk1:
            ld de, 6
            add ix, de
            inc c
            djnz pl_bk
            ld a, (pl_bi)
            add a, a
            ld e, a
            ld d, 0
            ld hl, pl_sx
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (pl_hx), hl
            ld hl, pl_sy
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (pl_hy), hl
            ld ix, pl_u             ; q
            ld iy, {suc}
            call mrow
            bit 7, h
            jr z, pl_q1
            ld hl, 0
pl_q1:
            ld a, h                 ; t = 16 (1 - q): 16ths
            srl a
            srl a
            neg
            add a, 16
            jp p, pl_q2
            xor a
pl_q2:
            ld (pl_bt), a
            or a
            ret z
pl_bands:
            ; bands: shrunk toward (pl_hx, pl_hy) by t * 13/16, 10/16, 7/16, 4/16 of the disc, lighter
            ; (fewer the bigger it is: their pixels are drawn over each other)
            ld hl, (pl_wid)
            ld de, 200
            or a
            sbc hl, de
            jr nc, pl_b2
            ld hl, (pl_wid)
            ld de, 90
            or a
            sbc hl, de
            jr nc, pl_b3
            ld a, 13
            ld b, 6
            call pl_band
            ld a, 10
            ld b, 9
            call pl_band
            ld a, 7
            ld b, 12
            call pl_band
            ld a, 4
            ld b, 14
            jp pl_band
pl_b3:
            ld a, 12
            ld b, 7
            call pl_band
            ld a, 8
            ld b, 10
            call pl_band
            ld a, 4
            ld b, 13
            jp pl_band
pl_b2:
            ld a, 11
            ld b, 8
            call pl_band
            ld a, 5
            ld b, 12
            jp pl_band
pl_band:                            ; A = f (16ths) x t; B = the shade (dithered with the one under)
            push bc
            ld e, a
            ld a, (pl_bt)
            ld d, a
            mul d, e
            ld a, e
            srl a
            srl a
            srl a
            srl a                   ; f t / 16
            pop bc
            or a
            ret z
            ld (pl_hf), a
            ld a, ({pcol})
            add a, a
            add a, a
            add a, a
            add a, a
            add a, b
            ld h, a
            dec a
            ld l, a
            ld ({pc}), hl
; pl_hom: the disc's outline scaled by pl_hf / 16 about (pl_hx, pl_hy), filled in pc
pl_hom:
            ld a, (pl_hf)
            ld (pl_hc), a
            ld ix, pl_sx
            ld iy, {pvx}
            ld b, 32
ph_lp:
            push bc
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld de, (pl_hx)
            call ph_one
            ld (iy + 0), l
            ld (iy + 1), h
            ld l, (ix + 64)
            ld h, (ix + 65)
            ld de, (pl_hy)
            call ph_one
            ld (iy + 96), l
            ld (iy + 97), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz ph_lp
            ld a, 32
            ld ({pn}), a
            jp fill
ph_one:                             ; DE + (HL - DE) * f / 16 (|HL - DE| under 4096)
            push de
            or a
            sbc hl, de
            ld a, (pl_hc)
            cp 16
            jr z, ph_1
            ld c, h                 ; (the sign)
            bit 7, h
            jr z, ph_p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
ph_p:
            ld e, l                 ; |x| f = xh f 256 + xl f
            ld d, a
            mul d, e
            ld b, a
            ld a, h
            ex de, hl               ; HL = xl f
            ld e, a
            ld d, b
            mul d, e                ; xh f (it adds to the high byte)
            ld a, h
            add a, e
            ld h, a
            srl h                   ; >> 4
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            bit 7, c
            jr z, ph_1
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
ph_1:
            pop de
            add hl, de
            ret
; ---- near: the ground below the horizon (the cone cut to the view)
pl_near:
            ld a, 32
            ld ({cn}), a
            ld a, (pl_or)
            ld ({cmask}), a
            ld a, ({pcol})
            add a, a
            add a, a
            add a, a
            add a, a
            add a, 6
            ld l, a
            inc a
            ld h, a
            ld ({pc}), hl
            jp poly3
pl_in:                              ; inside it: all ground
            ld hl, 0
            ld ({palt}), hl
            ret
pl_a63:                             ; HL - HL / 64
            ld d, h
            ld e, l
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            sra d
            rr e
            or a
            sbc hl, de
            ret
pl_b8:                              ; HL (s1.14) -> A (x 127 / 16384, to +-127)
            ld d, h
            ld e, l
            add hl, hl
            ld a, h                 ; >> 7
            bit 7, d
            jr nz, pb_n
            cp 128
            ret c
            ld a, 127
            ret
pb_n:
            cp 129
            ret nc
            ld a, 129
            ret
; div14: HL (signed) / pl_dd (|HL| at most pl_dd) -> HL (s1.14)
div14:
            ld a, h
            ld (dv_sg), a
            call absh
            ld de, (pl_dd)
            call udivf              ; 65536ths
            srl h
            rr l
            srl h
            rr l                    ; 16384ths
            ld a, (dv_sg)
            bit 7, a
            ret z
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ret
dv_sg:      db 0
; len3: the length of the vector at HL (3 words) -> HL
len3:
            ld (l3_p), hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld b, d
            ld c, e
            call ssmul
            ld (l3_s), de
            ld (l3_s + 2), hl
            ld hl, (l3_p)
            inc hl
            inc hl
            call l3_add
            ld hl, (l3_p)
            ld de, 4
            add hl, de
            call l3_add
            ld hl, (l3_s + 2)
            ld de, (l3_s)
            jp isqrt
l3_add:
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld b, d
            ld c, e
            call ssmul
            push hl
            ld hl, (l3_s)
            add hl, de
            ld (l3_s), hl
            pop de
            ld hl, (l3_s + 2)
            adc hl, de
            ld (l3_s + 2), hl
            ret
l3_p:       dw 0
l3_s:       ds 4
; isqrt: the square root of HL:DE (32 bits) -> HL
isqrt:
            ld (sq_n), de
            ld (sq_n + 2), hl
            ld hl, 0
            ld (sq_r), hl           ; the root
            ld (sq_m), hl           ; the remainder (24 bits)
            xor a
            ld (sq_m + 2), a
            ld b, 16
sq_lp:
            push bc
            ld b, 2                 ; the remainder << 2, the number's top 2 bits into it
sq_sh:
            ld hl, sq_n
            sla (hl)
            inc hl
            rl (hl)
            inc hl
            rl (hl)
            inc hl
            rl (hl)
            ld hl, sq_m
            rl (hl)
            inc hl
            rl (hl)
            inc hl
            rl (hl)
            djnz sq_sh
            ld hl, (sq_r)           ; the root << 1; test = root << 1 | 1 (17 bits)
            add hl, hl
            ld (sq_r), hl
            ld d, h
            ld e, l
            sla e
            rl d
            ld a, 0
            rla                     ; (A: test's bit 16)
            set 0, e
            ld hl, (sq_m)           ; remainder - test
            or a
            sbc hl, de
            ld c, a
            ld a, (sq_m + 2)
            sbc a, c
            jr c, sq_no
            ld (sq_m), hl
            ld (sq_m + 2), a
            ld hl, sq_r
            set 0, (hl)
sq_no:
            pop bc
            djnz sq_lp
            ld hl, (sq_r)
            ret
sq_n:       ds 4
sq_r:       dw 0
sq_m:       ds 3
pl_d:       ds 9
pl_k:       db 0
pl_w:       ds 6
pl_a:       ds 6
pl_dd:      dw 0
pl_r:       ds 3
pl_sn:      dw 0
pl_cs:      dw 0
pl_u:       ds 6                    ; u, then v, then w: (the cone's axis and its square ones)
pl_v:       ds 6
pl_wv:      ds 6
pl_ca:      ds 6                    ; A (words), V8, W8 (bytes)
pl_v8:      ds 3
pl_w8:      ds 3
pl_gp:      dw 0
pl_f:       db 0
pl_cf:      db 0
pl_sf:      db 0
pl_and:     db 0
pl_or:      db 0
pl_mx:      dw 0
pl_my:      dw 0
pl_hx:      dw 0
pl_hy:      dw 0
pl_hf:      db 0
pl_hc:      db 0
pl_bt:      db 0
pl_bd:      dw 0
pl_bi:      db 0
pl_x0:      dw 0
pl_x1:      dw 0
pl_wid:     dw 0
pl_s:       ds 6
pl_sx:      ds 64
pl_sy:      ds 64
; ============================================================================ the city
; city: the city (E3Data CitySite: where it lies and how, its kinds of building; CityMap: 48 x 48
; cells of 128 units, the roads empty) drawn when the camera is near it: its ground, then the
; buildings within 18 cells of the camera, far to near
cy_site:    equ fn_e3data_citysite_citysite_d
cy_map:     equ fn_e3data_citymap_citymap_d
city:
            ld ix, {cp}             ; rel = the site - the camera (each way under 16000, else far)
            ld iy, cy_site
            ld hl, cy_rel
            ld b, 3
cy_r:
            push bc
            ld a, (iy + 0)
            sub (ix + 1)
            ld e, a
            ld a, (iy + 1)
            sbc a, (ix + 2)
            ld d, a
            ld a, (iy + 2)
            sbc a, (ix + 3)
            ld c, a
            ld a, d
            rla
            sbc a, a
            cp c
            jr nz, cy_far
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            push hl
            ex de, hl
            call absh
            ld de, 16000
            or a
            sbc hl, de
            pop hl
            jr nc, cy_far
            ld de, 4
            add ix, de
            inc iy
            inc iy
            inc iy
            pop bc
            djnz cy_r
            jr cy_near
cy_far:
            pop bc
            ret
cy_near:
            ld iy, cy_rel           ; c0 = M rel: the site in the view
            ld ix, {cm}
            call mrow
            ld (cy_c0), hl
            ld ix, {cm} + 6
            call mrow
            ld (cy_c0 + 2), hl
            ld ix, {cm} + 12
            call mrow
            ld (cy_c0 + 4), hl
            ld iy, cy_site + 9      ; the site's east, up, north in the view: M E, M U, M N
            ld hl, cy_me
            call cy_mv
            ld iy, cy_site + 15
            ld hl, cy_mu
            call cy_mv
            ld iy, cy_site + 21
            ld hl, cy_mn
            call cy_mv
            ld ix, cy_site + 9      ; the camera on the city: -(E . rel), -(U . rel), -(N . rel)
            ld iy, cy_rel
            call mrow
            call cy_ng
            ld (cy_cl), de
            ld ix, cy_site + 15
            call mrow
            call cy_ng
            ld (cy_cl + 2), de
            ld ix, cy_site + 21
            call mrow
            call cy_ng
            ld (cy_cl + 4), de
            ld a, (cy_cl + 3)       ; (under the ground: none)
            bit 7, a
            ret nz
            ; 8 bit copies of the frame in the view (e8, u8, n8)
            ld hl, cy_me
            ld de, cy_e8
            ld b, 9
cy_8:
            call s8_one
            djnz cy_8
            ; each kind's corner steps: EW = e8 w >> 7, ED = n8 d >> 7, EH = u8 h >> 5 (h in 4s)
            ld iy, cy_site + 27
            ld hl, cy_tv
            ld b, 8
cy_tk:
            push bc
            ld a, (iy + 0)
            ld de, cy_e8
            ld c, 7
            call cy_tv3
            ld a, (iy + 1)
            ld de, cy_n8
            ld c, 7
            call cy_tv3
            ld a, (iy + 2)
            ld de, cy_u8
            ld c, 5
            call cy_tv3
            ld de, 4
            add iy, de
            pop bc
            djnz cy_tk
            ; the cells' middles across: TX(i) = M E (128 i - 3008), TZ(j) = M N (..) (8.8: start
            ; -47 m, step 2 m)
            ld hl, cy_me
            ld de, cy_tx
            call cy_tab
            ld hl, cy_mn
            ld de, cy_tz
            call cy_tab
            ; the sun on the city: shades for the faces +E, -E, +N, -N, up
            ld ix, cy_site + 9
            ld iy, {sun}
            call mrow
            ld (cy_sl), hl
            ld ix, cy_site + 15
            call mrow
            ld (cy_sl + 2), hl
            ld ix, cy_site + 21
            call mrow
            ld (cy_sl + 4), hl
            ld hl, (cy_sl)
            call cy_lv
            ld (cy_sh), a
            ld hl, (cy_sl)
            call oe_neg
            ex de, hl
            call cy_lv
            ld (cy_sh + 1), a
            ld hl, (cy_sl + 4)
            call cy_lv
            ld (cy_sh + 2), a
            ld hl, (cy_sl + 4)
            call oe_neg
            ex de, hl
            call cy_lv
            ld (cy_sh + 3), a
            ld hl, (cy_sl + 2)
            call cy_lv
            ld (cy_sh + 4), a
            ; ---- the ground: one quad 3136 each way about the site
            call cy_ground
            ; ---- the cells near the camera: ci, cj = (cl + 3072) >> 7, 18 either way (in the city)
            ld hl, (cy_cl)
            call cy_cell
            ld (cy_i0), bc          ; C = from, B = to
            ld hl, (cy_cl + 4)
            call cy_cell
            ld (cy_j0), bc
            ld a, (cy_i0)
            ld b, a
            ld a, (cy_i1)
            cp b
            ret c
            ld a, (cy_j0)
            ld b, a
            ld a, (cy_j1)
            cp b
            ret c
            xor a
            ld (cy_n), a
            call cy_blocks
            ld a, (cy_j0)
            ld (cy_j), a
cy_jl:
            ; this row: its cells' x and z in the view (c0 + TZ(j)), the map's row, TX(i0)
            ld a, (cy_j)
            call cy_x6
            ld de, cy_tz
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push hl
            ld hl, (cy_c0)
            add hl, de
            ld (cy_xj), hl
            pop hl
            inc hl
            inc hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, (cy_c0 + 4)
            add hl, de
            ld (cy_zj), hl
            ld a, (cy_j)            ; cy_map + 48 j + i0
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld a, (cy_i0)
            ld e, a
            ld d, 0
            add hl, de
            ld de, cy_map
            add hl, de
            ld (cy_mp), hl
            ld a, (cy_i0)
            call cy_x6
            ld de, cy_tx
            add hl, de
            ld (cy_t6), hl
            ld a, (cy_i0)
            ld (cy_i), a
cy_il:
            ld hl, (cy_mp)
            ld a, (hl)
            inc hl
            ld (cy_mp), hl
            or a
            jp z, cy_inx
            dec a
            ld (cy_t), a
            ld a, (cy_j)            ; (its block far: drawn as one box)
            and #FC
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de              ; (j / 4) * 12
            ld a, (cy_i)
            srl a
            srl a
            add a, l
            ld l, a
            ld de, cy_bf
            add hl, de
            ld a, (hl)
            or a
            jp nz, cy_inx
            ld hl, (cy_t6)          ; seen? z + 200 > 0 and |x| < z + 200 (a rough sphere)
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld de, 3
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, (cy_zj)
            add hl, de
            ld de, 200
            add hl, de
            bit 7, h
            jp nz, cy_inx
            ld (cy_zr), hl
            ld hl, (cy_xj)
            add hl, bc
            call absh
            ld de, (cy_zr)
            or a
            sbc hl, de
            jp nc, cy_inx
            ld a, (cy_n)            ; listed: i, j, kind, how far (z / 64)
            cp 120
            jp nc, cy_inx
            inc a
            ld (cy_n), a
            dec a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, cy_ent
            add hl, de
            ld a, (cy_i)
            ld (hl), a
            inc hl
            ld a, (cy_j)
            ld (hl), a
            inc hl
            ld a, (cy_t)
            ld (hl), a
            inc hl
            push hl
            ld hl, (cy_zr)          ; z / 64, 0..63
            ld de, -200
            add hl, de
            bit 7, h
            jr z, cy_z1
            ld hl, 0
cy_z1:
            add hl, hl
            add hl, hl
            ld a, h
            jr c, cy_z0
            cp 64
            jr c, cy_z2
cy_z0:
            ld a, 63
cy_z2:
            pop hl
            ld (hl), a
cy_inx:
            ld hl, (cy_t6)
            ld de, 6
            add hl, de
            ld (cy_t6), hl
            ld hl, cy_i
            ld a, (cy_i1)
            cp (hl)
            jr z, cy_jnx
            inc (hl)
            jp cy_il
cy_jnx:
            ld hl, cy_j
            ld a, (cy_j1)
            cp (hl)
            jr z, cy_sort
            inc (hl)
            jp cy_jl
cy_sort:
            ; ---- far to near: counted by how far (z / 64), placed, drawn
            ld a, (cy_n)
            or a
            ret z
            ld hl, cy_cnt
            ld b, 64
cs_cl:
            ld (hl), 0
            inc hl
            djnz cs_cl
            ld a, (cy_n)
            ld b, a
            ld hl, cy_ent + 3
cs_ct:
            ld e, (hl)
            ld d, 0
            push hl
            ld hl, cy_cnt
            add hl, de
            inc (hl)
            pop hl
            inc hl
            inc hl
            inc hl
            inc hl
            djnz cs_ct
            ld hl, cy_cnt + 63      ; the starts: far first
            ld b, 64
            ld c, 0
cs_st:
            ld a, (hl)
            ld (hl), c
            add a, c
            ld c, a
            dec hl
            djnz cs_st
            ld a, (cy_n)            ; placed
            ld b, a
            ld c, 0
            ld hl, cy_ent + 3
cs_pl:
            ld e, (hl)
            ld d, 0
            push hl
            ld hl, cy_cnt
            add hl, de
            ld e, (hl)
            inc (hl)
            ld hl, cy_ord
            add hl, de
            ld (hl), c
            pop hl
            inc hl
            inc hl
            inc hl
            inc hl
            inc c
            djnz cs_pl
            ld a, (cy_n)
            ld b, a
            ld hl, cy_ord
cs_dr:
            push bc
            push hl
            ld a, (hl)
            add a, a
            add a, a
            ld e, a
            ld d, 0
            jr nc, cs_d1
            inc d
cs_d1:
            ld hl, cy_ent
            add hl, de
            ld a, (hl)
            ld (cy_i), a
            inc hl
            ld a, (hl)
            ld (cy_j), a
            inc hl
            ld a, (hl)
            ld (cy_t), a
            inc a
            jr nz, cs_bd
            call cy_blk
            jr cs_dn
cs_bd:
            call cy_bld
cs_dn:
            pop hl
            inc hl
            pop bc
            djnz cs_dr
            ret
; cy_blocks: the blocks within the cells' range: those far (their middle's z 1100 on) flagged
; (cy_bf: their cells left out) and listed (kind 255) when in the view
cy_blocks:
            ld hl, cy_bf
            ld b, 144
cb_cl:
            ld (hl), 0
            inc hl
            djnz cb_cl
            ld a, (cy_j0)
            srl a
            srl a
            ld (cy_bj), a
cbj_l:
            ld a, (cy_i0)
            srl a
            srl a
            ld (cy_bi), a
cbi_l:
            ld a, (cy_bj)           ; its height (0: none)
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            add hl, hl
            add hl, hl              ; 12 bj
            ld a, (cy_bi)
            ld e, a
            ld d, 0
            add hl, de
            ld (cy_bix), hl
            add hl, hl
            ld de, fn_e3data_cityblocks_cityblocks_d
            add hl, de
            ld a, (hl)
            or a
            jp z, cbi_nx
            ld a, (cy_bi)           ; its middle: cells 4 b + 2
            add a, a
            add a, a
            add a, 2
            call cy_x6
            ld de, cy_tx
            add hl, de
            ld c, (hl)
            inc hl
            ld b, (hl)
            push bc                 ; TX x
            inc hl
            inc hl
            inc hl
            ld c, (hl)
            inc hl
            ld b, (hl)
            push bc                 ; TX z
            ld a, (cy_bj)
            add a, a
            add a, a
            add a, 2
            call cy_x6
            ld de, cy_tz
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)              ; TZ x
            inc hl
            inc hl
            inc hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; TZ z
            ld hl, (cy_c0 + 4)
            add hl, bc
            pop bc
            add hl, bc              ; z
            ld (cy_zr), hl
            ld bc, -1100
            add hl, bc
            bit 7, h
            jr z, cb_far
            pop bc
            jp cbi_nx
cb_far:
            ld hl, (cy_bix)         ; far: its cells left out
            ld bc, cy_bf
            add hl, bc
            ld (hl), 1
            ld hl, (cy_c0)          ; in the view? |x| < z + 400
            add hl, de
            pop bc
            add hl, bc
            call absh
            ld de, (cy_zr)
            push hl
            ld hl, 400
            add hl, de
            ex de, hl
            pop hl
            or a
            sbc hl, de
            jp nc, cbi_nx
            ld a, (cy_n)            ; listed: bi, bj, 255, how far
            cp 120
            jp nc, cbi_nx
            inc a
            ld (cy_n), a
            dec a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, cy_ent
            add hl, de
            ld a, (cy_bi)
            ld (hl), a
            inc hl
            ld a, (cy_bj)
            ld (hl), a
            inc hl
            ld (hl), 255
            inc hl
            push hl
            ld hl, (cy_zr)
            add hl, hl
            add hl, hl
            ld a, h
            jr c, cb_z0
            cp 64
            jr c, cb_z2
cb_z0:
            ld a, 63
cb_z2:
            pop hl
            ld (hl), a
cbi_nx:
            ld a, (cy_i1)
            srl a
            srl a
            ld hl, cy_bi
            cp (hl)
            jr z, cbj_nx
            inc (hl)
            jp cbi_l
cbj_nx:
            ld a, (cy_j1)
            srl a
            srl a
            ld hl, cy_bj
            cp (hl)
            ret z
            inc (hl)
            jp cbj_l
; cy_blk: far block (cy_i, cy_j: its block's place) drawn as one box: its outline in the haze
cy_blk:
            ld a, (cy_i)
            ld (cy_bi), a
            ld a, (cy_j)
            ld (cy_bj), a
            ld a, (cy_i)            ; its bottom middle: c0 + TX(4 bi + 2) + TZ(4 bj + 2)
            add a, a
            add a, a
            add a, 2
            ld (cy_i), a
            ld a, (cy_j)
            add a, a
            add a, a
            add a, 2
            ld (cy_j), a
            xor a
            ld (cy_t), a
            call cy_mid             ; (cb; oc and the kind's steps not wanted)
            ld a, (cy_bj)           ; its height
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            add hl, hl
            add hl, hl
            ld a, (cy_bi)
            ld e, a
            ld d, 0
            add hl, de
            add hl, hl
            ld de, fn_e3data_cityblocks_cityblocks_d
            add hl, de
            ld a, (hl)
            ld (cy_h4), a
            ld hl, cy_tvb           ; its steps: EW = e8 88 >> 6, ED = n8 88 >> 6, EH = u8 h >> 5
            ld (cy_tp), hl
            ld a, 88
            ld de, cy_e8
            ld c, 6
            call cy_tv3
            ld a, 88
            ld de, cy_n8
            ld c, 6
            call cy_tv3
            ld a, (cy_h4)
            ld de, cy_u8
            ld c, 5
            call cy_tv3
            ld a, 176
            ld (cy_w), a
            ld (cy_dd), a
            ld a, (cy_i)            ; the camera from it
            call cy_lx
            ld hl, (cy_cl)
            or a
            sbc hl, de
            ld (cy_dx), hl
            ld a, (cy_j)
            call cy_lx
            ld hl, (cy_cl + 4)
            or a
            sbc hl, de
            ld (cy_dz), hl
            xor a
            ld (cy_have), a
            call cy_fmask
            call cy_bz
            ret c                   ; (its bottom near: left out)
            call cy_affs
            jp cy_silh
; cy_bz: carry if the bottom middle's z (cy_cb) is under 512 (the affine way wrong there)
cy_bz:
            ld a, (cy_cb + 5)
            sub 2                   ; 2..#7F -> 0..#7D: fine; 0, 1 or negative: #7E up
            cp #7E
            ccf
            ret
; cy_mv: (the camera) x the vector at IY -> 3 words at HL
cy_mv:
            push hl
            ld ix, {cm}
            call mrow
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            push hl
            ld ix, {cm} + 6
            call mrow
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            push hl
            ld ix, {cm} + 12
            call mrow
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
cy_ng:                              ; DE = -HL
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ex de, hl
            ret
; cy_tv3: the 3 bytes at DE x A >> C -> 3 words at HL (HL on)
cy_tv3:
            ld (cy_f), a
            ld a, c
            ld (cy_fs), a
            ld b, 3
c3_lp:
            push bc
            push hl
            ld a, (de)
            inc de
            push de
            ld d, a
            ld a, (cy_f)
            ld e, a
            call mul8s
            ld a, (cy_fs)
            ld b, a
c3_sh:
            sra d
            rr e
            djnz c3_sh
            pop bc                  ; (the bytes' pointer)
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld d, b
            ld e, c
            pop bc
            djnz c3_lp
            ret
; cy_tab: 48 x 3 words at DE: (the 3 words at HL) x (2 i - 47) / 256, rounded (8.8 sums)
cy_tab:
            ld (ct_dst), de
            ld b, 3
ct_k:
            push bc
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push hl
            ld (ct_m), de
            ld b, d                 ; acc = -47 m (24 bits)
            ld c, e
            ld de, 47
            call smul               ; HL:DE
            xor a
            sub e
            ld (ct_a), a
            ld a, 0
            sbc a, d
            ld (ct_a + 1), a
            ld a, 0
            sbc a, l
            ld (ct_a + 2), a
            ld hl, (ct_m)           ; step = 2 m (24 bits)
            add hl, hl
            ld (ct_s), hl
            sbc a, a                ; (the carry out: the step's top - but m's sign decides)
            ld a, (ct_m + 1)
            rla
            sbc a, a
            ld (ct_s + 2), a
            ld hl, (ct_dst)
            ld b, 48
ct_i:
            push bc
            ld de, (ct_a)           ; (acc + 128) >> 8
            ld a, (ct_a + 2)
            ld c, a
            ld a, e
            add a, 128
            ld a, d
            adc a, 0
            ld (hl), a
            inc hl
            ld a, c
            adc a, 0
            ld (hl), a
            ld de, 5
            add hl, de
            push hl
            ld hl, (ct_a)           ; acc += step
            ld de, (ct_s)
            add hl, de
            ld (ct_a), hl
            ld a, (ct_a + 2)
            ld hl, ct_s + 2
            adc a, (hl)
            ld (ct_a + 2), a
            pop hl
            pop bc
            djnz ct_i
            ld hl, (ct_dst)
            inc hl
            inc hl
            ld (ct_dst), hl
            pop hl
            pop bc
            djnz ct_k
            ret
; cy_lv: HL (a face's normal . the sun, s1.14) -> A: its shade level, 4..30
cy_lv:
            bit 7, h
            jr z, lv_p
            ld a, 4
            ret
lv_p:
            ld a, h                 ; / 512: 0..32, then * 13 / 16 + 4
            srl a
            ld b, a
            srl a
            srl a
            neg
            add a, b
            add a, 4
            cp 31
            ret c
            ld a, 30
            ret
; cy_cell: HL = the camera on the city (one way) -> C = the first cell, B = the last (18 either
; way, in 0..47; C > B: none)
cy_cell:
            ld de, 3072
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
            sra h
            rr l                    ; the camera's cell (maybe outside)
            push hl
            ld de, -18
            add hl, de
            bit 7, h
            jr z, cc_1
            ld hl, 0
cc_1:
            ld a, h
            or a
            jr z, cc_2
            ld l, 48
cc_2:
            ld c, l
            pop hl
            ld de, 18
            add hl, de
            bit 7, h
            jr z, cc_3
            ld bc, 1                ; (all before the city: none)
            ret
cc_3:
            ld a, h
            or a
            jr nz, cc_4
            ld a, l
            cp 48
            jr c, cc_5
cc_4:
            ld l, 47
cc_5:
            ld b, l
            ret
; cy_mid: cell (cy_i, cy_j) kind cy_t: its bottom middle in the view (cy_cb) and its middle
; (oc), the sphere round it (orad: w + d + 2 h)
cy_mid:
            ld a, (cy_i)
            call cy_x6
            ld de, cy_tx
            add hl, de
            push hl
            ld a, (cy_j)
            call cy_x6
            ld de, cy_tz
            add hl, de
            ex de, hl               ; DE: TZ(j)
            pop hl                  ; HL: TX(i)
            ld ix, cy_cb
            ld iy, cy_c0
            ld b, 3
cm_lp:
            push bc
            ld c, (hl)
            inc hl
            ld b, (hl)
            inc hl
            push hl
            ld a, (de)
            inc de
            ld l, a
            ld a, (de)
            inc de
            ld h, a
            add hl, bc
            ld c, (iy + 0)
            ld b, (iy + 1)
            add hl, bc
            ld (ix + 0), l
            ld (ix + 1), h
            pop hl
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz cm_lp
            ld a, (cy_t)            ; its kind's steps: EH / 2 up for the middle
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, de              ; * 18
            ld de, cy_tv
            add hl, de
            ld (cy_tp), hl
            ld de, 12
            add hl, de              ; EH
            ld ix, cy_cb
            ld iy, {oc}
            ld b, 3
cm_m:
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            sra d
            rr e
            push hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            add hl, de
            ld (iy + 0), l
            ld (iy + 1), h
            pop hl
            inc ix
            inc ix
            inc iy
            inc iy
            djnz cm_m
            ld a, (cy_t)            ; the radius: w + d + 2 h
            add a, a
            add a, a
            ld e, a
            ld d, 0
            ld hl, cy_site + 27
            add hl, de
            ld (cy_kp), hl
            ld a, (hl)
            inc hl
            add a, (hl)
            ld e, a
            ld d, 0
            inc hl
            ld a, (hl)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, de
            ld ({orad}), hl
            ret
; cy_bld: building (cy_i, cy_j) kind cy_t drawn: the faces turned to the camera (by where it is
; beside it), their corners when wanted
cy_bld:
            call cy_mid
            ld hl, (cy_kp)
            ld a, (hl)
            ld (cy_w), a
            inc hl
            ld a, (hl)
            ld (cy_dd), a
            inc hl
            ld a, (hl)
            ld (cy_h4), a
            inc hl
            ld a, (hl)
            ld (cy_ramp), a
            ld a, ({oc} + 5)        ; far (z over 1792): in the haze
            ld (cy_fz), a
            ; the camera from it (on the city): dx = clx - (128 i - 3008), dz = clz - (128 j - 3008)
            ld a, (cy_i)
            call cy_lx
            ld hl, (cy_cl)
            or a
            sbc hl, de
            ld (cy_dx), hl
            ld a, (cy_j)
            call cy_lx
            ld hl, (cy_cl + 4)
            or a
            sbc hl, de
            ld (cy_dz), hl
            xor a
            ld (cy_have), a
            call cy_fmask
            jp cb_nt
; cy_fmask: the faces the camera sees (cy_fm: +E, -E, +N, -N, the top), by cy_dx, cy_dz and its
; height over the ground
cy_fmask:
            xor a
            ld (cy_fm), a
            ld hl, (cy_dx)          ; +E: dx > w; -E: dx < -w
            ld a, (cy_w)
            call cy_side
            ld (cy_fm), a
            ld hl, (cy_dz)          ; +N, -N
            ld a, (cy_dd)
            call cy_side
            add a, a
            add a, a
            ld hl, cy_fm
            or (hl)
            ld (hl), a
            ld a, (cy_h4)           ; top: the camera over it (y > 4 h)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            ex de, hl
            ld hl, (cy_cl + 2)
            or a
            sbc hl, de
            ret c
            ret z
            ld hl, cy_fm
            set 4, (hl)
            ret
cb_nt:
            ; far ones: corners from their middle's projection and three steps' (affine); the
            ; farthest one polygon, their outline, in the haze
            xor a
            ld (cy_aff), a
            ld a, ({oc} + 5)
            cp 2
            jr c, cb_ex
            call cy_bz              ; (its bottom near or behind: steep down on a tall one: exact)
            jr c, cb_ex
            call cy_affs
            ld a, ({oc} + 5)
            cp 4
            jp nc, cy_silh
cb_ex:
            ld hl, cy_faces
            ld b, 5
            ld c, 0                 ; (the face: its shade)
cb_f:
            push bc
            push hl
            ld a, (cy_fm)
            rrca
            ld (cy_fm), a
            jr nc, cb_fn
            ld a, c
            ld (cy_fd), a
            call cy_face
cb_fn:
            pop hl
            inc hl
            inc hl
            inc hl
            inc hl
            pop bc
            inc c
            djnz cb_f
            ret
cy_x6:                              ; HL = 6 A
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ret
cy_lx:                              ; A = a cell -> DE = its middle (128 A - 3008)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, -3008
            add hl, de
            ex de, hl
            ret
cy_side:                            ; HL = d, A = half: 1 if d > half, 2 if d < -half, else 0
            ld e, a
            ld d, 0
            push hl
            or a
            sbc hl, de
            pop hl
            jr z, cs_0
            jp m, cs_n
            ld a, 1
            ret
cs_n:
            add hl, de
            bit 7, h
            jr z, cs_0
            ld a, 2
            ret
cs_0:
            xor a
            ret
; cy_face: the face of the 4 corners at HL drawn (its shade cy_fd: +E, -E, +N, -N, up)
cy_face:
            ld (cf_p), hl
            ld b, 4
cf_c:
            push bc
            push hl
            ld a, (hl)
            call cy_corner
            pop hl
            inc hl
            pop bc
            djnz cf_c
            ld de, (cf_p)           ; the codes: AND, OR
            ld h, vpage >> 8
            ld c, 0
            ld a, #FF
            db #08
            ld b, 4
cf_cd:
            ld a, (de)
            inc de
            ld l, a
            ld a, (hl)
            or c
            ld c, a
            db #08
            and (hl)
            db #08
            djnz cf_cd
            db #08
            and #1F
            ret nz
            ld a, c
            ld ({cmask}), a
            ld a, (cy_fd)           ; the colour
            ld e, a
            ld d, 0
            ld hl, cy_sh
            add hl, de
            ld c, (hl)
            ld a, (cy_ramp)
            ld b, a
            ld a, (cy_fz)
            cp 4
            jr c, cf_nf
            ld b, 10                ; far: the haze ramp, lighter
            ld a, c
            add a, 22
            srl a
            ld c, a
cf_nf:
            ld a, c
            srl a
            ld e, a
            ld a, b
            add a, a
            add a, a
            add a, a
            add a, a
            add a, e
            ld l, a
            bit 0, c
            jr z, cf_d0
            inc a
cf_d0:
            ld h, a
            ld ({pc}), hl
            ld a, ({cmask})
            or a
            jr nz, cf_nfast
            ld hl, (cf_p)
            ld b, 4
            jp ffi
cf_nfast:
            and #1F
            jr nz, cf_clip
            ld hl, (cf_p)           ; in the view, not all on the screen: 16 bit points
            ld ix, {pvx}
            ld a, 4
            ld ({pn}), a
            ld b, 4
cf_fp:
            ld a, (hl)
            inc hl
            push hl
            add a, a
            ld e, a
            ld d, 0
            ld hl, {osx}
            add hl, de
            ld a, (hl)
            ld (ix + 0), a
            inc hl
            ld a, (hl)
            ld (ix + 1), a
            ld hl, {osy}
            add hl, de
            ld a, (hl)
            ld (ix + 96), a
            inc hl
            ld a, (hl)
            ld (ix + 97), a
            inc ix
            inc ix
            pop hl
            djnz cf_fp
            jp fill
cf_clip:
            ld hl, (cf_p)           ; crossing the view's edges: to the clipper
            ld de, {cla}
            ld b, 4
cf_sp:
            push bc
            ld a, (hl)
            inc hl
            push hl
            ld l, a
            ld h, 0
            add hl, hl
            ld b, h
            ld c, l
            add hl, hl
            add hl, bc
            ld bc, {ov}
            add hl, bc
            ld bc, 6
            ldir
            pop hl
            pop bc
            djnz cf_sp
            ld a, 4
            ld ({cn}), a
            jp poly3
; cy_affs: the building's bottom middle, and it plus each step (EW, ED, EH), on the screen:
; cy_p0 and the steps there (cy_dw, cy_dd2, cy_dh)
cy_affs:
            ld hl, (cy_cb)
            ld de, (cy_cb + 2)
            ld bc, (cy_cb + 4)
            call proj
            ld (cy_p0), hl
            ld (cy_p0 + 2), de
            ld hl, (cy_tp)
            ld de, cy_dw
            call ca_one
            ld hl, (cy_tp)
            ld bc, 6
            add hl, bc
            ld de, cy_dd2
            call ca_one
            ld hl, (cy_tp)
            ld bc, 12
            add hl, bc
            ld de, cy_dh
            call ca_one
            ld a, 1
            ld (cy_aff), a
            ret
ca_one:                             ; the step at HL: (cb + it) on the screen - cy_p0 -> 2 words at DE
            push de
            ld ix, cy_cb
            ld b, 3
            ld iy, cr_v
ca_l:
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            push hl
            ld l, (ix + 0)
            ld h, (ix + 1)
            add hl, de
            ld (iy + 0), l
            ld (iy + 1), h
            pop hl
            inc ix
            inc ix
            inc iy
            inc iy
            djnz ca_l
            ld hl, (cr_v)
            ld de, (cr_v + 2)
            ld bc, (cr_v + 4)
            call proj
            ld bc, (cy_p0)
            or a
            sbc hl, bc
            ex de, hl
            ld bc, (cy_p0 + 2)
            or a
            sbc hl, bc
            ex de, hl
            pop bc
            ld a, l
            ld (bc), a
            inc bc
            ld a, h
            ld (bc), a
            inc bc
            ld a, e
            ld (bc), a
            inc bc
            ld a, d
            ld (bc), a
            ret
; cy_acorner: corner (cr_k) on the screen the affine way: p0 -+ dw -+ dd (+ dh), its code by the
; screen (0 or #80: no clipping; far ones are small)
cy_acorner:
            ld a, (cr_k)
            ld c, a
            ld hl, (cy_p0)
            ld de, (cy_dw)
            call ca_pm0
            ld de, (cy_dd2)
            call ca_pm1
            ld de, (cy_dh)
            call ca_p2
            ld (cr_sx), hl
            ld hl, (cy_p0 + 2)
            ld de, (cy_dw + 2)
            call ca_pm0
            ld de, (cy_dd2 + 2)
            call ca_pm1
            ld de, (cy_dh + 2)
            call ca_p2
            ex de, hl               ; DE = y
            ld hl, (cr_sx)
            ld b, h
            ld c, l
            jp cr_put
ca_pm0:                             ; HL -+ DE by bit 0 of C
            bit 0, c
            jr nz, ca_add
            or a
            sbc hl, de
            ret
ca_add:
            add hl, de
            ret
ca_pm1:
            bit 1, c
            jr nz, ca_add
            or a
            sbc hl, de
            ret
ca_p2:
            bit 2, c
            ret z
            add hl, de
            ret
; cy_silh: the farthest: the outline of the faces seen, one polygon in the haze (the top's shade)
cy_silh:
            ld a, (cy_fm)
            and 31
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            or a
            sbc hl, de              ; * 7
            ld de, cy_sil
            add hl, de
            ld a, (hl)
            or a
            ret z
            ld b, a
            inc hl
            ld (cf_p), hl
            ld (sil_n), a
cs_c:
            push bc
            push hl
            ld a, (hl)
            call cy_corner
            pop hl
            inc hl
            pop bc
            djnz cs_c
            ld a, (cy_sh + 4)       ; the colour: the haze, the top's shade lightened
            add a, 22
            srl a
            ld c, a
            srl a
            add a, 10 * 16
            ld l, a
            bit 0, c
            jr z, cs_d0
            inc a
cs_d0:
            ld h, a
            ld ({pc}), hl
            ld de, (cf_p)           ; all in the fast range: the fast way; else 16 bit points
            ld h, vpage >> 8
            ld a, (sil_n)
            ld b, a
            ld c, 0
cs_cd:
            ld a, (de)
            inc de
            ld l, a
            ld a, (hl)
            or c
            ld c, a
            djnz cs_cd
            ld a, c
            or a
            jr nz, cs_slow
            ld hl, (cf_p)
            ld a, (sil_n)
            ld b, a
            jp ffi
cs_slow:
            ld hl, (cf_p)
            ld ix, {pvx}
            ld a, (sil_n)
            ld ({pn}), a
            ld b, a
            jp cf_fp
; cy_corner: corner A (bit 0 +w, bit 1 +d, bit 2 the top) of the building at cy_cb, kind steps
; at cy_tp: in the view, its code, on the screen (as an object's points: ov, vpage, osx, osy)
cy_corner:
            ld (cr_k), a
            ld e, a
            ld d, 0
            ld hl, cr_bit
            add hl, de
            ld c, (hl)
            ld a, (cy_have)
            ld b, a
            and c
            ret nz
            ld a, b
            or c
            ld (cy_have), a
            ld a, (cy_aff)
            or a
            jp nz, cy_acorner
            ld hl, (cy_tp)
            ld ix, cy_cb
            ld iy, cr_v
            ld b, 3
cr_lp:
            push bc
            push hl
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld c, (hl)              ; EW
            inc hl
            ld b, (hl)
            ld a, (cr_k)
            bit 0, a
            jr nz, cr_1
            ex de, hl
            or a
            sbc hl, bc
            jr cr_1e
cr_1:
            ex de, hl
            add hl, bc
cr_1e:
            ex de, hl
            pop hl
            push hl
            ld bc, 6
            add hl, bc
            ld c, (hl)              ; ED
            inc hl
            ld b, (hl)
            ld a, (cr_k)
            bit 1, a
            ex de, hl
            jr nz, cr_2
            or a
            sbc hl, bc
            jr cr_2e
cr_2:
            add hl, bc
cr_2e:
            ex de, hl
            ld a, (cr_k)
            bit 2, a
            jr z, cr_3
            pop hl
            push hl
            ld bc, 12
            add hl, bc
            ld c, (hl)              ; EH
            inc hl
            ld b, (hl)
            ex de, hl
            add hl, bc
            ex de, hl
cr_3:
            ld (iy + 0), e
            ld (iy + 1), d
            pop hl
            inc hl
            inc hl
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz cr_lp
            ld a, (cr_k)            ; ov(k)
            ld l, a
            ld h, 0
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, {ov}
            add hl, de
            ex de, hl
            ld hl, cr_v
            ld bc, 6
            ldir
            ld hl, (cr_v)
            ld de, (cr_v + 2)
            ld bc, (cr_v + 4)
            call vcode
            or a
            jr z, cr_in
            or #80
            jr cr_cd
cr_in:
            ld hl, (cr_v)
            ld de, (cr_v + 2)
            ld bc, (cr_v + 4)
            call proj
            ld b, h
            ld c, l
cr_put:
            ld a, (cr_k)
            add a, a
            push de
            ld e, a
            ld d, 0
            ld hl, {osx}
            add hl, de
            ld (hl), c
            inc hl
            ld (hl), b
            ld hl, {osy}
            add hl, de
            pop de
            ld (hl), e
            inc hl
            ld (hl), d
            ld a, b
            or d
            jr nz, cr_far
            ld a, c
            or a
            jr z, cr_far
            ld a, e
            cp 193
            jr nc, cr_far
            ld a, (cr_k)
            ld l, a
            ld h, vpage >> 8
            ld (hl), 0
            set 6, l
            ld (hl), c
            ld a, l
            xor #C0
            ld l, a
            ld (hl), e
            ret
cr_far:
            ld a, #80
cr_cd:
            ld e, a
            ld a, (cr_k)
            ld l, a
            ld h, vpage >> 8
            ld (hl), e
cc_done:
            ret
; cy_ground: the city's ground, a quad 3136 each way about the site (concrete, dark)
cy_ground:
            ld ix, cy_me            ; corners: c0 -+ E * 3136/16384 -+ N * 3136/16384 (x 49 / 256)
            ld de, cg_e
            call cg_sc
            ld ix, cy_mn
            ld de, cg_n
            call cg_sc
            ld iy, {cla}
            ld a, 0                 ; (-, -), (-, +), (+, +), (+, -): clockwise seen from above
            call cg_pt
            ld a, 2
            call cg_pt
            ld a, 3
            call cg_pt
            ld a, 1
            call cg_pt
            ld ix, {cla}            ; the codes
            ld b, 4
            ld c, 0
            ld e, #FF
cg_cd:
            push bc
            push de
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld c, (ix + 4)
            ld b, (ix + 5)
            call vcode
            pop de
            pop bc
            ld d, a
            or c
            ld c, a
            ld a, d
            and e
            ld e, a
            push de
            ld de, 6
            add ix, de
            pop de
            djnz cg_cd
            ld a, e
            or a
            ret nz
            ld a, c
            ld ({cmask}), a
            ld a, 4
            ld ({cn}), a
            ld hl, 6 * 16 + 4 + (6 * 16 + 5) * 256
            ld ({pc}), hl
            ld a, ({cmask})
            or a
            jp nz, poly3
            ld ix, {cla}            ; (all in the view: projected here)
            ld iy, {pvx}
            ld b, 4
cg_pj:
            push bc
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld c, (ix + 4)
            ld b, (ix + 5)
            call proj
            ld (iy + 0), l
            ld (iy + 1), h
            ld (iy + 96), e
            ld (iy + 97), d
            ld de, 6
            add ix, de
            inc iy
            inc iy
            pop bc
            djnz cg_pj
            ld a, 4
            ld ({pn}), a
            jp fill
cg_sc:                              ; 3 words at IX x 49 / 256 -> DE
            ld b, 3
cgs_lp:
            push bc
            push de
            ld c, (ix + 0)
            ld b, (ix + 1)
            ld de, 49
            call smul               ; >> 8: the middle 16 bits
            ld h, l
            ld l, d
            pop de
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ex de, hl
            inc ix
            inc ix
            pop bc
            djnz cgs_lp
            ret
cg_pt:                              ; corner A (bit 0 +E, bit 1 +N) into (IY), IY on
            ld (cg_k), a
            ld ix, cy_c0
            ld hl, cg_e
            ld de, cg_n
            ld b, 3
cp_lp:
            push bc
            push hl
            push de
            ld c, (hl)
            inc hl
            ld b, (hl)              ; E part
            ld l, (ix + 0)
            ld h, (ix + 1)
            ld a, (cg_k)
            bit 0, a
            jr nz, cp_1
            or a
            sbc hl, bc
            jr cp_1e
cp_1:
            add hl, bc
cp_1e:
            ex de, hl
            ld c, (hl)
            inc hl
            ld b, (hl)              ; N part
            ex de, hl
            bit 1, a
            jr nz, cp_2
            or a
            sbc hl, bc
            jr cp_2e
cp_2:
            add hl, bc
cp_2e:
            ld (iy + 0), l
            ld (iy + 1), h
            inc iy
            inc iy
            inc ix
            inc ix
            pop de
            inc de
            inc de
            pop hl
            inc hl
            inc hl
            pop bc
            djnz cp_lp
            ret
cr_bit:     db 1, 2, 4, 8, 16, 32, 64, 128
cy_sil:                             ; each face mask's outline: how many corners, the corners
            db 0, 0, 0, 0, 0, 0, 0
            db 4, 1, 5, 7, 3, 0, 0
            db 4, 2, 6, 4, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 4, 3, 7, 6, 2, 0, 0
            db 6, 1, 5, 7, 6, 2, 3
            db 6, 6, 4, 0, 2, 3, 7
            db 0, 0, 0, 0, 0, 0, 0
            db 4, 0, 4, 5, 1, 0, 0
            db 6, 5, 7, 3, 1, 0, 4
            db 6, 2, 6, 4, 5, 1, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 4, 4, 6, 7, 5, 0, 0
            db 6, 1, 5, 4, 6, 7, 3
            db 6, 2, 6, 7, 5, 4, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 6, 3, 7, 5, 4, 6, 2
            db 6, 1, 5, 4, 6, 2, 3
            db 6, 4, 0, 2, 3, 7, 5
            db 0, 0, 0, 0, 0, 0, 0
            db 6, 0, 4, 6, 7, 5, 1
            db 6, 7, 3, 1, 0, 4, 6
            db 6, 2, 6, 7, 5, 1, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
            db 0, 0, 0, 0, 0, 0, 0
cy_faces:   db 1, 5, 7, 3           ; +E (clockwise from outside)
            db 2, 6, 4, 0           ; -E
            db 3, 7, 6, 2           ; +N
            db 0, 4, 5, 1           ; -N
            db 4, 6, 7, 5           ; the top
cy_rel:     ds 6
cy_c0:      ds 6
cy_me:      ds 6
cy_mu:      ds 6
cy_mn:      ds 6
cy_e8:      ds 3
cy_u8:      ds 3
cy_n8:      ds 3
cy_cl:      ds 6
cy_sl:      ds 6
cy_sh:      ds 5
cy_tv:      ds 18 * 8
cy_tx:      ds 6 * 48
cy_tz:      ds 6 * 48
cy_i0:      db 0
cy_i1:      db 0
cy_j0:      db 0
cy_j1:      db 0
cy_i:       db 0
cy_j:       db 0
cy_t:       db 0
cy_n:       db 0
cy_zk:      db 0
cy_zj:      dw 0
cy_bf:      ds 144
cy_bi:      db 0
cy_bj:      db 0
cy_bix:     dw 0
cy_tvb:     ds 18
cy_xj:      dw 0
cy_zr:      dw 0
cy_mp:      dw 0
cy_t6:      dw 0
cy_ent:     ds 4 * 120
cy_cnt:     ds 64
cy_ord:     ds 120
cy_cb:      ds 6
cy_tp:      dw 0
cy_kp:      dw 0
cy_w:       db 0
cy_dd:      db 0
cy_h4:      db 0
cy_ramp:    db 0
cy_fz:      db 0
cy_dx:      dw 0
cy_dz:      dw 0
cy_have:    db 0
cy_fm:      db 0
cy_fd:      db 0
cy_f:       db 0
cy_fs:      db 0
cf_p:       dw 0
cr_k:       db 0
cr_v:       ds 6
cr_sx:      dw 0
cy_aff:     db 0
cy_p0:      ds 4
cy_dw:      ds 4
cy_dd2:     ds 4
cy_dh:      ds 4
sil_n:      db 0
ct_dst:     dw 0
ct_m:       dw 0
ct_a:       ds 3
ct_s:       ds 3
cg_e:       ds 6
cg_n:       ds 6
cg_k:       db 0
; ============================================================================ text, aim
; chr: character A (ASCII 32..95) at pixel (tx_x, tx_y) in colour tx_c (E3Data's 5 x 7 font; its set
; pixels only)
chr:
            sub 32
            cp 64
            ret nc
            ld e, a
            ld d, 0
            ld hl, fn_e3data_fontix_fontix_d
            add hl, de
            ld a, (hl)              ; 7 bytes each
            ld l, a
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, hl
            or a
            sbc hl, de
            ld de, fn_e3data_font_font_d
            add hl, de
            ld (tx_g), hl
            ld a, (tx_y)
            ld (tx_r), a
            ld b, 7
tx_row:
            push bc
            ld a, (tx_r)            ; the row's window
            cp 192
            jr nc, tx_nx
            ld e, a
            rlca
            rlca
            and 3
            add a, a
            ld c, a
            ld a, ({back})
            add a, a
            add a, c
            db #ED, #92, #56
            inc a
            db #ED, #92, #57
            ld a, e
            and 63
            or #C0
            ld h, a
            ld a, (tx_x)
            ld l, a
            ld de, (tx_g)
            ld a, (de)
            inc de
            ld (tx_g), de
            ld c, a
            ld a, (tx_c)
            ld b, 5
tx_px:
            sla c
            jr nc, tx_p0
            ld (hl), a
tx_p0:
            inc l
            djnz tx_px
tx_nx:
            ld hl, tx_r
            inc (hl)
            pop bc
            djnz tx_row
            ld a, 10
            db #ED, #92, #56
            ld a, 11
            db #ED, #92, #57
            ret
tx_g:       dw 0
tx_r:       db 0
tx_x:       db 0
tx_y:       db 0
tx_c:       db 0
; aim: the point (aimp: x, y, z / 256 in the world) in the view: aimv (3 words, shifted right by
; aimk to fit 15 bits; its length << aimk is how far)
aim:
            ld ix, {cp}
            ld iy, {aimp}
            ld hl, pl_d
            ld b, 3
am_dl:
            xor a
            sub (ix + 1)
            ld (hl), a
            inc hl
            ld a, (iy + 0)
            sbc a, (ix + 2)
            ld (hl), a
            inc hl
            ld a, (iy + 1)
            sbc a, (ix + 3)
            ld (hl), a
            inc hl
            ld de, 4
            add ix, de
            inc iy
            inc iy
            djnz am_dl
            xor a
            ld (pl_k), a
            call pl_fit
            ld a, (pl_k)
            ld ({aimk}), a
            ld iy, pl_w
            ld ix, {cm}
            call mrow
            ld ({aimv}), hl
            ld ix, {cm} + 6
            call mrow
            ld ({aimv} + 2), hl
            ld ix, {cm} + 12
            call mrow
            ld ({aimv} + 4), hl
            ret
; ============================================================================ the stars
; stars: E3Data's stars (directions) by the camera's 8 bit copy: a pixel each in the view, in its
; colour (none when nstar is 0)
stars:
            ld a, ({nstar})
            or a
            ret z
            ld b, a
            ld hl, fn_e3data_stars_stars_d
            ld a, 255
            ld (st_w), a
st_lp:
            push bc
            ld (st_p), hl
            ld a, (hl)
            ld (st_v), a
            inc hl
            ld a, (hl)
            ld (st_v + 1), a
            inc hl
            ld a, (hl)
            ld (st_v + 2), a
            inc hl
            ld a, (hl)
            ld (st_c), a
            ld ix, cm8 + 6          ; z first: behind - none
            call st_dot
            ld a, h
            or a
            jp m, st_nx
            cp 32                   ; (z under 8192: far off the view)
            jp c, st_nx
            ld (st_z), hl
            ld ix, cm8
            call st_dot
            ld (st_x), hl
            call absh               ; |x| < z
            ld de, (st_z)
            or a
            sbc hl, de
            jp nc, st_nx
            ld ix, cm8 + 3
            call st_dot
            ld (st_y), hl
            call absh               ; |y| < z
            ld de, (st_z)
            or a
            sbc hl, de
            jp nc, st_nx
            ld hl, (st_z)           ; R = 2^24 / (z / 4); x R >> 19 (x / 4 by pj_m)
            srl h
            rr l
            srl h
            rr l
            dec h
            add hl, hl
            ld de, fn_e3data_rproj_rproj_d
            add hl, de
            ld a, (hl)
            ld (pj_rl), a
            inc hl
            ld a, (hl)
            ld (pj_rh), a
            ld hl, (st_x)
            sra h
            rr l
            sra h
            rr l
            call pj_m
            ld de, 128
            add hl, de
            ld a, h
            or a
            jp nz, st_nx
            ld a, l
            ld (st_sx), a
            ld hl, (st_y)
            sra h
            rr l
            sra h
            rr l
            call pj_m
            ex de, hl
            ld hl, 96
            or a
            sbc hl, de
            ld a, h
            or a
            jp nz, st_nx
            ld a, l
            cp 192
            jp nc, st_nx
            ld e, a                 ; the pixel
            rlca
            rlca
            and 3
            ld d, a
            ld a, (st_w)
            cp d
            jr z, st_wok
            ld a, d
            ld (st_w), a
            add a, a
            ld c, a
            ld a, ({back})
            add a, a
            add a, c
            db #ED, #92, #56
            inc a
            db #ED, #92, #57
st_wok:
            ld a, e
            and 63
            or #C0
            ld h, a
            ld a, (st_sx)
            ld l, a
            ld a, (st_c)
            ld (hl), a
st_nx:
            ld hl, (st_p)
            ld de, 4
            add hl, de
            pop bc
            dec b
            jp nz, st_lp
            ld a, 10
            db #ED, #92, #56
            ld a, 11
            db #ED, #92, #57
            ret
st_dot:                             ; (IX: 3 bytes of the camera) . the star -> HL
            ld d, (ix + 0)
            ld a, (st_v)
            ld e, a
            call mul8s
            push de
            ld d, (ix + 1)
            ld a, (st_v + 1)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            push hl
            ld d, (ix + 2)
            ld a, (st_v + 2)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            ret
st_p:       dw 0
st_v:       ds 3
st_c:       db 0
st_w:       db 0
st_sx:      db 0
st_x:       dw 0
st_y:       dw 0
st_z:       dw 0
; ============================================================================ the scene
; scene: the objects in obj (nobj records of 16 bytes: x, y, z, oa, ob, da, db, kind, osc, rad,
; dot colour) turned by their spins, those seen sorted far to near and drawn: near ones by their
; kind's near model, far ones (rad * 8 < z) by its far model, tiny ones (rad * 64 < z) as dots
scene:
            xor a
            ld (sc_n), a
            ld a, ({nobj})
            or a
            ret z
            ld (sc_k), a
            xor a
            ld (sc_i), a
            ld hl, {obj}
            ld (sc_p), hl
sc_lp:
            ld hl, (sc_p)
            ld de, {op}
            ld bc, 6
            ldir                    ; the position
            ld a, (hl)              ; turned: oa += da, ob += db
            inc hl
            inc hl
            add a, (hl)
            dec hl
            dec hl
            ld (hl), a
            inc hl
            ld a, (hl)
            inc hl
            inc hl
            add a, (hl)
            dec hl
            dec hl
            ld (hl), a
            ld de, 5
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({orad}), de
            call oprep8
            ld a, ({ovis})
            or a
            jr z, sc_nx
            ld hl, ({oc} + 4)       ; into the list, far first
            ld (sc_zn), hl
            ld a, (sc_n)
            ld b, a
sc_in:
            ld a, b
            or a
            jr z, sc_put
            dec a
            add a, a
            ld e, a
            ld d, 0
            ld hl, sc_z
            add hl, de
            ld (sc_pz), hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, (sc_zn)
            ex de, hl
            or a
            sbc hl, de
            jp p, sc_put            ; z(j - 1) >= z: here
            ld hl, (sc_pz)          ; z(j) = z(j - 1)
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld (hl), e
            inc hl
            ld (hl), d
            ld hl, sc_x - 1         ; x(j) = x(j - 1)
            ld e, b
            ld d, 0
            add hl, de
            ld a, (hl)
            inc hl
            ld (hl), a
            dec b
            jr sc_in
sc_put:
            ld a, b
            add a, a
            ld e, a
            ld d, 0
            ld hl, sc_z
            add hl, de
            ld de, (sc_zn)
            ld (hl), e
            inc hl
            ld (hl), d
            ld hl, sc_x
            ld e, b
            ld d, 0
            add hl, de
            ld a, (sc_i)
            ld (hl), a
            ld hl, sc_n
            inc (hl)
sc_nx:
            ld hl, (sc_p)
            ld de, 16
            add hl, de
            ld (sc_p), hl
            ld hl, sc_i
            inc (hl)
            ld hl, sc_k
            dec (hl)
            jp nz, sc_lp
            ; ---- drawn far to near
            ld a, (sc_n)
            or a
            ret z
            ld (sc_k), a
            xor a
            ld (sc_j), a
sc_dl:
            ld a, (sc_j)
            ld e, a
            ld d, 0
            ld hl, sc_x
            add hl, de
            ld l, (hl)              ; P = obj + 16 i
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, {obj}
            add hl, de
            ld de, {op}
            ld bc, 6
            ldir
            ld a, (hl)
            ld ({oa}), a
            inc hl
            ld a, (hl)
            ld ({ob}), a
            inc hl
            inc hl
            inc hl
            ld a, (hl)              ; the kind
            ld (sc_kind), a
            inc hl
            ld a, (hl)
            ld ({osc}), a
            inc hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({orad}), de
            inc hl
            ld a, (hl)
            ld (sc_dc), a           ; the dot's colour
            ld a, (sc_j)            ; z: how far
            add a, a
            ld e, a
            ld d, 0
            ld hl, sc_z
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl               ; HL = z: how big (128 rad / z): over 32 pixels near (exact, the
            ld b, 2                 ; near model); 16..32 far (the cheap way, the near model); 4..16
            call sc_shr             ; far (the far model); 2..4 a blob; under 2 a dot
            ld c, 0
            ld a, 0
            jr nc, sc_mod
            ld b, 1
            call sc_shr
            ld a, 1
            jr nc, sc_mod
            ld b, 2
            call sc_shr
            ld c, 2
            jr nc, sc_mod
            ld b, 1
            call sc_shr
            jp nc, sc_blob
            jr sc_dot
sc_mod:
            ld (od_far), a
            ld a, (sc_kind)
            add a, a
            add a, a
            add a, c
            ld e, a
            ld d, 0
            ld hl, fn_e3data_modeltab_modeltab_d
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, fn_e3data_modeldata_modeldata_d
            add hl, de
            ld ({omod}), hl
            call odraw
            jr sc_dnx
sc_blob:
            ld a, 1
            ld (sc_isb), a
            jr sc_db
sc_dot:
            xor a
            ld (sc_isb), a
sc_db:
            call oprep8
            ld a, ({ovis})
            or a
            jr z, sc_dnx
            ld hl, ({oc})
            ld de, ({oc} + 2)
            ld bc, ({oc} + 4)
            ld a, b
            or a
            jp m, sc_dnx
            ld a, c
            cp 16
            jr nc, sc_dp
            ld a, b
            or a
            jr z, sc_dnx            ; (z under 16)
sc_dp:
            ld a, (sc_isb)
            or a
            jr nz, sc_bl
            call proj
            ld a, (sc_dc)
            call dot
            jr sc_dnx
sc_bl:
            call blob
sc_dnx:
            ld hl, sc_j
            inc (hl)
            ld hl, sc_k
            dec (hl)
            jp nz, sc_dl
            ret
sc_shr:                             ; carry: HL >> B > orad (HL kept shifted)
            sra h
            rr l
            djnz sc_shr
            push hl
            ld de, ({orad})
            ex de, hl
            or a
            sbc hl, de              ; orad - (z >> n) < 0: carry
            pop hl
            jp m, sc_sc
            or a
            ret
sc_sc:
            scf
            ret
; blob: the object at oc as a hexagon its size on the screen (orad), in its dot colour (dithered
; with the next shade)
blob:
            ld (bl_z), bc
            push hl
            push de
            call proj               ; the middle
            ld (bl_x), hl
            ld (bl_y), de
            ld hl, ({orad})         ; the size: (128 + rad 128 / z) - 128
            ld de, 0
            ld bc, (bl_z)
            call proj
            ld de, -128
            add hl, de
            pop de
            pop de
            ld a, h
            or a
            ret nz
            ld a, l
            or a
            ret z
            ld (bl_r), a
            srl a
            ld (bl_r2), a           ; r / 2
            ld a, (bl_r)            ; r * 7 / 8
            ld b, a
            srl a
            srl a
            srl a
            neg
            add a, b
            ld (bl_r7), a
            ld ix, {pvx}            ; clockwise from the top left
            ld de, (bl_r2)
            ld d, 0
            ld hl, (bl_x)
            or a
            sbc hl, de
            ld (ix + 0), l
            ld (ix + 1), h
            ld (ix + 8), l
            ld (ix + 9), h
            ld hl, (bl_x)
            add hl, de
            ld (ix + 2), l
            ld (ix + 3), h
            ld (ix + 6), l
            ld (ix + 7), h
            ld a, (bl_r)
            ld e, a
            ld hl, (bl_x)
            add hl, de
            ld (ix + 4), l
            ld (ix + 5), h
            ld hl, (bl_x)
            or a
            sbc hl, de
            ld (ix + 10), l
            ld (ix + 11), h
            ld a, (bl_r7)
            ld e, a
            ld hl, (bl_y)
            or a
            sbc hl, de
            ld (ix + 96), l
            ld (ix + 97), h
            ld (ix + 98), l
            ld (ix + 99), h
            ld hl, (bl_y)
            add hl, de
            ld (ix + 102), l
            ld (ix + 103), h
            ld (ix + 104), l
            ld (ix + 105), h
            ld hl, (bl_y)
            ld (ix + 100), l
            ld (ix + 101), h
            ld (ix + 106), l
            ld (ix + 107), h
            ld a, 6
            ld ({pn}), a
            ld a, (sc_dc)
            ld l, a
            inc a
            ld h, a
            ld ({pc}), hl
            jp fill
bl_x:       dw 0
bl_y:       dw 0
bl_z:       dw 0
bl_r:       db 0
bl_r2:      db 0
            db 0
bl_r7:      db 0
; dot: HL = x, DE = y on the screen, A = the colour: 2 x 2 pixels
dot:
            ld (dt_c), a
            ld a, h
            or d
            ret nz
            ld a, l
            cp 255
            ret nc
            ld a, e
            cp 191
            ret nc
            rlca
            rlca
            and 3
            add a, a
            ld c, a
            ld a, ({back})
            add a, a
            add a, c
            db #ED, #92, #56
            inc a
            db #ED, #92, #57
            ld a, e
            and 63
            or #C0
            ld h, a
            ld a, (dt_c)
            ld (hl), a
            inc l
            ld (hl), a
            inc h
            jr z, dt_e              ; (the row's in the next window: left out)
            ld (hl), a
            dec l
            ld (hl), a
dt_e:
            ld a, 10
            db #ED, #92, #56
            ld a, 11
            db #ED, #92, #57
            ret
dt_c:       db 0
sc_n:       db 0
sc_k:       db 0
sc_i:       db 0
sc_j:       db 0
sc_p:       dw 0
sc_zn:      dw 0
sc_pz:      dw 0
sc_kind:    db 0
sc_dc:      db 0
sc_isb:     db 0
sc_z:       ds 128
sc_x:       ds 64
; ============================================================================ objects
; reld: HL (a position, world, 16 bits) - the camera's (IX: 32 bits, 24.8) -> HL, carry: too far
; (over 16000 any way)
reld:
            ld a, h
            rla
            sbc a, a
            ld c, a
            ld a, l
            sub (ix + 1)
            ld l, a
            ld a, h
            sbc a, (ix + 2)
            ld h, a
            ld a, c
            sbc a, (ix + 3)
            ld c, a
            ld a, h
            rla
            sbc a, a
            cp c
            jr nz, rd_far
            bit 7, h
            jr z, rd_pos
            ld de, 16000
            push hl
            add hl, de
            pop hl
            ccf
            ret
rd_pos:
            ld de, 16001
            push hl
            or a
            sbc hl, de
            pop hl
            ccf
            ret
rd_far:
            scf
            ret
; ctest: HL = a plane's distance, DE = the radius -> A: 0 inside, 1 crossing, 2 outside
ctest:
            push hl
            or a
            adc hl, de
            pop hl
            ld a, 2
            ret m
            or a
            sbc hl, de
            ld a, 1
            ret m
            xor a
            ret
; ocull: oc (in the view), orad -> ovis: 0 outside, 1 all in, 2 crossing the view's edges
ocull:
            xor a
            ld (op_part), a
            ld hl, ({orad})         ; rk = r * 17 / 16 (the side planes lean: their distances are short)
            ld d, h
            ld e, l
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            add hl, de
            ld (op_rk), hl
            ld hl, ({oc} + 4)       ; near: z - 16
            ld de, -16
            add hl, de
            ld de, ({orad})
            call ctest
            call op_acc
            jp z, op_out
            ld hl, ({oc})           ; z - x / 4
            sra h
            rr l
            sra h
            rr l
            ex de, hl
            ld hl, ({oc} + 4)
            or a
            sbc hl, de
            ld de, (op_rk)
            call ctest
            call op_acc
            jp z, op_out
            ld hl, ({oc})           ; z + x / 4
            sra h
            rr l
            sra h
            rr l
            ld de, ({oc} + 4)
            add hl, de
            ld de, (op_rk)
            call ctest
            call op_acc
            jp z, op_out
            ld hl, ({oc} + 2)       ; z - y / 4
            sra h
            rr l
            sra h
            rr l
            ex de, hl
            ld hl, ({oc} + 4)
            or a
            sbc hl, de
            ld de, (op_rk)
            call ctest
            call op_acc
            jp z, op_out
            ld hl, ({oc} + 2)       ; z + y / 4
            sra h
            rr l
            sra h
            rr l
            ld de, ({oc} + 4)
            add hl, de
            ld de, (op_rk)
            call ctest
            call op_acc
            jp z, op_out
            ld a, (op_part)
            inc a
            ld ({ovis}), a
            xor a
            ld ({ovis} + 1), a
            ret
op_out:
            xor a
            ld ({ovis}), a
            ld ({ovis} + 1), a
            ret
op_acc:                             ; A (ctest): Z set when outside
            cp 2
            ret z
            ld b, a
            ld a, (op_part)
            or b
            ld (op_part), a
            or 1
            ret
op_part:    db 0
op_rk:      dw 0
; orel: od = op - the camera; carry: too far
orel:
            ld ix, {cp}
            ld hl, ({op})
            call reld
            ret c
            ld ({od}), hl
            ld ix, {cp} + 4
            ld hl, ({op} + 2)
            call reld
            ret c
            ld ({od} + 2), hl
            ld ix, {cp} + 8
            ld hl, ({op} + 4)
            call reld
            ret c
            ld ({od} + 4), hl
            ret
; oprep: od, oc (exact), ovis
oprep:
            call orel
            jr c, op_out
            ld iy, {od}
            ld ix, {cm}
            call mrow
            ld ({oc}), hl
            ld ix, {cm} + 6
            call mrow
            ld ({oc} + 2), hl
            ld ix, {cm} + 12
            call mrow
            ld ({oc} + 4), hl
            jp ocull
; oprep8: od, oc (by the camera's 8 bit copy: to 1/128), ovis - for sorting and leaving out
oprep8:
            call orel
            jr c, op_out
            ld hl, cm8
            ld de, {oc}
            ld b, 3
o8_r:
            push bc
            push de
            ld (o8_m), hl
            ld hl, 0
            ld (o8_s), hl
            ld ix, {od}
            ld b, 3
o8_t:
            push bc
            ld hl, (o8_m)
            ld a, (hl)
            inc hl
            ld (o8_m), hl
            ld e, (ix + 0)
            ld d, (ix + 1)
            call mt
            ld de, (o8_s)
            add hl, de
            ld (o8_s), hl
            inc ix
            inc ix
            pop bc
            djnz o8_t
            pop de
            ld hl, (o8_s)
            ex de, hl
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ex de, hl
            ld hl, (o8_m)
            pop bc
            djnz o8_r
            jp ocull
o8_m:       dw 0
o8_s:       dw 0
; mt: DE (signed) x A (signed, 127 = 1) >> 7 -> HL
mt:
            ld c, a
            xor d
            ld (mt_sg), a
            ld a, c
            or a
            jp p, mt_1
            neg
            ld c, a
mt_1:
            bit 7, d
            jr z, mt_2
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
mt_2:
            ld a, d                 ; hi
            ld d, c
            mul d, e                ; |a| lo
            ex de, hl
            add hl, hl              ; (carry, H) = |a| lo >> 7
            ld l, h
            ld h, 0
            rl h
            ld e, a
            ld d, c
            mul d, e                ; |a| hi
            ex de, hl
            add hl, hl
            add hl, de              ; 2 |a| hi + (|a| lo >> 7)
            ld a, (mt_sg)
            or a
            ret p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ret
mt_sg:      db 0
; mul8s: D x E (signed) -> DE
mul8s:
            ld h, d
            ld l, e
            mul d, e
            bit 7, h
            jr z, m8s_1
            ld a, d
            sub l
            ld d, a
m8s_1:
            bit 7, l
            ret z
            ld a, d
            sub h
            ld d, a
            ret
; trig: A = angle -> A = sin x 127 (signed), C = cos x 127
trig:
            ld hl, fn_e3data_sines_sines_d
            ld e, a
            ld d, 0
            add hl, de
            ld b, (hl)              ; sin
            add a, 64
            ld e, a
            ld hl, fn_e3data_sines_sines_d
            add hl, de
            ld c, (hl)              ; cos
            ld a, b
            ret
; odraw: the object drawn
odraw:
            ld a, (od_far)          ; (far: the cheap way - by the 8 bit camera)
            or a
            jr z, od_ex
            call oprep8
            jr od_vis
od_ex:
            call oprep
od_vis:
            ld a, ({ovis})
            or a
            ret z
            xor a
            ld (oe_ok), a
            ; O = Ry(oa) Rx(ob): C = M O by columns: Cc0 = ca Mc0 - sa Mc2, P = sa Mc0 + ca Mc2,
            ; Cc1 = sb P + cb Mc1, Cc2 = cb P - sb Mc1 (Mc j: the camera's column j)
            ld a, ({oa})
            call trig
            ld (od_sa), a
            ld a, c
            ld (od_ca), a
            ld a, ({ob})
            call trig
            ld (od_sb), a
            ld a, c
            ld (od_cb), a
            ld a, 6
            ld hl, {osc}
            sub (hl)
            ld (od_shf), a
            ld a, (od_far)
            or a
            jp nz, od_c8
            ld a, (od_shf)          ; the camera >> (6 - osc)
            ld l, a
            add a, a
            add a, a
            add a, a
            add a, l
            add a, a                ; * 18
            ld e, a
            ld d, 0
            ld ix, cms
            add ix, de
            ld iy, {ccl}
            ld b, 3
oc_lp:
            push bc
            ld e, (ix + 0)          ; Cc0 = ca Mc0 - sa Mc2
            ld d, (ix + 1)
            ld a, (od_ca)
            call mt
            ld (od_t), hl
            ld e, (ix + 4)
            ld d, (ix + 5)
            ld a, (od_sa)
            call mt
            ex de, hl
            ld hl, (od_t)
            or a
            sbc hl, de
            ld (iy + 0), l
            ld (iy + 1), h
            ld e, (ix + 0)          ; P = sa Mc0 + ca Mc2
            ld d, (ix + 1)
            ld a, (od_sa)
            call mt
            ld (od_t), hl
            ld e, (ix + 4)
            ld d, (ix + 5)
            ld a, (od_ca)
            call mt
            ld de, (od_t)
            add hl, de
            ld (od_p), hl
            ex de, hl               ; Cc1 = sb P + cb Mc1
            ld a, (od_sb)
            call mt
            ld (od_t), hl
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld a, (od_cb)
            call mt
            ld de, (od_t)
            add hl, de
            ld (iy + 6), l
            ld (iy + 7), h
            ld de, (od_p)           ; Cc2 = cb P - sb Mc1
            ld a, (od_cb)
            call mt
            ld (od_t), hl
            ld e, (ix + 2)
            ld d, (ix + 3)
            ld a, (od_sb)
            call mt
            ex de, hl
            ld hl, (od_t)
            or a
            sbc hl, de
            ld (iy + 12), l
            ld (iy + 13), h
            ld de, 6
            add ix, de
            inc iy
            inc iy
            pop bc
            dec b
            jp nz, oc_lp
od_osn:
            ; the sun in the model (8 bit): osn8 = O^T sunw8 = Rx^T (Ry^T sunw8)
            ld a, (sunw8)           ; Ry^T: x1 = ca sx - sa sz, z1 = sa sx + ca sz
            ld d, a
            ld a, (od_ca)
            ld e, a
            call mul8s
            push de
            ld a, (sunw8 + 2)
            ld d, a
            ld a, (od_sa)
            ld e, a
            call mul8s
            pop hl
            or a
            sbc hl, de
            add hl, hl
            ld a, h
            ld (osn8), a            ; x
            ld a, (sunw8)
            ld d, a
            ld a, (od_sa)
            ld e, a
            call mul8s
            push de
            ld a, (sunw8 + 2)
            ld d, a
            ld a, (od_ca)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            add hl, hl
            ld a, h
            ld (od_z1), a           ; z1
            ld a, (sunw8 + 1)       ; Rx^T: y = cb sy + sb z1, z = cb z1 - sb sy
            ld d, a
            ld a, (od_cb)
            ld e, a
            call mul8s
            push de
            ld a, (od_z1)
            ld d, a
            ld a, (od_sb)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            add hl, hl
            ld a, h
            ld (osn8 + 1), a
            ld a, (od_z1)
            ld d, a
            ld a, (od_cb)
            ld e, a
            call mul8s
            push de
            ld a, (sunw8 + 1)
            ld d, a
            ld a, (od_sb)
            ld e, a
            call mul8s
            pop hl
            or a
            sbc hl, de
            add hl, hl
            ld a, h
            ld (osn8 + 2), a
            ; C' (C by the camera scaled to the object's size) into the transform: |C'| and its sign
            ; into each term (;@@SPLIT, tools/gen_xform.py)
            ld hl, ({ccl} + 0)
            bit 7, h
            jr z, xs00p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt00h + 1), a
            ld a, l
            ld (xt00l + 1), a
            ld a, #B7
            ld (xt00a), a
            ld (xt00b), a
            ld hl, #52ED
            ld (xt00a + 1), hl
            ld (xt00b + 1), hl
            jr xs00e
xs00p:
            ld a, h
            ld (xt00h + 1), a
            ld a, l
            ld (xt00l + 1), a
            xor a
            ld (xt00a), a
            ld (xt00b), a
            ld hl, #1900
            ld (xt00a + 1), hl
            ld (xt00b + 1), hl
xs00e:
            ld hl, ({ccl} + 6)
            bit 7, h
            jr z, xs01p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt01h + 1), a
            ld a, l
            ld (xt01l + 1), a
            ld a, #B7
            ld (xt01a), a
            ld (xt01b), a
            ld hl, #52ED
            ld (xt01a + 1), hl
            ld (xt01b + 1), hl
            jr xs01e
xs01p:
            ld a, h
            ld (xt01h + 1), a
            ld a, l
            ld (xt01l + 1), a
            xor a
            ld (xt01a), a
            ld (xt01b), a
            ld hl, #1900
            ld (xt01a + 1), hl
            ld (xt01b + 1), hl
xs01e:
            ld hl, ({ccl} + 12)
            bit 7, h
            jr z, xs02p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt02h + 1), a
            ld a, l
            ld (xt02l + 1), a
            ld a, #B7
            ld (xt02a), a
            ld (xt02b), a
            ld hl, #52ED
            ld (xt02a + 1), hl
            ld (xt02b + 1), hl
            jr xs02e
xs02p:
            ld a, h
            ld (xt02h + 1), a
            ld a, l
            ld (xt02l + 1), a
            xor a
            ld (xt02a), a
            ld (xt02b), a
            ld hl, #1900
            ld (xt02a + 1), hl
            ld (xt02b + 1), hl
xs02e:
            ld hl, ({ccl} + 2)
            bit 7, h
            jr z, xs10p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt10h + 1), a
            ld a, l
            ld (xt10l + 1), a
            ld a, #B7
            ld (xt10a), a
            ld (xt10b), a
            ld hl, #52ED
            ld (xt10a + 1), hl
            ld (xt10b + 1), hl
            jr xs10e
xs10p:
            ld a, h
            ld (xt10h + 1), a
            ld a, l
            ld (xt10l + 1), a
            xor a
            ld (xt10a), a
            ld (xt10b), a
            ld hl, #1900
            ld (xt10a + 1), hl
            ld (xt10b + 1), hl
xs10e:
            ld hl, ({ccl} + 8)
            bit 7, h
            jr z, xs11p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt11h + 1), a
            ld a, l
            ld (xt11l + 1), a
            ld a, #B7
            ld (xt11a), a
            ld (xt11b), a
            ld hl, #52ED
            ld (xt11a + 1), hl
            ld (xt11b + 1), hl
            jr xs11e
xs11p:
            ld a, h
            ld (xt11h + 1), a
            ld a, l
            ld (xt11l + 1), a
            xor a
            ld (xt11a), a
            ld (xt11b), a
            ld hl, #1900
            ld (xt11a + 1), hl
            ld (xt11b + 1), hl
xs11e:
            ld hl, ({ccl} + 14)
            bit 7, h
            jr z, xs12p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt12h + 1), a
            ld a, l
            ld (xt12l + 1), a
            ld a, #B7
            ld (xt12a), a
            ld (xt12b), a
            ld hl, #52ED
            ld (xt12a + 1), hl
            ld (xt12b + 1), hl
            jr xs12e
xs12p:
            ld a, h
            ld (xt12h + 1), a
            ld a, l
            ld (xt12l + 1), a
            xor a
            ld (xt12a), a
            ld (xt12b), a
            ld hl, #1900
            ld (xt12a + 1), hl
            ld (xt12b + 1), hl
xs12e:
            ld hl, ({ccl} + 4)
            bit 7, h
            jr z, xs20p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt20h + 1), a
            ld a, l
            ld (xt20l + 1), a
            ld a, #B7
            ld (xt20a), a
            ld (xt20b), a
            ld hl, #52ED
            ld (xt20a + 1), hl
            ld (xt20b + 1), hl
            jr xs20e
xs20p:
            ld a, h
            ld (xt20h + 1), a
            ld a, l
            ld (xt20l + 1), a
            xor a
            ld (xt20a), a
            ld (xt20b), a
            ld hl, #1900
            ld (xt20a + 1), hl
            ld (xt20b + 1), hl
xs20e:
            ld hl, ({ccl} + 10)
            bit 7, h
            jr z, xs21p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt21h + 1), a
            ld a, l
            ld (xt21l + 1), a
            ld a, #B7
            ld (xt21a), a
            ld (xt21b), a
            ld hl, #52ED
            ld (xt21a + 1), hl
            ld (xt21b + 1), hl
            jr xs21e
xs21p:
            ld a, h
            ld (xt21h + 1), a
            ld a, l
            ld (xt21l + 1), a
            xor a
            ld (xt21a), a
            ld (xt21b), a
            ld hl, #1900
            ld (xt21a + 1), hl
            ld (xt21b + 1), hl
xs21e:
            ld hl, ({ccl} + 16)
            bit 7, h
            jr z, xs22p
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ld a, h
            ld (xt22h + 1), a
            ld a, l
            ld (xt22l + 1), a
            ld a, #B7
            ld (xt22a), a
            ld (xt22b), a
            ld hl, #52ED
            ld (xt22a + 1), hl
            ld (xt22b + 1), hl
            jr xs22e
xs22p:
            ld a, h
            ld (xt22h + 1), a
            ld a, l
            ld (xt22l + 1), a
            xor a
            ld (xt22a), a
            ld (xt22b), a
            ld hl, #1900
            ld (xt22a + 1), hl
            ld (xt22b + 1), hl
xs22e:
            ; the rows' starts: c i - K i (K i = (C'(i, 0) + C'(i, 1) + C'(i, 2)) / 2: the 128 the
            ; points' coordinates carry)
            ld hl, ({ccl} + 0)
            ld de, ({ccl} + 6)
            add hl, de
            ld de, ({ccl} + 12)
            add hl, de
            sra h
            rr l
            ex de, hl
            ld hl, ({oc} + 0)
            or a
            sbc hl, de
            ld (xr0c + 1), hl
            ld hl, ({ccl} + 2)
            ld de, ({ccl} + 8)
            add hl, de
            ld de, ({ccl} + 14)
            add hl, de
            sra h
            rr l
            ex de, hl
            ld hl, ({oc} + 2)
            or a
            sbc hl, de
            ld (xr1c + 1), hl
            ld hl, ({ccl} + 4)
            ld de, ({ccl} + 10)
            add hl, de
            ld de, ({ccl} + 16)
            add hl, de
            sra h
            rr l
            ex de, hl
            ld hl, ({oc} + 4)
            or a
            sbc hl, de
            ld (xr2c + 1), hl
            jp ov_go
od_sa:      db 0
od_ca:      db 0
od_sb:      db 0
od_cb:      db 0
od_sh:      db 0
od_t:       dw 0
od_p:       dw 0
oe_ok:      db 0
od_far:     db 0
od_shf:     db 0
od_p8:      db 0
od_z1:      db 0
osn8:       ds 3
; od_c8: the far way's C' = (the 8 bit camera) O >> (6 - osc), row by row
od_c8:
            ld ix, cm8
            ld iy, {ccl}
            ld b, 3
c8_lp:
            push bc
            ld d, (ix + 0)          ; Cc0 = ca M0 - sa M2
            ld a, (od_ca)
            ld e, a
            call mul8s
            push de
            ld d, (ix + 2)
            ld a, (od_sa)
            ld e, a
            call mul8s
            pop hl
            or a
            sbc hl, de
            call c8_sh
            ld (iy + 0), l
            ld (iy + 1), h
            ld d, (ix + 0)          ; P = (sa M0 + ca M2) >> 7
            ld a, (od_sa)
            ld e, a
            call mul8s
            push de
            ld d, (ix + 2)
            ld a, (od_ca)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            add hl, hl
            ld a, h
            ld (od_p8), a
            ld d, a                 ; Cc1 = sb P + cb M1
            ld a, (od_sb)
            ld e, a
            call mul8s
            push de
            ld d, (ix + 1)
            ld a, (od_cb)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            call c8_sh
            ld (iy + 6), l
            ld (iy + 7), h
            ld a, (od_p8)           ; Cc2 = cb P - sb M1
            ld d, a
            ld a, (od_cb)
            ld e, a
            call mul8s
            push de
            ld d, (ix + 1)
            ld a, (od_sb)
            ld e, a
            call mul8s
            pop hl
            or a
            sbc hl, de
            call c8_sh
            ld (iy + 12), l
            ld (iy + 13), h
            inc ix
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            dec b
            jp nz, c8_lp
            jp od_osn
c8_sh:                              ; HL >> (6 - osc)
            ld a, (od_shf)
            or a
            ret z
            ld b, a
c8_s:
            sra h
            rr l
            djnz c8_s
            ret
; od_pa: the far way's faces first: e8 = O^T (-od) (shifted under 64 each way: k), each face seen
; if n . e8 > d >> (k - osc); those seen listed (fvis) and their points marked (vmark)
od_pa:
            ld hl, ({od})
            call oe_neg
            ld (pa_w), de
            ld hl, ({od} + 2)
            call oe_neg
            ld (pa_w + 2), de
            ld hl, ({od} + 4)
            call oe_neg
            ld (pa_w + 4), de
            xor a
            ld (pa_k), a
pa_fit:
            ld hl, pa_w
            ld b, 3
pa_ck:
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld a, e                 ; -64..63: w + 64 in 0..127
            add a, 64
            ld c, a
            ld a, d
            adc a, 0
            jr nz, pa_half
            bit 7, c
            jr nz, pa_half
            djnz pa_ck
            jr pa_rot
pa_half:
            ld hl, pa_w
            ld b, 3
pa_hl:
            inc hl
            sra (hl)
            dec hl
            rr (hl)
            inc hl
            inc hl
            djnz pa_hl
            ld hl, pa_k
            inc (hl)
            jr pa_fit
pa_rot:
            ld a, (pa_w)            ; Ry^T: x1 = ca x - sa z, z1 = sa x + ca z
            ld d, a
            ld a, (od_ca)
            ld e, a
            call mul8s
            push de
            ld a, (pa_w + 4)
            ld d, a
            ld a, (od_sa)
            ld e, a
            call mul8s
            pop hl
            or a
            sbc hl, de
            add hl, hl
            ld a, h
            ld (pa_e), a
            ld a, (pa_w)
            ld d, a
            ld a, (od_sa)
            ld e, a
            call mul8s
            push de
            ld a, (pa_w + 4)
            ld d, a
            ld a, (od_ca)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            add hl, hl
            ld a, h
            ld (pa_z1), a
            ld a, (pa_w + 2)        ; Rx^T: y = cb y1 + sb z1, z = cb z1 - sb y1
            ld d, a
            ld a, (od_cb)
            ld e, a
            call mul8s
            push de
            ld a, (pa_z1)
            ld d, a
            ld a, (od_sb)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            add hl, hl
            ld a, h
            ld (pa_e + 1), a
            ld a, (pa_z1)
            ld d, a
            ld a, (od_cb)
            ld e, a
            call mul8s
            push de
            ld a, (pa_w + 2)
            ld d, a
            ld a, (od_sb)
            ld e, a
            call mul8s
            pop hl
            or a
            sbc hl, de
            add hl, hl
            ld a, h
            ld (pa_e + 2), a
            ld a, (pa_k)            ; m = k - osc
            ld hl, {osc}
            sub (hl)
            ld (pa_m), a
            ld hl, ({omod})         ; no points marked (as many as the model has)
            ld b, (hl)
            ld hl, vmark
pa_cl:
            ld (hl), 0
            inc hl
            djnz pa_cl
            ld hl, fvis
            ld (pa_lp), hl
            xor a
            ld (fv_n), a
            ld hl, ({omod})         ; the faces: after the points
            ld a, (hl)
            ld e, a
            add a, a
            add a, e
            add a, 3
            ld e, a
            ld d, 0
            jr nc, pa_f0
            inc d
pa_f0:
            inc hl
            ld a, (hl)
            ld (pa_nf), a
            dec hl
            add hl, de
            push hl
            pop iy
pa_lp0:
            ld d, (iy + 2)          ; n . e8
            ld a, (pa_e)
            ld e, a
            call mul8s
            push de
            ld d, (iy + 3)
            ld a, (pa_e + 1)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            push hl
            ld d, (iy + 4)
            ld a, (pa_e + 2)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            push hl
            ld l, (iy + 5)          ; d >> m (m < 0: << -m)
            ld h, (iy + 6)
            ld a, (pa_m)
            or a
            jr z, pa_d0
            jp m, pa_dl
            ld b, a
pa_dr:
            sra h
            rr l
            djnz pa_dr
            jr pa_d0
pa_dl:
            neg
            ld b, a
pa_dls:
            add hl, hl
            djnz pa_dls
pa_d0:
            ex de, hl
            pop hl
            or a
            sbc hl, de              ; n . e8 - d': seen when > 0
            jp m, pa_nx
            jr z, pa_nx
            ld hl, (pa_lp)          ; listed
            push iy
            pop de
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (pa_lp), hl
            ld hl, fv_n
            inc (hl)
            ld b, (iy + 0)          ; its points marked
            push iy
            pop hl
            ld de, 7
            add hl, de
pa_mk:
            ld a, (hl)
            inc hl
            push hl
            ld e, a
            ld d, 0
            ld hl, vmark
            add hl, de
            ld (hl), 1
            pop hl
            djnz pa_mk
pa_nx:
            ld a, (iy + 0)
            add a, 7
            ld e, a
            ld d, 0
            add iy, de
            ld hl, pa_nf
            dec (hl)
            jp nz, pa_lp0
            ret
pa_w:       ds 6
pa_k:       db 0
pa_m:       db 0
pa_e:       ds 3
pa_z1:      db 0
pa_nf:      db 0
pa_lp:      dw 0
fv_n:       db 0
fv_i:       dw 0
fvis:       ds 128
vmark:      ds 64
; ---- the vertices
ov_go:
            ld a, (od_far)
            or a
            jr z, ov_g1
            call od_pa
            ld a, (fv_n)
            or a
            ret z
ov_g1:
            ld hl, ({omod})
            ld a, (hl)
            ld (xv_k), a
            inc hl
            ld a, (hl)
            ld (of_k), a
            inc hl
            inc hl
            ld (xv_p), hl
            ld hl, {ov}
            ld (xv_o), hl
            ld hl, {osx}
            ld (xv_sx), hl
            ld hl, {osy}
            ld (xv_sy), hl
            xor a
            ld (xv_i), a
            ld (xv_or), a
xv_lp:
            ld a, (od_far)          ; (the far way: only the points of faces seen)
            or a
            jr z, xv_go
            ld a, (xv_i)
            ld e, a
            ld d, 0
            ld hl, vmark
            add hl, de
            ld a, (hl)
            or a
            jr nz, xv_go
            ld hl, (xv_p)
            inc hl
            inc hl
            inc hl
            ld (xv_p), hl
            ld a, ({ovis})
            cp 2
            jp nz, xv_nx
            ld hl, (xv_o)
            ld de, 6
            add hl, de
            ld (xv_o), hl
            jp xv_nx
xv_go:
            ld hl, (xv_p)
            ld a, (hl)
            xor #80
            ld b, a
            inc hl
            ld a, (hl)
            xor #80
            ld c, a
            inc hl
            ld a, (hl)
            xor #80
            ld iyl, a
            inc hl
            ld (xv_p), hl
;@@XFORM (tools/gen_xform.py)
xr0c:      ld hl, 0
            ld e, b
xt00h:      ld d, 0
            mul d, e
xt00a:      nop
            nop
            add hl, de
            ld e, b
xt00l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt00b:      nop
            nop
            add hl, de
            ld e, c
xt01h:      ld d, 0
            mul d, e
xt01a:      nop
            nop
            add hl, de
            ld e, c
xt01l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt01b:      nop
            nop
            add hl, de
            ld e, iyl
xt02h:      ld d, 0
            mul d, e
xt02a:      nop
            nop
            add hl, de
            ld e, iyl
xt02l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt02b:      nop
            nop
            add hl, de
            ld (xv_o0), hl
xr1c:      ld hl, 0
            ld e, b
xt10h:      ld d, 0
            mul d, e
xt10a:      nop
            nop
            add hl, de
            ld e, b
xt10l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt10b:      nop
            nop
            add hl, de
            ld e, c
xt11h:      ld d, 0
            mul d, e
xt11a:      nop
            nop
            add hl, de
            ld e, c
xt11l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt11b:      nop
            nop
            add hl, de
            ld e, iyl
xt12h:      ld d, 0
            mul d, e
xt12a:      nop
            nop
            add hl, de
            ld e, iyl
xt12l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt12b:      nop
            nop
            add hl, de
            ld (xv_o1), hl
xr2c:      ld hl, 0
            ld e, b
xt20h:      ld d, 0
            mul d, e
xt20a:      nop
            nop
            add hl, de
            ld e, b
xt20l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt20b:      nop
            nop
            add hl, de
            ld e, c
xt21h:      ld d, 0
            mul d, e
xt21a:      nop
            nop
            add hl, de
            ld e, c
xt21l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt21b:      nop
            nop
            add hl, de
            ld e, iyl
xt22h:      ld d, 0
            mul d, e
xt22a:      nop
            nop
            add hl, de
            ld e, iyl
xt22l:      ld d, 0
            mul d, e
            ld e, d
            ld d, 0
xt22b:      nop
            nop
            add hl, de
            ld (xv_o2), hl
;@@XFORM-END
            ld a, ({ovis})
            cp 2
            jr nz, xv_in
            ld hl, (xv_o)           ; crossing the view's edges: the vertex in the view kept (the
            ld de, (xv_o0)          ; clipper's), and its code
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (xv_o1)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld de, (xv_o2)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (xv_o), hl
            ld hl, (xv_o0)
            ld de, (xv_o1)
            ld bc, (xv_o2)
            call vcode
            or a
            jr z, xv_in
            or #80
            jr xv_cd
xv_in:
            ld hl, (xv_o0)          ; on the screen: 16 bits (osx, osy), and bytes in vpage when in
            ld de, (xv_o1)          ; the fast range (x 1..255, y 0..192: code 0; else bit 7)
            ld bc, (xv_o2)
            call proj
            ld b, h
            ld c, l
            ld hl, (xv_sx)
            ld (hl), c
            inc hl
            ld (hl), b
            ld hl, (xv_sy)
            ld (hl), e
            inc hl
            ld (hl), d
            ld a, b
            or d
            jr nz, xv_far
            ld a, c
            or a
            jr z, xv_far
            ld a, e
            cp 193
            jr nc, xv_far
            ld a, (xv_i)
            ld l, a
            ld h, vpage >> 8
            ld (hl), 0
            set 6, l
            ld (hl), c
            ld a, l
            xor #C0
            ld l, a
            ld (hl), e
            jr xv_nx
xv_far:
            ld a, #80
xv_cd:
            ld e, a
            ld hl, xv_or
            or (hl)
            ld (hl), a
            ld a, (xv_i)
            ld l, a
            ld h, vpage >> 8
            ld (hl), e
xv_nx:
            ld hl, xv_i
            inc (hl)
            ld hl, (xv_sx)
            inc hl
            inc hl
            ld (xv_sx), hl
            ld hl, (xv_sy)
            inc hl
            inc hl
            ld (xv_sy), hl
            ld a, (xv_k)
            dec a
            ld (xv_k), a
            jp nz, xv_lp
            ; ---- the faces
            ld iy, (xv_p)
            ld a, (od_far)
            or a
            jr z, of_lp
            ld hl, fvis
            ld (fv_i), hl
            ld a, (fv_n)
            ld (of_k), a
of_fv:
            ld hl, (fv_i)
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld (fv_i), hl
            push de
            pop iy
of_lp:
            ld a, (iy + 0)
            ld (of_n), a
            ld b, a
            push iy
            pop de
            ld hl, 7
            add hl, de
            ld (of_ix), hl
            ld a, (xv_or)           ; (all the object's points in the fast range: no codes to see)
            or a
            jr nz, of_cds
            ld ({cmask}), a
            jp of_fw
of_cds:
            ex de, hl               ; DE: the points
            ld h, vpage >> 8        ; their codes: all outside one plane: not seen; OR in C
            ld c, 0
            ld a, #FF
            db #08                  ; (A': the AND)
of_cd:
            ld a, (de)
            inc de
            ld l, a
            ld a, (hl)
            or c
            ld c, a
            db #08
            and (hl)
            db #08
            djnz of_cd
            db #08
            and #1F
            jp nz, of_skip
            ld a, c
            ld ({cmask}), a
            or a
            jp nz, of_3d
            ; all in the fast range: seen if clockwise on the screen (the first three points' bytes)
of_fw:
            ld a, (od_far)
            or a
            jp nz, of_lit
            ld de, (of_ix)
            ld h, vpage >> 8
            ld a, (de)
            inc de
            or #40
            ld l, a
            ld b, (hl)              ; x0
            xor #C0
            ld l, a
            ld c, (hl)              ; y0
            ld a, (de)
            inc de
            or #40
            ld l, a
            ld a, (hl)
            sub b
            ld (of_a), a            ; x1 - x0 (and its sign)
            sbc a, a
            ld (of_as), a
            ld a, l
            xor #C0
            ld l, a
            ld a, (hl)
            sub c
            ld (of_c), a            ; y1 - y0
            sbc a, a
            ld (of_cs), a
            ld a, (de)
            or #40
            ld l, a
            ld a, (hl)
            sub b
            ld (of_d), a            ; x2 - x0
            sbc a, a
            ld (of_ds), a
            ld a, l
            xor #C0
            ld l, a
            ld a, (hl)
            sub c
            ld (of_b), a            ; y2 - y0
            sbc a, a
            ld (of_bs), a
            ; (x1 - x0)(y2 - y0) - (y1 - y0)(x2 - x0) > 0: the sizes multiplied, the signs apart
            ld a, (of_as)
            or a
            ld a, (of_a)
            jr z, ow_1
            neg
ow_1:
            ld d, a
            ld a, (of_bs)
            or a
            ld a, (of_b)
            jr z, ow_2
            neg
ow_2:
            ld e, a
            mul d, e
            push de                 ; |p1|
            ld a, (of_cs)
            or a
            ld a, (of_c)
            jr z, ow_3
            neg
ow_3:
            ld d, a
            ld a, (of_ds)
            or a
            ld a, (of_d)
            jr z, ow_4
            neg
ow_4:
            ld e, a
            mul d, e                ; |p2|
            pop hl                  ; |p1|
            ld a, (of_as)
            ld b, a
            ld a, (of_bs)
            xor b
            ld b, a                 ; p1's sign
            ld a, (of_cs)
            ld c, a
            ld a, (of_ds)
            xor c                   ; p2's sign
            jr nz, ow_n2
            ld a, b                 ; p2 >= 0
            or a
            jp nz, of_skip          ; p1 < 0: p1 - p2 < 0
            or a                    ; both >= 0: |p1| > |p2|
            sbc hl, de
            jp z, of_skip
            jp c, of_skip
            jp of_lit
ow_n2:
            ld a, b                 ; p2 < 0
            or a
            jr nz, ow_nn
            ld a, h                 ; p1 >= 0: seen unless both 0
            or l
            or d
            or e
            jp z, of_skip
            jp of_lit
ow_nn:
            ex de, hl               ; both < 0: |p2| > |p1|
            or a
            sbc hl, de
            jp z, of_skip
            jp c, of_skip
            jp of_lit
of_3d:
            ld a, (od_far)
            or a
            jp nz, of_lit
            ld a, ({cmask})
            and #1F
            jp z, of_w16
            ; crossing the view's edges: seen if n . e > d (e: the camera in the model)
            ld a, (oe_ok)
            or a
            call z, of_e
            ld hl, {oe}
            call ndot
            ld e, (iy + 5)
            ld d, (iy + 6)
            ld a, d
            rla
            sbc a, a
            ld c, a
            ld hl, (nd_l)
            or a
            sbc hl, de
            ld a, (nd_h)
            sbc a, c
            jp m, of_skip
            or h
            or l
            jp z, of_skip
of_lit:
            ; the shade: 3 + n . sun (0..30: 16 shades and the steps between, dithered)
            ld d, (iy + 2)
            ld a, (osn8)
            ld e, a
            call mul8s
            push de
            ld d, (iy + 3)
            ld a, (osn8 + 1)
            ld e, a
            call mul8s
            pop hl
            add hl, de
            push hl
            ld d, (iy + 4)
            ld a, (osn8 + 2)
            ld e, a
            call mul8s
            pop hl
            add hl, de              ; n . sun (to +-15240)
            add hl, hl
            ld a, h                 ; >> 7 (to +-119), then / 4
            sra a
            sra a
            bit 7, a
            jr z, of_lp1
            sra a
            sra a
            add a, 3
            jp p, of_lv
            xor a
            jr of_lv
of_lp1:
            add a, 3
            cp 31
            jr c, of_lv
            ld a, 30
of_lv:
            ld c, a
            srl a
            ld b, a
            ld a, (iy + 1)          ; ramp * 16 + level / 2
            add a, a
            add a, a
            add a, a
            add a, a
            add a, b
            ld l, a
            bit 0, c
            jr z, of_d0
            inc a
of_d0:
            ld h, a
            ld ({pc}), hl
            ld a, ({cmask})
            or a
            jr nz, of_nf
            ld hl, (of_ix)          ; all in the fast range: filled from their bytes
            ld a, (of_n)
            ld b, a
            push iy
            call ffi
            pop iy
            jp of_skip
of_nf:
            and #1F
            jr nz, of_slow
            ; in the view (some off the screen): the screen points (16 bits) to pvx, pvy
            ld a, (of_n)
            ld ({pn}), a
            ld b, a
            ld hl, (of_ix)
            ld ix, {pvx}
of_fp:
            push bc
            ld a, (hl)
            inc hl
            push hl
            add a, a
            ld c, a
            ld b, 0
            ld hl, {osx}
            add hl, bc
            ld a, (hl)
            ld (ix + 0), a
            inc hl
            ld a, (hl)
            ld (ix + 1), a
            ld hl, {osy}
            add hl, bc
            ld a, (hl)
            ld (ix + 96), a
            inc hl
            ld a, (hl)
            ld (ix + 97), a
            inc ix
            inc ix
            pop hl
            pop bc
            djnz of_fp
            push iy
            call fill
            pop iy
            jr of_skip
of_slow:
            ; crossing the view's edges: the points in the view to the clipper
            ld a, (of_n)
            ld ({cn}), a
            ld b, a
            ld hl, (of_ix)
            ld de, {cla}
of_sp:
            push bc
            ld a, (hl)
            inc hl
            push hl
            ld l, a
            ld h, 0
            add hl, hl
            ld b, h
            ld c, l
            add hl, hl
            add hl, bc
            ld bc, {ov}
            add hl, bc
            ld bc, 6
            ldir
            pop hl
            pop bc
            djnz of_sp
            push iy
            call poly3
            pop iy
of_skip:
            ld a, (od_far)
            or a
            jr z, of_sq
            ld hl, of_k
            dec (hl)
            jp nz, of_fv
            ret
of_sq:
            ld a, (iy + 0)
            add a, 7
            ld e, a
            ld d, 0
            add iy, de
            ld a, (of_k)
            dec a
            ld (of_k), a
            jp nz, of_lp
            ret
; of_w16: in the view, not all in the fast range: seen if clockwise on the screen (16 bit points,
; halved together till the differences fit 8 bits)
of_w16:
            ld hl, (of_ix)
            ld a, (hl)
            call ow_pt
            ld (ow_x0), bc
            ld (ow_y0), de
            ld hl, (of_ix)
            inc hl
            ld a, (hl)
            call ow_pt
            ld hl, (ow_x0)
            call ow_sub
            ld (ow_a), bc
            ld b, d
            ld c, e
            ld hl, (ow_y0)
            call ow_sub
            ld (ow_c), bc
            ld hl, (of_ix)
            inc hl
            inc hl
            ld a, (hl)
            call ow_pt
            ld hl, (ow_x0)
            call ow_sub
            ld (ow_d), bc
            ld b, d
            ld c, e
            ld hl, (ow_y0)
            call ow_sub
            ld (ow_b), bc
ow_sc:
            ld hl, ow_a
            ld b, 4
ow_ck:
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld a, e
            rla
            ld a, d
            adc a, 0                ; 0 when -128..127
            jr nz, ow_half
            djnz ow_ck
            jr ow_x
ow_half:
            ld hl, ow_a
            ld b, 4
ow_hl:
            inc hl
            sra (hl)
            dec hl
            rr (hl)
            inc hl
            inc hl
            djnz ow_hl
            jr ow_sc
ow_x:
            ld a, (ow_a)            ; (x1 - x0)(y2 - y0) - (y1 - y0)(x2 - x0) > 0
            ld d, a
            ld a, (ow_b)
            ld e, a
            call mul8s
            push de
            ld a, (ow_c)
            ld d, a
            ld a, (ow_d)
            ld e, a
            call mul8s
            pop hl
            or a
            sbc hl, de
            jp m, of_skip
            jp z, of_skip
            jp of_lit
ow_pt:                              ; point A -> BC = x, DE = y (16 bits)
            add a, a
            ld e, a
            ld d, 0
            ld hl, {osx}
            add hl, de
            ld c, (hl)
            inc hl
            ld b, (hl)
            ld hl, {osy}
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ret
ow_sub:                             ; BC = BC - HL
            push de
            ld d, h
            ld e, l
            ld h, b
            ld l, c
            or a
            sbc hl, de
            ld b, h
            ld c, l
            pop de
            ret
ow_x0:      dw 0
ow_y0:      dw 0
ow_a:       dw 0
ow_b:       dw 0
ow_c:       dw 0
ow_d:       dw 0
; of_e: oe = O^T (-od) >> osc (the camera in the model: by the object's turn, to about 1%)
of_e:
            ld hl, ({od})           ; Ry^T: x1 = ca x - sa z, z1 = sa x + ca z (x, z = -od)
            call oe_neg
            ld a, (od_ca)
            call mt
            ld (oe_t), hl
            ld hl, ({od} + 4)
            call oe_neg
            ld a, (od_sa)
            call mt
            ex de, hl
            ld hl, (oe_t)
            or a
            sbc hl, de
            call oe_sh
            ld ({oe}), hl
            ld hl, ({od})
            call oe_neg
            ld a, (od_sa)
            call mt
            ld (oe_t), hl
            ld hl, ({od} + 4)
            call oe_neg
            ld a, (od_ca)
            call mt
            ld de, (oe_t)
            add hl, de
            ld (oe_z1), hl
            ld hl, ({od} + 2)       ; Rx^T: y = cb y1 + sb z1, z = cb z1 - sb y1 (y1 = -od y)
            call oe_neg
            ld a, (od_cb)
            call mt
            ld (oe_t), hl
            ld de, (oe_z1)
            ld a, (od_sb)
            call mt
            ld de, (oe_t)
            add hl, de
            call oe_sh
            ld ({oe} + 2), hl
            ld de, (oe_z1)
            ld a, (od_cb)
            call mt
            ld (oe_t), hl
            ld hl, ({od} + 2)
            call oe_neg
            ld a, (od_sb)
            call mt
            ex de, hl
            ld hl, (oe_t)
            or a
            sbc hl, de
            call oe_sh
            ld ({oe} + 4), hl
            ld a, 1
            ld (oe_ok), a
            ret
oe_neg:                             ; DE = -HL
            ex de, hl
            ld hl, 0
            or a
            sbc hl, de
            ex de, hl
            ret
oe_sh:                              ; HL >> osc
            ld a, ({osc})
            or a
            ret z
            ld b, a
oe_s:
            sra h
            rr l
            djnz oe_s
            ret
oe_t:       dw 0
oe_z1:      dw 0
of_a:       db 0
of_b:       db 0
of_c:       db 0
of_d:       db 0
of_as:      db 0
of_bs:      db 0
of_cs:      db 0
of_ds:      db 0
xv_i:       db 0
xv_or:      db 0
; ndot: the face's normal (IY + 2..4, int8) . the 3 words at HL -> nd_h:nd_l (24 bits)
ndot:
            ld (nd_v), hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld a, (iy + 2)
            call m816
            ld (nd_l), hl
            ld (nd_h), a
            ld hl, (nd_v)
            inc hl
            inc hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld a, (iy + 3)
            call m816
            call nd_add
            ld hl, (nd_v)
            ld de, 4
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld a, (iy + 4)
            call m816
nd_add:
            ld c, a
            ld de, (nd_l)
            add hl, de
            ld (nd_l), hl
            ld a, (nd_h)
            adc a, c
            ld (nd_h), a
            ret
nd_v:       dw 0
nd_l:       dw 0
nd_h:       db 0
xv_k:       db 0
of_k:       db 0
of_n:       db 0
of_ix:      dw 0
xv_p:       dw 0
xv_o:       dw 0
xv_sx:      dw 0
xv_sy:      dw 0
xv_o0:      dw 0
xv_o1:      dw 0
xv_o2:      dw 0
cm8:        ds 9
suc8:       ds 3
sunw8:      ds 3
cms:        ds 126                  ; the camera >> 0..6 (rounded): C' = cms(6 - osc) O
#endasm
End Sub
