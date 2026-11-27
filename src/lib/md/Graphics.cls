' Graphics - drawing on the Sega Mega Drive, which has no bitmap: plane B's 40 x 28 cells are
' given a tile each (tiles 128-1247) and the dots are written into those tiles, so 320 x 224.
' NTC platform class: Sega Mega Drive / Genesis. A copy of the picture is kept in RAM (9K, a
' bit a dot: the chip's memory is not read back). The text (plane A) stays in front. Pens are
' palette 0's colours 1-15 (Vdp.Color sets them; 1 is the text's colour); the 8 dots of a row
' that share a byte take the newest pen. Pen 0 draws nothing.
' Lines are XORed: drawing a line again takes it off and leaves what was under it. The same
' methods as the CPC's class, so programs carry over. One screen: DoubleBuffer, Flip and
' CopyText do nothing, Back() is 0. Made by tools/graphics/gen.js: change it there.
Option Explicit

Private m_pen As Integer, m_penset As Integer, m_noclip As Integer, m_on As Integer
Private m_sh(8959) As Byte, m_w(1) As Integer

' the screen made ready (before the first dot)
Private Sub Start()
  m_on = 1
  If m_penset = 0 Then
    m_pen = 1
  End If
  Dim cx As Integer, cy As Integer
  For cy = 0 To 27
    For cx = 0 To 39
      Vdp.Cell Vdp.PlaneB, cx, cy, 128 + cy * 40 + cx
    Next
  Next
End Sub

' one dot XORed with the pen (x and y on the screen)
Private Sub Dot(ByVal x As Integer, ByVal y As Integer)
  Dim i As Integer, b As Integer, p As Integer
  p = m_pen And 15
  If p = 0 Then
    Exit Sub
  End If
  i = y * 40 + (x \ 8)
  b = m_sh(i) Xor Bits(x And 7)
  m_sh(i) = b
  m_w(0) = Spread(b \ 16) * p
  m_w(1) = Spread(b And 15) * p
  Vdp.Copy VarPtr(m_w(0)), (128 + (y \ 8) * 40 + (x \ 8)) * 32 + (y And 7) * 4, 2
End Sub

' four dots (bits 3-0, the left one first) as a tile row's four colour 1 nibbles
Private Function Spread(ByVal n As Integer) As Integer
  Dim v As Integer
  v = 0
  If (n And 8) <> 0 Then
    v = v + &H1000
  End If
  If (n And 4) <> 0 Then
    v = v + &H0100
  End If
  If (n And 2) <> 0 Then
    v = v + &H0010
  End If
  If (n And 1) <> 0 Then
    v = v + &H0001
  End If
  Spread = v
End Function

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
    If x0 >= 320 Or x1 >= 320 Or y0 >= 224 Or y1 >= 224 Then
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

' Pen p: the pen lines are drawn in (1-15: palette 0's colours; 0 = none)
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
  Width = 320
End Function

' Height(): the height in pixels
Public Function Height() As Integer
  Height = 224
End Function

' Back(): the buffer drawn on now: always 0
Public Function Back() As Integer
  Back = 0
End Function

' Buffering(): True while double buffering is on: never
Public Function Buffering() As Integer
  Buffering = 0
End Function
