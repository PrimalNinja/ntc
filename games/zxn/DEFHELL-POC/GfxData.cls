' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_SHIP = 0
Public Const S_SHIP_N = 3
Public Const S_SHIP_W = 2
Public Const S_LASER = 6
Public Const S_LASER_N = 1
Public Const S_HUMAN = 7
Public Const S_HUMAN_N = 3
Public Const S_GATE = 10
Public Const S_GATE_N = 2
Public Const S_STARS = 12
Public Const S_STARS_N = 1
Public Const S_WINDOW = 13
Public Const S_WINDOW_N = 1
Public Const S_MINE = 14
Public Const S_MINE_N = 1
Public Const S_LANDER = 15
Public Const S_LANDER_N = 2
Public Const S_MUTANT = 17
Public Const S_MUTANT_N = 2
Public Const S_BOMBER = 19
Public Const S_BOMBER_N = 2
Public Const S_POD = 21
Public Const S_POD_N = 2
Public Const S_SWARMER = 23
Public Const S_SWARMER_N = 2
Public Const S_BAITER = 25
Public Const S_BAITER_N = 2
Public Const S_FIREB = 27
Public Const S_FIREB_N = 2
Public Const S_FIREBALL = 29
Public Const S_FIREBALL_N = 2
Public Const S_DYNAMO = 31
Public Const S_DYNAMO_N = 2
Public Const S_HUM = 33
Public Const S_HUM_N = 2
Public Const S_GUPPY = 35
Public Const S_GUPPY_N = 2
Public Const S_PHRED = 37
Public Const S_PHRED_N = 2
Public Const S_MUNCHIE = 39
Public Const S_MUNCHIE_N = 2
Public Const S_BULLET = 41
Public Const S_BULLET_N = 2
Public Const S_BOOM = 43
Public Const S_BOOM_N = 4
Public Const S_ITEM = 47
Public Const S_ITEM_N = 4
Public Const S_BIGP = 51
Public Const S_BIGP_N = 2
Public Const S_GEM = 53
Public Const S_GEM_N = 2
Public Const S_GUARD = 55
Public Const S_GUARD_N = 1
Public Const S_SPARK = 56
Public Const S_SPARK_N = 1
Public Const S_BOSS1 = 57
Public Const S_BOSS1_N = 1
Public Const S_BOSS1_W = 2
Public Const S_BOSS1_H = 3
Public Const S_BOSS2 = 63
Public Const S_BOSS2_N = 1
Public Const S_BOSS2_W = 2
Public Const S_BOSS2_H = 3
Public Const S_BOSS3 = 69
Public Const S_BOSS3_N = 1
Public Const S_BOSS3_W = 2
Public Const S_BOSS3_H = 3
Public Const S_BOSS4 = 75
Public Const S_BOSS4_N = 1
Public Const S_BOSS4_W = 2
Public Const S_BOSS4_H = 3
Public Const S_BOSS5 = 81
Public Const S_BOSS5_N = 1
Public Const S_BOSS5_W = 2
Public Const S_BOSS5_H = 3
Public Const T_HUD = 1
Public Const T_SCAN = 2
Public Const T_SCANT = 3
Public Const T_SCANG = 4
Public Const T_LIFE = 5
Public Const T_SMART = 6
Public Const T_BLACK = 7
Public Const T_INV = 8
Public Const T_INVE = 9
Public Const T_SCANS = 10
Public Const T_DOT = 96
Public Const T_DOT_N = 60
Public Const SpritePatterns = 87
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
            ld bc, #303B            ; sprite patterns from pattern 0
            xor a
            out (c), a
            ld hl, #C000            ; 64 from bank 5 (#C000)
            ld de, 8192
            call ld_po
            ld hl, #F400            ; 20 from bank 5 (#F400)
            ld de, 2560
            call ld_po
            ld bc, #243B            ; the rest from bank 47 (its first page at #E000)
            ld a, #57
            out (c), a
            inc b
            ld a, 94
            out (c), a
            ld hl, #E000
            ld de, 384
            call ld_po
            ld bc, #243B
            ld a, #57               ; the tiles: its second page at #E000
            out (c), a
            inc b
            ld a, 95
            out (c), a
            dec b
            ld hl, #C000            ; every tile transparent (colour 15) first
            ld de, #C001
            ld bc, #1FFF
            ld (hl), #FF
            ldir
            ld hl, #E000
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
            jr ld_done
            ld bc, #303B            ; sprite patterns from pattern 0
            xor a
            out (c), a
            ld hl, pats
            ld de, 11136
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
            ld bc, #243B            ; bank 5 back at #E000
            ld a, #57
            out (c), a
            inc b
            ld a, 11
            out (c), a
            ld sp, ({sps})
            jp ld_end
; ld_po - DE bytes from HL to the sprite patterns
ld_po:
            ld c, #5B
ld_pol:
            ld a, d
            or e
            ret z
            ld a, (hl)
            out (c), a
            inc hl
            dec de
            jr ld_pol
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
            db #00, #FF, #00, #2B, #00, #2B, #CC, #E4, #3C, #FC, #5F, #F0, #83, #FF, #25, #E3
spal:
            db #00, #FF, #B6, #6D, #E0, #F0, #FC, #3C, #10, #1F, #2B, #A3, #EA, #F6, #88, #E3
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #E3
            db #00, #FF, #EB, #EB, #EB, #EB, #EB, #EB, #EB, #EB, #EB, #EB, #EB, #EB, #EB, #E3
            db #00, #FF, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #53, #E3
            db #00, #06, #06, #06, #2B, #2B, #2B, #2B, #2B, #2B, #2B, #2B, #2B, #2B, #2B, #E3
            db #00, #FF, #B6, #6D, #E0, #F0, #FC, #A3, #EA, #1F, #2B, #3C, #10, #F6, #88, #E3
            db #00, #FF, #B6, #6D, #E0, #F0, #FC, #3C, #10, #1F, #2B, #E0, #F0, #F6, #88, #E3
            db #00, #FF, #B6, #6D, #2B, #F0, #1F, #3C, #10, #FC, #E0, #A3, #EA, #F6, #88, #E3
            db #00, #FF, #B7, #6E, #25, #5F, #2F, #06, #FC, #F0, #E4, #80, #EF, #62, #58, #E3
            db #00, #FF, #C4, #80, #40, #B6, #6E, #25, #FC, #EC, #5F, #0E, #F9, #AC, #44, #E3
            db #00, #FF, #D5, #8C, #44, #92, #49, #24, #E8, #80, #FD, #B0, #79, #30, #08, #E3
            db #00, #FF, #B7, #6E, #25, #53, #2B, #06, #5F, #13, #EB, #82, #FD, #D0, #68, #E3
            db #00, #FF, #67, #42, #21, #DB, #92, #49, #EF, #A2, #7F, #33, #FC, #B0, #48, #E3
            db #00, #FF, #FF, #B6, #6E, #F8, #B0, #68, #EC, #E0, #5F, #0F, #4B, #26, #01, #E3
