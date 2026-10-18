' Road - the road and the sky for ESCORT, on Layer 2, bent and rolled by the copper.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Layer 2 holds a picture that never changes: the sky in rows 0-79 (Scenery.cls), and below it
' 112 straight roads, one a row, each a little wider than the one above (row 80 + dy: half a
' width of dy x 5 / 8 pixels, kerbs, a line down the middle). On screen, the line dy below the
' horizon shows row 80 + dy - so the vertical scroll is the same all the way down - and the copper
' sets, for each line:
'   the horizontal scroll (NextReg #16): where the road is on that line - the bends (shifting the
'     far lines most) and where you are across it (shifting the near lines most)
'   the palette offset (NextReg #70): light or dark stripes (grass, kerbs, road, the dashes) by
'     how far away the line is, so they rush towards you as you drive.
' Build makes the copper's list for the next frame; Show (straight after Frame) loads it.
' Distances: the line dy below the horizon is 888 / dy metres away (14208 / dy sixteenths); across,
' 1 unit is 6 / 128 of a metre, and x units are x * dy / 128 pixels on that line (the road's
' half width, 3.75 metres, is 80; the kerbs go out to about 92).
Option Explicit

Public Const SKYROWS = 80, ROWS = 112

Private inv(127) As Byte          ' 255 / dy
Private zl(127) As Integer        ' the line's distance: 14208 / dy (16ths of a metre)
Private lim(127) As Byte          ' how far the line may move before the road wraps round
Private sh(127) As Byte           ' how far each line moved this frame (signed)
Private cop(1023) As Byte         ' the copper's list
Private oat(109) As Byte          ' the roadside things' sprites (22 x 5 attribute bytes: slots 4-25)
Private copLen As Integer, cp As Integer, sps As Integer, yy As Integer, hor As Integer
Private ofl As Integer, ofull As Integer, opat As Integer, ox As Integer, od As Integer, odst As Integer
Private cam As Integer, l16 As Integer, l70 As Integer
Private crv As Integer, camx As Integer, zpos As Integer, skyx As Integer, s16 As Integer

' Init: Layer 2 on; its palette's road colours; the road rows drawn; the sky drawn; the tables
Public Sub Init()
  Dim dy As Integer, hw As Integer, rw As Integer
  Nx.Reg &H70, 0
  Nx.Reg &H12, 16
  Nx.Reg &H1C, 1
  Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0
  ' the road's colours: 1-4 the light stripes, 17-20 the dark (palette offset 1)
  Nx.Reg &H43, &H10
  Colour 1, &H34 : Colour 2, &HE4 : Colour 3, &H92 : Colour 4, &HFF
  Colour 17, &H30 : Colour 18, &HFF : Colour 19, &H6E : Colour 20, &H6E
  Nx.Reg &H43, 0
  Template
  Scenery.Draw
  Out &H123B, 2
  For dy = 0 To 127
    If dy = 0 Then inv(0) = 255 Else inv(dy) = 255 \ dy
    If dy = 0 Then zl(0) = 14208 Else zl(dy) = 14208 \ dy
    hw = dy : If hw > ROWS - 1 Then hw = ROWS - 1
    rw = hw \ 10 + 1
    hw = hw \ 2 + hw \ 8
    lim(dy) = 124 - hw - rw
    sh(dy) = 0
  Next
End Sub

Private Sub Colour(ByVal i As Integer, ByVal v As Integer)
  Nx.Reg &H40, i
  Nx.Reg &H41, v
End Sub

' the 112 road rows (80-191): grass, kerbs, road, the middle line
Private Sub Template()
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            xor a
            ld ({yy}), a
