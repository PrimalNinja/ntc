' VDP - a TMS9918 / V9938 / V9958 video chip on its ports. NTC platform class: MSX
'
' The MSX's own chip (#98: a TMS9918 on an MSX1, a V9938 / V9958 from the MSX2 on) - the
' console's too. VDP.Port &H88 for a card.
' Every method is #asm only (a keyword): its arguments go to the library's VDP engine
' (asm/ntc_lib_vdp.asm, ntc_vdpc), which runs on the real stack. The V9938's own commands draw
' Box, Line, Copy and PSet in Screen 5-8; Screen 2 (256 x 192, any chip) has PSet by the CPU.
'   VDP.Screen 5 : VDP.Box 10, 10, 100, 50, 4 : VDP.Line 0, 0, 255, 211, 15

Public Const DefaultPort = &H0098      ' the data port (the control port is the next)
Public Const DefaultChip = 1          ' 0 = TMS9918, 1 = V9938 / V9958 (an MSX1: 0, read from the BIOS)

' the data port (the control port is the next) - for another chip than the platform's
Public Sub Port(ByVal p As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_port
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' the chip on the port: 0 = TMS9918 / TMS9929, 1 = V9938 / V9958
Public Sub Chip(ByVal t As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_chip
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a register (0-7 on a TMS9918, 0-46 on a V9938)
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_reg
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' status register n (S#0-S#9 on a V9938; S#0 on a TMS9918)
Public Function Status(ByVal n As Integer) As Integer
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_stat
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, got
            jp ntc_vcall
got:
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' a VRAM byte (the first 64K)
Public Sub VPoke(ByVal addr As Integer, ByVal v As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_poke
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a VRAM byte (the first 64K)
Public Function VPeek(ByVal addr As Integer) As Integer
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_peek
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, got
            jp ntc_vcall
got:
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' count VRAM bytes from addr set to v
Public Sub Fill(ByVal addr As Integer, ByVal count As Integer, ByVal v As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_fill
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' count bytes from RAM (from: VarPtr, an array's first element ...) to VRAM at addr
Public Sub Write(ByVal addr As Integer, ByVal from As Integer, ByVal count As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_write
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' count bytes from VRAM at addr to RAM at dest
Public Sub Read(ByVal addr As Integer, ByVal dest As Integer, ByVal count As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_read
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' colour n (0-15) = red, green, blue (0-7 each) - V9938 / V9958
Public Sub Palette(ByVal n As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_pal
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a graphics screen, cleared: 2 = 256 x 192 (the TMS9918 too), 5 = 256 x 212 16 colours, 6 = 512 x 212 4 colours, 7 = 512 x 212 16 colours, 8 = 256 x 212 256 colours (V9938 / V9958). Mode (or Cls on the console's chip) gives the text back
Public Sub Screen(ByVal m As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_screen
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a dot of colour c (Screen 2: ink c for its 8 dots)
Public Sub PSet(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_pset
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' the colour of a dot (Screen 5-8)
Public Function Point(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_point
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, got
            jp ntc_vcall
got:
            ex de, hl
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' a filled box (Screen 5-8: the chip draws it)
Public Sub Box(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal c As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_box
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a line (Screen 5-8: the chip draws it)
Public Sub Line(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal c As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_line
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a block of the screen copied (Screen 5-8; the second 64K of 128K VRAM: y + 256 in 5 and 6)
Public Sub Copy(ByVal sx As Integer, ByVal sy As Integer, ByVal dx As Integer, ByVal dy As Integer, ByVal w As Integer, ByVal h As Integer)
#asm
            ld de, ntc_vca
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_vcx_copy
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' until the chip has finished drawing (the methods wait before they start)
Public Sub Wait()
#asm
            ld iy, ntc_vcx_wait
            ld hl, #0098
            ld de, #FF20        ; D = the chip, E = its frame interrupt bit (R#1)
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub
