' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_RSUB = 0
Public Const S_RSUB_N = 2
Public Const S_ASUB = 2
Public Const S_ASUB_N = 2
Public Const S_TORP = 4
Public Const S_TORP_N = 2
Public Const S_FISH = 6
Public Const S_FISH_N = 2
Public Const S_BLAST = 8
Public Const S_BLAST_N = 3
Public Const S_SIGHT = 11
Public Const S_SIGHT_N = 1
Public Const S_ME = 12
Public Const S_ME_N = 1
Public Const S_RDOT = 13
Public Const S_RDOT_N = 1
Public Const S_ADOT = 14
Public Const S_ADOT_N = 1
Public Const S_TDOT = 15
Public Const S_TDOT_N = 1
Public Const S_GOAL = 16
Public Const S_GOAL_N = 1
Public Const T_BLACK = 1
Public Const T_PANEL = 2
Public Const T_PANELT = 3
Public Const T_SQL = 4
Public Const T_SQD = 5
Public Const T_ROCKL = 6
Public Const T_ROCKD = 7
Public Const T_CREW = 8
Public Const T_CREWX = 9
Public Const T_BAR = 16
Public Const T_BAR_N = 9
Public Const T_TORP = 25
Public Const T_TUBE = 26
Public Const SpritePatterns = 17
Public Const SpritePalettes = 1

Private sps As Integer

Public Sub Load()
#asm
            ld ({sps}), sp          ; the real stack (calls)
            ld sp, (ntc_csp)
            ld bc, #243B
            ld a, #43               ; palette control: the tilemap's first palette
            out (c), a
            inc b
            ld a, #30
            out (c), a
            dec b
            ld hl, tpal
            ld e, 16
            call palset
            ld a, #43               ; the sprites' first palette
            out (c), a
            inc b
            ld a, #20
            out (c), a
            dec b
            ld hl, spal
            ld e, 16                ; 1 x 16 (0 = 256)
            call palset
            ld a, #43               ; back to the ULA's, first palettes in use
            out (c), a
            inc b
            xor a
            out (c), a
            ld hl, #C000            ; every tile transparent (colour 15) first
            ld de, #C001
            ld bc, #1FFF
            ld (hl), #FF
            ldir
            ld hl, truns
ld_run:
            ld a, (hl)              ; a run: first tile, count (0, 0 = the end), its definitions
            inc hl
            ld c, (hl)
            inc hl
            ld b, a
            or c
            jr z, ld_spr
            ld a, b
            ld e, a                 ; DE = #C000 + first * 32
            ld d, 0
            ex de, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld a, h
            add a, #C0
            ld h, a
            ex de, hl
            ld a, c                 ; BC = count * 32 (count 1 - 255: tile 0 run of 0 not used)
            ld b, 0
            ld c, a
            push hl
            ld h, b
            ld l, c
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld b, h
            ld c, l
            pop hl
            ldir
            jr ld_run
ld_spr:
            ld bc, #303B            ; sprite patterns from pattern 0
            xor a
            out (c), a
            ld hl, pats
            ld de, 2176
            ld c, #5B
ld_pat:
            ld a, d
            or e
            jr z, ld_done
            ld a, (hl)
            out (c), a
            inc hl
            dec de
            jr ld_pat
ld_done:
            ld sp, ({sps})
            jp ld_end
