' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_RIGHT = 0
Public Const S_RIGHT_N = 3
Public Const S_UP = 3
Public Const S_UP_N = 3
Public Const S_SENTRY = 6
Public Const S_SENTRY_N = 2
Public Const S_SCARED = 8
Public Const S_SCARED_N = 2
Public Const S_EYES = 10
Public Const S_EYES_N = 4
Public Const S_BONUS = 14
Public Const S_BONUS_N = 4
Public Const S_PTS = 18
Public Const S_PTS_N = 4
Public Const S_DIE = 22
Public Const S_DIE_N = 6
Public Const T_DOT = 1
Public Const T_POWER = 2
Public Const T_POWER_N = 2
Public Const T_DOOR = 4
Public Const T_LIFE = 5
Public Const T_WALL = 16
Public Const T_WALL_N = 16
Public Const T_LOGO = 128
Public Const T_LOGO_N = 3
Public Const SpritePatterns = 28
Public Const SpritePalettes = 5

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
            ld e, 80                ; 5 x 16 (0 = 256)
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
            ld de, 3584
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
            db #00, #FF, #2F, #06, #FA, #FD, #EF, #FC, #1B, #E4, #5D, #93, #F0, #4A, #AB, #E3
spal:
            db #00, #FF, #E4, #80, #5D, #11, #03, #2B, #BB, #93, #1B, #FC, #EC, #F3, #4A, #E3
            db #00, #FF, #F3, #86, #5D, #11, #03, #2B, #BB, #93, #1B, #FC, #EC, #F3, #4A, #E3
            db #00, #FF, #1B, #0E, #5D, #11, #03, #2B, #BB, #93, #1B, #FC, #EC, #F3, #4A, #E3
            db #00, #FF, #F0, #88, #5D, #11, #03, #2B, #BB, #93, #1B, #FC, #EC, #F3, #4A, #E3
            db #00, #FF, #E4, #80, #5D, #11, #03, #FF, #E4, #93, #1B, #FC, #EC, #F3, #4A, #E3
