' Graphics - drawing on the TI-89's LCD (160 x 100, on or off), straight into its bitmap at
' $4C00 (30 bytes a row). NTC platform class: TI-89 / TI-92 Plus / Voyage 200 (the bigger
' screens show the same 160 x 100 at their top left). Pen 0 draws nothing.
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
End Sub

' one dot XORed with the pen (x and y on the screen)
Private Sub Dot(ByVal x As Integer, ByVal y As Integer)
  Dim a As Integer, m As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  a = &H4C00 + y * 30 + (x \ 8)
  m = Bits(x And 7)
  Poke a, Peek(a) Xor m
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
    If x0 >= 160 Or x1 >= 160 Or y0 >= 100 Or y1 >= 100 Then
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

' Pen p: the pen lines are drawn in (0 = none, anything else = on)
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
  Width = 160
End Function

' Height(): the height in pixels
Public Function Height() As Integer
  Height = 100
End Function

' Back(): the buffer drawn on now: always 0
Public Function Back() As Integer
  Back = 0
End Function

' Buffering(): True while double buffering is on: never
Public Function Buffering() As Integer
  Buffering = 0
End Function
