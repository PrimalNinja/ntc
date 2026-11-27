' Graphics - drawing on the FM Towns' back layer (256 x 240, 32768 colours) through the Vdp
' class (GPixel, GPlot). NTC platform class: Fujitsu FM Towns. The first line sets the Vdp
' class's screen up (Vdp.Init). Pen 1 is white (the pen that shows, as on the CPC); any other
' pen is the 15 bit colour itself (green in bits 10-14, red in 5-9, blue in 0-4). Pen 0 draws
' nothing.
' Lines are XORed: drawing a line again takes it off and leaves what was under it. The same
' methods as the CPC's class, so programs carry over. One screen: DoubleBuffer, Flip and
' CopyText do nothing, Back() is 0. Made by tools/graphics/gen.js: change it there.
Option Explicit

Private m_pen As Integer, m_penset As Integer, m_noclip As Integer, m_on As Integer
Private m_col As Integer

' the screen made ready (before the first dot)
Private Sub Start()
  m_on = 1
  If m_penset = 0 Then
    m_pen = 1
  End If
  Vdp.Init
  Ink
End Sub

' one dot XORed with the pen (x and y on the screen)
Private Sub Dot(ByVal x As Integer, ByVal y As Integer)
  If m_col = 0 Then
    Exit Sub
  End If
  Vdp.GPlot x, y, Vdp.GPixel(x, y) Xor m_col
End Sub

Private Sub Ink()
  m_col = m_pen
  If m_pen = 1 Then
    m_col = &H7FFF
  End If
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
    If x0 >= 256 Or x1 >= 256 Or y0 >= 240 Or y1 >= 240 Then
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

' Pen p: the pen lines are drawn in (1 = white, else a 15 bit colour; 0 = none)
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
  Height = 240
End Function

' Back(): the buffer drawn on now: always 0
Public Function Back() As Integer
  Back = 0
End Function

' Buffering(): True while double buffering is on: never
Public Function Buffering() As Integer
  Buffering = 0
End Function