truns:
            db 1, 5        ; tiles 1-5
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #4F, #FF
            db #FF, #F4, #4F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #55, #55, #FF, #F5, #77, #77, #5F, #55, #71, #17, #55, #57, #17, #77, #75
            db #57, #77, #77, #75, #55, #77, #77, #55, #F5, #77, #77, #5F, #FF, #55, #55, #FF
            db #FF, #FF, #FF, #FF, #FF, #55, #55, #FF, #F5, #55, #55, #5F, #F5, #57, #75, #5F
            db #F5, #55, #55, #5F, #F5, #55, #55, #5F, #FF, #55, #55, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #66, #66, #66
            db #66, #66, #66, #66, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FA, #FF, #FA, #FF, #FF, #AA, #AF, #FF, #FA, #8A, #AA, #FF
            db #AA, #A8, #AA, #AF, #FA, #8A, #AA, #FF, #FF, #AA, #AF, #FF, #FA, #FF, #FA, #FF
            db 16, 16        ; tiles 16-31
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #33, #FF, #32, #22, #22
            db #FF, #32, #22, #22, #FF, #33, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #33, #FF, #32, #22, #22
            db #FF, #32, #22, #22, #FF, #33, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #33, #FF, #32, #22, #22
            db #FF, #32, #22, #22, #FF, #32, #23, #33, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #33, #FF, #32, #22, #22
            db #FF, #32, #22, #22, #FF, #32, #23, #33, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #33, #FF, #22, #22, #23, #FF
            db #22, #22, #23, #FF, #33, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #33, #32, #23, #FF, #22, #22, #23, #FF
            db #22, #22, #23, #FF, #33, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #33, #33, #22, #22, #22, #22
            db #22, #22, #22, #22, #33, #33, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #33, #32, #23, #33, #22, #22, #22, #22
            db #22, #22, #22, #22, #33, #33, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #33, #FF, #22, #22, #23, #FF
            db #22, #22, #23, #FF, #33, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #33, #32, #23, #FF, #22, #22, #23, #FF
            db #22, #22, #23, #FF, #33, #32, #23, #FF, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #33, #33, #22, #22, #22, #22
            db #22, #22, #22, #22, #33, #32, #23, #33, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db #FF, #32, #23, #FF, #FF, #32, #23, #FF, #33, #32, #23, #33, #22, #22, #22, #22
            db #22, #22, #22, #22, #33, #32, #23, #33, #FF, #32, #23, #FF, #FF, #32, #23, #FF
            db 33, 94        ; tiles 33-126
            db #FF, #F1, #1F, #FF, #FF, #11, #11, #FF, #FF, #11, #11, #DF, #FF, #F1, #1D, #DF
            db #FF, #F1, #1D, #FF, #FF, #FF, #DD, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #DD, #FF
            db #F1, #1F, #11, #FF, #F1, #1D, #11, #DF, #FF, #DD, #FD, #DF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #F1, #1F, #11, #FF, #F1, #1D, #11, #DF, #11, #11, #11, #1F, #F1, #1D, #11, #DD
            db #11, #11, #11, #1F, #F1, #1D, #11, #DD, #F1, #1D, #11, #DF, #FF, #DD, #FD, #DF
            db #FF, #11, #FF, #FF, #F1, #11, #11, #FF, #11, #DD, #DD, #DF, #F1, #11, #1F, #FF
            db #FF, #DD, #11, #FF, #11, #11, #1D, #DF, #FD, #11, #DD, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #11, #FF, #F1, #1F, #11, #DF, #11, #DD, #FD, #D1, #1D, #DF
            db #FF, #11, #DD, #FF, #F1, #1D, #D1, #1F, #11, #DD, #F1, #1D, #FD, #DF, #FF, #DD
            db #FF, #11, #1F, #FF, #F1, #1D, #11, #FF, #FF, #11, #1D, #DF, #F1, #11, #D1, #1F
            db #11, #D1, #11, #DD, #11, #DF, #11, #DF, #F1, #11, #F1, #1F, #FF, #DD, #DF, #DD
            db #F1, #1F, #FF, #FF, #F1, #1D, #FF, #FF, #11, #DD, #FF, #FF, #FD, #DF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F1, #1F, #FF, #FF, #11, #DD, #FF, #F1, #1D, #DF, #FF, #F1, #1D, #FF, #FF
            db #F1, #1D, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #DD, #FF
            db #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #F1, #1D, #FF
            db #FF, #F1, #1D, #FF, #FF, #11, #DD, #FF, #F1, #1D, #DF, #FF, #FF, #DD, #FF, #FF
            db #FF, #FF, #FF, #FF, #F1, #1F, #F1, #1F, #FF, #11, #11, #DD, #11, #11, #11, #11
            db #FD, #11, #11, #DD, #F1, #1D, #D1, #1F, #FF, #DD, #FF, #DD, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #11, #11, #11, #FF
            db #FD, #11, #DD, #DF, #FF, #11, #DF, #FF, #FF, #FD, #DF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #F1, #1D, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #FF
            db #FD, #DD, #DD, #DF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #F1, #1F, #FF, #FF, #11, #DD, #FF, #F1, #1D, #DF, #FF, #11, #DD, #FF
            db #F1, #1D, #DF, #FF, #11, #DD, #FF, #FF, #1D, #DF, #FF, #FF, #FD, #FF, #FF, #FF
            db #F1, #11, #11, #FF, #11, #DD, #D1, #1F, #11, #DF, #11, #1D, #11, #D1, #11, #1D
            db #11, #11, #D1, #1D, #11, #1D, #D1, #1D, #F1, #11, #11, #DD, #FF, #DD, #DD, #DF
            db #FF, #11, #FF, #FF, #F1, #11, #DF, #FF, #FF, #11, #DF, #FF, #FF, #11, #DF, #FF
            db #FF, #11, #DF, #FF, #FF, #11, #DF, #FF, #11, #11, #11, #FF, #FD, #DD, #DD, #DF
            db #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #FD, #DF, #11, #DF, #FF, #11, #1D, #DF
            db #F1, #1D, #DD, #FF, #11, #DD, #11, #FF, #11, #11, #11, #DF, #FD, #DD, #DD, #DF
            db #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #FD, #DF, #11, #DF, #FF, #11, #1D, #DF
            db #FF, #FD, #11, #FF, #11, #FF, #11, #DF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #FF, #F1, #11, #FF, #FF, #11, #11, #DF, #F1, #1D, #11, #DF, #11, #DD, #11, #DF
            db #11, #11, #11, #1F, #FD, #DD, #11, #DD, #FF, #F1, #11, #1F, #FF, #FF, #DD, #DD
            db #11, #11, #11, #FF, #11, #DD, #DD, #DF, #11, #11, #1F, #FF, #FD, #DD, #11, #FF
            db #FF, #FF, #11, #DF, #11, #FF, #11, #DF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #FF, #11, #1F, #FF, #F1, #1D, #DD, #FF, #11, #DD, #FF, #FF, #11, #11, #1F, #FF
            db #11, #DD, #11, #FF, #11, #DF, #11, #DF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #11, #11, #11, #FF, #11, #DD, #11, #DF, #FD, #DF, #11, #DF, #FF, #F1, #1D, #DF
            db #FF, #11, #DD, #FF, #FF, #11, #DF, #FF, #FF, #11, #DF, #FF, #FF, #FD, #DF, #FF
            db #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #11, #DF, #11, #DF, #F1, #11, #1D, #DF
            db #11, #DD, #11, #FF, #11, #DF, #11, #DF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #11, #DF, #11, #DF, #F1, #11, #11, #DF
            db #FF, #DD, #11, #DF, #FF, #F1, #1D, #DF, #F1, #11, #DD, #FF, #FF, #DD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #F1, #1D, #DF, #FF
            db #FF, #F1, #1F, #FF, #FF, #11, #DD, #FF, #F1, #1D, #DF, #FF, #11, #DD, #FF, #FF
            db #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #FF, #FD, #DD, #DD, #DF
            db #FF, #FF, #FF, #FF, #11, #11, #11, #FF, #FD, #DD, #DD, #DF, #FF, #FF, #FF, #FF
            db #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #11, #FF
            db #FF, #F1, #1D, #DF, #FF, #11, #DD, #FF, #F1, #1D, #DF, #FF, #FF, #DD, #FF, #FF
            db #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #FD, #DF, #11, #DF, #FF, #F1, #1D, #DF
            db #FF, #11, #DD, #FF, #FF, #FD, #DF, #FF, #FF, #11, #FF, #FF, #FF, #FD, #DF, #FF
            db #F1, #11, #11, #FF, #11, #DD, #D1, #1F, #11, #D1, #11, #1D, #11, #D1, #11, #1D
            db #11, #D1, #11, #1D, #11, #DF, #DD, #DD, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #FF, #11, #FF, #FF, #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #11, #DF, #11, #DF
            db #11, #11, #11, #DF, #11, #DD, #11, #DF, #11, #DF, #11, #DF, #FD, #DF, #FD, #DF
            db #11, #11, #11, #FF, #F1, #1D, #D1, #1F, #F1, #1D, #F1, #1D, #F1, #11, #11, #DD
            db #F1, #1D, #D1, #1F, #F1, #1D, #F1, #1D, #11, #11, #11, #DD, #FD, #DD, #DD, #DF
            db #FF, #11, #11, #FF, #F1, #1D, #D1, #1F, #11, #DD, #FF, #DD, #11, #DF, #FF, #FF
            db #11, #DF, #FF, #FF, #F1, #1F, #F1, #1F, #FF, #11, #11, #DD, #FF, #FD, #DD, #DF
            db #11, #11, #1F, #FF, #F1, #1D, #11, #FF, #F1, #1D, #F1, #1F, #F1, #1D, #F1, #1D
            db #F1, #1D, #F1, #1D, #F1, #1D, #11, #DD, #11, #11, #1D, #DF, #FD, #DD, #DD, #FF
            db #11, #11, #11, #1F, #F1, #1D, #DD, #1D, #F1, #1D, #1F, #FD, #F1, #11, #1D, #FF
            db #F1, #1D, #1D, #FF, #F1, #1D, #FD, #1F, #11, #11, #11, #1D, #FD, #DD, #DD, #DD
            db #11, #11, #11, #1F, #F1, #1D, #DD, #1D, #F1, #1D, #1F, #FD, #F1, #11, #1D, #FF
            db #F1, #1D, #1D, #FF, #F1, #1D, #FD, #FF, #11, #11, #FF, #FF, #FD, #DD, #DF, #FF
            db #FF, #11, #11, #FF, #F1, #1D, #D1, #1F, #11, #DD, #FF, #DD, #11, #DF, #FF, #FF
            db #11, #DF, #11, #1F, #F1, #1F, #F1, #1D, #FF, #11, #11, #1D, #FF, #FD, #DD, #DD
            db #11, #FF, #11, #FF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #11, #11, #DF
            db #11, #DD, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #FD, #DF, #FD, #DF
            db #F1, #11, #1F, #FF, #FF, #11, #DD, #FF, #FF, #11, #DF, #FF, #FF, #11, #DF, #FF
            db #FF, #11, #DF, #FF, #FF, #11, #DF, #FF, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #FF, #F1, #11, #1F, #FF, #FF, #11, #DD, #FF, #FF, #11, #DF, #FF, #FF, #11, #DF
            db #11, #FF, #11, #DF, #11, #DF, #11, #DF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #11, #1F, #F1, #1F, #F1, #1D, #F1, #1D, #F1, #1D, #11, #DD, #F1, #11, #1D, #DF
            db #F1, #1D, #11, #FF, #F1, #1D, #F1, #1F, #11, #1D, #F1, #1D, #FD, #DD, #FF, #DD
            db #11, #11, #FF, #FF, #F1, #1D, #DF, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #FF, #FF
            db #F1, #1D, #FF, #1F, #F1, #1D, #F1, #1D, #11, #11, #11, #1D, #FD, #DD, #DD, #DD
            db #11, #FF, #F1, #1F, #11, #1F, #11, #1D, #11, #11, #11, #1D, #11, #11, #11, #1D
            db #11, #D1, #D1, #1D, #11, #DF, #D1, #1D, #11, #DF, #F1, #1D, #FD, #DF, #FF, #DD
            db #11, #FF, #F1, #1F, #11, #1F, #F1, #1D, #11, #11, #F1, #1D, #11, #D1, #11, #1D
            db #11, #DF, #11, #1D, #11, #DF, #F1, #1D, #11, #DF, #F1, #1D, #FD, #DF, #FF, #DD
            db #FF, #11, #1F, #FF, #F1, #1D, #11, #FF, #11, #DD, #F1, #1F, #11, #DF, #F1, #1D
            db #11, #DF, #F1, #1D, #F1, #1F, #11, #DD, #FF, #11, #1D, #DF, #FF, #FD, #DD, #FF
            db #11, #11, #11, #FF, #F1, #1D, #D1, #1F, #F1, #1D, #F1, #1D, #F1, #11, #11, #DD
            db #F1, #1D, #DD, #DF, #F1, #1D, #FF, #FF, #11, #11, #FF, #FF, #FD, #DD, #DF, #FF
            db #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #11, #DF, #11, #DF, #11, #DF, #11, #DF
            db #11, #D1, #11, #DF, #F1, #11, #1D, #DF, #FF, #D1, #11, #FF, #FF, #FF, #DD, #DF
            db #11, #11, #11, #FF, #F1, #1D, #D1, #1F, #F1, #1D, #F1, #1D, #F1, #11, #11, #DD
            db #F1, #1D, #11, #DF, #F1, #1D, #F1, #1F, #11, #1D, #F1, #1D, #FD, #DD, #FF, #DD
            db #F1, #11, #1F, #FF, #11, #DD, #11, #FF, #11, #1F, #FD, #DF, #F1, #11, #FF, #FF
            db #FF, #D1, #11, #FF, #11, #FF, #11, #DF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #11, #11, #11, #FF, #1D, #11, #D1, #DF, #FD, #11, #DF, #DF, #FF, #11, #DF, #FF
            db #FF, #11, #DF, #FF, #FF, #11, #DF, #FF, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #11, #FF, #11, #FF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #DF
            db #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #11, #11, #DF, #FD, #DD, #DD, #DF
            db #11, #FF, #11, #FF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #DF
            db #11, #DF, #11, #DF, #F1, #11, #1D, #DF, #FF, #11, #DD, #FF, #FF, #FD, #DF, #FF
            db #11, #FF, #F1, #1F, #11, #DF, #F1, #1D, #11, #DF, #F1, #1D, #11, #D1, #F1, #1D
            db #11, #11, #11, #1D, #11, #1D, #11, #1D, #11, #DD, #F1, #1D, #FD, #DF, #FF, #DD
            db #11, #FF, #F1, #1F, #11, #DF, #F1, #1D, #F1, #1F, #11, #DD, #FF, #11, #1D, #DF
            db #FF, #11, #1D, #FF, #F1, #1D, #11, #FF, #11, #DD, #F1, #1F, #FD, #DF, #FF, #DD
            db #11, #FF, #11, #FF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #F1, #11, #1D, #DF
            db #FF, #11, #DD, #FF, #FF, #11, #DF, #FF, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #11, #11, #11, #1F, #11, #DD, #D1, #1D, #1D, #DF, #11, #DD, #FD, #F1, #1D, #DF
            db #FF, #11, #DD, #1F, #F1, #1D, #D1, #1D, #11, #11, #11, #1D, #FD, #DD, #DD, #DD
            db #F1, #11, #1F, #FF, #F1, #1D, #DD, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #FF, #FF
            db #F1, #1D, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF
            db #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #1D, #FF, #FF, #FF, #FD
            db #F1, #11, #1F, #FF, #FF, #D1, #1D, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #FF
            db #FF, #F1, #1D, #FF, #FF, #F1, #1D, #FF, #F1, #11, #1D, #FF, #FF, #DD, #DD, #FF
            db #FF, #F1, #FF, #FF, #FF, #11, #1F, #FF, #F1, #1D, #11, #FF, #11, #DD, #F1, #1F
            db #FD, #DF, #FF, #DD, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #11
            db #FF, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #FF, #DD, #11, #FF
            db #F1, #11, #11, #DF, #11, #DD, #11, #DF, #F1, #11, #F1, #1F, #FF, #DD, #DF, #DD
            db #11, #1F, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #11, #11, #FF
            db #F1, #1D, #D1, #1F, #F1, #1D, #F1, #1D, #11, #D1, #11, #DD, #FD, #DF, #DD, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #11, #DD, #11, #FF
            db #11, #DF, #FD, #DF, #11, #DF, #11, #FF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #FF, #F1, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #11, #DF, #F1, #11, #11, #DF
            db #11, #DD, #11, #DF, #11, #DF, #11, #DF, #F1, #11, #F1, #1F, #FF, #DD, #DF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #11, #DD, #11, #FF
            db #11, #11, #11, #DF, #11, #DD, #DD, #DF, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #FF, #11, #1F, #FF, #F1, #1D, #11, #FF, #F1, #1D, #FD, #DF, #11, #11, #FF, #FF
            db #F1, #1D, #DF, #FF, #F1, #1D, #FF, #FF, #11, #11, #FF, #FF, #FD, #DD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #F1, #1F, #11, #DD, #11, #DD
            db #11, #DF, #11, #DF, #F1, #11, #11, #DF, #FF, #DD, #11, #DF, #11, #11, #1D, #DF
            db #11, #1F, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #11, #FF, #F1, #11, #F1, #1F
            db #F1, #1D, #D1, #1D, #F1, #1D, #F1, #1D, #11, #1D, #F1, #1D, #FD, #DD, #FF, #DD
            db #FF, #11, #FF, #FF, #FF, #FD, #DF, #FF, #F1, #11, #FF, #FF, #FF, #11, #DF, #FF
            db #FF, #11, #DF, #FF, #FF, #11, #DF, #FF, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #FF, #FF, #11, #FF, #FF, #FF, #FD, #DF, #FF, #FF, #11, #FF, #FF, #FF, #11, #DF
            db #FF, #FF, #11, #DF, #11, #FF, #11, #DF, #11, #DF, #11, #DF, #F1, #11, #1D, #DF
            db #11, #1F, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #F1, #1F, #F1, #1D, #11, #DD
            db #F1, #11, #1D, #DF, #F1, #1D, #11, #FF, #11, #1D, #F1, #1F, #FD, #DD, #FF, #DD
            db #F1, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #11, #DF, #FF, #FF, #11, #DF, #FF
            db #FF, #11, #DF, #FF, #FF, #11, #DF, #FF, #F1, #11, #1F, #FF, #FF, #DD, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #11, #11, #1F
            db #11, #11, #11, #1D, #11, #D1, #D1, #1D, #11, #DF, #D1, #1D, #FD, #DF, #FF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #1F, #FF, #11, #DD, #11, #FF
            db #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #11, #DF, #FD, #DF, #FD, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #11, #DD, #11, #FF
            db #11, #DF, #11, #DF, #11, #DF, #11, #DF, #F1, #11, #1D, #DF, #FF, #DD, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #F1, #11, #FF, #F1, #1F, #D1, #1F
            db #F1, #1D, #F1, #1D, #F1, #11, #11, #DD, #F1, #1D, #DD, #DF, #11, #11, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #F1, #1F, #11, #DD, #11, #DD
            db #11, #DF, #11, #DF, #F1, #11, #11, #DF, #FF, #DD, #11, #DF, #FF, #F1, #11, #1F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #F1, #11, #FF, #F1, #11, #D1, #1F
            db #F1, #1D, #D1, #1D, #F1, #1D, #FF, #DD, #11, #11, #FF, #FF, #FD, #DD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #11, #FF, #11, #DD, #DD, #DF
            db #F1, #11, #1F, #FF, #FF, #DD, #11, #FF, #11, #11, #1D, #DF, #FD, #DD, #DD, #FF
            db #FF, #F1, #FF, #FF, #FF, #11, #DF, #FF, #F1, #11, #11, #FF, #FF, #11, #DD, #DF
            db #FF, #11, #DF, #FF, #FF, #11, #D1, #FF, #FF, #F1, #1F, #DF, #FF, #FF, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #DF, #11, #DF
            db #11, #DF, #11, #DF, #11, #DF, #11, #DF, #F1, #11, #F1, #1F, #FF, #DD, #DF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #DF, #11, #DF
            db #11, #DF, #11, #DF, #F1, #11, #1D, #DF, #FF, #11, #DD, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #F1, #1F, #11, #D1, #F1, #1D
            db #11, #11, #11, #1D, #11, #11, #11, #1D, #F1, #1D, #11, #DD, #FF, #DD, #FD, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #F1, #1F, #F1, #1F, #11, #DD
            db #FF, #11, #1D, #DF, #F1, #1D, #11, #FF, #11, #DD, #F1, #1F, #FD, #DF, #FF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #DF, #11, #DF
            db #11, #DF, #11, #DF, #F1, #11, #11, #DF, #FF, #DD, #11, #DF, #11, #11, #1D, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #FF, #1D, #D1, #1D, #DF
            db #FD, #11, #DD, #FF, #F1, #1D, #D1, #FF, #11, #11, #11, #DF, #FD, #DD, #DD, #DF
            db #FF, #F1, #11, #FF, #FF, #11, #DD, #DF, #FF, #11, #DF, #FF, #11, #1D, #DF, #FF
            db #FD, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #F1, #11, #FF, #FF, #FF, #DD, #DF
            db #FF, #F1, #1F, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #FF, #FF, #FF, #DD, #FF
            db #FF, #F1, #1F, #FF, #FF, #F1, #1D, #FF, #FF, #F1, #1D, #FF, #FF, #FF, #DD, #FF
            db #11, #1F, #FF, #FF, #FD, #11, #FF, #FF, #FF, #11, #DF, #FF, #FF, #F1, #11, #FF
            db #FF, #11, #DD, #DF, #FF, #11, #DF, #FF, #11, #1D, #DF, #FF, #FD, #DD, #FF, #FF
            db #F1, #11, #F1, #1F, #11, #D1, #11, #DD, #FD, #DF, #DD, #DF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db 128, 3        ; tiles 128-130
            db #11, #11, #11, #1F, #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2
            db #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2, #F2, #22, #22, #22
            db #11, #11, #11, #1F, #17, #77, #77, #7C, #17, #77, #77, #7C, #17, #77, #77, #7C
            db #17, #77, #77, #7C, #17, #77, #77, #7C, #17, #77, #77, #7C, #FC, #CC, #CC, #CC
            db #11, #11, #11, #1F, #16, #66, #66, #6E, #16, #66, #66, #6E, #16, #66, #66, #6E
            db #16, #66, #66, #6E, #16, #66, #66, #6E, #16, #66, #66, #6E, #FE, #EE, #EE, #EE
            db 0, 0
