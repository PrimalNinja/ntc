' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_IDLE = 0
Public Const S_IDLE_N = 2
Public Const S_IDLE_W = 2
Public Const S_IDLE_H = 3
Public Const S_WALK = 12
Public Const S_WALK_N = 2
Public Const S_WALK_W = 2
Public Const S_WALK_H = 3
Public Const S_CROUCH = 24
Public Const S_CROUCH_N = 1
Public Const S_CROUCH_W = 2
Public Const S_CROUCH_H = 3
Public Const S_JUMP = 30
Public Const S_JUMP_N = 1
Public Const S_JUMP_W = 2
Public Const S_JUMP_H = 3
Public Const S_PUNCH = 36
Public Const S_PUNCH_N = 1
Public Const S_PUNCH_W = 2
Public Const S_PUNCH_H = 3
Public Const S_KICK = 42
Public Const S_KICK_N = 1
Public Const S_KICK_W = 2
Public Const S_KICK_H = 3
Public Const S_LOWKICK = 48
Public Const S_LOWKICK_N = 1
Public Const S_LOWKICK_W = 2
Public Const S_LOWKICK_H = 3
Public Const S_BLOCK = 54
Public Const S_BLOCK_N = 1
Public Const S_BLOCK_W = 2
Public Const S_BLOCK_H = 3
Public Const S_HIT = 60
Public Const S_HIT_N = 1
Public Const S_HIT_W = 2
Public Const S_HIT_H = 3
Public Const S_DOWN = 66
Public Const S_DOWN_N = 1
Public Const S_DOWN_W = 2
Public Const S_DOWN_H = 3
Public Const S_SPECIAL = 72
Public Const S_SPECIAL_N = 1
Public Const S_SPECIAL_W = 2
Public Const S_SPECIAL_H = 3
Public Const S_WIN = 78
Public Const S_WIN_N = 1
Public Const S_WIN_W = 2
Public Const S_WIN_H = 3
Public Const S_ORB = 84
Public Const S_ORB_N = 2
Public Const S_SPARK = 86
Public Const S_SPARK_N = 2
Public Const T_SKY = 1
Public Const T_STARS = 2
Public Const T_BUILD = 3
Public Const T_WIN1 = 4
Public Const T_WIN2 = 5
Public Const T_ROOFL = 6
Public Const T_ROOFR = 7
Public Const T_BRICK = 8
Public Const T_BRICK_N = 2
Public Const T_WALLB = 10
Public Const T_PAVE = 11
Public Const T_PAVE_N = 2
Public Const T_DOOR = 13
Public Const T_DARK = 14
Public Const T_GREY = 15
Public Const T_BAR = 16
Public Const T_BAR_N = 9
Public Const T_BARR = 131
Public Const T_BARR_N = 9
Public Const T_ROUND = 25
Public Const T_ROUND_N = 2
Public Const T_SIGN = 27
Public Const T_SIGN_N = 5
Public Const T_LOGO = 128
Public Const T_LOGO_N = 3
Public Const SpritePatterns = 88
Public Const SpritePalettes = 4

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
            ld e, 64                ; 4 x 16 (0 = 256)
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
            ld de, 11264
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
            db #00, #FF, #21, #25, #F9, #A4, #40, #6E, #49, #E4, #FC, #40, #1F, #4A, #EB, #E3
spal:
            db #00, #FF, #F6, #AD, #20, #E4, #80, #26, #01, #64, #FC, #1F, #BF, #FD, #F0, #E3
            db #00, #FF, #AD, #68, #D5, #15, #0C, #6F, #4A, #64, #FF, #1F, #BF, #FD, #F0, #E3
            db #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #BF, #FD, #F0, #E3
            db #00, #FF, #F6, #AD, #20, #E4, #80, #26, #01, #64, #FC, #EB, #FB, #FD, #F0, #E3
