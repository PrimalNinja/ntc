' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_MAN = 0
Public Const S_MAN_N = 8
Public Const S_MAN_W = 2
Public Const S_MAN_H = 3
Public Const S_HURT = 48
Public Const S_HURT_N = 1
Public Const S_HURT_W = 2
Public Const S_HURT_H = 3
Public Const S_OOLA = 54
Public Const S_OOLA_N = 1
Public Const S_OOLA_W = 2
Public Const S_OOLA_H = 3
Public Const S_TREX = 60
Public Const S_TREX_N = 2
Public Const S_TREX_W = 3
Public Const S_TREX_H = 3
Public Const S_BRONTO = 78
Public Const S_BRONTO_N = 1
Public Const S_BRONTO_W = 3
Public Const S_BRONTO_H = 3
Public Const S_DOWN = 87
Public Const S_DOWN_N = 1
Public Const S_DOWN_W = 3
Public Const S_DOWN_H = 2
Public Const S_RAPTOR = 93
Public Const S_RAPTOR_N = 3
Public Const S_RAPTOR_W = 2
Public Const S_RAPTOR_H = 2
Public Const S_TRIKE = 105
Public Const S_TRIKE_N = 2
Public Const S_TRIKE_W = 3
Public Const S_TRIKE_H = 2
Public Const S_SHADOW = 117
Public Const S_SHADOW_N = 1
Public Const S_SPARK = 118
Public Const S_SPARK_N = 1
Public Const S_PTERO = 119
Public Const S_PTERO_N = 2
Public Const S_PTERO_W = 2
Public Const S_DUST = 123
Public Const S_DUST_N = 1
Public Const S_MEAT = 124
Public Const S_MEAT_N = 1
Public Const S_ROCK = 125
Public Const S_ROCK_N = 1
Public Const S_ARROW = 126
Public Const S_ARROW_N = 1
Public Const S_HEART = 127
Public Const S_HEART_N = 1
Public Const T_PANEL = 1
Public Const T_LIFE = 2
Public Const T_BAR = 16
Public Const T_BAR_N = 9
Public Const T_MT_FILL = 96
Public Const T_MT_FILL2 = 97
Public Const T_MT_SL = 98
Public Const T_MT_SR = 99
Public Const T_MT_TOP = 100
Public Const T_MT_CRATER = 101
Public Const T_MT_SMOKE = 102
Public Const T_MT_LAVA = 103
Public Const T_CAN_TOP0 = 104
Public Const T_CAN_TOP1 = 105
Public Const T_CAN_TOP2 = 106
Public Const T_CAN_FILL = 107
Public Const T_CAN_FILL2 = 108
Public Const T_CAN_PALM = 109
Public Const T_GR_EDGE = 110
Public Const T_GR_EDGE2 = 111
Public Const T_GR_FILL = 112
Public Const T_GR_FILL2 = 113
Public Const T_GR_FILL3 = 114
Public Const T_GR_ROCK = 115
Public Const T_GR_SKULL = 116
Public Const T_GR_BONEL = 117
Public Const T_GR_BONER = 118
Public Const T_GR_PUDL = 119
Public Const T_GR_PUDR = 120
Public Const T_GR_FERN = 121
Public Const T_GR_STONES = 122
Public Const SpritePatterns = 128
Public Const SpritePalettes = 14

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
            ld e, 224                ; 14 x 16 (0 = 256)
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
            ld de, 16384
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
            db #00, #FF, #92, #49, #58, #0C, #E4, #60, #FC, #F0, #88, #2B, #D6, #44, #A3, #E3
spal:
            db #00, #FF, #F6, #AD, #F4, #AC, #64, #20, #D1, #69, #92, #E4, #88, #49, #FC, #E3
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #E3
            db #00, #FF, #F6, #AD, #78, #30, #08, #44, #D1, #69, #92, #E4, #88, #49, #FC, #E3
            db #00, #FF, #D2, #AD, #73, #2B, #06, #C4, #D1, #69, #92, #E4, #88, #49, #FC, #E3
            db #00, #FF, #F6, #AD, #CF, #86, #41, #B6, #D1, #69, #92, #E4, #88, #49, #FC, #E3
            db #00, #FF, #DA, #91, #99, #50, #28, #20, #D1, #69, #92, #E4, #AC, #64, #FC, #E3
            db #00, #FF, #FA, #B1, #D1, #88, #44, #20, #D1, #69, #92, #E4, #28, #04, #FC, #E3
            db #00, #FF, #F6, #AD, #CD, #89, #44, #20, #D1, #69, #92, #E4, #E8, #49, #FC, #E3
            db #00, #FF, #DA, #91, #96, #4D, #25, #20, #D1, #69, #92, #E4, #C8, #49, #FC, #E3
            db #00, #FF, #DA, #91, #B0, #6C, #24, #20, #D1, #69, #92, #E4, #84, #40, #FC, #E3
            db #00, #FF, #BB, #72, #77, #4E, #25, #20, #D1, #69, #92, #E4, #2D, #49, #FC, #E3
            db #00, #FF, #F6, #AD, #F9, #D0, #88, #F8, #D1, #69, #92, #E4, #44, #49, #FC, #E3
            db #00, #FF, #B1, #69, #50, #28, #04, #00, #D1, #69, #92, #E4, #88, #49, #FC, #E3
            db #00, #FF, #F6, #AD, #E8, #A0, #60, #F8, #F8, #AC, #92, #E4, #88, #49, #FC, #E3
