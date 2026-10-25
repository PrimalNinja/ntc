' Vdp - the Mega Drive's video chip: colours, tiles, the two planes, scrolling and the 80
' hardware sprites. NTC platform class: Sega Mega Drive / Genesis (68000)
'
' Each method's body is only #asm, so each is a keyword: Vdp.Sprite n, x, y, size, value
' compiles to one thread long and its arguments. The VDP is only touched from the program
' (never from the frame interrupt), so a method is never cut in two by it.
'
' The screen: 320 x 224 (40 x 28 cells of 8 x 8). Plane A ($C000) also has the console (Print,
' Locate, Cls: character c is tile c, tiles 32-126); plane B ($E000) is under it. Both are 64
' x 32 cells, so they wrap when scrolled. Tiles 128 on ($1000) are free for the program; a tile
' is 32 bytes (8 rows of 4 bytes, 2 pixels a byte, the high nibble first, colour 0 = clear).
'
' A cell's value (planes and sprites): the tile number (0-2047) + Palette * the palette (0-3)
' + FlipX / FlipY + Front (in front of sprites that are not Front).
' A colour: &H0BGR with each of B, G, R 0-7 doubled (0, 2, 4 ... E), e.g. &H0EEE white,
' &H000E red, &H00E0 green, &H0E00 blue.
' Sprites: Vdp.Sprite n (0-79), x, y (the top left on the screen, -32 .. 352 / 256), size, value;
' size = (width in cells - 1) * 4 + (height in cells - 1), e.g. Size16 (2 x 2 cells), Size32 (4 x
' 4). A sprite's tiles go down then across: a 2 x 2 sprite is tiles t, t+1 (left column), t+2,
' t+3. The table is kept in RAM: Vdp.Update writes it to the VDP - call it once a frame, after
' Frame (the vertical blank). At most 20 sprites (320 pixels of them) on a line.

Public Const Palette = 8192         ' * 0-3: the cell's palette
Public Const FlipX = 2048
Public Const FlipY = 4096
Public Const Front = -32768         ' in front (priority)
Public Const Size8 = 0              ' 1 x 1 cell
Public Const Size16 = 5             ' 2 x 2 cells
Public Const Size24 = 10            ' 3 x 3 cells
Public Const Size32 = 15            ' 4 x 4 cells
Public Const PlaneA = 0
Public Const PlaneB = 1

