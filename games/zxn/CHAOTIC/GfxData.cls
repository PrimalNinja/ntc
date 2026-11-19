' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit
Option SaveNex "CHAOTIC.DAT", 45, 46      ' the patterns in page 45, the tiles in page 46 (a page is the Next's 16K bank of the same number)

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
            ld a, 90               ; page 45 (its first half) at #E000: 42 patterns
            call ld_pg
            ld hl, #E000
            ld de, 5376
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
#endasm
End Sub
