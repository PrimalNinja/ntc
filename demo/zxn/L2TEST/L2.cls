' L2 - Layer 2 on the ZX Spectrum Next: 256 x 192, 256 colours, two buffers (draw on one while
' the other is shown), clipped lines and points, straight on the hardware.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The buffers are 16K banks 16-18 and 19-21 (8K pages 32-37, 38-43). Drawing maps the page it
' needs into MMU slot 6 (#C000-#DFFF) and puts bank 5's first half back after (the tilemap's
' tiles live there). Colours are the Layer 2 palette's: as the Next starts, the colour number is
' its colour (RRRGGGBB); #E3 is transparent (what is under Layer 2 shows through).
' Every line drawn is kept in a list for its buffer, so Clear takes them off again by drawing
' them in the background colour - far quicker than wiping 48K when a frame has a few hundred
' lines. A frame:
'     L2.Clear                 ' the lines drawn on this buffer last time, gone
'     L2.Line ...              ' draw (up to 1024 lines and points a frame)
'     Frame : L2.Flip          ' show it at the frame's end, draw on the other next
' Coordinates are signed: a line partly or wholly off the screen is cut to it.
Option Explicit

Private lg(8191) As Byte          ' two lists of up to 1024 lines: x0, y0, x1, y1
Private cnt0 As Integer, cnt1 As Integer
Private cur As Integer            ' the buffer drawn on: 0 = bank 16, 1 = bank 19
Private bankA As Integer, bankB As Integer
Private bg As Integer
Private sps As Integer

' Init backColour: Layer 2 on (256 x 192), both buffers wiped to that colour, the first shown
Public Sub Init(ByVal backColour As Integer)
  bankA = 16 : bankB = 19 : bg = backColour And 255
  cnt0 = 0 : cnt1 = 0
  Nx.Reg &H70, 0                         ' 256 x 192
  Nx.Reg &H1C, 1                         ' its clip window: all of it
  Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0        ' no scroll
  cur = 1
  Wipe
  cur = 0
  Wipe
  Nx.Reg &H12, bankB                     ' bank 19 shown, 16 drawn on
  Out &H123B, 2                          ' Layer 2 visible
End Sub

' Off: Layer 2 hidden
Public Sub Off()
  Out &H123B, 0
End Sub

' Wipe: the whole buffer drawn on, the background colour (and its list emptied)
Public Sub Wipe()
#asm
            ld ({sps}), sp          ; the real stack (call / ret inside)
            ld sp, (ntc_csp)
            ld a, ({cur})
            or a
            ld a, ({bankA})
            jr z, bs_a
            ld a, ({bankB})
bs_a:
            add a, a
            ld (dl_base), a
            ld b, 6
wp_lp:
            push bc
            ld (dl_page), a
            call dl_map
            ld hl, #C000
            ld de, #C001
            ld bc, #1FFF
            ld a, ({bg})
            ld (hl), a
            ldir
            ld a, (dl_page)
            inc a
            pop bc
            djnz wp_lp
            ld hl, 0
            ld a, ({cur})
            or a
            jr nz, wp_b
            ld ({cnt0}), hl
            jr wp_c
wp_b:
            ld ({cnt1}), hl
wp_c:
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ld sp, ({sps})
            ret
dl_map:
            push bc
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, (dl_page)
            out (c), a
            pop bc
            ret
dl_page:    db 0
dl_base:    db 0
#endasm
End Sub

' Flip: show the buffer just drawn (call it straight after Frame), draw on the other
Public Sub Flip()
#asm
            ld a, ({cur})
            or a
            ld a, ({bankA})
            jr z, fl_a
            ld a, ({bankB})
fl_a:
            ld bc, #243B
            ld e, a
            ld a, #12
            out (c), a
            inc b
            out (c), e
            ld a, ({cur})
            xor 1
            ld ({cur}), a
#endasm
End Sub

' Clear: the lines drawn on this buffer last time it was drawn on, taken off (drawn again in
' the background colour)
Public Sub Clear()
#asm
            ld ({sps}), sp          ; the real stack (call / ret inside)
            ld sp, (ntc_csp)
            ld a, ({cur})
            or a
            ld a, ({bankA})
            jr z, bs_a
            ld a, ({bankB})
bs_a:
            add a, a
            ld (dl_base), a
            ld a, ({bg})
            ld (dl_c), a
            ld a, ({cur})
            or a
            ld hl, ({cnt0})
            ld de, {lg}
            jr z, cr_a
            ld hl, ({cnt1})
            ld de, {lg} + 4096
cr_a:
            ld (cr_n), hl
            ex de, hl
cr_lp:
            ld de, (cr_n)
            ld a, d
            or e
            jr z, cr_done
            dec de
            ld (cr_n), de
            ld de, dl_x0
            ldi
            ldi
            ldi
            ldi
            push hl
            call dl_line
            pop hl
            jr cr_lp
cr_done:
            ld hl, 0
            ld a, ({cur})
            or a
            jr nz, cr_b
            ld ({cnt0}), hl
            jr cr_c
cr_b:
            ld ({cnt1}), hl
cr_c:
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ld sp, ({sps})
            ret
cr_n:       dw 0

; ---- draw: dl_x0, dl_y0 -> dl_x1, dl_y1 (on the screen) in colour dl_c, Layer 2 pages from dl_base
dl_line:
            ld a, (dl_x1)
            ld hl, dl_x0
            sub (hl)
            ld c, #2C               ; inc l
            jr nc, dl_px
            neg
            ld c, #2D               ; dec l
dl_px:
            ld (dl_dx), a
            ld a, c
            ld (dl_xm1), a
            ld (dl_xm2), a
            ld a, (dl_y1)
            ld hl, dl_y0
            sub (hl)
            ld c, #24               ; inc h
            jr nc, dl_py
            neg
            ld c, #25               ; dec h
dl_py:
            ld (dl_dy), a
            ld a, c
            ld (dl_ym1), a
            ld (dl_ym2), a
            ld a, (dl_y0)
            ld e, a
            and 31
            or #C0
            ld h, a
            ld a, (dl_x0)
            ld l, a
            ld a, e
            rlca
            rlca
            rlca
            and 7
            ld e, a
            ld a, (dl_base)
            add a, e
            ld (dl_page), a
            call dl_map
            ld a, (dl_c)
            ld c, a
            ld a, (dl_dx)
            ld d, a
            ld a, (dl_dy)
            ld e, a
            cp d
            jr nc, dl_ymaj
            ld b, d                 ; x major: dx + 1 pixels
            inc b
            ld a, d
            srl a
dl_xl:
            ld (hl), c
dl_xm1:
            inc l
            sub e
            jr nc, dl_xn
            add a, d
dl_ym1:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
dl_xn:
            djnz dl_xl
            ret
dl_ymaj:
            ld b, e                 ; y major: dy + 1 pixels
            inc b
            ld a, e
            srl a
dl_yl:
            ld (hl), c
dl_ym2:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
            sub d
            jr nc, dl_yn
            add a, e
dl_xm2:
            inc l
dl_yn:
            djnz dl_yl
            ret
; H went off the 8K page: the next one (down) or the one before (up)
dl_wrap:
            ld a, h
            cp #E0
            jr nz, dl_wup
            ld h, #C0
            ld a, (dl_page)
            inc a
            jr dl_wset
dl_wup:
            ld h, #DF
            ld a, (dl_page)
            dec a
dl_wset:
            ld (dl_page), a
dl_map:
            push bc
            ld bc, #243B
            ld a, #56               ; MMU slot 6 (#C000-#DFFF)
            out (c), a
            inc b
            ld a, (dl_page)
            out (c), a
            pop bc
            ret
dl_x0:      db 0
dl_y0:      db 0
dl_x1:      db 0
dl_y1:      db 0
dl_c:       db 0
dl_dx:      db 0
dl_dy:      db 0
dl_page:    db 0
dl_base:    db 0

#endasm
End Sub

' Line x0, y0, x1, y1, colour: a line on the buffer drawn on, cut to the screen
Public Sub Line(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer, ByVal colour As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (cl_x0), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (cl_y0), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (cl_x1), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (cl_y1), hl
            pop hl
            ld a, (hl)
            ld (dl_c), a
            ld ({sps}), sp          ; the real stack (call / ret inside)
            ld sp, (ntc_csp)
            call cl_clip
            jr c, ln_none
            ld a, ({cur})
            or a
            ld a, ({bankA})
            jr z, bs_a
            ld a, ({bankB})
bs_a:
            add a, a
            ld (dl_base), a
            call dl_line
            call lg_add
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
ln_none:
            ld sp, ({sps})
            ret

; ---- clip: cl_x0, cl_y0, cl_x1, cl_y1 (signed) to the screen; NC = draw dl_x0 .. dl_y1
cl_clip:
            ld b, 8                 ; at most 8 cuts
cl_again:
            push bc
            ld hl, (cl_x0)
            ld de, (cl_y0)
            call cl_code
            ld (cl_c0), a
            ld hl, (cl_x1)
            ld de, (cl_y1)
            call cl_code
            ld (cl_c1), a
            pop bc
            ld c, a
            ld a, (cl_c0)
            or c
            jr z, cl_in             ; both in
            ld a, (cl_c0)
            and c
            jr nz, cl_out           ; both off the same side
            dec b
            jr z, cl_out
            push bc
            ld a, (cl_c0)
            or a
            jr z, cl_p1
            call cl_cut0            ; point 0 is out: move it
            pop bc
            jr cl_again
cl_p1:
            call cl_swap            ; point 1 is out: swap, move, swap back
            call cl_cut0
            call cl_swap
            pop bc
            jr cl_again
cl_in:
            ld a, (cl_x0)
            ld (dl_x0), a
            ld a, (cl_y0)
            ld (dl_y0), a
            ld a, (cl_x1)
            ld (dl_x1), a
            ld a, (cl_y1)
            ld (dl_y1), a
            or a
            ret
cl_out:
            scf
            ret
; A = the outcode of HL, DE: 1 left, 2 right, 4 above, 8 below
cl_code:
            xor a
            bit 7, h
            jr z, cl_cx1
            or 1
            jr cl_cy
cl_cx1:
            inc h
            dec h
            jr z, cl_cy
            or 2
cl_cy:
            bit 7, d
            jr z, cl_cy1
            or 4
            ret
cl_cy1:
            ld c, a
            ld a, d
            or a
            jr nz, cl_cy2
            ld a, e
            cp 192
            ld a, c
            ret c
            or 8
            ret
cl_cy2:
            ld a, c
            or 8
            ret
cl_swap:
            ld hl, (cl_x0)
            ld de, (cl_x1)
            ld (cl_x0), de
            ld (cl_x1), hl
            ld hl, (cl_y0)
            ld de, (cl_y1)
            ld (cl_y0), de
            ld (cl_y1), hl
            ld a, (cl_c0)
            ld c, a
            ld a, (cl_c1)
            ld (cl_c0), a
            ld a, c
            ld (cl_c1), a
            ret
; point 0 moved onto the edge its code names first (above, below, left, right)
cl_cut0:
            ld a, (cl_c0)
            bit 2, a
            jr z, cl_cb
            ld hl, 0                ; above: y = 0
            jr cl_cuty
cl_cb:
            bit 3, a
            jr z, cl_cl
            ld hl, 191              ; below: y = 191
cl_cuty:
            ; x0 = x0 + (x1 - x0) * (edge - y0) / (y1 - y0) ; y0 = edge
            ld (cl_e), hl
            ld de, (cl_y0)
            or a
            sbc hl, de              ; edge - y0
            ld b, h
            ld c, l
            ld hl, (cl_x1)
            ld de, (cl_x0)
            or a
            sbc hl, de              ; x1 - x0
            ex de, hl
            call cl_muls            ; DEHL = (x1 - x0) * (edge - y0)
            push de
            push hl
            ld hl, (cl_y1)
            ld de, (cl_y0)
            or a
            sbc hl, de
            ld b, h
            ld c, l                 ; y1 - y0
            pop hl
            pop de
            call cl_divs            ; HL = DEHL / BC
            ld de, (cl_x0)
            add hl, de
            ld (cl_x0), hl
            ld hl, (cl_e)
            ld (cl_y0), hl
            ret
cl_cl:
            bit 0, a
            jr z, cl_cr
            ld hl, 0                ; left: x = 0
            jr cl_cutx
cl_cr:
            ld hl, 255              ; right: x = 255
cl_cutx:
            ld (cl_e), hl
            ld de, (cl_x0)
            or a
            sbc hl, de
            ld b, h
            ld c, l
            ld hl, (cl_y1)
            ld de, (cl_y0)
            or a
            sbc hl, de
            ex de, hl
            call cl_muls
            push de
            push hl
            ld hl, (cl_x1)
            ld de, (cl_x0)
            or a
            sbc hl, de
            ld b, h
            ld c, l
            pop hl
            pop de
            call cl_divs
            ld de, (cl_y0)
            add hl, de
            ld (cl_y0), hl
            ld hl, (cl_e)
            ld (cl_x0), hl
            ret
; DEHL = DE * BC, signed
cl_muls:
            ld a, d
            xor b
            ld (cl_sg), a
            bit 7, d
            jr z, cl_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
cl_m1:
            bit 7, b
            jr z, cl_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
cl_m2:
            ld hl, 0                ; DE x BC unsigned -> HL:IX? (kept: HL high, (cl_lo) low)
            ld a, 16
            ld (cl_n), a
            ld ix, 0
cl_m3:
            add ix, ix
            adc hl, hl
            sla e
            rl d
            jr nc, cl_m4
            add ix, bc
            jr nc, cl_m4
            inc hl
cl_m4:
            ld a, (cl_n)
            dec a
            ld (cl_n), a
            jr nz, cl_m3
            ex de, hl               ; DE high
            push ix
            pop hl                  ; HL low
            ld a, (cl_sg)
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
cl_divs:
            ld a, d
            xor b
            ld (cl_sg), a
            bit 7, d
            jr z, cl_d1
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
cl_d1:
            bit 7, b
            jr z, cl_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
cl_d2:
            ld a, b
            or c
            jr nz, cl_d3
            ld hl, 0
            ret
cl_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ld a, 16
            ld (cl_n), a
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, cl_d4
            ld hl, 32767
            jr cl_d7
cl_d4:
            add hl, bc
cl_d5:
            sla e
            rl d
            adc hl, hl
            jr c, cl_d5b
            or a
            sbc hl, bc
            jr nc, cl_d6
            add hl, bc
            jr cl_d6n
cl_d5b:
            or a
            sbc hl, bc
cl_d6:
            inc e
cl_d6n:
            ld a, (cl_n)
            dec a
            ld (cl_n), a
            jr nz, cl_d5
            ex de, hl               ; HL = quotient
cl_d7:
            ld a, (cl_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
cl_x0:      dw 0
cl_y0:      dw 0
cl_x1:      dw 0
cl_y1:      dw 0
cl_c0:      db 0
cl_c1:      db 0
cl_e:       dw 0
cl_sg:      db 0
cl_n:       db 0

; ---- draw: dl_x0, dl_y0 -> dl_x1, dl_y1 (on the screen) in colour dl_c, Layer 2 pages from dl_base
dl_line:
            ld a, (dl_x1)
            ld hl, dl_x0
            sub (hl)
            ld c, #2C               ; inc l
            jr nc, dl_px
            neg
            ld c, #2D               ; dec l
dl_px:
            ld (dl_dx), a
            ld a, c
            ld (dl_xm1), a
            ld (dl_xm2), a
            ld a, (dl_y1)
            ld hl, dl_y0
            sub (hl)
            ld c, #24               ; inc h
            jr nc, dl_py
            neg
            ld c, #25               ; dec h
dl_py:
            ld (dl_dy), a
            ld a, c
            ld (dl_ym1), a
            ld (dl_ym2), a
            ld a, (dl_y0)
            ld e, a
            and 31
            or #C0
            ld h, a
            ld a, (dl_x0)
            ld l, a
            ld a, e
            rlca
            rlca
            rlca
            and 7
            ld e, a
            ld a, (dl_base)
            add a, e
            ld (dl_page), a
            call dl_map
            ld a, (dl_c)
            ld c, a
            ld a, (dl_dx)
            ld d, a
            ld a, (dl_dy)
            ld e, a
            cp d
            jr nc, dl_ymaj
            ld b, d                 ; x major: dx + 1 pixels
            inc b
            ld a, d
            srl a
dl_xl:
            ld (hl), c
dl_xm1:
            inc l
            sub e
            jr nc, dl_xn
            add a, d
dl_ym1:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
dl_xn:
            djnz dl_xl
            ret
dl_ymaj:
            ld b, e                 ; y major: dy + 1 pixels
            inc b
            ld a, e
            srl a
dl_yl:
            ld (hl), c
dl_ym2:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
            sub d
            jr nc, dl_yn
            add a, e
dl_xm2:
            inc l
dl_yn:
            djnz dl_yl
            ret
; H went off the 8K page: the next one (down) or the one before (up)
dl_wrap:
            ld a, h
            cp #E0
            jr nz, dl_wup
            ld h, #C0
            ld a, (dl_page)
            inc a
            jr dl_wset
dl_wup:
            ld h, #DF
            ld a, (dl_page)
            dec a
dl_wset:
            ld (dl_page), a
dl_map:
            push bc
            ld bc, #243B
            ld a, #56               ; MMU slot 6 (#C000-#DFFF)
            out (c), a
            inc b
            ld a, (dl_page)
            out (c), a
            pop bc
            ret
dl_x0:      db 0
dl_y0:      db 0
dl_x1:      db 0
dl_y1:      db 0
dl_c:       db 0
dl_dx:      db 0
dl_dy:      db 0
dl_page:    db 0
dl_base:    db 0
; ---- the line just drawn (dl_x0 ..) into the back buffer's list, for Clear
lg_add:
            ld hl, ({cnt0})
            ld a, ({cur})
            or a
            jr z, lg_a
            ld hl, ({cnt1})
lg_a:
            ld de, 1024
            or a
            sbc hl, de
            ret nc                  ; the list is full: not logged (it stays on the screen)
            add hl, de
            ld e, l
            ld d, h
            inc hl
            ld a, ({cur})
            or a
            jr nz, lg_b
            ld ({cnt0}), hl
            ld hl, {lg}
            jr lg_c
lg_b:
            ld ({cnt1}), hl
            ld hl, {lg} + 4096
lg_c:
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, de              ; the entry: base + n * 4
            ld a, (dl_x0)
            ld (hl), a
            inc hl
            ld a, (dl_y0)
            ld (hl), a
            inc hl
            ld a, (dl_x1)
            ld (hl), a
            inc hl
            ld a, (dl_y1)
            ld (hl), a
            ret
#endasm
End Sub

' Plot x, y, colour: a point (off the screen: nothing)
Public Sub Plot(ByVal x As Integer, ByVal y As Integer, ByVal colour As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl
            ld c, (hl)
            inc hl
            ld b, (hl)
            pop hl
            ld a, (hl)
            ld (dl_c), a
            ld a, d                 ; on the screen?
            or b
            jr nz, pl_none
            ld a, c
            cp 192
            jr nc, pl_none
            ld a, e
            ld (dl_x0), a
            ld (dl_x1), a
            ld a, c
            ld (dl_y0), a
            ld (dl_y1), a
            ld ({sps}), sp          ; the real stack (call / ret inside)
            ld sp, (ntc_csp)
            ld a, ({cur})
            or a
            ld a, ({bankA})
            jr z, bs_a
            ld a, ({bankB})
bs_a:
            add a, a
            ld (dl_base), a
            call dl_line
            call lg_add
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ld sp, ({sps})
pl_none:
            ret

; ---- draw: dl_x0, dl_y0 -> dl_x1, dl_y1 (on the screen) in colour dl_c, Layer 2 pages from dl_base
dl_line:
            ld a, (dl_x1)
            ld hl, dl_x0
            sub (hl)
            ld c, #2C               ; inc l
            jr nc, dl_px
            neg
            ld c, #2D               ; dec l
dl_px:
            ld (dl_dx), a
            ld a, c
            ld (dl_xm1), a
            ld (dl_xm2), a
            ld a, (dl_y1)
            ld hl, dl_y0
            sub (hl)
            ld c, #24               ; inc h
            jr nc, dl_py
            neg
            ld c, #25               ; dec h
dl_py:
            ld (dl_dy), a
            ld a, c
            ld (dl_ym1), a
            ld (dl_ym2), a
            ld a, (dl_y0)
            ld e, a
            and 31
            or #C0
            ld h, a
            ld a, (dl_x0)
            ld l, a
            ld a, e
            rlca
            rlca
            rlca
            and 7
            ld e, a
            ld a, (dl_base)
            add a, e
            ld (dl_page), a
            call dl_map
            ld a, (dl_c)
            ld c, a
            ld a, (dl_dx)
            ld d, a
            ld a, (dl_dy)
            ld e, a
            cp d
            jr nc, dl_ymaj
            ld b, d                 ; x major: dx + 1 pixels
            inc b
            ld a, d
            srl a
dl_xl:
            ld (hl), c
dl_xm1:
            inc l
            sub e
            jr nc, dl_xn
            add a, d
dl_ym1:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
dl_xn:
            djnz dl_xl
            ret
dl_ymaj:
            ld b, e                 ; y major: dy + 1 pixels
            inc b
            ld a, e
            srl a
dl_yl:
            ld (hl), c
dl_ym2:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
            sub d
            jr nc, dl_yn
            add a, e
dl_xm2:
            inc l
dl_yn:
            djnz dl_yl
            ret
; H went off the 8K page: the next one (down) or the one before (up)
dl_wrap:
            ld a, h
            cp #E0
            jr nz, dl_wup
            ld h, #C0
            ld a, (dl_page)
            inc a
            jr dl_wset
dl_wup:
            ld h, #DF
            ld a, (dl_page)
            dec a
dl_wset:
            ld (dl_page), a
dl_map:
            push bc
            ld bc, #243B
            ld a, #56               ; MMU slot 6 (#C000-#DFFF)
            out (c), a
            inc b
            ld a, (dl_page)
            out (c), a
            pop bc
            ret
dl_x0:      db 0
dl_y0:      db 0
dl_x1:      db 0
dl_y1:      db 0
dl_c:       db 0
dl_dx:      db 0
dl_dy:      db 0
dl_page:    db 0
dl_base:    db 0
; ---- the line just drawn (dl_x0 ..) into the back buffer's list, for Clear
lg_add:
            ld hl, ({cnt0})
            ld a, ({cur})
            or a
            jr z, lg_a
            ld hl, ({cnt1})
lg_a:
            ld de, 1024
            or a
            sbc hl, de
            ret nc                  ; the list is full: not logged (it stays on the screen)
            add hl, de
            ld e, l
            ld d, h
            inc hl
            ld a, ({cur})
            or a
            jr nz, lg_b
            ld ({cnt0}), hl
            ld hl, {lg}
            jr lg_c
lg_b:
            ld ({cnt1}), hl
            ld hl, {lg} + 4096
lg_c:
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, de              ; the entry: base + n * 4
            ld a, (dl_x0)
            ld (hl), a
            inc hl
            ld a, (dl_y0)
            ld (hl), a
            inc hl
            ld a, (dl_x1)
            ld (hl), a
            inc hl
            ld a, (dl_y1)
            ld (hl), a
            ret
#endasm
End Sub

' Shape x, y, address, colour: lines from a table, each point relative to x, y: a count of
' points, then each point as two signed bytes (dx, dy); a point dx = -128 lifts the pen (the
' next point starts a new line). Rotated or scaled shapes are made into tables by the program.
Public Sub Shape(ByVal x As Integer, ByVal y As Integer, ByVal address As Integer, ByVal colour As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (sh_x), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (sh_y), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (sh_p), hl
            pop hl
            ld a, (hl)
            ld (dl_c), a
            ld ({sps}), sp          ; the real stack (call / ret inside)
            ld sp, (ntc_csp)
            ; well inside the screen (a shape is +-12 at most): no cutting needed
            xor a
            ld (sh_fast), a
            ld hl, (sh_x)
            ld de, -12
            add hl, de
            ld a, h
            or a
            jr nz, sh_slow
            ld a, l
            cp 256 - 24
            jr nc, sh_slow
            ld hl, (sh_y)
            add hl, de
            ld a, h
            or a
            jr nz, sh_slow
            ld a, l
            cp 192 - 24
            jr nc, sh_slow
            ld a, 1
            ld (sh_fast), a
sh_slow:
            ld hl, (sh_p)
            ld a, (hl)
            or a
            jp z, sh_done
            ld (sh_n), a
            inc hl
            xor a
            ld (sh_up), a           ; the first point: the pen goes down there
            inc a
            ld (sh_up), a
sh_lp:
            ld a, (hl)
            inc hl
            cp #80
            jr nz, sh_pt
            inc hl
            ld a, 1
            ld (sh_up), a
            jp sh_next
sh_pt:
            ld e, a                 ; DE = x + dx
            rla
            sbc a, a
            ld d, a
            push hl
            ld hl, (sh_x)
            add hl, de
            ex de, hl
            pop hl
            ld a, (hl)
            inc hl
            push hl
            ld l, a
            rla
            sbc a, a
            ld h, a
            ld bc, (sh_y)
            add hl, bc              ; HL = y + dy
            ld a, (sh_up)
            or a
            jr nz, sh_move
            ; a line from the last point to this one
            ld (cl_x1), de
            ld (cl_y1), hl
            ld (sh_lx), de
            ld (sh_ly), hl
            ld hl, (sh_px)
            ld (cl_x0), hl
            ld hl, (sh_py)
            ld (cl_y0), hl
            ld a, (sh_fast)
            or a
            jp z, sh_cut
            ld a, (cl_x0)           ; on the screen for sure: straight to the bytes
            ld (dl_x0), a
            ld a, (cl_y0)
            ld (dl_y0), a
            ld a, (cl_x1)
            ld (dl_x1), a
            ld a, (cl_y1)
            ld (dl_y1), a
            jp sh_draw
sh_cut:
            call cl_clip
            jp c, sh_skip
sh_draw:
            ld a, ({cur})
            or a
            ld a, ({bankA})
            jr z, bs_a
            ld a, ({bankB})
bs_a:
            add a, a
            ld (dl_base), a
            call dl_line
            call lg_add
sh_skip:
            ld hl, (sh_lx)
            ld (sh_px), hl
            ld hl, (sh_ly)
            ld (sh_py), hl
            pop hl
            jp sh_next
sh_move:
            ld (sh_px), de
            ld (sh_py), hl
            xor a
            ld (sh_up), a
            pop hl
sh_next:
            ld a, (sh_n)
            dec a
            ld (sh_n), a
            jp nz, sh_lp
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
sh_done:
            ld sp, ({sps})
            ret
sh_x:       dw 0
sh_y:       dw 0
sh_p:       dw 0
sh_px:      dw 0
sh_py:      dw 0
sh_lx:      dw 0
sh_ly:      dw 0
sh_n:       db 0
sh_up:      db 0
sh_fast:    db 0

; ---- clip: cl_x0, cl_y0, cl_x1, cl_y1 (signed) to the screen; NC = draw dl_x0 .. dl_y1
cl_clip:
            ld b, 8                 ; at most 8 cuts
cl_again:
            push bc
            ld hl, (cl_x0)
            ld de, (cl_y0)
            call cl_code
            ld (cl_c0), a
            ld hl, (cl_x1)
            ld de, (cl_y1)
            call cl_code
            ld (cl_c1), a
            pop bc
            ld c, a
            ld a, (cl_c0)
            or c
            jr z, cl_in             ; both in
            ld a, (cl_c0)
            and c
            jr nz, cl_out           ; both off the same side
            dec b
            jr z, cl_out
            push bc
            ld a, (cl_c0)
            or a
            jr z, cl_p1
            call cl_cut0            ; point 0 is out: move it
            pop bc
            jr cl_again
cl_p1:
            call cl_swap            ; point 1 is out: swap, move, swap back
            call cl_cut0
            call cl_swap
            pop bc
            jr cl_again
cl_in:
            ld a, (cl_x0)
            ld (dl_x0), a
            ld a, (cl_y0)
            ld (dl_y0), a
            ld a, (cl_x1)
            ld (dl_x1), a
            ld a, (cl_y1)
            ld (dl_y1), a
            or a
            ret
cl_out:
            scf
            ret
; A = the outcode of HL, DE: 1 left, 2 right, 4 above, 8 below
cl_code:
            xor a
            bit 7, h
            jr z, cl_cx1
            or 1
            jr cl_cy
cl_cx1:
            inc h
            dec h
            jr z, cl_cy
            or 2
cl_cy:
            bit 7, d
            jr z, cl_cy1
            or 4
            ret
cl_cy1:
            ld c, a
            ld a, d
            or a
            jr nz, cl_cy2
            ld a, e
            cp 192
            ld a, c
            ret c
            or 8
            ret
cl_cy2:
            ld a, c
            or 8
            ret
cl_swap:
            ld hl, (cl_x0)
            ld de, (cl_x1)
            ld (cl_x0), de
            ld (cl_x1), hl
            ld hl, (cl_y0)
            ld de, (cl_y1)
            ld (cl_y0), de
            ld (cl_y1), hl
            ld a, (cl_c0)
            ld c, a
            ld a, (cl_c1)
            ld (cl_c0), a
            ld a, c
            ld (cl_c1), a
            ret
; point 0 moved onto the edge its code names first (above, below, left, right)
cl_cut0:
            ld a, (cl_c0)
            bit 2, a
            jr z, cl_cb
            ld hl, 0                ; above: y = 0
            jr cl_cuty
cl_cb:
            bit 3, a
            jr z, cl_cl
            ld hl, 191              ; below: y = 191
cl_cuty:
            ; x0 = x0 + (x1 - x0) * (edge - y0) / (y1 - y0) ; y0 = edge
            ld (cl_e), hl
            ld de, (cl_y0)
            or a
            sbc hl, de              ; edge - y0
            ld b, h
            ld c, l
            ld hl, (cl_x1)
            ld de, (cl_x0)
            or a
            sbc hl, de              ; x1 - x0
            ex de, hl
            call cl_muls            ; DEHL = (x1 - x0) * (edge - y0)
            push de
            push hl
            ld hl, (cl_y1)
            ld de, (cl_y0)
            or a
            sbc hl, de
            ld b, h
            ld c, l                 ; y1 - y0
            pop hl
            pop de
            call cl_divs            ; HL = DEHL / BC
            ld de, (cl_x0)
            add hl, de
            ld (cl_x0), hl
            ld hl, (cl_e)
            ld (cl_y0), hl
            ret
cl_cl:
            bit 0, a
            jr z, cl_cr
            ld hl, 0                ; left: x = 0
            jr cl_cutx
cl_cr:
            ld hl, 255              ; right: x = 255
cl_cutx:
            ld (cl_e), hl
            ld de, (cl_x0)
            or a
            sbc hl, de
            ld b, h
            ld c, l
            ld hl, (cl_y1)
            ld de, (cl_y0)
            or a
            sbc hl, de
            ex de, hl
            call cl_muls
            push de
            push hl
            ld hl, (cl_x1)
            ld de, (cl_x0)
            or a
            sbc hl, de
            ld b, h
            ld c, l
            pop hl
            pop de
            call cl_divs
            ld de, (cl_y0)
            add hl, de
            ld (cl_y0), hl
            ld hl, (cl_e)
            ld (cl_x0), hl
            ret
; DEHL = DE * BC, signed
cl_muls:
            ld a, d
            xor b
            ld (cl_sg), a
            bit 7, d
            jr z, cl_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
cl_m1:
            bit 7, b
            jr z, cl_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
cl_m2:
            ld hl, 0                ; DE x BC unsigned -> HL:IX? (kept: HL high, (cl_lo) low)
            ld a, 16
            ld (cl_n), a
            ld ix, 0
cl_m3:
            add ix, ix
            adc hl, hl
            sla e
            rl d
            jr nc, cl_m4
            add ix, bc
            jr nc, cl_m4
            inc hl
cl_m4:
            ld a, (cl_n)
            dec a
            ld (cl_n), a
            jr nz, cl_m3
            ex de, hl               ; DE high
            push ix
            pop hl                  ; HL low
            ld a, (cl_sg)
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
cl_divs:
            ld a, d
            xor b
            ld (cl_sg), a
            bit 7, d
            jr z, cl_d1
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
cl_d1:
            bit 7, b
            jr z, cl_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
cl_d2:
            ld a, b
            or c
            jr nz, cl_d3
            ld hl, 0
            ret
cl_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ld a, 16
            ld (cl_n), a
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, cl_d4
            ld hl, 32767
            jr cl_d7
cl_d4:
            add hl, bc
cl_d5:
            sla e
            rl d
            adc hl, hl
            jr c, cl_d5b
            or a
            sbc hl, bc
            jr nc, cl_d6
            add hl, bc
            jr cl_d6n
cl_d5b:
            or a
            sbc hl, bc
cl_d6:
            inc e
cl_d6n:
            ld a, (cl_n)
            dec a
            ld (cl_n), a
            jr nz, cl_d5
            ex de, hl               ; HL = quotient
cl_d7:
            ld a, (cl_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
cl_x0:      dw 0
cl_y0:      dw 0
cl_x1:      dw 0
cl_y1:      dw 0
cl_c0:      db 0
cl_c1:      db 0
cl_e:       dw 0
cl_sg:      db 0
cl_n:       db 0

; ---- draw: dl_x0, dl_y0 -> dl_x1, dl_y1 (on the screen) in colour dl_c, Layer 2 pages from dl_base
dl_line:
            ld a, (dl_x1)
            ld hl, dl_x0
            sub (hl)
            ld c, #2C               ; inc l
            jr nc, dl_px
            neg
            ld c, #2D               ; dec l
dl_px:
            ld (dl_dx), a
            ld a, c
            ld (dl_xm1), a
            ld (dl_xm2), a
            ld a, (dl_y1)
            ld hl, dl_y0
            sub (hl)
            ld c, #24               ; inc h
            jr nc, dl_py
            neg
            ld c, #25               ; dec h
dl_py:
            ld (dl_dy), a
            ld a, c
            ld (dl_ym1), a
            ld (dl_ym2), a
            ld a, (dl_y0)
            ld e, a
            and 31
            or #C0
            ld h, a
            ld a, (dl_x0)
            ld l, a
            ld a, e
            rlca
            rlca
            rlca
            and 7
            ld e, a
            ld a, (dl_base)
            add a, e
            ld (dl_page), a
            call dl_map
            ld a, (dl_c)
            ld c, a
            ld a, (dl_dx)
            ld d, a
            ld a, (dl_dy)
            ld e, a
            cp d
            jr nc, dl_ymaj
            ld b, d                 ; x major: dx + 1 pixels
            inc b
            ld a, d
            srl a
dl_xl:
            ld (hl), c
dl_xm1:
            inc l
            sub e
            jr nc, dl_xn
            add a, d
dl_ym1:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
dl_xn:
            djnz dl_xl
            ret
dl_ymaj:
            ld b, e                 ; y major: dy + 1 pixels
            inc b
            ld a, e
            srl a
dl_yl:
            ld (hl), c
dl_ym2:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
            sub d
            jr nc, dl_yn
            add a, e
dl_xm2:
            inc l
dl_yn:
            djnz dl_yl
            ret
; H went off the 8K page: the next one (down) or the one before (up)
dl_wrap:
            ld a, h
            cp #E0
            jr nz, dl_wup
            ld h, #C0
            ld a, (dl_page)
            inc a
            jr dl_wset
dl_wup:
            ld h, #DF
            ld a, (dl_page)
            dec a
dl_wset:
            ld (dl_page), a
dl_map:
            push bc
            ld bc, #243B
            ld a, #56               ; MMU slot 6 (#C000-#DFFF)
            out (c), a
            inc b
            ld a, (dl_page)
            out (c), a
            pop bc
            ret
dl_x0:      db 0
dl_y0:      db 0
dl_x1:      db 0
dl_y1:      db 0
dl_c:       db 0
dl_dx:      db 0
dl_dy:      db 0
dl_page:    db 0
dl_base:    db 0
; ---- the line just drawn (dl_x0 ..) into the back buffer's list, for Clear
lg_add:
            ld hl, ({cnt0})
            ld a, ({cur})
            or a
            jr z, lg_a
            ld hl, ({cnt1})
lg_a:
            ld de, 1024
            or a
            sbc hl, de
            ret nc                  ; the list is full: not logged (it stays on the screen)
            add hl, de
            ld e, l
            ld d, h
            inc hl
            ld a, ({cur})
            or a
            jr nz, lg_b
            ld ({cnt0}), hl
            ld hl, {lg}
            jr lg_c
lg_b:
            ld ({cnt1}), hl
            ld hl, {lg} + 4096
lg_c:
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, de              ; the entry: base + n * 4
            ld a, (dl_x0)
            ld (hl), a
            inc hl
            ld a, (dl_y0)
            ld (hl), a
            inc hl
            ld a, (dl_x1)
            ld (hl), a
            inc hl
            ld a, (dl_y1)
            ld (hl), a
            ret
#endasm
End Sub


' Lines count, address, colour: count lines from a table of words (x0, y0, x1, y1 each,
' signed), each cut to the screen - one call for a whole model (View.Model fills such a table)
Public Sub Lines(ByVal count As Integer, ByVal address As Integer, ByVal colour As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (ls_n), hl
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld (ls_p), hl
            pop hl
            ld a, (hl)
            ld (dl_c), a
            ld ({sps}), sp          ; the real stack (call / ret inside)
            ld sp, (ntc_csp)
ls_lp:
            ld hl, (ls_n)
            ld a, h
            or l
            jr z, ls_done
            dec hl
            ld (ls_n), hl
            ld hl, (ls_p)
            ld de, cl_x0
            ld bc, 8
            ldir
            ld (ls_p), hl
            call cl_clip
            jr c, ls_lp
            ld a, ({cur})
            or a
            ld a, ({bankA})
            jr z, bs_a
            ld a, ({bankB})
bs_a:
            add a, a
            ld (dl_base), a
            call dl_line
            call lg_add
            jr ls_lp
ls_done:
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            ld sp, ({sps})
            ret
ls_n:       dw 0
ls_p:       dw 0

; ---- clip: cl_x0, cl_y0, cl_x1, cl_y1 (signed) to the screen; NC = draw dl_x0 .. dl_y1
cl_clip:
            ld b, 8                 ; at most 8 cuts
cl_again:
            push bc
            ld hl, (cl_x0)
            ld de, (cl_y0)
            call cl_code
            ld (cl_c0), a
            ld hl, (cl_x1)
            ld de, (cl_y1)
            call cl_code
            ld (cl_c1), a
            pop bc
            ld c, a
            ld a, (cl_c0)
            or c
            jr z, cl_in             ; both in
            ld a, (cl_c0)
            and c
            jr nz, cl_out           ; both off the same side
            dec b
            jr z, cl_out
            push bc
            ld a, (cl_c0)
            or a
            jr z, cl_p1
            call cl_cut0            ; point 0 is out: move it
            pop bc
            jr cl_again
cl_p1:
            call cl_swap            ; point 1 is out: swap, move, swap back
            call cl_cut0
            call cl_swap
            pop bc
            jr cl_again
cl_in:
            ld a, (cl_x0)
            ld (dl_x0), a
            ld a, (cl_y0)
            ld (dl_y0), a
            ld a, (cl_x1)
            ld (dl_x1), a
            ld a, (cl_y1)
            ld (dl_y1), a
            or a
            ret
cl_out:
            scf
            ret
; A = the outcode of HL, DE: 1 left, 2 right, 4 above, 8 below
cl_code:
            xor a
            bit 7, h
            jr z, cl_cx1
            or 1
            jr cl_cy
cl_cx1:
            inc h
            dec h
            jr z, cl_cy
            or 2
cl_cy:
            bit 7, d
            jr z, cl_cy1
            or 4
            ret
cl_cy1:
            ld c, a
            ld a, d
            or a
            jr nz, cl_cy2
            ld a, e
            cp 192
            ld a, c
            ret c
            or 8
            ret
cl_cy2:
            ld a, c
            or 8
            ret
cl_swap:
            ld hl, (cl_x0)
            ld de, (cl_x1)
            ld (cl_x0), de
            ld (cl_x1), hl
            ld hl, (cl_y0)
            ld de, (cl_y1)
            ld (cl_y0), de
            ld (cl_y1), hl
            ld a, (cl_c0)
            ld c, a
            ld a, (cl_c1)
            ld (cl_c0), a
            ld a, c
            ld (cl_c1), a
            ret
; point 0 moved onto the edge its code names first (above, below, left, right)
cl_cut0:
            ld a, (cl_c0)
            bit 2, a
            jr z, cl_cb
            ld hl, 0                ; above: y = 0
            jr cl_cuty
cl_cb:
            bit 3, a
            jr z, cl_cl
            ld hl, 191              ; below: y = 191
cl_cuty:
            ; x0 = x0 + (x1 - x0) * (edge - y0) / (y1 - y0) ; y0 = edge
            ld (cl_e), hl
            ld de, (cl_y0)
            or a
            sbc hl, de              ; edge - y0
            ld b, h
            ld c, l
            ld hl, (cl_x1)
            ld de, (cl_x0)
            or a
            sbc hl, de              ; x1 - x0
            ex de, hl
            call cl_muls            ; DEHL = (x1 - x0) * (edge - y0)
            push de
            push hl
            ld hl, (cl_y1)
            ld de, (cl_y0)
            or a
            sbc hl, de
            ld b, h
            ld c, l                 ; y1 - y0
            pop hl
            pop de
            call cl_divs            ; HL = DEHL / BC
            ld de, (cl_x0)
            add hl, de
            ld (cl_x0), hl
            ld hl, (cl_e)
            ld (cl_y0), hl
            ret
cl_cl:
            bit 0, a
            jr z, cl_cr
            ld hl, 0                ; left: x = 0
            jr cl_cutx
cl_cr:
            ld hl, 255              ; right: x = 255
cl_cutx:
            ld (cl_e), hl
            ld de, (cl_x0)
            or a
            sbc hl, de
            ld b, h
            ld c, l
            ld hl, (cl_y1)
            ld de, (cl_y0)
            or a
            sbc hl, de
            ex de, hl
            call cl_muls
            push de
            push hl
            ld hl, (cl_x1)
            ld de, (cl_x0)
            or a
            sbc hl, de
            ld b, h
            ld c, l
            pop hl
            pop de
            call cl_divs
            ld de, (cl_y0)
            add hl, de
            ld (cl_y0), hl
            ld hl, (cl_e)
            ld (cl_x0), hl
            ret
; DEHL = DE * BC, signed
cl_muls:
            ld a, d
            xor b
            ld (cl_sg), a
            bit 7, d
            jr z, cl_m1
            xor a
            sub e
            ld e, a
            sbc a, a
            sub d
            ld d, a
cl_m1:
            bit 7, b
            jr z, cl_m2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
cl_m2:
            ld hl, 0                ; DE x BC unsigned -> HL:IX? (kept: HL high, (cl_lo) low)
            ld a, 16
            ld (cl_n), a
            ld ix, 0
cl_m3:
            add ix, ix
            adc hl, hl
            sla e
            rl d
            jr nc, cl_m4
            add ix, bc
            jr nc, cl_m4
            inc hl
cl_m4:
            ld a, (cl_n)
            dec a
            ld (cl_n), a
            jr nz, cl_m3
            ex de, hl               ; DE high
            push ix
            pop hl                  ; HL low
            ld a, (cl_sg)
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
cl_divs:
            ld a, d
            xor b
            ld (cl_sg), a
            bit 7, d
            jr z, cl_d1
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
cl_d1:
            bit 7, b
            jr z, cl_d2
            xor a
            sub c
            ld c, a
            sbc a, a
            sub b
            ld b, a
cl_d2:
            ld a, b
            or c
            jr nz, cl_d3
            ld hl, 0
            ret
cl_d3:
            ; DEHL / BC: the remainder in DE as the dividend's bits come in from HL
            ld a, 16
            ld (cl_n), a
            ; first make sure the high word is below the divisor (else the quotient is > 16 bits): clamp
            ex de, hl               ; HL = high, DE = low
            or a
            sbc hl, bc
            jr c, cl_d4
            ld hl, 32767
            jr cl_d7
cl_d4:
            add hl, bc
cl_d5:
            sla e
            rl d
            adc hl, hl
            jr c, cl_d5b
            or a
            sbc hl, bc
            jr nc, cl_d6
            add hl, bc
            jr cl_d6n
cl_d5b:
            or a
            sbc hl, bc
cl_d6:
            inc e
cl_d6n:
            ld a, (cl_n)
            dec a
            ld (cl_n), a
            jr nz, cl_d5
            ex de, hl               ; HL = quotient
cl_d7:
            ld a, (cl_sg)
            bit 7, a
            ret z
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
cl_x0:      dw 0
cl_y0:      dw 0
cl_x1:      dw 0
cl_y1:      dw 0
cl_c0:      db 0
cl_c1:      db 0
cl_e:       dw 0
cl_sg:      db 0
cl_n:       db 0

; ---- draw: dl_x0, dl_y0 -> dl_x1, dl_y1 (on the screen) in colour dl_c, Layer 2 pages from dl_base
dl_line:
            ld a, (dl_x1)
            ld hl, dl_x0
            sub (hl)
            ld c, #2C               ; inc l
            jr nc, dl_px
            neg
            ld c, #2D               ; dec l
dl_px:
            ld (dl_dx), a
            ld a, c
            ld (dl_xm1), a
            ld (dl_xm2), a
            ld a, (dl_y1)
            ld hl, dl_y0
            sub (hl)
            ld c, #24               ; inc h
            jr nc, dl_py
            neg
            ld c, #25               ; dec h
dl_py:
            ld (dl_dy), a
            ld a, c
            ld (dl_ym1), a
            ld (dl_ym2), a
            ld a, (dl_y0)
            ld e, a
            and 31
            or #C0
            ld h, a
            ld a, (dl_x0)
            ld l, a
            ld a, e
            rlca
            rlca
            rlca
            and 7
            ld e, a
            ld a, (dl_base)
            add a, e
            ld (dl_page), a
            call dl_map
            ld a, (dl_c)
            ld c, a
            ld a, (dl_dx)
            ld d, a
            ld a, (dl_dy)
            ld e, a
            cp d
            jr nc, dl_ymaj
            ld b, d                 ; x major: dx + 1 pixels
            inc b
            ld a, d
            srl a
dl_xl:
            ld (hl), c
dl_xm1:
            inc l
            sub e
            jr nc, dl_xn
            add a, d
dl_ym1:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
dl_xn:
            djnz dl_xl
            ret
dl_ymaj:
            ld b, e                 ; y major: dy + 1 pixels
            inc b
            ld a, e
            srl a
dl_yl:
            ld (hl), c
dl_ym2:
            inc h
            ex af, af'
            ld a, h
            and #E0
            cp #C0
            call nz, dl_wrap
            ex af, af'
            sub d
            jr nc, dl_yn
            add a, e
dl_xm2:
            inc l
dl_yn:
            djnz dl_yl
            ret
; H went off the 8K page: the next one (down) or the one before (up)
dl_wrap:
            ld a, h
            cp #E0
            jr nz, dl_wup
            ld h, #C0
            ld a, (dl_page)
            inc a
            jr dl_wset
dl_wup:
            ld h, #DF
            ld a, (dl_page)
            dec a
dl_wset:
            ld (dl_page), a
dl_map:
            push bc
            ld bc, #243B
            ld a, #56               ; MMU slot 6 (#C000-#DFFF)
            out (c), a
            inc b
            ld a, (dl_page)
            out (c), a
            pop bc
            ret
dl_x0:      db 0
dl_y0:      db 0
dl_x1:      db 0
dl_y1:      db 0
dl_c:       db 0
dl_dx:      db 0
dl_dy:      db 0
dl_page:    db 0
dl_base:    db 0
; ---- the line just drawn (dl_x0 ..) into the back buffer's list, for Clear
lg_add:
            ld hl, ({cnt0})
            ld a, ({cur})
            or a
            jr z, lg_a
            ld hl, ({cnt1})
lg_a:
            ld de, 1024
            or a
            sbc hl, de
            ret nc                  ; the list is full: not logged (it stays on the screen)
            add hl, de
            ld e, l
            ld d, h
            inc hl
            ld a, ({cur})
            or a
            jr nz, lg_b
            ld ({cnt0}), hl
            ld hl, {lg}
            jr lg_c
lg_b:
            ld ({cnt1}), hl
            ld hl, {lg} + 4096
lg_c:
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, de              ; the entry: base + n * 4
            ld a, (dl_x0)
            ld (hl), a
            inc hl
            ld a, (dl_y0)
            ld (hl), a
            inc hl
            ld a, (dl_x1)
            ld (hl), a
            inc hl
            ld a, (dl_y1)
            ld (hl), a
            ret
#endasm
End Sub

' Back(): the buffer drawn on (0 / 1)
Public Function Back() As Integer
  Back = cur
End Function

' Used(): lines and points drawn on this buffer since its Clear
Public Function Used() As Integer
  If cur Then Used = cnt1 Else Used = cnt0
End Function
