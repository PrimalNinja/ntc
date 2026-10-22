' CpcScr - BOUNCE's screen on the Amstrad CPC: two screens in main RAM (#4000 and #C000), drawn
' in turn - one shown while the other is drawn, then the CRTC flipped to it (double buffering).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The CPC's screen is always in main RAM, and a CyborgOS slot runs with its own 64K bank in all
' four 16K places (RAM setting C2), so main RAM isn't there. To draw, the program changes the
' gate array's RAM setting for a moment:
'   C1 (main 0, 1, 2 + the bank's page 7): main RAM's #4000 screen at #4000
'   C3 (main 0, 3, 2 + the bank's page 7): main RAM's #C000 screen at #4000
' Both keep the slot's own top 16K (page 7: #C000-#FFFF) where it is, so the drawing code runs
' from there: it's copied to #E000 (this class) and #E200 (the compiled ball, BallGfx) at the
' start, and draws through the same window, #4000-#7FFF, whichever screen it is. The RAM setting
' it goes back to (the slot's own C2) is what came back in BC from a BDOS call: CyborgOS's switch
' into the bank loads BC with it (Hyp.Run), and the stub hands it through.
' While another setting is in, nothing may use the stack (it's in the program: main RAM then)
' and interrupts stay off (main RAM's #0038 isn't the slot's): turbo mode is off-interrupts, and
' the routines at #E000 / #E200 push nothing.
'
' The gate array's mode (2: 640 x 200, 2 colours) and the inks are the console's: CyborgOS's
' firmware sets them again itself (its interrupts run between the slots' turns), so a program
' can't keep its own. The CRTC is the program's: R12 / R13 (which screen) while it's in front.
' When another slot comes to the front, CyborgOS sets the CRTC and the #C000 screen back for its
' console by itself (ToFront: Scr, Show) - so Leave has nothing to do.
Option Explicit

Private own As Integer           ' the slot's own RAM setting: port (high byte), value (C2)
Private back As Integer          ' the screen being drawn: 1 (#4000) or 3 (#C000)
Private oldMode As Integer       ' the slot's console MODE before (Done puts it back)
Private hsp As Integer
Private adr As Integer

' Init: 0 if it can't run (the RAM setting not found), else 1
Public Function Init() As Integer
  Init = 0
  Bank
  ' a RAM setting is port #7F..#78 (high byte), value #C0-#FF with C2 in its low 3 bits
  If (own \ 256) < &H78 Or (own \ 256) > &H7F Or (own And &HC7) <> &HC2 Then Exit Function
  Install
  BallGfx.CpcInstall
  Doke &HE000, own
  oldMode = CybSys.Ask(9, 255)       ' the slot's console MODE (0-4) ...
  If CybSys.Ask(9, 0) = 0 Then       ' ... set to MODE 2 (80 x 25: no status strip, the CRTC
  End If                             ' as standard) - the screens' layout, 80 bytes a line
  Init = 1
End Function

' Bank: own = BC after a BDOS call (12: CP/M's version, which also ends the slot's turn)
Private Sub Bank()
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld c, 12
            ei
            call 5
            di
            ld ({own}), bc
            ld sp, ({hsp})
#endasm
End Sub

' Install: the window routines to #E000 (in the slot's page 7, seen in C1, C2 and C3 alike)
Private Sub Install()
#asm
            ld hl, cs_src
            ld de, #E000
            ld bc, cs_after - cs_src
            ldir
            jp cs_end
@cs_src:
            DISP #E000
@cs_own:     dw 0                    ; #E000 the slot's own RAM setting (B port, C value)
@cs_win:     dw 0                    ; #E002 the back screen's: C1 or C3
@cs_clear:                           ; the back screen all paper
            ld bc, (cs_win)
            out (c), c
            ld hl, #4000
            ld de, #4001
            ld bc, #3FFF
            ld (hl), 0
            ldir
            ld bc, (cs_own)
            out (c), c
            ret
@cs_char:                            ; DE = a character's 8 bytes (the slot's font at #F300 -
            ld bc, (cs_win)         ; page 7 too), HL = its top byte on the back screen
            out (c), c
            ld b, 8
@cs_ch_lp:
            ld a, (de)
            ld (hl), a
            inc de
            ld a, h
            add a, 8                ; the next pixel line: #800 on (within a character row)
            ld h, a
            djnz cs_ch_lp
            ld bc, (cs_own)
            out (c), c
            ret
            ENT
@cs_after:
            ASSERT ntc_free <= #E000, "BOUNCE's program and arrays must end below #E000 (the drawing code's place)"
@cs_end:
#endasm
End Sub

' SetBack p: draw on screen p (1: #4000, 3: #C000) - its RAM setting (C1 / C3) for the window
Private Sub SetBack(ByVal p As Integer)
  back = p
  Doke &HE002, (own And &HFFF8) Or p
End Sub

Private Sub ClearBack()
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            call cs_clear
            ld sp, ({hsp})
#endasm
End Sub

' Text col, row, s: on the back screen, from the slot's own font
Public Sub Text(ByVal col As Integer, ByVal row As Integer, ByVal s As String)
  Dim k As Integer
  For k = 1 To Len(s)
    adr = &H4000 + row * 80 + col + k - 1
    CharAt &HF300 + (Asc(Mid$(s, k, 1)) - 32) * 8
  Next
End Sub

Private Sub CharAt(ByVal f As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld hl, ({adr})
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            call cs_char
            ld sp, ({hsp})
#endasm
End Sub

' Enter: the slot is in front (CyborgOS has just drawn its console on #C000): both screens
' cleared and titled, #4000 shown, #C000 the one drawn
Public Sub Enter()
  SetBack 3 : ClearBack : Title
  SetBack 1 : ClearBack : Title
  Flip
End Sub

Private Sub Title()
  Text 1, 0, "BOUNCE - one .CYB, the CPC and the Next.  Q quits."
End Sub

' Leave: nothing - CyborgOS sets the CRTC and #C000 back for the slot it brings to the front
Public Sub Leave()
End Sub

' Ball i, x, y: the ball at the game's x (0-319, a multiple of 4: a byte is 4 of its pixels),
' y (0-199) on the back screen - with its border, which wipes where it was two frames ago
Public Sub Ball(ByVal i As Integer, ByVal x As Integer, ByVal y As Integer)
  y = y - BallGfx.BY
  adr = &H4000 + (y \ 8) * 80 + (y And 7) * 2048 + x \ 4 - BallGfx.BX
  DrawBall
End Sub

Private Sub DrawBall()
#asm
            ld hl, ({adr})
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            call cb_draw
            ld sp, ({hsp})
#endasm
End Sub

' Show: the back screen shown (the CRTC's R12 / R13: it takes them at its next frame), the
' other one the back now. The caller waits a frame before drawing again (BOUNCE's frame: 1/50 s)
Public Sub Show()
  Flip
End Sub

Private Sub Flip()
  Out &HBC00, 12
  If back = 1 Then Out &HBD00, &H10 Else Out &HBD00, &H30
  Out &HBC00, 13
  Out &HBD00, 0
  If back = 1 Then SetBack 3 Else SetBack 1
End Sub

' Done: the slot's console MODE back - CyborgOS sets the CRTC for it and clears #C000
Public Sub Done(ByVal n As Integer)
  If CybSys.Ask(9, oldMode) = 0 Then
  End If
End Sub
