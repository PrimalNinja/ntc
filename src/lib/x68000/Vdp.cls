' Vdp - the Sharp X68000's video for games: sprites, a scrolling 256 colour picture with raster
' splits, words on the text plane. NTC platform class: Sharp X68000 (the X68000's answer to the
' Mega Drive's Vdp class; first written for TIANLONG). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The screen: 256 x 256 in 256 colours (IOCS mode 11, 15 kHz, 61.5 Hz), three layers, front to back:
'   the text plane   4 bit planes, palette block 0 (16 colours, 0 clear): words drawn with an 8 x
'                    8 font (Font, Text, TFill)
'   the sprites      128 of 16 x 16, 4 bits, palette blocks 0-15, patterns 0-255 in the PCG
'   graphics page 0  a 256 colour bitmap 512 x 512 (GLoad, GFill), its own 256 colour palette
'                    (GColors), scrolled across (Scroll), with up to 4 raster splits: from each
'                    split's line down, a scroll of its own (Split; Upload sets them every frame)
' The X68000 keeps its video for supervisor mode and NTC runs in user mode (its thread is A7), so
' the work is done in routines called through trap #1 (the platform's supervisor call: the
' routine's address in a0, it runs in supervisor mode on the supervisor stack and returns with
' rts). Interrupts stay on.
'
' Sprites: a table in RAM (Sat: 128 x 4 words, as the hardware's: x + 16, y + 16, the flips, the
' palette block and the pattern (VR HR - - CCCC PPPPPPPP), 3 shown / 0 not), written by the
' program, sent by Update (once a frame, just after Frame). Sprite 0 is in front.
' Upload: after Frame, the raster splits' scroll and Update.
Option Explicit

Private spr(511) As Integer            ' the sprite table (128 x 4 words)
Private rl(3) As Integer, rx(3) As Integer, rn As Integer, ri As Integer
Private fontp As Long

' ---------------------------------------------------------------- set up
Public Sub Init()
    Screen
    HideAll
    rn = 0
    Update
End Sub

' the screen set up (IOCS), the layers' order and scroll
Private Sub Screen()
#asm
            move.w #11, d1              ; IOCS _CRTMOD 11: 256 x 256, 256 colours, 15 kHz (61 Hz)
            moveq #$10, d0
            trap #15
            move.l #$90, d0             ; _G_CLR_ON: the graphics cleared and shown
            trap #15
            moveq #$1F, d0              ; _B_CUROFF
            trap #15
            moveq #2, d1                ; _B_CLR_ST: the text plane cleared
            moveq #$2A, d0
            trap #15
            move.l #$C0, d0             ; _SP_INIT, _SP_ON: the sprites for this screen, on
            trap #15
            move.l #$C1, d0
            trap #15
            lea vi_sup, a0              ; (trap #1: the platform's supervisor call)
            trap #1
            bra vi_end
vi_sup:
            move.w #$12E4, $E82500      ; priority: the text, the sprites, the graphics
            move.w #$0063, $E82600      ; shown: the sprites, the text, graphics pages 0 and 1 (in 256
                                        ; colours a pixel is page 0's 4 bits and page 1's)
            move.w #$0000, $E80014      ; the text plane unscrolled
            move.w #$0000, $E80016
            move.w #$0000, $E80018      ; graphics pages 0 and 1 unscrolled
            move.w #$0000, $E8001A
            move.w #$0000, $E8001C
            move.w #$0000, $E8001E
            move.w #$0200, $EB0808      ; the sprites shown (the BG layers off)
            rts
vi_end:
#endasm
End Sub

' Sat(): the sprite table's address
Public Function Sat() As Long
#asm
            lea {spr}, a1
            movea.l (sp)+, a0
            move.l a1, (a0)
#endasm
End Function

