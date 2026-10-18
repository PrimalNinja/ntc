' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_ALIENA = 0
Public Const S_ALIENA_N = 2
Public Const S_ALIENB = 2
Public Const S_ALIENB_N = 2
Public Const S_ALIENC = 4
Public Const S_ALIENC_N = 2
Public Const S_PLAYER = 6
Public Const S_PLAYER_N = 1
Public Const S_SHOT = 7
Public Const S_SHOT_N = 1
Public Const S_BOMB = 8
Public Const S_BOMB_N = 2
Public Const S_SAUCER = 10
Public Const S_SAUCER_N = 1
Public Const S_BOOM = 11
Public Const S_BOOM_N = 2
Public Const S_PDIE = 13
Public Const S_PDIE_N = 2
Public Const T_SHIELD = 1
Public Const T_SHIELD_N = 4
Public Const T_GROUND = 5
Public Const T_GROUNDTOP = 6
Public Const T_STAR = 7
Public Const T_STAR_N = 3
Public Const T_LIFE = 10
Public Const T_LOGO = 16
Public Const T_LOGO_N = 3
Public Const SpritePatterns = 15
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
            ld de, 1920
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
            db #00, #FF, #93, #39, #0C, #E4, #FC, #1B, #01, #AB, #F0, #26, #9D, #4A, #67, #E3
spal:
            db #00, #FF, #39, #1B, #C7, #FC, #E4, #F0, #2B, #B7, #4A, #9D, #77, #F7, #46, #E3
            db #00, #FF, #F0, #FC, #E4, #FC, #E4, #F0, #2B, #B7, #4A, #9D, #77, #F7, #46, #E3
            db #00, #FF, #1B, #13, #2B, #FC, #E4, #F0, #2B, #B7, #4A, #9D, #77, #F7, #46, #E3
            db #00, #FF, #C7, #F7, #67, #FC, #E4, #F0, #2B, #B7, #4A, #9D, #77, #F7, #46, #E3
            db #00, #E4, #E4, #F0, #FC, #FF, #E4, #F0, #2B, #B7, #4A, #9D, #77, #F7, #46, #E3
truns:
            db 1, 10        ; tiles 1-10
            db #33, #33, #33, #33, #34, #43, #44, #43, #33, #33, #33, #33, #44, #34, #44, #34
            db #33, #33, #33, #33, #34, #43, #44, #43, #33, #33, #33, #33, #44, #34, #44, #34
            db #33, #F3, #33, #33, #34, #43, #4F, #F3, #33, #33, #33, #3F, #44, #34, #44, #34
            db #F3, #33, #33, #F3, #34, #43, #44, #43, #33, #3F, #33, #33, #44, #34, #4F, #34
            db #F3, #F3, #F3, #FF, #3F, #43, #FF, #F3, #F3, #3F, #33, #FF, #4F, #3F, #F4, #3F
            db #F3, #F3, #3F, #F3, #3F, #F3, #F4, #F3, #F3, #FF, #3F, #3F, #FF, #34, #FF, #F4
            db #FF, #FF, #F3, #FF, #3F, #FF, #FF, #FF, #FF, #F3, #FF, #FF, #FF, #FF, #F4, #FF
            db #F3, #FF, #FF, #FF, #FF, #FF, #FF, #3F, #FF, #F3, #FF, #FF, #3F, #FF, #FF, #4F
            db #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44
            db #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44
            db #44, #44, #44, #44, #CC, #CC, #CC, #CC, #44, #44, #44, #44, #44, #44, #44, #44
            db #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F2, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FD, #FF, #FF, #FF, #D1, #DF, #FF
            db #FF, #FD, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #DF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FD, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FC, #CF, #FF, #FC, #CC, #CC, #CF
            db #CC, #CC, #CC, #CC, #C4, #CC, #CC, #4C, #CC, #CC, #CC, #CC, #FF, #FF, #FF, #FF
            db 16, 3        ; tiles 16-18
            db #11, #11, #11, #1F, #16, #66, #66, #6A, #16, #66, #66, #6A, #16, #66, #66, #6A
            db #16, #66, #66, #6A, #16, #66, #66, #6A, #16, #66, #66, #6A, #FA, #AA, #AA, #AA
            db #11, #11, #11, #1F, #15, #55, #55, #59, #15, #55, #55, #59, #15, #55, #55, #59
            db #15, #55, #55, #59, #15, #55, #55, #59, #15, #55, #55, #59, #F9, #99, #99, #99
            db #11, #11, #11, #1F, #17, #77, #77, #7B, #17, #77, #77, #7B, #17, #77, #77, #7B
            db #17, #77, #77, #7B, #17, #77, #77, #7B, #17, #77, #77, #7B, #FB, #BB, #BB, #BB
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
            db 0, 0
