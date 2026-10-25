' V9990 - the V9990 video chip on its ports. NTC platform class: MSX
'
' A V9990 cartridge at #60 (GFX9000, Video9000, Powergraph, TRH9000): its own monitor output.
' Every method is #asm only (a keyword): its arguments go to the library's V9990 engine
' (asm/ntc_lib_vdp.asm, ntc_v9c), which runs on the real stack. Box, Line, Copy and PSet are the
' chip's own commands.
'   V9990.Screen 1 : V9990.Box 10, 10, 100, 50, 4 : V9990.Line 0, 0, 255, 211, 15

Public Const DefaultPort = &H0060      ' P#0 (P#n = + n)

' the port base (P#0) - for another V9990 than the platform's
Public Sub Port(ByVal p As Integer)
#asm
            ld de, ntc_v9a
            pop hl
            ldi
            ldi
            ld iy, ntc_v9x_port
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a register (R#0-R#54)
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
#asm
            ld de, ntc_v9a
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_v9x_reg
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' the status port (P#5)
Public Function Status() As Integer
#asm
            ld iy, ntc_v9x_stat
            ld hl, #0060
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

' VPoke and VPeek's 64K of the 512K VRAM (0-7)
Public Sub Page(ByVal n As Integer)
#asm
            ld de, ntc_v9a
            pop hl
            ldi
            ldi
            ld iy, ntc_v9x_page
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a VRAM byte in the Page
Public Sub VPoke(ByVal addr As Integer, ByVal v As Integer)
#asm
            ld de, ntc_v9a
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_v9x_poke
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a VRAM byte in the Page
Public Function VPeek(ByVal addr As Integer) As Integer
#asm
            ld de, ntc_v9a
            pop hl
            ldi
            ldi
            ld iy, ntc_v9x_peek
            ld hl, #0060
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

' colour n (0-63) = red, green, blue (0-31 each)
Public Sub Palette(ByVal n As Integer, ByVal r As Integer, ByVal g As Integer, ByVal b As Integer)
#asm
            ld de, ntc_v9a
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
            ld iy, ntc_v9x_pal
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a bit map screen, cleared: 1 = 256 x 212 16 colours, 2 = 512 x 212 16 colours, 3 = 256 x 212 256 colours (the first 16 the MSX2's colours). Mode gives the console's text back (msx9990, cpc9990)
Public Sub Screen(ByVal m As Integer)
#asm
            ld de, ntc_v9a
            pop hl
            ldi
            ldi
            ld iy, ntc_v9x_screen
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a dot of colour c
Public Sub PSet(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer)
#asm
            ld de, ntc_v9a
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            pop hl
            ldi
            ldi
            ld iy, ntc_v9x_pset
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a filled box (the chip draws it)
Public Sub Box(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal c As Integer)
#asm
            ld de, ntc_v9a
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
            ld iy, ntc_v9x_box
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a line (the chip draws it)
Public Sub Line(ByVal x1 As Integer, ByVal y1 As Integer, ByVal x2 As Integer, ByVal y2 As Integer, ByVal c As Integer)
#asm
            ld de, ntc_v9a
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
            ld iy, ntc_v9x_line
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' a block of the screen copied (the chip does it)
Public Sub Copy(ByVal sx As Integer, ByVal sy As Integer, ByVal dx As Integer, ByVal dy As Integer, ByVal w As Integer, ByVal h As Integer)
#asm
            ld de, ntc_v9a
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
            ld iy, ntc_v9x_copy
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub

' until the chip has finished drawing (the methods wait before they start)
Public Sub Wait()
#asm
            ld iy, ntc_v9x_wait
            ld hl, #0060
            ld ix, ntc_next
            jp ntc_vcall
#endasm
End Sub
