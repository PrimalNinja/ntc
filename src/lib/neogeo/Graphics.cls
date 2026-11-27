' Graphics - drawing on the SNK Neo Geo, which has no bitmap and keeps its tiles in ROM: the fix
' layer's 40 x 28 cells show block tiles of 2 x 4 dots (tiles 256-511 of the S ROM, which
' test/ngbuild.js puts there with NTC's font), so 80 x 112 dots, each 4 x 2 of the TV's pixels.
' NTC platform class: SNK Neo Geo, Neo Geo CD. A cell holds text or dots, not both. A cartridge
' with its own S ROM needs those 256 tiles in it. Pen 1 is fix palette 0 (white at the start),
' pen 2 palette 1 ... pen 16 palette 15 (Vdp.Color sets a palette's colour 1); a cell's 8 dots
' take the newest pen. Pen 0 draws nothing.
' Lines are XORed: drawing a line again takes it off and leaves what was under it. The same
' methods as the CPC's class, so programs carry over. One screen: DoubleBuffer, Flip and
' CopyText do nothing, Back() is 0. Made by tools/graphics/gen.js: change it there.
Option Explicit

Private m_pen As Integer, m_penset As Integer, m_noclip As Integer, m_on As Integer
Private m_sh(1119) As Byte

' the screen made ready (before the first dot)
Private Sub Start()
  m_on = 1
  If m_penset = 0 Then
    m_pen = 1
  End If
End Sub

' one dot XORed with the pen (x and y on the screen)
Private Sub Dot(ByVal x As Integer, ByVal y As Integer)
  Dim i As Integer, b As Integer
  If m_pen = 0 Then
    Exit Sub
  End If
  i = (y \ 4) * 40 + (x \ 2)
  b = m_sh(i) Xor Bits(7 - ((y And 3) * 2 + (x And 1)))
  m_sh(i) = b
  Vdp.Cell x \ 2, y \ 4, ((m_pen - 1) And 15) * 4096 + 256 + b
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
    If x0 >= 80 Or x1 >= 80 Or y0 >= 112 Or y1 >= 112 Then
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

' Pen p: the pen lines are drawn in (1-16: fix palettes 0-15; 0 = none)
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
  Height = 112
End Function

' Back(): the buffer drawn on now: always 0
Public Function Back() As Integer
  Back = 0
End Function

' Buffering(): True while double buffering is on: never
Public Function Buffering() As Integer
  Buffering = 0
End Function