ld_end:
            MMU 6 7, 10             ; bank 5 (in the NEX file): the first patterns
            ORG #C000
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #11, #1F, #FF, #FF, #FF, #99, #FF, #FF, #11, #11, #FF, #FF, #99, #99
            db #FF, #33, #11, #11, #11, #11, #11, #11, #FF, #33, #11, #11, #11, #11, #11, #11
            db #FF, #33, #11, #11, #11, #11, #11, #11, #FF, #33, #44, #44, #44, #44, #44, #44
            db #FF, #FF, #CC, #CC, #CC, #CC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #99, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #99, #91, #1F, #FF, #FF, #FF, #FF, #FF
            db #11, #11, #11, #11, #1F, #FF, #FF, #FF, #11, #11, #11, #11, #11, #11, #11, #FF
            db #11, #11, #11, #11, #11, #11, #FF, #FF, #44, #44, #44, #44, #44, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #11, #1F, #FF, #FF, #FF, #99, #FF, #FF, #11, #11, #FF, #FF, #99, #99
            db #CC, #C3, #11, #11, #11, #11, #11, #11, #C6, #C3, #11, #11, #11, #11, #11, #11
            db #FF, #33, #11, #11, #11, #11, #11, #11, #FF, #33, #44, #44, #44, #44, #44, #44
            db #FF, #FF, #CC, #CC, #CC, #CC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #99, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #99, #91, #1F, #FF, #FF, #FF, #FF, #FF
            db #11, #11, #11, #11, #1F, #FF, #FF, #FF, #11, #11, #11, #11, #11, #11, #11, #FF
            db #11, #11, #11, #11, #11, #11, #FF, #FF, #44, #44, #44, #44, #44, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #11, #1F, #FF, #FF, #FF, #99, #FF, #FF, #11, #11, #FF, #FF, #99, #99
            db #6C, #C6, #11, #11, #11, #11, #11, #11, #CC, #CC, #11, #11, #11, #11, #11, #11
            db #FF, #33, #11, #11, #11, #11, #11, #11, #FF, #33, #44, #44, #44, #44, #44, #44
            db #FF, #FF, #CC, #CC, #CC, #CC, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #99, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #99, #91, #1F, #FF, #FF, #FF, #FF, #FF
            db #11, #11, #11, #11, #1F, #FF, #FF, #FF, #11, #11, #11, #11, #11, #11, #11, #FF
            db #11, #11, #11, #11, #11, #11, #FF, #FF, #44, #44, #44, #44, #44, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #99, #AA, #BB, #CC, #55, #66, #11, #11
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FD, #DF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FD, #DF, #FF, #FF, #FF, #FF, #FF, #FF, #CC, #CC, #FF, #FF, #FF
            db #FF, #FF, #FC, #FC, #CF, #CF, #FF, #FF, #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F8, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #8F, #F8, #FF, #FF, #FF
            db #FF, #FF, #FF, #8F, #F8, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FD, #DF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FD, #DF, #FF, #FF, #FF, #FF, #FF, #FF, #CC, #CC, #FF, #FF, #FF
            db #FF, #FF, #FC, #FC, #CF, #CF, #FF, #FF, #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F8, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #F8, #8F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F8, #F8, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FD, #DF, #CF, #FF, #FF
            db #FF, #FF, #FC, #FD, #DF, #CF, #FF, #FF, #FF, #FF, #FF, #CC, #CC, #FF, #FF, #FF
            db #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #CF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F8, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #8F, #F8, #FF, #FF, #FF
            db #FF, #FF, #F8, #FF, #FF, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #16, #66, #16, #66, #16, #66, #16, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #FF, #FF, #FF, #FF, #FF, #FF, #66, #66, #F4, #44, #44, #44, #44, #4F, #66
            db #66, #F4, #FF, #FF, #FF, #FF, #4F, #66, #66, #F4, #FF, #FF, #FF, #FF, #4F, #66
            db #66, #F4, #FF, #FF, #FF, #FF, #4F, #66, #66, #F4, #FF, #FF, #FF, #FF, #4F, #66
            db #66, #F4, #FF, #FF, #FF, #FF, #4F, #66, #66, #F4, #FF, #FF, #FF, #FF, #4F, #66
            db #66, #F4, #FF, #FF, #FF, #FF, #4F, #66, #66, #F4, #FF, #FF, #FF, #FF, #4F, #66
            db #66, #F4, #44, #44, #44, #44, #4F, #66, #66, #FF, #FF, #FF, #FF, #FF, #FF, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #61, #66, #61, #66, #61, #66, #61
            db #99, #19, #99, #19, #99, #19, #99, #19, #99, #99, #99, #99, #99, #99, #99, #99
            db #99, #FF, #FF, #FF, #FF, #FF, #FF, #99, #99, #FA, #AA, #AA, #AA, #AA, #AF, #99
            db #99, #FA, #FF, #FF, #FF, #FF, #AF, #99, #99, #FA, #FF, #FF, #FF, #FF, #AF, #99
            db #99, #FA, #FF, #FF, #FF, #FF, #AF, #99, #99, #FA, #FF, #FF, #FF, #FF, #AF, #99
            db #99, #FA, #FF, #FF, #FF, #FF, #AF, #99, #99, #FA, #FF, #FF, #FF, #FF, #AF, #99
            db #99, #FA, #FF, #FF, #FF, #FF, #AF, #99, #99, #FA, #FF, #FF, #FF, #FF, #AF, #99
            db #99, #FA, #AA, #AA, #AA, #AA, #AF, #99, #99, #FF, #FF, #FF, #FF, #FF, #FF, #99
            db #99, #99, #99, #99, #99, #99, #99, #99, #91, #99, #91, #99, #91, #99, #91, #99
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF
            db #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF
            db #F6, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #11, #FF, #FF, #FF, #FF, #FF, #FF, #11, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1
            db #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1
            db #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1
            db #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1
            db #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1
            db #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1
            db #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1
            db #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #FF, #FF, #FF, #FF, #FF, #FF, #11
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #16, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #77, #77, #FF, #FF, #FF, #FF, #FF, #77, #77, #77, #77, #FF, #FF
            db #FF, #F7, #76, #67, #66, #67, #7F, #FF, #FF, #77, #77, #77, #77, #77, #77, #FF
            db #FF, #F8, #F8, #F8, #8F, #8F, #8F, #FF, #FF, #F8, #FF, #8F, #F8, #FF, #8F, #FF
            db #FF, #8F, #FF, #8F, #F8, #FF, #F8, #FF, #FF, #8F, #FF, #8F, #F8, #FF, #F8, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #77, #77, #FF, #FF, #FF, #FF, #FF, #77, #77, #77, #77, #FF, #FF
            db #FF, #F7, #67, #66, #76, #76, #7F, #FF, #FF, #77, #77, #77, #77, #77, #77, #FF
            db #FF, #F8, #F8, #F8, #8F, #8F, #8F, #FF, #FF, #F8, #FF, #8F, #F8, #FF, #8F, #FF
            db #FF, #F8, #FF, #8F, #F8, #FF, #8F, #FF, #FF, #8F, #FF, #F8, #8F, #FF, #F8, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #B7, #7B, #FF, #FF, #FF, #FF, #FF, #F7, #BB, #7B, #B7, #FF, #FF
            db #FF, #FF, #B7, #B7, #7B, #7B, #FF, #FF, #FF, #FF, #7B, #BB, #BB, #B7, #FF, #FF
            db #FF, #FF, #B7, #7B, #B7, #7B, #FF, #FF, #FF, #FF, #FB, #7F, #F7, #BF, #FF, #FF
            db #FF, #FF, #B7, #FF, #FF, #7B, #FF, #FF, #FF, #FF, #7F, #FF, #FF, #F7, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #7B, #B7, #FF, #FF, #FF, #FF, #FF, #FB, #77, #B7, #7B, #FF, #FF
            db #FF, #FF, #7B, #7B, #B7, #B7, #FF, #FF, #FF, #FF, #B7, #77, #77, #7B, #FF, #FF
            db #FF, #FF, #7B, #B7, #7B, #B7, #FF, #FF, #FF, #FF, #F7, #BF, #FB, #7F, #FF, #FF
            db #FF, #FF, #F7, #BF, #FB, #7F, #FF, #FF, #FF, #FF, #7B, #FF, #FF, #B7, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #AB, #BB, #BB, #BA, #FF, #FF, #FF, #FF, #B1, #11, #11, #1B, #FF, #FF
            db #FF, #FF, #B1, #BA, #AB, #1B, #FF, #FF, #FF, #FF, #B1, #AA, #AA, #1B, #FF, #FF
            db #FF, #FF, #B1, #AA, #AA, #1B, #FF, #FF, #FF, #FF, #B1, #BA, #AB, #1B, #FF, #FF
            db #FF, #FF, #B1, #11, #11, #1B, #FF, #FF, #FF, #FF, #AB, #BB, #BB, #BA, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #AB, #BB, #BB, #BA, #FF, #FF, #FF, #FF, #B1, #11, #11, #1B, #FF, #FF
            db #FF, #FF, #B1, #AB, #BA, #1B, #FF, #FF, #FF, #FF, #B1, #BB, #BB, #1B, #FF, #FF
            db #FF, #FF, #B1, #BB, #BB, #1B, #FF, #FF, #FF, #FF, #B1, #AB, #BA, #1B, #FF, #FF
            db #FF, #FF, #B1, #11, #11, #1B, #FF, #FF, #FF, #FF, #AB, #BB, #BB, #BA, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FB, #FF, #FB, #FF, #FB, #FF, #FF
            db #FF, #FF, #BF, #FB, #FF, #BF, #FF, #FF, #FF, #FF, #FB, #B4, #BB, #FF, #FF, #FF
            db #FF, #FF, #FB, #46, #4B, #FF, #FF, #FF, #FF, #FB, #B4, #66, #64, #BB, #FF, #FF
            db #FF, #FF, #FB, #46, #4B, #FF, #FF, #FF, #FF, #FF, #FB, #B4, #BB, #FF, #FF, #FF
            db #FF, #FF, #BF, #FB, #FF, #BF, #FF, #FF, #FF, #FB, #FF, #FB, #FF, #FB, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FB, #FF, #FF, #FF, #FF
            db #FF, #FF, #BF, #FB, #FF, #BF, #FF, #FF, #FF, #FF, #FB, #B4, #BB, #FF, #FF, #FF
            db #FF, #FF, #FB, #46, #4B, #FF, #FF, #FF, #FF, #FB, #BB, #66, #6B, #BB, #FF, #FF
            db #FF, #FF, #FB, #46, #4B, #FF, #FF, #FF, #FF, #FF, #FB, #B4, #BB, #FF, #FF, #FF
            db #FF, #FF, #BF, #FB, #FF, #BF, #FF, #FF, #FF, #FF, #FF, #FB, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F4, #4F, #FF, #FF, #FF, #FF, #FF, #FF, #46, #64, #FF, #FF, #FF
            db #FF, #FF, #FF, #46, #64, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #4F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #4F, #F4, #FF, #FF, #FF, #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #F4, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #77, #77, #77, #7F, #FF, #FF, #F7, #77, #77, #77, #77, #77, #77, #7F
            db #77, #87, #78, #77, #87, #78, #77, #87, #F7, #77, #77, #77, #77, #77, #77, #7F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #77, #77, #77, #7F, #FF, #FF, #F7, #77, #77, #77, #77, #77, #77, #7F
            db #78, #77, #87, #78, #77, #87, #78, #77, #F7, #77, #77, #77, #77, #77, #77, #7F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #56, #5F, #FF, #FF, #FF
            db #FF, #FF, #F5, #61, #65, #FF, #FF, #FF, #FF, #F5, #56, #11, #16, #55, #FF, #FF
            db #FF, #FF, #F5, #61, #65, #FF, #FF, #FF, #FF, #FF, #FF, #56, #5F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #F5, #FF, #FF
            db #FF, #FF, #5F, #FF, #FF, #5F, #FF, #FF, #FF, #FF, #F5, #FF, #F5, #FF, #FF, #FF
            db #FF, #FF, #FF, #61, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #11, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #61, #6F, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #F5, #FF, #FF, #FF
            db #FF, #FF, #5F, #FF, #FF, #5F, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #F5, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #56, #5F, #FF, #FF, #FF
            db #FF, #FF, #F5, #61, #65, #FF, #FF, #FF, #FF, #FF, #F6, #11, #16, #FF, #FF, #FF
            db #FF, #FF, #F5, #61, #65, #FF, #FF, #FF, #FF, #FF, #FF, #56, #5F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #F6, #F5, #FF, #FF, #FF
            db #FF, #FF, #FF, #61, #6F, #FF, #FF, #FF, #FF, #FF, #F6, #11, #16, #FF, #FF, #FF
            db #FF, #FF, #FF, #61, #6F, #FF, #FF, #FF, #FF, #FF, #F5, #F6, #F5, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #A9, #AF, #FF, #FF, #FF, #FF, #FF, #FA, #F1, #FA, #FF, #FF, #FF
            db #FF, #FF, #AF, #91, #9F, #AF, #FF, #FF, #FF, #FA, #9F, #11, #1F, #9A, #FF, #FF
            db #FF, #FF, #AF, #91, #9F, #AF, #FF, #FF, #FF, #FF, #FA, #F1, #FA, #FF, #FF, #FF
            db #FF, #FF, #FF, #A9, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F9, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #9A, #9F, #FF, #FF, #FF, #FF, #FF, #F9, #F1, #F9, #FF, #FF, #FF
            db #FF, #FF, #9F, #A1, #AF, #9F, #FF, #FF, #FF, #F9, #AF, #11, #1F, #A9, #FF, #FF
            db #FF, #FF, #9F, #A1, #AF, #9F, #FF, #FF, #FF, #FF, #F9, #F1, #F9, #FF, #FF, #FF
            db #FF, #FF, #FF, #9A, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #F9, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #91, #9F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #9F, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #9F, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #AF, #FF, #FF, #55, #5F, #FF, #FF, #FF, #AA, #FF, #55, #66, #65, #FF, #FF
            db #FF, #FA, #A5, #56, #61, #65, #5F, #FF, #FF, #FF, #A5, #55, #55, #55, #5F, #FF
            db #FF, #FA, #A5, #56, #66, #65, #5F, #FF, #FF, #AA, #FF, #55, #55, #5F, #FF, #FF
            db #FF, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AF, #FF, #F5, #55, #FF, #FF, #FF
            db #FF, #FA, #F5, #56, #66, #55, #FF, #FF, #FF, #FA, #A5, #56, #61, #65, #5F, #FF
            db #FF, #FA, #A5, #55, #55, #55, #5F, #FF, #FF, #FA, #F5, #56, #66, #65, #FF, #FF
            db #FF, #AF, #FF, #F5, #55, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #BB, #BB, #BB, #BB, #FF, #FF
            db #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF, #FF, #FB, #B1, #1B, #BB, #BB, #BF, #FF
            db #FF, #FB, #B1, #0B, #BB, #BB, #BF, #FF, #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF
            db #FF, #FB, #BB, #B1, #F1, #F1, #FF, #FF, #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF
            db #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF, #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF
            db #FF, #FF, #BB, #BB, #BB, #BB, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #BB, #BB, #BB, #BB, #FF, #FF
            db #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF, #FF, #FB, #B1, #1B, #BB, #BB, #BF, #FF
            db #FF, #FB, #B1, #0B, #BB, #BB, #BF, #FF, #FF, #FB, #BB, #B1, #F1, #F1, #FF, #FF
            db #FF, #FB, #BB, #BF, #FF, #FF, #FF, #FF, #FF, #FB, #BB, #B1, #F1, #F1, #FF, #FF
            db #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF, #FF, #FB, #BB, #BB, #BB, #BB, #BF, #FF
            db #FF, #FF, #BB, #BB, #BB, #BB, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #77, #7F, #FF, #FF, #FF
            db #FF, #FF, #F7, #71, #77, #FF, #FF, #FF, #FF, #FF, #F7, #77, #FF, #FF, #FF, #FF
            db #FF, #FF, #F7, #77, #77, #FF, #FF, #FF, #FF, #FF, #FF, #77, #7F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #77, #7F, #FF, #FF, #FF
            db #FF, #FF, #F7, #71, #77, #FF, #FF, #FF, #FF, #FF, #F7, #7F, #FF, #FF, #FF, #FF
            db #FF, #FF, #F7, #77, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #77, #7F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #22, #22, #FF, #FF, #FF, #FF, #FF, #FF, #21, #12, #FF, #FF, #FF
            db #FF, #FF, #FF, #21, #12, #FF, #FF, #FF, #FF, #FF, #FF, #22, #22, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF
            db #FF, #FF, #FF, #15, #61, #FF, #FF, #FF, #FF, #FF, #F6, #16, #C6, #6F, #FF, #FF
            db #FF, #FF, #F6, #49, #16, #6F, #FF, #FF, #FF, #FF, #FF, #16, #61, #FF, #FF, #FF
            db #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #55, #FF, #FF, #FF, #FF
            db #FF, #FF, #51, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FC, #FF, #FF, #FF
            db #FF, #FF, #1C, #CF, #F4, #5F, #FF, #FF, #FF, #FF, #F1, #44, #F1, #FF, #FF, #FF
            db #FF, #FF, #FF, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #1F, #FF, #5F, #FF, #FF, #FF, #FF, #51, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #9F, #FF, #FF, #FF, #CF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #51, #FF, #FF, #FF, #4F, #FF, #FF, #FF, #FC, #FC, #FF, #FF, #F6, #5F, #FF
            db #FF, #FF, #14, #9F, #41, #56, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F9, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F3, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #3F, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #F3, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #F3, #3F
            db #FF, #FF, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #33, #FF, #FF, #F3, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #00, #FF, #FF, #FF
            db #FF, #FF, #06, #66, #66, #0F, #FF, #FF, #FF, #F0, #61, #65, #66, #60, #FF, #FF
            db #FF, #06, #15, #55, #55, #66, #0F, #FF, #F0, #66, #57, #77, #75, #56, #60, #FF
            db #F0, #66, #57, #55, #57, #56, #60, #FF, #F0, #65, #57, #77, #75, #55, #60, #FF
            db #F0, #66, #57, #55, #55, #56, #60, #FF, #F0, #66, #57, #55, #55, #56, #60, #FF
            db #FF, #06, #65, #55, #55, #66, #0F, #FF, #FF, #F0, #66, #65, #66, #60, #FF, #FF
            db #FF, #FF, #06, #66, #66, #0F, #FF, #FF, #FF, #FF, #F0, #00, #00, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF
            db #FF, #FF, #F0, #66, #60, #FF, #FF, #FF, #FF, #FF, #01, #65, #66, #0F, #FF, #FF
            db #FF, #F0, #16, #55, #56, #0F, #FF, #FF, #FF, #F0, #65, #55, #55, #60, #FF, #FF
            db #FF, #F0, #65, #55, #55, #60, #FF, #FF, #FF, #F0, #65, #55, #55, #60, #FF, #FF
            db #FF, #F0, #65, #55, #55, #60, #FF, #FF, #FF, #F0, #65, #55, #55, #60, #FF, #FF
            db #FF, #FF, #06, #55, #56, #0F, #FF, #FF, #FF, #FF, #06, #65, #66, #0F, #FF, #FF
            db #FF, #FF, #F0, #66, #60, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #06, #0F, #FF, #FF, #FF, #FF, #FF, #01, #05, #0F, #FF, #FF, #FF
            db #FF, #F0, #10, #65, #60, #FF, #FF, #FF, #FF, #FF, #00, #65, #60, #FF, #FF, #FF
            db #FF, #FF, #F0, #65, #60, #FF, #FF, #FF, #FF, #FF, #F0, #65, #60, #FF, #FF, #FF
            db #FF, #FF, #F0, #65, #60, #FF, #FF, #FF, #FF, #FF, #F0, #65, #60, #FF, #FF, #FF
            db #FF, #FF, #F0, #65, #60, #FF, #FF, #FF, #FF, #FF, #FF, #05, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #06, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF
            db #FF, #FF, #F0, #66, #60, #FF, #FF, #FF, #FF, #FF, #01, #65, #66, #0F, #FF, #FF
            db #FF, #F0, #16, #55, #56, #0F, #FF, #FF, #FF, #F0, #65, #55, #55, #60, #FF, #FF
            db #FF, #F0, #65, #55, #55, #60, #FF, #FF, #FF, #F0, #65, #55, #55, #60, #FF, #FF
            db #FF, #F0, #65, #55, #55, #60, #FF, #FF, #FF, #F0, #65, #55, #55, #60, #FF, #FF
            db #FF, #FF, #06, #55, #56, #0F, #FF, #FF, #FF, #FF, #06, #65, #66, #0F, #FF, #FF
            db #FF, #FF, #F0, #66, #60, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #00, #00, #FF, #FF, #FF, #FF, #F0, #09, #99, #99, #00, #FF, #FF
            db #FF, #09, #99, #88, #89, #99, #0F, #FF, #F0, #99, #81, #88, #88, #89, #90, #FF
            db #F0, #98, #18, #88, #88, #88, #90, #FF, #09, #98, #8B, #BB, #B8, #88, #99, #0F
            db #09, #88, #8B, #88, #8B, #88, #89, #0F, #09, #88, #8B, #BB, #B8, #88, #89, #0F
            db #09, #88, #8B, #88, #88, #88, #89, #0F, #09, #98, #8B, #88, #88, #88, #99, #0F
            db #F0, #98, #88, #88, #88, #88, #90, #FF, #F0, #99, #88, #88, #88, #89, #90, #FF
            db #FF, #09, #99, #88, #89, #99, #0F, #FF, #FF, #F0, #09, #99, #99, #00, #FF, #FF
            db #FF, #FF, #F0, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #F0, #00, #00, #FF, #FF, #FF, #FF, #00, #09, #99, #99, #00, #0F, #FF
            db #F0, #19, #99, #88, #89, #99, #10, #FF, #F0, #99, #81, #88, #88, #89, #90, #FF
            db #F0, #98, #18, #88, #88, #88, #90, #FF, #09, #98, #8B, #BB, #B8, #88, #99, #0F
            db #09, #88, #8B, #88, #8B, #88, #89, #0F, #09, #88, #8B, #BB, #B8, #88, #89, #0F
            db #09, #88, #8B, #88, #88, #88, #89, #0F, #09, #98, #8B, #88, #88, #88, #99, #0F
            db #F0, #98, #88, #88, #88, #88, #90, #FF, #F0, #99, #88, #88, #88, #89, #90, #FF
            db #F0, #19, #99, #88, #89, #99, #10, #FF, #FF, #00, #09, #99, #99, #00, #0F, #FF
            db #FF, #FF, #F0, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #01, #0F, #FF, #FF, #FF, #FF, #FF, #F0, #E1, #10, #FF, #FF, #FF
            db #FF, #FF, #0E, #E1, #11, #0F, #FF, #FF, #FF, #F0, #EE, #E1, #11, #10, #FF, #FF
            db #FF, #0E, #EE, #E1, #11, #11, #0F, #FF, #FF, #04, #44, #4E, #EE, #EE, #0F, #FF
            db #FF, #F0, #44, #4E, #EE, #E0, #FF, #FF, #FF, #FF, #04, #4E, #EE, #0F, #FF, #FF
            db #FF, #FF, #04, #4E, #EE, #0F, #FF, #FF, #FF, #FF, #F0, #4E, #E0, #FF, #FF, #FF
            db #FF, #FF, #FF, #0E, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #0E, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #F0, #FF, #FF
            db #FF, #FF, #FF, #01, #0F, #01, #0F, #FF, #FF, #FF, #F0, #C1, #10, #10, #10, #FF
            db #FF, #FF, #0C, #C1, #11, #01, #0F, #FF, #FF, #F0, #CC, #C1, #11, #10, #FF, #FF
            db #FF, #0C, #CC, #C1, #11, #11, #0F, #FF, #FF, #0D, #DD, #DC, #CC, #CC, #0F, #FF
            db #FF, #F0, #DD, #DC, #CC, #C0, #FF, #FF, #FF, #FF, #0D, #DC, #CC, #0F, #FF, #FF
            db #FF, #FF, #0D, #DC, #CC, #0F, #FF, #FF, #FF, #FF, #F0, #DC, #C0, #FF, #FF, #FF
            db #FF, #FF, #FF, #0C, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #0C, #0F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F5, #5F, #FF, #FF, #FF, #FF, #FF, #51, #15, #55, #11, #FF, #FF
            db #FF, #F5, #56, #6F, #FF, #F1, #5F, #FF, #FF, #11, #FF, #FF, #FF, #F6, #55, #FF
            db #F1, #1F, #FF, #FF, #FF, #FF, #F1, #1F, #F5, #6F, #FF, #FF, #FF, #FF, #FF, #1F
            db #F5, #6F, #FF, #FF, #FF, #FF, #FF, #5F, #11, #FF, #FF, #FF, #FF, #FF, #FF, #55
            db #55, #6F, #FF, #FF, #FF, #FF, #F6, #11, #F1, #FF, #FF, #FF, #FF, #FF, #F6, #1F
            db #F1, #FF, #FF, #FF, #FF, #FF, #FF, #5F, #F5, #5F, #FF, #FF, #FF, #FF, #F5, #5F
            db #FF, #55, #6F, #FF, #FF, #FF, #11, #FF, #FF, #F1, #1F, #FF, #F6, #65, #1F, #FF
            db #FF, #FF, #15, #51, #11, #55, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF
            db #FF, #FF, #5F, #F5, #FF, #5F, #FF, #FF, #FF, #FF, #F5, #F1, #F5, #FF, #FF, #FF
            db #FF, #FF, #FF, #11, #1F, #FF, #FF, #FF, #FF, #F5, #51, #1F, #11, #55, #FF, #FF
            db #FF, #FF, #FF, #11, #1F, #FF, #FF, #FF, #FF, #FF, #F5, #F1, #F5, #FF, #FF, #FF
            db #FF, #FF, #5F, #F5, #FF, #5F, #FF, #FF, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #F0, #00, #00, #0F, #0D, #FF, #FF, #F0, #01, #11, #11, #10, #0D
            db #FF, #FF, #01, #15, #55, #55, #51, #1D, #FF, #F0, #15, #55, #66, #66, #55, #51
            db #FF, #01, #55, #66, #55, #55, #16, #55, #F0, #15, #56, #55, #66, #66, #55, #15
            db #F0, #15, #65, #66, #66, #66, #66, #51, #01, #55, #65, #66, #66, #66, #66, #71
            db #01, #56, #56, #66, #66, #66, #66, #65, #01, #56, #56, #66, #66, #66, #66, #67
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #00, #00, #00
            db #FF, #FF, #FF, #01, #11, #11, #11, #11, #00, #00, #00, #12, #22, #22, #22, #22
            db #DD, #DD, #11, #22, #22, #22, #22, #22, #DD, #DD, #12, #22, #22, #22, #22, #22
            db #DD, #DD, #12, #22, #22, #22, #22, #22, #11, #11, #23, #33, #33, #33, #33, #33
            db #11, #22, #32, #22, #22, #22, #22, #22, #51, #12, #32, #33, #33, #33, #33, #44
            db #56, #12, #32, #33, #33, #33, #44, #AA, #55, #11, #32, #33, #33, #34, #AA, #AA
            db #15, #61, #32, #33, #33, #4A, #AA, #AA, #15, #61, #32, #33, #33, #4A, #AA, #BB
            db #01, #56, #56, #66, #66, #66, #66, #67, #01, #56, #56, #66, #66, #66, #66, #67
            db #01, #55, #15, #66, #66, #66, #66, #71, #F0, #15, #65, #66, #66, #66, #66, #71
            db #F0, #15, #51, #57, #66, #66, #77, #15, #FF, #01, #55, #11, #57, #77, #11, #55
            db #FF, #F0, #15, #66, #66, #66, #15, #56, #FF, #FF, #01, #66, #77, #77, #16, #61
            db #FF, #FF, #F0, #06, #77, #77, #10, #12, #FF, #FF, #FF, #06, #77, #77, #00, #12
            db #FF, #FF, #FF, #06, #77, #77, #00, #12, #FF, #FF, #FF, #06, #77, #77, #00, #12
            db #FF, #FF, #FF, #06, #77, #77, #00, #13, #FF, #FF, #FF, #06, #77, #77, #00, #12
            db #FF, #FF, #FF, #06, #77, #77, #00, #12, #FF, #FF, #FF, #06, #77, #77, #0F, #01
            db #15, #61, #32, #33, #34, #AA, #AB, #BB, #15, #61, #32, #33, #34, #AA, #AB, #B8
            db #55, #61, #32, #33, #34, #AA, #AB, #B8, #56, #12, #32, #33, #34, #AA, #AB, #BB
            db #56, #12, #32, #33, #33, #2A, #AA, #BB, #61, #22, #32, #33, #33, #4A, #AA, #AA
            db #12, #22, #32, #33, #33, #32, #AA, #AA, #22, #22, #32, #33, #33, #33, #22, #AA
            db #22, #22, #32, #33, #33, #33, #33, #22, #22, #22, #32, #33, #33, #33, #33, #33
            db #22, #22, #32, #33, #33, #33, #33, #33, #22, #22, #32, #33, #33, #33, #33, #33
            db #22, #22, #32, #33, #33, #33, #33, #33, #22, #22, #32, #33, #33, #33, #33, #33
            db #22, #22, #32, #44, #44, #44, #44, #44, #22, #23, #31, #11, #11, #11, #11, #11
            db #FF, #FF, #FF, #06, #77, #77, #0F, #01, #FF, #FF, #FF, #06, #77, #77, #0F, #F0
            db #FF, #FF, #FF, #06, #77, #77, #0F, #F0, #FF, #FF, #FF, #06, #77, #77, #0F, #FF
            db #FF, #FF, #FF, #06, #77, #77, #0F, #FF, #FF, #FF, #FF, #06, #77, #77, #0F, #FF
            db #FF, #FF, #FF, #06, #99, #96, #0F, #FF, #FF, #FF, #FF, #06, #99, #96, #0F, #FF
            db #FF, #FF, #FF, #06, #99, #96, #0F, #FF, #FF, #FF, #FF, #F0, #99, #90, #FF, #FF
            db #FF, #FF, #FF, #F0, #99, #90, #FF, #FF, #FF, #FF, #FF, #F0, #99, #90, #FF, #FF
            db #FF, #FF, #FF, #F0, #99, #90, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #3C, #CC, #CC, #CC, #CC, #CC, #12, #12, #21, #11, #11, #11, #11, #11, #22
            db #12, #23, #33, #33, #33, #33, #33, #22, #01, #3C, #CC, #CC, #CC, #CC, #CC, #12
            db #01, #21, #11, #11, #11, #11, #11, #22, #F0, #13, #33, #33, #33, #33, #33, #22
            db #F0, #1C, #CC, #CC, #CC, #CC, #CC, #12, #FF, #01, #11, #11, #11, #11, #11, #22
            db #FF, #01, #33, #33, #33, #33, #33, #22, #FF, #0C, #CC, #CC, #CC, #CC, #CC, #12
            db #FF, #F0, #00, #11, #11, #11, #11, #22, #FF, #FF, #FF, #00, #01, #33, #22, #22
            db #FF, #FF, #FF, #FF, #F0, #00, #13, #32, #FF, #FF, #FF, #FF, #FF, #FF, #00, #01
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF, #FF
            db #FF, #F0, #11, #10, #00, #00, #FF, #FF, #FF, #F0, #16, #61, #11, #11, #00, #00
            db #FF, #05, #55, #55, #15, #55, #11, #11, #FF, #05, #66, #67, #15, #55, #55, #55
            db #FF, #05, #66, #67, #15, #55, #55, #55, #F0, #15, #66, #67, #15, #55, #55, #55
            db #F0, #15, #66, #67, #15, #55, #55, #55, #FF, #05, #66, #67, #15, #55, #55, #55
            db #FF, #05, #66, #67, #15, #55, #55, #55, #FF, #05, #66, #67, #15, #55, #55, #55
            db #FF, #05, #77, #77, #15, #56, #66, #66, #FF, #F0, #00, #11, #66, #60, #00, #00
            ORG #F400
            db #FF, #FF, #FF, #FF, #FF, #F0, #11, #11, #FF, #FF, #FF, #FF, #FF, #01, #22, #22
            db #FF, #FF, #FF, #FF, #F0, #12, #22, #22, #FF, #FF, #FF, #FF, #01, #33, #33, #32
            db #FF, #FF, #FF, #F0, #22, #22, #22, #21, #0F, #FF, #FF, #01, #11, #11, #11, #12
            db #10, #00, #00, #12, #22, #22, #22, #22, #51, #11, #11, #13, #22, #22, #22, #22
            db #55, #55, #55, #11, #13, #33, #33, #32, #55, #55, #55, #56, #22, #22, #22, #21
            db #55, #55, #55, #56, #11, #11, #11, #88, #55, #55, #55, #56, #12, #22, #38, #88
            db #55, #55, #55, #56, #13, #33, #88, #89, #55, #55, #66, #66, #13, #33, #88, #99
            db #66, #66, #00, #01, #22, #22, #22, #29, #00, #00, #FF, #01, #11, #11, #88, #89
            db #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #0F, #FF, #FF, #FF, #FF
            db #FF, #F0, #11, #10, #00, #00, #FF, #FF, #FF, #F0, #16, #61, #11, #11, #00, #00
            db #FF, #05, #55, #55, #15, #55, #11, #11, #FF, #05, #66, #67, #15, #55, #55, #55
            db #FF, #05, #66, #67, #15, #55, #55, #55, #F0, #15, #66, #67, #15, #55, #55, #55
            db #F0, #15, #66, #67, #15, #55, #55, #55, #FF, #05, #66, #67, #15, #55, #55, #55
            db #FF, #05, #66, #67, #15, #55, #55, #55, #FF, #05, #66, #67, #15, #55, #55, #55
            db #FF, #05, #77, #77, #15, #56, #66, #66, #FF, #F0, #00, #11, #66, #60, #00, #00
            db #FF, #FF, #FF, #01, #22, #22, #18, #88, #FF, #FF, #FF, #01, #22, #22, #21, #88
            db #FF, #FF, #FF, #01, #33, #33, #33, #11, #FF, #FF, #FF, #F0, #22, #22, #22, #21
            db #FF, #FF, #FF, #F0, #11, #11, #11, #12, #0F, #FF, #FF, #F0, #12, #22, #22, #22
            db #10, #00, #00, #F0, #12, #22, #22, #22, #51, #11, #11, #00, #13, #33, #33, #32
            db #55, #55, #55, #11, #22, #22, #22, #21, #55, #55, #55, #56, #11, #11, #11, #AA
            db #55, #55, #55, #56, #12, #23, #AA, #AA, #55, #55, #55, #56, #01, #23, #AA, #AA
            db #55, #55, #55, #56, #01, #3A, #AA, #BB, #55, #55, #66, #66, #22, #22, #22, #2B
            db #66, #66, #00, #00, #01, #1A, #AA, #BB, #00, #00, #FF, #FF, #01, #3A, #AA, #BB
            db #FF, #FF, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #01, #21, #AA, #AA, #FF, #FF, #FF, #FF, #01, #33, #AA, #AA
            db #FF, #FF, #FF, #F0, #22, #22, #22, #2A, #FF, #FF, #FF, #FF, #01, #11, #11, #11
            db #FF, #FF, #FF, #FF, #F0, #13, #22, #22, #FF, #FF, #FF, #FF, #F0, #12, #22, #22
            db #FF, #FF, #FF, #FF, #00, #13, #33, #32, #FF, #FF, #FF, #F0, #22, #22, #22, #21
            db #FF, #FF, #FF, #F0, #11, #11, #11, #12, #FF, #FF, #FF, #01, #55, #51, #12, #22
            db #FF, #FF, #F0, #15, #55, #60, #12, #22, #FF, #FF, #01, #55, #56, #0F, #01, #22
            db #FF, #F0, #15, #55, #60, #FF, #F0, #12, #FF, #01, #55, #56, #0F, #FF, #FF, #01
            db #F0, #16, #66, #60, #FF, #FF, #FF, #F0, #FF, #00, #00, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #01, #0F, #FF, #FF, #FF, #FF, #FF, #FF, #01, #10, #0F, #FF, #FF, #FF, #FF, #FF
            db #01, #61, #10, #FF, #FF, #FF, #FF, #FF, #01, #66, #11, #00, #FF, #FF, #FF, #FF
            db #01, #67, #16, #66, #0F, #00, #FF, #FF, #01, #67, #16, #67, #10, #66, #0F, #00
            db #01, #67, #16, #67, #11, #67, #00, #66, #01, #67, #16, #67, #16, #67, #00, #67
            db #01, #67, #16, #67, #16, #67, #10, #67, #01, #67, #16, #67, #16, #67, #11, #67
            db #01, #67, #16, #67, #16, #67, #16, #67, #F0, #67, #16, #67, #16, #67, #16, #67
            db #F0, #67, #16, #67, #16, #67, #16, #67, #F0, #67, #16, #67, #16, #67, #16, #67
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #01, #FF, #FF, #FF, #FF, #FF, #FF, #01, #12
            db #FF, #FF, #FF, #FF, #FF, #F0, #12, #22, #FF, #FF, #FF, #FF, #FF, #01, #22, #22
            db #0F, #FF, #FF, #FF, #FF, #01, #23, #33, #0F, #FF, #FF, #FF, #FF, #01, #3A, #AA
            db #0F, #FF, #FF, #FF, #F0, #13, #AA, #AA, #0F, #FF, #FF, #FF, #F0, #1A, #AA, #AA
            db #00, #FF, #FF, #FF, #01, #AA, #AA, #BB, #11, #0F, #FF, #FF, #0A, #AA, #AB, #BB
            db #15, #10, #FF, #F0, #1A, #AA, #BB, #BB, #15, #51, #00, #F0, #88, #8A, #BB, #B1
            db #FF, #00, #16, #67, #16, #67, #16, #67, #FF, #F0, #16, #67, #16, #67, #16, #67
            db #FF, #FF, #01, #67, #16, #67, #16, #67, #FF, #FF, #01, #11, #56, #67, #16, #67
            db #FF, #FF, #F0, #15, #56, #67, #16, #67, #FF, #FF, #FF, #01, #56, #67, #16, #67
            db #FF, #FF, #FF, #01, #55, #11, #56, #67, #FF, #FF, #FF, #F0, #15, #55, #56, #67
            db #FF, #FF, #FF, #FF, #01, #65, #56, #67, #FF, #FF, #00, #00, #F0, #01, #65, #11
            db #FF, #F0, #55, #55, #00, #00, #01, #66, #FF, #F0, #56, #66, #55, #55, #55, #55
            db #FF, #FF, #05, #66, #66, #66, #66, #66, #FF, #FF, #05, #66, #66, #66, #66, #66
            db #FF, #FF, #05, #66, #66, #66, #66, #66, #FF, #FF, #05, #66, #66, #66, #66, #66
            db #15, #55, #11, #00, #88, #8A, #BB, #B1, #15, #55, #55, #11, #88, #8A, #BB, #BB
            db #15, #55, #55, #51, #18, #AA, #AB, #BB, #15, #56, #66, #56, #11, #AA, #AA, #BB
            db #15, #68, #88, #11, #33, #1A, #AA, #AA, #15, #68, #88, #81, #22, #21, #AA, #AA
            db #15, #68, #88, #11, #22, #22, #1A, #AA, #15, #51, #11, #12, #22, #22, #21, #11
            db #15, #55, #56, #12, #22, #22, #22, #22, #55, #66, #56, #01, #22, #22, #22, #22
            db #56, #88, #10, #01, #22, #22, #22, #22, #18, #88, #80, #01, #22, #22, #22, #22
            db #58, #88, #80, #01, #33, #33, #22, #22, #65, #88, #0F, #01, #22, #22, #22, #22
            db #66, #55, #0F, #01, #22, #22, #22, #22, #66, #67, #0F, #01, #22, #22, #22, #22
            db #FF, #FF, #05, #66, #66, #66, #66, #66, #FF, #FF, #F0, #56, #66, #66, #66, #66
            db #FF, #FF, #F0, #56, #66, #66, #66, #66, #FF, #FF, #F0, #57, #77, #77, #77, #77
            db #FF, #FF, #FF, #00, #00, #00, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #66, #67, #00, #01, #22, #22, #22, #22, #66, #78, #88, #01, #22, #22, #22, #22
            db #66, #78, #88, #81, #22, #22, #22, #22, #77, #78, #88, #00, #12, #22, #22, #22
            db #00, #00, #00, #F0, #13, #33, #22, #22, #FF, #FF, #FF, #F0, #18, #12, #22, #22
            db #FF, #FF, #FF, #F0, #88, #81, #22, #23, #FF, #FF, #FF, #F0, #88, #81, #22, #38
            db #FF, #FF, #FF, #F0, #88, #81, #23, #88, #FF, #FF, #FF, #FF, #00, #01, #33, #88
            db #FF, #FF, #FF, #FF, #FF, #F0, #01, #18, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #01
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #00, #00, #00, #00
            db #FF, #FF, #FF, #01, #11, #11, #11, #11, #F0, #00, #00, #13, #33, #22, #22, #22
            db #03, #33, #33, #33, #33, #13, #33, #33, #03, #44, #44, #44, #44, #12, #22, #22
            db #03, #22, #22, #22, #23, #12, #22, #22, #03, #33, #33, #33, #34, #12, #22, #23
            db #03, #44, #44, #44, #44, #12, #22, #39, #03, #44, #44, #44, #44, #12, #22, #39
            db #03, #22, #22, #22, #23, #12, #22, #39, #03, #33, #33, #33, #34, #12, #22, #39
            db #03, #44, #44, #44, #44, #13, #33, #31, #03, #44, #44, #44, #44, #12, #22, #22
            db #03, #22, #22, #22, #23, #12, #22, #22, #03, #33, #33, #33, #34, #12, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #00, #00, #00, #00, #00, #00, #00, #00
            db #11, #11, #11, #11, #11, #11, #11, #11, #22, #22, #22, #22, #22, #22, #22, #22
            db #22, #22, #33, #33, #33, #33, #22, #22, #22, #22, #22, #22, #22, #22, #22, #22
            db #33, #33, #22, #22, #22, #22, #22, #22, #99, #99, #12, #22, #22, #22, #22, #22
            db #99, #99, #91, #22, #22, #22, #22, #22, #99, #99, #91, #22, #22, #22, #23, #33
            db #99, #99, #91, #22, #22, #33, #31, #11, #99, #99, #91, #22, #23, #11, #15, #55
            db #99, #99, #13, #33, #31, #55, #56, #66, #11, #11, #22, #23, #15, #56, #65, #55
            db #22, #22, #22, #31, #55, #65, #56, #66, #22, #22, #23, #15, #56, #56, #66, #66
            db #03, #44, #44, #44, #44, #12, #22, #22, #03, #44, #44, #44, #44, #12, #22, #22
            db #03, #22, #22, #22, #23, #12, #22, #22, #03, #33, #33, #33, #34, #12, #22, #22
            db #03, #44, #44, #44, #44, #13, #33, #33, #03, #44, #44, #44, #44, #12, #22, #22
            db #03, #22, #22, #22, #23, #12, #22, #22, #03, #33, #33, #33, #34, #12, #22, #22
            db #03, #44, #44, #44, #44, #12, #22, #22, #03, #44, #44, #44, #44, #12, #22, #22
            db #03, #22, #22, #22, #23, #12, #22, #22, #03, #33, #33, #33, #34, #12, #22, #22
            db #03, #44, #44, #44, #44, #13, #33, #33, #03, #44, #44, #44, #44, #12, #22, #22
            db #03, #22, #22, #22, #23, #12, #22, #22, #03, #33, #33, #33, #34, #12, #22, #22
            db #22, #22, #31, #55, #65, #66, #66, #66, #22, #22, #31, #56, #56, #66, #66, #77
            db #22, #22, #31, #56, #56, #66, #67, #AA, #22, #23, #15, #65, #66, #66, #7A, #AA
            db #22, #23, #15, #65, #66, #67, #AA, #A8, #22, #23, #15, #65, #66, #67, #AA, #88
            db #22, #23, #15, #65, #66, #67, #AA, #88, #22, #23, #15, #65, #66, #67, #AA, #A8
            db #22, #23, #15, #65, #66, #66, #5A, #AA, #22, #22, #11, #51, #56, #66, #65, #AA
            db #22, #22, #31, #56, #56, #66, #66, #55, #22, #22, #31, #55, #15, #66, #66, #66
            db #22, #22, #31, #15, #51, #56, #66, #66, #22, #22, #22, #11, #55, #15, #76, #77
            db #22, #22, #22, #21, #15, #51, #15, #66, #22, #22, #22, #22, #11, #55, #51, #67
            db #03, #44, #44, #44, #44, #12, #22, #22, #03, #44, #44, #44, #44, #12, #23, #33
            db #03, #22, #22, #22, #23, #12, #3C, #CC, #03, #33, #33, #33, #34, #12, #3C, #DD
            db #03, #44, #44, #44, #44, #13, #3C, #DD, #03, #44, #44, #44, #44, #12, #3C, #CC
            db #03, #22, #22, #22, #23, #12, #3C, #CC, #03, #33, #33, #33, #34, #12, #3C, #CC
            db #03, #44, #44, #44, #44, #12, #3C, #CC, #03, #44, #44, #44, #44, #12, #21, #11
            db #03, #22, #22, #22, #23, #12, #22, #22, #03, #33, #33, #33, #34, #12, #22, #22
            db #03, #44, #44, #44, #44, #13, #33, #33, #F0, #00, #11, #11, #11, #33, #33, #33
            db #FF, #FF, #00, #00, #00, #00, #00, #00, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #22, #22, #22, #21, #16, #66, #67, #33, #33, #33, #33, #22, #11, #11, #67
            db #CC, #CC, #CC, #CC, #12, #22, #21, #67, #DD, #DD, #DD, #DC, #12, #22, #23, #67
            db #DD, #DD, #DD, #DC, #13, #33, #23, #67, #CC, #CC, #CC, #CC, #12, #22, #23, #67
            db #CC, #CC, #CC, #CC, #12, #22, #23, #67, #CC, #CC, #CC, #CC, #12, #22, #23, #67
            db #CC, #CC, #CC, #CC, #12, #22, #23, #67, #11, #11, #11, #11, #22, #22, #23, #67
            db #22, #22, #22, #22, #22, #22, #23, #67, #22, #22, #22, #22, #22, #22, #23, #67
            db #22, #22, #33, #33, #33, #33, #23, #67, #33, #33, #33, #33, #33, #33, #33, #67
            db #00, #00, #00, #00, #00, #00, #00, #67, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #67
            db #F0, #10, #0F, #FF, #FF, #FF, #FF, #FF, #F0, #11, #10, #0F, #FF, #FF, #FF, #FF
            db #F0, #15, #51, #10, #0F, #FF, #FF, #FF, #F0, #15, #55, #51, #10, #0F, #FF, #FF
            db #01, #55, #55, #55, #51, #10, #0F, #FF, #01, #55, #55, #55, #55, #51, #10, #0F
            db #01, #55, #55, #55, #55, #55, #51, #10, #01, #55, #55, #55, #55, #55, #55, #51
            db #F0, #15, #55, #55, #55, #55, #55, #55, #FF, #01, #55, #55, #55, #55, #55, #55
            db #FF, #F0, #15, #55, #55, #55, #55, #56, #FF, #FF, #01, #55, #55, #55, #55, #56
            db #FF, #FF, #F0, #15, #55, #55, #55, #62, #F0, #FF, #FF, #01, #55, #55, #55, #62
            db #05, #00, #0F, #F0, #15, #55, #55, #62, #05, #55, #50, #00, #01, #55, #55, #62
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #0C
            db #FF, #FF, #FF, #FF, #FF, #FF, #F0, #CC, #FF, #FF, #FF, #FF, #FF, #FF, #0C, #CC
            db #FF, #FF, #FF, #FF, #FF, #FF, #0C, #CC, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #CC
            db #0F, #FF, #FF, #FF, #FF, #FF, #FF, #0C, #10, #0F, #FF, #FF, #FF, #FF, #00, #11
            db #51, #10, #00, #FF, #FF, #F0, #11, #33, #66, #22, #22, #00, #FF, #01, #33, #AA
            db #22, #33, #33, #22, #00, #13, #AA, #AA, #23, #33, #33, #34, #10, #13, #AA, #AA
            db #33, #33, #33, #33, #21, #1A, #AA, #BB, #33, #33, #33, #33, #41, #1A, #AA, #BB
            db #33, #33, #33, #33, #41, #1A, #AA, #BB, #33, #33, #33, #33, #41, #3A, #AA, #BB
            db #F0, #56, #65, #55, #00, #15, #55, #51, #F0, #56, #66, #66, #55, #51, #66, #56
            db #F0, #56, #66, #66, #66, #65, #55, #12, #FF, #05, #66, #66, #66, #66, #66, #52
            db #FF, #05, #66, #66, #66, #66, #66, #72, #FF, #05, #66, #66, #66, #66, #66, #72
            db #FF, #F0, #56, #66, #66, #66, #66, #72, #FF, #F0, #57, #66, #66, #66, #66, #72
            db #FF, #FF, #00, #57, #76, #66, #66, #72, #FF, #FF, #FF, #00, #05, #77, #66, #72
            db #FF, #FF, #FF, #FF, #F0, #00, #57, #72, #FF, #FF, #FF, #FF, #FF, #FF, #00, #02
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #02, #FF, #FF, #FF, #00, #00, #00, #00, #02
            db #FF, #FF, #F0, #66, #66, #66, #66, #62, #FF, #FF, #FF, #06, #77, #77, #77, #72
            MMU 6 7, 94             ; bank 47: the rest of the patterns, then the tiles
            ORG #C000
