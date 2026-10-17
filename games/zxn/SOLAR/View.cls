' View - a 3D view for Layer 2: a camera that turns and moves, points projected onto the
' 256 x 192 screen, wireframe models and ellipses made into a table of lines for L2.Lines.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' World coordinates are Integers: keep everything within +-9000 on each axis (so the distance
' between two things fits 16 bits). Directions are bases of three vectors - right, up, forward
' - in 2.14 fixed point (16384 = 1.0): 9 Integers, kept square by TurnB. x is right, y up, z
' forward. The screen: x' * 128 / z' across from the middle (128, 96), up is up.
'   View.Begin
'   View.Model x, y, z, View.ModelAt(n), VarPtr(basis)     ' a ship's lines into the table
'   L2.Lines View.Count, View.Table, colour                 ' drawn
' All the sums are Z80 (#asm); every block switches to the real stack for its calls.
Option Explicit

Public Const NEAR = 16              ' nearer than this (z') is not drawn
Public px As Integer, py As Integer, pz As Integer      ' Project / Dir: the point on the screen, its depth
Public lx As Integer, ly As Integer, lz As Integer      ' Local: a vector in a basis's terms
Public nl As Integer                                    ' lines in the table
Private lb(599) As Integer                              ' the table: 150 lines of x0, y0, x1, y1
Private cam(2) As Integer                               ' the camera: where
Private cb(8) As Integer                                ' and its basis
Private sps As Integer

' Init: the camera at the origin looking along z
Public Sub Init()
  Dim k As Integer
  For k = 0 To 8
    cb(k) = 0
  Next
  cb(0) = 16384 : cb(4) = 16384 : cb(8) = 16384
  cam(0) = 0 : cam(1) = 0 : cam(2) = 0
End Sub

Public Sub SetCam(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer)
  cam(0) = x : cam(1) = y : cam(2) = z
End Sub

Public Function CamX() As Integer
  CamX = cam(0)
End Function
Public Function CamY() As Integer
  CamY = cam(1)
End Function
Public Function CamZ() As Integer
  CamZ = cam(2)
End Function
' the camera's position (3 Integers) and basis (9), for Move / TurnB / Local
Public Function CamPos() As Integer
  CamPos = VarPtr(cam)
End Function
Public Function CamBasis() As Integer
  CamBasis = VarPtr(cb)
End Function
Public Function Table() As Integer
  Table = VarPtr(lb)
End Function
Public Function Count() As Integer
  Count = nl
End Function

' Begin: the line table emptied
Public Sub Begin()
  nl = 0
End Sub

' Line x0, y0, x1, y1: a line (screen coordinates) into the table
Public Sub Line(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  Dim k As Integer
  If nl >= 150 Then Exit Sub
  k = nl * 4
  lb(k) = x0 : lb(k + 1) = y0 : lb(k + 2) = x1 : lb(k + 3) = y1
  nl = nl + 1
End Sub

' Project(x, y, z): True when the world point is in front of the camera; px, py its place on the
' screen (maybe off it), pz its depth
Public Function Project(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 2), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 4), hl
            pop hl
            ld (pr_r), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, (vm_v)           ; relative to the camera
            ld de, ({cam})
            or a
            sbc hl, de
            ld (vm_v), hl
            ld hl, (vm_v + 2)
            ld de, ({cam} + 2)
            or a
            sbc hl, de
            ld (vm_v + 2), hl
            ld hl, (vm_v + 4)
            ld de, ({cam} + 4)
            or a
            sbc hl, de
            ld (vm_v + 4), hl
            ld iy, {cb}
            call vm_dot
            ld (vc_x), hl
            ld iy, {cb} + 6
            call vm_dot
            ld (vc_y), hl
            ld iy, {cb} + 12
            call vm_dot
            ld (vc_z), hl
            ld hl, (vc_z)
            ld (pr_z), hl
            ld de, 16
            or a
            sbc hl, de
            bit 7, h
            jr nz, pr_no            ; behind (or too near): not seen
            ld hl, (vc_x)
            ld bc, (vc_z)
            call vm_proj
            ld de, 128
            add hl, de
            ld (pr_x), hl
            ld hl, (vc_y)
            ld bc, (vc_z)
            call vm_proj
            ex de, hl
            ld hl, 96
            or a
            sbc hl, de
            ld (pr_y), hl
            ld hl, (pr_x)
            ld ({px}), hl
            ld hl, (pr_y)
            ld ({py}), hl
            ld hl, (pr_z)
            ld ({pz}), hl
            ld de, -1
            jr pr_set
