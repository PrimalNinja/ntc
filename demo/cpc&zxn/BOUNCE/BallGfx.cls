' BallGfx - BOUNCE's ball, made by tools/mkball.py from gfx/ball.png: don't edit, run the tool.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' ZxnLoad: the Next's sprite pattern 0 and the sprite palette entries it uses.
' CpcInstall: the CPC's compiled ball copied to #E200 (CpcScr calls it there: see CpcScr.cls).
Option Explicit
Public Const W = 8          ' the CPC drawing's size: bytes across, lines (the border in)
Public Const H = 24
Public Const BX = 2         ' its border: bytes left, lines above
Public Const BY = 4
Private hsp As Integer

Public Sub ZxnLoad()
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld bc, #303B            ; pattern 0
            xor a
            out (c), a
            ld hl, bg_pat
            ld bc, #005B            ; 256 bytes to port #5B (B = 0: 256 times)
            otir
            ld bc, #243B            ; the sprite palette entries: each colour used = itself
            ld a, #43
            out (c), a
            inc b
            in a, (c)
            ld (bg_43), a           ; (the palette control as it was: put back after)
            and #8F
            or #20                  ; the first sprite palette, for writing
            out (c), a
            ld hl, bg_cols
@bg_lp:
            ld a, (hl)
            or a
            jr z, bg_done
            ld bc, #243B
            ld e, #40
            out (c), e
            inc b
            out (c), a              ; the index
            dec b
            ld e, #41
            out (c), e
            inc b
            out (c), a              ; its colour: itself
            inc hl
            jr bg_lp
@bg_done:
            ld bc, #243B
            ld a, #43
            out (c), a
            inc b
            ld a, (bg_43)
            out (c), a
            ld sp, ({hsp})
            jp bg_end
@bg_43:      db 0
@bg_cols:    db #2F, #53, #FF, 0
@bg_pat:
            db #E3, #E3, #E3, #E3, #E3, #2F, #2F, #2F, #2F, #2F, #2F, #E3, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #2F, #2F, #2F, #2F, #2F, #2F, #2F, #2F, #E3, #E3, #E3, #E3
            db #E3, #E3, #2F, #2F, #2F, #2F, #53, #53, #53, #53, #2F, #2F, #2F, #2F, #E3, #E3
            db #E3, #E3, #2F, #2F, #53, #FF, #FF, #53, #53, #53, #53, #53, #2F, #2F, #E3, #E3
            db #E3, #2F, #2F, #53, #FF, #FF, #FF, #FF, #53, #53, #53, #53, #53, #2F, #2F, #E3
            db #2F, #2F, #2F, #53, #FF, #FF, #FF, #FF, #53, #53, #53, #53, #53, #2F, #2F, #2F
            db #2F, #2F, #53, #53, #53, #FF, #FF, #53, #53, #53, #53, #53, #53, #53, #2F, #2F
            db #2F, #2F, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #2F, #2F
            db #2F, #2F, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #2F, #2F
            db #2F, #2F, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #2F, #2F
            db #2F, #2F, #2F, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #2F, #2F, #2F
            db #E3, #2F, #2F, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #2F, #2F, #E3
            db #E3, #E3, #2F, #2F, #53, #53, #53, #53, #53, #53, #53, #53, #2F, #2F, #E3, #E3
            db #E3, #E3, #2F, #2F, #2F, #2F, #53, #53, #53, #53, #2F, #2F, #2F, #2F, #E3, #E3
            db #E3, #E3, #E3, #E3, #2F, #2F, #2F, #2F, #2F, #2F, #2F, #2F, #E3, #E3, #E3, #E3
            db #E3, #E3, #E3, #E3, #E3, #2F, #2F, #2F, #2F, #2F, #2F, #E3, #E3, #E3, #E3, #E3
@bg_end:
#endasm
End Sub

Public Sub CpcInstall()
#asm
            ld hl, cb_src
            ld de, #E200
            ld bc, cb_after - cb_src
            ldir
            jp cb_end
@cb_src:
            DISP #E200              ; assembled for #E200, where it runs
@cb_draw:                ; HL = the top left byte (border included), in the #4000 window
            ld bc, (cs_win)         ; the back screen into #4000-#7FFF (C1 or C3)
            out (c), c
            ld bc, #FF00            ; B = all ink, C = all paper (the commonest bytes)
            ld d, h                 ; line 0
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 1
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 2
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 3
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 4
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #3F
            inc hl
            ld (hl), #FC
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 5
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 6
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #0F
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), #F0
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 7
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #0F
            inc hl
            ld (hl), #C3
            inc hl
            ld (hl), b
            inc hl
            ld (hl), #F0
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 8
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #3F
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), #FC
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 9
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 10
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), #C3
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 11
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 12
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 13
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 14
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 15
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #3F
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), #FC
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 16
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #0F
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), #F0
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 17
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #0F
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), #F0
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 18
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), b
            inc hl
            ld (hl), b
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 19
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), #3F
            inc hl
            ld (hl), #FC
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 20
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 21
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 22
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld a, h
            add a, 8
            ld h, a
            and #38
            jr nz, $ + 10
            ld a, l
            add a, #50
            ld l, a
            ld a, h
            adc a, #C0
            ld h, a
            ld d, h                 ; line 23
            ld e, l
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            inc hl
            ld (hl), c
            ex de, hl
            ld bc, (cs_own)         ; the slot's own bank back (C2)
            out (c), c
            ret
            ENT
@cb_after:
            ASSERT #E200 + (cb_after - cb_src) <= #EF00, "the compiled ball must end below the stub (#EF00)"
@cb_end:
#endasm
End Sub