; palset - E colours (0 = 256) from HL into the palette chosen, from index 0 (BC = #243B)
palset:
            ld a, #40
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
ps_lp:
            ld a, #41
            out (c), a
            inc b
            ld a, (hl)
            out (c), a
            dec b
            inc hl
            dec e
            jr nz, ps_lp
            ret
tpal:
            db #00, #FF, #05, #2E, #FC, #E4, #01, #2B, #5B, #F0, #92, #49, #7E, #05, #BF, #E3
spal:
            db #00, #FF, #E4, #60, #2F, #06, #92, #49, #FC, #F0, #79, #BF, #1B, #DB, #A9, #E3
truns:
            db 1, 9        ; tiles 1-9
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #77, #77, #77, #77, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #3A, #A3, #3A, #A3, #AB, #BA, #AB, #BA, #AB, #BB, #BB, #BA, #3A, #BB, #BB, #A3
            db #3A, #BB, #BB, #A3, #AB, #BB, #BB, #BA, #AB, #BA, #AB, #BA, #3A, #A3, #3A, #A3
            db #2A, #A2, #2A, #A2, #AB, #BA, #AB, #BA, #AB, #BB, #BB, #BA, #2A, #BB, #BB, #A2
            db #2A, #BB, #BB, #A2, #AB, #BB, #BB, #BA, #AB, #BA, #AB, #BA, #2A, #A2, #2A, #A2
            db #FF, #44, #44, #FF, #F4, #44, #44, #4F, #F4, #40, #04, #4F, #FF, #44, #44, #FF
            db #FF, #F4, #4F, #FF, #F4, #44, #44, #4F, #44, #44, #44, #44, #44, #F4, #4F, #44
            db #FF, #BB, #BB, #FF, #FB, #BB, #BB, #BF, #FB, #B0, #0B, #BF, #FF, #BB, #BB, #FF
            db #FF, #FB, #BF, #FF, #FB, #BB, #BB, #BF, #BB, #BB, #BB, #BB, #BB, #FB, #BF, #BB
            db 16, 11        ; tiles 16-26
            db #66, #66, #66, #66, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #82, #22, #22, #22, #82, #22, #22, #22, #82, #22, #22, #22
            db #82, #22, #22, #22, #82, #22, #22, #22, #82, #22, #22, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #88, #22, #22, #22, #88, #22, #22, #22, #88, #22, #22, #22
            db #88, #22, #22, #22, #88, #22, #22, #22, #88, #22, #22, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #88, #82, #22, #22, #88, #82, #22, #22, #88, #82, #22, #22
            db #88, #82, #22, #22, #88, #82, #22, #22, #88, #82, #22, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #88, #88, #22, #22, #88, #88, #22, #22, #88, #88, #22, #22
            db #88, #88, #22, #22, #88, #88, #22, #22, #88, #88, #22, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #88, #88, #82, #22, #88, #88, #82, #22, #88, #88, #82, #22
            db #88, #88, #82, #22, #88, #88, #82, #22, #88, #88, #82, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #88, #88, #88, #22, #88, #88, #88, #22, #88, #88, #88, #22
            db #88, #88, #88, #22, #88, #88, #88, #22, #88, #88, #88, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #88, #88, #88, #82, #88, #88, #88, #82, #88, #88, #88, #82
            db #88, #88, #88, #82, #88, #88, #88, #82, #88, #88, #88, #82, #66, #66, #66, #66
            db #66, #66, #66, #66, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88
            db #88, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #61, #11, #11, #96
            db #AA, #AA, #AA, #A6, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #6B, #BB, #BB, #B6
            db #6B, #66, #66, #B6, #6B, #BB, #BB, #B6, #66, #66, #66, #66, #66, #66, #66, #66
            db 32, 95        ; tiles 32-126
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #6E, #E6, #66, #66, #EE, #EE, #66, #66, #EE, #EE, #26, #66, #6E, #E2, #26
            db #66, #6E, #E2, #66, #66, #66, #22, #66, #66, #6E, #E6, #66, #66, #66, #22, #66
            db #6E, #E6, #EE, #66, #6E, #E2, #EE, #26, #66, #22, #62, #26, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #6E, #E6, #EE, #66, #6E, #E2, #EE, #26, #EE, #EE, #EE, #E6, #6E, #E2, #EE, #22
            db #EE, #EE, #EE, #E6, #6E, #E2, #EE, #22, #6E, #E2, #EE, #26, #66, #22, #62, #26
            db #66, #EE, #66, #66, #6E, #EE, #EE, #66, #EE, #22, #22, #26, #6E, #EE, #E6, #66
            db #66, #22, #EE, #66, #EE, #EE, #E2, #26, #62, #EE, #22, #66, #66, #62, #26, #66
            db #66, #66, #66, #66, #EE, #66, #6E, #E6, #EE, #26, #EE, #22, #62, #2E, #E2, #26
            db #66, #EE, #22, #66, #6E, #E2, #2E, #E6, #EE, #22, #6E, #E2, #62, #26, #66, #22
            db #66, #EE, #E6, #66, #6E, #E2, #EE, #66, #66, #EE, #E2, #26, #6E, #EE, #2E, #E6
            db #EE, #2E, #EE, #22, #EE, #26, #EE, #26, #6E, #EE, #6E, #E6, #66, #22, #26, #22
            db #6E, #E6, #66, #66, #6E, #E2, #66, #66, #EE, #22, #66, #66, #62, #26, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #6E, #E6, #66, #66, #EE, #22, #66, #6E, #E2, #26, #66, #6E, #E2, #66, #66
            db #6E, #E2, #66, #66, #66, #EE, #66, #66, #66, #6E, #E6, #66, #66, #66, #22, #66
            db #6E, #E6, #66, #66, #66, #EE, #66, #66, #66, #6E, #E6, #66, #66, #6E, #E2, #66
            db #66, #6E, #E2, #66, #66, #EE, #22, #66, #6E, #E2, #26, #66, #66, #22, #66, #66
            db #66, #66, #66, #66, #6E, #E6, #6E, #E6, #66, #EE, #EE, #22, #EE, #EE, #EE, #EE
            db #62, #EE, #EE, #22, #6E, #E2, #2E, #E6, #66, #22, #66, #22, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #EE, #66, #66, #66, #EE, #26, #66, #EE, #EE, #EE, #66
            db #62, #EE, #22, #26, #66, #EE, #26, #66, #66, #62, #26, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #EE, #66, #66, #66, #EE, #26, #66, #6E, #E2, #26, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #EE, #EE, #EE, #66
            db #62, #22, #22, #26, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #EE, #66, #66, #66, #EE, #26, #66, #66, #62, #26, #66
            db #66, #66, #6E, #E6, #66, #66, #EE, #22, #66, #6E, #E2, #26, #66, #EE, #22, #66
            db #6E, #E2, #26, #66, #EE, #22, #66, #66, #E2, #26, #66, #66, #62, #66, #66, #66
            db #6E, #EE, #EE, #66, #EE, #22, #2E, #E6, #EE, #26, #EE, #E2, #EE, #2E, #EE, #E2
            db #EE, #EE, #2E, #E2, #EE, #E2, #2E, #E2, #6E, #EE, #EE, #22, #66, #22, #22, #26
            db #66, #EE, #66, #66, #6E, #EE, #26, #66, #66, #EE, #26, #66, #66, #EE, #26, #66
            db #66, #EE, #26, #66, #66, #EE, #26, #66, #EE, #EE, #EE, #66, #62, #22, #22, #26
            db #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #62, #26, #EE, #26, #66, #EE, #E2, #26
            db #6E, #E2, #22, #66, #EE, #22, #EE, #66, #EE, #EE, #EE, #26, #62, #22, #22, #26
            db #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #62, #26, #EE, #26, #66, #EE, #E2, #26
            db #66, #62, #EE, #66, #EE, #66, #EE, #26, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #66, #6E, #EE, #66, #66, #EE, #EE, #26, #6E, #E2, #EE, #26, #EE, #22, #EE, #26
            db #EE, #EE, #EE, #E6, #62, #22, #EE, #22, #66, #6E, #EE, #E6, #66, #66, #22, #22
            db #EE, #EE, #EE, #66, #EE, #22, #22, #26, #EE, #EE, #E6, #66, #62, #22, #EE, #66
            db #66, #66, #EE, #26, #EE, #66, #EE, #26, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #66, #EE, #E6, #66, #6E, #E2, #22, #66, #EE, #22, #66, #66, #EE, #EE, #E6, #66
            db #EE, #22, #EE, #66, #EE, #26, #EE, #26, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #EE, #EE, #EE, #66, #EE, #22, #EE, #26, #62, #26, #EE, #26, #66, #6E, #E2, #26
            db #66, #EE, #22, #66, #66, #EE, #26, #66, #66, #EE, #26, #66, #66, #62, #26, #66
            db #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #EE, #26, #EE, #26, #6E, #EE, #E2, #26
            db #EE, #22, #EE, #66, #EE, #26, #EE, #26, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #EE, #26, #EE, #26, #6E, #EE, #EE, #26
            db #66, #22, #EE, #26, #66, #6E, #E2, #26, #6E, #EE, #22, #66, #66, #22, #26, #66
            db #66, #66, #66, #66, #66, #EE, #66, #66, #66, #EE, #26, #66, #66, #62, #26, #66
            db #66, #66, #66, #66, #66, #EE, #66, #66, #66, #EE, #26, #66, #66, #62, #26, #66
            db #66, #66, #66, #66, #66, #EE, #66, #66, #66, #EE, #26, #66, #66, #62, #26, #66
            db #66, #66, #66, #66, #66, #EE, #66, #66, #66, #EE, #26, #66, #6E, #E2, #26, #66
            db #66, #6E, #E6, #66, #66, #EE, #22, #66, #6E, #E2, #26, #66, #EE, #22, #66, #66
            db #6E, #E6, #66, #66, #66, #EE, #66, #66, #66, #6E, #E6, #66, #66, #66, #22, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #EE, #EE, #66, #62, #22, #22, #26
            db #66, #66, #66, #66, #EE, #EE, #EE, #66, #62, #22, #22, #26, #66, #66, #66, #66
            db #6E, #E6, #66, #66, #66, #EE, #66, #66, #66, #6E, #E6, #66, #66, #66, #EE, #66
            db #66, #6E, #E2, #26, #66, #EE, #22, #66, #6E, #E2, #26, #66, #66, #22, #66, #66
            db #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #62, #26, #EE, #26, #66, #6E, #E2, #26
            db #66, #EE, #22, #66, #66, #62, #26, #66, #66, #EE, #66, #66, #66, #62, #26, #66
            db #6E, #EE, #EE, #66, #EE, #22, #2E, #E6, #EE, #2E, #EE, #E2, #EE, #2E, #EE, #E2
            db #EE, #2E, #EE, #E2, #EE, #26, #22, #22, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #66, #EE, #66, #66, #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #EE, #26, #EE, #26
            db #EE, #EE, #EE, #26, #EE, #22, #EE, #26, #EE, #26, #EE, #26, #62, #26, #62, #26
            db #EE, #EE, #EE, #66, #6E, #E2, #2E, #E6, #6E, #E2, #6E, #E2, #6E, #EE, #EE, #22
            db #6E, #E2, #2E, #E6, #6E, #E2, #6E, #E2, #EE, #EE, #EE, #22, #62, #22, #22, #26
            db #66, #EE, #EE, #66, #6E, #E2, #2E, #E6, #EE, #22, #66, #22, #EE, #26, #66, #66
            db #EE, #26, #66, #66, #6E, #E6, #6E, #E6, #66, #EE, #EE, #22, #66, #62, #22, #26
            db #EE, #EE, #E6, #66, #6E, #E2, #EE, #66, #6E, #E2, #6E, #E6, #6E, #E2, #6E, #E2
            db #6E, #E2, #6E, #E2, #6E, #E2, #EE, #22, #EE, #EE, #E2, #26, #62, #22, #22, #66
            db #EE, #EE, #EE, #E6, #6E, #E2, #22, #E2, #6E, #E2, #E6, #62, #6E, #EE, #E2, #66
            db #6E, #E2, #E2, #66, #6E, #E2, #62, #E6, #EE, #EE, #EE, #E2, #62, #22, #22, #22
            db #EE, #EE, #EE, #E6, #6E, #E2, #22, #E2, #6E, #E2, #E6, #62, #6E, #EE, #E2, #66
            db #6E, #E2, #E2, #66, #6E, #E2, #62, #66, #EE, #EE, #66, #66, #62, #22, #26, #66
            db #66, #EE, #EE, #66, #6E, #E2, #2E, #E6, #EE, #22, #66, #22, #EE, #26, #66, #66
            db #EE, #26, #EE, #E6, #6E, #E6, #6E, #E2, #66, #EE, #EE, #E2, #66, #62, #22, #22
            db #EE, #66, #EE, #66, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #EE, #EE, #26
            db #EE, #22, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #62, #26, #62, #26
            db #6E, #EE, #E6, #66, #66, #EE, #22, #66, #66, #EE, #26, #66, #66, #EE, #26, #66
            db #66, #EE, #26, #66, #66, #EE, #26, #66, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #66, #6E, #EE, #E6, #66, #66, #EE, #22, #66, #66, #EE, #26, #66, #66, #EE, #26
            db #EE, #66, #EE, #26, #EE, #26, #EE, #26, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #EE, #E6, #6E, #E6, #6E, #E2, #6E, #E2, #6E, #E2, #EE, #22, #6E, #EE, #E2, #26
            db #6E, #E2, #EE, #66, #6E, #E2, #6E, #E6, #EE, #E2, #6E, #E2, #62, #22, #66, #22
            db #EE, #EE, #66, #66, #6E, #E2, #26, #66, #6E, #E2, #66, #66, #6E, #E2, #66, #66
            db #6E, #E2, #66, #E6, #6E, #E2, #6E, #E2, #EE, #EE, #EE, #E2, #62, #22, #22, #22
            db #EE, #66, #6E, #E6, #EE, #E6, #EE, #E2, #EE, #EE, #EE, #E2, #EE, #EE, #EE, #E2
            db #EE, #2E, #2E, #E2, #EE, #26, #2E, #E2, #EE, #26, #6E, #E2, #62, #26, #66, #22
            db #EE, #66, #6E, #E6, #EE, #E6, #6E, #E2, #EE, #EE, #6E, #E2, #EE, #2E, #EE, #E2
            db #EE, #26, #EE, #E2, #EE, #26, #6E, #E2, #EE, #26, #6E, #E2, #62, #26, #66, #22
            db #66, #EE, #E6, #66, #6E, #E2, #EE, #66, #EE, #22, #6E, #E6, #EE, #26, #6E, #E2
            db #EE, #26, #6E, #E2, #6E, #E6, #EE, #22, #66, #EE, #E2, #26, #66, #62, #22, #66
            db #EE, #EE, #EE, #66, #6E, #E2, #2E, #E6, #6E, #E2, #6E, #E2, #6E, #EE, #EE, #22
            db #6E, #E2, #22, #26, #6E, #E2, #66, #66, #EE, #EE, #66, #66, #62, #22, #26, #66
            db #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #EE, #26, #EE, #26, #EE, #26, #EE, #26
            db #EE, #2E, #EE, #26, #6E, #EE, #E2, #26, #66, #2E, #EE, #66, #66, #66, #22, #26
            db #EE, #EE, #EE, #66, #6E, #E2, #2E, #E6, #6E, #E2, #6E, #E2, #6E, #EE, #EE, #22
            db #6E, #E2, #EE, #26, #6E, #E2, #6E, #E6, #EE, #E2, #6E, #E2, #62, #22, #66, #22
            db #6E, #EE, #E6, #66, #EE, #22, #EE, #66, #EE, #E6, #62, #26, #6E, #EE, #66, #66
            db #66, #2E, #EE, #66, #EE, #66, #EE, #26, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #EE, #EE, #EE, #66, #E2, #EE, #2E, #26, #62, #EE, #26, #26, #66, #EE, #26, #66
            db #66, #EE, #26, #66, #66, #EE, #26, #66, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #EE, #66, #EE, #66, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #26
            db #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #EE, #EE, #26, #62, #22, #22, #26
            db #EE, #66, #EE, #66, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #26
            db #EE, #26, #EE, #26, #6E, #EE, #E2, #26, #66, #EE, #22, #66, #66, #62, #26, #66
            db #EE, #66, #6E, #E6, #EE, #26, #6E, #E2, #EE, #26, #6E, #E2, #EE, #2E, #6E, #E2
            db #EE, #EE, #EE, #E2, #EE, #E2, #EE, #E2, #EE, #22, #6E, #E2, #62, #26, #66, #22
            db #EE, #66, #6E, #E6, #EE, #26, #6E, #E2, #6E, #E6, #EE, #22, #66, #EE, #E2, #26
            db #66, #EE, #E2, #66, #6E, #E2, #EE, #66, #EE, #22, #6E, #E6, #62, #26, #66, #22
            db #EE, #66, #EE, #66, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #6E, #EE, #E2, #26
            db #66, #EE, #22, #66, #66, #EE, #26, #66, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #EE, #EE, #EE, #E6, #EE, #22, #2E, #E2, #E2, #26, #EE, #22, #62, #6E, #E2, #26
            db #66, #EE, #22, #E6, #6E, #E2, #2E, #E2, #EE, #EE, #EE, #E2, #62, #22, #22, #22
            db #6E, #EE, #E6, #66, #6E, #E2, #22, #66, #6E, #E2, #66, #66, #6E, #E2, #66, #66
            db #6E, #E2, #66, #66, #6E, #E2, #66, #66, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #EE, #66, #66, #66, #6E, #E6, #66, #66, #66, #EE, #66, #66, #66, #6E, #E6, #66
            db #66, #66, #EE, #66, #66, #66, #6E, #E6, #66, #66, #66, #E2, #66, #66, #66, #62
            db #6E, #EE, #E6, #66, #66, #2E, #E2, #66, #66, #6E, #E2, #66, #66, #6E, #E2, #66
            db #66, #6E, #E2, #66, #66, #6E, #E2, #66, #6E, #EE, #E2, #66, #66, #22, #22, #66
            db #66, #6E, #66, #66, #66, #EE, #E6, #66, #6E, #E2, #EE, #66, #EE, #22, #6E, #E6
            db #62, #26, #66, #22, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #EE, #EE, #EE, #EE
            db #66, #EE, #66, #66, #66, #EE, #26, #66, #66, #6E, #E6, #66, #66, #66, #22, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #6E, #EE, #E6, #66, #66, #22, #EE, #66
            db #6E, #EE, #EE, #26, #EE, #22, #EE, #26, #6E, #EE, #6E, #E6, #66, #22, #26, #22
            db #EE, #E6, #66, #66, #6E, #E2, #66, #66, #6E, #E2, #66, #66, #6E, #EE, #EE, #66
            db #6E, #E2, #2E, #E6, #6E, #E2, #6E, #E2, #EE, #2E, #EE, #22, #62, #26, #22, #26
            db #66, #66, #66, #66, #66, #66, #66, #66, #6E, #EE, #E6, #66, #EE, #22, #EE, #66
            db #EE, #26, #62, #26, #EE, #26, #EE, #66, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #66, #6E, #EE, #66, #66, #66, #EE, #26, #66, #66, #EE, #26, #6E, #EE, #EE, #26
            db #EE, #22, #EE, #26, #EE, #26, #EE, #26, #6E, #EE, #6E, #E6, #66, #22, #26, #22
            db #66, #66, #66, #66, #66, #66, #66, #66, #6E, #EE, #E6, #66, #EE, #22, #EE, #66
            db #EE, #EE, #EE, #26, #EE, #22, #22, #26, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #66, #EE, #E6, #66, #6E, #E2, #EE, #66, #6E, #E2, #62, #26, #EE, #EE, #66, #66
            db #6E, #E2, #26, #66, #6E, #E2, #66, #66, #EE, #EE, #66, #66, #62, #22, #26, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #6E, #EE, #6E, #E6, #EE, #22, #EE, #22
            db #EE, #26, #EE, #26, #6E, #EE, #EE, #26, #66, #22, #EE, #26, #EE, #EE, #E2, #26
            db #EE, #E6, #66, #66, #6E, #E2, #66, #66, #6E, #E2, #EE, #66, #6E, #EE, #6E, #E6
            db #6E, #E2, #2E, #E2, #6E, #E2, #6E, #E2, #EE, #E2, #6E, #E2, #62, #22, #66, #22
            db #66, #EE, #66, #66, #66, #62, #26, #66, #6E, #EE, #66, #66, #66, #EE, #26, #66
            db #66, #EE, #26, #66, #66, #EE, #26, #66, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #66, #66, #EE, #66, #66, #66, #62, #26, #66, #66, #EE, #66, #66, #66, #EE, #26
            db #66, #66, #EE, #26, #EE, #66, #EE, #26, #EE, #26, #EE, #26, #6E, #EE, #E2, #26
            db #EE, #E6, #66, #66, #6E, #E2, #66, #66, #6E, #E2, #6E, #E6, #6E, #E2, #EE, #22
            db #6E, #EE, #E2, #26, #6E, #E2, #EE, #66, #EE, #E2, #6E, #E6, #62, #22, #66, #22
            db #6E, #EE, #66, #66, #66, #EE, #26, #66, #66, #EE, #26, #66, #66, #EE, #26, #66
            db #66, #EE, #26, #66, #66, #EE, #26, #66, #6E, #EE, #E6, #66, #66, #22, #22, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #66, #EE, #66, #EE, #EE, #EE, #E6
            db #EE, #EE, #EE, #E2, #EE, #2E, #2E, #E2, #EE, #26, #2E, #E2, #62, #26, #66, #22
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #EE, #E6, #66, #EE, #22, #EE, #66
            db #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #EE, #26, #62, #26, #62, #26
            db #66, #66, #66, #66, #66, #66, #66, #66, #6E, #EE, #E6, #66, #EE, #22, #EE, #66
            db #EE, #26, #EE, #26, #EE, #26, #EE, #26, #6E, #EE, #E2, #26, #66, #22, #22, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #6E, #EE, #66, #6E, #E6, #2E, #E6
            db #6E, #E2, #6E, #E2, #6E, #EE, #EE, #22, #6E, #E2, #22, #26, #EE, #EE, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #6E, #EE, #6E, #E6, #EE, #22, #EE, #22
            db #EE, #26, #EE, #26, #6E, #EE, #EE, #26, #66, #22, #EE, #26, #66, #6E, #EE, #E6
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #6E, #EE, #66, #6E, #EE, #2E, #E6
            db #6E, #E2, #2E, #E2, #6E, #E2, #66, #22, #EE, #EE, #66, #66, #62, #22, #26, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #6E, #EE, #EE, #66, #EE, #22, #22, #26
            db #6E, #EE, #E6, #66, #66, #22, #EE, #66, #EE, #EE, #E2, #26, #62, #22, #22, #66
            db #66, #6E, #66, #66, #66, #EE, #26, #66, #6E, #EE, #EE, #66, #66, #EE, #22, #26
            db #66, #EE, #26, #66, #66, #EE, #2E, #66, #66, #6E, #E6, #26, #66, #66, #22, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #66, #EE, #66, #EE, #26, #EE, #26
            db #EE, #26, #EE, #26, #EE, #26, #EE, #26, #6E, #EE, #6E, #E6, #66, #22, #26, #22
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #66, #EE, #66, #EE, #26, #EE, #26
            db #EE, #26, #EE, #26, #6E, #EE, #E2, #26, #66, #EE, #22, #66, #66, #62, #26, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #66, #6E, #E6, #EE, #2E, #6E, #E2
            db #EE, #EE, #EE, #E2, #EE, #EE, #EE, #E2, #6E, #E2, #EE, #22, #66, #22, #62, #26
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #66, #6E, #E6, #6E, #E6, #EE, #22
            db #66, #EE, #E2, #26, #6E, #E2, #EE, #66, #EE, #22, #6E, #E6, #62, #26, #66, #22
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #66, #EE, #66, #EE, #26, #EE, #26
            db #EE, #26, #EE, #26, #6E, #EE, #EE, #26, #66, #22, #EE, #26, #EE, #EE, #E2, #26
            db #66, #66, #66, #66, #66, #66, #66, #66, #EE, #EE, #EE, #66, #E2, #2E, #E2, #26
            db #62, #EE, #22, #66, #6E, #E2, #2E, #66, #EE, #EE, #EE, #26, #62, #22, #22, #26
            db #66, #6E, #EE, #66, #66, #EE, #22, #26, #66, #EE, #26, #66, #EE, #E2, #26, #66
            db #62, #EE, #66, #66, #66, #EE, #26, #66, #66, #6E, #EE, #66, #66, #66, #22, #26
            db #66, #6E, #E6, #66, #66, #6E, #E2, #66, #66, #6E, #E2, #66, #66, #66, #22, #66
            db #66, #6E, #E6, #66, #66, #6E, #E2, #66, #66, #6E, #E2, #66, #66, #66, #22, #66
            db #EE, #E6, #66, #66, #62, #EE, #66, #66, #66, #EE, #26, #66, #66, #6E, #EE, #66
            db #66, #EE, #22, #26, #66, #EE, #26, #66, #EE, #E2, #26, #66, #62, #22, #66, #66
            db #6E, #EE, #6E, #E6, #EE, #2E, #EE, #22, #62, #26, #22, #26, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db 0, 0
pats:
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #03, #30, #FF, #FF, #FF, #FF, #FF, #FF, #03, #30, #FF, #FF, #FF
            db #FF, #F0, #00, #33, #33, #00, #0F, #FF, #F0, #03, #33, #33, #33, #33, #30, #0F
            db #03, #33, #33, #33, #33, #33, #33, #30, #03, #22, #22, #22, #22, #22, #23, #00
            db #03, #33, #33, #33, #33, #33, #33, #30, #F0, #03, #33, #33, #33, #33, #30, #F0
            db #FF, #F0, #00, #00, #00, #00, #FF, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #03, #30, #FF, #FF, #FF, #FF, #FF, #FF, #03, #30, #FF, #FF, #FF
            db #FF, #FF, #F0, #33, #33, #0F, #FF, #FF, #FF, #FF, #03, #33, #33, #30, #FF, #FF
            db #FF, #F0, #33, #33, #33, #33, #0F, #FF, #FF, #00, #33, #33, #33, #33, #00, #FF
            db #FF, #F0, #33, #33, #33, #33, #0F, #FF, #FF, #FF, #03, #33, #33, #30, #FF, #FF
            db #FF, #FF, #F0, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #05, #50, #FF, #FF, #FF, #FF, #FF, #FF, #05, #50, #FF, #FF, #FF
            db #FF, #F0, #00, #55, #55, #00, #0F, #FF, #F0, #05, #55, #55, #55, #55, #50, #0F
            db #05, #55, #55, #55, #55, #55, #55, #50, #05, #44, #44, #44, #44, #44, #45, #00
            db #05, #55, #55, #55, #55, #55, #55, #50, #F0, #05, #55, #55, #55, #55, #50, #F0
            db #FF, #F0, #00, #00, #00, #00, #FF, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #05, #50, #FF, #FF, #FF, #FF, #FF, #FF, #05, #50, #FF, #FF, #FF
            db #FF, #FF, #F0, #55, #55, #0F, #FF, #FF, #FF, #FF, #05, #55, #55, #50, #FF, #FF
            db #FF, #F0, #55, #55, #55, #55, #0F, #FF, #FF, #00, #55, #55, #55, #55, #00, #FF
            db #FF, #F0, #55, #55, #55, #55, #0F, #FF, #FF, #FF, #05, #55, #55, #50, #FF, #FF
            db #FF, #FF, #F0, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #BF, #BF, #FF, #FF, #FF, #FF, #FF, #FB, #FB, #FD, #DD, #DD, #DD, #DD, #9F
            db #FF, #BF, #66, #66, #66, #66, #66, #6F, #FF, #FB, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #BB, #BB, #FF, #FF, #FF, #FF, #FF, #FB, #FF, #FF, #BF, #FF, #FF
            db #FF, #FF, #BF, #FD, #DF, #FB, #FF, #FF, #FF, #FF, #BF, #D9, #9D, #FB, #FF, #FF
            db #FF, #FF, #BF, #D9, #9D, #FB, #FF, #FF, #FF, #FF, #BF, #FD, #DF, #FB, #FF, #FF
            db #FF, #FF, #FB, #FF, #FF, #BF, #FF, #FF, #FF, #FF, #FF, #BB, #BB, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #88, #FF, #FF, #FF
            db #FF, #8F, #FF, #88, #88, #8F, #FF, #FF, #FF, #88, #F8, #88, #88, #88, #FF, #FF
            db #FF, #F8, #88, #88, #80, #88, #8F, #FF, #FF, #88, #F8, #88, #88, #88, #FF, #FF
            db #FF, #8F, #FF, #88, #88, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #88, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #88, #FF, #FF, #FF
            db #FF, #FF, #FF, #88, #88, #8F, #FF, #FF, #88, #FF, #F8, #88, #88, #88, #FF, #FF
            db #F8, #88, #88, #88, #80, #88, #8F, #FF, #88, #FF, #F8, #88, #88, #88, #FF, #FF
            db #FF, #FF, #FF, #88, #88, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #88, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #98, #89, #FF, #FF, #FF
            db #FF, #FF, #F9, #88, #88, #9F, #FF, #FF, #FF, #FF, #F8, #81, #18, #8F, #FF, #FF
            db #FF, #FF, #F8, #81, #18, #8F, #FF, #FF, #FF, #FF, #F9, #88, #88, #9F, #FF, #FF
            db #FF, #FF, #FF, #98, #89, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F9, #F9, #9F, #9F, #FF, #FF, #FF, #F9, #99, #88, #88, #99, #9F, #FF
            db #FF, #F9, #88, #81, #18, #88, #9F, #FF, #FF, #99, #88, #11, #11, #88, #99, #FF
            db #FF, #98, #81, #11, #11, #18, #89, #FF, #FF, #98, #81, #11, #11, #18, #89, #FF
            db #FF, #99, #88, #11, #11, #88, #99, #FF, #FF, #F9, #88, #81, #18, #88, #9F, #FF
            db #FF, #F9, #99, #88, #88, #99, #9F, #FF, #FF, #FF, #F9, #F9, #9F, #9F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #BF, #FF, #FF, #FB, #FF, #FF, #FB, #FF, #FF, #FB, #FF, #FF, #FB, #FF
            db #FF, #FB, #FF, #FF, #FF, #FF, #FF, #FB, #BF, #FF, #FF, #BF, #FB, #FF, #FF, #FF
            db #FF, #FB, #FF, #FF, #FF, #FF, #FB, #FF, #FF, #FF, #FF, #FB, #FF, #FB, #FF, #FF
            db #BF, #FB, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FB, #FF, #BF, #FF, #BF
            db #FF, #BF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FB, #FF, #FF, #BF, #FB, #FF
            db #BF, #FF, #FF, #FF, #FF, #BF, #FF, #FF, #FF, #FB, #FF, #BF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FB, #FF, #FF, #FF, #BF, #FB, #FF, #FF, #FF, #FF, #FF, #BF, #FF
            db #FF, #FF, #FB, #FF, #BF, #FF, #FF, #FF, #FF, #BF, #FF, #FF, #FF, #FF, #BF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FC, #CC, #FF, #FF, #FF, #FC, #CC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #FF, #FF, #FF
            db #FF, #FF, #FF, #10, #10, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #FF, #FF, #FF
            db #FF, #FF, #FF, #1F, #11, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F2, #2F, #FF, #FF, #FF
            db #FF, #FF, #FF, #22, #22, #FF, #FF, #FF, #FF, #FF, #FF, #F2, #2F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #4F, #FF, #FF, #FF
            db #FF, #FF, #FF, #44, #44, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #4F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F8, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FA, #FF, #FF, #FF
            db #FF, #FF, #FF, #AF, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #AF, #AF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FA, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ld_end:
#endasm
End Sub
