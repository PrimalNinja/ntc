' Graphics - drawing on the CPC screen in any mode (0: 160 x 200, 16 pens; 1: 320 x 200, 4
' pens; 2: 640 x 200, 2 pens), with XOR lines (drawing a line again takes it off and leaves
' what was under it), and double buffering: two screens, #C000 and main RAM's #4000-#7FFF,
' one shown while the other is drawn on. NTC platform class: Amstrad CPC (direct hardware).
' Double buffering takes main RAM's #4000 (RAM page 1): with Option Memory CPCExpansion
' take page 1 first (Memory.AllocPage until it gives 1) so nothing else is put there. RAM
' pages still work: the CRTC always shows main RAM, and drawing puts main RAM in the window
' only while it writes. Text (Print) goes to #C000: CopyText puts it on the other screen.
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

' Pen p: the pen lines are drawn in (mode 0: 0-15, mode 1: 0-3, mode 2: 0-1)
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

' DoubleBuffer on: two screens (#C000 copied to #4000, drawing goes to the one not shown;
' Flip shows it). Off: #C000 shown and drawn on
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

' Flip: double buffering - wait for the frame flyback, show the screen just drawn, draw on
' the other one. Nothing without double buffering
Public Sub Flip()
#asm
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_flip
            ld sp, (gfx_sp)
#endasm
End Sub

' CopyText rows: the top rows of text copied from #C000 to the other screen
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

' Width(): the screen's width in pixels in this mode (160, 320, 640)
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

' Back(): the screen drawn on now: 0 = #C000, 1 = #4000
Public Function Back() As Integer
#asm
            pop hl
            ld a, (gfx_base)
            cp #40
            ld a, 0
            jr nz, bk0
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
