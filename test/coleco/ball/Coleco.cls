' Coleco - the ColecoVision's hardware, straight on its ports (no BIOS). Test class: tools/coleco
'
' Every method is #asm only, so each call is one keyword in the thread: the arguments arrive as
' addresses (pop hl), no call, no push. The TMS9918A: data port #BE, control port #BF. With the
' display on the chip wants 29 T or more between two accesses; the nops below keep that. The
' frame interrupt (NMI) is never enabled: R#1 bit 5 stays 0.
'   Coleco.Reg 7, &HF4 : Coleco.VPoke &H1800, 2 : Coleco.Frame
'   If (Coleco.Joy And 1) <> 0 Then ...        ' bit 0 up, 1 right, 2 down, 3 left, 6 fire

' VDP register r = v (r 0-7). R#1 bit 5 (the frame interrupt = NMI) must stay 0
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
#asm
            pop hl              ; address of r
            ld c, (hl)
            pop hl              ; address of v
            ld a, (hl)
            out (#BF), a
            ld a, c
            or #80
            nop
            nop
            out (#BF), a
#endasm
End Sub

' one VRAM byte: VRAM(addr) = v
Public Sub VPoke(ByVal addr As Integer, ByVal v As Integer)
#asm
            pop hl              ; address of addr
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; address of v
            ld c, (hl)
            ld a, e
            out (#BF), a
            ld a, d
            and #3F
            or #40              ; write
            nop
            out (#BF), a
            ld a, c
            nop
            nop
            nop
            nop
            out (#BE), a
#endasm
End Sub

' count VRAM bytes from addr set to v
Public Sub Fill(ByVal addr As Integer, ByVal count As Integer, ByVal v As Integer)
#asm
            pop hl              ; address of addr
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; address of count
            ld c, (hl)
            inc hl
            ld b, (hl)
            pop hl              ; address of v
            ld a, (hl)
            ex af, af'          ; the value in A'
            ld a, e
            out (#BF), a
            ld a, d
            and #3F
            or #40
            nop
            out (#BF), a
            nop
            nop
            nop
            nop
fl_loop:
            ex af, af'
            out (#BE), a
            ex af, af'
            dec bc
            ld a, b
            or c
            jr nz, fl_loop
#endasm
End Sub

' wait for the next frame: the VDP's frame flag (status bit 7), polled - NMI is off
Public Sub Frame()
#asm
fr_wait:
            in a, (#BF)
            rlca
            jr nc, fr_wait
#endasm
End Sub

' the controller 1 joystick: bit 0 up, 1 right, 2 down, 3 left, 6 fire (1 = pressed)
Public Function Joy() As Integer
#asm
            out (#C0), a        ; joystick mode (#C0-#DF: the pad, #80-#9F: the keypad)
            in a, (#FC)         ; controller 1: active low
            cpl
            and #4F
            ld e, a
            ld d, 0
            pop hl              ; address of the result
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' sprite 0 (the ball): x, y = its top left pixel. The chip shows a sprite one line lower than its Y
' byte, so Y - 1 is written. Its pattern and colour are set by Gfx. Sprite attribute table at VRAM #1B00
Public Sub Sprite(ByVal x As Integer, ByVal y As Integer)
#asm
            pop hl              ; address of x
            ld c, (hl)
            pop hl              ; address of y
            ld a, (hl)
            dec a
            ld b, a
            xor a
            out (#BF), a        ; VRAM #1B00 for writing
            ld a, #1B | #40
            nop
            nop
            nop
            out (#BF), a
            ld a, b
            nop
            nop
            nop
            nop
            out (#BE), a        ; Y - 1
            ld a, c
            nop
            nop
            nop
            nop
            out (#BE), a        ; X
#endasm
End Sub

' the graphics, written to VRAM from tables in the ROM: tile 0 blank, 1 solid (the border), 2 a dot
' (the background); the colour table (white on dark blue for tiles 0-7); the ball, a 16 x 16 sprite
' pattern at #3800; sprite 0 (the ball: pattern 0, colour light red) and the end of the sprite list
Public Sub Gfx()
#asm
            ld ix, gx_list
gx_next:
            ld l, (ix + 0)      ; the data
            ld h, (ix + 1)
            ld c, (ix + 2)      ; its length, 0 = the end of the list
            ld b, (ix + 3)
            ld a, b
            or c
            jp z, gx_done
            ld a, (ix + 4)      ; its VRAM address
            out (#BF), a
            ld a, (ix + 5)
            or #40
            nop
            nop
            nop
            out (#BF), a
            nop
            nop
            nop
gx_cp:
            ld a, (hl)
            out (#BE), a
            inc hl
            dec bc
            ld a, b
            or c
            jr nz, gx_cp
            ld de, 6
            add ix, de
            jr gx_next
gx_list:    ; @const    data, length, VRAM address
            dw gx_tiles, 24, #0000
            dw gx_colour, 32, #2000
            dw gx_ball, 32, #3800
            dw gx_sat, 8, #1B00
            dw 0, 0, 0
gx_tiles:   ; @const
            db #00, #00, #00, #00, #00, #00, #00, #00   ; 0 blank
            db #FF, #FF, #FF, #FF, #FF, #FF, #FF, #FF   ; 1 solid
            db #00, #00, #00, #00, #08, #00, #00, #00   ; 2 dot
gx_colour:  ; @const
            db #F4, #BF, #BF, #BF, #BF, #BF, #BF, #BF
            db #BF, #BF, #BF, #BF, #BF, #BF, #BF, #BF
            db #BF, #BF, #BF, #BF, #BF, #BF, #BF, #BF
            db #BF, #BF, #BF, #BF, #BF, #BF, #BF, #BF
gx_ball:    ; @const    16 x 16, top left, bottom left, top right, bottom right quarters
            db #07, #1F, #3F, #7F, #7F, #FF, #FF, #FF
            db #FF, #FF, #FF, #7F, #7F, #3F, #1F, #07
            db #E0, #F8, #FC, #FE, #FE, #FF, #FF, #FF
            db #FF, #FF, #FF, #FE, #FE, #FC, #F8, #E0
gx_sat:     ; @const    sprite 0: Y - 1, X, pattern, colour; then Y = #D0: no more sprites
            db 87, 120, 0, 9
            db #D0, 0, 0, 0
gx_done:
#endasm
End Sub
