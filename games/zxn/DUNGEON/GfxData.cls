' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit
Option SaveNex "DUNGEON.DAT", 45, 46      ' the patterns in page 45, the tiles in page 46 (a page is the Next's 16K bank of the same number)

Public Const S_MON = 0
Public Const S_MON_N = 8
Public Const S_MON_W = 2
Public Const S_MON_H = 2
Public Const S_MON2 = 32
Public Const S_MON2_N = 4
Public Const S_MON2_W = 2
Public Const S_MON2_H = 2
Public Const S_HERO = 48
Public Const S_HERO_N = 4
Public Const S_HERO_W = 2
Public Const S_HERO_H = 2
Public Const S_THING = 64
Public Const S_THING_N = 4
Public Const S_FX = 68
Public Const S_FX_N = 4
Public Const S_STAIRS = 72
Public Const S_STAIRS_N = 1
Public Const S_POINT = 73
Public Const S_POINT_N = 1
Public Const T_PANEL = 1
Public Const T_FTL = 2
Public Const T_FT = 3
Public Const T_FTR = 4
Public Const T_FL = 5
Public Const T_FR = 6
Public Const T_FBL = 7
Public Const T_FB = 8
Public Const T_FBR = 9
Public Const T_BLACK = 10
Public Const T_KEY = 11
Public Const T_GOLD = 12
Public Const T_POTION = 13
Public Const T_BARH = 112
Public Const T_BARH_N = 9
Public Const T_BARM = 121
Public Const T_BARM_N = 9
Public Const T_MWALL = 96
Public Const T_MFLOOR = 97
Public Const T_MYOU = 98
Public Const T_MYOU_N = 4
Public Const T_MSTAIRS = 102
Public Const T_MDOOR = 103
Public Const T_MMON = 104
Public Const T_MCHEST = 105
Public Const T_MDARK = 106
Public Const SpritePatterns = 74
Public Const SpritePalettes = 11

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
            ld e, 176                ; 11 x 16 (0 = 256)
            call palset
            ld a, #43               ; back to the ULA's, first palettes in use
            out (c), a
            inc b
            xor a
            out (c), a
            ld bc, #303B            ; sprite patterns from pattern 0
            xor a
            out (c), a
            ld a, 90               ; page 45 (its first half) at #E000: 64 patterns
            call ld_pg
            ld hl, #E000
            ld de, 8192
            call ld_po
            ld a, 91               ; its second half: 10 more
            call ld_pg
            ld hl, #E000
            ld de, 1280
            call ld_po
            ld a, 92               ; page 46 at #E000: the tiles
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
            db #00, #FF, #25, #8D, #D6, #E4, #53, #F8, #58, #92, #40, #05, #B2, #24, #00, #E3
spal:
            db #00, #FF, #F6, #D1, #88, #5F, #A7, #41, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #79, #50, #28, #FC, #AD, #64, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #ED, #A4, #60, #FC, #6D, #24, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #FE, #DA, #91, #E0, #8D, #44, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #B1, #88, #44, #E0, #D6, #69, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #6F, #4A, #25, #E0, #93, #4A, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #D3, #8B, #42, #7F, #AB, #41, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #DF, #9B, #53, #FF, #BF, #53, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #F8, #D0, #88, #E0, #FD, #AC, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #00, #FF, #57, #2E, #05, #FC, #7B, #2A, #B6, #FE, #E4, #F8, #2B, #55, #8D, #E3
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #E3
ld_end:
#endasm
End Sub
