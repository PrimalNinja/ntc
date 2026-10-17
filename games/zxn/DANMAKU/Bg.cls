' Bg - the scrolling background on Layer 2: 16 x 16 blocks, the hardware scrolling it down a line
' a frame, one new line drawn at the top each time (the line about to come into view).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Layer 2 is 256 x 192 in 16K bank 16 (8K pages 32-37); only the left 192 pixels are shown (its
' clip window), 12 blocks across. Drawing maps the page it needs into MMU slot 6 (#C000-#DFFF)
' and puts bank 5's first half back after (the tilemap's tiles live there).
' A frame (just after Frame, so the new line is drawn before the picture reaches it):
'     If Bg.Phase() = 0 Then  ...Bg.Cell c, block for the 12 cells of the next block row...
'     Bg.Scroll
' Phase(): the block row's line drawn last (15 down to 0): 0 = the row is done, set the next.
Option Explicit

Private cells(15) As Byte          ' the block row being drawn: 12 block numbers
Private top As Integer             ' Layer 2's scroll (NextReg #17): the buffer line shown at the top
Private phs As Integer           ' the block's line drawn last (15 .. 0)
Private blk As Integer             ' the blocks' address
Private col As Integer             ' the colour sets' address
Private cnt As Integer

' Init blocks, colours: Layer 2 on (256 x 192, bank 16, the left 192 pixels shown), the first set
' of colours
Public Sub Init(ByVal blocks As Integer, ByVal colours As Integer)
  blk = blocks : col = colours
  top = 0 : phs = 0
  Nx.Reg &H70, 0                         ' 256 x 192
  Nx.Reg &H12, 16                        ' 16K bank 16
  Nx.Reg &H1C, 1                         ' its clip window: the left 192 pixels
  Nx.Reg &H18, 0 : Nx.Reg &H18, 191 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0
  Theme 0
  Out &H123B, 2                          ' Layer 2 visible
End Sub

' Theme n: the colours of stage n (0-4), or 5 the bomb's flash
Public Sub Theme(ByVal n As Integer)
#asm
            pop hl
            ld a, (hl)
            ld l, a                 ; HL = col + n * 48
            ld h, 0
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ld d, h
            ld e, l
            add hl, hl
            add hl, de
            ld de, ({col})
            add hl, de
            ld bc, #243B
            ld a, #43               ; Layer 2's first palette, written in turn
            out (c), a
            inc b
            ld a, #10
            out (c), a
            dec b
            ld a, #40
            out (c), a
            inc b
            xor a
            out (c), a
            dec b
            ld a, #41
            out (c), a
            inc b
            ld e, 48
th_lp:
            ld a, (hl)
            out (c), a
            inc hl
            dec e
            jr nz, th_lp
            dec b
            ld a, #43               ; back to the ULA's palette (others write #41 too)
            out (c), a
            inc b
            xor a
            out (c), a
#endasm
End Sub

' Cell c, b: cell c (0-11) of the next block row is block b
Public Sub Cell(ByVal c As Integer, ByVal b As Integer)
#asm
            pop hl
            ld a, (hl)
            and 15
            ld e, a
            ld d, 0
            pop hl
            ld a, (hl)
            ld hl, {cells}
            add hl, de
            ld (hl), a
#endasm
End Sub

' Phase(): the line of the block row drawn last (0: the row is finished)
Public Function Phase() As Integer
  Phase = phs
End Function

' Scroll: everything down a line, the new top line drawn (the next line up of the block row)
Public Sub Scroll()
#asm
            ld a, ({phs})
            dec a
            and 15
            ld ({phs}), a
            ld c, a                 ; C = the block's line
            ld a, ({top})           ; the buffer line: top - 1, 191 after 0
            or a
            jr nz, sc_dec
            ld a, 192
sc_dec:
            dec a
            ld ({top}), a
            ld b, a
            rlca                    ; its page: 32 + line / 32
            rlca
            rlca
            and 7
            add a, 32
            ld e, a
            ld a, b
            and 31
            add a, #C0
            ld d, a                 ; D = #C0 + line mod 32 (the address's high byte)
            ld a, e
            ld (sc_pg + 1), a
            ld a, c                 ; the source offset in a block: line * 16
            rlca
            rlca
            rlca
            rlca
            ld (sc_off + 1), a
            ld e, 0                 ; DE = the line's first pixel
            ld bc, #243B
            ld a, #56
            out (c), a
            inc b
sc_pg:
            ld a, 0
            out (c), a
            ld hl, {cells}
            ld (sc_hl + 1), hl
            ld a, 12
            ld ({cnt}), a
sc_cell:
sc_hl:
            ld hl, 0
            ld a, (hl)              ; the block: blk + b * 256 + line * 16
            inc hl
            ld (sc_hl + 1), hl
            ld hl, ({blk})
            add a, h
            ld h, a
sc_off:
            ld a, 0
            add a, l
            ld l, a
            jr nc, sc_nc
            inc h
sc_nc:
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ldi
            ld hl, {cnt}
            dec (hl)
            jr nz, sc_cell
            ld bc, #243B            ; slot 6 back to bank 5's first half (the tiles)
            ld a, #56
            out (c), a
            inc b
            ld a, 10
            out (c), a
            dec b
            ld a, #17               ; the new line at the top
            out (c), a
            inc b
            ld a, ({top})
            out (c), a
#endasm
End Sub