truns:
            db 1, 31        ; tiles 1-31
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #12, #22, #22, #22, #22, #22
            db #22, #22, #22, #22, #22, #22, #22, #22, #21, #22, #22, #22, #22, #22, #22, #22
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #34, #43, #34, #43, #34, #43, #34, #43, #33, #33, #33, #33
            db #33, #33, #33, #33, #34, #43, #33, #33, #34, #43, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #3D, #D3, #34, #43, #3D, #D3, #34, #43, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #3D, #D3, #33, #33, #3D, #D3, #33, #33, #33, #33
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #33, #33, #22, #22, #33, #33, #22, #22, #33, #33, #33, #33, #33, #33, #33, #33
            db #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #22, #22, #33, #33, #22, #22, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #55, #55, #55, #56, #55, #55, #55, #56, #55, #55, #55, #56, #66, #66, #66, #66
            db #55, #56, #55, #55, #55, #56, #55, #55, #55, #56, #55, #55, #66, #66, #66, #66
            db #55, #55, #55, #56, #55, #55, #55, #56, #56, #55, #55, #56, #66, #66, #66, #66
            db #55, #56, #55, #55, #55, #56, #55, #65, #55, #56, #55, #55, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #DD, #DD, #DD, #DD, #77, #77, #77, #77
            db #77, #77, #77, #77, #88, #88, #88, #88, #66, #66, #66, #66, #66, #66, #66, #66
            db #77, #77, #77, #77, #77, #77, #77, #87, #77, #77, #77, #77, #78, #77, #77, #77
            db #77, #77, #77, #77, #77, #77, #78, #77, #77, #77, #77, #77, #88, #88, #88, #88
            db #77, #77, #77, #77, #77, #77, #77, #77, #77, #78, #77, #77, #77, #77, #77, #77
            db #77, #77, #77, #77, #77, #77, #77, #87, #77, #77, #77, #77, #88, #88, #88, #88
            db #DD, #DD, #DD, #DD, #D8, #88, #88, #8D, #D8, #33, #33, #8D, #D8, #33, #33, #8D
            db #D8, #33, #33, #8D, #D8, #33, #33, #8D, #D8, #88, #88, #8D, #DD, #DD, #DD, #DD
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD, #DD
            db #00, #00, #00, #00, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #A6, #66, #66, #66, #96, #66, #66, #66, #96, #66, #66, #66
            db #96, #66, #66, #66, #96, #66, #66, #66, #A6, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #66, #66, #66, #99, #66, #66, #66, #99, #66, #66, #66
            db #99, #66, #66, #66, #99, #66, #66, #66, #AA, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #A6, #66, #66, #99, #96, #66, #66, #99, #96, #66, #66
            db #99, #96, #66, #66, #99, #96, #66, #66, #AA, #A6, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #AA, #66, #66, #99, #99, #66, #66, #99, #99, #66, #66
            db #99, #99, #66, #66, #99, #99, #66, #66, #AA, #AA, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #AA, #A6, #66, #99, #99, #96, #66, #99, #99, #96, #66
            db #99, #99, #96, #66, #99, #99, #96, #66, #AA, #AA, #A6, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #AA, #AA, #66, #99, #99, #99, #66, #99, #99, #99, #66
            db #99, #99, #99, #66, #99, #99, #99, #66, #AA, #AA, #AA, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #AA, #AA, #A6, #99, #99, #99, #96, #99, #99, #99, #96
            db #99, #99, #99, #96, #99, #99, #99, #96, #AA, #AA, #AA, #A6, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #AA, #AA, #AA, #99, #99, #99, #99, #99, #99, #99, #99
            db #99, #99, #99, #99, #99, #99, #99, #99, #AA, #AA, #AA, #AA, #00, #00, #00, #00
            db #11, #11, #11, #11, #10, #00, #00, #01, #10, #00, #00, #01, #10, #00, #00, #01
            db #10, #00, #00, #01, #10, #00, #00, #01, #10, #00, #00, #01, #11, #11, #11, #11
            db #11, #11, #11, #11, #1A, #AA, #AA, #A1, #1A, #99, #99, #A1, #1A, #99, #99, #A1
            db #1A, #99, #99, #A1, #1A, #99, #99, #A1, #1A, #AA, #AA, #A1, #11, #11, #11, #11
            db #EE, #EE, #EE, #EE, #EE, #EE, #EE, #EE, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #EE, #EE, #EE, #EE, #EE, #EE, #EE, #EE
            db #EE, #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00
            db #EE, #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00
            db #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00, #EE
            db #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00, #EE, #00, #00, #00, #EE
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
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
            db 128, 12        ; tiles 128-139
            db #11, #11, #11, #1F, #19, #99, #99, #96, #19, #99, #99, #96, #19, #99, #99, #96
            db #19, #99, #99, #96, #19, #99, #99, #96, #19, #99, #99, #96, #F6, #66, #66, #66
            db #11, #11, #11, #1F, #1A, #AA, #AA, #A8, #1A, #AA, #AA, #A8, #1A, #AA, #AA, #A8
            db #1A, #AA, #AA, #A8, #1A, #AA, #AA, #A8, #1A, #AA, #AA, #A8, #F8, #88, #88, #88
            db #11, #11, #11, #1F, #1C, #CC, #CC, #C3, #1C, #CC, #CC, #C3, #1C, #CC, #CC, #C3
            db #1C, #CC, #CC, #C3, #1C, #CC, #CC, #C3, #1C, #CC, #CC, #C3, #F3, #33, #33, #33
            db #00, #00, #00, #00, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #66, #66, #66, #6A, #66, #66, #66, #69, #66, #66, #66, #69
            db #66, #66, #66, #69, #66, #66, #66, #69, #66, #66, #66, #6A, #00, #00, #00, #00
            db #00, #00, #00, #00, #66, #66, #66, #AA, #66, #66, #66, #99, #66, #66, #66, #99
            db #66, #66, #66, #99, #66, #66, #66, #99, #66, #66, #66, #AA, #00, #00, #00, #00
            db #00, #00, #00, #00, #66, #66, #6A, #AA, #66, #66, #69, #99, #66, #66, #69, #99
            db #66, #66, #69, #99, #66, #66, #69, #99, #66, #66, #6A, #AA, #00, #00, #00, #00
            db #00, #00, #00, #00, #66, #66, #AA, #AA, #66, #66, #99, #99, #66, #66, #99, #99
            db #66, #66, #99, #99, #66, #66, #99, #99, #66, #66, #AA, #AA, #00, #00, #00, #00
            db #00, #00, #00, #00, #66, #6A, #AA, #AA, #66, #69, #99, #99, #66, #69, #99, #99
            db #66, #69, #99, #99, #66, #69, #99, #99, #66, #6A, #AA, #AA, #00, #00, #00, #00
            db #00, #00, #00, #00, #66, #AA, #AA, #AA, #66, #99, #99, #99, #66, #99, #99, #99
            db #66, #99, #99, #99, #66, #99, #99, #99, #66, #AA, #AA, #AA, #00, #00, #00, #00
            db #00, #00, #00, #00, #6A, #AA, #AA, #AA, #69, #99, #99, #99, #69, #99, #99, #99
            db #69, #99, #99, #99, #69, #99, #99, #99, #6A, #AA, #AA, #AA, #00, #00, #00, #00
            db #00, #00, #00, #00, #AA, #AA, #AA, #AA, #99, #99, #99, #99, #99, #99, #99, #99
            db #99, #99, #99, #99, #99, #99, #99, #99, #AA, #AA, #AA, #AA, #00, #00, #00, #00
            db 0, 0
