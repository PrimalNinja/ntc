' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_CLAW = 0
Public Const S_CLAW_N = 2
Public Const S_CLAWD = 2
Public Const S_CLAWD_N = 2
Public Const S_SHOT = 4
Public Const S_SHOT_N = 2
Public Const S_BULLET = 6
Public Const S_BULLET_N = 3
Public Const S_GUARD = 9
Public Const S_GUARD_N = 1
Public Const S_ITEM = 10
Public Const S_ITEM_N = 2
Public Const S_BIGP = 12
Public Const S_BIGP_N = 1
Public Const S_GEM = 13
Public Const S_GEM_N = 1
Public Const S_GITEM = 14
Public Const S_GITEM_N = 1
Public Const S_NITEM = 15
Public Const S_NITEM_N = 1
Public Const S_SNAP = 16
Public Const S_SNAP_N = 3
Public Const S_POD = 19
Public Const S_POD_N = 3
Public Const S_SPIN = 22
Public Const S_SPIN_N = 3
Public Const S_PULS = 25
Public Const S_PULS_N = 3
Public Const S_SEED = 28
Public Const S_SEED_N = 3
Public Const S_FUSES = 31
Public Const S_FUSES_N = 1
Public Const S_FUSE = 32
Public Const S_FUSE_N = 2
Public Const S_CORE = 34
Public Const S_CORE_N = 2
Public Const S_CORE_W = 2
Public Const S_CORE_H = 2
Public Const T_PANEL = 1
Public Const T_PANELB = 2
Public Const T_LIFE = 3
Public Const T_NOVA = 4
Public Const T_GUARDT = 5
Public Const T_PGAUGE = 9
Public Const T_PGAUGE_N = 5
Public Const T_GAUGE = 16
Public Const T_GAUGE_N = 9
Public Const SpritePatterns = 42
Public Const SpritePalettes = 9

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
            ld e, 144                ; 9 x 16 (0 = 256)
            call palset
            ld a, #43               ; back to the ULA's, first palettes in use
            out (c), a
            inc b
            xor a
            out (c), a
            ld bc, #303B            ; sprite patterns from pattern 0
            xor a
            out (c), a
            ld hl, #C000            ; 42 from bank 5 (#C000)
            ld de, 5376
            call ld_po
            ld hl, #F400            ; 0 from bank 5 (#F400)
            ld de, 0
            call ld_po
            ld bc, #243B            ; the rest from bank 45 (its first page at #E000)
            ld a, #57
            out (c), a
            inc b
            ld a, 90
            out (c), a
            ld hl, #E000
            ld de, 0
            call ld_po
            ld bc, #243B
            ld a, #57               ; the tiles: its second page at #E000
            out (c), a
            inc b
            ld a, 91
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
            ld de, 5376
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
            db #00, #FF, #B6, #6D, #21, #C7, #E4, #F0, #FC, #5F, #2B, #EE, #58, #60, #62, #E3
spal:
            db #00, #FF, #FC, #F0, #E0, #E3, #83, #2B, #1F, #18, #BC, #EF, #02, #60, #92, #E3
            db #B6, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #E3
            db #00, #FF, #F7, #EB, #A2, #E3, #83, #2B, #1F, #18, #BC, #EF, #02, #60, #92, #E3
            db #00, #FF, #9F, #1B, #0F, #E3, #83, #2B, #1F, #18, #BC, #EF, #02, #60, #92, #E3
            db #00, #FF, #FD, #F4, #C8, #E3, #83, #2B, #1F, #18, #BC, #EF, #02, #60, #92, #E3
            db #00, #FF, #BD, #5C, #10, #E3, #83, #2B, #1F, #18, #BC, #EF, #02, #60, #92, #E3
            db #00, #FF, #FC, #F0, #1F, #FC, #12, #2B, #EC, #E3, #BC, #EF, #02, #60, #92, #E3
            db #00, #FF, #FC, #F0, #FC, #1C, #90, #2B, #E0, #0F, #BC, #EF, #02, #60, #92, #E3
            db #00, #FF, #FC, #F0, #E0, #FF, #E3, #2B, #FC, #18, #BC, #EF, #02, #60, #92, #E3