' Sprite n, x, y, c, p: sprite n's entry (x, y the screen's, top left; c its flips, block and
' pattern; p 3 shown, 0 not)
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

' Update: the table to the hardware
Public Sub Update()
#asm
            lea {spr}, a1
            lea vu_sup, a0
            trap #1
            bra vu_end
vu_sup:
            lea $EB0000, a2
            move.w #255, d0
vu_lp:
            move.l (a1)+, (a2)+
            dbra d0, vu_lp
            rts
vu_end:
#endasm
End Sub

' ---------------------------------------------------------------- patterns and palettes
' Pcg addr, first, n: n patterns (128 bytes each, the PCG's format) from addr to first on
Public Sub Pcg(ByVal a As Long, ByVal first As Integer, ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a1
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            lea vp_sup, a0
            trap #1
            bra vp_end
vp_sup:
            lea $EB8000, a2
            andi.l #255, d1
            lsl.l #7, d1
            adda.l d1, a2
            subq.w #1, d2
            bmi vp_done
vp_pat:
            moveq #31, d0
vp_lp:
            move.l (a1)+, (a2)+
            dbra d0, vp_lp
            dbra d2, vp_pat
vp_done:
            rts
vp_end:
#endasm
End Sub

' Colors addr, first, n: n colours (words: GGGGG RRRRR BBBBB I) to the text and sprite palettes
' (block b's colour k is first = b * 16 + k)
Public Sub Colors(ByVal a As Long, ByVal first As Integer, ByVal n As Integer)
    PalCopy a, &HE82200 + first * 2, n
End Sub

' GColors addr, first, n: n colours to the graphics' 256 colour palette
Public Sub GColors(ByVal a As Long, ByVal first As Integer, ByVal n As Integer)
    PalCopy a, &HE82000 + first * 2, n
End Sub