truns:
            db 1, 2        ; tiles 1-2
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #FF, #FF, #FF, #FF, #FF, #11, #11, #FF, #F1, #11, #11, #1F, #F1, #F1, #1F, #1F
            db #F1, #11, #11, #1F, #FF, #1F, #F1, #FF, #FF, #11, #11, #FF, #FF, #FF, #FF, #FF
            db 16, 9        ; tiles 16-24
            db #00, #00, #00, #00, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #00, #00, #00, #00
            db #00, #00, #00, #00, #43, #33, #33, #33, #43, #33, #33, #33, #43, #33, #33, #33
            db #53, #33, #33, #33, #53, #33, #33, #33, #53, #33, #33, #33, #00, #00, #00, #00
            db #00, #00, #00, #00, #44, #33, #33, #33, #44, #33, #33, #33, #44, #33, #33, #33
            db #55, #33, #33, #33, #55, #33, #33, #33, #55, #33, #33, #33, #00, #00, #00, #00
            db #00, #00, #00, #00, #44, #43, #33, #33, #44, #43, #33, #33, #44, #43, #33, #33
            db #55, #53, #33, #33, #55, #53, #33, #33, #55, #53, #33, #33, #00, #00, #00, #00
            db #00, #00, #00, #00, #44, #44, #33, #33, #44, #44, #33, #33, #44, #44, #33, #33
            db #55, #55, #33, #33, #55, #55, #33, #33, #55, #55, #33, #33, #00, #00, #00, #00
            db #00, #00, #00, #00, #44, #44, #43, #33, #44, #44, #43, #33, #44, #44, #43, #33
            db #55, #55, #53, #33, #55, #55, #53, #33, #55, #55, #53, #33, #00, #00, #00, #00
            db #00, #00, #00, #00, #44, #44, #44, #33, #44, #44, #44, #33, #44, #44, #44, #33
            db #55, #55, #55, #33, #55, #55, #55, #33, #55, #55, #55, #33, #00, #00, #00, #00
            db #00, #00, #00, #00, #44, #44, #44, #43, #44, #44, #44, #43, #44, #44, #44, #43
            db #55, #55, #55, #53, #55, #55, #55, #53, #55, #55, #55, #53, #00, #00, #00, #00
            db #00, #00, #00, #00, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44
            db #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #00, #00, #00, #00
            db 33, 90        ; tiles 33-122
            db #FF, #F1, #1F, #FF, #FF, #11, #11, #FF, #FF, #11, #11, #0F, #FF, #F1, #10, #0F
            db #FF, #F1, #10, #FF, #FF, #FF, #00, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #00, #FF
            db #F1, #1F, #11, #FF, #F1, #10, #11, #0F, #FF, #00, #F0, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #F1, #1F, #11, #FF, #F1, #10, #11, #0F, #11, #11, #11, #1F, #F1, #10, #11, #00
            db #11, #11, #11, #1F, #F1, #10, #11, #00, #F1, #10, #11, #0F, #FF, #00, #F0, #0F
            db #FF, #11, #FF, #FF, #F1, #11, #11, #FF, #11, #00, #00, #0F, #F1, #11, #1F, #FF
            db #FF, #00, #11, #FF, #11, #11, #10, #0F, #F0, #11, #00, #FF, #FF, #F0, #0F, #FF
            db #FF, #FF, #FF, #FF, #11, #FF, #F1, #1F, #11, #0F, #11, #00, #F0, #01, #10, #0F
            db #FF, #11, #00, #FF, #F1, #10, #01, #1F, #11, #00, #F1, #10, #F0, #0F, #FF, #00
            db #FF, #11, #1F, #FF, #F1, #10, #11, #FF, #FF, #11, #10, #0F, #F1, #11, #01, #1F
            db #11, #01, #11, #00, #11, #0F, #11, #0F, #F1, #11, #F1, #1F, #FF, #00, #0F, #00
            db #F1, #1F, #FF, #FF, #F1, #10, #FF, #FF, #11, #00, #FF, #FF, #F0, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F1, #1F, #FF, #FF, #11, #00, #FF, #F1, #10, #0F, #FF, #F1, #10, #FF, #FF
            db #F1, #10, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #00, #FF
            db #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #F1, #10, #FF
            db #FF, #F1, #10, #FF, #FF, #11, #00, #FF, #F1, #10, #0F, #FF, #FF, #00, #FF, #FF
            db #FF, #FF, #FF, #FF, #F1, #1F, #F1, #1F, #FF, #11, #11, #00, #11, #11, #11, #11
            db #F0, #11, #11, #00, #F1, #10, #01, #1F, #FF, #00, #FF, #00, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #11, #11, #11, #FF
            db #F0, #11, #00, #0F, #FF, #11, #0F, #FF, #FF, #F0, #0F, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #F1, #10, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #FF
            db #F0, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #F0, #0F, #FF
            db #FF, #FF, #F1, #1F, #FF, #FF, #11, #00, #FF, #F1, #10, #0F, #FF, #11, #00, #FF
            db #F1, #10, #0F, #FF, #11, #00, #FF, #FF, #10, #0F, #FF, #FF, #F0, #FF, #FF, #FF
            db #F1, #11, #11, #FF, #11, #00, #01, #1F, #11, #0F, #11, #10, #11, #01, #11, #10
            db #11, #11, #01, #10, #11, #10, #01, #10, #F1, #11, #11, #00, #FF, #00, #00, #0F
            db #FF, #11, #FF, #FF, #F1, #11, #0F, #FF, #FF, #11, #0F, #FF, #FF, #11, #0F, #FF
            db #FF, #11, #0F, #FF, #FF, #11, #0F, #FF, #11, #11, #11, #FF, #F0, #00, #00, #0F
            db #F1, #11, #1F, #FF, #11, #00, #11, #FF, #F0, #0F, #11, #0F, #FF, #11, #10, #0F
            db #F1, #10, #00, #FF, #11, #00, #11, #FF, #11, #11, #11, #0F, #F0, #00, #00, #0F
            db #F1, #11, #1F, #FF, #11, #00, #11, #FF, #F0, #0F, #11, #0F, #FF, #11, #10, #0F
            db #FF, #F0, #11, #FF, #11, #FF, #11, #0F, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #FF, #F1, #11, #FF, #FF, #11, #11, #0F, #F1, #10, #11, #0F, #11, #00, #11, #0F
            db #11, #11, #11, #1F, #F0, #00, #11, #00, #FF, #F1, #11, #1F, #FF, #FF, #00, #00
            db #11, #11, #11, #FF, #11, #00, #00, #0F, #11, #11, #1F, #FF, #F0, #00, #11, #FF
            db #FF, #FF, #11, #0F, #11, #FF, #11, #0F, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #FF, #11, #1F, #FF, #F1, #10, #00, #FF, #11, #00, #FF, #FF, #11, #11, #1F, #FF
            db #11, #00, #11, #FF, #11, #0F, #11, #0F, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #11, #11, #11, #FF, #11, #00, #11, #0F, #F0, #0F, #11, #0F, #FF, #F1, #10, #0F
            db #FF, #11, #00, #FF, #FF, #11, #0F, #FF, #FF, #11, #0F, #FF, #FF, #F0, #0F, #FF
            db #F1, #11, #1F, #FF, #11, #00, #11, #FF, #11, #0F, #11, #0F, #F1, #11, #10, #0F
            db #11, #00, #11, #FF, #11, #0F, #11, #0F, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #F1, #11, #1F, #FF, #11, #00, #11, #FF, #11, #0F, #11, #0F, #F1, #11, #11, #0F
            db #FF, #00, #11, #0F, #FF, #F1, #10, #0F, #F1, #11, #00, #FF, #FF, #00, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #F0, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #F0, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #F0, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #F1, #10, #0F, #FF
            db #FF, #F1, #1F, #FF, #FF, #11, #00, #FF, #F1, #10, #0F, #FF, #11, #00, #FF, #FF
            db #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #00, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #FF, #F0, #00, #00, #0F
            db #FF, #FF, #FF, #FF, #11, #11, #11, #FF, #F0, #00, #00, #0F, #FF, #FF, #FF, #FF
            db #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #11, #FF
            db #FF, #F1, #10, #0F, #FF, #11, #00, #FF, #F1, #10, #0F, #FF, #FF, #00, #FF, #FF
            db #F1, #11, #1F, #FF, #11, #00, #11, #FF, #F0, #0F, #11, #0F, #FF, #F1, #10, #0F
            db #FF, #11, #00, #FF, #FF, #F0, #0F, #FF, #FF, #11, #FF, #FF, #FF, #F0, #0F, #FF
            db #F1, #11, #11, #FF, #11, #00, #01, #1F, #11, #01, #11, #10, #11, #01, #11, #10
            db #11, #01, #11, #10, #11, #0F, #00, #00, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #FF, #11, #FF, #FF, #F1, #11, #1F, #FF, #11, #00, #11, #FF, #11, #0F, #11, #0F
            db #11, #11, #11, #0F, #11, #00, #11, #0F, #11, #0F, #11, #0F, #F0, #0F, #F0, #0F
            db #11, #11, #11, #FF, #F1, #10, #01, #1F, #F1, #10, #F1, #10, #F1, #11, #11, #00
            db #F1, #10, #01, #1F, #F1, #10, #F1, #10, #11, #11, #11, #00, #F0, #00, #00, #0F
            db #FF, #11, #11, #FF, #F1, #10, #01, #1F, #11, #00, #FF, #00, #11, #0F, #FF, #FF
            db #11, #0F, #FF, #FF, #F1, #1F, #F1, #1F, #FF, #11, #11, #00, #FF, #F0, #00, #0F
            db #11, #11, #1F, #FF, #F1, #10, #11, #FF, #F1, #10, #F1, #1F, #F1, #10, #F1, #10
            db #F1, #10, #F1, #10, #F1, #10, #11, #00, #11, #11, #10, #0F, #F0, #00, #00, #FF
            db #11, #11, #11, #1F, #F1, #10, #00, #10, #F1, #10, #1F, #F0, #F1, #11, #10, #FF
            db #F1, #10, #10, #FF, #F1, #10, #F0, #1F, #11, #11, #11, #10, #F0, #00, #00, #00
            db #11, #11, #11, #1F, #F1, #10, #00, #10, #F1, #10, #1F, #F0, #F1, #11, #10, #FF
            db #F1, #10, #10, #FF, #F1, #10, #F0, #FF, #11, #11, #FF, #FF, #F0, #00, #0F, #FF
            db #FF, #11, #11, #FF, #F1, #10, #01, #1F, #11, #00, #FF, #00, #11, #0F, #FF, #FF
            db #11, #0F, #11, #1F, #F1, #1F, #F1, #10, #FF, #11, #11, #10, #FF, #F0, #00, #00
            db #11, #FF, #11, #FF, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #11, #11, #0F
            db #11, #00, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #F0, #0F, #F0, #0F
            db #F1, #11, #1F, #FF, #FF, #11, #00, #FF, #FF, #11, #0F, #FF, #FF, #11, #0F, #FF
            db #FF, #11, #0F, #FF, #FF, #11, #0F, #FF, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #FF, #F1, #11, #1F, #FF, #FF, #11, #00, #FF, #FF, #11, #0F, #FF, #FF, #11, #0F
            db #11, #FF, #11, #0F, #11, #0F, #11, #0F, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #11, #1F, #F1, #1F, #F1, #10, #F1, #10, #F1, #10, #11, #00, #F1, #11, #10, #0F
            db #F1, #10, #11, #FF, #F1, #10, #F1, #1F, #11, #10, #F1, #10, #F0, #00, #FF, #00
            db #11, #11, #FF, #FF, #F1, #10, #0F, #FF, #F1, #10, #FF, #FF, #F1, #10, #FF, #FF
            db #F1, #10, #FF, #1F, #F1, #10, #F1, #10, #11, #11, #11, #10, #F0, #00, #00, #00
            db #11, #FF, #F1, #1F, #11, #1F, #11, #10, #11, #11, #11, #10, #11, #11, #11, #10
            db #11, #01, #01, #10, #11, #0F, #01, #10, #11, #0F, #F1, #10, #F0, #0F, #FF, #00
            db #11, #FF, #F1, #1F, #11, #1F, #F1, #10, #11, #11, #F1, #10, #11, #01, #11, #10
            db #11, #0F, #11, #10, #11, #0F, #F1, #10, #11, #0F, #F1, #10, #F0, #0F, #FF, #00
            db #FF, #11, #1F, #FF, #F1, #10, #11, #FF, #11, #00, #F1, #1F, #11, #0F, #F1, #10
            db #11, #0F, #F1, #10, #F1, #1F, #11, #00, #FF, #11, #10, #0F, #FF, #F0, #00, #FF
            db #11, #11, #11, #FF, #F1, #10, #01, #1F, #F1, #10, #F1, #10, #F1, #11, #11, #00
            db #F1, #10, #00, #0F, #F1, #10, #FF, #FF, #11, #11, #FF, #FF, #F0, #00, #0F, #FF
            db #F1, #11, #1F, #FF, #11, #00, #11, #FF, #11, #0F, #11, #0F, #11, #0F, #11, #0F
            db #11, #01, #11, #0F, #F1, #11, #10, #0F, #FF, #01, #11, #FF, #FF, #FF, #00, #0F
            db #11, #11, #11, #FF, #F1, #10, #01, #1F, #F1, #10, #F1, #10, #F1, #11, #11, #00
            db #F1, #10, #11, #0F, #F1, #10, #F1, #1F, #11, #10, #F1, #10, #F0, #00, #FF, #00
            db #F1, #11, #1F, #FF, #11, #00, #11, #FF, #11, #1F, #F0, #0F, #F1, #11, #FF, #FF
            db #FF, #01, #11, #FF, #11, #FF, #11, #0F, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #11, #11, #11, #FF, #10, #11, #01, #0F, #F0, #11, #0F, #0F, #FF, #11, #0F, #FF
            db #FF, #11, #0F, #FF, #FF, #11, #0F, #FF, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #11, #FF, #11, #FF, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #0F
            db #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #11, #11, #0F, #F0, #00, #00, #0F
            db #11, #FF, #11, #FF, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #0F
            db #11, #0F, #11, #0F, #F1, #11, #10, #0F, #FF, #11, #00, #FF, #FF, #F0, #0F, #FF
            db #11, #FF, #F1, #1F, #11, #0F, #F1, #10, #11, #0F, #F1, #10, #11, #01, #F1, #10
            db #11, #11, #11, #10, #11, #10, #11, #10, #11, #00, #F1, #10, #F0, #0F, #FF, #00
            db #11, #FF, #F1, #1F, #11, #0F, #F1, #10, #F1, #1F, #11, #00, #FF, #11, #10, #0F
            db #FF, #11, #10, #FF, #F1, #10, #11, #FF, #11, #00, #F1, #1F, #F0, #0F, #FF, #00
            db #11, #FF, #11, #FF, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #F1, #11, #10, #0F
            db #FF, #11, #00, #FF, #FF, #11, #0F, #FF, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #11, #11, #11, #1F, #11, #00, #01, #10, #10, #0F, #11, #00, #F0, #F1, #10, #0F
            db #FF, #11, #00, #1F, #F1, #10, #01, #10, #11, #11, #11, #10, #F0, #00, #00, #00
            db #F1, #11, #1F, #FF, #F1, #10, #00, #FF, #F1, #10, #FF, #FF, #F1, #10, #FF, #FF
            db #F1, #10, #FF, #FF, #F1, #10, #FF, #FF, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF
            db #FF, #FF, #11, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #10, #FF, #FF, #FF, #F0
            db #F1, #11, #1F, #FF, #FF, #01, #10, #FF, #FF, #F1, #10, #FF, #FF, #F1, #10, #FF
            db #FF, #F1, #10, #FF, #FF, #F1, #10, #FF, #F1, #11, #10, #FF, #FF, #00, #00, #FF
            db #FF, #F1, #FF, #FF, #FF, #11, #1F, #FF, #F1, #10, #11, #FF, #11, #00, #F1, #1F
            db #F0, #0F, #FF, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #11
            db #21, #21, #11, #12, #21, #11, #12, #31, #12, #11, #12, #13, #11, #12, #11, #11
            db #11, #11, #12, #22, #22, #11, #11, #21, #12, #11, #12, #21, #11, #11, #21, #21
            db #22, #12, #21, #22, #12, #11, #22, #12, #12, #11, #13, #11, #21, #11, #12, #11
            db #11, #21, #11, #22, #21, #11, #12, #22, #11, #12, #21, #12, #21, #22, #21, #12
            db #FF, #FF, #FF, #F4, #FF, #FF, #FF, #41, #FF, #FF, #F4, #11, #FF, #FF, #41, #11
            db #FF, #F4, #22, #22, #FF, #42, #12, #11, #F4, #11, #12, #32, #42, #12, #11, #11
            db #3F, #FF, #FF, #FF, #13, #FF, #FF, #FF, #21, #3F, #FF, #FF, #11, #23, #FF, #FF
            db #12, #11, #3F, #FF, #32, #12, #23, #FF, #12, #22, #12, #3F, #11, #21, #11, #23
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #44, #44, #44, #44
            db #21, #12, #11, #21, #11, #11, #12, #22, #11, #11, #31, #12, #12, #12, #21, #11
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #67, #75, #77, #67, #66, #55, #55, #66
            db #66, #55, #55, #66, #22, #11, #12, #11, #11, #12, #21, #11, #11, #31, #21, #21
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F7, #77, #7F, #F7, #77, #77, #7F
            db #77, #77, #77, #FF, #77, #77, #77, #FF, #F7, #77, #77, #FF, #FF, #FF, #FF, #FF
            db #21, #15, #52, #12, #21, #11, #55, #21, #22, #11, #55, #11, #13, #15, #55, #11
            db #11, #55, #52, #22, #22, #55, #12, #11, #21, #55, #12, #21, #11, #15, #52, #11
            db #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FF, #FF, #FF, #FA, #CF, #CF, #FF, #C8, #AF
            db #AF, #FC, #B9, #9C, #AF, #C8, #A8, #99, #AC, #9A, #89, #A9, #A9, #99, #99, #AA
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FA, #9C, #CF, #FC
            db #FB, #AB, #AF, #F9, #C9, #A9, #BC, #F9, #A9, #99, #8B, #CB, #9A, #A9, #AA, #9A
            db #FF, #FF, #FF, #FF, #CF, #FF, #FF, #CF, #9F, #FF, #FF, #9C, #AF, #FF, #FC, #9A
            db #AC, #FF, #CA, #9B, #89, #FC, #89, #89, #A9, #CA, #8A, #BA, #98, #AA, #A9, #9A
            db #99, #99, #99, #98, #9A, #AA, #9A, #99, #99, #8A, #BA, #98, #9B, #9A, #8A, #99
            db #AA, #AB, #AA, #9B, #AA, #99, #8A, #99, #A9, #9A, #99, #8B, #9A, #BA, #99, #8A
            db #8A, #98, #99, #89, #99, #99, #A9, #89, #AA, #88, #8A, #9A, #AB, #DD, #A9, #99
            db #BA, #DD, #89, #AB, #A8, #DD, #8A, #AA, #AA, #DD, #8A, #9A, #98, #DD, #A9, #99
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #CF, #FF, #FC, #CC, #CC, #CF
            db #CC, #FD, #DF, #CC, #FF, #FD, #DF, #FF, #FF, #FD, #DF, #FF, #FF, #FD, #DF, #FF
            db #55, #55, #55, #55, #55, #55, #55, #55, #66, #56, #65, #66, #56, #65, #66, #56
            db #22, #22, #21, #13, #22, #23, #22, #33, #22, #22, #21, #23, #22, #22, #22, #32
            db #65, #66, #56, #65, #65, #66, #56, #65, #65, #66, #56, #65, #36, #22, #26, #23
            db #63, #22, #62, #21, #20, #03, #12, #22, #33, #22, #23, #32, #13, #22, #22, #03
            db #32, #32, #22, #22, #12, #00, #31, #22, #23, #32, #22, #33, #21, #32, #22, #20
            db #31, #23, #12, #22, #22, #11, #22, #23, #21, #32, #32, #12, #23, #10, #02, #12
            db #03, #12, #31, #22, #22, #21, #12, #22, #32, #13, #23, #21, #22, #31, #00, #21
            db #21, #12, #22, #22, #22, #22, #12, #33, #22, #32, #20, #33, #21, #22, #23, #22
            db #32, #11, #22, #22, #23, #22, #21, #23, #32, #33, #22, #03, #32, #13, #22, #32
            db #23, #22, #32, #13, #11, #22, #23, #23, #22, #22, #22, #32, #12, #22, #23, #03
            db #22, #32, #23, #21, #31, #12, #22, #22, #32, #29, #A2, #21, #29, #9A, #AA, #A0
            db #29, #AA, #AA, #A1, #2A, #AA, #AA, #A1, #2A, #AA, #AA, #A1, #20, #4A, #A4, #42
            db #22, #22, #22, #22, #22, #77, #77, #22, #27, #77, #77, #72, #27, #87, #78, #72
            db #27, #77, #77, #72, #22, #78, #78, #22, #22, #27, #72, #22, #22, #22, #22, #22
            db #02, #11, #23, #22, #12, #23, #21, #32, #77, #71, #13, #23, #17, #77, #77, #77
            db #27, #77, #77, #77, #77, #78, #88, #88, #30, #23, #23, #20, #22, #32, #33, #22
            db #32, #22, #32, #22, #22, #12, #27, #71, #13, #02, #37, #77, #77, #77, #77, #72
            db #77, #77, #77, #71, #88, #88, #87, #77, #22, #22, #17, #72, #22, #21, #22, #13
            db #22, #21, #12, #12, #13, #32, #13, #22, #32, #22, #21, #20, #22, #BB, #BB, #BB
            db #31, #CC, #CC, #CC, #22, #CC, #CC, #CC, #31, #CC, #CC, #CC, #22, #22, #22, #12
            db #13, #11, #22, #22, #12, #22, #31, #11, #23, #13, #03, #21, #BB, #BB, #BB, #21
            db #CC, #CC, #CC, #32, #CC, #CC, #CC, #12, #CC, #CC, #CC, #31, #22, #33, #22, #22
            db #12, #22, #D1, #23, #23, #3D, #E2, #21, #23, #2E, #D3, #33, #12, #ED, #ED, #22
            db #22, #DE, #DE, #23, #2D, #ED, #ED, #E3, #1E, #DE, #DE, #D2, #ED, #ED, #ED, #ED
            db #22, #22, #12, #22, #32, #22, #13, #12, #39, #92, #12, #02, #2A, #A2, #22, #32
            db #22, #21, #33, #22, #23, #23, #29, #91, #21, #29, #1A, #A2, #21, #20, #12, #20
            db 0, 0