pr_no:
            ld hl, (pr_z)
            ld ({pz}), hl
            ld de, 0
pr_set:

            ld hl, (pr_r)
            ld (hl), e
            inc hl
            ld (hl), d
            ld sp, ({sps})
            ret
pr_r:       dw 0
pr_x:       dw 0
pr_y:       dw 0
pr_z:       dw 0
vc_x:       dw 0
vc_y:       dw 0
vc_z:       dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Function

' Dir(x, y, z): as Project, for a direction (a star: as far as you go, it stays put)
Public Function Dir(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 2), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 4), hl
            pop hl
            ld (pr_r), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld iy, {cb}
            call vm_dot
            ld (vc_x), hl
            ld iy, {cb} + 6
            call vm_dot
            ld (vc_y), hl
            ld iy, {cb} + 12
            call vm_dot
            ld (vc_z), hl
            ld hl, (vc_z)
            ld (pr_z), hl
            ld de, 16
            or a
            sbc hl, de
            bit 7, h
            jr nz, pr_no            ; behind (or too near): not seen
            ld hl, (vc_x)
            ld bc, (vc_z)
            call vm_proj
            ld de, 128
            add hl, de
            ld (pr_x), hl
            ld hl, (vc_y)
            ld bc, (vc_z)
            call vm_proj
            ex de, hl
            ld hl, 96
            or a
            sbc hl, de
            ld (pr_y), hl
            ld hl, (pr_x)
            ld ({px}), hl
            ld hl, (pr_y)
            ld ({py}), hl
            ld hl, (pr_z)
            ld ({pz}), hl
            ld de, -1
            jr pr_set
pr_no:
            ld hl, (pr_z)
            ld ({pz}), hl
            ld de, 0
pr_set:

            ld hl, (pr_r)
            ld (hl), e
            inc hl
            ld (hl), d
            ld sp, ({sps})
            ret
pr_r:       dw 0
pr_x:       dw 0
pr_y:       dw 0
pr_z:       dw 0
vc_x:       dw 0
vc_y:       dw 0
vc_z:       dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Function

' Local basis, dx, dy, dz: the vector in the basis's terms -> lx (right), ly (up), lz (forward)
Public Sub Local(ByVal basis As Integer, ByVal dx As Integer, ByVal dy As Integer, ByVal dz As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (lc_b), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 2), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 4), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld iy, (lc_b)
            call vm_dot
            ld ({lx}), hl
            ld iy, (lc_b)
            ld de, 6
            add iy, de
            call vm_dot
            ld ({ly}), hl
            ld iy, (lc_b)
            ld de, 12
            add iy, de
            call vm_dot
            ld ({lz}), hl
            ld sp, ({sps})
            ret
lc_b:       dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Sub

