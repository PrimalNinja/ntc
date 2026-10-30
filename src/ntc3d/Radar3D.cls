' Radar3D - NTC3D's Elite style instruments for Layer 2 (draw them each picture, after Obj3D.Draw):
' the scanner with stalks and the compass. Optional: a game names "Radar3D.cls" in game.json's
' "extras" (tools/build.js adds it from the framework's folder); Hud3D's flat Scanner needs nothing.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private va As Long, vb As Long, vc As Long, vd As Long
Private ox As Integer, oy As Integer, oz As Integer

' Scanner x, y, w, h, frame, bg, rx, rz, ry, tab: the scanner box (the frame colour, the background),
' you in the middle, ahead up it. Each object is a dot on a stalk: the dot's place across is its x
' / rx, ahead its z / rz, and its stalk (from the plane up or down to the dot) its y / ry pixels
' (rx 440, rz 1000, ry 900 give about 16000 units across). An object's colour: tab 0, its
' Obj3D.Mark colour (0: not shown); tab the address (VarPtr) of an Integer array of colours indexed by
' the object's otype (0: not shown) - a game that sets otype needn't Mark each one
Public Sub Scanner(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal frame As Integer, ByVal bg As Integer, ByVal rx As Integer, ByVal rz As Integer, ByVal ry As Integer, ByVal tab As Integer)
  Dim i As Integer, c As Integer, sx As Integer, sy As Integer, hg As Integer, cx As Integer, cy As Integer, tp As Integer, ln As Integer
  E3.Box x, y, w, h, frame
  E3.Box x + 1, y + 1, w - 2, h - 2, bg
  cx = x + w \ 2 : cy = y + h \ 2
  E3.Box x + 2, cy, w - 4, 1, frame - 6
  E3.Dot cx - 1, cy - 1, 15
  For i = 0 To Obj3D.NOBJ - 1
    If Obj3D.ocls(i) <> 0 Then
      If tab = 0 Then
        c = (E3.obj(i * 8 + 7) \ 256) And 255
      Else
        c = Deek(tab + Obj3D.otype(i) * 2)
      End If
      If c <> 0 Then
        sx = cx + E3.vwx(i) \ rx : sy = cy - E3.vwz(i) \ rz : hg = E3.vwy(i) \ ry
        If hg > 14 Then hg = 14
        If hg < -14 Then hg = -14
        If sx > x + 1 And sx < x + w - 3 And sy > y + 1 And sy < y + h - 3 And sy - hg > y + 1 And sy - hg < y + h - 3 Then
          If hg > 0 Then tp = sy - hg Else tp = sy
          ln = Abs(hg)
          If ln > 0 Then E3.Box sx, tp, 1, ln, frame + 3
          E3.Dot sx - 1, sy - hg - 1, c
        End If
      End If
    End If
  Next
End Sub

' Compass x, y, w, h, frame, bg, tx, ty, tz, ahead, behind: a box with a cross; the dot is where the
' target is: tx, ty, tz is the way to it in the WORLD (any units to 500: Galaxy3D.dx, dy, dz do), the
' dot across and up by the camera's turn, colour ahead when it's in front of you, behind when it's
' behind. A target of 0, 0, 0 (none) draws the box only
Public Sub Compass(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal frame As Integer, ByVal bg As Integer, ByVal tx As Integer, ByVal ty As Integer, ByVal tz As Integer, ByVal ahead As Integer, ByVal behind As Integer)
  Dim cx As Integer, cy As Integer, l As Integer, c As Integer
  E3.Box x, y, w, h, frame
  E3.Box x + 1, y + 1, w - 2, h - 2, bg
  cx = x + w \ 2 : cy = y + h \ 2
  E3.Box x + 3, cy, w - 6, 1, frame - 6
  If tx = 0 And ty = 0 And tz = 0 Then Exit Sub
  ox = Dot3(tx, ty, tz, 0) : oy = Dot3(tx, ty, tz, 3) : oz = Dot3(tx, ty, tz, 6)
  va = ox \ 16 : va = va * (ox \ 16) : vb = oy \ 16 : vb = vb * (oy \ 16) : vc = oz \ 16 : vc = vc * (oz \ 16)
  l = Isqrt(va + vb + vc) * 16                    ' (a sixteenth size: Isqrt's top is 30000 squared)
  If l < 16 Then l = 16
  If oz >= 0 Then c = ahead Else c = behind
  E3.Dot cx + (ox * (w \ 2 - 4)) \ l - 1, cy - (oy * (h \ 2 - 5)) \ l - 1, c
End Sub

' Isqrt(v): the whole number square root of a Long, 0 .. 900,000,000 (NTC's own Sqr takes only an Integer:
' over 32767 it gives 0 or rubbish)
Public Function Isqrt(ByVal v As Long) As Integer
  Dim lo As Integer, hi As Integer, m As Integer
  lo = 0 : hi = 30000
  Do While lo < hi
    m = lo + (hi - lo + 1) \ 2
    vd = m : vd = vd * m
    If vd <= v Then lo = m Else hi = m - 1
  Loop
  Isqrt = lo
End Function

' Dot3(tx, ty, tz, b): the vector's part along the camera's axis b (E3.cm: 0 right, 3 up, 6 ahead), in
' 16ths of the units given (all in 16 bit: the vector to 500, as Galaxy3D's offsets are)
Private Function Dot3(ByVal tx As Integer, ByVal ty As Integer, ByVal tz As Integer, ByVal b As Integer) As Integer
  Dot3 = (tx \ 16) * (E3.cm(b) \ 64) + (ty \ 16) * (E3.cm(b + 1) \ 64) + (tz \ 16) * (E3.cm(b + 2) \ 64)
End Function
