' Graphics - drawing on the Commodore 64's text screen with block characters: each of the 40 x
' 25 characters is 2 dots wide and 2 high, so 80 x 50 dots of 4 x 4 pixels. NTC platform class:
' Commodore 64 + REU. The first line makes characters 128-143 the sixteen blocks (in the
' program's own font at $E800). A character cell holds text or dots, not both. Pens are the
' C64's colours 1-15 (1 white); a cell's 4 dots take the newest pen. Pen 0 draws nothing.
' Lines are XORed: drawing a line again takes it off and leaves what was under it. The same
' methods as the CPC's class, so programs carry over. One screen: DoubleBuffer, Flip and
' CopyText do nothing, Back() is 0. Made by tools/graphics/gen.js: change it there.
Option Explicit

Private m_pen As Integer, m_penset As Integer, m_noclip As Integer, m_on As Integer

' the screen made ready (before the first dot)
Private Sub Start()
  m_on = 1
  If m_penset = 0 Then
    m_pen = 1
  End If
  Dim c As Integer, r As Integer, v As Integer
  For c = 0 To 15
    v = 0
    If (c And 1) <> 0 Then
      v = v + 240
    End If
    If (c And 2) <> 0 Then
      v = v + 15
    End If
    For r = 0 To 3
      Poke &HE800 + (128 + c) * 8 + r, v
    Next
    v = 0
    If (c And 4) <> 0 Then
      v = v + 240
    End If
    If (c And 8) <> 0 Then
      v = v + 15
    End If
    For r = 4 To 7
      Poke &HE800 + (128 + c) * 8 + r, v
    Next
  Next
End Sub

' one dot XORed with the pen (x and y on the screen)
Private Sub Dot(ByVal x As Integer, ByVal y As Integer)
  Dim a As Integer, c As Integer, m As Integer
  If (m_pen And 15) = 0 Then
    Exit Sub
  End If
  a = (y \ 2) * 40 + (x \ 2)
  c = Peek(&HE000 + a)
  If c < 128 Or c > 143 Then
    c = 128
  End If
  m = 1
  If (x And 1) <> 0 Then
    m = 2
  End If
  If (y And 1) <> 0 Then
    m = m * 4
  End If
  Poke &HE000 + a, 128 + ((c - 128) Xor m)
  Poke &HD800 + a, m_pen And 15
End Sub

' Line x0, y0, x1, y1: a line in the pen (XOR), in pixels
Public Sub Line(ByVal x0 As Integer, ByVal y0 As Integer, ByVal x1 As Integer, ByVal y1 As Integer)
  Dim x As Integer, y As Integer, dx As Integer, dy As Integer, sx As Integer, sy As Integer
  Dim e As Integer, e2 As Integer, n As Integer
  If m_on = 0 Then
    Start
  End If
  If m_noclip = 0 Then
    If x0 < 0 Or x1 < 0 Or y0 < 0 Or y1 < 0 Then
      Exit Sub
    End If
    If x0 >= 80 Or x1 >= 80 Or y0 >= 50 Or y1 >= 50 Then
      Exit Sub
    End If
  End If
  x = x0
  y = y0
  dx = x1 - x0
  sx = 1
  If dx < 0 Then
    dx = 0 - dx
    sx = -1
  End If
  dy = y1 - y0
  sy = 1
  If dy < 0 Then
    dy = 0 - dy
    sy = -1
  End If
  n = dx
  If dy > dx Then
    n = dy
  End If
  e = dx - dy
  Do
    Dot x, y
    If n = 0 Then
      Exit Do
    End If
    n = n - 1
    e2 = e + e
    If e2 > 0 - dy Then
      e = e - dy
      x = x + sx
    End If
    If e2 < dx Then
      e = e + dx
      y = y + sy
    End If
  Loop
End Sub

' Plot x, y: one pixel in the pen (XOR)
Public Sub Plot(ByVal x As Integer, ByVal y As Integer)
  Line x, y, x, y
End Sub

' Pen p: the pen lines are drawn in (1-15: the C64's colours; 0 = none)
Public Sub Pen(ByVal p As Integer)
  m_pen = p
  m_penset = 1
End Sub

' Clip on: on (the default) a line with an end off the screen isn't drawn; off: no checks
' (the program keeps every point on the screen, or it writes over memory)
Public Sub Clip(ByVal on As Integer)
  m_noclip = 0
  If on = 0 Then
    m_noclip = 1
  End If
End Sub

' DoubleBuffer on: nothing here (one screen)
Public Sub DoubleBuffer(ByVal on As Integer)
End Sub

' Flip: nothing here (one screen)
Public Sub Flip()
End Sub

' CopyText rows: nothing here (one screen)
Public Sub CopyText(ByVal rows As Integer)
End Sub

' Width(): the width in pixels
Public Function Width() As Integer
  Width = 80
End Function

' Height(): the height in pixels
Public Function Height() As Integer
  Height = 50
End Function

' Back(): the buffer drawn on now: always 0
Public Function Back() As Integer
  Back = 0
End Function

' Buffering(): True while double buffering is on: never
Public Function Buffering() As Integer
  Buffering = 0
End Function
