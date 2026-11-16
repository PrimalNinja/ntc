' Nx - the ZX Spectrum Next's own hardware, straight on the ports: NextRegs (#243B select,
' #253B value), the layer order, the border, palettes, the CPU speed.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' No Z80N opcodes are used (plain out (c)), so any Z80 assembler builds it.
Option Explicit

' layer orders (NextReg #15 bits 4-2): first = on top. S sprites, L Layer 2, U ULA + tilemap
Public Const OrderSLU = 0
Public Const OrderLSU = 1
Public Const OrderSUL = 2
Public Const OrderLUS = 3
Public Const OrderUSL = 4
Public Const OrderULS = 5
' palettes for PalEntry / PalTable (NextReg #43 bits 6-4, the first of each pair)
Public Const PalULA = 0
Public Const PalLayer2 = 1
Public Const PalSprites = 2
Public Const PalTiles = 3

' Reg r, v: NextReg r = v
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
#asm
            pop hl
            ld a, (hl)
            pop hl
            ld e, (hl)
            ld bc, #243B
            out (c), a
            inc b
            out (c), e
#endasm
End Sub

' RegGet(r): NextReg r read back
Public Function RegGet(ByVal r As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            ld bc, #243B
            out (c), a
            inc b
            in e, (c)
            pop hl
            ld (hl), e
            inc hl
            ld (hl), 0
#endasm
End Function

' Layers order: which layer is on top (OrderSLU ...), sprites on and over the border kept
Public Sub Layers(ByVal order As Integer)
#asm
            pop hl
            ld a, (hl)
            and 7
            add a, a
            add a, a
            ld e, a
            ld bc, #243B
            ld a, #15
            out (c), a
            inc b
            in a, (c)
            and %11100011
            or e
            out (c), a
#endasm
End Sub

' Border c: the border colour (0-7, port #FE)
Public Sub Border(ByVal c As Integer)
#asm
            pop hl
            ld a, (hl)
            and 7
            out (#FE), a
#endasm
End Sub

' PalEntry which, index, colour: one colour (RRRGGGBB) of a palette (PalULA ... PalTiles, the
' first palette of each)
Public Sub PalEntry(ByVal which As Integer, ByVal index As Integer, ByVal colour As Integer)
#asm
            pop hl
            ld a, (hl)
            and 3
            rlca
            rlca
            rlca
            rlca
            ld d, a                 ; palette select, bits 6-4
            pop hl
            ld e, (hl)              ; index
            pop hl
            ld l, (hl)              ; colour
            ld bc, #243B
            ld a, #43
            out (c), a
            inc b
            out (c), d
            dec b
            ld a, #40
            out (c), a
            inc b
            out (c), e
            dec b
            ld a, #41
            out (c), a
            inc b
            out (c), l
            dec b
            ld a, #43
            out (c), a
            inc b
            xor a
            out (c), a
#endasm
End Sub

' PalTable which, first, count, address: count colours (1 byte each, RRRGGGBB) from memory
Public Sub PalTable(ByVal which As Integer, ByVal first As Integer, ByVal count As Integer, ByVal address As Integer)
#asm
            pop hl
            ld a, (hl)
            and 3
            rlca
            rlca
            rlca
            rlca
            ld d, a
            pop hl
            ld e, (hl)
            ld bc, #243B
            ld a, #43
            out (c), a
            inc b
            out (c), d
            dec b
            ld a, #40
            out (c), a
            inc b
            out (c), e
            dec b
            pop hl
            ld e, (hl)              ; count (1-256: 0 = 256)
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld a, #41
            out (c), a
            inc b
pt_lp:
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, pt_lp
            dec b
            ld a, #43
            out (c), a
            inc b
            xor a
            out (c), a
#endasm
End Sub

' Raster(): the line the display is on now (0-311; 0-191 the picture)
Public Function Raster() As Integer
#asm
            ld bc, #243B
rs_again:
            ld a, #1E
            out (c), a
            inc b
            in d, (c)
            dec b
            ld a, #1F
            out (c), a
            inc b
            in e, (c)
            dec b
            ld a, #1E
            out (c), a
            inc b
            in a, (c)
            dec b
            cp d
            jr nz, rs_again
            and 1
            ld d, a
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' Seed n: start Rnd's sequence from n (as Randomize n - kept here because Randomize with a
' variable doesn't link on its own in this NTC build: kw_seedv jumps into kw_seedl's section)
Public Sub Seed(ByVal n As Integer)
#asm
            pop hl
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            or h
            jr nz, sd_ok
            inc l
sd_ok:
            ld (ntc_rnd_seed), hl
#endasm
End Sub