Private Sub PalCopy(ByVal a As Long, ByVal d As Long, ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a1
            movea.l (sp)+, a0
            movea.l (a0), a2
            movea.l (sp)+, a0
            move.w (a0), d2
            lea vc_sup, a0
            trap #1
            bra vc_end
vc_sup:
            subq.w #1, d2
            bmi vc_done
vc_lp:
            move.w (a1)+, (a2)+
            dbra d2, vc_lp
vc_done:
            rts
vc_end:
#endasm
End Sub

' ---------------------------------------------------------------- the graphics page
' GLoad addr, y, n: n rows of 256 bytes (a colour each) from addr to graphics page 0's rows y on,
' twice across (x 0-255 and 256-511: it wraps every 256 when scrolled)
Public Sub GLoad(ByVal a As Long, ByVal y As Integer, ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            movea.l (a0), a1
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            lea vg_sup, a0
            trap #1
            bra vg_end
vg_sup:
            lea $C00000, a2
            andi.l #511, d1
            moveq #10, d0
            lsl.l d0, d1
            adda.l d1, a2
            subq.w #1, d2
            bmi vg_done
vg_row:
            move.w #255, d0
            lea 512(a2), a3
            moveq #0, d1
vg_px:
            move.b (a1)+, d1
            move.w d1, (a2)+
            move.w d1, (a3)+
            dbra d0, vg_px
            lea 512(a2), a2
            dbra d2, vg_row
vg_done:
            rts
vg_end:
#endasm
End Sub

' GFill y, n, c: graphics page 0's rows y .. y + n - 1 all colour c
Public Sub GFill(ByVal y As Integer, ByVal n As Integer, ByVal c As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            movea.l (sp)+, a0
            move.w (a0), d3
            lea vf_sup, a0
            trap #1
            bra vf_end
vf_sup:
            lea $C00000, a2
            andi.l #511, d1
            moveq #10, d0
            lsl.l d0, d1
            adda.l d1, a2
            andi.w #255, d3
            subq.w #1, d2
            bmi vf_done
vf_row:
            move.w #511, d0
vf_px:
            move.w d3, (a2)+
            dbra d0, vf_px
            dbra d2, vf_row
vf_done:
            rts
vf_end:
#endasm
End Sub

' GPixel(x, y) / GPlot x, y, c: graphics page 0's pixel (x 0-511, y 0-511)
Public Function GPixel(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            lea vx_sup, a0
            trap #1
            movea.l (sp)+, a0
            move.w d3, (a0)
            bra vx_end
vx_sup:
            andi.l #511, d2
            moveq #10, d0
            lsl.l d0, d2
            andi.l #511, d1
            add.l d1, d1
            add.l d1, d2
            lea $C00000, a2
            move.w 0(a2, d2.l), d3
            andi.w #255, d3
            rts
vx_end:
#endasm
End Function

Public Sub GPlot(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            movea.l (sp)+, a0
            move.w (a0), d3
            lea vy_sup, a0
            trap #1
            bra vy_end
vy_sup:
            andi.l #511, d2
            moveq #10, d0
            lsl.l d0, d2
            andi.l #511, d1
            add.l d1, d1
            add.l d1, d2
            lea $C00000, a2
            move.w d3, 0(a2, d2.l)
            rts
vy_end:
#endasm
End Sub

' Split k, line, x: from raster line `line` down, graphics page 0 scrolled to x (k 0-3, in the order
' they come down the screen; Splits n: how many there are); Scroll x: the top's (above the first)
Public Sub Split(ByVal k As Integer, ByVal intLine As Integer, ByVal x As Integer)
    rl(k) = intLine
    rx(k) = x
End Sub

Public Sub Splits(ByVal n As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d0
            move.w d0, {rn}
            lea vs_ras, a1              ; IOCS _CRTCRAS: the raster interrupt (0: off)
            tst.w d0
            bne vs_on
            suba.l a1, a1
vs_on:
            move.w {rl}, d1
            moveq #$6D, d0
            trap #15
            bra vs_end
; the raster interrupt (supervisor mode): this split's scroll, the next split's line
vs_ras:
            movem.l d0-d1/a0, -(sp)
            move.w {ri}, d0
            add.w d0, d0
            lea {rx}, a0
            move.w 0(a0, d0.w), $E80018
            move.w 0(a0, d0.w), $E8001C
            lsr.w #1, d0
            addq.w #1, d0
            cmp.w {rn}, d0
            bcs vs_next
            moveq #0, d0
vs_next:
            move.w d0, {ri}
            add.w d0, d0
            lea {rl}, a0
            move.w 0(a0, d0.w), $E80012
            movem.l (sp)+, d0-d1/a0
            rte
vs_end:
#endasm
End Sub

' Upload x: after Frame (the vertical blank): graphics page 0's scroll for the top of the screen,
' the splits from the first again, the sprites
Public Sub Upload(ByVal x As Integer)
    Top x
    Update
End Sub

Private Sub Top(ByVal x As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            lea vl_sup, a0
            trap #1
            bra vl_end
vl_sup:
            move.w d1, $E80018
            move.w d1, $E8001C
            clr.w {ri}
            move.w {rl}, $E80012
            rts
vl_end:
#endasm
End Sub

' ---------------------------------------------------------------- the text plane
' Font addr: the font (64 characters from 32, 16 bytes each: the letter's 8 rows, its shadow's 8)
Public Sub Font(ByVal a As Long)
    fontp = a
End Sub

' Text cx, cy, s, c, sh, bg: s at cell cx, cy (8 x 8 cells, 32 x 32) in colour c, its shadow in
' sh, the rest of each cell bg (0: clear). Characters 32-95 (a-z as A-Z), and 123-126 the font's
' 64-67 (a program's own)
Public Sub Text(ByVal cx As Integer, ByVal cy As Integer, ByVal s As String, ByVal c As Integer, ByVal sh As Integer, ByVal bg As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d1             ; cx
            movea.l (sp)+, a0
            move.w (a0), d2             ; cy
            movea.l (sp)+, a3           ; the string
            movea.l (sp)+, a0
            move.w (a0), d3             ; colour
            movea.l (sp)+, a0
            move.w (a0), d4             ; shadow
            movea.l (sp)+, a0
            move.w (a0), d5             ; the rest
            movea.l {fontp}, a4
            lea vt_sup, a0
            trap #1
            bra vt_end
; vt_sup: d1 cx, d2 cy, a3 the string (0 at the end), d3 the colour, d4 the shadow's, d5 the
; rest's, a4 the font. d3 then holds all three (bits 0-3, 8-11, 16-19)
vt_sup:
            movem.l d5-d7/a1-a2/a5, -(sp)
            lea $E00000, a1
            andi.l #$FF, d2
            moveq #10, d0               ; cy * 8 rows * 128
            lsl.l d0, d2
            adda.l d2, a1
            andi.w #$FF, d1
            adda.w d1, a1
            andi.l #15, d3
            andi.l #15, d4
            lsl.l #8, d4
            or.l d4, d3
            andi.l #15, d5
            swap d5
            or.l d5, d3
vt_ch:
            moveq #0, d0
            move.b (a3)+, d0
            beq vt_done
            cmpi.w #123, d0             ; 123-126: the font's 64-67
            bcs vt_lc
            subi.w #123-96, d0
            bra vt_up
vt_lc:
            cmpi.w #97, d0              ; a-z: A-Z
            bcs vt_up
            subi.w #32, d0
vt_up:
            subi.w #32, d0
            bcc vt_ok
            moveq #0, d0
vt_ok:
            lsl.w #4, d0
            lea 0(a4, d0.w), a5         ; the letter's rows, then the shadow's
            moveq #0, d5                ; the row
vt_row:
            move.b 0(a5, d5.w), d6      ; the letter
            move.b 8(a5, d5.w), d7      ; the shadow
            move.b d6, d4               ; the rest
            or.b d7, d4
            not.b d4
            movea.l a1, a2
            moveq #0, d0                ; the plane
vt_pl:
            moveq #0, d2
            btst d0, d3
            beq vt_nl
            or.b d6, d2
vt_nl:
            move.w d0, d1
            addq.w #8, d1
            btst d1, d3
            beq vt_ns
            or.b d7, d2
vt_ns:
            addq.w #8, d1
            btst d1, d3
            beq vt_nb
            or.b d4, d2
vt_nb:
            move.b d2, (a2)
            adda.l #$20000, a2
            addq.w #1, d0
            cmpi.w #4, d0
            bcs vt_pl
            lea 128(a1), a1
            addq.w #1, d5
            cmpi.w #8, d5
            bcs vt_row
            lea -1023(a1), a1           ; the next cell (8 rows up, 1 across)
            bra vt_ch
vt_done:
            movem.l (sp)+, d5-d7/a1-a2/a5
            rts
vt_end:
#endasm
End Sub

' TFill cx, cy, w, h, c: cells cx .. cx + w - 1, cy .. cy + h - 1 all colour c (0: clear)
Public Sub TFill(ByVal cx As Integer, ByVal cy As Integer, ByVal w As Integer, ByVal h As Integer, ByVal c As Integer)
#asm
            movea.l (sp)+, a0
            move.w (a0), d1
            movea.l (sp)+, a0
            move.w (a0), d2
            movea.l (sp)+, a0
            move.w (a0), d3
            movea.l (sp)+, a0
            move.w (a0), d4
            movea.l (sp)+, a0
            move.w (a0), d5
            lea vtf_sup, a0
            trap #1
            bra vtf_end
vtf_sup:
            movem.l d6-d7/a1-a3, -(sp)
            lea $E00000, a1
            andi.l #$FF, d2
            moveq #10, d0
            lsl.l d0, d2
            adda.l d2, a1
            andi.w #$FF, d1
            adda.w d1, a1
            lsl.w #3, d4                ; rows
            subq.w #1, d4
            bmi vtf_done
            subq.w #1, d3
            bmi vtf_done
vtf_row:
            moveq #0, d0                ; the plane
            movea.l a1, a2
vtf_pl:
            moveq #0, d6
            btst d0, d5
            beq vtf_z
            moveq #-1, d6
vtf_z:
            movea.l a2, a3
            move.w d3, d7
vtf_x:
            move.b d6, (a3)+
            dbra d7, vtf_x
            adda.l #$20000, a2
            addq.w #1, d0
            cmpi.w #4, d0
            bcs vtf_pl
            lea 128(a1), a1
            dbra d4, vtf_row
vtf_done:
            movem.l (sp)+, d6-d7/a1-a3
            rts
vtf_end:
#endasm
End Sub