' Move pos, basis, speed: the position (3 Integers at pos) moved along the basis's forward
Public Sub Move(ByVal pos As Integer, ByVal basis As Integer, ByVal speed As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (mv_p), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (mv_b), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (mv_s), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld iy, (mv_b)
            ld ix, (mv_p)
            ld b, 3
mv_lp:
            push bc
            ld e, (iy + 12)
            ld d, (iy + 13)
            ld bc, (mv_s)
            push ix
            call vm_fix
            pop ix
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
            djnz mv_lp
            ld sp, ({sps})
            ret
mv_p:       dw 0
mv_b:       dw 0
mv_s:       dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Sub

' TurnB basis, pitch, yaw, roll: the basis turned (each -2 .. 2: steps of 2 degrees; pitch 1
' nose up, yaw 1 to the right, roll 1 right wing down), then made square and of length 1 again
Public Sub TurnB(ByVal basis As Integer, ByVal pitch As Integer, ByVal yaw As Integer, ByVal roll As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (tb_b), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (tb_p), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (tb_y), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (tb_r), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ; pitch: forward towards up (A = F, B = U)
            ld a, (tb_p)
            ld hl, 12
            ld de, 6
            call tb_turn
            ; yaw: forward towards right (A = F, B = R)
            ld a, (tb_y)
            ld hl, 12
            ld de, 0
            call tb_turn
            ; roll: up towards right (A = U, B = R)
            ld a, (tb_r)
            ld hl, 6
            ld de, 0
            call tb_turn
            call tb_tidy
            ld sp, ({sps})
            ret
; turn the pair of vectors at basis + HL (A) and basis + DE (B) by A steps (signed, -2..2)
tb_turn:
            or a
            ret z
            ld (tb_k), a
            ld bc, (tb_b)
            add hl, bc
            ld (tb_pa), hl
            ex de, hl
            add hl, bc
            ld (tb_pb), hl
tb_again:
            ld a, (tb_k)
            or a
            ret z
            ld hl, 572              ; sin 2 degrees
            bit 7, a
            jr z, tb_pos
            inc a
            ld hl, -572
            jr tb_go
tb_pos:
            dec a
tb_go:
            ld (tb_k), a
            ld (tb_s), hl
            ld ix, (tb_pa)
            ld iy, (tb_pb)
            ld b, 3
tb_lp:
            push bc
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld (tb_a), de
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld (tb_bb), de
            ld de, (tb_a)
            ld bc, 16374            ; cos 2 degrees
            push ix
            call vm_fix
            ld (tb_t), hl
            ld de, (tb_bb)
            ld bc, (tb_s)
            call vm_fix
            pop ix
            ld de, (tb_t)
            add hl, de
            ld (ix + 0), l          ; A = A cos + B sin
            ld (ix + 1), h
            ld de, (tb_bb)
            ld bc, 16374
            push ix
            call vm_fix
            ld (tb_t), hl
            ld de, (tb_a)
            ld bc, (tb_s)
            call vm_fix
            pop ix
            ex de, hl
            ld hl, (tb_t)
            or a
            sbc hl, de
            ld (iy + 0), l          ; B = B cos - A sin
            ld (iy + 1), h
            inc ix
            inc ix
            inc iy
            inc iy
            pop bc
            djnz tb_lp
            jp tb_again
; forward of length 1; right square to it and of length 1; up = forward x right
tb_tidy:
            ld hl, (tb_b)
            ld de, 12
            add hl, de
            call tb_unit
            ; right -= (right . forward) forward
            ld hl, (tb_b)
            ld de, vm_v
            ld bc, 6
            ldir                    ; vm_v = right
            ld iy, (tb_b)
            ld de, 12
            add iy, de
            call vm_dot             ; right . forward
            ld (tb_t), hl
            ld ix, (tb_b)
            ld iy, (tb_b)
            ld de, 12
            add iy, de
            ld b, 3
td_lp:
            push bc
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (tb_t)
            push ix
            call vm_fix
            pop ix
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
            ld hl, (tb_b)
            call tb_unit
            ; up = forward x right: (Fy Rz - Fz Ry, Fz Rx - Fx Rz, Fx Ry - Fy Rx)
            ld ix, (tb_b)
            ld e, (ix + 14)         ; Fy
            ld d, (ix + 15)
            ld c, (ix + 4)          ; Rz
            ld b, (ix + 5)
            call tb_cross
            ld (ix + 6), l
            ld (ix + 7), h
            ld e, (ix + 16)         ; Fz Rx - Fx Rz
            ld d, (ix + 17)
            ld c, (ix + 0)
            ld b, (ix + 1)
            ld (tb_t2), ix
            call vm_fix
            ld ix, (tb_t2)
            ld (tb_t), hl
            ld e, (ix + 12)
            ld d, (ix + 13)
            ld c, (ix + 4)
            ld b, (ix + 5)
            call vm_fix
            ld ix, (tb_t2)
            ex de, hl
            ld hl, (tb_t)
            or a
            sbc hl, de
            ld (ix + 8), l
            ld (ix + 9), h
            ld e, (ix + 12)         ; Fx Ry - Fy Rx
            ld d, (ix + 13)
            ld c, (ix + 2)
            ld b, (ix + 3)
            call vm_fix
            ld ix, (tb_t2)
            ld (tb_t), hl
            ld e, (ix + 14)
            ld d, (ix + 15)
            ld c, (ix + 0)
            ld b, (ix + 1)
            call vm_fix
            ld ix, (tb_t2)
            ex de, hl
            ld hl, (tb_t)
            or a
            sbc hl, de
            ld (ix + 10), l
            ld (ix + 11), h
            ret
; up x: Fy Rz - Fz Ry (DE = Fy, BC = Rz on entry), IX = the basis (kept)
tb_cross:
            ld (tb_t2), ix
            call vm_fix
            ld ix, (tb_t2)
            ld (tb_t), hl
            ld e, (ix + 16)         ; Fz
            ld d, (ix + 17)
            ld c, (ix + 2)          ; Ry
            ld b, (ix + 3)
            call vm_fix
            ld ix, (tb_t2)
            ex de, hl
            ld hl, (tb_t)
            or a
            sbc hl, de
            ret
; the vector at HL scaled to length 1: times (3 - |v|^2) / 2
tb_unit:
            ld (tb_pa), hl
            ld de, vm_v
            ld bc, 6
            ldir
            ld iy, (tb_pa)
            call vm_dot             ; |v|^2 (2.14)
            sra h
            rr l
            ex de, hl
            ld hl, 24576            ; 1.5
            or a
            sbc hl, de
            ld (tb_t), hl           ; the factor
            ld ix, (tb_pa)
            ld b, 3
tu_lp:
            push bc
            ld e, (ix + 0)
            ld d, (ix + 1)
            ld bc, (tb_t)
            push ix
            call vm_fix
            pop ix
            ld (ix + 0), l
            ld (ix + 1), h
            inc ix
            inc ix
            pop bc
            djnz tu_lp
            ret
tb_b:       dw 0
tb_p:       dw 0
tb_y:       dw 0
tb_r:       dw 0
tb_k:       db 0
tb_s:       dw 0
tb_pa:      dw 0
tb_pb:      dw 0
tb_a:       dw 0
tb_bb:      dw 0
tb_t:       dw 0
tb_t2:      dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Sub

' Model x, y, z, model, basis: a wireframe model at x, y, z turned by the basis, into the line
' table (cut where it passes the camera). A model: the number of points, each point 3 signed
' bytes (x, y, z in 4s of world units), the number of lines, each 2 point numbers.
Public Sub Model(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal model As Integer, ByVal basis As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 2), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (vm_v + 4), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (md_m), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (md_b), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, (vm_v)
            ld de, ({cam})
            or a
            sbc hl, de
            ld (vm_v), hl
            ld hl, (vm_v + 2)
            ld de, ({cam} + 2)
            or a
            sbc hl, de
            ld (vm_v + 2), hl
            ld hl, (vm_v + 4)
            ld de, ({cam} + 4)
            or a
            sbc hl, de
            ld (vm_v + 4), hl
            ld iy, {cb}
            call vm_dot
            ld (vc_x), hl
            ld iy, {cb} + 6
            call vm_dot
            ld (vc_y), hl
            ld iy, {cb} + 12
            call vm_dot
            ld (vc_z), hl
            ; well behind, or far off: nothing
            ld hl, (vc_z)
            ld de, 200
            add hl, de
            bit 7, h
            jp nz, md_done
            ld hl, (vc_z)
            ld de, -10000
            add hl, de
            jp c, md_done
            ; the matrix: m(i, j) = camera row i . model row j
            ld hl, md_m9
            ld (md_mp), hl
            ld a, 0
md_row:
            ld (md_i), a
            ld b, 0
md_col:
            push bc
            ld l, b                 ; vm_v = model row j (j = b)
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de              ; j * 6
            ld de, (md_b)
            add hl, de
            ld de, vm_v
            ld bc, 6
            ldir
            ld a, (md_i)
            ld l, a
            ld h, 0
            add hl, hl
            ld e, l
            ld d, h
            add hl, hl
            add hl, de              ; i * 6
            ld de, {cb}
            add hl, de
            push hl
            pop iy
            call vm_dot
            ex de, hl
            ld hl, (md_mp)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (md_mp), hl
            pop bc
            inc b
            ld a, b
            cp 3
            jr nz, md_col
            ld a, (md_i)
            inc a
            cp 3
            jr nz, md_row
            ; the points
            ld hl, (md_m)
            ld a, (hl)
            ld (md_nv), a
            inc hl
            ld (md_src), hl
            ld hl, md_pts
            ld (md_dst), hl
md_pt:
            ; camera x = (a m00 + b m01 + c m02) >> 12 + vc_x ...
            ld hl, md_m9
            ld (md_mp), hl
            ld de, vc_x
            ld (md_tp), de
            ld b, 3
md_axis:
            push bc
            ld hl, 0
            ld (vm_acc), hl
            ld hl, (md_src)
            ld (md_s2), hl
            ld b, 3
md_term:
            push bc
            ld hl, (md_s2)
            ld a, (hl)
            inc hl
            ld (md_s2), hl
            ld c, a
            rla
            sbc a, a
            ld b, a                 ; BC = the byte, signed
            ld hl, (md_mp)
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld (md_mp), hl
            ld hl, (vm_acc)
            push hl
            call vm_f12
            pop de
            add hl, de
            ld (vm_acc), hl
            pop bc
            djnz md_term
            ld hl, (md_tp)          ; + the model's place in camera space
            ld e, (hl)
            inc hl
            ld d, (hl)
            inc hl
            ld (md_tp), hl
            ld hl, (vm_acc)
            add hl, de
            ex de, hl
            ld hl, (md_dst)
            ld (hl), e
            inc hl
            ld (hl), d
            inc hl
            ld (md_dst), hl
            pop bc
            djnz md_axis
            ; projected (x, y) after (cx, cy, cz) when cz >= NEAR
            ld hl, (md_dst)
            dec hl
            ld d, (hl)
            dec hl
            ld e, (hl)              ; cz
            ld hl, 15
            or a
            sbc hl, de
            jp p, md_behind         ; 15 - cz >= 0: behind
            ld (md_cz), de
            ld hl, (md_dst)
            ld de, -6
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            ld bc, (md_cz)
            call vm_proj
            ld de, 128
            add hl, de
            ex de, hl
            ld hl, (md_dst)
            ld (hl), e
            inc hl
            ld (hl), d
            ld hl, (md_dst)
            ld de, -4
            add hl, de
            ld e, (hl)
            inc hl
            ld d, (hl)
            ex de, hl
            ld bc, (md_cz)
            call vm_proj
            ex de, hl
            ld hl, 96
            or a
            sbc hl, de
            ex de, hl
            ld hl, (md_dst)
            inc hl
            inc hl
            ld (hl), e
            inc hl
            ld (hl), d
md_behind:
            ld hl, (md_dst)
            ld de, 4
            add hl, de
            ld (md_dst), hl         ; 5 words a point: cx cy cz sx sy
            ld hl, (md_src)
            inc hl
            inc hl
            inc hl
            ld (md_src), hl
            ld a, (md_nv)
            dec a
            ld (md_nv), a
            jp nz, md_pt
            ; the lines
            ld a, (hl)
            ld (md_ne), a
            inc hl
            ld (md_src), hl
md_ln:
            ld a, (md_ne)
            or a
            jp z, md_done
            dec a
            ld (md_ne), a
            ld hl, (md_src)
            ld a, (hl)
            inc hl
            ld c, (hl)
            inc hl
            ld (md_src), hl
            call md_ptr
            ld (md_pa), hl
            ld a, c
            call md_ptr
            ld (md_pb), hl
            ; both in front?
            ld ix, (md_pa)
            ld iy, (md_pb)
            ld l, (ix + 4)
            ld h, (ix + 5)
            ld de, 16
            or a
            sbc hl, de
            ld a, h
            and #80
            ld b, a                 ; B bit 7: a behind
            ld l, (iy + 4)
            ld h, (iy + 5)
            or a
            sbc hl, de
            ld a, h
            and #80
            ld c, a                 ; C bit 7: b behind
            and b
            jp nz, md_ln            ; both behind
            ld a, b
            or c
            jr nz, md_cut
            ld l, (ix + 6)
            ld h, (ix + 7)
            ld (md_l0), hl
            ld l, (ix + 8)
            ld h, (ix + 9)
            ld (md_l0 + 2), hl
            ld l, (iy + 6)
            ld h, (iy + 7)
            ld (md_l0 + 4), hl
            ld l, (iy + 8)
            ld h, (iy + 9)
            ld (md_l0 + 6), hl
            call md_out
            jp md_ln
md_cut:
            ; one is behind: IX the one in front, IY the one behind
            ld a, b
            or a
            jr z, md_c1
            ld (md_pa), iy
            ld (md_pb), ix
            ld ix, (md_pa)
            ld iy, (md_pb)
md_c1:
            ld l, (ix + 6)
            ld h, (ix + 7)
            ld (md_l0), hl
            ld l, (ix + 8)
            ld h, (ix + 9)
            ld (md_l0 + 2), hl
            ; t = (NEAR - za) / (zb - za) on the one behind (a: behind, b: in front)
            ; x = xa + (xb - xa) * (NEAR - za) / (zb - za)
            ld l, (iy + 4)
            ld h, (iy + 5)
            ld (md_za), hl
            ld l, (ix + 4)
            ld h, (ix + 5)
            ld de, (md_za)
            or a
            sbc hl, de
            ld (md_dz), hl          ; zb - za (> 0)
            ld hl, 16
            or a
            sbc hl, de
            ld (md_nz), hl          ; NEAR - za
            ld l, (iy + 0)
            ld h, (iy + 1)
            ld (md_xa), hl
            ld e, (ix + 0)
            ld d, (ix + 1)
            ex de, hl
            or a
            sbc hl, de              ; xb - xa
            ex de, hl
            ld bc, (md_nz)
            push ix
            push iy
            call vm_muls
            ld bc, (md_dz)
            call vm_divs
            ld de, (md_xa)
            add hl, de              ; x at NEAR
            ld bc, 16
            call vm_proj            ; * 128 / NEAR
            ld de, 128
            add hl, de
            ld (md_l0 + 4), hl
            pop iy
            pop ix
            ld l, (iy + 2)
            ld h, (iy + 3)
            ld (md_xa), hl
            ld e, (ix + 2)
            ld d, (ix + 3)
            ex de, hl
            or a
            sbc hl, de
            ex de, hl
            ld bc, (md_nz)
            call vm_muls
            ld bc, (md_dz)
            call vm_divs
            ld de, (md_xa)
            add hl, de
            ld bc, 16
            call vm_proj
            ex de, hl
            ld hl, 96
            or a
            sbc hl, de
            ld (md_l0 + 6), hl
            call md_out
            jp md_ln
md_done:
            ld sp, ({sps})
            ret
; HL = the point A's record (5 words)
md_ptr:
            ld l, a
            ld h, 0
            ld e, l
            ld d, h
            add hl, hl
            add hl, hl
            add hl, de
            add hl, hl              ; * 10
            ld de, md_pts
            add hl, de
            ret
; the line md_l0 (4 words) into the table
md_out:
            ld hl, ({nl})
            ld de, 150
            or a
            sbc hl, de
            ret nc
            add hl, de
            ld e, l
            ld d, h
            inc hl
            ld ({nl}), hl
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, hl              ; * 8
            ld de, {lb}
            add hl, de
            ex de, hl
            ld hl, md_l0
            ld bc, 8
            ldir
            ret
md_m:       dw 0
md_b:       dw 0
md_i:       db 0
md_m9:      dw 0, 0, 0, 0, 0, 0, 0, 0, 0
md_mp:      dw 0
md_tp:      dw 0
md_nv:      db 0
md_ne:      db 0
md_src:     dw 0
md_s2:      dw 0
md_dst:     dw 0
md_cz:      dw 0
md_pa:      dw 0
md_pb:      dw 0
md_za:      dw 0
md_dz:      dw 0
md_nz:      dw 0
md_xa:      dw 0
md_l0:      dw 0, 0, 0, 0
md_pts:     ds 32 * 10
vc_x:       dw 0
vc_y:       dw 0
vc_z:       dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Sub


' FMul(a, b): a * b / 16384, rounded down (for 2.14 numbers: a sine times a length)
Public Function FMul(ByVal a As Integer, ByVal b As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (fm_a), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (fm_b), hl
            pop hl
            ld (fm_r), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld de, (fm_a)
            ld bc, (fm_b)
            call vm_fix
            ex de, hl
            ld hl, (fm_r)
            ld (hl), e
            inc hl
            ld (hl), d
            ld sp, ({sps})
            ret
fm_a:       dw 0
fm_b:       dw 0
fm_r:       dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Function

' MulDiv(a, b, c): a * b / c with a 32 bit product (c not 0; the answer kept within +-32767)
Public Function MulDiv(ByVal a As Integer, ByVal b As Integer, ByVal c As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (fm_a), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (fm_b), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (fm_c), hl
            pop hl
            ld (fm_r), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld de, (fm_a)
            ld bc, (fm_b)
            call vm_muls
            ld bc, (fm_c)
            call vm_divs
            ex de, hl
            ld hl, (fm_r)
            ld (hl), e
            inc hl
            ld (hl), d
            ld sp, ({sps})
            ret
fm_a:       dw 0
fm_b:       dw 0
fm_c:       dw 0
fm_r:       dw 0
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Function

' Ellipse cx, cy, rx, ry: 16 lines round an ellipse on the screen into the table
Public Sub Ellipse(ByVal cx As Integer, ByVal cy As Integer, ByVal rx As Integer, ByVal ry As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (el_cx), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (el_cy), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (el_rx), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (el_ry), hl
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, el_sin
            ld (el_p), hl
            ; small ones: 8 sides (every other entry of the table), else 16
            ld hl, (el_rx)
            ld de, (el_ry)
            ld a, h
            or d
            jr nz, el_big
            ld a, l
            cp 24
            jr nc, el_big
            ld a, e
            cp 24
            jr nc, el_big
            ld a, 4
            ld (el_st), a
            ld b, 9
            jr el_lp
el_big:
            ld a, 2
            ld (el_st), a
            ld b, 17
el_lp:
            push bc
            ld hl, (el_p)
            ld e, (hl)              ; cos = sin + 4 steps
            inc hl
            ld d, (hl)
            ld bc, 7
            add hl, bc
            ld c, (hl)
            inc hl
            ld b, (hl)
            push bc
            ld bc, (el_rx)
            call vm_fix
            ld de, (el_cx)
            add hl, de
            ld (el_nx), hl          ; x = cx + rx sin
            pop de
            ld bc, (el_ry)
            call vm_fix
            ld de, (el_cy)
            add hl, de
            ld (el_ny), hl          ; y = cy + ry cos
            pop bc
            push bc
            ld a, (el_st)
            cp 4
            ld a, b
            jr nz, el_b16
            cp 9
            jr z, el_first
            jr el_line
el_b16:
            cp 17
            jr z, el_first
el_line:
            ld hl, (el_ox)
            ld (el_l0), hl
            ld hl, (el_oy)
            ld (el_l0 + 2), hl
            ld hl, (el_nx)
            ld (el_l0 + 4), hl
            ld hl, (el_ny)
            ld (el_l0 + 6), hl
            call el_out
el_first:
            ld hl, (el_nx)
            ld (el_ox), hl
            ld hl, (el_ny)
            ld (el_oy), hl
            ld hl, (el_p)
            ld a, (el_st)
            ld e, a
            ld d, 0
            add hl, de
            ld (el_p), hl
            pop bc
            djnz el_lp
            ld sp, ({sps})
            ret
el_out:
            ld hl, ({nl})
            ld de, 150
            or a
            sbc hl, de
            ret nc
            add hl, de
            ld e, l
            ld d, h
            inc hl
            ld ({nl}), hl
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, {lb}
            add hl, de
            ex de, hl
            ld hl, el_l0
            ld bc, 8
            ldir
            ret
el_cx:      dw 0
el_cy:      dw 0
el_rx:      dw 0
el_ry:      dw 0
el_nx:      dw 0
el_ny:      dw 0
el_ox:      dw 0
el_oy:      dw 0
el_p:       dw 0
el_st:      db 2
el_l0:      dw 0, 0, 0, 0
el_sin:     dw 0, 6270, 11585, 15137, 16384, 15137, 11585, 6270, 0, -6270, -11585, -15137, -16384, -15137, -11585, -6270
            dw 0, 6270, 11585, 15137, 16384, 15137
; DEHL = DE * BC, signed
vm_muls:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vm_m1:
            bit 7, b
            jr z, vm_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_m2:
            call vm_umul            ; DEHL = DE * BC, unsigned
            ld a, (vm_sg)
            bit 7, a
            ret z
            ; negate DEHL
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
; HL = DEHL / BC, signed (the quotient's low 16 bits; |divisor| > 0)
vm_divs:
            ld a, d
            xor b
            ld (vm_sg), a
            bit 7, d
            jr z, vm_d1
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
vm_d1:
            bit 7, b
            jr z, vm_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vm_d2:
            ld a, b
            or c
            jr nz, vm_d3
            ld hl, 0
            ret
vm_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vm_d4
            ld hl, 32767
            jr vm_d7
vm_d4:
            add hl, bc
            ld a, 16
vm_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vm_d5b
            or a
            sbc hl, bc
            jr nc, vm_d6
            add hl, bc
            jr vm_d6n
vm_d5b:
            or a
            sbc hl, bc
vm_d6:
            inc e
vm_d6n:
            dec a
            jr nz, vm_d5
            ex de, hl               ; HL = quotient
vm_d7:
            ld a, (vm_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret

; DEHL = DE * BC, unsigned: four 8 x 8 products on the Next's multiplier
vm_umul:
            ld (vm_ua), de
            ld (vm_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vm_zm1:
            db #ED, #30             ; mul d, e
            ld (vm_lo), de
            ld a, (vm_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vm_ub + 1)
            ld e, a
vm_zm2:
            db #ED, #30
            ld (vm_hi), de
            ld a, (vm_ua)           ; a low x b high
            ld d, a
            ld e, b
vm_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vm_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vm_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vm_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vm_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vm_ua:      dw 0
vm_ub:      dw 0
vm_lo:      dw 0
vm_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vm_fix:
            call vm_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vm_f12:
            call vm_muls
            ld a, 4
vm_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_f12a
            ex de, hl
            ret
; HL = vm_v . (IY), 3 words each, >> 14
vm_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vm_v)
            call vm_fix
            ld (vm_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vm_v + 2)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ld (vm_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vm_v + 4)
            call vm_fix
            ld de, (vm_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vm_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vm_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vm_pr1
            call vm_divs
vm_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vm_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vm_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vm_v:       dw 0, 0, 0
vm_acc:     dw 0
vm_sg:      db 0
vm_n:       db 0

#endasm
End Sub