ld_end:
            MMU 6 7, 10             ; bank 5 (in the NEX file): the first patterns
            ORG #C000
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #33, #FF, #FF, #32, #FF, #FF, #FF, #FF, #23, #FF, #FF, #32, #FF, #FF
            db #FF, #F2, #2F, #3F, #F3, #32, #2F, #FF, #FF, #F2, #FF, #3F, #F3, #FF, #2F, #FF
            db #FF, #F2, #FF, #3F, #33, #FF, #2F, #FF, #FF, #22, #FF, #F3, #3F, #FF, #22, #FF
            db #FF, #2F, #FF, #F3, #3F, #FF, #F2, #FF, #FF, #2F, #FF, #FF, #FF, #FF, #F2, #FF
            db #F2, #33, #33, #33, #33, #33, #32, #2F, #F2, #FF, #FF, #FF, #FF, #FF, #FF, #2F
            db #22, #22, #22, #22, #22, #22, #22, #2F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF
            db #FF, #FF, #33, #FF, #1F, #32, #FF, #FF, #FF, #FF, #23, #FF, #1F, #32, #FF, #FF
            db #FF, #F2, #2F, #3F, #13, #32, #2F, #FF, #FF, #F2, #FF, #3F, #13, #FF, #2F, #FF
            db #FF, #F2, #FF, #11, #13, #FF, #2F, #FF, #FF, #22, #FF, #F3, #1F, #FF, #22, #FF
            db #FF, #2F, #FF, #F3, #1F, #FF, #F2, #FF, #FF, #2F, #FF, #FF, #FF, #FF, #F2, #FF
            db #F2, #33, #33, #33, #33, #33, #32, #2F, #F2, #FF, #FF, #FF, #FF, #FF, #FF, #2F
            db #22, #22, #22, #22, #22, #22, #22, #2F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #3F, #FF, #FF
            db #FF, #FF, #FF, #FF, #23, #FF, #FF, #FF, #FF, #FF, #F2, #22, #F3, #FF, #FF, #FF
            db #FF, #F2, #22, #FF, #33, #FF, #FF, #FF, #F2, #22, #FF, #FF, #3F, #FF, #FF, #3F
            db #2F, #3F, #FF, #FF, #3F, #F3, #33, #FF, #2F, #F3, #FF, #F3, #F3, #33, #F2, #FF
            db #F2, #FF, #3F, #F3, #3F, #FF, #2F, #FF, #FF, #2F, #F3, #FF, #FF, #FF, #2F, #FF
            db #FF, #F2, #F3, #3F, #FF, #F2, #2F, #FF, #FF, #FF, #2F, #F3, #FF, #F2, #FF, #FF
            db #FF, #FF, #F2, #FF, #3F, #22, #FF, #FF, #FF, #FF, #FF, #2F, #F3, #2F, #FF, #FF
            db #FF, #FF, #FF, #F2, #FF, #2F, #FF, #FF, #FF, #FF, #FF, #FF, #22, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #3F, #FF, #FF
            db #FF, #FF, #FF, #FF, #23, #FF, #FF, #FF, #FF, #FF, #F2, #22, #F3, #FF, #1F, #FF
            db #FF, #F2, #22, #FF, #33, #F1, #FF, #FF, #F2, #22, #FF, #FF, #3F, #1F, #FF, #3F
            db #2F, #3F, #FF, #FF, #11, #F3, #33, #FF, #2F, #F3, #FF, #F3, #13, #33, #F2, #FF
            db #F2, #FF, #3F, #F1, #31, #FF, #2F, #FF, #FF, #2F, #F3, #FF, #FF, #FF, #2F, #FF
            db #FF, #F2, #F3, #3F, #FF, #F2, #2F, #FF, #FF, #FF, #2F, #F3, #FF, #F2, #FF, #FF
            db #FF, #FF, #F2, #FF, #3F, #22, #FF, #FF, #FF, #FF, #FF, #2F, #F3, #2F, #FF, #FF
            db #FF, #FF, #FF, #F2, #FF, #2F, #FF, #FF, #FF, #FF, #FF, #FF, #22, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #33, #33, #FF, #FF, #FF
            db #FF, #FF, #33, #32, #33, #3F, #FF, #FF, #FF, #F3, #32, #22, #22, #33, #FF, #FF
            db #FF, #F3, #32, #11, #12, #33, #FF, #FF, #FF, #F3, #22, #11, #12, #23, #FF, #FF
            db #FF, #F3, #32, #11, #12, #33, #FF, #FF, #FF, #F3, #32, #22, #22, #33, #FF, #FF
            db #FF, #FF, #33, #32, #33, #3F, #FF, #FF, #FF, #FF, #F3, #33, #33, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #3F, #FF, #FF, #FF
            db #FF, #FF, #F3, #21, #23, #FF, #FF, #FF, #FF, #FF, #F3, #11, #13, #FF, #FF, #FF
            db #FF, #FF, #F3, #21, #23, #FF, #FF, #FF, #FF, #FF, #FF, #33, #3F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #33, #3F, #FF, #FF, #FF
            db #FF, #FF, #F3, #21, #23, #FF, #FF, #FF, #FF, #FF, #F3, #11, #13, #FF, #FF, #FF
            db #FF, #FF, #F3, #21, #23, #FF, #FF, #FF, #FF, #FF, #FF, #33, #3F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #44, #44, #FF, #FF, #FF
            db #FF, #FF, #44, #33, #34, #4F, #FF, #FF, #FF, #F4, #43, #22, #23, #44, #FF, #FF
            db #FF, #F4, #32, #21, #22, #34, #FF, #FF, #FF, #F4, #32, #11, #12, #34, #FF, #FF
            db #FF, #F4, #32, #21, #22, #34, #FF, #FF, #FF, #F4, #43, #22, #23, #44, #FF, #FF
            db #FF, #FF, #44, #33, #34, #4F, #FF, #FF, #FF, #FF, #F4, #44, #44, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F3, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #3F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F3, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #3F, #13, #FF, #FF, #FF
            db #FF, #FF, #FF, #3F, #13, #FF, #FF, #FF, #FF, #FF, #FF, #3F, #13, #FF, #FF, #FF
            db #FF, #FF, #FF, #22, #23, #3F, #FF, #FF, #FF, #FF, #FF, #3F, #13, #FF, #FF, #FF
            db #FF, #FF, #FF, #3F, #13, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #F3, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #3F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #18, #F1, #8F, #18, #FF, #FF
            db #FF, #F8, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #F8, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F8, #FF, #FF, #FF, #FF, #FF, #FF, #1F
            db #F1, #FF, #FF, #FF, #FF, #FF, #FF, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #8F, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #8F
            db #F8, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #1F, #FF, #FF, #FF, #FF, #F8, #FF, #FF, #F8, #FF, #FF, #FF, #FF, #1F, #FF
            db #FF, #FF, #18, #F1, #8F, #18, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F8, #88, #88, #88, #88, #8F, #FF
            db #FF, #87, #77, #77, #77, #77, #78, #FF, #FF, #87, #77, #77, #77, #77, #78, #FF
            db #FF, #87, #71, #11, #11, #17, #78, #FF, #FF, #87, #77, #11, #77, #11, #78, #FF
            db #FF, #87, #77, #11, #77, #11, #78, #FF, #FF, #87, #77, #11, #11, #17, #78, #FF
            db #FF, #87, #77, #11, #77, #77, #78, #FF, #FF, #87, #77, #11, #77, #77, #78, #FF
            db #FF, #87, #71, #11, #17, #77, #78, #FF, #FF, #87, #77, #77, #77, #77, #78, #FF
            db #FF, #87, #77, #77, #77, #77, #78, #FF, #FF, #87, #77, #77, #77, #77, #78, #FF
            db #FF, #F8, #88, #88, #88, #88, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F8, #88, #88, #8F, #FF, #FF
            db #FF, #FF, #87, #77, #77, #78, #FF, #FF, #FF, #FF, #87, #77, #77, #78, #FF, #FF
            db #FF, #FF, #81, #11, #17, #78, #FF, #FF, #FF, #FF, #81, #17, #11, #78, #FF, #FF
            db #FF, #FF, #81, #17, #11, #78, #FF, #FF, #FF, #FF, #81, #11, #17, #78, #FF, #FF
            db #FF, #FF, #81, #17, #77, #78, #FF, #FF, #FF, #FF, #81, #17, #77, #78, #FF, #FF
            db #FF, #FF, #81, #11, #77, #78, #FF, #FF, #FF, #FF, #87, #77, #77, #78, #FF, #FF
            db #FF, #FF, #87, #77, #77, #78, #FF, #FF, #FF, #FF, #87, #77, #77, #78, #FF, #FF
            db #FF, #FF, #F8, #88, #88, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #F2, #2F, #22, #F2, #2F, #22, #F2, #2F, #22, #22, #22, #22, #22, #22, #22, #22
            db #23, #33, #33, #33, #33, #33, #33, #32, #23, #33, #33, #33, #33, #33, #33, #32
            db #23, #33, #33, #33, #11, #11, #11, #32, #23, #33, #33, #33, #31, #13, #31, #12
            db #23, #33, #33, #33, #31, #13, #31, #12, #23, #33, #33, #33, #31, #11, #11, #32
            db #23, #33, #33, #33, #31, #13, #33, #32, #23, #33, #33, #33, #31, #13, #33, #32
            db #23, #33, #33, #33, #11, #11, #33, #32, #23, #33, #33, #33, #33, #33, #33, #32
            db #23, #33, #33, #33, #33, #33, #33, #32, #23, #33, #33, #33, #33, #33, #33, #32
            db #F2, #22, #22, #22, #22, #22, #22, #2F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #81, #18, #FF, #FF, #FF, #FF, #FF, #F8, #81, #1F, #8F, #FF, #FF
            db #FF, #FF, #88, #11, #11, #88, #FF, #FF, #FF, #FF, #8F, #1F, #F1, #F8, #8F, #FF
            db #FF, #F8, #FF, #1F, #F1, #FF, #8F, #FF, #FF, #8F, #FF, #1F, #F1, #FF, #F8, #FF
            db #FF, #11, #11, #91, #19, #91, #11, #1F, #FF, #F8, #FF, #9F, #F9, #FF, #8F, #FF
            db #FF, #FF, #8F, #9F, #F9, #F8, #8F, #FF, #FF, #FF, #88, #99, #99, #88, #FF, #FF
            db #FF, #FF, #F8, #89, #9F, #8F, #FF, #FF, #FF, #FF, #FF, #89, #98, #FF, #FF, #FF
            db #FF, #FF, #FF, #F9, #9F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #99, #99, #99, #99, #99, #99, #FF
            db #F9, #CC, #CC, #CC, #CC, #CC, #CC, #9F, #F9, #CC, #CC, #CC, #CC, #CC, #CC, #9F
            db #F9, #CC, #CC, #CA, #AA, #AC, #CC, #9F, #F9, #CC, #CC, #AA, #CC, #AA, #CC, #9F
            db #F9, #CC, #CA, #AC, #CC, #CC, #CC, #9F, #F9, #CC, #CA, #AC, #CC, #CC, #CC, #9F
            db #F9, #CC, #CA, #AC, #CA, #AA, #CC, #9F, #F9, #CC, #CC, #AA, #CC, #AA, #CC, #9F
            db #F9, #CC, #CC, #CA, #AA, #AA, #CC, #9F, #F9, #CC, #CC, #CC, #CC, #CC, #CC, #9F
            db #F9, #CC, #CC, #CC, #CC, #CC, #CC, #9F, #F9, #CC, #CC, #CC, #CC, #CC, #CC, #9F
            db #FF, #99, #99, #99, #99, #99, #99, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #44, #44, #44, #44, #44, #44, #FF
            db #F4, #DD, #DD, #DD, #DD, #DD, #DD, #4F, #F4, #DD, #DD, #DD, #DD, #DD, #DD, #4F
            db #F4, #DD, #D2, #2D, #DD, #22, #DD, #4F, #F4, #DD, #D2, #22, #DD, #22, #DD, #4F
            db #F4, #DD, #D2, #22, #2D, #22, #DD, #4F, #F4, #DD, #D2, #2D, #22, #22, #DD, #4F
            db #F4, #DD, #D2, #2D, #D2, #22, #DD, #4F, #F4, #DD, #D2, #2D, #DD, #22, #DD, #4F
            db #F4, #DD, #D2, #2D, #DD, #22, #DD, #4F, #F4, #DD, #DD, #DD, #DD, #DD, #DD, #4F
            db #F4, #DD, #DD, #DD, #DD, #DD, #DD, #4F, #F4, #DD, #DD, #DD, #DD, #DD, #DD, #4F
            db #FF, #44, #44, #44, #44, #44, #44, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #44, #FF, #FF, #44, #FF, #FF, #FF, #FF, #4F, #44, #44, #F4, #FF, #FF
            db #FF, #FF, #4F, #FF, #F4, #F4, #FF, #FF, #FF, #FF, #44, #FF, #FF, #44, #FF, #FF
            db #FF, #FF, #4F, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #44, #4F, #FF, #FF, #FF, #FF, #F4, #4F, #4F, #44, #4F, #FF, #FF, #F4, #44, #4F
            db #4F, #FF, #44, #FF, #FF, #44, #FF, #4F, #4F, #FF, #FF, #44, #44, #FF, #FF, #4F
            db #4F, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #4F, #FF, #44, #FF, #FF, #44, #FF, #4F
            db #4F, #44, #4F, #FF, #FF, #F4, #44, #4F, #44, #4F, #FF, #FF, #FF, #FF, #F4, #4F
            db #4F, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #4F, #FF, #FF, #FF, #FF, #FF, #FF, #4F, #44, #44, #44, #44, #F4, #44, #44, #4F
            db #44, #44, #44, #44, #F4, #44, #44, #4F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #66, #66, #FF, #FF, #FF
            db #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #66, #FF, #9F, #66, #FF, #FF
            db #FF, #FF, #66, #F9, #9F, #66, #FF, #FF, #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF
            db #FF, #FF, #FF, #66, #66, #FF, #FF, #FF, #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF
            db #FF, #FF, #FF, #6F, #F6, #FF, #FF, #FF, #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF
            db #FF, #FF, #6F, #FF, #FF, #F6, #FF, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #6F, #FF
            db #FF, #6F, #FF, #FF, #9F, #FF, #F6, #FF, #F6, #FF, #FF, #FF, #9F, #FF, #FF, #6F
            db #66, #FF, #FF, #99, #9F, #FF, #FF, #6F, #FF, #6F, #FF, #FF, #FF, #FF, #F6, #FF
            db #FF, #F6, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #6F, #FF, #FF, #F6, #FF, #FF
            db #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #6F, #F6, #FF, #FF, #FF
            db #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF
            db #FF, #FF, #FF, #6F, #F6, #FF, #FF, #FF, #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF
            db #FF, #FF, #6F, #FF, #FF, #F6, #FF, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #6F, #FF
            db #FF, #6F, #FF, #9F, #9F, #FF, #F6, #FF, #F6, #FF, #FF, #F9, #9F, #FF, #FF, #6F
            db #66, #FF, #FF, #99, #9F, #FF, #FF, #6F, #FF, #6F, #FF, #FF, #FF, #FF, #F6, #FF
            db #FF, #F6, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #6F, #FF, #FF, #F6, #FF, #FF
            db #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #6F, #F6, #FF, #FF, #FF
            db #FF, #FF, #FF, #F6, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #9F, #FF, #FF, #FF
            db #FF, #FF, #FF, #99, #FA, #AF, #FF, #FF, #FF, #FF, #FF, #9F, #FF, #AF, #FF, #FF
            db #FF, #FF, #FF, #99, #9F, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FA, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #AF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F9, #99, #9F, #FF, #FF
            db #FF, #FF, #FF, #99, #FF, #9A, #FF, #FF, #FF, #FF, #F9, #FF, #FF, #FF, #AF, #FF
            db #FF, #FF, #F9, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #F9, #FF, #FF, #FF, #FA, #FF
            db #FF, #FF, #F9, #FF, #9F, #FF, #FA, #FF, #FF, #FF, #FF, #99, #9F, #FF, #FA, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF, #FF
            db #FF, #FF, #FF, #FF, #FA, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F9, #99, #9F, #FF, #FF
            db #FF, #FF, #FF, #9F, #FF, #F9, #FF, #FF, #FF, #FF, #FF, #9F, #FF, #F9, #9F, #FF
            db #FF, #FF, #FF, #99, #9F, #FF, #9F, #FF, #FA, #FF, #FF, #FF, #FF, #FF, #9F, #FF
            db #FA, #AF, #FF, #FF, #FF, #F9, #9F, #FF, #FF, #AF, #FF, #FF, #FF, #FA, #FF, #FF
            db #FF, #FA, #AF, #FF, #FA, #AF, #FF, #FF, #FF, #FF, #AA, #AA, #AA, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F8, #8F, #88, #FF, #FF, #FF
            db #FF, #FF, #F8, #8F, #88, #FF, #FF, #FF, #FF, #FF, #8F, #8F, #88, #FF, #FF, #FF
            db #FF, #FF, #8F, #8F, #88, #F8, #FF, #FF, #FF, #FF, #FF, #F8, #FF, #8F, #FF, #FF
            db #FF, #FF, #FF, #F8, #FF, #8F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #8F, #FF, #FF, #8F, #FF, #FF, #FF, #F8, #8F, #FF, #F8, #8F, #FF, #FF
            db #FF, #88, #8F, #FF, #F8, #8F, #FF, #FF, #FF, #8F, #8F, #FF, #F8, #8F, #FF, #FF
            db #F8, #8F, #88, #FF, #8F, #88, #FF, #FF, #F8, #FF, #F8, #FF, #8F, #F8, #FF, #FF
            db #8F, #FF, #F8, #FF, #8F, #F8, #FF, #8F, #FF, #FF, #F8, #8F, #8F, #F8, #8F, #8F
            db #FF, #FF, #FF, #88, #FF, #FF, #88, #8F, #FF, #FF, #FF, #88, #FF, #FF, #88, #FF
            db #FF, #FF, #FF, #88, #FF, #FF, #88, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #1F, #FF, #FF, #1F, #FF, #FF, #FF, #F1, #1F, #FF, #F1, #1F, #FF, #FF
            db #FF, #F1, #1F, #FF, #F1, #1F, #FF, #FF, #FF, #1F, #1F, #FF, #F1, #1F, #FF, #FF
            db #FF, #1F, #1F, #FF, #F1, #1F, #FF, #FF, #FF, #1F, #11, #FF, #11, #11, #FF, #FF
            db #F1, #FF, #F1, #FF, #1F, #F1, #FF, #FF, #F1, #FF, #F1, #FF, #1F, #F1, #FF, #FF
            db #88, #88, #88, #88, #88, #88, #88, #8F, #FF, #FF, #F1, #FF, #1F, #F1, #FF, #1F
            db #FF, #FF, #F1, #11, #1F, #F1, #1F, #1F, #FF, #FF, #FF, #11, #FF, #FF, #11, #1F
            db #FF, #FF, #FF, #11, #FF, #FF, #11, #FF, #FF, #FF, #FF, #11, #FF, #FF, #11, #FF
            db #FF, #FF, #FF, #11, #FF, #FF, #11, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F3, #3F, #FF, #FF, #FF, #FF, #FF, #F3, #3F, #23, #3F, #FF, #FF
            db #FF, #FF, #F3, #FF, #2F, #3F, #FF, #FF, #FF, #FF, #3F, #FF, #2F, #F3, #FF, #FF
            db #FF, #FF, #32, #22, #22, #23, #FF, #FF, #FF, #FF, #F3, #FF, #2F, #3F, #FF, #FF
            db #FF, #FF, #F3, #3F, #23, #3F, #FF, #FF, #FF, #FF, #FF, #F3, #3F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #33, #33, #FF, #FF, #FF
            db #FF, #F3, #33, #FF, #2F, #33, #3F, #FF, #FF, #33, #FF, #FF, #2F, #FF, #33, #FF
            db #FF, #3F, #FF, #FF, #2F, #FF, #F3, #FF, #FF, #3F, #FF, #FF, #2F, #FF, #F3, #FF
            db #F3, #FF, #FF, #FF, #2F, #FF, #FF, #3F, #F3, #FF, #FF, #FF, #2F, #FF, #FF, #3F
            db #33, #22, #22, #22, #22, #22, #2F, #3F, #F3, #FF, #FF, #FF, #2F, #FF, #FF, #3F
            db #FF, #3F, #FF, #FF, #2F, #FF, #F3, #FF, #FF, #3F, #FF, #FF, #2F, #FF, #F3, #FF
            db #FF, #33, #FF, #FF, #2F, #FF, #33, #FF, #FF, #F3, #33, #FF, #FF, #33, #3F, #FF
            db #FF, #FF, #FF, #33, #33, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F3, #33, #33, #3F, #FF, #FF
            db #FF, #F3, #3F, #FF, #FF, #F3, #3F, #FF, #FF, #33, #FF, #FF, #FF, #FF, #33, #FF
            db #FF, #3F, #2F, #FF, #FF, #F2, #F3, #FF, #F3, #FF, #F2, #FF, #FF, #2F, #FF, #3F
            db #F3, #FF, #FF, #2F, #F2, #FF, #FF, #3F, #F3, #FF, #FF, #F2, #2F, #FF, #FF, #3F
            db #F3, #FF, #FF, #11, #1F, #FF, #FF, #3F, #F3, #FF, #FF, #2F, #F2, #FF, #FF, #3F
            db #F3, #FF, #F2, #FF, #FF, #2F, #FF, #3F, #FF, #3F, #2F, #FF, #FF, #F2, #F3, #FF
            db #FF, #33, #FF, #FF, #FF, #FF, #33, #FF, #FF, #F3, #3F, #FF, #FF, #F3, #3F, #FF
            db #FF, #FF, #F3, #33, #33, #3F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FA, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF, #FF, #FF, #44, #22, #8F, #FF, #FF, #FF
            db #FF, #FF, #4F, #F2, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FA, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #AA, #FF, #FF, #FF, #FF
            db #FF, #FF, #2F, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #42, #AF, #FF, #8F, #FF, #FF
            db #FF, #44, #F2, #AF, #F8, #FF, #FF, #FF, #F4, #FF, #FF, #2F, #F8, #FF, #FF, #FF
            db #4F, #FF, #FF, #22, #8F, #1F, #FF, #FF, #FF, #FF, #FF, #F2, #81, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #81, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F1, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #F2, #44, #4F, #FF, #FF, #88, #FF, #FF, #F2, #FF, #FF
            db #FF, #88, #8F, #FF, #FF, #2F, #FF, #FF, #F8, #8F, #FF, #FF, #FF, #2F, #FF, #FF
            db #8F, #FF, #AA, #FF, #F2, #FF, #FF, #FF, #FF, #FF, #FA, #FF, #F2, #FF, #FF, #FF
            db #FF, #FF, #FA, #AF, #2F, #FF, #FF, #FF, #FF, #FF, #FF, #AF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #AF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F6, #66
            db #FF, #FF, #FF, #FF, #FF, #F6, #66, #FF, #FF, #FF, #FF, #FF, #66, #6F, #FF, #FF
            db #FF, #FF, #FF, #66, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF
            db #FF, #F6, #6F, #FF, #FF, #FF, #F8, #88, #FF, #F6, #FF, #FF, #FF, #F8, #88, #FF
            db #FF, #F6, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #F8, #FF, #FD, #DD
            db #FF, #6F, #FF, #FF, #F8, #FF, #DD, #DD, #F6, #6F, #FF, #FF, #88, #FD, #DD, #44
            db #F6, #FF, #FF, #FF, #8F, #FD, #D4, #41, #F6, #FF, #FF, #FF, #8F, #FD, #D4, #11
            db #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #6F, #FF, #FF, #FF, #FF, #FF, #FF
            db #6F, #66, #6F, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #F6, #66, #FF, #FF, #FF, #FF
            db #6F, #FF, #FF, #F6, #66, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #6F, #FF, #FF, #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #F6, #FF, #FF
            db #88, #8F, #FF, #FF, #FF, #F6, #6F, #FF, #FF, #88, #8F, #FF, #FF, #FF, #6F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #DD, #FF, #FF, #8F, #FF, #FF, #F6, #FF
            db #DD, #DF, #FF, #8F, #FF, #FF, #F6, #FF, #4D, #DD, #FF, #88, #FF, #FF, #F6, #6F
            db #44, #DD, #FF, #F8, #FF, #FF, #FF, #6F, #14, #DD, #FF, #F8, #FF, #FF, #66, #6F
            db #66, #66, #66, #66, #8F, #FD, #D4, #41, #F6, #FF, #FF, #FF, #8F, #FD, #DD, #44
            db #F6, #6F, #FF, #FF, #88, #FF, #DD, #DD, #FF, #6F, #FF, #FF, #F8, #FF, #FD, #DD
            db #FF, #6F, #FF, #FF, #F8, #FF, #FF, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F6, #FF, #FF, #FF, #F8, #88, #FF, #FF, #F6, #6F, #FF, #FF, #FF, #F8, #88
            db #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #6F, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #66, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F6, #66, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #F6, #66, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #44, #DD, #FF, #F8, #66, #66, #FF, #6F, #4D, #DD, #FF, #F8, #FF, #FF, #FF, #6F
            db #DD, #DF, #FF, #88, #FF, #FF, #F6, #6F, #DD, #FF, #FF, #8F, #FF, #FF, #F6, #FF
            db #FF, #FF, #FF, #8F, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF
            db #FF, #88, #8F, #FF, #FF, #FF, #6F, #FF, #88, #8F, #FF, #FF, #FF, #F6, #6F, #FF
            db #6F, #FF, #FF, #FF, #FF, #F6, #FF, #FF, #6F, #FF, #FF, #FF, #FF, #F6, #FF, #FF
            db #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #F6, #66, #FF, #FF, #FF
            db #6F, #FF, #F6, #66, #FF, #FF, #FF, #FF, #6F, #66, #6F, #FF, #FF, #FF, #FF, #FF
            db #66, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F6
            db #FF, #FF, #FF, #FF, #FF, #66, #66, #66, #FF, #FF, #FF, #FF, #66, #6F, #FF, #FF
            db #FF, #FF, #FF, #66, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #FF
            db #FF, #FF, #F6, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #6F, #FF, #FF, #FF, #F8, #88, #FF, #F6, #FF, #FF, #FF, #FF, #8F, #FF
            db #FF, #66, #FF, #FF, #FF, #8F, #FF, #FF, #FF, #6F, #FF, #FF, #FF, #8F, #F4, #44
            db #F6, #FF, #FF, #FF, #F8, #FF, #44, #44, #F6, #66, #66, #FF, #88, #F4, #44, #22
            db #F6, #FF, #FF, #66, #8F, #F4, #42, #21, #F6, #FF, #FF, #FF, #8F, #F4, #42, #11
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #66, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #6F, #66, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #F6, #6F, #FF, #FF, #FF, #FF
            db #FF, #6F, #FF, #F6, #6F, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #66, #FF, #FF, #FF
            db #F6, #FF, #FF, #FF, #FF, #66, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #F6, #FF, #FF
            db #88, #8F, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #88, #FF, #FF, #FF, #FF, #6F, #FF
            db #FF, #FF, #88, #FF, #FF, #FF, #66, #FF, #44, #FF, #FF, #FF, #FF, #FF, #F6, #FF
            db #44, #4F, #FF, #8F, #FF, #FF, #F6, #FF, #24, #44, #FF, #F8, #FF, #FF, #F6, #FF
            db #22, #44, #FF, #F8, #FF, #FF, #F6, #FF, #12, #44, #FF, #F8, #FF, #FF, #F6, #6F
            db #F6, #6F, #FF, #FF, #8F, #F4, #42, #21, #FF, #6F, #FF, #FF, #8F, #F4, #44, #22
            db #FF, #6F, #FF, #FF, #8F, #FF, #44, #44, #FF, #6F, #FF, #FF, #F8, #FF, #F4, #44
            db #FF, #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #FF, #FF, #FF, #88, #FF, #FF
            db #FF, #F6, #FF, #FF, #FF, #FF, #88, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #F8, #88
            db #FF, #FF, #6F, #FF, #FF, #FF, #FF, #6F, #FF, #FF, #66, #FF, #FF, #FF, #FF, #6F
            db #FF, #FF, #FF, #66, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #F6, #6F, #FF, #F6, #FF
            db #FF, #FF, #FF, #FF, #F6, #6F, #F6, #FF, #FF, #FF, #FF, #FF, #FF, #66, #F6, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #66, #66, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #22, #44, #FF, #F8, #FF, #FF, #FF, #6F, #24, #44, #FF, #F8, #66, #FF, #FF, #6F
            db #44, #4F, #FF, #88, #FF, #66, #66, #6F, #44, #FF, #FF, #8F, #FF, #FF, #FF, #6F
            db #FF, #FF, #F8, #FF, #FF, #FF, #F6, #FF, #FF, #FF, #F8, #FF, #FF, #FF, #66, #FF
            db #FF, #F8, #FF, #FF, #FF, #FF, #6F, #FF, #88, #8F, #FF, #FF, #FF, #F6, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #66, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #6F, #FF, #FF
            db #FF, #FF, #FF, #FF, #F6, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #66, #FF, #FF, #FF
            db #FF, #FF, #F6, #66, #FF, #FF, #FF, #FF, #66, #66, #66, #FF, #FF, #FF, #FF, #FF
            db #6F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            ORG #F400
            MMU 6 7, 90             ; bank 45: the rest of the patterns, then the tiles
            ORG #C000