pats:
            db #23, #33, #33, #34, #11, #21, #AA, #AA, #23, #33, #33, #44, #11, #23, #AA, #AA
            db #33, #44, #44, #11, #61, #22, #11, #AA, #34, #11, #11, #55, #61, #22, #22, #11
            db #34, #55, #16, #66, #01, #33, #22, #22, #34, #56, #55, #51, #01, #22, #22, #22
            db #34, #56, #66, #65, #12, #22, #22, #33, #34, #56, #66, #67, #12, #22, #23, #88
            db #34, #56, #66, #70, #12, #22, #38, #88, #34, #56, #66, #70, #12, #22, #38, #81
            db #34, #56, #66, #70, #12, #22, #38, #81, #34, #56, #66, #70, #12, #22, #38, #88
            db #34, #57, #77, #00, #13, #33, #21, #88, #34, #00, #05, #00, #12, #22, #22, #11
            db #34, #66, #66, #66, #01, #22, #22, #22, #34, #67, #77, #77, #01, #22, #22, #22
            db #FF, #FF, #FF, #06, #77, #77, #77, #72, #FF, #FF, #FF, #F0, #67, #77, #77, #72
            db #FF, #FF, #FF, #F0, #67, #77, #77, #72, #FF, #FF, #FF, #FF, #06, #77, #77, #72
            db #FF, #FF, #FF, #FF, #06, #77, #77, #72, #FF, #FF, #FF, #FF, #F0, #67, #77, #02
            db #FF, #FF, #FF, #FF, #FF, #00, #00, #02, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #02
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #02, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F0
            db #34, #67, #77, #77, #01, #22, #22, #22, #34, #67, #77, #77, #01, #22, #22, #22
            db #34, #67, #77, #77, #01, #22, #22, #22, #34, #67, #77, #77, #01, #22, #22, #22
            db #34, #67, #70, #00, #01, #33, #22, #22, #34, #00, #0F, #FF, #01, #22, #22, #22
            db #34, #0F, #FF, #FF, #01, #22, #22, #22, #44, #0F, #FF, #FF, #F0, #12, #22, #22
            db #82, #0F, #FF, #FF, #F0, #12, #22, #22, #80, #FF, #FF, #FF, #F0, #12, #22, #22
            db #80, #FF, #FF, #FF, #F0, #12, #22, #22, #80, #FF, #FF, #FF, #F0, #13, #22, #22
            db #80, #FF, #FF, #FF, #FF, #00, #13, #32, #80, #FF, #FF, #FF, #FF, #FF, #00, #01
            db #80, #FF, #FF, #FF, #FF, #FF, #FF, #F0, #80, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            ORG #E000