tp_row:
            ld a, ({yy})            ; the row: 80 + dy
            add a, 80
            ld c, a
            rlca                    ; its page: 32 + row / 32, into slot 6
            rlca
            rlca
            and 7
            add a, 32
            ld e, a
            push bc
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            out (c), e
            pop bc
            ld a, c
            and 31
            add a, #C0
            ld h, a                 ; HL = the row's start
            ld l, 0
            ld ({cp}), hl
            ld (hl), 1              ; grass all along
            ld d, h
            ld e, 1
            ld bc, 255
            ldir
            ld a, ({yy})            ; hw = dy * 5 / 8; rw = dy / 10 + 1; mw = dy / 28
            srl a
            ld b, a
            srl a
            srl a
            add a, b
            ld ({hor}), a           ; (hw, for now)
            ld a, ({yy})
            ld e, 26
            ld d, a
tp_zm1:
            db #ED, #30             ; mul d, e: dy * 26 / 256 = dy / 10
            ld a, d
            inc a
            ld ({crv}), a           ; (rw)
            ld a, ({yy})
            ld e, 9
            ld d, a
tp_zm2:
            db #ED, #30             ; dy * 9 / 256 = dy / 28
            ld a, d
            ld ({camx}), a          ; (mw)
            ; the kerbs: 128 - hw - rw .. 128 + hw + rw
            ld a, ({hor})
            ld b, a
            ld a, ({crv})
            add a, b
            ld b, a                 ; hw + rw
            ld a, 128
            sub b
            ld e, a
            ld a, b
            add a, a
            ld b, a
            ld c, 2
            call tp_span
            ; the road: 128 - hw .. 128 + hw
            ld a, ({hor})
            or a
            jr z, tp_next
            ld b, a
            ld a, 128
            sub b
            ld e, a
            ld a, b
            add a, a
            ld b, a
            ld c, 3
            call tp_span
            ; the line down the middle: 128 - mw .. 128 + mw
            ld a, ({camx})
            or a
            jr z, tp_next
            ld b, a
            ld a, 128
            sub b
            ld e, a
            ld a, b
            add a, a
            ld b, a
            ld c, 4
            call tp_span
tp_next:
            ld a, ({yy})
            inc a
            ld ({yy}), a
            cp 112
            jp nz, tp_row
            ld bc, #243B            ; slot 6 back to bank 5
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            jp tp_done
; B bytes of colour C from x = E of the row at ({cp})
tp_span:
            ld hl, ({cp})
            ld l, e
tp_sp:
            ld (hl), c
            inc hl
            djnz tp_sp
            ret
tp_done:
            ld sp, ({sps})
#endasm
End Sub

' Build h, curve, cx, z, sx: the copper list for the next frame - the horizon at paper line h
' (72-100), the bend (-127 .. 127: how far the horizon end moves, pixels; + bends right), where you
' are across the road (cx, -127 .. 127: the camera's place, 1 unit = 6/128 m, + right), how far
' you have come (z, 16ths of a metre - only its stripes matter, so it may wrap), the sky's scroll
Public Sub Build(ByVal h As Integer, ByVal curve As Integer, ByVal cx As Integer, ByVal z As Integer, ByVal sx As Integer)
#asm
            pop hl
            ld a, (hl)
            ld ({hor}), a
            pop hl
            ld a, (hl)
            ld ({crv}), a
            pop hl
            ld a, (hl)
            ld ({camx}), a
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({zpos}), de
            pop hl
            ld a, (hl)
            ld ({skyx}), a
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld hl, {cop}
            ld ({cp}), hl
            ; the sky: its scroll; the rows from the top (the same vertical scroll all the way down)
            ld b, #16
            ld a, ({skyx})
            call bu_emit
            ld b, #17
            ld a, ({hor})
            ld c, a
            ld a, 80
            sub c
            jr nc, bu_v
            add a, 192
bu_v:
            call bu_emit
            ld b, #70
            xor a
            call bu_emit
            ; the lines below the horizon: only what changes from the line above is sent
            ld a, ({hor})
            inc a
            ld ({yy}), a
            xor a
            ld ({s16}), a           ; dy (from 1)
            ld hl, 0
            ld ({cam}), hl          ; camx * dy, added up line by line
            ld a, ({skyx})
            ld ({l16}), a           ; the last horizontal scroll sent
            xor a
            ld ({l70}), a           ; the last palette offset sent