pats:
            ORG #E000
truns:
            db 1, 5        ; tiles 1-5
            db #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44
            db #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44
            db #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44
            db #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #44, #55, #55, #55, #55
            db #FF, #FF, #FF, #FF, #FF, #F8, #8F, #FF, #FF, #8F, #F8, #FF, #F8, #F8, #8F, #8F
            db #8F, #8F, #F8, #F8, #88, #FF, #FF, #88, #8F, #FF, #FF, #F8, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #66, #66, #FF, #F6, #77, #77, #6F, #67, #71, #17, #76
            db #67, #71, #17, #76, #F6, #77, #77, #6F, #FF, #66, #66, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #99, #99, #FF, #F9, #FF, #FF, #9F, #9F, #F1, #1F, #F9
            db #9F, #F1, #1F, #F9, #F9, #FF, #FF, #9F, #FF, #99, #99, #FF, #FF, #FF, #FF, #FF
            db 9, 5        ; tiles 9-13
            db #FF, #FF, #FF, #FF, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #99, #33, #33, #33, #99, #33, #33, #33, #99, #33, #33, #33
            db #AA, #33, #33, #33, #AA, #33, #33, #33, #AA, #33, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #99, #99, #33, #33, #99, #99, #33, #33, #99, #99, #33, #33
            db #AA, #AA, #33, #33, #AA, #AA, #33, #33, #AA, #AA, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #99, #99, #99, #33, #99, #99, #99, #33, #99, #99, #99, #33
            db #AA, #AA, #AA, #33, #AA, #AA, #AA, #33, #AA, #AA, #AA, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99
            db #AA, #AA, #AA, #AA, #AA, #AA, #AA, #AA, #AA, #AA, #AA, #AA, #FF, #FF, #FF, #FF
            db 16, 9        ; tiles 16-24
            db #FF, #FF, #FF, #FF, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33
            db #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #83, #33, #33, #33, #83, #33, #33, #33, #83, #33, #33, #33
            db #73, #33, #33, #33, #73, #33, #33, #33, #73, #33, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #88, #33, #33, #33, #88, #33, #33, #33, #88, #33, #33, #33
            db #77, #33, #33, #33, #77, #33, #33, #33, #77, #33, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #88, #83, #33, #33, #88, #83, #33, #33, #88, #83, #33, #33
            db #77, #73, #33, #33, #77, #73, #33, #33, #77, #73, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #88, #88, #33, #33, #88, #88, #33, #33, #88, #88, #33, #33
            db #77, #77, #33, #33, #77, #77, #33, #33, #77, #77, #33, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #88, #88, #83, #33, #88, #88, #83, #33, #88, #88, #83, #33
            db #77, #77, #73, #33, #77, #77, #73, #33, #77, #77, #73, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #88, #88, #88, #33, #88, #88, #88, #33, #88, #88, #88, #33
            db #77, #77, #77, #33, #77, #77, #77, #33, #77, #77, #77, #33, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #88, #88, #88, #83, #88, #88, #88, #83, #88, #88, #88, #83
            db #77, #77, #77, #73, #77, #77, #77, #73, #77, #77, #77, #73, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88, #88
            db #77, #77, #77, #77, #77, #77, #77, #77, #77, #77, #77, #77, #FF, #FF, #FF, #FF
            db 33, 94        ; tiles 33-126
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
            db #FF, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #F1, #1F, #FF, #FF, #FF, #00, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #FF, #00, #11, #FF
            db #F1, #11, #11, #0F, #11, #00, #11, #0F, #F1, #11, #F1, #1F, #FF, #00, #0F, #00
            db #11, #1F, #FF, #FF, #F1, #10, #FF, #FF, #F1, #10, #FF, #FF, #F1, #11, #11, #FF
            db #F1, #10, #01, #1F, #F1, #10, #F1, #10, #11, #01, #11, #00, #F0, #0F, #00, #0F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #11, #00, #11, #FF
            db #11, #0F, #F0, #0F, #11, #0F, #11, #FF, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #FF, #F1, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #11, #0F, #F1, #11, #11, #0F
            db #11, #00, #11, #0F, #11, #0F, #11, #0F, #F1, #11, #F1, #1F, #FF, #00, #0F, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #11, #00, #11, #FF
            db #11, #11, #11, #0F, #11, #00, #00, #0F, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #FF, #11, #1F, #FF, #F1, #10, #11, #FF, #F1, #10, #F0, #0F, #11, #11, #FF, #FF
            db #F1, #10, #0F, #FF, #F1, #10, #FF, #FF, #11, #11, #FF, #FF, #F0, #00, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #F1, #1F, #11, #00, #11, #00
            db #11, #0F, #11, #0F, #F1, #11, #11, #0F, #FF, #00, #11, #0F, #11, #11, #10, #0F
            db #11, #1F, #FF, #FF, #F1, #10, #FF, #FF, #F1, #10, #11, #FF, #F1, #11, #F1, #1F
            db #F1, #10, #01, #10, #F1, #10, #F1, #10, #11, #10, #F1, #10, #F0, #00, #FF, #00
            db #FF, #11, #FF, #FF, #FF, #F0, #0F, #FF, #F1, #11, #FF, #FF, #FF, #11, #0F, #FF
            db #FF, #11, #0F, #FF, #FF, #11, #0F, #FF, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #FF, #FF, #11, #FF, #FF, #FF, #F0, #0F, #FF, #FF, #11, #FF, #FF, #FF, #11, #0F
            db #FF, #FF, #11, #0F, #11, #FF, #11, #0F, #11, #0F, #11, #0F, #F1, #11, #10, #0F
            db #11, #1F, #FF, #FF, #F1, #10, #FF, #FF, #F1, #10, #F1, #1F, #F1, #10, #11, #00
            db #F1, #11, #10, #0F, #F1, #10, #11, #FF, #11, #10, #F1, #1F, #F0, #00, #FF, #00
            db #F1, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #11, #0F, #FF, #FF, #11, #0F, #FF
            db #FF, #11, #0F, #FF, #FF, #11, #0F, #FF, #F1, #11, #1F, #FF, #FF, #00, #00, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #11, #11, #1F
            db #11, #11, #11, #10, #11, #01, #01, #10, #11, #0F, #01, #10, #F0, #0F, #FF, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #1F, #FF, #11, #00, #11, #FF
            db #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #11, #0F, #F0, #0F, #F0, #0F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #1F, #FF, #11, #00, #11, #FF
            db #11, #0F, #11, #0F, #11, #0F, #11, #0F, #F1, #11, #10, #0F, #FF, #00, #00, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #F1, #11, #FF, #F1, #1F, #01, #1F
            db #F1, #10, #F1, #10, #F1, #11, #11, #00, #F1, #10, #00, #0F, #11, #11, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #F1, #1F, #11, #00, #11, #00
            db #11, #0F, #11, #0F, #F1, #11, #11, #0F, #FF, #00, #11, #0F, #FF, #F1, #11, #1F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #F1, #11, #FF, #F1, #11, #01, #1F
            db #F1, #10, #01, #10, #F1, #10, #FF, #00, #11, #11, #FF, #FF, #F0, #00, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F1, #11, #11, #FF, #11, #00, #00, #0F
            db #F1, #11, #1F, #FF, #FF, #00, #11, #FF, #11, #11, #10, #0F, #F0, #00, #00, #FF
            db #FF, #F1, #FF, #FF, #FF, #11, #0F, #FF, #F1, #11, #11, #FF, #FF, #11, #00, #0F
            db #FF, #11, #0F, #FF, #FF, #11, #01, #FF, #FF, #F1, #1F, #0F, #FF, #FF, #00, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #0F, #11, #0F
            db #11, #0F, #11, #0F, #11, #0F, #11, #0F, #F1, #11, #F1, #1F, #FF, #00, #0F, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #0F, #11, #0F
            db #11, #0F, #11, #0F, #F1, #11, #10, #0F, #FF, #11, #00, #FF, #FF, #F0, #0F, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #F1, #1F, #11, #01, #F1, #10
            db #11, #11, #11, #10, #11, #11, #11, #10, #F1, #10, #11, #00, #FF, #00, #F0, #0F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #F1, #1F, #F1, #1F, #11, #00
            db #FF, #11, #10, #0F, #F1, #10, #11, #FF, #11, #00, #F1, #1F, #F0, #0F, #FF, #00
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #FF, #11, #FF, #11, #0F, #11, #0F
            db #11, #0F, #11, #0F, #F1, #11, #11, #0F, #FF, #00, #11, #0F, #11, #11, #10, #0F
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #11, #11, #11, #FF, #10, #01, #10, #0F
            db #F0, #11, #00, #FF, #F1, #10, #01, #FF, #11, #11, #11, #0F, #F0, #00, #00, #0F
            db #FF, #F1, #11, #FF, #FF, #11, #00, #0F, #FF, #11, #0F, #FF, #11, #10, #0F, #FF
            db #F0, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #F1, #11, #FF, #FF, #FF, #00, #0F
            db #FF, #F1, #1F, #FF, #FF, #F1, #10, #FF, #FF, #F1, #10, #FF, #FF, #FF, #00, #FF
            db #FF, #F1, #1F, #FF, #FF, #F1, #10, #FF, #FF, #F1, #10, #FF, #FF, #FF, #00, #FF
            db #11, #1F, #FF, #FF, #F0, #11, #FF, #FF, #FF, #11, #0F, #FF, #FF, #F1, #11, #FF
            db #FF, #11, #00, #0F, #FF, #11, #0F, #FF, #11, #10, #0F, #FF, #F0, #00, #FF, #FF
            db #F1, #11, #F1, #1F, #11, #01, #11, #00, #F0, #0F, #00, #0F, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db 0, 0
            MMU 6 7, 0
            ORG ld_end
#endasm
End Sub
