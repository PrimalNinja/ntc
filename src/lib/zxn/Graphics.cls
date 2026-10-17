' Graphics - drawing on the ZX Spectrum Next's Layer 2 (320 x 256, 256 colours) in the CPC's
' mode 1 size: 320 x 200 (shown 28 rows down, centred), with XOR lines (drawing a line again
' takes it off and leaves what was under it), and double buffering: two Layer 2 buffers (banks
' 12-16 and 17-21), one shown while the other is drawn on. NTC platform class: ZX Spectrum Next
' (direct hardware). Layer 2 comes on with the first line or DoubleBuffer, Mode turns it off.
' Pens are Layer 2's palette entries (set them with NextRegs #43, #40, #41: index 1, 2, 3 ...).
' Text (Print) stays on the tilemap over Layer 2 (its paper see-through meanwhile): CopyText has
' nothing to do. The same methods as the CPC's class, so programs carry over.
Option Explicit

' Line x0, y0, x1, y1: a line in the pen (XOR), in pixels of this mode
Public Sub Line(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (gfx_x0), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (gfx_y0), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (gfx_x1), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (gfx_y1), de
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_line
            ld sp, (gfx_sp)
#endasm
End Sub

' Plot x, y: one pixel in the pen (XOR)
Public Sub Plot(ByVal x As Integer, ByVal y As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (gfx_x0), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (gfx_y0), de
            ld hl, (gfx_x0)
            ld (gfx_x1), hl
            ld hl, (gfx_y0)
            ld (gfx_y1), hl
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_line
            ld sp, (gfx_sp)
#endasm
End Sub

' Pen p: the pen lines are drawn in (0-255: a Layer 2 palette entry, XORed into the pixel)
Public Sub Pen(ByVal p As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (gfx_pen), a
#endasm
End Sub

' Clip on: on (the default) a line with an end off the screen isn't drawn; off: no checks
' (fastest - the program keeps every point on the screen, or it writes over memory)
Public Sub Clip(ByVal on As Integer)
#asm
            pop hl
            ld a, (hl)
            or a
            jr z, cl0
            ld a, 1
cl0:
            ld (gfx_clip), a
#endasm
End Sub

' DoubleBuffer on: two buffers (the one not shown cleared and drawn on; Flip shows it). Off:
' the buffer shown is drawn on
Public Sub DoubleBuffer(ByVal on As Integer)
#asm
            pop hl
            ld a, (hl)
            or a
            jr z, db0
            ld a, 1
db0:
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_double
            ld sp, (gfx_sp)
#endasm
End Sub

' Flip: double buffering - wait for Layer 2's flyback, show the buffer just drawn, draw on the
' other one. Nothing without double buffering
Public Sub Flip()
#asm
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_flip
            ld sp, (gfx_sp)
#endasm
End Sub

' CopyText rows: nothing on the Next (the text is on the tilemap, over both buffers)
Public Sub CopyText(ByVal rows As Integer)
#asm
            pop hl
            ld a, (hl)
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_copyrows
            ld sp, (gfx_sp)
#endasm
End Sub

' Width(): the width in pixels: 320
Public Function Width() As Integer
#asm
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_width
            ex de, hl
            ld sp, (gfx_sp)
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function

' Back(): the buffer drawn on now: 0 = the first (banks 12-16), 1 = the second (17-21)
Public Function Back() As Integer
#asm
            pop hl
            ld a, (gfx_base)
            cp 12
            ld a, 0
            jr z, bk0
            inc a
bk0:
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

' Buffering(): True while double buffering is on
Public Function Buffering() As Integer
#asm
            pop hl
            ld a, (gfx_dbl)
            or a
            jr z, bf0
            ld a, #FF
bf0:
            ld (hl), a
            inc hl
            ld (hl), a
#endasm
End Function
