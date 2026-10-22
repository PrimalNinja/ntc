' ZxnScr - BOUNCE's screen on the ZX Spectrum Next: hardware sprites over the slot's own console.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The console (CyborgOS-Next's text screen: the tilemap) stays as it is - the program's Print
' shows there as always - and the balls are sprites on top of it. So the whole job of "only on
' screen while in front" is one NextReg, #15 (the layers): sprites on when the slot comes to the
' front, the console's own value back when it goes behind. The sprites themselves (their pattern
' RAM, their positions) are left alone while it's away: nothing else on CyborgOS uses them.
' Two programs that both use sprites would have to load their patterns again in Enter (BallGfx.ZxnLoad).
Option Explicit

Private con15 As Integer         ' NextReg #15 as the console had it (Init)
Private hsp As Integer

' Reg r, v / RegGet(r): a NextReg (port #243B picks it, #253B its value)
Public Sub Reg(ByVal r As Integer, ByVal v As Integer)
#asm
            pop hl
            ld a, (hl)
            ld bc, #243B
            out (c), a
            pop hl
            ld a, (hl)
            inc b
            out (c), a
#endasm
End Sub

Public Function RegGet(ByVal r As Integer) As Integer
#asm
            pop hl
            ld a, (hl)
            ld bc, #243B
            out (c), a
            inc b
            in a, (c)
            pop hl
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function

' Init: the console's layers noted, the ball's pattern into the sprite RAM
Public Sub Init()
  con15 = RegGet(&H15)
  BallGfx.ZxnLoad
End Sub

' Enter: the slot is in front - the sprites on (over the border too), the console's layer order kept
Public Sub Enter()
  Reg &H15, (con15 And &HFC) Or 3
End Sub

' Leave: the slot has gone behind - the layers as the console had them (its sprites off)
Public Sub Leave()
  Reg &H15, con15
End Sub

' Ball i, x, y: sprite i at the game's x (0-319), y (0-199): the Next's picture is 320 x 256,
' so y is moved down 28 to centre it
Public Sub Ball(ByVal i As Integer, ByVal x As Integer, ByVal y As Integer)
  y = y + 28
  Out &H303B, i
  Out &H57, x And 255
  Out &H57, y And 255
  Out &H57, (x \ 256) And 1          ' attribute 2: the 9th bit of x (no palette offset, no mirror)
  Out &H57, &H80                     ' attribute 3: shown, pattern 0
End Sub

' Show: the frame done (the sprites moved as Ball wrote them: nothing to flip)
Public Sub Show()
End Sub

' Done: the balls hidden, the console's layers back
Public Sub Done(ByVal n As Integer)
  Dim i As Integer
  For i = 0 To n - 1
    Out &H303B, i
    Out &H57, 0 : Out &H57, 0 : Out &H57, 0 : Out &H57, 0
  Next
  Leave
End Sub
