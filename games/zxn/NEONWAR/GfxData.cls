' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_SPAWN = 0
Public Const S_SPAWN_N = 2
Public Const S_SHIP = 2
Public Const S_SHIP_N = 8
Public Const T_GRIDC = 1
Public Const T_GRIDT = 2
Public Const T_GRIDL = 3
Public Const T_GRIDN = 4
Public Const T_FRAMET = 5
Public Const T_FRAMEB = 6
Public Const T_FRAMEL = 7
Public Const T_FRAMER = 8
Public Const T_CORNER = 9
Public Const T_CORNER_N = 4
Public Const T_LIFE = 13
Public Const T_BOMB = 14
Public Const T_LOGO = 128
Public Const T_LOGO_N = 3
Public Const SpritePatterns = 10
Public Const SpritePalettes = 2

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
            ld e, 32                ; 2 x 16 (0 = 256)
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
            ld de, 1280
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
            db #00, #FF, #05, #06, #2B, #FC, #E7, #1F, #F0, #87, #3B, #E8, #6F, #25, #B7, #E3
spal:
            db #00, #FF, #E7, #FC, #1F, #13, #F0, #87, #4A, #B7, #3B, #6F, #93, #DB, #25, #E3
            db #00, #3B, #E7, #FC, #1F, #13, #F0, #87, #4A, #B7, #FF, #6F, #93, #DB, #25, #E3
