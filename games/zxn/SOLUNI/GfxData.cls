' GfxData - the game's graphics, made by gfxtool.js from gfx/*.png and layout.txt.
' Don't edit: change the PNGs and run  node gfxtool.js build
' Load: the tilemap palette, the sprite palettes, the tile definitions (bank 5 + #0000, seen at
' #C000: Tiles.Init points the tilemap there) and the sprite patterns (4 bit, from pattern 0).
Option Explicit

Public Const S_CROSS = 0
Public Const S_CROSS_N = 1
Public Const S_LOCK = 1
Public Const S_LOCK_N = 1
Public Const S_ICON = 2
Public Const S_ICON_N = 1
Public Const T_BLACK = 1
Public Const T_PANEL = 8
Public Const T_BARG = 16
Public Const T_BARG_N = 9
Public Const T_BARO = 136
Public Const T_BARO_N = 9
Public Const T_LOGO = 128
Public Const T_LOGO_N = 3
Public Const SpritePatterns = 3
Public Const SpritePalettes = 1

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
            ld e, 16                ; 1 x 16 (0 = 256)
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
            ld de, 384
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
            db #00, #FF, #09, #15, #FC, #E4, #04, #2B, #01, #F0, #93, #25, #1E, #4A, #7B, #E3
spal:
            db #00, #FF, #1E, #11, #E4, #FC, #2F, #9B, #F0, #4A, #B7, #CB, #6F, #25, #93, #E3
truns:
            db 1, 8        ; tiles 1-8
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00, #00
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #22, #22, #22, #22
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #26, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #33, #33, #33, #33
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #36, #66, #66, #66
            db #CC, #CC, #CC, #CC, #22, #22, #22, #22, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66, #66
            db #66, #66, #66, #66, #66, #66, #66, #66, #22, #22, #22, #22, #CC, #CC, #CC, #CC
            db #C6, #66, #66, #66, #C6, #66, #66, #66, #C6, #66, #66, #66, #C6, #66, #66, #66
            db #C6, #66, #66, #66, #C6, #66, #66, #66, #C6, #66, #66, #66, #C6, #66, #66, #66
            db #66, #66, #66, #6C, #66, #66, #66, #6C, #66, #66, #66, #6C, #66, #66, #66, #6C
            db #66, #66, #66, #6C, #66, #66, #66, #6C, #66, #66, #66, #6C, #66, #66, #66, #6C
            db #DD, #DD, #DD, #DD, #DB, #BB, #BB, #BB, #DB, #BB, #BB, #BB, #DB, #BB, #BB, #BB
            db #DB, #BB, #BB, #BB, #DB, #BB, #BB, #BB, #DB, #BB, #BB, #BB, #DB, #BB, #BB, #BB
            db 16, 9        ; tiles 16-24
            db #DD, #DD, #DD, #DD, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB
            db #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CB, #BB, #BB, #BB, #CB, #BB, #BB, #BB, #CB, #BB, #BB, #BB
            db #CB, #BB, #BB, #BB, #CB, #BB, #BB, #BB, #CB, #BB, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CC, #BB, #BB, #BB, #CC, #BB, #BB, #BB, #CC, #BB, #BB, #BB
            db #CC, #BB, #BB, #BB, #CC, #BB, #BB, #BB, #CC, #BB, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CC, #CB, #BB, #BB, #CC, #CB, #BB, #BB, #CC, #CB, #BB, #BB
            db #CC, #CB, #BB, #BB, #CC, #CB, #BB, #BB, #CC, #CB, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CC, #CC, #BB, #BB, #CC, #CC, #BB, #BB, #CC, #CC, #BB, #BB
            db #CC, #CC, #BB, #BB, #CC, #CC, #BB, #BB, #CC, #CC, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CC, #CC, #CB, #BB, #CC, #CC, #CB, #BB, #CC, #CC, #CB, #BB
            db #CC, #CC, #CB, #BB, #CC, #CC, #CB, #BB, #CC, #CC, #CB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CC, #CC, #CC, #BB, #CC, #CC, #CC, #BB, #CC, #CC, #CC, #BB
            db #CC, #CC, #CC, #BB, #CC, #CC, #CC, #BB, #CC, #CC, #CC, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CC, #CC, #CC, #CB, #CC, #CC, #CC, #CB, #CC, #CC, #CC, #CB
            db #CC, #CC, #CC, #CB, #CC, #CC, #CC, #CB, #CC, #CC, #CC, #CB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC
            db #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #CC, #DD, #DD, #DD, #DD
            db 33, 94        ; tiles 33-126
            db #FF, #FE, #EF, #FF, #FF, #EE, #EE, #FF, #FF, #EE, #EE, #DF, #FF, #FE, #ED, #DF
            db #FF, #FE, #ED, #FF, #FF, #FF, #DD, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #DD, #FF
            db #FE, #EF, #EE, #FF, #FE, #ED, #EE, #DF, #FF, #DD, #FD, #DF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FE, #EF, #EE, #FF, #FE, #ED, #EE, #DF, #EE, #EE, #EE, #EF, #FE, #ED, #EE, #DD
            db #EE, #EE, #EE, #EF, #FE, #ED, #EE, #DD, #FE, #ED, #EE, #DF, #FF, #DD, #FD, #DF
            db #FF, #EE, #FF, #FF, #FE, #EE, #EE, #FF, #EE, #DD, #DD, #DF, #FE, #EE, #EF, #FF
            db #FF, #DD, #EE, #FF, #EE, #EE, #ED, #DF, #FD, #EE, #DD, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #EE, #FF, #FE, #EF, #EE, #DF, #EE, #DD, #FD, #DE, #ED, #DF
            db #FF, #EE, #DD, #FF, #FE, #ED, #DE, #EF, #EE, #DD, #FE, #ED, #FD, #DF, #FF, #DD
            db #FF, #EE, #EF, #FF, #FE, #ED, #EE, #FF, #FF, #EE, #ED, #DF, #FE, #EE, #DE, #EF
            db #EE, #DE, #EE, #DD, #EE, #DF, #EE, #DF, #FE, #EE, #FE, #EF, #FF, #DD, #DF, #DD
            db #FE, #EF, #FF, #FF, #FE, #ED, #FF, #FF, #EE, #DD, #FF, #FF, #FD, #DF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FE, #EF, #FF, #FF, #EE, #DD, #FF, #FE, #ED, #DF, #FF, #FE, #ED, #FF, #FF
            db #FE, #ED, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #DD, #FF
            db #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FE, #ED, #FF
            db #FF, #FE, #ED, #FF, #FF, #EE, #DD, #FF, #FE, #ED, #DF, #FF, #FF, #DD, #FF, #FF
            db #FF, #FF, #FF, #FF, #FE, #EF, #FE, #EF, #FF, #EE, #EE, #DD, #EE, #EE, #EE, #EE
            db #FD, #EE, #EE, #DD, #FE, #ED, #DE, #EF, #FF, #DD, #FF, #DD, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #EE, #EE, #EE, #FF
            db #FD, #EE, #DD, #DF, #FF, #EE, #DF, #FF, #FF, #FD, #DF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FE, #ED, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF
            db #FD, #DD, #DD, #DF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FE, #EF, #FF, #FF, #EE, #DD, #FF, #FE, #ED, #DF, #FF, #EE, #DD, #FF
            db #FE, #ED, #DF, #FF, #EE, #DD, #FF, #FF, #ED, #DF, #FF, #FF, #FD, #FF, #FF, #FF
            db #FE, #EE, #EE, #FF, #EE, #DD, #DE, #EF, #EE, #DF, #EE, #ED, #EE, #DE, #EE, #ED
            db #EE, #EE, #DE, #ED, #EE, #ED, #DE, #ED, #FE, #EE, #EE, #DD, #FF, #DD, #DD, #DF
            db #FF, #EE, #FF, #FF, #FE, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF
            db #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #EE, #EE, #EE, #FF, #FD, #DD, #DD, #DF
            db #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #FD, #DF, #EE, #DF, #FF, #EE, #ED, #DF
            db #FE, #ED, #DD, #FF, #EE, #DD, #EE, #FF, #EE, #EE, #EE, #DF, #FD, #DD, #DD, #DF
            db #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #FD, #DF, #EE, #DF, #FF, #EE, #ED, #DF
            db #FF, #FD, #EE, #FF, #EE, #FF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #FF, #FE, #EE, #FF, #FF, #EE, #EE, #DF, #FE, #ED, #EE, #DF, #EE, #DD, #EE, #DF
            db #EE, #EE, #EE, #EF, #FD, #DD, #EE, #DD, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #DD
            db #EE, #EE, #EE, #FF, #EE, #DD, #DD, #DF, #EE, #EE, #EF, #FF, #FD, #DD, #EE, #FF
            db #FF, #FF, #EE, #DF, #EE, #FF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #FF, #EE, #EF, #FF, #FE, #ED, #DD, #FF, #EE, #DD, #FF, #FF, #EE, #EE, #EF, #FF
            db #EE, #DD, #EE, #FF, #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #EE, #EE, #EE, #FF, #EE, #DD, #EE, #DF, #FD, #DF, #EE, #DF, #FF, #FE, #ED, #DF
            db #FF, #EE, #DD, #FF, #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #FF, #FD, #DF, #FF
            db #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF
            db #EE, #DD, #EE, #FF, #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #EE, #DF, #EE, #DF, #FE, #EE, #EE, #DF
            db #FF, #DD, #EE, #DF, #FF, #FE, #ED, #DF, #FE, #EE, #DD, #FF, #FF, #DD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FE, #ED, #DF, #FF
            db #FF, #FE, #EF, #FF, #FF, #EE, #DD, #FF, #FE, #ED, #DF, #FF, #EE, #DD, #FF, #FF
            db #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF, #FD, #DD, #DD, #DF
            db #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF, #FD, #DD, #DD, #DF, #FF, #FF, #FF, #FF
            db #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #EE, #FF
            db #FF, #FE, #ED, #DF, #FF, #EE, #DD, #FF, #FE, #ED, #DF, #FF, #FF, #DD, #FF, #FF
            db #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #FD, #DF, #EE, #DF, #FF, #FE, #ED, #DF
            db #FF, #EE, #DD, #FF, #FF, #FD, #DF, #FF, #FF, #EE, #FF, #FF, #FF, #FD, #DF, #FF
            db #FE, #EE, #EE, #FF, #EE, #DD, #DE, #EF, #EE, #DE, #EE, #ED, #EE, #DE, #EE, #ED
            db #EE, #DE, #EE, #ED, #EE, #DF, #DD, #DD, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #FF, #EE, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #EE, #DF, #EE, #DF
            db #EE, #EE, #EE, #DF, #EE, #DD, #EE, #DF, #EE, #DF, #EE, #DF, #FD, #DF, #FD, #DF
            db #EE, #EE, #EE, #FF, #FE, #ED, #DE, #EF, #FE, #ED, #FE, #ED, #FE, #EE, #EE, #DD
            db #FE, #ED, #DE, #EF, #FE, #ED, #FE, #ED, #EE, #EE, #EE, #DD, #FD, #DD, #DD, #DF
            db #FF, #EE, #EE, #FF, #FE, #ED, #DE, #EF, #EE, #DD, #FF, #DD, #EE, #DF, #FF, #FF
            db #EE, #DF, #FF, #FF, #FE, #EF, #FE, #EF, #FF, #EE, #EE, #DD, #FF, #FD, #DD, #DF
            db #EE, #EE, #EF, #FF, #FE, #ED, #EE, #FF, #FE, #ED, #FE, #EF, #FE, #ED, #FE, #ED
            db #FE, #ED, #FE, #ED, #FE, #ED, #EE, #DD, #EE, #EE, #ED, #DF, #FD, #DD, #DD, #FF
            db #EE, #EE, #EE, #EF, #FE, #ED, #DD, #ED, #FE, #ED, #EF, #FD, #FE, #EE, #ED, #FF
            db #FE, #ED, #ED, #FF, #FE, #ED, #FD, #EF, #EE, #EE, #EE, #ED, #FD, #DD, #DD, #DD
            db #EE, #EE, #EE, #EF, #FE, #ED, #DD, #ED, #FE, #ED, #EF, #FD, #FE, #EE, #ED, #FF
            db #FE, #ED, #ED, #FF, #FE, #ED, #FD, #FF, #EE, #EE, #FF, #FF, #FD, #DD, #DF, #FF
            db #FF, #EE, #EE, #FF, #FE, #ED, #DE, #EF, #EE, #DD, #FF, #DD, #EE, #DF, #FF, #FF
            db #EE, #DF, #EE, #EF, #FE, #EF, #FE, #ED, #FF, #EE, #EE, #ED, #FF, #FD, #DD, #DD
            db #EE, #FF, #EE, #FF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #EE, #EE, #DF
            db #EE, #DD, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #FD, #DF, #FD, #DF
            db #FE, #EE, #EF, #FF, #FF, #EE, #DD, #FF, #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF
            db #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #FF, #FE, #EE, #EF, #FF, #FF, #EE, #DD, #FF, #FF, #EE, #DF, #FF, #FF, #EE, #DF
            db #EE, #FF, #EE, #DF, #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #EE, #EF, #FE, #EF, #FE, #ED, #FE, #ED, #FE, #ED, #EE, #DD, #FE, #EE, #ED, #DF
            db #FE, #ED, #EE, #FF, #FE, #ED, #FE, #EF, #EE, #ED, #FE, #ED, #FD, #DD, #FF, #DD
            db #EE, #EE, #FF, #FF, #FE, #ED, #DF, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FF, #FF
            db #FE, #ED, #FF, #EF, #FE, #ED, #FE, #ED, #EE, #EE, #EE, #ED, #FD, #DD, #DD, #DD
            db #EE, #FF, #FE, #EF, #EE, #EF, #EE, #ED, #EE, #EE, #EE, #ED, #EE, #EE, #EE, #ED
            db #EE, #DE, #DE, #ED, #EE, #DF, #DE, #ED, #EE, #DF, #FE, #ED, #FD, #DF, #FF, #DD
            db #EE, #FF, #FE, #EF, #EE, #EF, #FE, #ED, #EE, #EE, #FE, #ED, #EE, #DE, #EE, #ED
            db #EE, #DF, #EE, #ED, #EE, #DF, #FE, #ED, #EE, #DF, #FE, #ED, #FD, #DF, #FF, #DD
            db #FF, #EE, #EF, #FF, #FE, #ED, #EE, #FF, #EE, #DD, #FE, #EF, #EE, #DF, #FE, #ED
            db #EE, #DF, #FE, #ED, #FE, #EF, #EE, #DD, #FF, #EE, #ED, #DF, #FF, #FD, #DD, #FF
            db #EE, #EE, #EE, #FF, #FE, #ED, #DE, #EF, #FE, #ED, #FE, #ED, #FE, #EE, #EE, #DD
            db #FE, #ED, #DD, #DF, #FE, #ED, #FF, #FF, #EE, #EE, #FF, #FF, #FD, #DD, #DF, #FF
            db #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF
            db #EE, #DE, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DE, #EE, #FF, #FF, #FF, #DD, #DF
            db #EE, #EE, #EE, #FF, #FE, #ED, #DE, #EF, #FE, #ED, #FE, #ED, #FE, #EE, #EE, #DD
            db #FE, #ED, #EE, #DF, #FE, #ED, #FE, #EF, #EE, #ED, #FE, #ED, #FD, #DD, #FF, #DD
            db #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF, #EE, #EF, #FD, #DF, #FE, #EE, #FF, #FF
            db #FF, #DE, #EE, #FF, #EE, #FF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #EE, #EE, #EE, #FF, #ED, #EE, #DE, #DF, #FD, #EE, #DF, #DF, #FF, #EE, #DF, #FF
            db #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #EE, #FF, #EE, #FF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF
            db #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #EE, #EE, #DF, #FD, #DD, #DD, #DF
            db #EE, #FF, #EE, #FF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF
            db #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #EE, #DD, #FF, #FF, #FD, #DF, #FF
            db #EE, #FF, #FE, #EF, #EE, #DF, #FE, #ED, #EE, #DF, #FE, #ED, #EE, #DE, #FE, #ED
            db #EE, #EE, #EE, #ED, #EE, #ED, #EE, #ED, #EE, #DD, #FE, #ED, #FD, #DF, #FF, #DD
            db #EE, #FF, #FE, #EF, #EE, #DF, #FE, #ED, #FE, #EF, #EE, #DD, #FF, #EE, #ED, #DF
            db #FF, #EE, #ED, #FF, #FE, #ED, #EE, #FF, #EE, #DD, #FE, #EF, #FD, #DF, #FF, #DD
            db #EE, #FF, #EE, #FF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF
            db #FF, #EE, #DD, #FF, #FF, #EE, #DF, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #EE, #EE, #EE, #EF, #EE, #DD, #DE, #ED, #ED, #DF, #EE, #DD, #FD, #FE, #ED, #DF
            db #FF, #EE, #DD, #EF, #FE, #ED, #DE, #ED, #EE, #EE, #EE, #ED, #FD, #DD, #DD, #DD
            db #FE, #EE, #EF, #FF, #FE, #ED, #DD, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FF, #FF
            db #FE, #ED, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF
            db #FF, #FF, #EE, #FF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #ED, #FF, #FF, #FF, #FD
            db #FE, #EE, #EF, #FF, #FF, #DE, #ED, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FF
            db #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FF, #FE, #EE, #ED, #FF, #FF, #DD, #DD, #FF
            db #FF, #FE, #FF, #FF, #FF, #EE, #EF, #FF, #FE, #ED, #EE, #FF, #EE, #DD, #FE, #EF
            db #FD, #DF, #FF, #DD, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #EE
            db #FF, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #FE, #EF, #FF, #FF, #FF, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #EE, #FF
            db #FE, #EE, #EE, #DF, #EE, #DD, #EE, #DF, #FE, #EE, #FE, #EF, #FF, #DD, #DF, #DD
            db #EE, #EF, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #EE, #EE, #FF
            db #FE, #ED, #DE, #EF, #FE, #ED, #FE, #ED, #EE, #DE, #EE, #DD, #FD, #DF, #DD, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF
            db #EE, #DF, #FD, #DF, #EE, #DF, #EE, #FF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #FF, #FE, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FE, #EE, #EE, #DF
            db #EE, #DD, #EE, #DF, #EE, #DF, #EE, #DF, #FE, #EE, #FE, #EF, #FF, #DD, #DF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF
            db #EE, #EE, #EE, #DF, #EE, #DD, #DD, #DF, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #FF, #EE, #EF, #FF, #FE, #ED, #EE, #FF, #FE, #ED, #FD, #DF, #EE, #EE, #FF, #FF
            db #FE, #ED, #DF, #FF, #FE, #ED, #FF, #FF, #EE, #EE, #FF, #FF, #FD, #DD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #FE, #EF, #EE, #DD, #EE, #DD
            db #EE, #DF, #EE, #DF, #FE, #EE, #EE, #DF, #FF, #DD, #EE, #DF, #EE, #EE, #ED, #DF
            db #EE, #EF, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #EE, #FF, #FE, #EE, #FE, #EF
            db #FE, #ED, #DE, #ED, #FE, #ED, #FE, #ED, #EE, #ED, #FE, #ED, #FD, #DD, #FF, #DD
            db #FF, #EE, #FF, #FF, #FF, #FD, #DF, #FF, #FE, #EE, #FF, #FF, #FF, #EE, #DF, #FF
            db #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #FF, #FF, #EE, #FF, #FF, #FF, #FD, #DF, #FF, #FF, #EE, #FF, #FF, #FF, #EE, #DF
            db #FF, #FF, #EE, #DF, #EE, #FF, #EE, #DF, #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF
            db #EE, #EF, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FE, #EF, #FE, #ED, #EE, #DD
            db #FE, #EE, #ED, #DF, #FE, #ED, #EE, #FF, #EE, #ED, #FE, #EF, #FD, #DD, #FF, #DD
            db #FE, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF
            db #FF, #EE, #DF, #FF, #FF, #EE, #DF, #FF, #FE, #EE, #EF, #FF, #FF, #DD, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #EE, #EE, #EF
            db #EE, #EE, #EE, #ED, #EE, #DE, #DE, #ED, #EE, #DF, #DE, #ED, #FD, #DF, #FF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EF, #FF, #EE, #DD, #EE, #FF
            db #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #FD, #DF, #FD, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EF, #FF, #EE, #DD, #EE, #FF
            db #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #DD, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FE, #EE, #FF, #FE, #EF, #DE, #EF
            db #FE, #ED, #FE, #ED, #FE, #EE, #EE, #DD, #FE, #ED, #DD, #DF, #EE, #EE, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #FE, #EF, #EE, #DD, #EE, #DD
            db #EE, #DF, #EE, #DF, #FE, #EE, #EE, #DF, #FF, #DD, #EE, #DF, #FF, #FE, #EE, #EF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FE, #EE, #FF, #FE, #EE, #DE, #EF
            db #FE, #ED, #DE, #ED, #FE, #ED, #FF, #DD, #EE, #EE, #FF, #FF, #FD, #DD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FE, #EE, #EE, #FF, #EE, #DD, #DD, #DF
            db #FE, #EE, #EF, #FF, #FF, #DD, #EE, #FF, #EE, #EE, #ED, #DF, #FD, #DD, #DD, #FF
            db #FF, #FE, #FF, #FF, #FF, #EE, #DF, #FF, #FE, #EE, #EE, #FF, #FF, #EE, #DD, #DF
            db #FF, #EE, #DF, #FF, #FF, #EE, #DE, #FF, #FF, #FE, #EF, #DF, #FF, #FF, #DD, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #DF, #EE, #DF
            db #EE, #DF, #EE, #DF, #EE, #DF, #EE, #DF, #FE, #EE, #FE, #EF, #FF, #DD, #DF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #DF, #EE, #DF
            db #EE, #DF, #EE, #DF, #FE, #EE, #ED, #DF, #FF, #EE, #DD, #FF, #FF, #FD, #DF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FE, #EF, #EE, #DE, #FE, #ED
            db #EE, #EE, #EE, #ED, #EE, #EE, #EE, #ED, #FE, #ED, #EE, #DD, #FF, #DD, #FD, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #FE, #EF, #FE, #EF, #EE, #DD
            db #FF, #EE, #ED, #DF, #FE, #ED, #EE, #FF, #EE, #DD, #FE, #EF, #FD, #DF, #FF, #DD
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #FF, #EE, #FF, #EE, #DF, #EE, #DF
            db #EE, #DF, #EE, #DF, #FE, #EE, #EE, #DF, #FF, #DD, #EE, #DF, #EE, #EE, #ED, #DF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #EE, #EE, #EE, #FF, #ED, #DE, #ED, #DF
            db #FD, #EE, #DD, #FF, #FE, #ED, #DE, #FF, #EE, #EE, #EE, #DF, #FD, #DD, #DD, #DF
            db #FF, #FE, #EE, #FF, #FF, #EE, #DD, #DF, #FF, #EE, #DF, #FF, #EE, #ED, #DF, #FF
            db #FD, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #FE, #EE, #FF, #FF, #FF, #DD, #DF
            db #FF, #FE, #EF, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FF, #FF, #FF, #DD, #FF
            db #FF, #FE, #EF, #FF, #FF, #FE, #ED, #FF, #FF, #FE, #ED, #FF, #FF, #FF, #DD, #FF
            db #EE, #EF, #FF, #FF, #FD, #EE, #FF, #FF, #FF, #EE, #DF, #FF, #FF, #FE, #EE, #FF
            db #FF, #EE, #DD, #DF, #FF, #EE, #DF, #FF, #EE, #ED, #DF, #FF, #FD, #DD, #FF, #FF
            db #FE, #EE, #FE, #EF, #EE, #DE, #EE, #DD, #FD, #DF, #DD, #DF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db 128, 3        ; tiles 128-130
            db #11, #11, #11, #1F, #14, #44, #44, #49, #14, #44, #44, #49, #14, #44, #44, #49
            db #14, #44, #44, #49, #14, #44, #44, #49, #14, #44, #44, #49, #F9, #99, #99, #99
            db #11, #11, #11, #1F, #19, #99, #99, #95, #19, #99, #99, #95, #19, #99, #99, #95
            db #19, #99, #99, #95, #19, #99, #99, #95, #19, #99, #99, #95, #F5, #55, #55, #55
            db #11, #11, #11, #1F, #13, #33, #33, #32, #13, #33, #33, #32, #13, #33, #33, #32
            db #13, #33, #33, #32, #13, #33, #33, #32, #13, #33, #33, #32, #F2, #22, #22, #22
            db 136, 9        ; tiles 136-144
            db #DD, #DD, #DD, #DD, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB
            db #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #9B, #BB, #BB, #BB, #9B, #BB, #BB, #BB, #9B, #BB, #BB, #BB
            db #9B, #BB, #BB, #BB, #9B, #BB, #BB, #BB, #9B, #BB, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #99, #BB, #BB, #BB, #99, #BB, #BB, #BB, #99, #BB, #BB, #BB
            db #99, #BB, #BB, #BB, #99, #BB, #BB, #BB, #99, #BB, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #99, #9B, #BB, #BB, #99, #9B, #BB, #BB, #99, #9B, #BB, #BB
            db #99, #9B, #BB, #BB, #99, #9B, #BB, #BB, #99, #9B, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #99, #99, #BB, #BB, #99, #99, #BB, #BB, #99, #99, #BB, #BB
            db #99, #99, #BB, #BB, #99, #99, #BB, #BB, #99, #99, #BB, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #99, #99, #9B, #BB, #99, #99, #9B, #BB, #99, #99, #9B, #BB
            db #99, #99, #9B, #BB, #99, #99, #9B, #BB, #99, #99, #9B, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #99, #99, #99, #BB, #99, #99, #99, #BB, #99, #99, #99, #BB
            db #99, #99, #99, #BB, #99, #99, #99, #BB, #99, #99, #99, #BB, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #99, #99, #99, #9B, #99, #99, #99, #9B, #99, #99, #99, #9B
            db #99, #99, #99, #9B, #99, #99, #99, #9B, #99, #99, #99, #9B, #DD, #DD, #DD, #DD
            db #DD, #DD, #DD, #DD, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99
            db #99, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99, #99, #DD, #DD, #DD, #DD
            db 0, 0
pats:
            db #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF
            db #FF, #FF, #3F, #F2, #FF, #3F, #FF, #FF, #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #22, #22, #22, #F1, #FF, #22, #22, #22
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #3F, #F2, #FF, #3F, #FF, #FF, #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F2, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #F5, #5F, #F4, #FF, #55, #FF, #FF
            db #FF, #F5, #FF, #F4, #FF, #F5, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #44, #44, #4F, #FF, #FF, #F4, #44, #44
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
            db #FF, #F5, #FF, #FF, #FF, #F5, #FF, #FF, #FF, #F5, #5F, #F4, #FF, #55, #FF, #FF
            db #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #F4, #FF, #FF, #FF, #FF
            db #FF, #FF, #FF, #FF, #FF, #5F, #FF, #FF, #FF, #FF, #FF, #FF, #F5, #5F, #FF, #FF
            db #FF, #FF, #FF, #FF, #55, #FF, #FF, #FF, #FF, #FB, #FF, #F5, #5F, #FF, #FF, #FF
            db #FF, #BB, #BF, #11, #11, #FF, #FF, #FF, #FB, #BB, #F1, #11, #11, #1F, #FF, #FF
            db #BB, #BF, #11, #14, #11, #11, #FF, #FF, #BB, #F1, #11, #11, #11, #11, #11, #FF
            db #BF, #11, #11, #11, #11, #11, #11, #1F, #FF, #11, #11, #11, #FF, #F1, #11, #1F
            db #F1, #11, #11, #1F, #FF, #FF, #11, #FF, #F1, #11, #11, #FF, #FF, #FF, #FF, #FF
            db #11, #11, #1F, #FF, #FF, #FF, #FF, #FF, #11, #11, #FF, #FF, #FF, #FF, #FF, #FF
            db #11, #1F, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF
ld_end:
#endasm
End Sub
