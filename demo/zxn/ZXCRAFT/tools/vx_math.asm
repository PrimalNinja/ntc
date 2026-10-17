; vx_math.asm - signed 16 x 16 multiply and 32 / 16 divide (the multiply on the Next's MUL D,E),
; 2.14 fixed point: from SOLAR / SOL UNICORN's View.cls, for gen_vox.py
; DEHL = DE * BC, signed
vx_muls:
            ld a, d
            xor b
            ld (vx_sg), a
            bit 7, d
            jr z, vx_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
vx_m1:
            bit 7, b
            jr z, vx_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vx_m2:
            call vx_umul            ; DEHL = DE * BC, unsigned
            ld a, (vx_sg)
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
vx_divs:
            ld a, d
            xor b
            ld (vx_sg), a
            bit 7, d
            jr z, vx_d1
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
vx_d1:
            bit 7, b
            jr z, vx_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
vx_d2:
            ld a, b
            or c
            jr nz, vx_d3
            ld hl, 0
            ret
vx_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, vx_d4
            ld hl, 32767
            jr vx_d7
vx_d4:
            add hl, bc
            ld a, 16
vx_d5:
            sla e
            rl d
            adc hl, hl
            jr c, vx_d5b
            or a
            sbc hl, bc
            jr nc, vx_d6
            add hl, bc
            jr vx_d6n
vx_d5b:
            or a
            sbc hl, bc
vx_d6:
            inc e
vx_d6n:
            dec a
            jr nz, vx_d5
            ex de, hl               ; HL = quotient
vx_d7:
            ld a, (vx_sg)
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
vx_umul:
            ld (vx_ua), de
            ld (vx_ub), bc
            ld d, e                 ; a low x b low
            ld e, c
vx_zm1:
            db #ED, #30             ; mul d, e
            ld (vx_lo), de
            ld a, (vx_ua + 1)       ; a high x b high
            ld d, a
            ld a, (vx_ub + 1)
            ld e, a
vx_zm2:
            db #ED, #30
            ld (vx_hi), de
            ld a, (vx_ua)           ; a low x b high
            ld d, a
            ld e, b
vx_zm3:
            db #ED, #30
            ex de, hl
            ld a, (vx_ua + 1)       ; a high x b low
            ld d, a
            ld e, c
vx_zm4:
            db #ED, #30
            add hl, de              ; the middle: 17 bits (A = its top bit)
            ld a, 0
            adc a, a
            ld b, a
            ld de, (vx_lo)
            ld a, d
            add a, l
            ld d, a
            ld a, h
            ld hl, (vx_hi)
            adc a, l
            ld l, a
            ld a, b
            adc a, h
            ld h, a
            ex de, hl               ; DE = the high word, HL = the low
            ret
vx_ua:      dw 0
vx_ub:      dw 0
vx_lo:      dw 0
vx_hi:      dw 0

; HL = DE * BC >> 14 (2.14 fixed point, signed)
vx_fix:
            call vx_muls
            add hl, hl
            rl e
            rl d
            add hl, hl
            rl e
            rl d
            ex de, hl
            ret
; HL = DE * BC >> 12 (a model's byte coordinates are 4 world units)
vx_f12:
            call vx_muls
            ld a, 4
vx_f12a:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vx_f12a
            ex de, hl
            ret
; HL = vx_v . (IY), 3 words each, >> 14
vx_dot:
            ld e, (iy + 0)
            ld d, (iy + 1)
            ld bc, (vx_v)
            call vx_fix
            ld (vx_acc), hl
            ld e, (iy + 2)
            ld d, (iy + 3)
            ld bc, (vx_v + 2)
            call vx_fix
            ld de, (vx_acc)
            add hl, de
            ld (vx_acc), hl
            ld e, (iy + 4)
            ld d, (iy + 5)
            ld bc, (vx_v + 4)
            call vx_fix
            ld de, (vx_acc)
            add hl, de
            ret
; HL = HL * 128 / BC (BC > 0), kept within +-12000
vx_proj:
            ld a, h                 ; DEHL = HL sign extended, times 128
            rla
            sbc a, a
            ld e, a
            ld d, a
            ld a, 7
vx_pr1:
            add hl, hl
            rl e
            rl d
            dec a
            jr nz, vx_pr1
            call vx_divs
vx_clamp:
            ld de, 12000
            bit 7, h
            jr nz, vx_cneg
            push hl
            or a
            sbc hl, de
            pop hl
            ret c
            ex de, hl
            ret
vx_cneg:
            push hl
            add hl, de
            pop hl
            ret c
            ld hl, -12000
            ret
vx_v:       dw 0, 0, 0
vx_acc:     dw 0
vx_sg:      db 0
vx_n:       db 0