truns:
            db 1, 14        ; tiles 1-14
            db #33, #33, #33, #33, #30, #00, #00, #00, #30, #00, #00, #00, #30, #00, #00, #00
            db #30, #00, #00, #00, #30, #00, #00, #00, #30, #00, #00, #00, #30, #00, #00, #00
            db #33, #33, #33, #33, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #30, #00, #00, #00, #30, #00, #00, #00, #30, #00, #00, #00, #30, #00, #00, #00
            db #30, #00, #00, #00, #30, #00, #00, #00, #30, #00, #00, #00, #30, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #44, #44, #44, #44
            db #22, #22, #22, #22, #11, #11, #11, #11, #22, #22, #22, #22, #44, #44, #44, #44
            db #44, #44, #44, #44, #22, #22, #22, #22, #11, #11, #11, #11, #22, #22, #22, #22
            db #44, #44, #44, #44, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F4, #21, #24, #FF, #F4, #21, #24, #FF, #F4, #21, #24, #FF, #F4, #21, #24
            db #FF, #F4, #21, #24, #FF, #F4, #21, #24, #FF, #F4, #21, #24, #FF, #F4, #21, #24
            db #42, #12, #4F, #FF, #42, #12, #4F, #FF, #42, #12, #4F, #FF, #42, #12, #4F, #FF
            db #42, #12, #4F, #FF, #42, #12, #4F, #FF, #42, #12, #4F, #FF, #42, #12, #4F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #44, #44
            db #FF, #F4, #22, #22, #FF, #F4, #21, #11, #FF, #F4, #21, #22, #FF, #F4, #21, #24
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #44, #44, #4F, #FF
            db #22, #22, #4F, #FF, #11, #12, #4F, #FF, #22, #12, #4F, #FF, #42, #12, #4F, #FF
            db #FF, #F4, #21, #24, #FF, #F4, #21, #22, #FF, #F4, #21, #11, #FF, #F4, #22, #22
            db #FF, #F4, #44, #44, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #42, #12, #4F, #FF, #22, #12, #4F, #FF, #11, #12, #4F, #FF, #22, #22, #4F, #FF
            db #44, #44, #4F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F1, #FF, #FF, #FF, #1F, #1F, #FF, #FF, #1F, #1F, #FF, #F1, #FF, #F1, #FF
            db #F1, #F1, #F1, #FF, #1F, #1F, #1F, #1F, #11, #FF, #F1, #1F, #FF, #FF, #FF, #FF
            db #FF, #F8, #8F, #FF, #FF, #8F, #F8, #FF, #F8, #F5, #5F, #8F, #8F, #55, #55, #F8
            db #8F, #55, #55, #F8, #F8, #F5, #5F, #8F, #FF, #8F, #F8, #FF, #FF, #F8, #8F, #FF
            db 33, 94        ; tiles 33-126
            db #FF, #FE, #EF, #FF, #FF, #EE, #EE, #FF, #FF, #EE, #EE, #3F, #FF, #FE, #E3, #3F
            db #FF, #FE, #E3, #FF, #FF, #FF, #33, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #33, #FF
            db #FE, #EF, #EE, #FF, #FE, #E3, #EE, #3F, #FF, #33, #F3, #3F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FE, #EF, #EE, #FF, #FE, #E3, #EE, #3F, #EE, #EE, #EE, #EF, #FE, #E3, #EE, #33
            db #EE, #EE, #EE, #EF, #FE, #E3, #EE, #33, #FE, #E3, #EE, #3F, #FF, #33, #F3, #3F
            db #FF, #EE, #FF, #FF, #FE, #EE, #EE, #FF, #EE, #33, #33, #3F, #FE, #EE, #EF, #FF
            db #FF, #33, #EE, #FF, #EE, #EE, #E3, #3F, #F3, #EE, #33, #FF, #FF, #F3, #3F, #FF
            db #FF, #FF, #FF, #FF, #EE, #FF, #FE, #EF, #EE, #3F, #EE, #33, #F3, #3E, #E3, #3F
            db #FF, #EE, #33, #FF, #FE, #E3, #3E, #EF, #EE, #33, #FE, #E3, #F3, #3F, #FF, #33
            db #FF, #EE, #EF, #FF, #FE, #E3, #EE, #FF, #FF, #EE, #E3, #3F, #FE, #EE, #3E, #EF
            db #EE, #3E, #EE, #33, #EE, #3F, #EE, #3F, #FE, #EE, #FE, #EF, #FF, #33, #3F, #33
            db #FE, #EF, #FF, #FF, #FE, #E3, #FF, #FF, #EE, #33, #FF, #FF, #F3, #3F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FE, #EF, #FF, #FF, #EE, #33, #FF, #FE, #E3, #3F, #FF, #FE, #E3, #FF, #FF
            db #FE, #E3, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #33, #FF
            db #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FE, #E3, #FF
            db #FF, #FE, #E3, #FF, #FF, #EE, #33, #FF, #FE, #E3, #3F, #FF, #FF, #33, #FF, #FF
            db #FF, #FF, #FF, #FF, #FE, #EF, #FE, #EF, #FF, #EE, #EE, #33, #EE, #EE, #EE, #EE
            db #F3, #EE, #EE, #33, #FE, #E3, #3E, #EF, #FF, #33, #FF, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #EE, #EE, #EE, #FF
            db #F3, #EE, #33, #3F, #FF, #EE, #3F, #FF, #FF, #F3, #3F, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FE, #E3, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF
            db #F3, #33, #33, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #F3, #3F, #FF
            db #FF, #FF, #FE, #EF, #FF, #FF, #EE, #33, #FF, #FE, #E3, #3F, #FF, #EE, #33, #FF
            db #FE, #E3, #3F, #FF, #EE, #33, #FF, #FF, #E3, #3F, #FF, #FF, #F3, #FF, #FF, #FF
            db #FE, #EE, #EE, #FF, #EE, #33, #3E, #EF, #EE, #3F, #EE, #E3, #EE, #3E, #EE, #E3
            db #EE, #EE, #3E, #E3, #EE, #E3, #3E, #E3, #FE, #EE, #EE, #33, #FF, #33, #33, #3F
            db #FF, #EE, #FF, #FF, #FE, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF
            db #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #EE, #EE, #EE, #FF, #F3, #33, #33, #3F
            db #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #F3, #3F, #EE, #3F, #FF, #EE, #E3, #3F
            db #FE, #E3, #33, #FF, #EE, #33, #EE, #FF, #EE, #EE, #EE, #3F, #F3, #33, #33, #3F
            db #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #F3, #3F, #EE, #3F, #FF, #EE, #E3, #3F
            db #FF, #F3, #EE, #FF, #EE, #FF, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #FF, #FE, #EE, #FF, #FF, #EE, #EE, #3F, #FE, #E3, #EE, #3F, #EE, #33, #EE, #3F
            db #EE, #EE, #EE, #EF, #F3, #33, #EE, #33, #FF, #FE, #EE, #EF, #FF, #FF, #33, #33
            db #EE, #EE, #EE, #FF, #EE, #33, #33, #3F, #EE, #EE, #EF, #FF, #F3, #33, #EE, #FF
            db #FF, #FF, #EE, #3F, #EE, #FF, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #FF, #EE, #EF, #FF, #FE, #E3, #33, #FF, #EE, #33, #FF, #FF, #EE, #EE, #EF, #FF
            db #EE, #33, #EE, #FF, #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #EE, #EE, #EE, #FF, #EE, #33, #EE, #3F, #F3, #3F, #EE, #3F, #FF, #FE, #E3, #3F
            db #FF, #EE, #33, #FF, #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #FF, #F3, #3F, #FF
            db #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F
            db #EE, #33, #EE, #FF, #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #EE, #3F, #EE, #3F, #FE, #EE, #EE, #3F
            db #FF, #33, #EE, #3F, #FF, #FE, #E3, #3F, #FE, #EE, #33, #FF, #FF, #33, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #F3, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #F3, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #F3, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FE, #E3, #3F, #FF
            db #FF, #FE, #EF, #FF, #FF, #EE, #33, #FF, #FE, #E3, #3F, #FF, #EE, #33, #FF, #FF
            db #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #33, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF, #F3, #33, #33, #3F
            db #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF, #F3, #33, #33, #3F, #FF, #FF, #FF, #FF
            db #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #EE, #FF
            db #FF, #FE, #E3, #3F, #FF, #EE, #33, #FF, #FE, #E3, #3F, #FF, #FF, #33, #FF, #FF
            db #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #F3, #3F, #EE, #3F, #FF, #FE, #E3, #3F
            db #FF, #EE, #33, #FF, #FF, #F3, #3F, #FF, #FF, #EE, #FF, #FF, #FF, #F3, #3F, #FF
            db #FE, #EE, #EE, #FF, #EE, #33, #3E, #EF, #EE, #3E, #EE, #E3, #EE, #3E, #EE, #E3
            db #EE, #3E, #EE, #E3, #EE, #3F, #33, #33, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #FF, #EE, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #EE, #3F, #EE, #3F
            db #EE, #EE, #EE, #3F, #EE, #33, #EE, #3F, #EE, #3F, #EE, #3F, #F3, #3F, #F3, #3F
            db #EE, #EE, #EE, #FF, #FE, #E3, #3E, #EF, #FE, #E3, #FE, #E3, #FE, #EE, #EE, #33
            db #FE, #E3, #3E, #EF, #FE, #E3, #FE, #E3, #EE, #EE, #EE, #33, #F3, #33, #33, #3F
            db #FF, #EE, #EE, #FF, #FE, #E3, #3E, #EF, #EE, #33, #FF, #33, #EE, #3F, #FF, #FF
            db #EE, #3F, #FF, #FF, #FE, #EF, #FE, #EF, #FF, #EE, #EE, #33, #FF, #F3, #33, #3F
            db #EE, #EE, #EF, #FF, #FE, #E3, #EE, #FF, #FE, #E3, #FE, #EF, #FE, #E3, #FE, #E3
            db #FE, #E3, #FE, #E3, #FE, #E3, #EE, #33, #EE, #EE, #E3, #3F, #F3, #33, #33, #FF
            db #EE, #EE, #EE, #EF, #FE, #E3, #33, #E3, #FE, #E3, #EF, #F3, #FE, #EE, #E3, #FF
            db #FE, #E3, #E3, #FF, #FE, #E3, #F3, #EF, #EE, #EE, #EE, #E3, #F3, #33, #33, #33
            db #EE, #EE, #EE, #EF, #FE, #E3, #33, #E3, #FE, #E3, #EF, #F3, #FE, #EE, #E3, #FF
            db #FE, #E3, #E3, #FF, #FE, #E3, #F3, #FF, #EE, #EE, #FF, #FF, #F3, #33, #3F, #FF
            db #FF, #EE, #EE, #FF, #FE, #E3, #3E, #EF, #EE, #33, #FF, #33, #EE, #3F, #FF, #FF
            db #EE, #3F, #EE, #EF, #FE, #EF, #FE, #E3, #FF, #EE, #EE, #E3, #FF, #F3, #33, #33
            db #EE, #FF, #EE, #FF, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #EE, #EE, #3F
            db #EE, #33, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #F3, #3F, #F3, #3F
            db #FE, #EE, #EF, #FF, #FF, #EE, #33, #FF, #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF
            db #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #FF, #FE, #EE, #EF, #FF, #FF, #EE, #33, #FF, #FF, #EE, #3F, #FF, #FF, #EE, #3F
            db #EE, #FF, #EE, #3F, #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #EE, #EF, #FE, #EF, #FE, #E3, #FE, #E3, #FE, #E3, #EE, #33, #FE, #EE, #E3, #3F
            db #FE, #E3, #EE, #FF, #FE, #E3, #FE, #EF, #EE, #E3, #FE, #E3, #F3, #33, #FF, #33
            db #EE, #EE, #FF, #FF, #FE, #E3, #3F, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FF, #FF
            db #FE, #E3, #FF, #EF, #FE, #E3, #FE, #E3, #EE, #EE, #EE, #E3, #F3, #33, #33, #33
            db #EE, #FF, #FE, #EF, #EE, #EF, #EE, #E3, #EE, #EE, #EE, #E3, #EE, #EE, #EE, #E3
            db #EE, #3E, #3E, #E3, #EE, #3F, #3E, #E3, #EE, #3F, #FE, #E3, #F3, #3F, #FF, #33
            db #EE, #FF, #FE, #EF, #EE, #EF, #FE, #E3, #EE, #EE, #FE, #E3, #EE, #3E, #EE, #E3
            db #EE, #3F, #EE, #E3, #EE, #3F, #FE, #E3, #EE, #3F, #FE, #E3, #F3, #3F, #FF, #33
            db #FF, #EE, #EF, #FF, #FE, #E3, #EE, #FF, #EE, #33, #FE, #EF, #EE, #3F, #FE, #E3
            db #EE, #3F, #FE, #E3, #FE, #EF, #EE, #33, #FF, #EE, #E3, #3F, #FF, #F3, #33, #FF
            db #EE, #EE, #EE, #FF, #FE, #E3, #3E, #EF, #FE, #E3, #FE, #E3, #FE, #EE, #EE, #33
            db #FE, #E3, #33, #3F, #FE, #E3, #FF, #FF, #EE, #EE, #FF, #FF, #F3, #33, #3F, #FF
            db #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F
            db #EE, #3E, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #3E, #EE, #FF, #FF, #FF, #33, #3F
            db #EE, #EE, #EE, #FF, #FE, #E3, #3E, #EF, #FE, #E3, #FE, #E3, #FE, #EE, #EE, #33
            db #FE, #E3, #EE, #3F, #FE, #E3, #FE, #EF, #EE, #E3, #FE, #E3, #F3, #33, #FF, #33
            db #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF, #EE, #EF, #F3, #3F, #FE, #EE, #FF, #FF
            db #FF, #3E, #EE, #FF, #EE, #FF, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #EE, #EE, #EE, #FF, #E3, #EE, #3E, #3F, #F3, #EE, #3F, #3F, #FF, #EE, #3F, #FF
            db #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #EE, #FF, #EE, #FF, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F
            db #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #EE, #EE, #3F, #F3, #33, #33, #3F
            db #EE, #FF, #EE, #FF, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F
            db #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #EE, #33, #FF, #FF, #F3, #3F, #FF
            db #EE, #FF, #FE, #EF, #EE, #3F, #FE, #E3, #EE, #3F, #FE, #E3, #EE, #3E, #FE, #E3
            db #EE, #EE, #EE, #E3, #EE, #E3, #EE, #E3, #EE, #33, #FE, #E3, #F3, #3F, #FF, #33
            db #EE, #FF, #FE, #EF, #EE, #3F, #FE, #E3, #FE, #EF, #EE, #33, #FF, #EE, #E3, #3F
            db #FF, #EE, #E3, #FF, #FE, #E3, #EE, #FF, #EE, #33, #FE, #EF, #F3, #3F, #FF, #33
            db #EE, #FF, #EE, #FF, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F
            db #FF, #EE, #33, #FF, #FF, #EE, #3F, #FF, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #EE, #EE, #EE, #EF, #EE, #33, #3E, #E3, #E3, #3F, #EE, #33, #F3, #FE, #E3, #3F
            db #FF, #EE, #33, #EF, #FE, #E3, #3E, #E3, #EE, #EE, #EE, #E3, #F3, #33, #33, #33
            db #FE, #EE, #EF, #FF, #FE, #E3, #33, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FF, #FF
            db #FE, #E3, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF
            db #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #E3, #FF, #FF, #FF, #F3
            db #FE, #EE, #EF, #FF, #FF, #3E, #E3, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FF
            db #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FF, #FE, #EE, #E3, #FF, #FF, #33, #33, #FF
            db #FF, #FE, #FF, #FF, #FF, #EE, #EF, #FF, #FE, #E3, #EE, #FF, #EE, #33, #FE, #EF
            db #F3, #3F, #FF, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #EE
            db #FF, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #33, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #FF, #33, #EE, #FF
            db #FE, #EE, #EE, #3F, #EE, #33, #EE, #3F, #FE, #EE, #FE, #EF, #FF, #33, #3F, #33
            db #EE, #EF, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #EE, #EE, #FF
            db #FE, #E3, #3E, #EF, #FE, #E3, #FE, #E3, #EE, #3E, #EE, #33, #F3, #3F, #33, #3F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF
            db #EE, #3F, #F3, #3F, #EE, #3F, #EE, #FF, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #FF, #FE, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FE, #EE, #EE, #3F
            db #EE, #33, #EE, #3F, #EE, #3F, #EE, #3F, #FE, #EE, #FE, #EF, #FF, #33, #3F, #33
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF
            db #EE, #EE, #EE, #3F, #EE, #33, #33, #3F, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #FF, #EE, #EF, #FF, #FE, #E3, #EE, #FF, #FE, #E3, #F3, #3F, #EE, #EE, #FF, #FF
            db #FE, #E3, #3F, #FF, #FE, #E3, #FF, #FF, #EE, #EE, #FF, #FF, #F3, #33, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #FE, #EF, #EE, #33, #EE, #33
            db #EE, #3F, #EE, #3F, #FE, #EE, #EE, #3F, #FF, #33, #EE, #3F, #EE, #EE, #E3, #3F
            db #EE, #EF, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #EE, #FF, #FE, #EE, #FE, #EF
            db #FE, #E3, #3E, #E3, #FE, #E3, #FE, #E3, #EE, #E3, #FE, #E3, #F3, #33, #FF, #33
            db #FF, #EE, #FF, #FF, #FF, #F3, #3F, #FF, #FE, #EE, #FF, #FF, #FF, #EE, #3F, #FF
            db #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #FF, #FF, #EE, #FF, #FF, #FF, #F3, #3F, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #3F
            db #FF, #FF, #EE, #3F, #EE, #FF, #EE, #3F, #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F
            db #EE, #EF, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FE, #EF, #FE, #E3, #EE, #33
            db #FE, #EE, #E3, #3F, #FE, #E3, #EE, #FF, #EE, #E3, #FE, #EF, #F3, #33, #FF, #33
            db #FE, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF
            db #FF, #EE, #3F, #FF, #FF, #EE, #3F, #FF, #FE, #EE, #EF, #FF, #FF, #33, #33, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #EE, #EE, #EF
            db #EE, #EE, #EE, #E3, #EE, #3E, #3E, #E3, #EE, #3F, #3E, #E3, #F3, #3F, #FF, #33
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EF, #FF, #EE, #33, #EE, #FF
            db #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #F3, #3F, #F3, #3F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #33, #EE, #FF
            db #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #33, #33, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FE, #EE, #FF, #FE, #EF, #3E, #EF
            db #FE, #E3, #FE, #E3, #FE, #EE, #EE, #33, #FE, #E3, #33, #3F, #EE, #EE, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #FE, #EF, #EE, #33, #EE, #33
            db #EE, #3F, #EE, #3F, #FE, #EE, #EE, #3F, #FF, #33, #EE, #3F, #FF, #FE, #EE, #EF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FE, #EE, #FF, #FE, #EE, #3E, #EF
            db #FE, #E3, #3E, #E3, #FE, #E3, #FF, #33, #EE, #EE, #FF, #FF, #F3, #33, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EE, #FF, #EE, #33, #33, #3F
            db #FE, #EE, #EF, #FF, #FF, #33, #EE, #FF, #EE, #EE, #E3, #3F, #F3, #33, #33, #FF
            db #FF, #FE, #FF, #FF, #FF, #EE, #3F, #FF, #FE, #EE, #EE, #FF, #FF, #EE, #33, #3F
            db #FF, #EE, #3F, #FF, #FF, #EE, #3E, #FF, #FF, #FE, #EF, #3F, #FF, #FF, #33, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #3F, #EE, #3F
            db #EE, #3F, #EE, #3F, #EE, #3F, #EE, #3F, #FE, #EE, #FE, #EF, #FF, #33, #3F, #33
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #3F, #EE, #3F
            db #EE, #3F, #EE, #3F, #FE, #EE, #E3, #3F, #FF, #EE, #33, #FF, #FF, #F3, #3F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FE, #EF, #EE, #3E, #FE, #E3
            db #EE, #EE, #EE, #E3, #EE, #EE, #EE, #E3, #FE, #E3, #EE, #33, #FF, #33, #F3, #3F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FE, #EF, #FE, #EF, #EE, #33
            db #FF, #EE, #E3, #3F, #FE, #E3, #EE, #FF, #EE, #33, #FE, #EF, #F3, #3F, #FF, #33
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #3F, #EE, #3F
            db #EE, #3F, #EE, #3F, #FE, #EE, #EE, #3F, #FF, #33, #EE, #3F, #EE, #EE, #E3, #3F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF, #E3, #3E, #E3, #3F
            db #F3, #EE, #33, #FF, #FE, #E3, #3E, #FF, #EE, #EE, #EE, #3F, #F3, #33, #33, #3F
            db #FF, #FE, #EE, #FF, #FF, #EE, #33, #3F, #FF, #EE, #3F, #FF, #EE, #E3, #3F, #FF
            db #F3, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #FE, #EE, #FF, #FF, #FF, #33, #3F
            db #FF, #FE, #EF, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FF, #FF, #FF, #33, #FF
            db #FF, #FE, #EF, #FF, #FF, #FE, #E3, #FF, #FF, #FE, #E3, #FF, #FF, #FF, #33, #FF
            db #EE, #EF, #FF, #FF, #F3, #EE, #FF, #FF, #FF, #EE, #3F, #FF, #FF, #FE, #EE, #FF
            db #FF, #EE, #33, #3F, #FF, #EE, #3F, #FF, #EE, #E3, #3F, #FF, #F3, #33, #FF, #FF
            db #FE, #EE, #FE, #EF, #EE, #3E, #EE, #33, #F3, #3F, #33, #3F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db 128, 3        ; tiles 128-130
            db #11, #11, #11, #1F, #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2
            db #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2, #1A, #AA, #AA, #A2, #F2, #22, #22, #22
            db #11, #11, #11, #1F, #16, #66, #66, #69, #16, #66, #66, #69, #16, #66, #66, #69
            db #16, #66, #66, #69, #16, #66, #66, #69, #16, #66, #66, #69, #F9, #99, #99, #99
            db #11, #11, #11, #1F, #15, #55, #55, #58, #15, #55, #55, #58, #15, #55, #55, #58
            db #15, #55, #55, #58, #15, #55, #55, #58, #15, #55, #55, #58, #F8, #88, #88, #88
            db 0, 0
