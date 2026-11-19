' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit
Option SaveNex "DEFHELL.DAT", 46, 47      ' the patterns in page 46, the tiles in page 47 (a page is the Next's 16K bank of the same number)

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
            ld a, 92               ; page 46 (its first half) at #E000: 64 patterns
            call ld_pg
            ld hl, #E000
            ld de, 8192
            call ld_po
            ld a, 93               ; its second half: 23 more
            call ld_pg
            ld hl, #E000
            ld de, 2944
            call ld_po
            ld a, 94               ; page 47 at #E000: the tiles
            call ld_pg
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
ld_done:
            ld bc, #243B            ; bank 5 back at #E000
            ld a, #57
            out (c), a
            inc b
            ld a, 11
            out (c), a
            ld sp, ({sps})
            jp ld_end
; ld_pg - the Next's 8K page A at #E000 (MMU slot 7)
ld_pg:
            ld bc, #243B
            push af
            ld a, #57
            out (c), a
            inc b
            pop af
            out (c), a
            ret
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
#endasm
End Sub
