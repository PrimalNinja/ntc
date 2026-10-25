' Asic - the CPC Plus's ASIC (6128 Plus, 464 Plus, GX4000): 16 hardware sprites of 16 x 16, 15
' colours of their own (from 4096), over any screen mode, each with its own position and size.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Init unlocks the ASIC (17 bytes to the CRTC's port) and pages its registers in at #4000-#7FFF
' (they stay in: the program must keep out of #4000-#7FFF - Option Reserve &H4000, &H4000):
'   #4000 + n * 256   sprite n's pixels: 16 x 16, a byte each (its low 4 bits: 0 see-through)
'   #6000 + n * 8     sprite n's X (word, in mode 2 pixels), Y (word, lines), size (byte:
'                     bits 3-2 across, 1-0 down: 0 off, 1, 2, 4 times)
'   #6422             the sprite palette: colours 1-15, 2 bytes each (red * 16 + blue, green)
' A sprite has one image of its own (no pattern numbers), so Anim copies each frame in (256
' bytes, when it changes). Positions here are in mode 1 pixels (320 x 200): each sprite pixel
' is drawn 2 mode 2 pixels wide (a mode 1 pixel), a line high, so 16 x 16 looks square.
'
' The game library's calls, the same in every chip's class (Zxn, Cpc, Asic, Tms9918, V9938,
' V9990): Init, Pattern, Put, Hide, Anim, Move, Bounds, Frame, X, Y. The ASIC's own: Palette.
' Text: the platform's own (Mode, Cls, Print).
' UNTESTED on the hardware: no emulator here runs a CPC Plus (MAME needs its ROMs). Checked only
' by the bytes it leaves at #4000-#7FFF on a plain CPC (where they land in RAM).
Option Explicit

Public Const Slots = 16

Private sx(15) As Integer, sy(15) As Integer, vx(15) As Integer, vy(15) As Integer
Private pt(15) As Integer, af(15) As Integer, ac(15) As Integer, ad(15) As Integer, at(15) As Integer
Private son(15) As Integer, shown(15) As Integer, pat(15) As Integer
Private bx0 As Integer, by0 As Integer, bx1 As Integer, by1 As Integer

' Init: the ASIC unlocked and paged in, every sprite off
Public Sub Init()
  Dim i As Integer
  For i = 1 To 17
    Out &HBC00, Choose(i, &HFF, &H00, &HFF, &H77, &HB3, &H51, &HA8, &HD4, &H62, &H39, &H9C, &H46, &H2B, &H15, &H8A, &HCD, &HEE)
  Next
  Out &H7F00, &HB8                 ' the ASIC's registers in at #4000
  For i = 0 To Slots - 1
    son(i) = 0 : vx(i) = 0 : vy(i) = 0 : ac(i) = 0 : shown(i) = -1
    Poke &H6004 + i * 8, 0         ' off
  Next
  bx0 = 0 : by0 = 0 : bx1 = 303 : by1 = 183
End Sub

' Palette a: sprite colours 1-15 from 30 bytes at address a (red * 16 + blue, green)
Public Sub Palette(ByVal a As Integer)
  Copy &H6422, a, 30
End Sub

' Pattern n, a: pattern n is the 256 bytes at address a
Public Sub Pattern(ByVal n As Integer, ByVal a As Integer)
  pat(n) = a
End Sub

Public Sub Put(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal p As Integer)
  sx(n) = x : sy(n) = y : pt(n) = p : son(n) = 1 : ac(n) = 0
End Sub

Public Sub Hide(ByVal n As Integer)
  son(n) = 0
End Sub

Public Sub Anim(ByVal n As Integer, ByVal first As Integer, ByVal count As Integer, ByVal delay As Integer)
  af(n) = first : ac(n) = count : ad(n) = delay : at(n) = delay : pt(n) = first
End Sub

Public Sub Move(ByVal n As Integer, ByVal dx As Integer, ByVal dy As Integer)
  vx(n) = dx : vy(n) = dy
End Sub

Public Sub Bounds(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  bx0 = x0 : by0 = y0 : bx1 = x1 : by1 = y1
End Sub

Public Function X(ByVal n As Integer) As Integer
  X = sx(n)
End Function

Public Function Y(ByVal n As Integer) As Integer
  Y = sy(n)
End Function

' Frame: wait for the frame, each sprite's position (and image, when its frame changed) to the
' ASIC, then each sprite moves and animates on
Public Sub Frame()
  Dim i As Integer, r As Integer
  WaitFrame
  For i = 0 To Slots - 1
    r = &H6000 + i * 8
    If son(i) Then
      If shown(i) <> pt(i) Then
        Copy &H4000 + i * 256, pat(pt(i)), 256
        shown(i) = pt(i)
      End If
      Doke r, sx(i) * 2
      Doke r + 2, sy(i)
      Poke r + 4, 9                ' 2 across (a mode 1 pixel), 1 down
    Else
      Poke r + 4, 0
    End If
  Next
  For i = 0 To Slots - 1
    If son(i) Then
      sx(i) = sx(i) + vx(i)
      If sx(i) < bx0 Then sx(i) = bx0 : vx(i) = -vx(i)
      If sx(i) > bx1 Then sx(i) = bx1 : vx(i) = -vx(i)
      sy(i) = sy(i) + vy(i)
      If sy(i) < by0 Then sy(i) = by0 : vy(i) = -vy(i)
      If sy(i) > by1 Then sy(i) = by1 : vy(i) = -vy(i)
      If ac(i) Then
        at(i) = at(i) - 1
        If at(i) <= 0 Then
          at(i) = ad(i)
          pt(i) = pt(i) + 1
          If pt(i) >= af(i) + ac(i) Then pt(i) = af(i)
        End If
      End If
    End If
  Next
End Sub

Private Sub WaitFrame()
#asm
            jp kw_frame
#endasm
End Sub

' Copy dst, src, n: n bytes
Private Sub Copy(ByVal dst As Integer, ByVal src As Integer, ByVal n As Integer)
#asm
            pop hl              ; dst
            ld e, (hl)
            inc hl
            ld d, (hl)
            pop hl              ; src
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            pop bc              ; n
            ld a, (bc)
            ld (cp_n), a
            inc bc
            ld a, (bc)
            ld b, a
            ld a, (cp_n)
            ld c, a
            ldir
            ret
cp_n:       db 0
#endasm
End Sub

' Pens a: pens 0-15 from 32 bytes at address a in the ASIC's palette (4096 colours: red * 16 +
' blue, green), the border as pen 0. The ASIC is unlocked, paged in for this only and paged out
' again (so #4000-#7FFF is RAM again: NTC's second screen can be there)
Public Sub Pens(ByVal a As Integer)
  Dim i As Integer
  For i = 1 To 17
    Out &HBC00, Choose(i, &HFF, &H00, &HFF, &H77, &HB3, &H51, &HA8, &HD4, &H62, &H39, &H9C, &H46, &H2B, &H15, &H8A, &HCD, &HEE)
  Next
  Out &H7F00, &HB8
  Copy &H6400, a, 32
  Poke &H6420, Peek(a) : Poke &H6421, Peek(a + 1)
  Out &H7F00, &HA0
End Sub