truns:
            db 1, 10        ; tiles 1-10
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #33, #33, #33, #33, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #66, #66, #66, #66, #33, #33, #33, #33
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #10, #00, #00
            db #01, #11, #11, #10, #0C, #77, #11, #10, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #99, #90, #00, #09, #11, #19, #00
            db #09, #11, #19, #00, #00, #99, #90, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #0A, #AA, #AA, #AA, #0A, #AA, #AA, #AA, #0A, #AA, #AA, #AA
            db #0A, #AA, #AA, #AA, #0A, #AA, #AA, #AA, #0A, #AA, #AA, #AA, #00, #00, #00, #00
            db #00, #00, #00, #00, #03, #33, #33, #33, #03, #33, #33, #33, #03, #33, #33, #33
            db #03, #33, #33, #33, #03, #33, #33, #33, #03, #33, #33, #33, #00, #00, #00, #00
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db 32, 124        ; tiles 32-155
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #01, #10, #00, #00, #11, #11, #00, #00, #11, #11, #E0, #00, #01, #1E, #E0
            db #00, #01, #1E, #00, #00, #00, #EE, #00, #00, #01, #10, #00, #00, #00, #EE, #00
            db #01, #10, #11, #00, #01, #1E, #11, #E0, #00, #EE, #0E, #E0, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #01, #10, #11, #00, #01, #1E, #11, #E0, #11, #11, #11, #10, #01, #1E, #11, #EE
            db #11, #11, #11, #10, #01, #1E, #11, #EE, #01, #1E, #11, #E0, #00, #EE, #0E, #E0
            db #00, #11, #00, #00, #01, #11, #11, #00, #11, #EE, #EE, #E0, #01, #11, #10, #00
            db #00, #EE, #11, #00, #11, #11, #1E, #E0, #0E, #11, #EE, #00, #00, #0E, #E0, #00
            db #00, #00, #00, #00, #11, #00, #01, #10, #11, #E0, #11, #EE, #0E, #E1, #1E, #E0
            db #00, #11, #EE, #00, #01, #1E, #E1, #10, #11, #EE, #01, #1E, #0E, #E0, #00, #EE
            db #00, #11, #10, #00, #01, #1E, #11, #00, #00, #11, #1E, #E0, #01, #11, #E1, #10
            db #11, #E1, #11, #EE, #11, #E0, #11, #E0, #01, #11, #01, #10, #00, #EE, #E0, #EE
            db #01, #10, #00, #00, #01, #1E, #00, #00, #11, #EE, #00, #00, #0E, #E0, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #01, #10, #00, #00, #11, #EE, #00, #01, #1E, #E0, #00, #01, #1E, #00, #00
            db #01, #1E, #00, #00, #00, #11, #00, #00, #00, #01, #10, #00, #00, #00, #EE, #00
            db #01, #10, #00, #00, #00, #11, #00, #00, #00, #01, #10, #00, #00, #01, #1E, #00
            db #00, #01, #1E, #00, #00, #11, #EE, #00, #01, #1E, #E0, #00, #00, #EE, #00, #00
            db #00, #00, #00, #00, #01, #10, #01, #10, #00, #11, #11, #EE, #11, #11, #11, #11
            db #0E, #11, #11, #EE, #01, #1E, #E1, #10, #00, #EE, #00, #EE, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #E0, #00, #11, #11, #11, #00
            db #0E, #11, #EE, #E0, #00, #11, #E0, #00, #00, #0E, #E0, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #E0, #00, #01, #1E, #E0, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #11, #11, #11, #00
            db #0E, #EE, #EE, #E0, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #E0, #00, #00, #0E, #E0, #00
            db #00, #00, #01, #10, #00, #00, #11, #EE, #00, #01, #1E, #E0, #00, #11, #EE, #00
            db #01, #1E, #E0, #00, #11, #EE, #00, #00, #1E, #E0, #00, #00, #0E, #00, #00, #00
            db #01, #11, #11, #00, #11, #EE, #E1, #10, #11, #E0, #11, #1E, #11, #E1, #11, #1E
            db #11, #11, #E1, #1E, #11, #1E, #E1, #1E, #01, #11, #11, #EE, #00, #EE, #EE, #E0
            db #00, #11, #00, #00, #01, #11, #E0, #00, #00, #11, #E0, #00, #00, #11, #E0, #00
            db #00, #11, #E0, #00, #00, #11, #E0, #00, #11, #11, #11, #00, #0E, #EE, #EE, #E0
            db #01, #11, #10, #00, #11, #EE, #11, #00, #0E, #E0, #11, #E0, #00, #11, #1E, #E0
            db #01, #1E, #EE, #00, #11, #EE, #11, #00, #11, #11, #11, #E0, #0E, #EE, #EE, #E0
            db #01, #11, #10, #00, #11, #EE, #11, #00, #0E, #E0, #11, #E0, #00, #11, #1E, #E0
            db #00, #0E, #11, #00, #11, #00, #11, #E0, #01, #11, #1E, #E0, #00, #EE, #EE, #00
            db #00, #01, #11, #00, #00, #11, #11, #E0, #01, #1E, #11, #E0, #11, #EE, #11, #E0
            db #11, #11, #11, #10, #0E, #EE, #11, #EE, #00, #01, #11, #10, #00, #00, #EE, #EE
            db #11, #11, #11, #00, #11, #EE, #EE, #E0, #11, #11, #10, #00, #0E, #EE, #11, #00
            db #00, #00, #11, #E0, #11, #00, #11, #E0, #01, #11, #1E, #E0, #00, #EE, #EE, #00
            db #00, #11, #10, #00, #01, #1E, #EE, #00, #11, #EE, #00, #00, #11, #11, #10, #00
            db #11, #EE, #11, #00, #11, #E0, #11, #E0, #01, #11, #1E, #E0, #00, #EE, #EE, #00
            db #11, #11, #11, #00, #11, #EE, #11, #E0, #0E, #E0, #11, #E0, #00, #01, #1E, #E0
            db #00, #11, #EE, #00, #00, #11, #E0, #00, #00, #11, #E0, #00, #00, #0E, #E0, #00
            db #01, #11, #10, #00, #11, #EE, #11, #00, #11, #E0, #11, #E0, #01, #11, #1E, #E0
            db #11, #EE, #11, #00, #11, #E0, #11, #E0, #01, #11, #1E, #E0, #00, #EE, #EE, #00
            db #01, #11, #10, #00, #11, #EE, #11, #00, #11, #E0, #11, #E0, #01, #11, #11, #E0
            db #00, #EE, #11, #E0, #00, #01, #1E, #E0, #01, #11, #EE, #00, #00, #EE, #E0, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #E0, #00, #00, #0E, #E0, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #E0, #00, #00, #0E, #E0, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #E0, #00, #00, #0E, #E0, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #E0, #00, #01, #1E, #E0, #00
            db #00, #01, #10, #00, #00, #11, #EE, #00, #01, #1E, #E0, #00, #11, #EE, #00, #00
            db #01, #10, #00, #00, #00, #11, #00, #00, #00, #01, #10, #00, #00, #00, #EE, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #11, #11, #11, #00, #0E, #EE, #EE, #E0
            db #00, #00, #00, #00, #11, #11, #11, #00, #0E, #EE, #EE, #E0, #00, #00, #00, #00
            db #01, #10, #00, #00, #00, #11, #00, #00, #00, #01, #10, #00, #00, #00, #11, #00
            db #00, #01, #1E, #E0, #00, #11, #EE, #00, #01, #1E, #E0, #00, #00, #EE, #00, #00
            db #01, #11, #10, #00, #11, #EE, #11, #00, #0E, #E0, #11, #E0, #00, #01, #1E, #E0
            db #00, #11, #EE, #00, #00, #0E, #E0, #00, #00, #11, #00, #00, #00, #0E, #E0, #00
            db #01, #11, #11, #00, #11, #EE, #E1, #10, #11, #E1, #11, #1E, #11, #E1, #11, #1E
            db #11, #E1, #11, #1E, #11, #E0, #EE, #EE, #01, #11, #10, #00, #00, #EE, #EE, #00
            db #00, #11, #00, #00, #01, #11, #10, #00, #11, #EE, #11, #00, #11, #E0, #11, #E0
            db #11, #11, #11, #E0, #11, #EE, #11, #E0, #11, #E0, #11, #E0, #0E, #E0, #0E, #E0
            db #11, #11, #11, #00, #01, #1E, #E1, #10, #01, #1E, #01, #1E, #01, #11, #11, #EE
            db #01, #1E, #E1, #10, #01, #1E, #01, #1E, #11, #11, #11, #EE, #0E, #EE, #EE, #E0
            db #00, #11, #11, #00, #01, #1E, #E1, #10, #11, #EE, #00, #EE, #11, #E0, #00, #00
            db #11, #E0, #00, #00, #01, #10, #01, #10, #00, #11, #11, #EE, #00, #0E, #EE, #E0
            db #11, #11, #10, #00, #01, #1E, #11, #00, #01, #1E, #01, #10, #01, #1E, #01, #1E
            db #01, #1E, #01, #1E, #01, #1E, #11, #EE, #11, #11, #1E, #E0, #0E, #EE, #EE, #00
            db #11, #11, #11, #10, #01, #1E, #EE, #1E, #01, #1E, #10, #0E, #01, #11, #1E, #00
            db #01, #1E, #1E, #00, #01, #1E, #0E, #10, #11, #11, #11, #1E, #0E, #EE, #EE, #EE
            db #11, #11, #11, #10, #01, #1E, #EE, #1E, #01, #1E, #10, #0E, #01, #11, #1E, #00
            db #01, #1E, #1E, #00, #01, #1E, #0E, #00, #11, #11, #00, #00, #0E, #EE, #E0, #00
            db #00, #11, #11, #00, #01, #1E, #E1, #10, #11, #EE, #00, #EE, #11, #E0, #00, #00
            db #11, #E0, #11, #10, #01, #10, #01, #1E, #00, #11, #11, #1E, #00, #0E, #EE, #EE
            db #11, #00, #11, #00, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #11, #11, #11, #E0
            db #11, #EE, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #0E, #E0, #0E, #E0
            db #01, #11, #10, #00, #00, #11, #EE, #00, #00, #11, #E0, #00, #00, #11, #E0, #00
            db #00, #11, #E0, #00, #00, #11, #E0, #00, #01, #11, #10, #00, #00, #EE, #EE, #00
            db #00, #01, #11, #10, #00, #00, #11, #EE, #00, #00, #11, #E0, #00, #00, #11, #E0
            db #11, #00, #11, #E0, #11, #E0, #11, #E0, #01, #11, #1E, #E0, #00, #EE, #EE, #00
            db #11, #10, #01, #10, #01, #1E, #01, #1E, #01, #1E, #11, #EE, #01, #11, #1E, #E0
            db #01, #1E, #11, #00, #01, #1E, #01, #10, #11, #1E, #01, #1E, #0E, #EE, #00, #EE
            db #11, #11, #00, #00, #01, #1E, #E0, #00, #01, #1E, #00, #00, #01, #1E, #00, #00
            db #01, #1E, #00, #10, #01, #1E, #01, #1E, #11, #11, #11, #1E, #0E, #EE, #EE, #EE
            db #11, #00, #01, #10, #11, #10, #11, #1E, #11, #11, #11, #1E, #11, #11, #11, #1E
            db #11, #E1, #E1, #1E, #11, #E0, #E1, #1E, #11, #E0, #01, #1E, #0E, #E0, #00, #EE
            db #11, #00, #01, #10, #11, #10, #01, #1E, #11, #11, #01, #1E, #11, #E1, #11, #1E
            db #11, #E0, #11, #1E, #11, #E0, #01, #1E, #11, #E0, #01, #1E, #0E, #E0, #00, #EE
            db #00, #11, #10, #00, #01, #1E, #11, #00, #11, #EE, #01, #10, #11, #E0, #01, #1E
            db #11, #E0, #01, #1E, #01, #10, #11, #EE, #00, #11, #1E, #E0, #00, #0E, #EE, #00
            db #11, #11, #11, #00, #01, #1E, #E1, #10, #01, #1E, #01, #1E, #01, #11, #11, #EE
            db #01, #1E, #EE, #E0, #01, #1E, #00, #00, #11, #11, #00, #00, #0E, #EE, #E0, #00
            db #01, #11, #10, #00, #11, #EE, #11, #00, #11, #E0, #11, #E0, #11, #E0, #11, #E0
            db #11, #E1, #11, #E0, #01, #11, #1E, #E0, #00, #E1, #11, #00, #00, #00, #EE, #E0
            db #11, #11, #11, #00, #01, #1E, #E1, #10, #01, #1E, #01, #1E, #01, #11, #11, #EE
            db #01, #1E, #11, #E0, #01, #1E, #01, #10, #11, #1E, #01, #1E, #0E, #EE, #00, #EE
            db #01, #11, #10, #00, #11, #EE, #11, #00, #11, #10, #0E, #E0, #01, #11, #00, #00
            db #00, #E1, #11, #00, #11, #00, #11, #E0, #01, #11, #1E, #E0, #00, #EE, #EE, #00
            db #11, #11, #11, #00, #1E, #11, #E1, #E0, #0E, #11, #E0, #E0, #00, #11, #E0, #00
            db #00, #11, #E0, #00, #00, #11, #E0, #00, #01, #11, #10, #00, #00, #EE, #EE, #00
            db #11, #00, #11, #00, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #11, #E0
            db #11, #E0, #11, #E0, #11, #E0, #11, #E0, #11, #11, #11, #E0, #0E, #EE, #EE, #E0
            db #11, #00, #11, #00, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #11, #E0
            db #11, #E0, #11, #E0, #01, #11, #1E, #E0, #00, #11, #EE, #00, #00, #0E, #E0, #00
            db #11, #00, #01, #10, #11, #E0, #01, #1E, #11, #E0, #01, #1E, #11, #E1, #01, #1E
            db #11, #11, #11, #1E, #11, #1E, #11, #1E, #11, #EE, #01, #1E, #0E, #E0, #00, #EE
            db #11, #00, #01, #10, #11, #E0, #01, #1E, #01, #10, #11, #EE, #00, #11, #1E, #E0
            db #00, #11, #1E, #00, #01, #1E, #11, #00, #11, #EE, #01, #10, #0E, #E0, #00, #EE
            db #11, #00, #11, #00, #11, #E0, #11, #E0, #11, #E0, #11, #E0, #01, #11, #1E, #E0
            db #00, #11, #EE, #00, #00, #11, #E0, #00, #01, #11, #10, #00, #00, #EE, #EE, #00
            db #11, #11, #11, #10, #11, #EE, #E1, #1E, #1E, #E0, #11, #EE, #0E, #01, #1E, #E0
            db #00, #11, #EE, #10, #01, #1E, #E1, #1E, #11, #11, #11, #1E, #0E, #EE, #EE, #EE
            db #01, #11, #10, #00, #01, #1E, #EE, #00, #01, #1E, #00, #00, #01, #1E, #00, #00
            db #01, #1E, #00, #00, #01, #1E, #00, #00, #01, #11, #10, #00, #00, #EE, #EE, #00
            db #11, #00, #00, #00, #01, #10, #00, #00, #00, #11, #00, #00, #00, #01, #10, #00
            db #00, #00, #11, #00, #00, #00, #01, #10, #00, #00, #00, #1E, #00, #00, #00, #0E
            db #01, #11, #10, #00, #00, #E1, #1E, #00, #00, #01, #1E, #00, #00, #01, #1E, #00
            db #00, #01, #1E, #00, #00, #01, #1E, #00, #01, #11, #1E, #00, #00, #EE, #EE, #00
            db #00, #01, #00, #00, #00, #11, #10, #00, #01, #1E, #11, #00, #11, #EE, #01, #10
            db #0E, #E0, #00, #EE, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #11, #11, #11, #11
            db #00, #00, #00, #00, #77, #00, #00, #00, #77, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #77, #00, #00, #00, #77, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #77, #00, #00, #00, #77, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #77, #00, #00, #00, #77, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #77, #00, #00, #00
            db #77, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #77, #00, #00
            db #00, #77, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #77, #00
            db #00, #00, #77, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #77
            db #00, #00, #00, #77, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #77, #00, #00, #00, #77, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #77, #00, #00, #66, #77, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #77, #00, #66, #66, #77, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #77, #66, #66, #66, #77, #00, #00, #00, #00
            db #00, #00, #00, #00, #88, #00, #00, #00, #88, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #88, #00, #00, #00, #88, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #88, #00, #00, #00, #88, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #88, #00, #00, #00, #88, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #88, #00, #00, #00
            db #88, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #88, #00, #00
            db #00, #88, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #88, #00
            db #00, #00, #88, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #88
            db #00, #00, #00, #88, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #88, #00, #00, #00, #88, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #88, #00, #00, #66, #88, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #88, #00, #66, #66, #88, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #88, #66, #66, #66, #88, #00, #00, #00, #00
            db #00, #00, #00, #00, #11, #00, #00, #00, #11, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #11, #00, #00, #00, #11, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #11, #00, #00, #00
            db #11, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #11, #00, #00
            db #00, #11, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #11, #00
            db #00, #00, #11, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #11
            db #00, #00, #00, #11, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #11, #00, #00, #00, #11, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #11, #00, #00, #66, #11, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #11, #00, #66, #66, #11, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #11, #66, #66, #66, #11, #00, #00, #00, #00
            db #00, #00, #00, #00, #CC, #00, #00, #00, #CC, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #CC, #00, #00, #00, #CC, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #CC, #00, #00, #00, #CC, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #CC, #00, #00, #00, #CC, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #CC, #00, #00, #00
            db #CC, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #CC, #00, #00
            db #00, #CC, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #CC, #00
            db #00, #00, #CC, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #CC
            db #00, #00, #00, #CC, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #CC, #00, #00, #00, #CC, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #CC, #00, #00, #66, #CC, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #CC, #00, #66, #66, #CC, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #CC, #66, #66, #66, #CC, #00, #00, #00, #00
            db #00, #00, #00, #00, #99, #00, #00, #00, #99, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #99, #00, #00, #00, #99, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #99, #00, #00, #00, #99, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #99, #00, #00, #00, #99, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #99, #00, #00, #00
            db #99, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #99, #00, #00
            db #00, #99, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #99, #00
            db #00, #00, #99, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #99
            db #00, #00, #00, #99, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #99, #00, #00, #00, #99, #66, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #99, #00, #00, #66, #99, #66, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #99, #00, #66, #66, #99, #66, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #99, #66, #66, #66, #99, #00, #00, #00, #00
            db 0, 0
            MMU 6 7, 0
            ORG ld_end
#endasm
End Sub