bu_lp:
            ld a, ({s16})           ; dy + 1
            inc a
            ld ({s16}), a
            ld e, a
            ld d, 0
            ; the bend: crv * inv(dy) / 256, rounded towards 0
            ld hl, {inv}
            add hl, de
            ld e, (hl)
            ld a, ({crv})
            call bu_smul            ; HL = crv * inv (signed)
            ld c, h                 ; C = the bend (signed)
            ; where you are: (camx * dy) / 128, added up
            ld a, ({camx})
            ld e, a
            rla
            sbc a, a
            ld d, a
            ld hl, ({cam})
            add hl, de
            ld ({cam}), hl
            add hl, hl              ; / 128
            ld e, h
            ld a, h
            rla
            sbc a, a
            ld d, a                 ; DE = the camera's shift
            ld a, c
            ld l, a
            rla
            sbc a, a
            ld h, a
            or a
            sbc hl, de              ; HL = bend - where you are
            ; kept within lim(dy) both ways
            ld a, ({s16})
            ld e, a
            ld d, 0
            ex de, hl
            ld bc, {lim}
            add hl, bc
            ld c, (hl)
            ex de, hl
            bit 7, h
            jr nz, bu_neg
            ld a, h
            or a
            jr nz, bu_hi
            ld a, l
            cp c
            jr c, bu_ok
bu_hi:
            ld l, c
            jr bu_ok
bu_neg:
            ld a, h
            inc a
            jr nz, bu_lo
            ld a, l
            neg
            cp c
            jr c, bu_ok
            jr z, bu_ok
bu_lo:
            ld a, c
            neg
            ld l, a