pats:
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #11, #F1, #3F, #FF, #FF
            db #FF, #FF, #11, #FF, #FF, #11, #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #1F, #FF
            db #FF, #3F, #FF, #FF, #FF, #FF, #F3, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #F1, #1F
            db #F1, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #F3, #FF, #FF, #FF, #FF, #FF, #FF, #3F, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #1F
            db #F1, #1F, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #3F, #FF, #FF, #FF, #FF, #F3, #FF
            db #FF, #F1, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #11, #FF, #FF, #11, #FF, #FF
            db #FF, #FF, #F3, #1F, #11, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #31, #13, #1F, #FF, #FF
            db #FF, #FF, #11, #FF, #FF, #11, #FF, #FF, #FF, #F1, #3F, #FF, #FF, #F3, #1F, #FF
            db #FF, #F1, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #1F, #FF
            db #FF, #F3, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #1F, #FF
            db #FF, #F1, #3F, #FF, #FF, #F3, #1F, #FF, #FF, #FF, #11, #FF, #FF, #11, #FF, #FF
            db #FF, #FF, #F1, #31, #13, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF
            db #FA, #11, #AA, #AF, #FF, #FF, #FF, #FF, #FA, #11, #11, #1A, #AF, #FF, #FF, #FF
            db #FF, #A1, #AA, #11, #1A, #AF, #FF, #FF, #FF, #FA, #1A, #AA, #11, #1A, #AA, #FF
            db #FF, #FA, #11, #AF, #AA, #A1, #11, #AA, #FF, #FF, #A1, #AF, #FF, #FA, #A1, #11
            db #FF, #FA, #11, #1A, #FF, #FA, #A1, #11, #FF, #FA, #11, #AF, #AA, #A1, #11, #AA
            db #FF, #FA, #1A, #AA, #11, #1A, #AA, #FF, #FF, #A1, #AA, #11, #1A, #AF, #FF, #FF
            db #FA, #11, #11, #1A, #AF, #FF, #FF, #FF, #FA, #11, #AA, #AF, #FF, #FF, #FF, #FF
            db #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF, #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF
            db #FF, #FF, #FF, #A1, #11, #AF, #FF, #FF, #FF, #FF, #FF, #A1, #A1, #AF, #FF, #FF
            db #FF, #FF, #FA, #A1, #A1, #AF, #FF, #FF, #FF, #FF, #A1, #1A, #FA, #1A, #FF, #FF
            db #AA, #AA, #A1, #1A, #FA, #1A, #FF, #FF, #11, #11, #1A, #AF, #FA, #11, #AF, #FF
            db #11, #1A, #AF, #FF, #FF, #A1, #AF, #FF, #AA, #11, #1A, #AA, #FF, #A1, #AF, #FF
            db #FF, #AA, #A1, #11, #AA, #FA, #1A, #FF, #FF, #FF, #FA, #A1, #11, #AA, #1A, #FF
            db #FF, #FF, #FF, #FA, #AA, #11, #11, #AF, #FF, #FF, #FF, #FF, #FF, #AA, #11, #AF
            db #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF, #AA, #FF
            db #FA, #11, #AF, #FF, #FF, #FA, #11, #AF, #FA, #11, #1A, #AF, #AA, #A1, #11, #AF
            db #FF, #A1, #A1, #1A, #11, #1A, #1A, #FF, #FF, #A1, #AA, #11, #11, #AA, #1A, #FF
            db #FF, #A1, #1A, #AA, #1A, #A1, #1A, #FF, #FF, #FA, #1A, #FF, #AF, #A1, #AF, #FF
            db #FF, #FA, #11, #AF, #FA, #11, #AF, #FF, #FF, #FF, #A1, #AF, #FA, #1A, #FF, #FF
            db #FF, #FF, #A1, #AF, #FA, #1A, #FF, #FF, #FF, #FF, #FA, #1A, #A1, #AF, #FF, #FF
            db #FF, #FF, #FA, #1A, #A1, #AF, #FF, #FF, #FF, #FF, #FA, #11, #11, #AF, #FF, #FF
            db #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF, #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF
            db #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF, #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF
            db #FF, #FF, #FA, #11, #1A, #FF, #FF, #FF, #FF, #FF, #FA, #1A, #1A, #FF, #FF, #FF
            db #FF, #FF, #FA, #1A, #1A, #AF, #FF, #FF, #FF, #FF, #A1, #AF, #A1, #1A, #FF, #FF
            db #FF, #FF, #A1, #AF, #A1, #1A, #AA, #AA, #FF, #FA, #11, #AF, #FA, #A1, #11, #11
            db #FF, #FA, #1A, #FF, #FF, #FA, #A1, #11, #FF, #FA, #1A, #FF, #AA, #A1, #11, #AA
            db #FF, #A1, #AF, #AA, #11, #1A, #AA, #FF, #FF, #A1, #AA, #11, #1A, #AF, #FF, #FF
            db #FA, #11, #11, #AA, #AF, #FF, #FF, #FF, #FA, #11, #AA, #FF, #FF, #FF, #FF, #FF
            db #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF
            db #FF, #FF, #FF, #FF, #FA, #AA, #11, #AF, #FF, #FF, #FF, #FA, #A1, #11, #11, #AF
            db #FF, #FF, #FA, #A1, #11, #AA, #1A, #FF, #FF, #AA, #A1, #11, #AA, #A1, #AF, #FF
            db #AA, #11, #1A, #AA, #FA, #11, #AF, #FF, #11, #1A, #AF, #FF, #FA, #11, #AF, #FF
            db #11, #1A, #AF, #FF, #A1, #1A, #FF, #FF, #AA, #11, #1A, #AA, #FA, #11, #AF, #FF
            db #FF, #AA, #A1, #11, #AA, #A1, #AF, #FF, #FF, #FF, #FA, #A1, #11, #AA, #1A, #FF
            db #FF, #FF, #FF, #FA, #A1, #11, #11, #AF, #FF, #FF, #FF, #FF, #FA, #AA, #11, #AF
            db #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF
            db #FA, #11, #AA, #FF, #FF, #FF, #FF, #FF, #FA, #11, #11, #AA, #AF, #FF, #FF, #FF
            db #FF, #A1, #AA, #11, #1A, #AF, #FF, #FF, #FF, #A1, #AF, #AA, #11, #1A, #AA, #FF
            db #FF, #FA, #1A, #FF, #AA, #A1, #11, #AA, #FF, #FA, #1A, #FF, #FF, #FA, #A1, #11
            db #FF, #FA, #11, #AF, #FA, #A1, #11, #11, #FF, #FF, #A1, #AF, #A1, #1A, #AA, #AA
            db #FF, #FF, #A1, #AF, #A1, #1A, #FF, #FF, #FF, #FF, #FA, #1A, #1A, #AF, #FF, #FF
            db #FF, #FF, #FA, #1A, #1A, #FF, #FF, #FF, #FF, #FF, #FA, #11, #1A, #FF, #FF, #FF
            db #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF, #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF
            db #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF, #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF
            db #FF, #FF, #FA, #11, #11, #AF, #FF, #FF, #FF, #FF, #FA, #1A, #A1, #AF, #FF, #FF
            db #FF, #FF, #FA, #1A, #A1, #AF, #FF, #FF, #FF, #FF, #A1, #AF, #FA, #1A, #FF, #FF
            db #FF, #FF, #A1, #AF, #FA, #1A, #FF, #FF, #FF, #FA, #11, #AF, #FA, #11, #AF, #FF
            db #FF, #FA, #1A, #FF, #AF, #A1, #AF, #FF, #FF, #A1, #1A, #AA, #1A, #A1, #1A, #FF
            db #FF, #A1, #AA, #11, #11, #AA, #1A, #FF, #FF, #A1, #A1, #1A, #11, #1A, #1A, #FF
            db #FA, #11, #1A, #AF, #AA, #A1, #11, #AF, #FA, #11, #AF, #FF, #FF, #FA, #11, #AF
            db #FF, #AA, #FF, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF
            db #FF, #FF, #FF, #FF, #FF, #AA, #11, #AF, #FF, #FF, #FF, #FA, #AA, #11, #11, #AF
            db #FF, #FF, #FA, #A1, #11, #AA, #1A, #FF, #FF, #AA, #A1, #11, #AA, #FA, #1A, #FF
            db #AA, #11, #1A, #AA, #FF, #A1, #AF, #FF, #11, #1A, #AF, #FF, #FF, #A1, #AF, #FF
            db #11, #11, #1A, #AF, #FA, #11, #AF, #FF, #AA, #AA, #A1, #1A, #FA, #1A, #FF, #FF
            db #FF, #FF, #A1, #1A, #FA, #1A, #FF, #FF, #FF, #FF, #FA, #A1, #A1, #AF, #FF, #FF
            db #FF, #FF, #FF, #A1, #A1, #AF, #FF, #FF, #FF, #FF, #FF, #A1, #11, #AF, #FF, #FF
            db #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF, #FF, #FF, #FF, #A1, #1A, #FF, #FF, #FF
ld_end:
#endasm
End Sub
