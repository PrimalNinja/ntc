' Graphics - drawing on the TMS9918's Screen 2 (256 x 192) through the VDP class, a dot at a
' time by the CPU. NTC platform class: MSX (and the V9938 / V9990 card builds), Sega SC-3000,
' ColecoVision. The first line sets Screen 2 (the text goes: Mode or Cls brings the console
' back). Pens are the chip's colours 1-15; the chip keeps one ink for each 8 dots of a row, so
' lines of different pens that share 8 dots take the newer pen. Pen 1 is white (the pen that
' shows, as on the CPC); 2-15 are the chip's colours. Pen 0 draws nothing.
' Lines are XORed: drawing a line again takes it off and leaves what was under it. The same
' methods as the CPC's class, so programs carry over. One screen: DoubleBuffer, Flip and
' CopyText do nothing, Back() is 0. Made by tools/graphics/gen.js: change it there.
Option Explicit

Private m_pen As Integer, m_penset As Integer, m_noclip As Integer, m_on As Integer
Private m_ink As Integer

' the screen made ready (before the first dot)
Private Sub Start()
  m_on = 1
  If m_penset = 0 Then
    m_pen = 1
  End If
  VDP.Screen 2
  Ink
End Sub

' one dot XORed with the pen (x and y on the screen)
Private Sub Dot(ByVal x As Integer, ByVal y As Integer)
  Dim a As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = (y \ 8) * 256 + (x And 248) + (y And 7)
  VDP.VPoke a, VDP.VPeek(a) Xor Bits(x And 7)
  VDP.VPoke &H2000 + a, m_ink
End Sub

' the byte for the chip's colour table: the pen as the ink, black as the paper. Pen 1 is white
' (15), as the CPC's pen 1 is the one that shows; 2-15 are the chip's own colours
Private Sub Ink()
  m_ink = (m_pen And 15) * 16 + 1
  If m_pen = 1 Then
    m_ink = 241
  End If
End Sub

' the bit of dot n of a byte (0 = the left one)
Private Function Bits(ByVal n As Integer) As Integer
  Select Case n
    Case 0
      Bits = 128
    Case 1
      Bits = 64
    Case 2
      Bits = 32
    Case 3
      Bits = 16
    Case 4
      Bits = 8
    Case 5
      Bits = 4
    Case 6
      Bits = 2
    Case Else
      Bits = 1
  End Select
End Function

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
    If x0 >= 256 Or x1 >= 256 Or y0 >= 192 Or y1 >= 192 Then
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

' Pen p: the pen lines are drawn in (1 = white, 2-15 the chip's colours; 0 = none)
Public Sub Pen(ByVal p As Integer)
  m_pen = p
  m_penset = 1
  Ink
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
  Width = 256
End Function

' Height(): the height in pixels
Public Function Height() As Integer
  Height = 192
End Function

' Back(): the buffer drawn on now: always 0
Public Function Back() As Integer
  Back = 0
End Function

' Buffering(): True while double buffering is on: never
Public Function Buffering() As Integer
  Buffering = 0
End Function