pats:
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F5, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #5F, #FF, #5F, #FF, #FF, #FF
            db #FF, #F5, #55, #55, #55, #FF, #FF, #FF, #FF, #54, #44, #44, #44, #5F, #FF, #FF
            db #F5, #44, #4A, #44, #44, #45, #BF, #FF, #F5, #44, #A4, #44, #41, #40, #5B, #FF
            db #F5, #44, #A4, #44, #44, #45, #5B, #FF, #F5, #44, #4A, #44, #41, #40, #5B, #FF
            db #FF, #54, #44, #44, #44, #5F, #BF, #FF, #FF, #F5, #55, #55, #55, #FF, #FF, #FF
            db #FF, #FF, #5F, #FF, #5F, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #F5, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #5F, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #5F, #FF, #FF, #FF
            db #FF, #F5, #55, #55, #55, #FF, #FF, #FF, #FF, #54, #44, #44, #44, #5F, #FF, #FF
            db #F5, #44, #4A, #44, #44, #45, #BB, #FF, #F5, #44, #A4, #44, #41, #40, #5F, #BF
            db #F5, #44, #A4, #44, #44, #45, #5F, #FF, #F5, #44, #4A, #44, #41, #40, #5F, #BF
            db #FF, #54, #44, #44, #44, #5F, #BB, #FF, #FF, #F5, #55, #55, #55, #FF, #FF, #FF
            db #FF, #FF, #F5, #FF, #5F, #FF, #FF, #FF, #FF, #FF, #5F, #FF, #F5, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F5, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #5F, #FF, #5F, #FF, #FF, #FF
            db #FF, #F5, #55, #55, #55, #FF, #FB, #BF, #FF, #54, #44, #44, #44, #5F, #BF, #FB
            db #F5, #44, #4A, #44, #44, #45, #FF, #FF, #F5, #44, #A4, #44, #41, #40, #5F, #FF
            db #F5, #44, #A4, #44, #44, #45, #5F, #FF, #F5, #44, #4A, #44, #41, #40, #5F, #FF
            db #FF, #54, #44, #44, #44, #5F, #FF, #FF, #FF, #F5, #55, #55, #55, #FF, #BF, #FB
            db #FF, #FF, #5F, #FF, #5F, #FF, #FB, #BF, #FF, #F5, #FF, #FF, #F5, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FB, #BB, #FF, #FF, #FF, #FF, #FF, #FF, #B5, #55, #BF, #FF, #FF
            db #FF, #FF, #FF, #50, #50, #FF, #FF, #FF, #FF, #FF, #F5, #44, #44, #5F, #FF, #FF
            db #FF, #5F, #54, #41, #41, #45, #F5, #FF, #FF, #F5, #54, #44, #44, #45, #5F, #FF
            db #FF, #FF, #54, #44, #44, #45, #FF, #FF, #FF, #FF, #54, #44, #44, #45, #FF, #FF
            db #FF, #FF, #54, #A4, #4A, #45, #FF, #FF, #FF, #F5, #54, #4A, #A4, #45, #5F, #FF
            db #FF, #5F, #54, #44, #44, #45, #F5, #FF, #FF, #FF, #F5, #44, #44, #5F, #FF, #FF
            db #FF, #FF, #FF, #55, #55, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FB, #FB, #FF, #FF, #FF
            db #FF, #FF, #FF, #BF, #FF, #BF, #FF, #FF, #FF, #FF, #FF, #B5, #55, #BF, #FF, #FF
            db #FF, #FF, #FF, #50, #50, #FF, #FF, #FF, #FF, #FF, #F5, #44, #44, #5F, #FF, #FF
            db #FF, #5F, #54, #41, #41, #45, #F5, #FF, #FF, #F5, #54, #44, #44, #45, #5F, #FF
            db #FF, #FF, #54, #44, #44, #45, #FF, #FF, #FF, #FF, #54, #44, #44, #45, #FF, #FF
            db #FF, #F5, #54, #A4, #4A, #45, #5F, #FF, #FF, #5F, #54, #4A, #A4, #45, #F5, #FF
            db #FF, #FF, #54, #44, #44, #45, #FF, #FF, #FF, #FF, #F5, #44, #44, #5F, #FF, #FF
            db #FF, #FF, #FF, #55, #55, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FB, #FF, #FF, #FB, #FF, #FF, #FF, #FF, #BF, #FF, #FF, #FF, #BF, #FF
            db #FF, #FF, #BF, #FF, #FF, #FF, #BF, #FF, #FF, #FF, #FB, #F5, #55, #FB, #FF, #FF
            db #FF, #FF, #FF, #50, #50, #FF, #FF, #FF, #FF, #FF, #F5, #44, #44, #5F, #FF, #FF
            db #FF, #5F, #54, #41, #41, #45, #F5, #FF, #FF, #F5, #54, #44, #44, #45, #5F, #FF
            db #FF, #FF, #54, #44, #44, #45, #FF, #FF, #FF, #FF, #54, #44, #44, #45, #FF, #FF
            db #FF, #FF, #54, #A4, #4A, #45, #FF, #FF, #FF, #F5, #54, #4A, #A4, #45, #5F, #FF
            db #FF, #5F, #54, #44, #44, #45, #F5, #FF, #FF, #FF, #F5, #44, #44, #5F, #FF, #FF
            db #FF, #FF, #FF, #55, #55, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #F2, #22, #22, #2F, #FF, #FF, #FF, #FF, #22, #22, #22, #22, #FF, #FF
            db #FF, #F2, #22, #22, #22, #22, #2F, #FF, #FF, #22, #22, #22, #22, #22, #22, #FF
            db #FF, #22, #22, #22, #22, #22, #22, #FF, #FF, #22, #22, #22, #22, #22, #22, #FF
            db #FF, #22, #22, #22, #22, #22, #22, #FF, #FF, #33, #33, #33, #33, #33, #33, #FF
            db #F3, #F3, #33, #33, #33, #33, #3F, #3F, #3F, #FF, #33, #33, #33, #33, #FF, #F3
            db #FF, #FF, #F3, #33, #33, #3F, #FF, #FF, #FF, #FF, #FF, #CB, #BC, #FF, #FF, #FF
            db #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #F2, #22, #22, #2F, #FF, #FF, #FF, #FF, #22, #22, #22, #22, #FF, #FF
            db #FF, #F2, #22, #22, #22, #22, #2F, #FF, #FF, #22, #22, #22, #22, #22, #22, #FF
            db #FF, #22, #22, #22, #22, #22, #22, #FF, #FF, #22, #22, #22, #22, #22, #22, #FF
            db #FF, #22, #22, #22, #22, #22, #22, #FF, #FF, #33, #33, #33, #33, #33, #33, #FF
            db #F3, #F3, #33, #33, #33, #33, #3F, #3F, #3F, #FF, #33, #33, #33, #33, #FF, #F3
            db #FF, #FF, #F3, #33, #33, #3F, #FF, #FF, #FF, #FF, #FF, #BC, #CB, #FF, #FF, #FF
            db #FF, #FF, #FF, #CF, #FC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #F7, #77, #77, #7F, #FF, #FF, #FF, #FF, #77, #77, #77, #77, #FF, #FF
            db #FF, #F7, #77, #77, #77, #77, #7F, #FF, #FF, #77, #77, #77, #77, #77, #77, #FF
            db #FF, #77, #88, #77, #77, #88, #77, #FF, #FF, #77, #88, #77, #77, #88, #77, #FF
            db #FF, #77, #77, #77, #77, #77, #77, #FF, #FF, #88, #88, #88, #88, #88, #88, #FF
            db #F8, #F8, #78, #78, #78, #78, #8F, #8F, #8F, #FF, #88, #88, #88, #88, #FF, #F8
            db #FF, #FF, #F8, #88, #88, #8F, #FF, #FF, #FF, #FF, #FF, #CB, #BC, #FF, #FF, #FF
            db #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #F7, #77, #77, #7F, #FF, #FF, #FF, #FF, #77, #77, #77, #77, #FF, #FF
            db #FF, #F7, #77, #77, #77, #77, #7F, #FF, #FF, #77, #77, #77, #77, #77, #77, #FF
            db #FF, #77, #88, #77, #77, #88, #77, #FF, #FF, #77, #88, #77, #77, #88, #77, #FF
            db #FF, #77, #77, #77, #77, #77, #77, #FF, #FF, #88, #88, #88, #88, #88, #88, #FF
            db #F8, #F8, #78, #78, #78, #78, #8F, #8F, #8F, #FF, #88, #88, #88, #88, #FF, #F8
            db #FF, #FF, #F8, #88, #88, #8F, #FF, #FF, #FF, #FF, #FF, #BC, #CB, #FF, #FF, #FF
            db #FF, #FF, #FF, #CF, #FC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #11, #1F, #F1, #11, #FF, #FF, #FF, #FF, #11, #6F, #F1, #16, #FF, #FF
            db #FF, #FF, #11, #6F, #F1, #16, #FF, #FF, #FF, #FF, #11, #1F, #F1, #11, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #11, #1F, #F1, #11, #FF, #FF, #FF, #FF, #11, #1F, #F1, #11, #FF, #FF
            db #FF, #FF, #16, #1F, #F1, #61, #FF, #FF, #FF, #FF, #16, #1F, #F1, #61, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #11, #1F, #F1, #11, #FF, #FF, #FF, #FF, #61, #1F, #F6, #11, #FF, #FF
            db #FF, #FF, #61, #1F, #F6, #11, #FF, #FF, #FF, #FF, #11, #1F, #F1, #11, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #16, #1F, #F1, #61, #FF, #FF, #FF, #FF, #16, #1F, #F1, #61, #FF, #FF
            db #FF, #FF, #11, #1F, #F1, #11, #FF, #FF, #FF, #FF, #11, #1F, #F1, #11, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #AA, #AA, #AA, #FF, #FF
            db #FF, #FA, #11, #AA, #AA, #AE, #AF, #FF, #FF, #A1, #1A, #AA, #AA, #AA, #AE, #FF
            db #FA, #AA, #AA, #AA, #AA, #AA, #AA, #EF, #FF, #AA, #AA, #AA, #AA, #AA, #EE, #FF
            db #FF, #FA, #AA, #AA, #AA, #AE, #EF, #FF, #FF, #FF, #AA, #AA, #AA, #EE, #FF, #FF
            db #FF, #FF, #FA, #AA, #AE, #EF, #FF, #FF, #FF, #FF, #FF, #AA, #EE, #FF, #FF, #FF
            db #FF, #FF, #FF, #FA, #EF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #99, #99, #FF, #FF, #FF
            db #FF, #FF, #EE, #EE, #EE, #EE, #FF, #FF, #FF, #FF, #E4, #44, #44, #4E, #FF, #FF
            db #FF, #FF, #E4, #41, #44, #4E, #FF, #FF, #FF, #FF, #E4, #11, #14, #4E, #FF, #FF
            db #FF, #FF, #E4, #41, #44, #4E, #FF, #FF, #FF, #FF, #E4, #44, #44, #4E, #FF, #FF
            db #FF, #FF, #EB, #BB, #BB, #BE, #FF, #FF, #FF, #FF, #EB, #BB, #BB, #BE, #FF, #FF
            db #FF, #FF, #EB, #B3, #BB, #BE, #FF, #FF, #FF, #FF, #EB, #B3, #BB, #BE, #FF, #FF
            db #FF, #FF, #EB, #BB, #BB, #BE, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #EE, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #99, #99, #FF, #FF, #FF
            db #FF, #F9, #9F, #99, #99, #F9, #9F, #FF, #FF, #F9, #99, #99, #99, #99, #9F, #FF
            db #FF, #FF, #99, #9E, #E9, #99, #FF, #FF, #FF, #99, #99, #EE, #E9, #99, #99, #FF
            db #FF, #99, #9E, #EF, #FE, #E9, #99, #FF, #FF, #99, #9E, #FF, #FF, #E9, #99, #FF
            db #FF, #99, #9E, #FF, #FF, #E9, #99, #FF, #FF, #99, #9E, #EF, #FE, #E9, #99, #FF
            db #FF, #99, #99, #9E, #E9, #99, #99, #FF, #FF, #FF, #99, #99, #99, #99, #FF, #FF
            db #FF, #F9, #99, #99, #99, #99, #9F, #FF, #FF, #F9, #9F, #99, #99, #F9, #9F, #FF
            db #FF, #FF, #FF, #99, #99, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #9F, #9F, #9F, #9F, #9F, #9F, #FF
            db #FF, #EE, #EE, #EE, #EE, #EE, #EF, #FF, #9F, #E4, #54, #54, #54, #54, #EF, #9F
            db #FF, #E5, #00, #00, #00, #05, #EF, #FF, #9F, #E4, #0A, #AA, #AA, #64, #EF, #9F
            db #FF, #E5, #0A, #11, #AA, #65, #EF, #FF, #9F, #E4, #0A, #AA, #AA, #64, #EF, #9F
            db #FF, #E5, #06, #66, #66, #65, #EF, #FF, #9F, #E4, #54, #54, #54, #54, #EF, #9F
            db #FF, #EE, #EE, #EE, #EE, #EE, #EF, #FF, #FF, #9F, #9F, #9F, #9F, #9F, #9F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #AF, #AA, #AF, #AA, #AF, #FF
            db #FF, #FF, #AF, #AF, #AF, #AF, #AF, #FF, #FF, #AA, #AF, #AF, #AF, #AF, #AF, #FF
            db #FF, #AF, #FF, #AF, #AF, #AF, #AF, #FF, #FF, #AA, #AF, #AA, #AF, #AA, #AF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AF, #AF, #AA, #AF, #AA, #AF, #FF
            db #FF, #AF, #AF, #AF, #AF, #AF, #AF, #FF, #FF, #AA, #AF, #AF, #AF, #AF, #AF, #FF
            db #FF, #FF, #AF, #AF, #AF, #AF, #AF, #FF, #FF, #FF, #AF, #AA, #AF, #AA, #AF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #AF, #AA, #AF, #AA, #AF, #FF
            db #FF, #AF, #AF, #AF, #AF, #AF, #AF, #FF, #FF, #AA, #AF, #AF, #AF, #AF, #AF, #FF
            db #FF, #AF, #AF, #AF, #AF, #AF, #AF, #FF, #FF, #AA, #AF, #AA, #AF, #AA, #AF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #AA, #AF, #AA, #AF, #AA, #AF
            db #AA, #FF, #AF, #FF, #AF, #AF, #AF, #AF, #FA, #FF, #AA, #AF, #AF, #AF, #AF, #AF
            db #FA, #FF, #AF, #AF, #AF, #AF, #AF, #AF, #AA, #AF, #AA, #AF, #AA, #AF, #AA, #AF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #BF, #FF, #FF, #FF
            db #FF, #FF, #FB, #55, #54, #FF, #FF, #FF, #FF, #FF, #F4, #55, #5B, #FF, #FF, #FF
            db #FF, #FF, #FB, #55, #54, #FF, #FF, #FF, #FF, #FF, #FF, #45, #B5, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FB, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #55, #54, #FF, #FF, #FF
            db #FF, #FF, #BF, #55, #55, #BF, #FF, #FF, #FF, #FF, #FF, #55, #55, #FF, #FF, #FF
            db #FF, #FF, #4F, #55, #55, #4F, #FF, #FF, #FF, #FF, #FB, #55, #5B, #FF, #FF, #FF
            db #FF, #FF, #FF, #54, #55, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #BF, #4F, #FF, #FF, #FF
            db #FF, #FF, #F5, #55, #55, #5F, #FF, #FF, #FF, #FF, #45, #55, #55, #BF, #FF, #FF
            db #FF, #FF, #F5, #55, #55, #5F, #FF, #FF, #FF, #FB, #F5, #55, #55, #54, #FF, #FF
            db #FF, #FF, #F5, #55, #55, #5F, #FF, #FF, #FF, #FF, #45, #55, #55, #BF, #FF, #FF
            db #FF, #FF, #F5, #55, #55, #5F, #FF, #FF, #FF, #FF, #F5, #B5, #45, #5F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #FF, #BF, #FF, #FF, #BF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #FF
            db #FF, #4F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #BF, #FF, #FF, #BF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #FF, #FF, #4F, #FF, #FF
            db #FF, #FF, #FF, #FB, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #FF, #FB, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #FF
            db #FF, #BF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #FB, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #4F, #FF, #FF, #BF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #FF, #FB, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FB, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #FF, #FF
            db #FF, #4F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FB, #FF, #BF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #4F
            db #F4, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #BF, #FF, #FF, #FB, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ld_end:
#endasm
End Sub