pats:
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #F0, #44, #44, #FF, #FF, #FF, #FF, #FF, #F0, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #F0, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #42, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #22, #20, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #00, #00, #FF, #FF, #FF, #22, #22, #50, #AA, #AA, #0F, #FF, #FF
            db #22, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #50, #AA, #AA, #0F, #FF, #FF
            db #55, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #55, #22, #22, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #06, #35, #55, #55
            db #FF, #FF, #FF, #FF, #03, #55, #55, #55, #FF, #FF, #FF, #FF, #03, #55, #55, #55
            db #FF, #FF, #FF, #FF, #06, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #FF, #05, #57, #77
            db #FF, #FF, #FF, #FF, #F0, #85, #57, #77, #FF, #FF, #FF, #FF, #F0, #88, #85, #77
            db #55, #55, #52, #22, #22, #0F, #FF, #FF, #15, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #05, #22, #50, #FF, #FF, #FF
            db #55, #55, #00, #00, #0F, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #99, #0F, #FF, #FF, #FF, #FF, #FF, #77, #75, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #75, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #08, #88, #88, #87, #FF, #FF, #FF, #FF, #08, #88, #88, #87
            db #FF, #FF, #FF, #F0, #88, #88, #88, #80, #FF, #FF, #FF, #F0, #88, #88, #88, #80
            db #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F
            db #FF, #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #80, #FF
            db #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #07, #77, #77, #70, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF
            db #F0, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #FF, #07, #77, #77, #00, #FF, #FF, #FF, #FF, #07, #79, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00
            db #FF, #FF, #FF, #FF, #FF, #F0, #04, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #F0, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #F0, #52, #22, #FF, #FF, #FF, #FF, #FF, #F0, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #00, #00, #0F, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #42, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #20, #22, #0F, #FF, #FF, #FF, #FF
            db #22, #22, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #00, #00, #FF, #FF, #FF
            db #22, #22, #50, #AA, #AA, #0F, #FF, #FF, #22, #55, #50, #AA, #AA, #0F, #FF, #FF
            db #55, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #50, #AA, #AA, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #51
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #06, #35, #55, #55, #FF, #FF, #FF, #FF, #03, #55, #55, #55
            db #FF, #FF, #FF, #FF, #03, #55, #55, #55, #FF, #FF, #FF, #FF, #06, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #57, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #85, #57, #77, #FF, #FF, #FF, #FF, #F0, #85, #55, #77
            db #55, #55, #55, #22, #22, #0F, #FF, #FF, #55, #55, #52, #22, #22, #0F, #FF, #FF
            db #15, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #05, #22, #50, #FF, #FF, #FF, #55, #55, #00, #00, #0F, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #75, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #99, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #75, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #08, #88, #85, #77, #FF, #FF, #FF, #FF, #08, #88, #88, #87
            db #FF, #FF, #FF, #F0, #88, #88, #88, #87, #FF, #FF, #FF, #F0, #88, #88, #88, #80
            db #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F
            db #FF, #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #80, #FF
            db #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #77, #77, #70, #FF, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #07, #77, #77, #70, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF
            db #F0, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #FF, #07, #77, #77, #00, #FF, #FF, #FF, #FF, #07, #79, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #F0, #44, #44, #FF, #FF, #FF, #FF, #FF, #F0, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #F0, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #42, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #22, #20, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #00, #00, #FF, #FF, #FF, #22, #22, #50, #AA, #AA, #0F, #FF, #FF
            db #22, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #50, #AA, #AA, #0F, #FF, #FF
            db #55, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #55, #22, #22, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #06, #35, #55, #55
            db #FF, #FF, #FF, #FF, #03, #55, #55, #55, #FF, #FF, #FF, #FF, #03, #55, #55, #55
            db #FF, #FF, #FF, #FF, #06, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #FF, #05, #57, #77
            db #FF, #FF, #FF, #FF, #FF, #05, #57, #77, #FF, #FF, #FF, #FF, #FF, #08, #85, #77
            db #55, #55, #52, #22, #22, #0F, #FF, #FF, #15, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #05, #22, #50, #FF, #FF, #FF
            db #55, #55, #00, #00, #0F, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #99, #0F, #FF, #FF, #FF, #FF, #FF, #77, #75, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #75, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #08, #88, #77, #FF, #FF, #FF, #FF, #F0, #88, #88, #77
            db #FF, #FF, #FF, #FF, #F0, #88, #88, #87, #FF, #FF, #FF, #FF, #F0, #88, #88, #87
            db #FF, #FF, #FF, #FF, #F0, #88, #88, #88, #FF, #FF, #FF, #FF, #F0, #88, #88, #88
            db #FF, #FF, #FF, #FF, #FF, #08, #88, #87, #FF, #FF, #FF, #FF, #FF, #08, #88, #87
            db #FF, #FF, #FF, #FF, #FF, #08, #88, #87, #FF, #FF, #FF, #FF, #FF, #F0, #88, #77
            db #FF, #FF, #FF, #FF, #FF, #F0, #88, #77, #FF, #FF, #FF, #FF, #FF, #F0, #88, #79
            db #FF, #FF, #FF, #FF, #FF, #F0, #87, #99, #FF, #FF, #FF, #FF, #FF, #F0, #87, #99
            db #FF, #FF, #FF, #FF, #FF, #FF, #08, #79, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #87
            db #77, #77, #70, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #70, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #99, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #99, #99, #90, #FF, #FF, #FF, #FF, #FF, #99, #99, #90, #FF, #FF, #FF, #FF, #FF
            db #99, #99, #0F, #FF, #FF, #FF, #FF, #FF, #70, #00, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #F0, #44, #44, #FF, #FF, #FF, #FF, #FF, #F0, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #F0, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #42, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #22, #20, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #00, #00, #FF, #FF, #FF, #22, #22, #50, #AA, #AA, #0F, #FF, #FF
            db #22, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #50, #AA, #AA, #0F, #FF, #FF
            db #55, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #55, #22, #22, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #06, #35, #55, #55
            db #FF, #FF, #FF, #FF, #03, #55, #55, #55, #FF, #FF, #FF, #FF, #03, #55, #55, #55
            db #FF, #FF, #FF, #FF, #06, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #F0, #85, #57, #77
            db #FF, #FF, #FF, #FF, #08, #85, #55, #77, #FF, #FF, #FF, #F0, #88, #88, #85, #57
            db #55, #55, #52, #22, #22, #0F, #FF, #FF, #15, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #05, #22, #50, #FF, #FF, #FF
            db #55, #55, #00, #00, #0F, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #79, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #88, #88, #88, #80, #FF, #FF, #FF, #08, #88, #88, #88, #0F
            db #FF, #FF, #F0, #88, #88, #88, #88, #0F, #FF, #FF, #F0, #88, #88, #88, #80, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #08, #88, #88, #88, #0F, #FF
            db #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF
            db #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #80, #FF, #FF, #FF
            db #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #99, #99, #90, #FF, #FF, #FF
            db #F0, #89, #99, #99, #99, #0F, #FF, #FF, #F0, #89, #99, #99, #99, #0F, #FF, #FF
            db #FF, #08, #99, #99, #90, #FF, #FF, #FF, #FF, #F0, #88, #00, #0F, #FF, #FF, #FF
            db #77, #77, #77, #77, #0F, #FF, #FF, #FF, #07, #77, #77, #77, #70, #FF, #FF, #FF
            db #07, #77, #77, #77, #70, #FF, #FF, #FF, #F0, #77, #77, #77, #70, #FF, #FF, #FF
            db #FF, #07, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF
            db #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF
            db #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF
            db #FF, #FF, #F0, #77, #77, #77, #00, #FF, #FF, #FF, #F0, #77, #79, #99, #99, #0F
            db #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90
            db #FF, #FF, #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #F0, #44, #44, #FF, #FF, #FF, #FF, #FF, #F0, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #F0, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #06, #55, #55, #55
            db #FF, #FF, #FF, #FF, #03, #55, #55, #55, #FF, #FF, #FF, #FF, #03, #55, #55, #55
            db #44, #42, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #22, #20, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #00, #00, #FF, #FF, #FF, #22, #22, #50, #AA, #AA, #0F, #FF, #FF
            db #22, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #50, #AA, #AA, #0F, #FF, #FF
            db #55, #55, #50, #AA, #AA, #0F, #FF, #FF, #55, #55, #55, #22, #22, #0F, #FF, #FF
            db #55, #55, #52, #22, #22, #0F, #FF, #FF, #15, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #52, #22, #20, #FF, #FF, #FF
            db #55, #55, #52, #22, #20, #FF, #FF, #FF, #55, #55, #05, #22, #50, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #06, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #57, #77
            db #FF, #FF, #FF, #00, #08, #99, #77, #77, #FF, #FF, #F0, #88, #88, #99, #77, #77
            db #FF, #FF, #08, #88, #88, #55, #77, #77, #FF, #FF, #08, #88, #88, #55, #77, #77
            db #FF, #FF, #08, #88, #88, #85, #57, #77, #FF, #FF, #08, #88, #88, #85, #55, #55
            db #FF, #FF, #08, #88, #88, #80, #05, #55, #FF, #FF, #08, #88, #88, #80, #F0, #00
            db #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #55, #55, #00, #00, #0F, #FF, #FF, #FF, #77, #77, #00, #00, #0F, #FF, #FF, #FF
            db #77, #77, #77, #77, #70, #FF, #FF, #FF, #77, #77, #77, #77, #77, #0F, #FF, #FF
            db #77, #77, #77, #77, #77, #0F, #FF, #FF, #77, #77, #77, #77, #77, #0F, #FF, #FF
            db #77, #77, #77, #77, #77, #0F, #FF, #FF, #55, #77, #77, #77, #70, #FF, #FF, #FF
            db #50, #07, #77, #77, #70, #FF, #FF, #FF, #0F, #07, #77, #77, #70, #FF, #FF, #FF
            db #FF, #07, #77, #77, #0F, #FF, #FF, #FF, #FF, #07, #99, #99, #90, #FF, #FF, #FF
            db #F0, #79, #99, #99, #99, #0F, #FF, #FF, #F0, #79, #99, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #90, #FF, #FF, #FF, #FF, #F0, #77, #00, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #F0, #44, #44, #FF, #FF, #FF, #FF, #FF, #F0, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #F0, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #00, #FF, #FF, #FF, #FF
            db #44, #42, #AA, #AA, #0F, #FF, #FF, #FF, #22, #22, #AA, #AA, #0F, #FF, #FF, #FF
            db #22, #20, #AA, #AA, #0F, #FF, #FF, #FF, #22, #22, #AA, #AA, #0F, #FF, #FF, #FF
            db #22, #22, #22, #22, #0F, #FF, #FF, #FF, #22, #22, #22, #22, #0F, #FF, #FF, #FF
            db #22, #55, #22, #22, #0F, #FF, #FF, #FF, #55, #55, #22, #22, #0F, #FF, #FF, #FF
            db #55, #55, #22, #22, #0F, #FF, #FF, #FF, #55, #55, #22, #22, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #06, #35, #55, #55
            db #FF, #FF, #FF, #FF, #03, #55, #55, #55, #FF, #FF, #FF, #FF, #03, #55, #55, #55
            db #FF, #FF, #FF, #FF, #06, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #08, #55, #77, #77, #FF, #FF, #FF, #F0, #88, #85, #57, #77
            db #FF, #FF, #FF, #08, #88, #85, #55, #57, #FF, #FF, #FF, #08, #88, #88, #85, #55
            db #55, #55, #52, #25, #0F, #FF, #FF, #FF, #11, #55, #50, #00, #FF, #FF, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #79, #00, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #77, #00, #FF, #FF, #FF, #FF, #77, #77, #77, #77, #0F, #FF, #FF, #FF
            db #77, #77, #77, #77, #70, #FF, #FF, #FF, #77, #77, #77, #77, #70, #FF, #FF, #FF
            db #77, #77, #77, #77, #70, #FF, #FF, #FF, #50, #77, #77, #77, #70, #FF, #FF, #FF
            db #FF, #FF, #FF, #08, #88, #88, #88, #00, #FF, #FF, #FF, #08, #88, #88, #80, #F0
            db #FF, #FF, #FF, #08, #88, #88, #0F, #07, #FF, #FF, #FF, #08, #88, #88, #0F, #07
            db #FF, #FF, #FF, #08, #88, #88, #00, #79, #FF, #FF, #FF, #08, #99, #99, #90, #79
            db #FF, #FF, #F0, #89, #99, #99, #99, #07, #FF, #FF, #F0, #89, #99, #99, #99, #00
            db #FF, #FF, #FF, #08, #99, #99, #90, #FF, #FF, #FF, #FF, #F0, #88, #00, #0F, #FF
            db #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #07, #77, #77, #77, #0F, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #99, #99, #90, #FF, #FF, #FF, #FF, #FF
            db #99, #99, #99, #0F, #FF, #FF, #FF, #FF, #99, #99, #99, #0F, #FF, #FF, #FF, #FF
            db #99, #99, #90, #FF, #FF, #FF, #FF, #FF, #77, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #00, #04, #FF, #FF, #FF, #FF, #FF, #00, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #42
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #42, #FF, #FF, #FF, #FF, #FF, #F0, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #F0, #22, #22, #FF, #FF, #FF, #FF, #FF, #05, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #52, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #0F, #FF, #FF, #FF, #FF, #FF, #44, #44, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #0F, #FF, #FF, #FF, #FF, #FF, #44, #44, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #02, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #25, #50, #FF, #FF, #FF, #00, #00
            db #25, #55, #50, #00, #00, #00, #AA, #AA, #55, #55, #55, #55, #52, #22, #AA, #AA
            db #15, #55, #55, #55, #22, #22, #AA, #AA, #15, #55, #55, #55, #22, #22, #AA, #AA
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #F0, #35, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #FF, #05, #57, #77
            db #FF, #FF, #FF, #FF, #F0, #85, #57, #77, #FF, #FF, #FF, #FF, #F0, #88, #85, #77
            db #15, #55, #55, #55, #52, #22, #00, #00, #11, #55, #50, #00, #00, #00, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #99, #0F, #FF, #FF, #FF, #FF, #FF, #77, #75, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #75, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #08, #88, #88, #87, #FF, #FF, #FF, #FF, #08, #88, #88, #87
            db #FF, #FF, #FF, #F0, #88, #88, #88, #80, #FF, #FF, #FF, #F0, #88, #88, #88, #80
            db #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F
            db #FF, #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #80, #FF
            db #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #07, #77, #77, #70, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF
            db #F0, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #FF, #07, #77, #77, #00, #FF, #FF, #FF, #FF, #07, #79, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #F0, #00, #00, #FF, #FF, #FF, #FF, #00, #04, #44, #44
            db #FF, #FF, #FF, #00, #44, #44, #44, #44, #FF, #FF, #F0, #44, #44, #44, #44, #44
            db #FF, #FF, #F0, #44, #44, #44, #44, #44, #FF, #FF, #F0, #44, #44, #44, #44, #22
            db #FF, #FF, #F0, #44, #44, #42, #22, #22, #FF, #FF, #FF, #04, #44, #42, #22, #02
            db #FF, #FF, #FF, #F0, #22, #22, #22, #22, #FF, #FF, #FF, #F0, #22, #22, #22, #22
            db #FF, #FF, #FF, #F0, #52, #22, #22, #25, #FF, #FF, #FF, #F0, #55, #52, #25, #55
            db #FF, #FF, #FF, #F0, #55, #55, #55, #55, #FF, #FF, #FF, #F0, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #20, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #20, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #50, #F0, #00, #0F, #FF, #FF, #FF, #FF
            db #55, #0A, #AA, #A0, #FF, #FF, #FF, #FF, #55, #0A, #AA, #A0, #FF, #FF, #FF, #FF
            db #55, #0A, #AA, #A0, #FF, #FF, #FF, #FF, #55, #2A, #AA, #A0, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #06, #55, #55, #15, #55, #FF, #FF, #FF, #06, #55, #55, #15, #55
            db #FF, #FF, #F0, #63, #55, #55, #51, #55, #FF, #FF, #06, #33, #55, #55, #55, #55
            db #FF, #FF, #03, #33, #55, #55, #55, #55, #FF, #FF, #03, #33, #35, #55, #55, #55
            db #FF, #FF, #06, #33, #65, #55, #55, #55, #FF, #FF, #F0, #00, #05, #55, #55, #55
            db #FF, #FF, #FF, #FF, #05, #55, #55, #57, #FF, #FF, #FF, #FF, #05, #55, #77, #77
            db #FF, #FF, #FF, #FF, #09, #97, #77, #77, #FF, #FF, #FF, #FF, #09, #97, #77, #77
            db #FF, #FF, #FF, #FF, #05, #57, #77, #77, #FF, #FF, #FF, #FF, #05, #57, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #55, #22, #22, #0F, #FF, #FF, #FF, #FF, #55, #22, #22, #0F, #FF, #FF, #00, #FF
            db #52, #22, #22, #0F, #FF, #00, #77, #00, #52, #22, #20, #FF, #00, #77, #99, #99
            db #52, #22, #20, #F0, #77, #79, #99, #99, #55, #22, #50, #07, #77, #79, #99, #99
            db #55, #50, #77, #77, #77, #77, #99, #99, #57, #77, #77, #77, #77, #77, #77, #00
            db #77, #77, #77, #77, #77, #77, #00, #FF, #77, #77, #77, #77, #77, #70, #FF, #FF
            db #77, #77, #77, #77, #70, #0F, #FF, #FF, #77, #77, #77, #77, #0F, #FF, #FF, #FF
            db #77, #77, #70, #00, #FF, #FF, #FF, #FF, #77, #70, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #88, #55, #55, #FF, #FF, #FF, #FF, #F0, #88, #88, #88
            db #FF, #FF, #FF, #FF, #F0, #88, #88, #88, #FF, #FF, #FF, #FF, #F0, #88, #88, #88
            db #FF, #FF, #FF, #FF, #F0, #88, #88, #88, #FF, #FF, #FF, #FF, #F0, #88, #88, #88
            db #FF, #FF, #FF, #FF, #F0, #88, #88, #88, #FF, #FF, #FF, #FF, #F0, #88, #88, #80
            db #FF, #FF, #FF, #FF, #F0, #88, #88, #80, #FF, #FF, #FF, #FF, #F0, #88, #88, #80
            db #FF, #FF, #FF, #FF, #F0, #88, #88, #80, #FF, #FF, #FF, #FF, #F0, #89, #99, #99
            db #FF, #FF, #FF, #FF, #08, #99, #99, #99, #FF, #FF, #FF, #FF, #08, #99, #99, #99
            db #FF, #FF, #FF, #FF, #F0, #89, #99, #99, #FF, #FF, #FF, #FF, #FF, #08, #80, #00
            db #80, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #90, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #90, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #44, #FF, #FF, #FF, #FF, #FF, #04, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #F0, #44, #44, #FF, #FF, #FF, #FF, #FF, #F0, #52, #22
            db #FF, #FF, #FF, #FF, #FF, #F0, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #51
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #51, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #05, #55, #55, #55
            db #FF, #FF, #FF, #FF, #05, #55, #55, #55, #FF, #FF, #FF, #FF, #05, #55, #55, #55
            db #44, #42, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #22, #20, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #50, #FF, #FF, #FF, #FF, #FF
            db #22, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #00, #FF, #FF, #FF, #FF
            db #55, #55, #AA, #AA, #0F, #FF, #FF, #FF, #55, #55, #AA, #AA, #0F, #FF, #FF, #FF
            db #55, #55, #AA, #AA, #0F, #FF, #FF, #FF, #55, #52, #AA, #AA, #0F, #FF, #FF, #FF
            db #55, #52, #22, #20, #FF, #FF, #FF, #FF, #55, #22, #22, #20, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #05, #55, #55, #55, #FF, #FF, #FF, #FF, #05, #55, #55, #55
            db #FF, #FF, #FF, #00, #55, #57, #77, #75, #FF, #FF, #F0, #88, #99, #77, #77, #77
            db #FF, #FF, #08, #88, #99, #77, #77, #77, #FF, #FF, #08, #88, #55, #77, #77, #77
            db #FF, #FF, #08, #88, #55, #77, #77, #77, #FF, #FF, #08, #88, #85, #57, #77, #77
            db #FF, #FF, #08, #88, #85, #55, #55, #77, #FF, #F0, #88, #88, #88, #05, #55, #50
            db #FF, #F0, #88, #88, #80, #F0, #00, #0F, #FF, #F0, #89, #99, #99, #0F, #FF, #FF
            db #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF, #FF
            db #55, #22, #22, #0F, #FF, #FF, #FF, #FF, #55, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #55, #52, #25, #0F, #FF, #FF, #FF, #FF, #77, #00, #00, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #00, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #77, #77, #77, #77, #00, #FF, #FF, #FF, #77, #77, #77, #77, #77, #0F, #FF, #FF
            db #77, #77, #77, #77, #77, #70, #0F, #FF, #77, #77, #77, #77, #77, #77, #70, #00
            db #00, #07, #77, #77, #77, #79, #99, #99, #FF, #F0, #00, #77, #77, #99, #99, #99
            db #FF, #FF, #FF, #07, #77, #99, #99, #99, #FF, #FF, #FF, #F0, #07, #79, #99, #99
            db #FF, #FF, #FF, #FF, #F0, #07, #70, #00, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #00, #04
            db #FF, #FF, #FF, #FF, #FF, #00, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #42, #FF, #FF, #FF, #FF, #FF, #04, #44, #42
            db #FF, #FF, #FF, #FF, #FF, #F0, #22, #22, #FF, #FF, #FF, #FF, #FF, #05, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #52
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #44, #44, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #0F, #FF, #FF, #FF, #FF, #FF, #44, #44, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #0F, #FF, #FF, #FF, #FF, #FF, #44, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #0F, #FF, #FF, #FF, #FF, #22, #0A, #AA, #A0, #FF, #FF, #FF, #FF
            db #22, #2A, #AA, #A0, #FF, #FF, #FF, #FF, #22, #2A, #AA, #A0, #FF, #FF, #FF, #FF
            db #22, #2A, #AA, #A0, #FF, #FF, #FF, #FF, #55, #52, #22, #20, #FF, #FF, #FF, #FF
            db #55, #52, #22, #20, #FF, #FF, #FF, #FF, #55, #52, #22, #20, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #51, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #FF, #05, #57, #77
            db #FF, #FF, #FF, #FF, #F0, #85, #57, #77, #FF, #FF, #FF, #FF, #F0, #88, #85, #77
            db #55, #52, #22, #20, #FF, #FF, #FF, #FF, #15, #52, #22, #20, #FF, #FF, #FF, #FF
            db #55, #52, #22, #20, #FF, #FF, #FF, #FF, #55, #52, #22, #20, #FF, #FF, #FF, #FF
            db #55, #52, #22, #20, #FF, #FF, #FF, #FF, #55, #52, #22, #20, #FF, #FF, #FF, #FF
            db #55, #55, #22, #50, #FF, #FF, #FF, #FF, #55, #55, #00, #0F, #FF, #FF, #FF, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #99, #0F, #FF, #FF, #FF, #FF, #FF, #77, #75, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #75, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #08, #88, #88, #87, #FF, #FF, #FF, #FF, #08, #88, #88, #87
            db #FF, #FF, #FF, #F0, #88, #88, #88, #80, #FF, #FF, #FF, #F0, #88, #88, #88, #80
            db #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F
            db #FF, #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #80, #FF
            db #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #07, #77, #77, #70, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF
            db #F0, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #FF, #07, #77, #77, #00, #FF, #FF, #FF, #FF, #07, #79, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F
            db #FF, #FF, #FF, #F0, #00, #44, #44, #40, #FF, #FF, #F0, #04, #44, #44, #44, #40
            db #FF, #FF, #04, #44, #44, #44, #44, #40, #FF, #FF, #04, #44, #44, #44, #44, #40
            db #FF, #FF, #04, #44, #44, #44, #42, #20, #FF, #FF, #04, #44, #44, #22, #22, #22
            db #F0, #00, #00, #44, #44, #22, #20, #22, #0A, #AA, #A0, #02, #22, #22, #22, #25
            db #0A, #AA, #A0, #02, #22, #22, #22, #25, #0A, #AA, #A0, #05, #22, #22, #22, #55
            db #0A, #AA, #A3, #05, #55, #22, #55, #55, #F0, #33, #33, #65, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF, #FF
            db #FF, #FF, #0A, #AA, #A0, #FF, #FF, #FF, #0F, #FF, #0A, #AA, #A0, #FF, #FF, #FF
            db #0F, #F0, #2A, #AA, #A0, #FF, #FF, #FF, #0F, #F0, #2A, #AA, #A0, #FF, #FF, #FF
            db #00, #02, #22, #22, #0F, #FF, #FF, #FF, #55, #52, #22, #20, #FF, #FF, #FF, #FF
            db #55, #22, #22, #20, #FF, #FF, #FF, #FF, #55, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #F0, #33, #33, #65, #55, #55, #55, #55, #FF, #03, #33, #35, #55, #51, #55, #55
            db #FF, #03, #33, #35, #55, #51, #55, #55, #FF, #06, #33, #66, #55, #55, #11, #55
            db #FF, #F0, #00, #00, #55, #55, #55, #55, #FF, #FF, #FF, #F0, #55, #55, #55, #55
            db #FF, #FF, #FF, #F0, #55, #55, #55, #55, #FF, #FF, #FF, #F0, #55, #55, #55, #55
            db #FF, #FF, #FF, #F0, #55, #55, #55, #55, #FF, #FF, #FF, #FF, #05, #55, #77, #77
            db #FF, #FF, #FF, #FF, #09, #97, #77, #77, #FF, #FF, #FF, #FF, #09, #97, #77, #77
            db #FF, #FF, #FF, #FF, #05, #57, #77, #77, #FF, #FF, #FF, #FF, #05, #57, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #08, #55, #57, #77
            db #55, #52, #25, #0F, #FF, #FF, #FF, #FF, #55, #55, #00, #FF, #FF, #FF, #FF, #FF
            db #55, #00, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #79, #90, #FF, #FF, #FF, #FF, #FF, #FF, #77, #90, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #50, #FF, #FF, #FF, #FF, #FF, #FF, #77, #70, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #08, #88, #57, #77, #FF, #FF, #FF, #FF, #08, #88, #88, #77
            db #FF, #FF, #FF, #F0, #88, #88, #88, #87, #FF, #FF, #FF, #F0, #88, #88, #88, #00
            db #FF, #FF, #FF, #F0, #88, #88, #88, #00, #FF, #FF, #FF, #F0, #88, #88, #88, #0F
            db #FF, #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #80, #FF
            db #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #77, #77, #70, #FF, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF
            db #F0, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #FF, #07, #77, #77, #00, #FF, #FF, #FF, #FF, #07, #79, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF
            db #FF, #FF, #FF, #0A, #AA, #A0, #FF, #FF, #FF, #FF, #FF, #0A, #AA, #A2, #00, #0F
            db #FF, #FF, #FF, #0A, #AA, #A2, #22, #50, #FF, #FF, #FF, #0A, #AA, #A2, #22, #20
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #00, #00, #22, #22, #20, #FF, #00, #04, #44, #44, #55, #22, #50
            db #00, #44, #44, #44, #44, #55, #55, #55, #44, #44, #44, #44, #45, #55, #55, #55
            db #44, #44, #44, #44, #45, #55, #55, #55, #44, #44, #44, #44, #25, #55, #55, #55
            db #44, #44, #42, #22, #25, #55, #55, #99, #04, #44, #42, #22, #02, #21, #55, #99
            db #F0, #22, #22, #22, #22, #11, #15, #55, #00, #22, #22, #22, #22, #11, #15, #55
            db #AA, #A2, #22, #22, #25, #11, #55, #55, #AA, #AA, #32, #26, #00, #00, #55, #55
            db #AA, #AA, #33, #60, #FF, #FF, #00, #00, #AA, #AA, #00, #0F, #FF, #FF, #FF, #FF
            db #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF, #0F, #FF, #FF, #07, #77, #70, #FF, #FF
            db #50, #00, #00, #77, #77, #77, #0F, #FF, #55, #55, #77, #77, #77, #77, #0F, #FF
            db #55, #57, #77, #77, #77, #77, #0F, #FF, #57, #77, #77, #77, #77, #77, #70, #FF
            db #77, #77, #77, #77, #77, #77, #77, #0F, #77, #77, #77, #77, #77, #77, #77, #0F
            db #77, #77, #77, #77, #87, #77, #77, #70, #77, #77, #77, #55, #87, #77, #77, #77
            db #57, #77, #75, #58, #88, #77, #79, #99, #55, #55, #55, #58, #88, #87, #99, #99
            db #55, #55, #50, #00, #08, #87, #99, #99, #00, #00, #0F, #FF, #F0, #88, #79, #99
            db #FF, #FF, #FF, #FF, #FF, #00, #87, #79, #FF, #FF, #FF, #FF, #FF, #FF, #08, #80
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #00, #04
            db #FF, #FF, #FF, #FF, #FF, #00, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #42, #FF, #FF, #FF, #FF, #FF, #04, #44, #42
            db #FF, #FF, #FF, #FF, #FF, #F0, #22, #22, #FF, #FF, #FF, #FF, #FF, #05, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #52
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #44, #44, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #0F, #FF, #FF, #FF, #FF, #FF, #44, #44, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #0F, #FF, #FF, #FF, #FF, #FF, #44, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #FF, #FF, #FF, #FF, #FF, #22, #02, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #50, #FF, #FF, #FF, #FF, #FF
            db #22, #25, #50, #FF, #FF, #FF, #FF, #FF, #25, #55, #50, #0F, #FF, #FF, #FF, #FF
            db #15, #55, #55, #50, #0F, #FF, #FF, #FF, #15, #55, #55, #55, #50, #00, #00, #00
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #51, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #FF, #05, #57, #77
            db #FF, #FF, #FF, #FF, #F0, #85, #57, #77, #FF, #FF, #FF, #FF, #F0, #88, #85, #77
            db #15, #55, #55, #55, #22, #22, #AA, #AA, #11, #55, #55, #52, #22, #22, #AA, #AA
            db #55, #55, #55, #52, #22, #22, #AA, #AA, #55, #55, #53, #35, #22, #22, #AA, #AA
            db #55, #55, #33, #33, #33, #AA, #AA, #00, #55, #55, #03, #33, #33, #AA, #AA, #0F
            db #55, #55, #00, #00, #00, #AA, #AA, #0F, #55, #55, #0F, #FF, #FF, #00, #00, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #99, #0F, #FF, #FF, #FF, #FF, #FF, #77, #75, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #75, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #08, #88, #88, #87, #FF, #FF, #FF, #FF, #08, #88, #88, #87
            db #FF, #FF, #FF, #F0, #88, #88, #88, #80, #FF, #FF, #FF, #F0, #88, #88, #88, #80
            db #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F
            db #FF, #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #80, #FF
            db #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #07, #77, #77, #70, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF
            db #F0, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #FF, #07, #77, #77, #00, #FF, #FF, #FF, #FF, #07, #79, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #00, #04
            db #FF, #FF, #FF, #FF, #FF, #00, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #44, #FF, #FF, #FF, #FF, #F0, #44, #44, #44
            db #FF, #FF, #FF, #FF, #F0, #44, #44, #42, #FF, #FF, #FF, #FF, #FF, #04, #44, #42
            db #FF, #FF, #FF, #FF, #FF, #F0, #22, #22, #FF, #FF, #FF, #FF, #FF, #05, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #05, #52, #22, #FF, #FF, #FF, #FF, #FF, #05, #55, #52
            db #FF, #FF, #FF, #FF, #FF, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #05, #55, #51
            db #F0, #AA, #AA, #0F, #FF, #FF, #FF, #FF, #F0, #AA, #AA, #0F, #FF, #FF, #FF, #FF
            db #00, #AA, #AA, #0F, #FF, #FF, #FF, #FF, #44, #AA, #AA, #0F, #FF, #FF, #FF, #FF
            db #44, #22, #22, #0F, #FF, #FF, #FF, #FF, #44, #22, #22, #20, #FF, #FF, #FF, #FF
            db #44, #42, #22, #20, #FF, #FF, #FF, #FF, #44, #22, #22, #20, #FF, #FF, #FF, #FF
            db #22, #22, #22, #20, #FF, #FF, #FF, #FF, #22, #52, #22, #20, #FF, #FF, #FF, #FF
            db #22, #55, #22, #50, #FF, #FF, #FF, #FF, #25, #55, #55, #0F, #FF, #FF, #FF, #FF
            db #25, #55, #55, #0F, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #51, #FF, #FF, #FF, #FF, #F0, #65, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #65, #55, #55, #FF, #FF, #FF, #FF, #06, #35, #55, #55
            db #FF, #FF, #FF, #FF, #03, #55, #55, #55, #FF, #FF, #FF, #FF, #03, #55, #55, #55
            db #FF, #FF, #FF, #FF, #06, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #57, #77, #FF, #FF, #FF, #FF, #F0, #99, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #99, #77, #77, #FF, #FF, #FF, #FF, #F0, #55, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #55, #77, #77, #FF, #FF, #FF, #FF, #FF, #05, #57, #77
            db #FF, #FF, #FF, #FF, #F0, #85, #57, #77, #FF, #FF, #FF, #FF, #F0, #88, #85, #77
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #11, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #75, #55, #0F, #FF, #FF, #FF, #FF, #FF, #77, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #99, #0F, #FF, #FF, #FF, #FF, #FF, #77, #75, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #75, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #0F, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #08, #88, #88, #87, #FF, #FF, #FF, #FF, #08, #88, #88, #87
            db #FF, #FF, #FF, #F0, #88, #88, #88, #80, #FF, #FF, #FF, #F0, #88, #88, #88, #80
            db #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F
            db #FF, #FF, #FF, #08, #88, #88, #80, #FF, #FF, #FF, #FF, #08, #88, #88, #80, #FF
            db #FF, #FF, #FF, #08, #88, #88, #0F, #FF, #FF, #FF, #F0, #88, #88, #88, #0F, #FF
            db #FF, #FF, #F0, #88, #88, #88, #0F, #FF, #FF, #FF, #F0, #89, #99, #99, #0F, #FF
            db #FF, #FF, #08, #99, #99, #99, #90, #FF, #FF, #FF, #08, #99, #99, #99, #90, #FF
            db #FF, #FF, #F0, #89, #99, #99, #0F, #FF, #FF, #FF, #FF, #08, #80, #00, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #77, #77, #77, #70, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #07, #77, #77, #70, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF, #FF
            db #F0, #77, #77, #70, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #F0, #77, #77, #77, #0F, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF, #FF, #FF
            db #FF, #07, #77, #77, #00, #FF, #FF, #FF, #FF, #07, #79, #99, #99, #0F, #FF, #FF
            db #FF, #07, #99, #99, #99, #90, #FF, #FF, #FF, #07, #99, #99, #99, #90, #FF, #FF
            db #FF, #F0, #79, #99, #99, #0F, #FF, #FF, #FF, #FF, #07, #70, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #CF, #FF, #FF, #FC, #FF, #FF
            db #FF, #FF, #CC, #BB, #BB, #CC, #FF, #FF, #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF
            db #FF, #FB, #BB, #CC, #CC, #BB, #BF, #FF, #FF, #BB, #BC, #11, #CC, #CB, #BB, #FF
            db #FF, #BB, #C1, #11, #1C, #CC, #BB, #FF, #CC, #BB, #C1, #11, #1C, #CC, #BB, #CC
            db #CC, #BB, #CC, #11, #CC, #CC, #BB, #CC, #FF, #BB, #CC, #CC, #CC, #CC, #BB, #FF
            db #FF, #BB, #BC, #CC, #CC, #CB, #BB, #FF, #FF, #FB, #BB, #CC, #CC, #BB, #BF, #FF
            db #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF, #FF, #FF, #CC, #BB, #BB, #CC, #FF, #FF
            db #FF, #FF, #CF, #FF, #FF, #FC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FB, #BB, #BB, #BF, #FF, #CF
            db #CC, #CF, #BB, #BB, #BB, #BB, #FC, #CF, #FF, #CB, #BB, #11, #CC, #BB, #BF, #FF
            db #FF, #FB, #B1, #11, #1C, #CB, #BF, #FF, #FF, #FB, #B1, #11, #1C, #CB, #BF, #FF
            db #FF, #FB, #BC, #11, #CC, #CB, #BF, #FF, #FF, #FB, #BC, #CC, #CC, #CB, #BF, #FF
            db #FF, #FB, #BB, #CC, #CC, #BB, #BC, #FF, #FC, #CF, #BB, #BB, #BB, #BB, #FC, #CC
            db #FC, #FF, #FB, #BB, #BB, #BF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #CF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #CF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF
            db #FF, #FF, #FD, #FE, #EF, #DF, #FF, #FF, #FF, #FF, #DD, #DE, #ED, #DD, #FF, #FF
            db #FF, #FF, #FD, #D1, #1D, #DF, #FF, #FF, #EE, #EE, #EE, #11, #11, #EE, #EE, #EE
            db #EE, #EE, #EE, #11, #11, #EE, #EE, #EE, #FF, #FF, #FD, #D1, #1D, #DF, #FF, #FF
            db #FF, #FF, #DD, #DE, #ED, #DD, #FF, #FF, #FF, #FF, #FD, #FE, #EF, #DF, #FF, #FF
            db #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF
            db #FF, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #FF, #FF, #DF, #FE, #EF, #FF, #FF
            db #FE, #FF, #FF, #DD, #FE, #FF, #FF, #FF, #FE, #EE, #FF, #DD, #EE, #FF, #FF, #FF
            db #FF, #EE, #EE, #D1, #1D, #DD, #DF, #FF, #FF, #FF, #FE, #11, #11, #DD, #FF, #FF
            db #FF, #FF, #DD, #11, #11, #EF, #FF, #FF, #FF, #FD, #DD, #D1, #1D, #EE, #EE, #FF
            db #FF, #FF, #FF, #EE, #DD, #FF, #EE, #EF, #FF, #FF, #FF, #EF, #DD, #FF, #FF, #EF
            db #FF, #FF, #FE, #EF, #FD, #FF, #FF, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #FF
            db #FF, #FF, #EE, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ld_end:
#endasm
End Sub