' a colour: index 0-63 (palette * 16 + colour), value &H0BGR
Public Sub Color(ByVal index As Integer, ByVal value As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a1
            andi.l #$3F, d0
            add.w d0, d0
            swap d0
            ori.l #$C0000000, d0
            move.l d0, VDP_CTRL
            move.w (a1), VDP_DATA
#endasm
End Sub

' count colours (words) from the address (a Long: a label in the ROM) into index first on
Public Sub Colors(ByVal addr As Long, ByVal first As Integer, ByVal count As Integer)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a2
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            andi.l #$3F, d0
            add.w d0, d0
            swap d0
            ori.l #$C0000000, d0
            move.l d0, VDP_CTRL
            subq.w #1, d1
            bmi done
lp:
            move.w (a2)+, VDP_DATA
            dbra d1, lp
done:
#endasm
End Sub

' count tiles (32 bytes each) from the address (a Long) into the VDP from tile first on
Public Sub Tiles(ByVal addr As Long, ByVal first As Integer, ByVal count As Integer)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a2
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            lsl.w #5, d0
            NTC_RS
            jsr ntc_md_vaddr
            NTC_TS
            lsl.w #3, d1                ; longs
            subq.w #1, d1
            bmi done
lp:
            move.l (a2)+, VDP_DATA
            dbra d1, lp
done:
#endasm
End Sub

' a cell of a plane (PlaneA, PlaneB): column x 0-63, row y 0-31
Public Sub Cell(ByVal plane As Integer, ByVal x As Integer, ByVal y As Integer, ByVal value As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d2
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a1
            andi.w #63, d0
            andi.w #31, d1
            lsl.w #6, d1
            add.w d1, d0
            add.w d0, d0
            addi.w #$C000, d0
            tst.w d2
            beq pa
            addi.w #$2000, d0
pa:
            NTC_RS
            jsr ntc_md_vaddr
            NTC_TS
            move.w (a1), VDP_DATA
#endasm
End Sub

' w x h cells of a plane from column x, row y, all the same value
Public Sub Fill(ByVal plane As Integer, ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal value As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d2             ; plane
            movea.l (sp)+, a0
            move.w (a0), d3             ; x
            movea.l (sp)+, a0
            move.w (a0), d4             ; y
            movea.l (sp)+, a0
            move.w (a0), d5             ; w
            movea.l (sp)+, a0
            move.w (a0), d6             ; h
            movea.l (sp)+, a0
            move.w (a0), d7             ; value
            subq.w #1, d6
            bmi done
            subq.w #1, d5
            bmi done
            NTC_RS
row:
            move.w d6, -(sp)            ; rows left
            move.w d3, d1
            andi.w #63, d1              ; the column
            bsr addr
            move.w d5, d6
col:
            move.w d7, VDP_DATA
            addq.w #1, d1
            cmpi.w #64, d1
            bne nowrap
            moveq #0, d1                ; round to the plane's left edge
            bsr addr
nowrap:
            dbra d6, col
            move.w (sp)+, d6
            addq.w #1, d4
            dbra d6, row
            NTC_TS
            bra done
addr:
            move.w d4, d0               ; the VDP's address: row d4, column d1
            andi.w #31, d0
            lsl.w #6, d0
            add.w d1, d0
            add.w d0, d0
            addi.w #$C000, d0
            tst.w d2
            beq pa
            addi.w #$2000, d0
pa:
            jmp ntc_md_vaddr
done:
#endasm
End Sub

' scroll a plane: ScrollY moves its picture up by y pixels, ScrollX right by x (the whole plane)
Public Sub ScrollY(ByVal plane As Integer, ByVal y As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a1
            andi.l #1, d0
            add.w d0, d0
            swap d0
            ori.l #$40000010, d0
            move.l d0, VDP_CTRL
            move.w (a1), VDP_DATA
#endasm
End Sub

Public Sub ScrollX(ByVal plane As Integer, ByVal x As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a1
            andi.w #1, d0
            add.w d0, d0
            addi.w #$FC00, d0
            NTC_RS
            jsr ntc_md_vaddr
            NTC_TS
            move.w (a1), VDP_DATA
#endasm
End Sub

' the backdrop (behind everything): colour index 0-63
Public Sub Backdrop(ByVal index As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.w #$3F, d0
            ori.w #$8700, d0
            move.w d0, VDP_CTRL
#endasm
End Sub

' the console's text (Print): its palette (0-3) - the text is colour 1 of it
Public Sub TextPalette(ByVal pal As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.w #3, d0
            lsl.w #5, d0
            ori.w #$80, d0
            move.b d0, ntc_tattr
#endasm
End Sub

' a copy of the console's font into tiles first + 32 .. first + 126: the pixels colour fg (1-15),
' the rest colour bg (0 = clear) - e.g. an opaque font for a panel that sprites go behind
Public Sub LoadFont(ByVal first As Integer, ByVal fg As Integer, ByVal bg As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            andi.w #15, d1
            movea.l (sp)+, a0
            move.w (a0), d2
            andi.w #15, d2
            NTC_RS
            jsr ntc_md_loadfont
            NTC_TS
#endasm
End Sub

' the console's text from then on: character c is tile first + c (0: the font loaded at start)
Public Sub TextFont(ByVal first As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), ntc_tbase
#endasm
End Sub

' a sprite: n 0-79, x / y its top left on the screen, size (Size16 ...), value (tile + Palette ...)
Public Sub Sprite(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal size As Integer, ByVal value As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.w #127, d0
            lsl.w #3, d0
            lea ntc_sat, a1
            adda.w d0, a1
            movea.l (sp)+, a0
            move.w (a0), d1             ; x
            movea.l (sp)+, a0
            move.w (a0), d2             ; y
            addi.w #128, d2
            bgt yok
            moveq #0, d2
yok:
            move.w d2, (a1)+
            movea.l (sp)+, a0
            move.w (a0), (a1)+          ; size
            movea.l (sp)+, a0
            move.w (a0), (a1)+          ; value
            addi.w #128, d1
            bgt xok
            moveq #1, d1                ; (x 0 would hide the sprites after it on its lines)
xok:
            move.w d1, (a1)
#endasm
End Sub

' a sprite off the screen
Public Sub Hide(ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.w #127, d0
            lsl.w #3, d0
            lea ntc_sat, a1
            clr.w 0(a1, d0.w)
#endasm
End Sub

' every sprite off the screen
Public Sub HideAll()
#asm
            lea ntc_sat, a1
            moveq #80-1, d0
lp:
            clr.w (a1)
            addq.l #8, a1
            dbra d0, lp
#endasm
End Sub

' the sprite table to the VDP: once a frame, after Frame
Public Sub Update()
#asm
            NTC_RS
            jsr ntc_md_sprupd
            NTC_TS
#endasm
End Sub