pats:
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF, #FF
            db #FF, #FF, #09, #99, #90, #FF, #FF, #FF, #FF, #F0, #99, #99, #99, #0F, #FF, #00
            db #FF, #F0, #99, #99, #99, #90, #00, #77, #FF, #F0, #99, #99, #99, #90, #77, #77
            db #FF, #F0, #99, #99, #99, #97, #77, #77, #FF, #F0, #99, #99, #99, #99, #77, #77
            db #FF, #FF, #09, #99, #99, #89, #77, #72, #FF, #FF, #F0, #98, #88, #89, #77, #22
            db #FF, #FF, #FF, #09, #88, #89, #77, #72, #FF, #FF, #FF, #F0, #98, #88, #97, #72
            db #FF, #FF, #FF, #FF, #09, #88, #97, #77, #FF, #FF, #FF, #FF, #F0, #88, #97, #77
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #70, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #23, #77, #77, #70, #FF, #FF, #FF, #FF, #23, #77, #77, #70, #FF, #FF, #FF, #FF
            db #22, #37, #77, #0F, #FF, #FF, #FF, #FF, #22, #22, #33, #0F, #FF, #FF, #FF, #FF
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #33, #33, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #88, #89, #72, #FF, #FF, #FF, #FF, #F0, #68, #89, #22
            db #FF, #FF, #FF, #FF, #F0, #46, #88, #92, #FF, #FF, #FF, #FF, #F0, #46, #92, #22
            db #FF, #FF, #FF, #FF, #04, #56, #22, #22, #FF, #FF, #FF, #FF, #04, #56, #22, #22
            db #FF, #FF, #FF, #FF, #04, #55, #62, #22, #FF, #FF, #FF, #FF, #04, #55, #56, #22
            db #FF, #FF, #FF, #FF, #04, #55, #56, #22, #FF, #FF, #FF, #FF, #04, #55, #55, #62
            db #FF, #FF, #FF, #FF, #04, #56, #C5, #62, #FF, #FF, #FF, #F0, #45, #55, #55, #56
            db #FF, #FF, #FF, #F0, #45, #55, #62, #22, #FF, #FF, #FF, #F0, #45, #56, #22, #22
            db #FF, #FF, #FF, #04, #56, #C6, #22, #22, #FF, #FF, #FF, #04, #55, #56, #22, #22
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #23, #0F, #FF, #FF, #FF, #FF
            db #22, #23, #50, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #30, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #35, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #35, #0F, #FF, #FF, #FF, #FF, #FF
            db #35, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #23, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #40, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #06, #65, #56, #22, #22
            db #FF, #FF, #FF, #F0, #06, #33, #62, #22, #FF, #FF, #FF, #F0, #63, #36, #32, #22
            db #FF, #FF, #FF, #FF, #03, #33, #32, #22, #FF, #FF, #FF, #FF, #03, #33, #33, #22
            db #FF, #FF, #FF, #FF, #03, #33, #33, #22, #FF, #FF, #FF, #FF, #03, #33, #33, #22
            db #FF, #FF, #FF, #FF, #03, #33, #33, #22, #FF, #FF, #FF, #FF, #03, #33, #33, #22
            db #FF, #FF, #FF, #FF, #F0, #33, #33, #22, #FF, #FF, #FF, #FF, #F0, #33, #33, #22
            db #FF, #FF, #FF, #FF, #F0, #33, #33, #22, #FF, #FF, #FF, #FF, #F0, #33, #33, #99
            db #FF, #FF, #FF, #FF, #F0, #33, #33, #99, #FF, #FF, #FF, #FF, #FF, #03, #30, #99
            db #23, #55, #50, #FF, #FF, #FF, #FF, #FF, #22, #36, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #06, #0F, #FF, #FF, #FF, #FF, #22, #20, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #0F, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #99, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #99, #99, #0F, #FF, #FF, #FF, #FF, #FF, #99, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #00, #00, #FF, #FF, #FF, #FF, #FF, #F0, #99, #99, #0F, #FF, #FF, #00
            db #FF, #09, #99, #99, #90, #FF, #00, #77, #FF, #09, #99, #99, #99, #00, #77, #77
            db #F0, #99, #99, #99, #99, #07, #77, #77, #FF, #09, #99, #99, #99, #07, #77, #77
            db #FF, #09, #99, #99, #98, #97, #77, #72, #FF, #F0, #99, #99, #98, #97, #77, #22
            db #FF, #FF, #09, #88, #88, #80, #77, #72, #FF, #FF, #F0, #99, #88, #89, #77, #72
            db #FF, #FF, #FF, #00, #98, #89, #77, #77, #FF, #FF, #FF, #FF, #09, #88, #97, #77
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #70, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #23, #77, #77, #70, #FF, #FF, #FF, #FF, #23, #77, #77, #70, #FF, #FF, #FF, #FF
            db #22, #37, #77, #0F, #FF, #FF, #FF, #FF, #22, #22, #33, #0F, #FF, #FF, #FF, #FF
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #33, #33, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #88, #97, #72, #FF, #FF, #FF, #FF, #F0, #68, #89, #22
            db #FF, #FF, #FF, #FF, #F0, #68, #88, #92, #FF, #FF, #FF, #FF, #F0, #46, #92, #22
            db #FF, #FF, #FF, #FF, #04, #56, #22, #22, #FF, #FF, #FF, #FF, #04, #56, #22, #22
            db #FF, #FF, #FF, #FF, #04, #55, #62, #22, #FF, #FF, #FF, #FF, #04, #55, #56, #22
            db #FF, #FF, #FF, #FF, #04, #55, #55, #62, #FF, #FF, #FF, #FF, #04, #55, #55, #62
            db #FF, #FF, #FF, #FF, #04, #56, #C5, #56, #FF, #FF, #FF, #F0, #45, #55, #55, #55
            db #FF, #FF, #FF, #F0, #45, #55, #62, #22, #FF, #FF, #FF, #F0, #45, #56, #22, #22
            db #FF, #FF, #FF, #04, #56, #C6, #22, #22, #FF, #FF, #FF, #04, #55, #56, #22, #22
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #23, #0F, #FF, #FF, #FF, #FF
            db #22, #23, #50, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #30, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #30, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #62, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #35, #56, #30, #FF, #FF, #FF, #FF, #FF, #23, #56, #33, #0F, #FF, #FF, #FF, #FF
            db #23, #56, #30, #FF, #FF, #FF, #FF, #FF, #22, #35, #50, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #06, #55, #55, #62, #22
            db #FF, #FF, #FF, #F0, #36, #33, #63, #22, #FF, #FF, #FF, #03, #63, #36, #30, #32
            db #FF, #FF, #FF, #03, #33, #33, #0F, #02, #FF, #FF, #FF, #03, #33, #33, #0F, #03
            db #FF, #FF, #FF, #03, #33, #33, #0F, #F0, #FF, #FF, #FF, #03, #33, #33, #0F, #FF
            db #FF, #FF, #FF, #F0, #33, #33, #0F, #FF, #FF, #FF, #FF, #F0, #33, #33, #0F, #FF
            db #FF, #FF, #FF, #F0, #33, #33, #00, #FF, #FF, #FF, #FF, #F0, #33, #33, #33, #0F
            db #FF, #FF, #FF, #F0, #33, #33, #33, #0F, #FF, #FF, #FF, #F0, #33, #33, #33, #0F
            db #FF, #FF, #FF, #FF, #00, #33, #00, #FF, #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF
            db #22, #35, #50, #FF, #FF, #FF, #FF, #FF, #22, #23, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #06, #0F, #FF, #FF, #FF, #FF, #22, #23, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #32, #22, #20, #FF, #FF, #FF, #FF, #FF, #02, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #02, #22, #20, #FF, #FF, #FF, #FF, #FF, #02, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #02, #22, #22, #0F, #FF, #FF, #FF, #FF, #02, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #09, #99, #99, #90, #FF, #FF, #FF, #FF, #09, #99, #99, #90, #FF, #FF, #FF, #FF
            db #09, #99, #99, #90, #FF, #FF, #FF, #FF, #F0, #33, #30, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #09, #99, #00, #FF, #FF
            db #FF, #FF, #09, #99, #99, #99, #0F, #FF, #FF, #FF, #09, #99, #99, #99, #0F, #00
            db #FF, #FF, #09, #99, #99, #99, #00, #77, #FF, #FF, #09, #99, #99, #99, #77, #77
            db #FF, #FF, #09, #99, #99, #99, #77, #77, #FF, #FF, #F0, #99, #99, #98, #97, #77
            db #FF, #FF, #FF, #09, #98, #88, #97, #72, #FF, #FF, #FF, #F0, #88, #88, #97, #22
            db #FF, #FF, #FF, #F0, #98, #88, #97, #72, #FF, #FF, #FF, #FF, #09, #88, #97, #72
            db #FF, #FF, #FF, #FF, #F0, #88, #89, #77, #FF, #FF, #FF, #FF, #F0, #98, #89, #77
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #70, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #23, #77, #77, #70, #FF, #FF, #FF, #FF, #23, #77, #77, #70, #FF, #FF, #FF, #FF
            db #22, #37, #77, #0F, #FF, #FF, #FF, #FF, #22, #22, #33, #0F, #FF, #FF, #FF, #FF
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #33, #33, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #08, #89, #72, #FF, #FF, #FF, #FF, #F0, #46, #89, #22
            db #FF, #FF, #FF, #FF, #F0, #46, #89, #22, #FF, #FF, #FF, #FF, #F0, #46, #22, #22
            db #FF, #FF, #FF, #FF, #04, #56, #22, #22, #FF, #FF, #FF, #FF, #04, #56, #22, #22
            db #FF, #FF, #FF, #F0, #35, #55, #62, #22, #FF, #FF, #FF, #F0, #35, #55, #62, #22
            db #FF, #FF, #FF, #03, #35, #55, #56, #22, #FF, #FF, #FF, #03, #35, #55, #56, #22
            db #FF, #FF, #FF, #03, #35, #56, #C5, #62, #FF, #FF, #FF, #03, #55, #55, #55, #62
            db #FF, #FF, #FF, #03, #55, #55, #62, #22, #FF, #FF, #FF, #03, #55, #56, #22, #22
            db #FF, #FF, #FF, #04, #56, #C6, #22, #22, #FF, #FF, #FF, #04, #55, #56, #22, #22
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #23, #0F, #FF, #FF, #FF, #FF
            db #22, #23, #50, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #30, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #35, #0F, #FF, #FF, #FF, #FF, #FF, #22, #35, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #35, #0F, #FF, #FF, #FF, #FF, #FF, #22, #35, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #35, #0F, #FF, #FF, #FF, #FF, #FF, #22, #35, #0F, #FF, #FF, #FF, #FF, #FF
            db #35, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #23, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #40, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #04, #55, #62, #22, #22, #FF, #FF, #FF, #06, #65, #62, #22, #22
            db #FF, #FF, #FF, #F0, #06, #02, #22, #22, #FF, #FF, #FF, #F0, #60, #02, #22, #22
            db #FF, #FF, #FF, #FF, #0F, #02, #22, #23, #FF, #FF, #FF, #FF, #F0, #22, #22, #23
            db #FF, #FF, #FF, #FF, #F0, #22, #22, #33, #FF, #FF, #FF, #FF, #F0, #22, #22, #33
            db #FF, #FF, #FF, #FF, #F0, #22, #22, #33, #FF, #FF, #FF, #FF, #F0, #22, #22, #33
            db #FF, #FF, #FF, #FF, #F0, #22, #22, #33, #FF, #FF, #FF, #FF, #F0, #22, #22, #33
            db #FF, #FF, #FF, #FF, #F0, #22, #22, #20, #FF, #FF, #FF, #FF, #F0, #99, #99, #99
            db #FF, #FF, #FF, #FF, #F0, #99, #99, #99, #FF, #FF, #FF, #FF, #F0, #99, #99, #99
            db #23, #55, #50, #FF, #FF, #FF, #FF, #FF, #36, #56, #60, #FF, #FF, #FF, #FF, #FF
            db #20, #60, #06, #0F, #FF, #FF, #FF, #FF, #36, #00, #60, #FF, #FF, #FF, #FF, #FF
            db #33, #0F, #0F, #FF, #FF, #FF, #FF, #FF, #33, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #33, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #33, #30, #FF, #FF, #FF, #FF, #FF, #FF
            db #33, #30, #FF, #FF, #FF, #FF, #FF, #FF, #33, #30, #FF, #FF, #FF, #FF, #FF, #FF
            db #33, #33, #0F, #FF, #FF, #FF, #FF, #FF, #33, #33, #00, #FF, #FF, #FF, #FF, #FF
            db #33, #33, #33, #0F, #FF, #FF, #FF, #FF, #33, #33, #33, #0F, #FF, #FF, #FF, #FF
            db #33, #33, #33, #0F, #FF, #FF, #FF, #FF, #00, #00, #00, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #07
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #77, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #77
            db #FF, #FF, #FF, #FF, #FF, #FF, #07, #77, #FF, #FF, #FF, #FF, #FF, #FF, #07, #77
            db #00, #00, #FF, #FF, #FF, #FF, #F0, #77, #99, #99, #0F, #FF, #FF, #FF, #F0, #77
            db #99, #99, #90, #FF, #FF, #FF, #F0, #77, #99, #99, #98, #0F, #FF, #FF, #F0, #77
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #07, #77, #70, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #70, #FF, #FF, #FF, #FF
            db #77, #77, #77, #77, #0F, #FF, #FF, #FF, #77, #77, #77, #77, #0F, #FF, #FF, #FF
            db #77, #23, #77, #77, #70, #FF, #FF, #FF, #72, #23, #77, #77, #70, #FF, #FF, #FF
            db #72, #22, #37, #77, #70, #FF, #FF, #FF, #77, #22, #22, #33, #30, #FF, #FF, #FF
            db #77, #22, #22, #22, #0F, #FF, #FF, #FF, #77, #22, #3B, #1B, #0F, #FF, #FF, #FF
            db #99, #99, #99, #80, #0F, #FF, #06, #77, #99, #99, #99, #88, #80, #00, #45, #67
            db #99, #99, #98, #88, #88, #94, #55, #62, #99, #99, #98, #88, #88, #89, #55, #62
            db #09, #99, #99, #99, #98, #88, #88, #92, #F0, #00, #00, #00, #09, #88, #89, #22
            db #FF, #FF, #FF, #FF, #F0, #45, #69, #22, #FF, #FF, #FF, #FF, #F0, #45, #56, #22
            db #FF, #FF, #FF, #FF, #F0, #45, #55, #63, #FF, #FF, #FF, #FF, #04, #55, #55, #55
            db #FF, #FF, #FF, #FF, #04, #56, #C5, #55, #FF, #FF, #FF, #F0, #45, #55, #55, #55
            db #FF, #FF, #FF, #F0, #45, #55, #62, #22, #FF, #FF, #FF, #F0, #45, #56, #22, #22
            db #FF, #FF, #FF, #04, #56, #C6, #22, #22, #FF, #FF, #FF, #04, #55, #56, #22, #22
            db #77, #22, #3B, #BB, #00, #00, #0F, #FF, #22, #22, #22, #23, #33, #33, #30, #FF
            db #22, #22, #23, #33, #33, #33, #33, #0F, #22, #22, #23, #33, #33, #33, #33, #0F
            db #22, #22, #23, #33, #33, #33, #30, #FF, #22, #22, #22, #00, #00, #00, #0F, #FF
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #32, #22, #22, #20, #FF, #FF, #FF, #FF, #62, #22, #22, #20, #FF, #FF, #FF, #FF
            db #56, #22, #22, #30, #FF, #FF, #FF, #FF, #55, #62, #33, #0F, #FF, #FF, #FF, #FF
            db #35, #55, #00, #FF, #FF, #FF, #FF, #FF, #23, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #23, #55, #0F, #FF, #FF, #FF, #FF, #FF, #22, #35, #40, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #06, #55, #55, #62, #22
            db #FF, #FF, #FF, #F0, #36, #33, #62, #22, #FF, #FF, #FF, #F0, #63, #36, #33, #32
            db #FF, #FF, #FF, #F0, #33, #33, #30, #02, #FF, #FF, #FF, #03, #33, #33, #30, #03
            db #FF, #FF, #FF, #F0, #33, #33, #0F, #F0, #FF, #FF, #FF, #F0, #33, #33, #0F, #F0
            db #FF, #FF, #FF, #F0, #33, #33, #30, #F0, #FF, #FF, #FF, #F0, #33, #33, #30, #FF
            db #FF, #FF, #FF, #F0, #33, #33, #30, #FF, #FF, #FF, #FF, #F0, #33, #33, #30, #FF
            db #FF, #FF, #FF, #F0, #33, #33, #33, #0F, #FF, #FF, #FF, #F0, #33, #33, #33, #00
            db #FF, #FF, #FF, #F0, #33, #33, #33, #00, #FF, #FF, #FF, #FF, #00, #00, #00, #F0
            db #22, #35, #50, #FF, #FF, #FF, #FF, #FF, #22, #23, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #06, #0F, #FF, #FF, #FF, #FF, #22, #23, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #20, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #32, #22, #20, #FF, #FF, #FF, #FF, #FF, #02, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #02, #22, #20, #FF, #FF, #FF, #FF, #FF, #02, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #02, #22, #20, #FF, #FF, #FF, #FF, #FF, #99, #99, #99, #0F, #FF, #FF, #FF, #FF
            db #99, #99, #99, #0F, #FF, #FF, #FF, #FF, #99, #99, #99, #0F, #FF, #FF, #FF, #FF
            db #FF, #09, #88, #88, #0F, #FF, #FF, #FF, #FF, #F0, #98, #88, #0F, #FF, #FF, #FF
            db #FF, #FF, #09, #88, #80, #FF, #FF, #FF, #FF, #FF, #F0, #98, #80, #0F, #FF, #FF
            db #FF, #FF, #FF, #09, #89, #20, #FF, #FF, #FF, #FF, #FF, #F0, #22, #22, #00, #0F
            db #FF, #FF, #FF, #F0, #22, #23, #77, #70, #FF, #FF, #FF, #F0, #22, #23, #77, #77
            db #FF, #FF, #FF, #F0, #22, #23, #77, #77, #FF, #FF, #FF, #07, #22, #23, #77, #77
            db #FF, #FF, #FF, #07, #22, #22, #23, #77, #FF, #FF, #FF, #07, #22, #22, #23, #77
            db #FF, #FF, #FF, #F0, #22, #22, #22, #37, #FF, #FF, #FF, #F0, #22, #22, #22, #22
            db #FF, #FF, #FF, #F0, #22, #22, #22, #22, #FF, #FF, #FF, #F0, #72, #22, #22, #33
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #70, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #77, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #70, #FF, #FF, #FF, #FF, #FF, #FF, #77, #70, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #33, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #33, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #72, #22, #22, #22, #FF, #FF, #FF, #06, #77, #22, #22, #22
            db #FF, #FF, #FF, #04, #56, #22, #22, #22, #FF, #FF, #FF, #04, #56, #22, #22, #22
            db #FF, #FF, #FF, #04, #55, #62, #22, #22, #FF, #FF, #F0, #35, #55, #62, #22, #22
            db #FF, #FF, #03, #35, #55, #56, #22, #23, #FF, #FF, #03, #35, #55, #55, #55, #55
            db #FF, #F0, #33, #35, #55, #55, #55, #55, #FF, #F0, #33, #33, #55, #55, #55, #55
            db #FF, #FF, #03, #33, #55, #56, #C5, #55, #FF, #FF, #03, #33, #55, #55, #55, #55
            db #FF, #FF, #03, #33, #55, #55, #62, #22, #FF, #FF, #F0, #33, #55, #56, #22, #22
            db #FF, #FF, #F0, #35, #56, #C6, #22, #22, #FF, #FF, #F0, #35, #55, #56, #22, #22
            db #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #35, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #35, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #40, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #54, #0F, #FF, #FF, #FF, #FF, #FF
            db #35, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #23, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #40, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #06, #65, #55, #62, #22
            db #FF, #FF, #FF, #F0, #06, #33, #62, #22, #FF, #FF, #FF, #F0, #63, #36, #32, #22
            db #FF, #FF, #FF, #F0, #33, #33, #33, #22, #FF, #FF, #FF, #F0, #33, #33, #30, #32
            db #FF, #FF, #FF, #F0, #33, #33, #30, #02, #FF, #FF, #FF, #F0, #33, #33, #30, #02
            db #FF, #FF, #FF, #FF, #03, #33, #30, #02, #FF, #FF, #FF, #FF, #03, #33, #30, #02
            db #FF, #FF, #FF, #FF, #03, #33, #30, #02, #FF, #FF, #FF, #FF, #03, #33, #30, #02
            db #FF, #FF, #FF, #FF, #03, #33, #33, #32, #FF, #FF, #FF, #FF, #03, #33, #33, #39
            db #FF, #FF, #FF, #FF, #03, #33, #33, #39, #FF, #FF, #FF, #FF, #F0, #03, #00, #09
            db #22, #35, #50, #FF, #FF, #FF, #FF, #FF, #22, #36, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #06, #0F, #FF, #FF, #FF, #FF, #22, #20, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #99, #99, #90, #FF, #FF, #FF, #FF, #FF
            db #99, #99, #90, #FF, #FF, #FF, #FF, #FF, #99, #99, #90, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F0, #00, #00, #0F, #FF, #FF, #FF, #FF, #07, #77, #77, #70, #FF, #FF, #FF
            db #F0, #77, #77, #77, #77, #0F, #FF, #FF, #07, #77, #77, #77, #77, #70, #FF, #FF
            db #77, #77, #77, #77, #77, #70, #FF, #FF, #77, #77, #22, #23, #77, #77, #0F, #FF
            db #77, #77, #22, #37, #77, #77, #0F, #FF, #07, #77, #22, #23, #17, #72, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #04
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #45, #FF, #FF, #FF, #FF, #FF, #FF, #04, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #04, #55, #FF, #FF, #FF, #FF, #FF, #F0, #45, #55
            db #FF, #FF, #FF, #FF, #FF, #F0, #45, #55, #FF, #FF, #FF, #FF, #FF, #04, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #04, #55, #55, #FF, #FF, #FF, #FF, #F0, #45, #55, #55
            db #FF, #FF, #FF, #FF, #00, #46, #C5, #55, #FF, #FF, #FF, #F0, #44, #55, #55, #55
            db #FF, #FF, #FF, #F0, #45, #55, #62, #22, #FF, #FF, #FF, #F0, #45, #56, #22, #22
            db #07, #77, #72, #22, #23, #33, #0F, #FF, #07, #77, #72, #22, #22, #20, #FF, #FF
            db #07, #77, #72, #23, #B1, #B0, #FF, #FF, #67, #77, #22, #23, #BB, #B0, #00, #00
            db #56, #22, #22, #22, #22, #22, #22, #22, #56, #22, #22, #22, #22, #22, #22, #22
            db #62, #22, #22, #22, #22, #22, #22, #22, #56, #22, #22, #22, #22, #22, #22, #22
            db #56, #22, #22, #23, #33, #33, #33, #33, #55, #62, #22, #20, #00, #00, #00, #00
            db #55, #55, #56, #30, #0F, #FF, #FF, #FF, #55, #55, #56, #33, #30, #00, #FF, #FF
            db #55, #55, #56, #33, #33, #33, #0F, #FF, #55, #55, #63, #33, #33, #33, #30, #FF
            db #35, #55, #60, #33, #33, #33, #30, #FF, #23, #55, #0F, #00, #03, #33, #0F, #FF
            db #FF, #FF, #FF, #04, #56, #C6, #22, #22, #FF, #FF, #FF, #04, #55, #56, #22, #22
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #04, #55, #55, #63, #22
            db #FF, #FF, #FF, #03, #36, #33, #60, #22, #FF, #FF, #F0, #33, #63, #36, #30, #63
            db #FF, #FF, #F0, #33, #33, #33, #0F, #00, #FF, #FF, #F0, #33, #33, #30, #FF, #FF
            db #FF, #FF, #FF, #03, #33, #33, #0F, #FF, #FF, #FF, #FF, #03, #33, #33, #0F, #FF
            db #FF, #FF, #FF, #03, #33, #33, #0F, #FF, #FF, #FF, #FF, #F0, #33, #33, #0F, #FF
            db #FF, #FF, #FF, #F0, #33, #33, #00, #FF, #FF, #FF, #FF, #F0, #33, #33, #33, #0F
            db #FF, #FF, #FF, #F0, #33, #33, #33, #0F, #FF, #FF, #FF, #F0, #33, #33, #33, #0F
            db #22, #35, #0F, #FF, #F0, #00, #FF, #FF, #22, #35, #40, #FF, #FF, #FF, #FF, #FF
            db #22, #23, #50, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #36, #0F, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #32, #22, #22, #20, #FF, #FF, #FF, #FF, #03, #22, #22, #30, #FF, #FF, #FF, #FF
            db #F0, #22, #22, #0F, #FF, #FF, #FF, #FF, #F0, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #F0, #22, #22, #0F, #FF, #FF, #FF, #FF, #02, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #02, #22, #22, #0F, #FF, #FF, #FF, #FF, #02, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #09, #99, #99, #90, #FF, #FF, #FF, #FF, #09, #99, #99, #90, #FF, #FF, #FF, #FF
            db #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #F0, #99, #99, #90, #FF, #FF, #FF, #FF
            db #09, #99, #99, #99, #0F, #FF, #FF, #FF, #09, #99, #99, #99, #0F, #FF, #FF, #00
            db #09, #99, #99, #99, #0F, #FF, #00, #77, #09, #99, #99, #99, #0F, #F0, #77, #77
            db #09, #99, #99, #99, #0F, #07, #77, #77, #F0, #99, #99, #98, #0F, #07, #77, #77
            db #FF, #08, #88, #88, #0F, #07, #77, #72, #FF, #09, #88, #88, #0F, #07, #77, #22
            db #FF, #F0, #88, #88, #0F, #F0, #77, #72, #FF, #F0, #98, #88, #0F, #F0, #77, #72
            db #FF, #FF, #08, #88, #80, #F0, #77, #77, #FF, #FF, #09, #88, #80, #F0, #77, #77
            db #FF, #FF, #F0, #88, #80, #06, #77, #72, #FF, #FF, #F0, #98, #80, #46, #77, #22
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #70, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #77, #0F, #FF, #FF, #FF, #FF, #77, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #23, #77, #77, #70, #FF, #FF, #FF, #FF, #23, #77, #77, #70, #FF, #FF, #FF, #FF
            db #22, #37, #77, #0F, #FF, #FF, #FF, #FF, #22, #22, #33, #0F, #FF, #FF, #FF, #FF
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #33, #33, #0F, #FF, #FF, #FF, #FF
            db #22, #22, #22, #0F, #FF, #FF, #FF, #FF, #22, #22, #23, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #08, #93, #55, #62, #22, #FF, #FF, #FF, #02, #22, #35, #62, #22
            db #FF, #FF, #F0, #22, #22, #35, #62, #22, #FF, #FF, #F0, #32, #22, #22, #22, #22
            db #FF, #FF, #03, #32, #22, #22, #22, #22, #FF, #FF, #03, #33, #22, #22, #22, #22
            db #FF, #FF, #03, #33, #32, #22, #22, #23, #FF, #F0, #33, #33, #36, #22, #22, #35
            db #FF, #F0, #33, #33, #04, #62, #22, #35, #FF, #F0, #33, #33, #45, #55, #55, #55
            db #FF, #F0, #33, #33, #55, #55, #62, #22, #FF, #F0, #33, #30, #45, #56, #22, #22
            db #FF, #FF, #03, #04, #56, #C6, #22, #22, #FF, #FF, #F0, #04, #55, #56, #22, #22
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #06, #65, #66, #62, #22
            db #22, #23, #50, #FF, #FF, #FF, #FF, #FF, #22, #22, #20, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #30, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #35, #0F, #FF, #FF, #FF, #FF, #FF, #35, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #00, #00, #FF, #FF, #FF, #FF, #22, #22, #22, #22, #0F, #FF, #FF, #FF
            db #22, #22, #22, #22, #20, #FF, #FF, #FF, #22, #22, #22, #22, #20, #FF, #FF, #FF
            db #22, #22, #22, #22, #20, #FF, #FF, #FF, #22, #22, #22, #22, #30, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #06, #00, #63, #36, #FF, #FF, #FF, #F0, #60, #06, #03, #63
            db #FF, #FF, #FF, #FF, #0F, #F0, #F0, #33, #FF, #FF, #FF, #FF, #FF, #FF, #03, #33
            db #FF, #FF, #FF, #FF, #FF, #F0, #33, #33, #FF, #FF, #FF, #FF, #F0, #03, #33, #33
            db #FF, #FF, #FF, #FF, #03, #33, #33, #33, #FF, #FF, #FF, #FF, #03, #33, #33, #30
            db #FF, #FF, #FF, #FF, #03, #33, #33, #30, #FF, #FF, #FF, #FF, #F0, #03, #00, #0F
            db #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #33, #22, #22, #23, #0F, #FF, #FF, #FF, #36, #22, #22, #30, #FF, #FF, #FF, #FF
            db #32, #22, #22, #0F, #FF, #FF, #FF, #FF, #99, #99, #99, #0F, #FF, #FF, #FF, #FF
            db #99, #99, #99, #0F, #FF, #FF, #FF, #FF, #99, #99, #99, #0F, #FF, #FF, #FF, #FF
            db #00, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #FF, #FF
            db #FF, #FF, #FF, #00, #77, #77, #00, #FF, #FF, #FF, #F0, #77, #77, #77, #77, #0F
            db #FF, #FF, #07, #77, #77, #77, #77, #70, #FF, #FF, #07, #77, #77, #77, #77, #77
            db #FF, #F0, #77, #77, #72, #37, #77, #77, #FF, #F0, #77, #77, #22, #23, #77, #77
            db #FF, #FF, #07, #77, #22, #22, #37, #77, #FF, #FF, #F0, #77, #72, #22, #22, #33
            db #FF, #FF, #07, #77, #72, #22, #22, #22, #FF, #FF, #07, #77, #72, #22, #3B, #1B
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #F0, #00, #07, #77, #72, #22, #3B, #BB, #03, #33, #36, #77, #72, #22, #22, #22
            db #89, #33, #35, #67, #62, #22, #22, #35, #89, #22, #35, #56, #22, #22, #22, #22
            db #92, #22, #35, #56, #22, #22, #22, #23, #32, #22, #23, #62, #22, #22, #22, #23
            db #03, #22, #22, #22, #22, #22, #22, #35, #F0, #32, #22, #22, #22, #22, #35, #55
            db #FF, #03, #22, #22, #22, #35, #55, #55, #FF, #F0, #32, #22, #23, #55, #55, #55
            db #FF, #FF, #03, #32, #35, #56, #C5, #55, #FF, #FF, #F0, #03, #55, #55, #55, #55
            db #FF, #FF, #FF, #F0, #45, #55, #62, #22, #FF, #FF, #FF, #F0, #45, #56, #22, #22
            db #FF, #FF, #FF, #04, #56, #C6, #22, #22, #FF, #FF, #FF, #04, #55, #56, #22, #22
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #40, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #54, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #40, #FF, #00, #FF, #FF, #FF, #FF, #55, #54, #00, #22, #00, #00, #00, #00
            db #22, #22, #22, #22, #22, #23, #99, #99, #22, #22, #22, #22, #22, #23, #99, #99
            db #22, #22, #22, #22, #22, #23, #99, #99, #22, #22, #22, #23, #33, #33, #33, #33
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #06, #55, #55, #62, #32
            db #FF, #FF, #FF, #F0, #36, #33, #63, #06, #FF, #FF, #FF, #F0, #63, #36, #33, #60
            db #FF, #FF, #FF, #03, #33, #33, #30, #0F, #FF, #FF, #FF, #03, #33, #33, #30, #FF
            db #FF, #FF, #F0, #33, #33, #33, #0F, #FF, #FF, #FF, #F0, #33, #33, #30, #FF, #FF
            db #FF, #FF, #03, #33, #33, #30, #FF, #FF, #FF, #F0, #03, #33, #33, #0F, #FF, #FF
            db #FF, #03, #33, #33, #30, #FF, #FF, #FF, #FF, #03, #33, #33, #30, #FF, #FF, #FF
            db #FF, #03, #33, #33, #30, #FF, #FF, #FF, #FF, #F0, #33, #30, #0F, #FF, #FF, #FF
            db #FF, #FF, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #23, #30, #00, #00, #00, #00, #33, #36, #60, #0F, #FF, #FF, #FF, #FF
            db #00, #60, #06, #0F, #FF, #FF, #FF, #FF, #06, #00, #60, #FF, #FF, #FF, #FF, #FF
            db #F0, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #00, #00, #00, #FF, #FF, #FF, #FF, #F0, #77, #77, #77, #0F, #FF
            db #FF, #FF, #07, #77, #77, #77, #70, #FF, #FF, #F0, #77, #77, #77, #77, #77, #0F
            db #FF, #07, #77, #77, #77, #77, #77, #0F, #FF, #07, #77, #72, #23, #77, #77, #70
            db #FF, #07, #77, #72, #22, #37, #77, #70, #FF, #F0, #77, #72, #22, #23, #77, #0F
            db #FF, #F0, #77, #77, #22, #22, #22, #0F, #FF, #F0, #77, #77, #22, #3B, #1B, #0F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F0, #77, #77, #22, #3B, #BB, #0F, #FF, #F0, #77, #72, #22, #22, #22, #0F
            db #F0, #00, #67, #76, #22, #22, #35, #40, #03, #33, #55, #62, #22, #22, #23, #50
            db #33, #33, #55, #62, #22, #22, #22, #34, #33, #33, #36, #22, #22, #22, #22, #35
            db #33, #33, #36, #22, #22, #22, #23, #55, #33, #00, #02, #22, #22, #22, #35, #55
            db #22, #22, #22, #22, #23, #55, #55, #55, #22, #22, #22, #22, #35, #55, #55, #55
            db #22, #22, #22, #22, #35, #56, #C5, #55, #22, #33, #33, #33, #55, #55, #55, #55
            db #33, #00, #00, #06, #55, #55, #62, #22, #00, #FF, #FF, #F0, #45, #56, #22, #22
            db #FF, #FF, #FF, #04, #56, #C6, #22, #22, #FF, #FF, #FF, #04, #55, #56, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #40, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #54, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #00, #FF, #FF, #FF, #FF, #FF, #FF, #55, #44, #0F, #FF, #FF, #FF, #FF, #FF
            db #35, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #23, #55, #0F, #FF, #FF, #FF, #FF, #FF, #23, #55, #40, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #04, #55, #56, #22, #22, #FF, #FF, #FF, #06, #55, #56, #22, #22
            db #FF, #FF, #FF, #F0, #36, #33, #62, #22, #FF, #FF, #FF, #03, #63, #36, #32, #22
            db #FF, #FF, #FF, #03, #33, #33, #03, #22, #FF, #FF, #FF, #03, #33, #33, #00, #22
            db #FF, #FF, #FF, #03, #33, #33, #00, #22, #FF, #FF, #FF, #03, #33, #33, #00, #22
            db #FF, #FF, #FF, #F0, #33, #33, #30, #22, #FF, #FF, #FF, #F0, #33, #33, #30, #22
            db #FF, #FF, #FF, #FF, #03, #33, #30, #22, #FF, #FF, #FF, #FF, #03, #33, #33, #22
            db #FF, #FF, #FF, #FF, #03, #33, #33, #22, #FF, #FF, #FF, #FF, #03, #33, #33, #99
            db #FF, #FF, #FF, #FF, #F0, #03, #00, #99, #FF, #FF, #FF, #FF, #FF, #F0, #F0, #99
            db #23, #55, #50, #FF, #FF, #FF, #FF, #FF, #22, #36, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #06, #0F, #FF, #FF, #FF, #FF, #22, #20, #60, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #0F, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #99, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #99, #99, #0F, #FF, #FF, #FF, #FF, #FF, #99, #99, #0F, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00
            db #FF, #FF, #FF, #FF, #FF, #F0, #07, #77, #FF, #FF, #FF, #FF, #FF, #07, #77, #77
            db #FF, #FF, #FF, #FF, #F0, #77, #77, #B7, #FF, #FF, #FF, #FF, #07, #77, #71, #77
            db #FF, #FF, #FF, #FF, #07, #77, #77, #77, #FF, #FF, #FF, #FF, #07, #77, #72, #22
            db #FF, #FF, #FF, #F0, #77, #77, #72, #22, #FF, #FF, #FF, #F0, #77, #77, #72, #22
            db #FF, #FF, #FF, #FF, #07, #77, #22, #22, #FF, #FF, #FF, #FF, #07, #77, #72, #22
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #70, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #77, #70, #FF, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #0F, #FF, #FF, #FF, #FF, #FF, #77, #77, #70, #FF, #FF, #FF, #FF, #FF
            db #77, #77, #72, #0F, #FF, #FF, #FF, #FF, #27, #77, #72, #0F, #FF, #FF, #FF, #FF
            db #27, #77, #77, #0F, #FF, #FF, #FF, #FF, #27, #77, #77, #0F, #FF, #FF, #FF, #FF
            db #22, #77, #72, #0F, #FF, #FF, #FF, #FF, #22, #22, #22, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #07, #77, #72, #22, #FF, #FF, #FF, #FF, #07, #77, #72, #22
            db #FF, #FF, #FF, #FF, #07, #77, #70, #22, #FF, #FF, #FF, #FF, #07, #77, #72, #22
            db #FF, #FF, #FF, #FF, #07, #77, #72, #22, #FF, #FF, #FF, #FF, #F0, #77, #33, #22
            db #FF, #FF, #FF, #FF, #F0, #77, #33, #22, #FF, #FF, #FF, #FF, #FF, #03, #33, #22
            db #FF, #FF, #FF, #FF, #FF, #03, #33, #35, #FF, #FF, #FF, #FF, #FF, #03, #33, #35
            db #FF, #FF, #FF, #FF, #FF, #05, #33, #35, #FF, #FF, #FF, #FF, #FF, #05, #33, #35
            db #FF, #FF, #FF, #FF, #FF, #F0, #33, #33, #FF, #FF, #FF, #FF, #FF, #05, #53, #33
            db #FF, #FF, #FF, #FF, #FF, #05, #53, #33, #FF, #FF, #FF, #FF, #F0, #55, #C3, #33
            db #2B, #B0, #22, #0F, #FF, #FF, #FF, #FF, #22, #20, #00, #FF, #FF, #FF, #FF, #FF
            db #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #C5, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #FF, #05, #55, #55, #C5, #FF, #FF, #FF, #FF, #05, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #03, #33, #00, #FF, #FF, #FF, #FF, #FF, #03, #33, #00
            db #FF, #FF, #FF, #FF, #F0, #33, #33, #00, #FF, #FF, #FF, #FF, #F0, #33, #33, #00
            db #FF, #FF, #FF, #FF, #F0, #33, #33, #00, #FF, #FF, #FF, #FF, #F0, #33, #33, #00
            db #FF, #FF, #FF, #FF, #FF, #03, #33, #00, #FF, #FF, #FF, #FF, #FF, #03, #33, #00
            db #FF, #FF, #FF, #FF, #FF, #03, #33, #00, #FF, #FF, #FF, #FF, #F0, #03, #33, #00
            db #FF, #FF, #FF, #FF, #09, #99, #99, #00, #FF, #FF, #FF, #FF, #09, #99, #99, #00
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #5C, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #0F, #FF, #FF, #FF, #FF, #FF, #22, #22, #0F, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #FF, #FF, #FF, #FF, #FF, #FF, #22, #20, #0F, #FF, #FF, #FF, #FF, #FF
            db #99, #99, #90, #FF, #FF, #FF, #FF, #FF, #99, #99, #90, #FF, #FF, #FF, #FF, #FF
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
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #00, #44, #FF, #FF, #FF, #FF, #FF, #F0, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #55, #FF, #FF, #FF, #FF, #FF, #04, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #45, #55, #55, #FF, #FF, #00, #00, #00, #45, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #00, #0F, #FF, #FF, #FF, #FF
            db #44, #44, #44, #40, #00, #00, #00, #FF, #44, #44, #66, #66, #66, #44, #44, #0F
            db #55, #55, #5E, #EE, #E4, #44, #44, #0F, #55, #55, #5E, #EE, #05, #55, #55, #0F
            db #55, #55, #55, #EE, #55, #55, #55, #40, #55, #55, #55, #55, #55, #55, #55, #40
            db #55, #55, #55, #55, #55, #55, #55, #50, #55, #55, #55, #55, #55, #50, #00, #0F
            db #55, #55, #51, #51, #01, #01, #01, #0F, #55, #55, #55, #55, #45, #44, #44, #0F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F
            db #FF, #FF, #F0, #00, #00, #04, #44, #40, #FF, #F0, #04, #44, #44, #44, #44, #44
            db #FF, #04, #44, #44, #44, #45, #55, #54, #FF, #F0, #45, #55, #55, #55, #55, #DD
            db #FF, #FF, #05, #55, #5D, #D5, #55, #55, #FF, #FF, #F0, #05, #55, #55, #55, #55
            db #FF, #FF, #FF, #F0, #55, #55, #55, #55, #FF, #FF, #FF, #FF, #05, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #F0, #05, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #55, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #05, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #00, #44, #44, #44, #55, #55, #55, #00, #44, #44, #44, #44, #55, #55, #55
            db #44, #44, #55, #55, #55, #DD, #55, #55, #44, #55, #DD, #55, #55, #55, #55, #55
            db #55, #55, #55, #55, #55, #55, #55, #DD, #55, #55, #55, #55, #55, #55, #55, #55
            db #55, #55, #55, #5D, #D5, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55
            db #55, #55, #55, #22, #22, #22, #55, #55, #55, #52, #22, #22, #22, #22, #22, #25
            db #55, #22, #22, #22, #25, #55, #52, #22, #52, #66, #66, #22, #55, #55, #55, #22
            db #56, #66, #66, #65, #55, #55, #55, #52, #56, #66, #66, #65, #55, #55, #55, #52
            db #66, #66, #66, #65, #55, #55, #55, #52, #66, #66, #66, #65, #55, #55, #55, #52
            db #55, #55, #55, #55, #45, #45, #40, #FF, #55, #55, #55, #55, #55, #55, #50, #FF
            db #55, #55, #55, #55, #55, #55, #0F, #FF, #55, #55, #55, #00, #00, #00, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #33, #30, #0F, #FF, #FF, #FF, #FF, #FF, #33, #33, #30, #FF, #FF, #FF, #FF, #FF
            db #25, #33, #33, #0F, #FF, #FF, #FF, #FF, #25, #00, #01, #0F, #FF, #FF, #FF, #FF
            db #20, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #06
            db #66, #66, #66, #62, #55, #55, #55, #55, #66, #66, #66, #22, #55, #55, #55, #55
            db #66, #66, #66, #00, #05, #55, #55, #55, #66, #66, #60, #FF, #05, #55, #55, #55
            db #66, #66, #60, #FF, #05, #55, #55, #55, #66, #66, #60, #FF, #F0, #55, #55, #55
            db #66, #66, #0F, #FF, #F0, #55, #55, #55, #66, #66, #0F, #FF, #FF, #05, #55, #55
            db #66, #66, #0F, #FF, #FF, #05, #55, #55, #66, #66, #0F, #FF, #FF, #05, #55, #55
            db #66, #66, #0F, #FF, #FF, #05, #55, #55, #66, #66, #0F, #FF, #FF, #05, #55, #55
            db #66, #66, #0F, #FF, #FF, #05, #55, #55, #66, #66, #00, #00, #FF, #05, #55, #55
            db #66, #66, #66, #66, #0F, #05, #55, #55, #66, #66, #66, #66, #0F, #05, #55, #55
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #40, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #40, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF
            db #44, #44, #40, #FF, #FF, #FF, #FF, #FF, #44, #44, #40, #FF, #FF, #FF, #FF, #FF
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
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #00, #44, #FF, #FF, #FF, #FF, #FF, #F0, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #44, #55, #FF, #FF, #FF, #FF, #FF, #04, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #45, #55, #55, #FF, #FF, #00, #00, #00, #45, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #00, #0F, #FF, #FF, #FF, #FF
            db #44, #44, #44, #40, #00, #00, #00, #FF, #44, #44, #66, #66, #66, #44, #44, #0F
            db #55, #55, #5E, #EE, #E4, #44, #44, #0F, #55, #55, #5E, #EE, #05, #55, #55, #0F
            db #55, #55, #55, #EE, #55, #55, #55, #40, #55, #55, #55, #55, #55, #55, #55, #40
            db #55, #55, #55, #55, #55, #55, #55, #50, #55, #55, #55, #55, #55, #50, #00, #0F
            db #55, #55, #55, #1B, #1B, #1B, #1B, #10, #55, #55, #55, #BB, #BB, #BB, #BB, #0F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F
            db #FF, #FF, #F0, #00, #00, #04, #44, #40, #FF, #F0, #04, #44, #44, #44, #44, #44
            db #FF, #04, #44, #44, #44, #45, #55, #54, #FF, #F0, #45, #55, #55, #55, #55, #DD
            db #FF, #FF, #05, #55, #5D, #D5, #55, #55, #FF, #FF, #F0, #05, #55, #55, #55, #55
            db #FF, #FF, #FF, #F0, #55, #55, #55, #55, #FF, #FF, #FF, #FF, #05, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #05, #55, #55, #FF, #FF, #FF, #FF, #FF, #F0, #05, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #55, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #05, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #00, #44, #44, #44, #55, #55, #55, #00, #44, #44, #44, #44, #55, #55, #55
            db #44, #44, #55, #55, #55, #DD, #55, #55, #44, #55, #DD, #55, #55, #55, #55, #55
            db #55, #55, #55, #55, #55, #55, #55, #DD, #55, #55, #55, #55, #55, #55, #55, #55
            db #55, #55, #55, #5D, #D5, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55
            db #55, #55, #55, #22, #22, #22, #55, #55, #55, #52, #22, #22, #22, #22, #22, #25
            db #55, #22, #22, #22, #25, #55, #52, #22, #52, #66, #66, #22, #55, #55, #55, #22
            db #56, #66, #66, #65, #55, #55, #55, #52, #56, #66, #66, #65, #55, #55, #55, #52
            db #56, #66, #66, #65, #55, #55, #55, #52, #56, #66, #66, #65, #55, #55, #55, #52
            db #55, #55, #55, #5B, #BB, #BB, #BB, #0F, #55, #55, #55, #55, #BB, #BB, #BB, #0F
            db #55, #55, #55, #55, #55, #BB, #BB, #00, #55, #55, #55, #51, #51, #51, #B1, #01
            db #55, #55, #55, #55, #55, #55, #5B, #00, #55, #55, #50, #05, #55, #55, #50, #FF
            db #55, #55, #0F, #F0, #05, #55, #50, #FF, #55, #50, #FF, #FF, #F0, #05, #0F, #FF
            db #55, #50, #FF, #FF, #FF, #F0, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #33, #30, #0F, #FF, #FF, #FF, #FF, #FF, #33, #33, #30, #FF, #FF, #FF, #FF, #FF
            db #25, #33, #33, #0F, #FF, #FF, #FF, #FF, #25, #00, #01, #0F, #FF, #FF, #FF, #FF
            db #20, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #06, #66, #66, #65, #55, #55, #55, #50, #06, #66, #66, #65, #55, #55, #55, #50
            db #06, #66, #66, #65, #55, #55, #55, #50, #06, #66, #66, #60, #55, #55, #55, #0F
            db #06, #66, #66, #60, #55, #55, #55, #0F, #06, #66, #66, #60, #55, #55, #55, #0F
            db #06, #66, #66, #60, #55, #55, #55, #0F, #06, #66, #66, #60, #55, #55, #55, #0F
            db #F0, #66, #66, #60, #55, #55, #55, #0F, #F0, #66, #66, #60, #55, #55, #55, #0F
            db #F0, #66, #66, #60, #55, #55, #50, #FF, #FF, #06, #66, #60, #55, #55, #50, #FF
            db #FF, #06, #66, #60, #55, #55, #50, #FF, #FF, #06, #66, #60, #55, #55, #50, #00
            db #F0, #66, #66, #66, #55, #55, #54, #44, #F0, #66, #66, #66, #55, #55, #54, #44
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #44, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #44, #0F, #FF, #FF, #FF, #FF, #FF, #FF
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
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #04
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #05, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #05
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #00, #00, #FF
            db #FF, #FF, #F0, #44, #44, #44, #44, #0F, #FF, #FF, #04, #55, #55, #55, #55, #40
            db #FF, #F0, #45, #55, #55, #55, #50, #50, #FF, #04, #55, #55, #55, #55, #55, #50
            db #F0, #45, #55, #55, #55, #55, #55, #50, #F0, #55, #55, #55, #00, #55, #53, #33
            db #04, #55, #55, #55, #0F, #00, #00, #00, #05, #55, #55, #50, #FF, #FF, #FF, #FF
            db #45, #55, #55, #0F, #FF, #FF, #FF, #FF, #55, #55, #55, #0F, #FF, #FF, #FF, #FF
            db #55, #55, #50, #FF, #FF, #FF, #FF, #FF, #55, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00
            db #FF, #FF, #FF, #FF, #FF, #00, #04, #44, #FF, #FF, #FF, #FF, #00, #44, #45, #55
            db #FF, #FF, #FF, #00, #44, #55, #55, #55, #FF, #FF, #F0, #44, #55, #55, #55, #55
            db #FF, #FF, #04, #55, #55, #55, #CC, #55, #FF, #FF, #05, #55, #55, #55, #55, #55
            db #FF, #F0, #45, #55, #55, #55, #55, #55, #FF, #04, #55, #55, #55, #55, #55, #5C
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #45, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #04, #55, #FF, #FF, #FF, #FF, #FF, #FF, #05, #55
            db #FF, #FF, #FF, #FF, #FF, #F0, #45, #55, #FF, #FF, #FF, #FF, #FF, #F0, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #F0, #55, #55, #00, #00, #00, #0F, #FF, #04, #55, #55
            db #44, #44, #44, #40, #00, #05, #55, #55, #55, #55, #55, #54, #44, #45, #55, #55
            db #55, #CC, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55
            db #55, #55, #55, #55, #CC, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55, #55
            db #55, #55, #5C, #C5, #55, #55, #55, #55, #C5, #55, #55, #55, #55, #55, #55, #55
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #05, #55, #55, #55, #55, #52, #22, #F0, #45, #55, #55, #52, #22, #22, #22
            db #F0, #55, #55, #55, #22, #22, #22, #22, #04, #55, #55, #52, #22, #22, #22, #22
            db #05, #55, #50, #66, #66, #65, #55, #55, #45, #55, #00, #66, #66, #65, #55, #55
            db #05, #50, #F0, #66, #66, #65, #55, #55, #F0, #0F, #F0, #66, #66, #65, #55, #55
            db #FF, #FF, #F0, #66, #66, #65, #55, #55, #FF, #FF, #F0, #66, #66, #65, #55, #55
            db #FF, #FF, #F0, #66, #66, #65, #55, #55, #FF, #FF, #F0, #66, #66, #65, #55, #55
            db #FF, #FF, #F0, #66, #66, #65, #55, #55, #FF, #FF, #F0, #66, #66, #65, #55, #55
            db #FF, #FF, #06, #66, #66, #66, #66, #66, #FF, #FF, #06, #66, #66, #66, #66, #66
            db #22, #22, #22, #25, #55, #55, #55, #55, #22, #22, #22, #22, #22, #25, #55, #55
            db #22, #22, #22, #22, #22, #22, #55, #50, #22, #22, #22, #22, #22, #22, #25, #50
            db #22, #22, #26, #66, #66, #55, #55, #50, #22, #22, #26, #66, #66, #55, #55, #50
            db #22, #22, #26, #66, #66, #55, #55, #50, #22, #22, #26, #66, #66, #55, #55, #50
            db #00, #00, #06, #66, #66, #55, #55, #50, #0F, #FF, #06, #66, #66, #55, #55, #50
            db #0F, #FF, #06, #66, #66, #55, #55, #50, #0F, #FF, #06, #66, #66, #55, #55, #50
            db #0F, #FF, #06, #66, #66, #55, #55, #50, #0F, #FF, #06, #66, #66, #55, #55, #50
            db #60, #F0, #66, #66, #66, #66, #66, #66, #60, #F0, #66, #66, #66, #66, #66, #66
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #E0, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #0F, #FF, #0F
            db #FF, #FF, #F0, #E0, #FF, #FF, #F0, #E0, #FF, #FF, #FF, #0F, #FF, #FF, #00, #0F
            db #FF, #FF, #FF, #FF, #FF, #F0, #22, #20, #FF, #FF, #FF, #00, #FF, #02, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #77, #0F, #02, #22, #22, #FF, #FF, #07, #77, #70, #F0, #22, #22
            db #FF, #FF, #07, #77, #70, #00, #02, #22, #FF, #FF, #07, #77, #72, #22, #22, #22
            db #FF, #FF, #F0, #77, #77, #22, #22, #22, #FF, #FF, #F0, #77, #77, #22, #00, #22
            db #FF, #FF, #F0, #77, #77, #22, #22, #22, #FF, #FF, #F0, #77, #77, #22, #22, #22
            db #FF, #FF, #F0, #77, #77, #22, #22, #BB, #FF, #FF, #FF, #07, #77, #72, #22, #BB
            db #FF, #FF, #FF, #07, #77, #72, #22, #55, #FF, #FF, #FF, #07, #77, #00, #00, #55
            db #FF, #FF, #FF, #F0, #00, #FF, #06, #00, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #20, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #22, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #20, #00, #00, #00, #0F, #FF, #FF, #22, #22, #55, #55, #55, #50, #00, #FF
            db #22, #22, #55, #55, #55, #55, #55, #00, #22, #22, #55, #55, #55, #55, #55, #55
            db #22, #22, #55, #55, #55, #55, #22, #22, #55, #55, #55, #55, #55, #52, #22, #22
            db #55, #55, #55, #55, #55, #52, #22, #22, #55, #55, #55, #55, #55, #52, #22, #22
            db #55, #55, #55, #55, #55, #52, #22, #22, #55, #55, #55, #55, #55, #55, #22, #22
            db #65, #56, #55, #65, #56, #50, #60, #00, #00, #00, #00, #00, #00, #0F, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #00, #FF, #FF, #00, #0F, #00, #00, #02, #22, #0F, #F0, #99, #90
            db #22, #22, #22, #22, #20, #F0, #99, #90, #22, #22, #22, #22, #22, #00, #99, #90
            db #22, #22, #22, #22, #22, #22, #99, #90, #22, #22, #22, #22, #22, #22, #99, #92
            db #22, #22, #22, #22, #22, #22, #99, #92, #20, #00, #00, #22, #22, #22, #22, #22
            db #0F, #FF, #FF, #00, #00, #00, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF, #FF, #00, #00
            db #04, #44, #40, #00, #00, #00, #44, #44, #F0, #55, #54, #44, #44, #44, #55, #55
            db #FF, #05, #55, #55, #D5, #55, #D5, #55, #FF, #F0, #05, #55, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #44, #0F, #0F, #FF, #FF, #FF, #FF, #F0, #55, #E0, #40, #0F
            db #FF, #FF, #FF, #F0, #55, #55, #54, #40, #00, #FF, #FF, #F0, #55, #55, #55, #50
            db #44, #00, #0F, #F0, #55, #55, #55, #50, #D5, #44, #40, #0F, #05, #55, #55, #0F
            db #55, #55, #54, #40, #F0, #00, #00, #FF, #55, #5D, #55, #54, #0F, #FF, #FF, #FF
            db #FF, #FF, #F0, #55, #55, #55, #52, #22, #FF, #FF, #FF, #05, #55, #55, #22, #22
            db #FF, #FF, #FF, #F0, #55, #52, #66, #22, #FF, #FF, #FF, #FF, #05, #56, #66, #65
            db #FF, #FF, #FF, #FF, #F0, #66, #66, #65, #FF, #FF, #FF, #FF, #F0, #66, #66, #22
            db #FF, #FF, #FF, #FF, #06, #66, #66, #00, #FF, #FF, #FF, #FF, #06, #66, #60, #FF
            db #FF, #FF, #FF, #F0, #66, #66, #0F, #FF, #FF, #FF, #FF, #F0, #66, #60, #FF, #FF
            db #FF, #FF, #FF, #F0, #66, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #25, #33, #55, #40, #0F, #FF, #FF, #22, #22, #33, #33, #54, #40, #FF, #FF
            db #55, #22, #25, #33, #35, #50, #FF, #FF, #55, #52, #20, #00, #55, #50, #FF, #FF
            db #55, #55, #0F, #FF, #00, #0F, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #40, #FF, #FF, #FF, #FF, #FF, #05, #55, #50, #FF, #FF, #FF, #FF, #FF
            db #F0, #55, #54, #0F, #FF, #FF, #FF, #FF, #FF, #05, #55, #0F, #FF, #FF, #FF, #FF
            db #FF, #F0, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF, #FF, #00, #00
            db #04, #44, #40, #00, #00, #00, #44, #44, #F0, #55, #54, #44, #44, #44, #55, #55
            db #FF, #05, #55, #55, #D5, #55, #D5, #55, #FF, #F0, #05, #55, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #44, #0F, #0F, #FF, #FF, #FF, #FF, #F0, #55, #E0, #40, #0F
            db #FF, #FF, #FF, #F0, #55, #55, #54, #40, #00, #FF, #FF, #F0, #55, #55, #55, #50
            db #44, #00, #0F, #F0, #55, #55, #55, #50, #D5, #44, #40, #0F, #05, #55, #55, #0F
            db #55, #55, #54, #40, #F0, #00, #00, #FF, #55, #5D, #55, #54, #0F, #FF, #FF, #FF
            db #FF, #FF, #F0, #55, #55, #55, #52, #22, #FF, #FF, #FF, #05, #55, #55, #22, #22
            db #FF, #FF, #FF, #F0, #55, #52, #66, #22, #FF, #FF, #FF, #FF, #05, #56, #66, #65
            db #FF, #FF, #FF, #FF, #F0, #56, #66, #65, #FF, #FF, #FF, #FF, #FF, #00, #66, #55
            db #FF, #FF, #FF, #FF, #FF, #F0, #66, #55, #FF, #FF, #FF, #FF, #FF, #FF, #06, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #05, #55, #FF, #FF, #FF, #FF, #FF, #FF, #05, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #05, #55, #FF, #FF, #FF, #FF, #FF, #FF, #05, #50
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #25, #33, #55, #40, #0F, #FF, #FF, #22, #22, #33, #33, #54, #40, #FF, #FF
            db #55, #22, #25, #33, #35, #50, #FF, #FF, #55, #52, #20, #00, #55, #50, #FF, #FF
            db #55, #52, #0F, #FF, #00, #0F, #FF, #FF, #55, #20, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #50, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #66, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #60, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #0F, #FF, #FF, #FF, #00, #00
            db #04, #44, #40, #00, #00, #00, #44, #44, #F0, #55, #54, #44, #44, #44, #55, #55
            db #FF, #05, #55, #55, #D5, #55, #D5, #55, #FF, #F0, #05, #55, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #44, #0F, #0F, #FF, #FF, #FF, #FF, #F0, #55, #E0, #40, #0F
            db #FF, #FF, #FF, #F0, #55, #55, #54, #40, #00, #FF, #FF, #F0, #55, #55, #55, #50
            db #44, #00, #0F, #F0, #55, #BB, #BB, #B0, #D5, #44, #40, #0F, #05, #5B, #BB, #B0
            db #55, #55, #54, #40, #F0, #55, #BB, #B0, #55, #5D, #55, #54, #0F, #05, #55, #B0
            db #FF, #FF, #F0, #55, #55, #55, #52, #22, #FF, #FF, #FF, #05, #55, #55, #22, #22
            db #FF, #FF, #FF, #F0, #55, #52, #66, #22, #FF, #FF, #FF, #FF, #05, #56, #66, #65
            db #FF, #FF, #FF, #FF, #F0, #56, #66, #65, #FF, #FF, #FF, #FF, #FF, #06, #66, #65
            db #FF, #FF, #FF, #FF, #F0, #66, #66, #00, #FF, #FF, #FF, #FF, #F0, #66, #66, #00
            db #FF, #FF, #FF, #FF, #F0, #66, #60, #F0, #FF, #FF, #FF, #FF, #F0, #66, #60, #F0
            db #FF, #FF, #FF, #FF, #06, #66, #60, #FF, #FF, #FF, #FF, #FF, #F0, #66, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #25, #33, #55, #40, #00, #05, #0F, #22, #22, #33, #33, #54, #40, #F0, #FF
            db #55, #22, #25, #33, #35, #50, #FF, #FF, #55, #52, #20, #00, #55, #50, #FF, #FF
            db #55, #52, #0F, #FF, #00, #0F, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #50, #FF, #FF, #FF, #FF, #FF, #FF, #55, #50, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #54, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #05, #55, #0F, #FF, #FF, #FF, #FF, #FF, #05, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #F0, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #45, #55, #FF, #FF, #FF, #FF, #F0, #45, #55, #55
            db #FF, #FF, #00, #00, #04, #55, #55, #DD, #00, #00, #44, #44, #45, #55, #55, #55
            db #44, #44, #55, #55, #55, #55, #55, #55, #05, #55, #55, #55, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #DC, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #CC
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #CC, #00, #00, #00, #00, #FF, #FF, #F0, #CC
            db #44, #44, #44, #44, #00, #0F, #F0, #CC, #55, #55, #55, #55, #44, #40, #0F, #0C
            db #55, #55, #55, #55, #55, #54, #40, #0C, #55, #55, #DD, #55, #55, #55, #54, #0C
            db #55, #55, #55, #55, #55, #55, #55, #4C, #55, #55, #55, #55, #5D, #D5, #55, #5C
            db #55, #55, #55, #55, #55, #55, #55, #5C, #5D, #D5, #55, #55, #55, #55, #55, #5C
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #00, #00, #FF, #FF, #FF, #F0, #FF, #FF, #DC, #CC, #00, #FF, #FF, #01, #0F, #0F
            db #CC, #DC, #CC, #0F, #F0, #10, #F0, #10, #CC, #CC, #DC, #0F, #01, #0F, #01, #0F
            db #CC, #CC, #CC, #00, #11, #00, #10, #FF, #CC, #CC, #CC, #C1, #10, #11, #0F, #FF
            db #CC, #CC, #CC, #11, #01, #11, #0F, #FF, #CC, #CC, #C1, #11, #11, #10, #FF, #FF
            db #CC, #CC, #11, #11, #11, #50, #FF, #0F, #CC, #CC, #51, #55, #15, #54, #00, #10
            db #CC, #C5, #55, #55, #55, #55, #41, #0F, #CC, #55, #55, #55, #5E, #05, #11, #0F
            db #F0, #55, #55, #55, #55, #55, #55, #55, #FF, #05, #55, #55, #55, #55, #55, #52
            db #FF, #F0, #55, #55, #55, #55, #22, #22, #FF, #FF, #00, #00, #55, #52, #22, #22
            db #FF, #FF, #FF, #F0, #55, #22, #22, #22, #FF, #FF, #FF, #FF, #05, #22, #22, #22
            db #FF, #FF, #FF, #F0, #66, #66, #62, #55, #FF, #FF, #FF, #F0, #66, #66, #62, #55
            db #FF, #FF, #FF, #F0, #66, #66, #65, #55, #FF, #FF, #FF, #F0, #66, #66, #60, #55
            db #FF, #FF, #FF, #F0, #66, #66, #60, #55, #FF, #FF, #FF, #F0, #66, #66, #60, #55
            db #FF, #FF, #FF, #F0, #66, #66, #60, #55, #FF, #FF, #FF, #F0, #66, #66, #60, #55
            db #FF, #FF, #FF, #06, #66, #66, #66, #66, #FF, #FF, #FF, #06, #66, #66, #66, #66
            db #55, #55, #55, #55, #55, #55, #55, #5C, #22, #22, #22, #22, #25, #55, #55, #5C
            db #22, #22, #22, #22, #22, #22, #55, #55, #22, #22, #22, #22, #22, #22, #25, #55
            db #22, #22, #22, #22, #22, #22, #22, #55, #22, #22, #22, #22, #22, #22, #22, #50
            db #55, #52, #22, #22, #66, #66, #65, #54, #55, #52, #22, #22, #66, #66, #65, #55
            db #55, #52, #22, #22, #66, #66, #65, #55, #55, #55, #55, #55, #66, #66, #65, #55
            db #55, #50, #00, #00, #66, #66, #65, #55, #55, #50, #FF, #F0, #66, #66, #65, #55
            db #55, #50, #FF, #F0, #66, #66, #65, #55, #55, #50, #FF, #F0, #66, #66, #65, #55
            db #66, #66, #0F, #06, #66, #66, #66, #66, #66, #66, #0F, #06, #66, #66, #66, #66
            db #CC, #55, #55, #55, #55, #55, #55, #0F, #CC, #55, #55, #55, #55, #55, #55, #0F
            db #CC, #55, #55, #55, #55, #55, #A5, #0F, #CC, #C5, #55, #55, #55, #55, #AA, #0F
            db #CC, #C0, #55, #55, #55, #55, #AA, #0F, #C0, #0F, #05, #55, #55, #50, #A0, #FF
            db #54, #0F, #F0, #00, #00, #0F, #0F, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #55, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #66, #60, #FF, #FF, #FF, #FF, #FF, #FF, #66, #60, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #FF, #FF, #FF, #FF, #FF, #F0, #04, #44
            db #FF, #FF, #FF, #FF, #FF, #04, #45, #55, #FF, #FF, #FF, #FF, #F0, #45, #55, #55
            db #FF, #FF, #00, #00, #04, #55, #55, #DD, #00, #00, #44, #44, #45, #55, #55, #55
            db #44, #44, #55, #55, #55, #55, #55, #55, #05, #55, #55, #55, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #DC, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #CC
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #CC, #00, #00, #00, #00, #FF, #FF, #F0, #CC
            db #44, #44, #44, #44, #00, #0F, #F0, #CC, #55, #55, #55, #55, #44, #40, #0F, #0C
            db #55, #55, #55, #55, #55, #54, #40, #0C, #55, #55, #DD, #55, #55, #55, #54, #0C
            db #55, #55, #55, #55, #55, #55, #55, #4C, #55, #55, #55, #55, #5D, #D5, #55, #5C
            db #55, #55, #55, #55, #55, #55, #55, #5C, #5D, #D5, #55, #55, #55, #55, #55, #5C
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #00, #00, #FF, #FF, #FF, #F0, #FF, #FF, #DC, #CC, #00, #FF, #FF, #01, #0F, #0F
            db #CC, #DC, #CC, #0F, #F0, #10, #F0, #10, #CC, #CC, #DC, #0F, #01, #0F, #01, #0F
            db #CC, #CC, #CC, #00, #11, #00, #10, #FF, #CC, #CC, #CC, #C1, #10, #11, #0F, #FF
            db #CC, #CC, #CC, #11, #01, #11, #0F, #FF, #CC, #CC, #C1, #11, #11, #10, #FF, #FF
            db #CC, #CC, #11, #11, #11, #50, #FF, #0F, #CC, #CC, #51, #55, #15, #54, #00, #10
            db #CC, #C5, #55, #55, #55, #55, #41, #0F, #CC, #55, #55, #55, #5E, #05, #11, #0F
            db #F0, #55, #55, #55, #55, #55, #55, #55, #FF, #05, #55, #55, #55, #55, #55, #52
            db #FF, #F0, #55, #55, #55, #55, #22, #22, #FF, #FF, #00, #00, #55, #52, #22, #22
            db #FF, #FF, #FF, #F0, #55, #22, #22, #22, #FF, #FF, #FF, #FF, #05, #22, #22, #22
            db #FF, #FF, #FF, #FF, #F0, #66, #55, #55, #FF, #FF, #FF, #FF, #F0, #66, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #66, #55, #55, #FF, #FF, #FF, #FF, #F0, #66, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #66, #55, #55, #FF, #FF, #FF, #FF, #F0, #66, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #66, #55, #55, #FF, #FF, #FF, #FF, #F0, #66, #55, #55
            db #FF, #FF, #FF, #FF, #06, #66, #66, #66, #FF, #FF, #FF, #FF, #06, #66, #66, #66
            db #55, #55, #55, #55, #55, #55, #55, #5C, #22, #22, #22, #22, #25, #55, #55, #5C
            db #22, #22, #22, #22, #22, #22, #55, #55, #22, #22, #22, #22, #22, #22, #25, #55
            db #22, #22, #22, #22, #22, #22, #22, #55, #22, #22, #22, #22, #22, #22, #22, #50
            db #52, #22, #22, #66, #66, #62, #25, #04, #52, #22, #22, #66, #66, #62, #50, #05
            db #52, #22, #22, #66, #66, #60, #0F, #05, #55, #55, #55, #66, #66, #60, #FF, #05
            db #50, #00, #00, #66, #66, #60, #FF, #05, #50, #FF, #F0, #66, #66, #60, #FF, #05
            db #50, #FF, #F0, #66, #66, #60, #FF, #05, #50, #FF, #F0, #66, #66, #60, #FF, #05
            db #66, #0F, #06, #66, #66, #66, #00, #66, #66, #0F, #06, #66, #66, #66, #00, #66
            db #CC, #55, #55, #55, #55, #55, #55, #0F, #CC, #55, #55, #55, #55, #55, #55, #0F
            db #CC, #55, #55, #55, #55, #55, #A5, #0F, #CC, #C5, #55, #55, #55, #55, #AA, #0F
            db #CC, #C0, #55, #55, #55, #55, #AA, #0F, #C0, #00, #05, #55, #55, #50, #A0, #FF
            db #54, #44, #00, #00, #00, #0F, #0F, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #55, #55, #0F, #FF, #FF, #FF, #FF, #FF, #55, #55, #0F, #FF, #FF, #FF, #FF, #FF
            db #66, #66, #60, #FF, #FF, #FF, #FF, #FF, #66, #66, #60, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #00, #00, #00, #00, #00, #00, #FF, #F0, #00, #00, #00, #00, #00, #00, #0F
            db #F0, #00, #00, #00, #00, #00, #00, #0F, #FF, #00, #00, #00, #00, #00, #00, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #F1, #FE, #FF, #FF, #FF
            db #FF, #FF, #FF, #11, #1F, #FF, #FF, #FF, #FE, #EE, #E1, #1F, #11, #EE, #EE, #FF
            db #FF, #FF, #FF, #11, #1F, #FF, #FF, #FF, #FF, #FF, #FE, #F1, #FE, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #04, #00, #0F, #FF, #FF, #F0
            db #FF, #FF, #F0, #04, #40, #00, #00, #06, #FF, #FF, #FF, #F0, #04, #44, #44, #66
            db #FF, #FF, #FF, #FF, #05, #55, #56, #66, #FF, #FF, #FF, #FF, #05, #55, #55, #55
            db #FF, #FF, #FF, #FF, #F0, #55, #55, #55, #FF, #FF, #FF, #FF, #FF, #00, #00, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #0F, #FF, #FF, #FF, #FF, #FF, #0F, #06, #60, #0F, #FF, #FF, #FF
            db #F0, #C0, #66, #66, #60, #FF, #FF, #FF, #FF, #0C, #66, #66, #60, #FF, #FF, #FF
            db #00, #66, #C6, #66, #0F, #FF, #FF, #FF, #66, #66, #6C, #60, #00, #00, #FF, #FF
            db #66, #66, #66, #05, #55, #55, #0F, #FF, #66, #66, #55, #55, #5E, #55, #50, #FF
            db #66, #66, #55, #55, #55, #55, #55, #0F, #55, #55, #55, #55, #55, #55, #50, #FF
            db #55, #55, #00, #00, #00, #00, #0F, #FF, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #00, #00, #00, #FF, #FF, #FF, #FF, #F0, #55, #55, #55
            db #FF, #FF, #FF, #F0, #04, #44, #44, #44, #FF, #FF, #F0, #04, #44, #44, #46, #66
            db #FF, #F0, #04, #44, #44, #45, #55, #66, #F0, #04, #44, #44, #00, #00, #00, #00
            db #04, #40, #00, #00, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0F, #FF, #FF, #FF, #FF, #FF, #FF
            db #F0, #C0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0C, #0F, #FF, #FF, #FF, #FF, #FF
            db #FF, #F0, #C0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0C, #00, #00, #00, #FF, #FF
            db #00, #00, #00, #05, #55, #55, #0F, #FF, #55, #55, #55, #55, #5E, #55, #50, #FF
            db #44, #55, #55, #55, #55, #55, #55, #0F, #66, #66, #55, #55, #55, #55, #50, #FF
            db #66, #66, #66, #00, #00, #00, #0F, #FF, #66, #66, #66, #66, #0F, #FF, #FF, #FF
            db #00, #66, #66, #66, #60, #FF, #FF, #FF, #FF, #06, #66, #66, #60, #FF, #FF, #FF
            db #FF, #F0, #06, #60, #0F, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #FF, #FF, #AA, #AA, #FF
            db #FF, #11, #AA, #AA, #11, #AA, #AA, #FF, #FF, #1A, #A1, #1A, #11, #AA, #AA, #FF
            db #FF, #FF, #A1, #AA, #11, #11, #FF, #FF, #FF, #FF, #F1, #1A, #AA, #AF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #00, #00, #00, #FF, #FF, #FF, #FF, #F0, #BB, #BB, #BB, #0F, #FF
            db #FF, #FF, #0B, #CC, #CC, #BB, #B0, #FF, #FF, #F0, #BC, #CC, #CC, #CB, #BB, #0F
            db #FF, #F0, #BC, #CC, #CC, #CB, #BB, #0F, #F0, #00, #BB, #CC, #CC, #BB, #BB, #0F
            db #01, #10, #BB, #BB, #BB, #BB, #BB, #0F, #01, #11, #11, #1B, #BB, #BB, #B0, #FF
            db #01, #11, #11, #1B, #BB, #BB, #0F, #FF, #01, #10, #00, #00, #00, #00, #FF, #FF
            db #F0, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #00, #00, #0F, #FF, #FF, #FF, #FF, #0A, #AA, #AA, #A0, #FF, #FF
            db #FF, #F0, #AA, #1A, #AA, #AA, #0F, #FF, #FF, #F0, #AA, #AA, #AA, #AA, #0F, #FF
            db #FF, #F0, #AA, #AA, #AA, #AA, #0F, #FF, #FF, #F0, #AA, #AA, #AD, #DA, #0F, #FF
            db #FF, #FF, #0A, #AA, #AD, #D0, #FF, #FF, #FF, #FF, #F0, #00, #00, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #0E, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #0E, #E0, #FF, #FF
            db #F0, #00, #00, #00, #0E, #EE, #0F, #FF, #0E, #EE, #EE, #EE, #EE, #EE, #E0, #FF
            db #0E, #EE, #EE, #EE, #EE, #EE, #EE, #0F, #0E, #EE, #EE, #EE, #EE, #EE, #EE, #E0
            db #0E, #EE, #EE, #EE, #EE, #EE, #EE, #E0, #0E, #EE, #EE, #EE, #EE, #EE, #EE, #0F
            db #0E, #EE, #EE, #EE, #EE, #EE, #E0, #FF, #F0, #00, #00, #00, #0E, #EE, #0F, #FF
            db #FF, #FF, #FF, #FF, #0E, #E0, #FF, #FF, #FF, #FF, #FF, #FF, #0E, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F0, #00, #0F, #F0, #00, #0F, #FF, #FF, #0B, #BB, #B0, #0B, #BB, #B0, #FF
            db #F0, #BB, #BB, #BB, #BB, #BB, #BB, #0F, #F0, #BB, #1B, #BB, #BB, #BB, #BB, #0F
            db #F0, #BB, #BB, #BB, #BB, #BB, #BB, #0F, #F0, #BB, #BB, #BB, #BB, #BB, #BB, #0F
            db #FF, #0B, #BB, #BB, #BB, #BB, #B0, #FF, #FF, #F0, #BB, #BB, #BB, #BB, #0F, #FF
            db #FF, #FF, #0B, #BB, #BB, #B0, #FF, #FF, #FF, #FF, #F0, #BB, #BB, #0F, #FF, #FF
            db #FF, #FF, #FF, #0B, #B0, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ld_end:
#endasm
End Sub
