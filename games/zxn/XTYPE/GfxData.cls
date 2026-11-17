' GfxData - X-TYPE's sprites and tiles (made by tools/art.py with tools/nxkit.py: don't edit).
' 109 sprite patterns (4 bit, 16 x 16), 8 sprite palette rows, 112 tiles (4 bit, 8 x 8: the font is
' tiles 32-126) and the tilemap's palette rows, in banks 28 (the patterns) and 29 (the tiles at #0000,
' the sprite palette at #2000, the tilemap palette at #2200) of the NEX file (INCBIN XTYPE.DAT).
' Load: the patterns to the sprite RAM, both palettes, the tiles to bank 5 + #0000 (#C000, where
' Tiles.Init points the tilemap's tiles). S_NAME is a sprite's first pattern, P_NAME its palette
' offset (for Spr.Put's flags), T_NAME a tile.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Public Const S_SHIP = 0
Public Const S_SHIP_N = 3
Public Const S_SHIP_W = 2
Public Const S_SHIP_H = 1
Public Const P_SHIP = 0
Public Const S_FLAME = 6
Public Const S_FLAME_N = 2
Public Const P_FLAME = 0
Public Const S_ORB = 8
Public Const S_ORB_N = 4
Public Const P_ORB = 0
Public Const S_SHOT = 12
Public Const P_SHOT = 0
Public Const S_SHOTD = 13
Public Const P_SHOTD = 0
Public Const S_SHOTO = 14
Public Const P_SHOTO = 0
Public Const S_WAVEH = 15
Public Const P_WAVEH = 0
Public Const S_WAVEB = 16
Public Const P_WAVEB = 0
Public Const S_GLOW = 17
Public Const S_GLOW_N = 4
Public Const P_GLOW = 0
Public Const S_EBUL = 21
Public Const S_EBUL_N = 2
Public Const P_EBUL = 64
Public Const S_BOOM = 23
Public Const S_BOOM_N = 4
Public Const P_BOOM = 64
Public Const S_SPARK = 27
Public Const S_SPARK_N = 2
Public Const P_SPARK = 64
Public Const S_PUS = 29
Public Const S_PUS_N = 2
Public Const P_PUS = 64
Public Const S_PUP = 31
Public Const S_PUP_N = 2
Public Const P_PUP = 64
Public Const S_PUO = 33
Public Const S_PUO_N = 2
Public Const P_PUO = 64
Public Const S_DRONE = 35
Public Const S_DRONE_N = 2
Public Const P_DRONE = 16
Public Const S_DART = 37
Public Const P_DART = 32
Public Const S_SWOOP = 38
Public Const S_SWOOP_N = 2
Public Const P_SWOOP = 48
Public Const S_CRAWL = 40
Public Const S_CRAWL_N = 2
Public Const P_CRAWL = 32
Public Const S_TURRET = 42
Public Const S_TURRET_N = 5
Public Const P_TURRET = 16
Public Const S_HEAD = 47
Public Const P_HEAD = 32
Public Const S_SEG = 48
Public Const S_SEG_N = 2
Public Const P_SEG = 32
Public Const S_CARRIER = 50
Public Const S_CARRIER_N = 2
Public Const S_CARRIER_W = 2
Public Const S_CARRIER_H = 1
Public Const P_CARRIER = 16
Public Const S_MINE = 54
Public Const S_MINE_N = 2
Public Const P_MINE = 48
Public Const S_ORBIT = 56
Public Const S_ORBIT_N = 2
Public Const P_ORBIT = 32
Public Const S_BOSS1 = 58
Public Const S_BOSS1_W = 4
Public Const S_BOSS1_H = 3
Public Const P_BOSS1 = 80
Public Const S_GUARD = 70
Public Const S_GUARD_W = 2
Public Const S_GUARD_H = 2
Public Const P_GUARD = 80
Public Const S_BOSS2 = 74
Public Const S_BOSS2_W = 4
Public Const S_BOSS2_H = 3
Public Const P_BOSS2 = 96
Public Const S_DIGIT = 86
Public Const S_DIGIT_N = 10
Public Const P_DIGIT = 112
Public Const S_LIFE = 96
Public Const P_LIFE = 112
Public Const S_GAUGE = 97
Public Const S_GAUGE_N = 3
Public Const P_GAUGE = 112
Public Const S_STAR = 100
Public Const S_STAR_N = 3
Public Const P_STAR = 112
Public Const S_LOGO = 103
Public Const S_LOGO_N = 6
Public Const P_LOGO = 112
Public Const T_ROCKA = 1
Public Const T_ROCKB = 2
Public Const T_EDGEC = 3
Public Const T_EDGEF = 4
Public Const T_SLOPEA = 5
Public Const T_GLOWA = 6
Public Const T_EMPTY = 7
Public Const T_STARA = 8
Public Const T_STARB = 9
Public Const T_STARC = 10
Public Const T_STALAC = 11
Public Const T_STALAG = 12
Public Const T_PLATEA = 13
Public Const T_PLATEB = 14
Public Const T_PLATEC = 15
Public Const T_FLIPC = 16
Public Const T_FLIPF = 17
Public Const Patterns = 109

Public Sub Load()
#asm
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
            ld a, 56
            out (c), a
            dec b
            ld a, #57
            out (c), a
            inc b
            ld a, 57
            out (c), a
            dec b
            ld bc, #303B            ; the patterns, from pattern 0
            xor a
            out (c), a
            ld hl, #C000
            ld de, 13952
gd_pat:
            ld a, (hl)
            out (#5B), a
            inc hl
            dec de
            ld a, d
            or e
            jr nz, gd_pat
            ld bc, #243B            ; the tiles: their bank's first page at #E000, bank 5's at #C000
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            dec b
            ld a, #57
            out (c), a
            inc b
            ld a, 58
            out (c), a
            dec b
            ld hl, #E000
            ld de, #C000
            ld bc, 8192
            ldir
            ld bc, #243B
            ld a, #57
            out (c), a
            inc b
            ld a, 59
            out (c), a
            dec b
            ld a, #43
            out (c), a
            inc b
            ld a, #20
            out (c), a
            dec b
            ld hl, #E000
            ld a, #40
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #44
            out (c), a
            inc b
            ld e, 0
gd_p1:
            ld a, (hl)
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, gd_p1
            dec b
            ld a, #43
            out (c), a
            inc b
            ld a, #30
            out (c), a
            dec b
            ld hl, #E200
            ld a, #40
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #44
            out (c), a
            inc b
            ld e, 0
gd_p2:
            ld a, (hl)
            out (c), a
            inc hl
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, gd_p2
            dec b
            ld a, #43
            out (c), a
            inc b
            ld a, 0
            out (c), a
            dec b
            ld a, #57
            out (c), a
            inc b
            ld a, 11
            out (c), a
            dec b
            jp gd_end
gd_end:
            MMU 6 7, 56
            ORG #C000
            INCBIN "XTYPE.DAT", 0, 16384
            MMU 6 7, 58
            ORG #C000
            INCBIN "XTYPE.DAT", 16384, 16384
            MMU 6 7, 10
            ORG gd_end
#endasm
End Sub