bu_ok:
            ld a, ({s16})
            ld e, a
            ld d, 0
            ld a, l
            ld hl, {sh}             ; sh(dy) = it
            add hl, de
            ld (hl), a
            neg
            ld b, a                 ; B = the scroll for this line
            ; the stripes: bit 6 of (the line's distance + how far you have come)
            ld hl, {zl}
            add hl, de
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld de, ({zpos})
            add hl, de
            ld a, l
            rlca
            rlca
            and 1
            ld c, a                 ; C = the palette offset
            ; anything to send?
            ld a, ({s16})
            cp 112
            jr nc, bu_send          ; below the last road row: always (the vertical scroll)
            ld a, ({l16})
            cp b
            jr nz, bu_send
            ld a, ({l70})
            cp c
            jr z, bu_next
bu_send:
            ld hl, ({cp})
            ld a, ({yy})            ; WAIT for the end of the line before (h 40)
            dec a
            ld (hl), #D0
            inc hl
            ld (hl), a
            inc hl
            ld a, ({l16})
            cp b
            jr z, bu_n16
            ld (hl), #16
            inc hl
            ld (hl), b
            inc hl
            ld a, b
            ld ({l16}), a
bu_n16:
            ld a, ({l70})
            cp c
            jr z, bu_n70
            ld (hl), #70
            inc hl
            ld (hl), c
            inc hl
            ld a, c
            ld ({l70}), a
bu_n70:
            ld a, ({s16})
            cp 112
            jr c, bu_n17
            ld (hl), #17
            inc hl
            ld a, ({yy})
            ld c, a
            ld a, 191
            sub c
            ld (hl), a
            inc hl
bu_n17:
            ld ({cp}), hl
bu_next:
            ld a, ({yy})
            inc a
            ld ({yy}), a
            cp 192
            jp nz, bu_lp
            ld hl, ({cp})           ; the end: HALT
            ld (hl), #FF
            inc hl
            ld (hl), #FF
            inc hl
            ld de, {cop}
            or a
            sbc hl, de
            ld ({copLen}), hl
            jp bu_done
; a MOVE: register B, value A
bu_emit:
            ld hl, ({cp})
            ld (hl), b
            inc hl
            ld (hl), a
            inc hl
            ld ({cp}), hl
            ret
; HL = A (signed) * E (0-255), signed
bu_smul:
            ld d, a
            bit 7, a
            jr z, bu_sp
            neg
            ld d, a
bu_zm1:
            db #ED, #30             ; mul d, e
            ex de, hl
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
            ret
bu_sp:
bu_zm2:
            db #ED, #30
            ex de, hl
            ret
bu_done:
            ld sp, ({sps})
#endasm
End Sub

' Show: the list to the copper (straight after Frame, in the top border): the copper stopped, the
' list written from the start, then started again (restarting each frame)
Public Sub Show()
#asm
            ld bc, #243B
            ld a, #61
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #62
            out (c), a
            inc b
            xor a
            out (c), a              ; stopped, index 0
            dec b
            ld a, #60
            out (c), a
            inc b
            ld hl, {cop}
            ld de, ({copLen})
            srl d                   ; words
            rr e
sw_lp:
            ld a, (hl)
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            dec de
            ld a, d
            or e
            jr nz, sw_lp
            dec b
            ld a, #62
            out (c), a
            inc b
            ld a, #C0
            out (c), a              ; start: from 0, again at each frame
#endasm
End Sub

' Shift(dy): how far the line dy below the horizon moved this frame (pixels, + right)
Public Function Shift(ByVal dy As Integer) As Integer
  Dim v As Integer
  If dy > 127 Then dy = 127
  v = sh(dy)
  If v > 127 Then v = v - 256
  Shift = v
End Function

' Obj j, d, x, pat, fl, full: roadside thing j's sprite (slot 4 + j) for something d sixteenths of a
' metre from the eye (72 - 11500, else hidden), x across (units of 6/128 m), its first pattern,
' attribute 2 (palette x 16, mirrors; + 1: one drawing only, no sizes), and how many units its
' full-size drawing stands for: the size picked from 8, 12, 16, 24, 32, 48, 64 pixels (the
' drawings at 1/2, 3/4 and full size, shown 1x, 2x or 4x), standing on the road at its distance
Public Sub Obj(ByVal j As Integer, ByVal d As Integer, ByVal x As Integer, ByVal pat As Integer, ByVal fl As Integer, ByVal full As Integer)
#asm
            pop hl
            ld a, (hl)
            ld l, a                 ; the record: oat + j * 5
            ld h, 0
            ld d, h
            ld e, l
            add hl, hl
            add hl, hl
            add hl, de
            ld de, {oat}
            add hl, de
            ld ({odst}), hl
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({od}), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld ({ox}), de
            pop hl
            ld a, (hl)
            ld ({opat}), a
            pop hl
            ld a, (hl)
            ld ({ofl}), a
            pop hl
            ld a, (hl)
            ld ({ofull}), a
            ; near enough, far enough?
            ld hl, ({od})
            bit 7, h
            jp nz, ob_hide
            ld de, 72
            or a
            sbc hl, de
            jp c, ob_hide
            ld hl, ({od})
            ld de, 11500
            or a
            sbc hl, de
            jp nc, ob_hide
            ; dy = 14208 / d (AC / DE)
            ld de, ({od})
            ld a, #37               ; 14208 = #3780
            ld c, #80
            ld hl, 0
            ld b, 16
ob_dv:
            sla c
            rla
            adc hl, hl
            sbc hl, de
            jr c, ob_dr
            inc c
            djnz ob_dv
            jr ob_dd
ob_dr:
            add hl, de
            djnz ob_dv
ob_dd:
            or a
            jp nz, ob_hide          ; (over 255)
            ld a, c
            cp 151
            jp nc, ob_hide
            ld ({yy}), a            ; yy = dy
            ; its size: full * dy / 128
            ld d, a
            ld a, ({ofull})
            ld e, a
ob_zm1:
            db #ED, #30             ; mul d, e
            ex de, hl
            add hl, hl
            ld a, h                 ; A = full * dy / 128 (up to 255)
            cp 5
            jp c, ob_hide
            ld bc, #0001            ; B: the drawing (0, 1, 2), C: the scale (1, 2, 4)
            cp 10
            jr c, ob_sz
            ld b, 1
            cp 14
            jr c, ob_sz
            ld b, 2
            cp 20
            jr c, ob_sz
            ld bc, #0102
            cp 28
            jr c, ob_sz
            ld bc, #0202
            cp 40
            jr c, ob_sz
            ld bc, #0104
            cp 56
            jr c, ob_sz
            ld bc, #0204
ob_sz:
            ld a, ({ofl})
            and 1
            jr z, ob_sizes
            ld b, 0                 ; one drawing only
ob_sizes:
            ld a, ({opat})
            add a, b
            ld ({opat}), a
            ld a, c
            ld ({ofull}), a         ; (the scale, from here on)
            ; x: 128 + shift(dy) + (x / 2) * dy / 64 - 8 * scale + 32
            ld hl, ({ox})
            sra h
            rr l                    ; x / 2: -128 .. 127
            ld a, l
            ld b, 0
            bit 7, a
            jr z, ob_xp
            neg
            ld b, 1
ob_xp:
            ld d, a
            ld a, ({yy})
            ld e, a
ob_zm2:
            db #ED, #30             ; |x / 2| * dy
            ex de, hl
            add hl, hl              ; / 64: * 4, / 256
            add hl, hl
            ld l, h
            ld h, 0
            ld a, b
            or a
            jr z, ob_xs
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
ob_xs:
            ex de, hl               ; DE = the offset
            ld a, ({yy})
            cp 128
            jr c, ob_sh
            ld a, 127
ob_sh:
            ld l, a
            ld h, 0
            ld bc, {sh}
            add hl, bc
            ld a, (hl)              ; shift(dy), signed
            ld l, a
            rla
            sbc a, a
            ld h, a
            add hl, de
            ld de, 160              ; + 128 + 32
            add hl, de
            ld a, ({ofull})         ; - 8 * scale
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            or a
            sbc hl, de
            ld a, h                 ; 0 .. 300, or hidden
            or a
            jr z, ob_xok
            dec a
            jp nz, ob_hide
            ld a, l
            cp 45
            jp nc, ob_hide
ob_xok:
            ld ({ox}), hl           ; (the sprite's x)
            ; y: hor + dy - 16 * scale + 33
            ld a, ({hor})
            ld l, a
            ld h, 0
            ld a, ({yy})
            ld e, a
            ld d, 0
            add hl, de
            ld de, 33
            add hl, de
            ld a, ({ofull})
            add a, a
            add a, a
            add a, a
            add a, a
            ld e, a
            ld d, 0
            or a
            sbc hl, de
            ld a, h
            or a
            jp nz, ob_hide
            ld a, l
            cp 224
            jp nc, ob_hide
            ; the attributes
            ld c, l                 ; C = y
            ld hl, ({odst})
            ld a, ({ox})
            ld (hl), a              ; 0: x
            inc hl
            ld (hl), c              ; 1: y
            inc hl
            ld a, ({ox} + 1)
            and 1
            ld b, a
            ld a, ({ofl})
            and #FE
            or b
            ld (hl), a              ; 2: palette, mirrors, x bit 8
            inc hl
            ld a, ({opat})
            ld c, a
            srl a
            or #C0
            ld (hl), a              ; 3: shown, 5 bytes, pattern / 2
            inc hl
            ld a, c
            and 1
            rrca
            rrca
            or #80                  ; 4: 4 bit, pattern bit 0, the scale
            ld b, a
            ld a, ({ofull})
            cp 2
            jr nz, ob_s4
            ld a, b
            or #0A
            jr ob_s
ob_s4:
            cp 4
            ld a, b
            jr nz, ob_s
            or #14
ob_s:
            ld (hl), a
            jp ob_done
ob_hide:
            ld hl, ({odst})
            inc hl
            inc hl
            inc hl
            ld (hl), #40            ; not shown
ob_done:
#endasm
End Sub

' ShowObj: the roadside things' sprites to slots 4-25 (straight after Frame, after Spr.Show)
Public Sub ShowObj()
#asm
            ld bc, #303B
            ld a, 4
            out (c), a
            ld hl, {oat}
            ld bc, 110 * 256 + #57
            otir
#endasm
End Sub
