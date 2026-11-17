' Pals - the tilemap's palette for each stage (made by tools/art.py: don't edit). Set n puts stage n's colours in
' the tilemap's first palette (colours 1-4 are the font's, 5-14 the terrain, 15 see-through).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Public Sub Set(n As Integer)
#asm
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld de, pl_tab
            add hl, de
            ld bc, #243B
            ld a, #43
            out (c), a
            inc b
            ld a, #30
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
            ld e, 16
pl_lp:
            ld a, (hl)
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, pl_lp
            dec b
            ld a, #43
            out (c), a
            inc b
            xor a
            out (c), a
            jp pl_end
pl_tab:
            db #00,#00,#FF,#01,#DB,#01,#92,#01,#25,#00,#25,#00,#29,#01,#4E,#00,#24,#01,#8B,#00,#46,#00,#00,#01,#B7,#01,#7B,#01,#BB,#01,#E3,#01
            db #00,#00,#FF,#01,#DB,#01,#92,#01,#25,#00,#44,#01,#64,#01,#88,#01,#20,#00,#EC,#01,#A8,#01,#20,#00,#F5,#01,#FE,#00,#FA,#00,#E3,#01
            db #00,#00,#FF,#01,#DB,#01,#92,#01,#25,#00,#05,#00,#29,#00,#31,#01,#04,#01,#EE,#00,#A9,#01,#04,#01,#9F,#00,#BF,#01,#BF,#01,#E3,#01
pl_end:
#endasm
End Sub
