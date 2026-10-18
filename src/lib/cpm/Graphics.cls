' Graphics - drawing on the screen of an Amstrad CPC running CP/M, in mode 2 (640 x 200, 2
' pens: the console's mode), with XOR lines (drawing a line again takes it off and leaves what
' was under it). NTC platform class: CP/M, on an Amstrad CPC only (it writes to the CPC's
' screen memory, not through CP/M). No firmware: CP/M 2.2 has the screen at #C000 in the
' program's own 64K, drawn on directly; CP/M Plus (6128) runs programs in RAM configuration C2
' and has the screen in block 1, so the first line drawn copies the line loop to #C000 (common
' memory: the program must end below it, the Memory class's heap stays below it), and each line
' is drawn from there with C1 (the screen at #4000) and C2 put back. Lines assume the screen
' starts at its first byte: clear it (Cls, with Option Terminal VT52) before drawing. One
' screen: DoubleBuffer and CopyText do nothing, Flip does nothing, Back() is 0.
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

' Pen p: the pen lines are drawn in (mode 2: 0-1)
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

' DoubleBuffer on: nothing on CP/M (one screen)
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

' Flip: nothing on CP/M (one screen)
Public Sub Flip()
#asm
            ld (gfx_sp), sp
            ld sp, (ntc_csp)
            call gfx_flip
            ld sp, (gfx_sp)
#endasm
End Sub

' CopyText rows: nothing on CP/M (one screen)
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

' Width(): the screen's width in pixels (640)
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

' Back(): the screen drawn on: always 0 on CP/M
Public Function Back() As Integer
#asm
            pop hl
            ld (hl), 0
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
