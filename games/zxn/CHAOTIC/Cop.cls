' Cop - CHAOTIC's copper: on every line of the picture it sets the fallback colour (NextReg #4A:
' what shows where every layer is see-through - the background) and Layer 2's sideways scroll
' (NextReg #16: the web wobbles). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The background is a band of colours from g() that rolls down the screen (phase); a flash
' colour fills it all; amp makes Layer 2 wobble side to side (a sine wave rolling down).
' The list: every other line of the 192 x (WAIT line, MOVE #4A, MOVE #16) = 6 bytes, black under
' the picture, the end: 582 bytes (every other line: half the time to send it, and the bands are
' 8 lines deep anyway).
' A frame:  Cop.Build phase, amp, flash   (any time)
'           Frame : Cop.Show              (straight after Frame, in the top border)
Option Explicit

Private cop(583) As Byte
Private g(255) As Byte
Private ph As Integer, am As Integer, fl As Integer, cnt As Integer

' Grad i, c: background colour i (0-255) of the rolling band is c (RRRGGGBB)
Public Sub Grad(ByVal i As Integer, ByVal c As Integer)
  g(i And 255) = c
End Sub

' Build phase, amp, flash: the list for the next frame. phase rolls the band (0-255), amp the
' wobble (0 none - 127 about 63 pixels each way; the game asks for up to 64, about 32), flash not 0: the whole background that colour
Public Sub Build(ByVal phase As Integer, ByVal amp As Integer, ByVal flash As Integer)
#asm
            pop hl
            ld a, (hl)
            ld ({ph}), a
            pop hl
            ld a, (hl)
            ld (cb_amp + 1), a
            pop hl
            ld a, (hl)
            ld ({fl}), a
            ld hl, {cop}
            ld c, 0                 ; the line
cb_lp:
            ld (hl), #80            ; WAIT line c, at the start of the line
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #4A            ; the background
            inc hl
            ld a, ({fl})
            or a
            jr nz, cb_fl
            ld a, c
            srl a
            ld e, a
            ld a, ({ph})
            add a, e
            ld de, {g}
            add a, e
            ld e, a
            jr nc, cb_g1
            inc d
cb_g1:
            ld a, (de)
cb_fl:
            ld (hl), a
            inc hl
            ld (hl), #16            ; Layer 2's scroll
            inc hl
            ; sin(line * 4 + phase * 2) * amp / 256
            ld a, ({ph})
            add a, a
            ld e, a
            ld a, c
            add a, a
            add a, a
            add a, e
            ld de, fn_bul_sines_sn_data
            add a, e
            ld e, a
            jr nc, cb_g2
            inc d
cb_g2:
            ld a, (de)
            ld b, a
            bit 7, a
            jr z, cb_p
            neg
cb_p:
            ld d, a
cb_amp:
            ld e, 0
cb_zm:
            db #ED, #30             ; mul d, e
            ld a, d
            bit 7, b
            jr z, cb_v
            neg
cb_v:
            ld (hl), a
            inc hl
            inc c
            inc c
            ld a, c
            cp 192
            jr nz, cb_lp
            ld (hl), #80            ; under the picture: the background black
            inc hl
            ld (hl), 192
            inc hl
            ld (hl), #4A
            inc hl
            ld (hl), 0
            inc hl
            ld (hl), #FF            ; the end: a line that never comes
            inc hl
            ld (hl), #FF
#endasm
End Sub

' Show: the list to the copper (straight after Frame): stopped, written from the start, started
' again (from the top at every frame)
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
            out (c), a
            dec b
            ld a, #60
            out (c), a
            inc b
            ld hl, {cop}
            ld e, 145
cs_lp1:
            ld a, (hl)              ; 582 bytes: 4 x 145, then 2
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, cs_lp1
            ld e, 2
cs_lp2:
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, cs_lp2
            dec b
            ld a, #62
            out (c), a
            inc b
            ld a, #C0
            out (c), a
#endasm
End Sub

' Off: the copper stopped, the background black, no wobble
Public Sub Off()
  Nx.Reg &H62, 0
  Nx.Reg &H4A, 0
  Nx.Reg &H16, 0
End Sub
