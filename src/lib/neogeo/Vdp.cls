' Vdp - the Neo Geo's video: the sprites, a backdrop made of sprites, the palettes and the fix
' layer's cells. NTC platform class: SNK Neo Geo (68000; first written for TIANLONG and SILK TO
' STEEL). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The screen is 320 x 224. The Neo Geo has no tile planes: everything but the fix layer (8 x 8
' cells, in front of all: NTC's console is on it) is sprites - columns 16 wide, 1-32 tiles of
' 16 x 16 tall, each tile with its own palette (256 palettes of 16 colours: colour 0 clear).
' Sprites 1-380; one further on in VRAM is in front. The tiles are the cartridge's C ROM
' (tools/neogeo/ngtiles.js makes it from pictures; test/ngbuild.js --crom).
'
' THE GAME'S SPRITES: a table in RAM (Sat: 128 entries of 4 words, the X68000's form, so a game's
' sprite code is the same on both):
'   word 0   x + 16        word 1   y + 16
'   word 2   VR HR - - CCCC PPPPPPPP   (the flips, the palette block 0-15, the pattern 0-255)
'   word 3   3 shown / 0 not
' with the game's 256 x 192 picture at x 0, y 32 of that (so it sits in the middle of the Neo
' Geo's screen, from 32, 16). Update (once a frame) sends the table to sprites 100-227 (entry 0
' in front): pattern p is the C ROM tile Map gives it, block b is palette 16 + b.
'
' THE BACKDROP: sprites 1-68, a 256 x 192 picture in four bands (lines 0-55, 56-111, 112-151,
' 152-191) each scrolled sideways on its own (Back, Bands). ngtiles.js --backdrop cuts a picture
' into its 224 tiles and 224 palettes (palettes 32-255).
' A scrolled band's columns stand up to 15 pixels past the picture's left and right edges (x 32
' and 288): a game covers the screen's two sides with fix layer cells (Fill).
'
' ANY SPRITE, straight (69-99 and 228-380 are free of the two above): Strip, Place, Shrink, Join,
' Hide.
'
' PALETTES: Colors, Color, Backdrop; Rgb makes a colour. Entry p * 16 + k is palette p's colour k;
' palettes 0-15 are the fix layer's (0 is NTC's console: colour 1 white).
' THE FIX LAYER: Cell, Fill (40 x 28 cells: the rows a TV shows).
' VRAM is written from the program as it runs (the Neo Geo lets the 68000 at it at any time).
Option Explicit

Private spr(511) As Integer            ' the sprite table (128 x 4 words)
Private pmap(255) As Integer           ' pattern -> its C ROM tile
Private lst(127) As Integer            ' each entry's flips, block and pattern as last sent (-1: send it)
Private bt As Integer                  ' the backdrop's first tile
Private bw(3) As Integer               ' each band's wrap sprite: the column it shows now

' ---------------------------------------------------------------- VRAM
' VAddr a: VRAM's address a, VMod m: the step after each word, VPut v: a word written there
Public Sub VAddr(ByVal a As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), $3C0000
#endasm
End Sub

Public Sub VMod(ByVal m As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), $3C0004
#endasm
End Sub

Public Sub VPut(ByVal v As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), $3C0002
#endasm
End Sub

' VTile t, p: a sprite's tile pair: tile t in palette p (no flips)
Private Sub VTile(ByVal t As Integer, ByVal p As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), $3C0002
            movea.l (sp)+, a0
            move.w (a0), d0
            lsl.w #8, d0
            move.w d0, $3C0002
#endasm
End Sub

' VY y, h: a sprite's SCB3 word: its top at the screen's line y, h tiles tall
Private Sub VY(ByVal y As Integer, ByVal h As Integer)
#asm
            movea.l (sp)+, a0
            move.w #496, d0
            sub.w (a0), d0
            andi.w #511, d0
            lsl.w #7, d0
            movea.l (sp)+, a0
            or.w (a0), d0
            move.w d0, $3C0002
#endasm
End Sub

' ---------------------------------------------------------------- set up
Public Sub Init()
    Dim intI As Integer
    For intI = 0 To 255
        pmap(intI) = intI
    Next intI
    Forget
    HideAll
    Update
    BackOff
End Sub

' Sat(): the sprite table's address
Public Function Sat() As Long
#asm
            lea {spr}, a1
            movea.l (sp)+, a0
            move.l a1, (a0)
#endasm
End Function

' Sprite n, x, y, c, p: the table's entry n (0-127): x, y the game's picture's (top left; the
' picture's 0, 0 is the screen's 32, 16); c its flips, block and pattern; p 3 shown, 0 not. (As the
' X68000's Vdp.Sprite.)
Public Sub Sprite(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal c As Integer, ByVal p As Integer)
    spr(n * 4) = x + 16
    spr(n * 4 + 1) = y + 16
    spr(n * 4 + 2) = c
    spr(n * 4 + 3) = p
End Sub

Public Sub HideAll()
    Dim intI As Integer
    For intI = 0 To 127
        spr(intI * 4 + 3) = 0
    Next intI
End Sub

' Map first, n, tile: patterns first .. first + n - 1 are C ROM tiles tile on
Public Sub Map(ByVal first As Integer, ByVal n As Integer, ByVal tile As Integer)
    Dim intI As Integer
    For intI = 0 To n - 1
        pmap((first + intI) And 255) = tile + intI
    Next intI
    Forget
End Sub

' Forget: every sprite's tile sent again at the next Update
Private Sub Forget()
    Dim intI As Integer
    For intI = 0 To 127
        lst(intI) = -1
    Next intI
End Sub

' Update: the table to the sprites 100-227 (their tile, palette and flips, when they changed; y
' and 1 tall, or 0 tall: hidden; x)
Public Sub Update()
#asm
            lea {spr}, a1
            lea {pmap}, a3
            lea {lst}, a4
            lea $3C0000, a2
            move.w #1, 4(a2)
            move.w #227*64, d6          ; entry 0: sprite 227
            moveq #127, d7
vu_s1:
            tst.w 6(a1)
            beq vu_s1n
            move.w 4(a1), d0            ; VR HR - - CCCC PPPPPPPP
            cmp.w (a4), d0
            beq vu_s1n                  ; as it was
            move.w d0, (a4)
            move.w d6, (a2)
            move.w d0, d1
            andi.w #255, d1
            add.w d1, d1
            move.w 0(a3, d1.w), 2(a2)   ; the tile
            move.w d0, d1
            andi.w #$0F00, d1
            addi.w #$1000, d1           ; palette 16 + the block
            tst.w d0
            bpl vu_nv
            ori.w #2, d1
vu_nv:
            btst #14, d0
            beq vu_nh
            ori.w #1, d1
vu_nh:
            move.w d1, 2(a2)
vu_s1n:
            addq.l #8, a1
            addq.l #2, a4
            subi.w #64, d6
            dbra d7, vu_s1
            lea {spr}, a1               ; SCB3 (y, height) for sprites 100 on: entries 127 down
            adda.w #127*8, a1
            move.w #$8200+100, (a2)
            moveq #127, d7
vu_s3:
            moveq #0, d0
            tst.w 6(a1)
            beq vu_s3h
            move.w #496+32, d0          ; the screen's y = the table's - 32
            sub.w 2(a1), d0
            andi.w #511, d0
            lsl.w #7, d0
            addq.w #1, d0
vu_s3h:
            move.w d0, 2(a2)
            subq.l #8, a1
            dbra d7, vu_s3
            lea {spr}, a1               ; SCB4 (x)
            adda.w #127*8, a1
            move.w #$8400+100, (a2)
            moveq #127, d7
vu_s4:
            move.w (a1), d0             ; the screen's x = the table's + 16
            addi.w #16, d0
            andi.w #511, d0
            lsl.w #7, d0
            move.w d0, 2(a2)
            subq.l #8, a1
            dbra d7, vu_s4
#endasm
End Sub

' Colors addr, first, n: n colours (the Neo Geo's words) from addr to palette entries first on
Public Sub Colors(ByVal a As Long, ByVal first As Integer, ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a1
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            lea $400000, a2
            andi.l #$0FFF, d0
            add.l d0, d0
            adda.l d0, a2
            subq.w #1, d1
            bmi vc_done
vc_lp:
            move.w (a1)+, (a2)+
            dbra d1, vc_lp
vc_done:
#endasm
End Sub

' BackPal pal: the backdrop's 224 palettes (32-255, not entry 4095: the backdrop colour) from pal
' (a long at a time)
Public Sub BackPal(ByVal pal As Long)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a1
            lea $400400, a2
            move.w #(224*16-2)/2-1, d1
vp_lp:
            move.l (a1)+, (a2)+
            dbra d1, vp_lp
            move.w (a1)+, (a2)+
#endasm
End Sub

' BackFlash v: every colour of the backdrop's palettes v (the lightning's flash)
Public Sub BackFlash(ByVal v As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            move.w d0, d2
            swap d0
            move.w d2, d0
            lea $400400, a2
            move.w #(224*16-2)/2-1, d1
vfl_lp:
            move.l d0, (a2)+
            dbra d1, vfl_lp
            move.w d0, (a2)+
#endasm
End Sub

' Color i, v: palette entry i (4095: the backdrop colour, behind everything) = v
Public Sub Color(ByVal i As Integer, ByVal v As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            lea $400000, a2
            andi.l #$0FFF, d0
            add.l d0, d0
            move.w (a0), 0(a2, d0.l)
#endasm
End Sub

' ---------------------------------------------------------------- the backdrop
' the bands: their tops (the paper's lines), heights in tiles, first tiles (as ngtiles.js --backdrop cuts them)
Private Function BTop(ByVal b As Integer) As Integer
    Select Case b
        Case 0: BTop = 0
        Case 1: BTop = 56
        Case 2: BTop = 112
        Case Else: BTop = 152
    End Select
End Function

Private Function BRows(ByVal b As Integer) As Integer
    If b < 2 Then BRows = 4 Else BRows = 3
End Function

Private Function BOff(ByVal b As Integer) As Integer
    Select Case b
        Case 0: BOff = 0
        Case 1: BOff = 64
        Case 2: BOff = 128
        Case Else: BOff = 176
    End Select
End Function

' Back tile, pal: the backdrop from C ROM tile `tile` on (224 tiles: tools/neogeo/ngtiles.js --backdrop), its 224
' palettes from pal (to palettes 32-255); unscrolled
Public Sub Back(ByVal tile As Integer, ByVal pal As Long)
    Dim intB As Integer, intK As Integer, intR As Integer, intN As Integer, intT As Integer
    bt = tile
    BackPal pal
    VMod 1
    For intB = 0 To 3
        For intK = 0 To 15
            VAddr (1 + intB * 17 + intK) * 64
            For intR = 0 To BRows(intB) - 1
                intT = BOff(intB) + intK * BRows(intB) + intR
                VTile bt + intT, 32 + intT
            Next intR
        Next intK
        bw(intB) = -1
        VAddr &H8200 + 1 + intB * 17
        For intK = 0 To 16
            VY 16 + BTop(intB), BRows(intB)
        Next intK
    Next intB
    Bands 0, 0, 0, 0
End Sub

' BackOff: the backdrop hidden
Public Sub BackOff()
    Dim intK As Integer
    VMod 1
    VAddr &H8201
    For intK = 1 To 68
        VPut 0
    Next intK
End Sub

' BandX n, s: band sprites n .. n + 16's x for its scroll s (the picture's x at the paper's left):
' column k at (k * 16 - s) mod 256, the 17th (the wrap) 256 to the left of column s \ 16's
Private Sub BandX(ByVal n As Integer, ByVal s As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            lea $3C0000, a2
            move.w #1, 4(a2)
            addi.w #$8400, d0
            move.w d0, (a2)
            moveq #0, d2                ; k * 16
            moveq #15, d3
bx_lp:
            move.w d2, d0
            sub.w d1, d0
            andi.w #255, d0
            addi.w #32, d0
            lsl.w #7, d0
            move.w d0, 2(a2)
            addi.w #16, d2
            dbra d3, bx_lp
            move.w d1, d0               ; the wrap: (column s \ 16's x) - 256 + 32
            andi.w #15, d0
            neg.w d0
            andi.w #255, d0
            subi.w #224, d0
            andi.w #511, d0
            lsl.w #7, d0
            move.w d0, 2(a2)
#endasm
End Sub

' Bands a, b, c, d: the four bands' scroll (the picture's x at the paper's left edge)
Public Sub Bands(ByVal a As Integer, ByVal b As Integer, ByVal c As Integer, ByVal d As Integer)
    Band 0, a : Band 1, b : Band 2, c : Band 3, d
End Sub

Private Sub Band(ByVal intB_a As Integer, ByVal s As Integer)
    Dim intK As Integer, intR As Integer, intT As Integer
    s = s And 255
    BandX 1 + intB_a * 17, s
    intK = s \ 16
    If intK <> bw(intB_a) Then
        bw(intB_a) = intK
        VMod 1
        VAddr (1 + intB_a * 17 + 16) * 64
        For intR = 0 To BRows(intB_a) - 1
            intT = BOff(intB_a) + intK * BRows(intB_a) + intR
            VTile bt + intT, 32 + intT
        Next intR
    End If
End Sub

' ---------------------------------------------------------------- any sprite
' Strip n, tile, pal, h: sprite n's h tiles (1-32), from its top down, are C ROM tiles tile,
' tile + 1 ... in palette pal (no flips; tiles 0-65535)
Public Sub Strip(ByVal n As Integer, ByVal tile As Integer, ByVal pal As Integer, ByVal h As Integer)
    Dim intI As Integer
    VMod 1
    VAddr n * 64
    For intI = 0 To h - 1
        VTile tile + intI, pal
    Next intI
End Sub

' Place n, x, y, h: sprite n's top left at the screen's x, y (0-319, 0-223; it may be part off),
' h tiles tall (0: hidden)
Public Sub Place(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal h As Integer)
    VMod 1
    VAddr &H8200 + n
    VY y, h
    VAddr &H8400 + n
    VX x
End Sub

' Shrink n, hs, vs: sprite n's width hs (0-15: 15 full) and height vs (0-255: 255 full)
Public Sub Shrink(ByVal n As Integer, ByVal hs As Integer, ByVal vs As Integer)
    VAddr &H8000 + n
    VPut (hs And 15) * 256 + (vs And 255)
End Sub

' Join n: sprite n joined to sprite n - 1's right side: it takes that one's y, height and
' height shrink, and moves with it (a wide object is one Place and a row of Joins)
Public Sub Join(ByVal n As Integer)
    VAddr &H8200 + n
    VPut 64
End Sub

' Hide n: sprite n not shown (0 tall)
Public Sub Hide(ByVal n As Integer)
    VAddr &H8200 + n
    VPut 0
End Sub

' VX x: a sprite's SCB4 word: its left at the screen's x
Private Sub VX(ByVal x As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            andi.w #511, d0
            lsl.w #7, d0
            move.w d0, $3C0002
#endasm
End Sub

' ---------------------------------------------------------------- colours
' Rgb(r, g, b): the Neo Geo's colour word for red, green and blue 0-31
Public Function Rgb(ByVal r As Integer, ByVal g As Integer, ByVal b As Integer) As Integer
    Dim v As Integer
    v = ((r And 30) * 128) Or ((g And 30) * 8) Or ((b And 31) \ 2)
    If (r And 1) <> 0 Then v = v Or &H4000
    If (g And 1) <> 0 Then v = v Or &H2000
    If (b And 1) <> 0 Then v = v Or &H1000
    Rgb = v
End Function

' Backdrop v: the colour behind everything (palette entry 4095)
Public Sub Backdrop(ByVal v As Integer)
    Color 4095, v
End Sub

' ---------------------------------------------------------------- the fix layer
' Cell x, y, v: the fix layer's cell x, y (0-39, 0-27: the rows a TV shows) = v (palette << 12 |
' tile)
Public Sub Cell(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            lsl.w #5, d0
            add.w d1, d0
            addi.w #$7002, d0
            move.w d0, $3C0000
            move.w (a0), $3C0002
#endasm
End Sub

' Fill x, y, w, h, v: cells x .. x + w - 1, y .. y + h - 1 all v
Public Sub Fill(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal v As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            movea.l (sp)+, a0
            move.w (a0), d3
            movea.l (sp)+, a0
            move.w (a0), d4
            lea $3C0000, a2
            move.w #1, 4(a2)
            lsl.w #5, d0
            add.w d1, d0
            addi.w #$7002, d0
            subq.w #1, d2
            bmi vf_done
            subq.w #1, d3
            bmi vf_done
vf_col:
            move.w d0, (a2)
            move.w d3, d5
vf_row:
            move.w d4, 2(a2)
            dbra d5, vf_row
            addi.w #32, d0
            dbra d2, vf_col
vf_done:
#endasm
End Sub

' TextPalette p: Print's characters from now on are in fix palette p (0-15; 0 at the start: colour
' 1 white). (When the console scrolls or clears, every row is drawn again in the palette of the
' moment.)
Public Sub TextPalette(ByVal p As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            lsl.w #4, d0
            move.b d0, ntc_tattr
#endasm
End Sub

' TextBase t: Print's character c is fix tile c + t from now on (another font in the S ROM; 0 at
' the start)
Public Sub TextBase(ByVal t As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), ntc_tbase
#endasm
End Sub