pats:
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F2, #22, #22, #2F, #FF, #FF, #FF, #F2, #22, #22, #22, #22, #2F, #FF
            db #FF, #22, #22, #22, #22, #22, #22, #FF, #F2, #22, #11, #22, #22, #11, #22, #2F
            db #F2, #22, #10, #22, #22, #01, #22, #2F, #F2, #22, #22, #22, #22, #22, #22, #2F
            db #FF, #22, #33, #33, #33, #33, #22, #FF, #FF, #F3, #F3, #F3, #3F, #3F, #3F, #FF
            db #FF, #3F, #F3, #FF, #3F, #F3, #F3, #FF, #FF, #3F, #3F, #FF, #3F, #FF, #3F, #FF
            db #F3, #FF, #F3, #FF, #3F, #F3, #FF, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F2, #22, #22, #2F, #FF, #FF, #FF, #F2, #22, #22, #22, #22, #2F, #FF
            db #FF, #22, #22, #22, #22, #22, #22, #FF, #F2, #22, #11, #22, #22, #11, #22, #2F
            db #F2, #22, #01, #22, #22, #10, #22, #2F, #F2, #22, #22, #22, #22, #22, #22, #2F
            db #FF, #22, #33, #33, #33, #33, #22, #FF, #FF, #F3, #F3, #F3, #3F, #3F, #3F, #FF
            db #FF, #F3, #F3, #FF, #3F, #3F, #F3, #FF, #FF, #3F, #FF, #3F, #3F, #F3, #FF, #3F
            db #FF, #3F, #F3, #FF, #F3, #FF, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #22, #22, #FF, #FF, #FF, #FF, #FF, #22, #32, #23, #22, #FF, #FF
            db #FF, #F2, #33, #22, #22, #33, #2F, #FF, #FF, #22, #31, #12, #21, #13, #22, #FF
            db #FF, #22, #31, #02, #20, #13, #22, #FF, #FF, #22, #22, #22, #22, #22, #22, #FF
            db #FF, #F2, #32, #22, #22, #23, #2F, #FF, #FF, #FF, #22, #32, #23, #22, #FF, #FF
            db #FF, #F4, #FF, #22, #22, #FF, #4F, #FF, #FF, #4F, #F4, #FF, #FF, #4F, #F4, #FF
            db #F4, #FF, #4F, #FF, #FF, #F4, #FF, #4F, #F4, #4F, #FF, #FF, #FF, #FF, #F4, #4F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #22, #22, #FF, #FF, #FF, #FF, #FF, #22, #32, #23, #22, #FF, #FF
            db #FF, #F2, #33, #22, #22, #33, #2F, #FF, #FF, #22, #31, #12, #21, #13, #22, #FF
            db #FF, #22, #30, #12, #21, #03, #22, #FF, #FF, #22, #22, #22, #22, #22, #22, #FF
            db #FF, #F2, #32, #22, #22, #23, #2F, #FF, #FF, #FF, #22, #32, #23, #22, #FF, #FF
            db #FF, #FF, #4F, #22, #22, #F4, #FF, #FF, #FF, #F4, #F4, #FF, #FF, #4F, #4F, #FF
            db #FF, #F4, #FF, #4F, #F4, #FF, #4F, #FF, #FF, #FF, #44, #FF, #FF, #44, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F2, #2F, #FF, #FF, #FF, #FF, #FF, #F2, #22, #22, #2F, #FF, #FF
            db #4F, #FF, #22, #33, #33, #22, #FF, #F4, #44, #F2, #23, #11, #11, #32, #2F, #44
            db #F4, #44, #23, #10, #01, #32, #44, #4F, #FF, #44, #23, #10, #01, #32, #44, #FF
            db #F4, #44, #23, #11, #11, #32, #44, #4F, #44, #F2, #23, #33, #33, #32, #2F, #44
            db #4F, #FF, #22, #22, #22, #22, #FF, #F4, #FF, #FF, #F2, #F2, #2F, #2F, #FF, #FF
            db #FF, #FF, #FF, #2F, #F2, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F2, #2F, #FF, #FF, #FF, #FF, #FF, #F2, #22, #22, #2F, #FF, #FF
            db #FF, #FF, #22, #33, #33, #22, #FF, #FF, #FF, #F2, #23, #11, #11, #32, #2F, #FF
            db #44, #44, #23, #10, #01, #32, #44, #44, #F4, #44, #23, #10, #01, #32, #44, #4F
            db #44, #44, #23, #11, #11, #32, #44, #44, #FF, #F2, #23, #33, #33, #32, #2F, #FF
            db #FF, #FF, #22, #22, #22, #22, #FF, #FF, #FF, #FF, #F2, #F2, #2F, #2F, #FF, #FF
            db #FF, #FF, #F2, #FF, #FF, #2F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #91, #19, #FF, #FF, #FF
            db #FF, #FF, #FF, #9A, #A9, #FF, #FF, #FF, #FF, #BF, #F9, #AA, #AA, #9F, #FB, #FF
            db #FB, #BB, #F9, #A1, #1A, #9F, #BB, #BF, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BF
            db #BC, #CC, #CC, #CC, #CC, #CC, #CC, #BF, #BA, #AA, #AA, #AA, #AA, #AA, #AA, #FB
            db #FB, #AF, #AF, #AF, #AF, #AF, #AB, #FF, #FF, #5F, #7F, #5F, #7F, #5F, #7F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #66, #66, #FF, #FF, #FF, #FF, #FF, #66, #11, #11, #66, #FF, #FF
            db #FF, #F6, #61, #33, #33, #16, #6F, #FF, #F6, #66, #66, #66, #66, #66, #66, #6F
            db #65, #56, #67, #76, #67, #76, #65, #56, #F6, #66, #66, #66, #66, #66, #66, #6F
            db #FF, #F6, #6F, #FF, #FF, #F6, #6F, #FF, #FF, #FF, #7F, #FF, #FF, #F7, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #5F, #FF, #F1, #FF, #FF, #5F, #FF
            db #FF, #F5, #FF, #F5, #FF, #F5, #FF, #FF, #FF, #FF, #5F, #FF, #FF, #5F, #FF, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #F1, #15, #7F, #F6, #FF, #75, #11, #FF
            db #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF, #FF, #FF, #5F, #FF, #FF, #5F, #FF, #FF
            db #FF, #F5, #FF, #F5, #FF, #F5, #FF, #FF, #FF, #5F, #FF, #F1, #FF, #FF, #5F, #FF
            db #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #F5
            db #FF, #5F, #FF, #F7, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF, #7F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #77, #FF, #FF, #F6, #FF, #FF, #F7, #7F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #FF, #7F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F7, #FF, #FF, #FF, #FF
            db #FF, #5F, #FF, #F7, #FF, #FF, #F5, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #F5
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #5F, #F7, #FF, #FF, #FF
            db #FF, #F7, #FF, #F5, #FF, #FF, #F5, #FF, #FF, #FF, #F6, #FF, #7F, #6F, #FF, #FF
            db #FF, #5F, #FF, #66, #F6, #FF, #F7, #FF, #FF, #FF, #7F, #B6, #6B, #F5, #FF, #FF
            db #FF, #BF, #BB, #B6, #BB, #BB, #FB, #FF, #FB, #BB, #BC, #BB, #BC, #BB, #BB, #FF
            db #BC, #CC, #CC, #CC, #CC, #CC, #CC, #BF, #BA, #AF, #AA, #AF, #AA, #AA, #AF, #AB
            db #FB, #AF, #AF, #FF, #AF, #AF, #AB, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #F7, #FF, #FF, #F5, #FF, #FF, #F7, #FF, #FF, #F5, #FF, #FF, #FF, #F7, #FF, #FF
            db #FF, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #F7, #FF, #6F, #FF, #FF, #FF, #6F, #F5
            db #FF, #FF, #FF, #7F, #F5, #FF, #FF, #FF, #FF, #5F, #FF, #FF, #6F, #FF, #F7, #FF
            db #FF, #FB, #FF, #FB, #FB, #FF, #BF, #FF, #FB, #FF, #BC, #FB, #FC, #BF, #FB, #FF
            db #BC, #FC, #CC, #FC, #CF, #CF, #CC, #BF, #BA, #FF, #AA, #FF, #FA, #AF, #FA, #FB
            db #FF, #AF, #AF, #FF, #AF, #FF, #AB, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ld_end:
#endasm
End Sub
