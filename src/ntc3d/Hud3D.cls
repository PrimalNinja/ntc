' Hud3D - NTC3D's HUD: text and numbers on the ULA's screen over the picture (drawn once, when
' they change: they cost nothing a picture), bars and the scanner in Layer 2 (drawn each picture,
' after Obj3D.Draw). The ULA's inks 1 - 7 are the text's colours: Ink sets them from Layer 2's.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
' Text on the ULA sits in 8 x 8 cells for its colour: put each piece at y = 8n or 8n + 1 (all 7
' rows in one cell row) and keep pieces of different colours in different cells.
Option Explicit

Private t As Integer

' Ink n, c: the ULA's ink n (1 - 7) the colour of Layer 2's colour c
Public Sub Ink(ByVal n As Integer, ByVal c As Integer)
  E3.UInk n, c
  E3.UInk n + 8, c
End Sub

' Wipe: all the ULA's text gone (see-through)
Public Sub Wipe()
  E3.UWipe
End Sub

' Clear y, x0, x1: the text cells from x0 to x1 in the rows text at y covers cleared
Public Sub Clear(ByVal y As Integer, ByVal x0 As Integer, ByVal x1 As Integer)
  E3.UClr y, x0, x1
End Sub

' Text x, y, s, ink: s on the ULA (over what's there: Clear first to replace)
Public Sub Text(ByVal x As Integer, ByVal y As Integer, ByVal s As String, ByVal ink As Integer)
  E3.uto = 1
  E3.Text x, y, s, ink
  E3.uto = 0
End Sub

' Num x, y, v, n, ink: v in n places (leading 0s blank), its cells cleared first
Public Sub Num(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer, ByVal n As Integer, ByVal ink As Integer)
  E3.UClr y, x, x + n * 6 - 1
  E3.uto = 1
  E3.Num x, y, v, n, ink
  E3.uto = 0
End Sub

' Cross x, y, ink: cross hairs round x, y on the ULA
Public Sub Cross(ByVal x As Integer, ByVal y As Integer, ByVal ink As Integer)
  E3.UBox x - 12, y - 1, 8, 2, ink : E3.UBox x + 5, y - 1, 8, 2, ink
  E3.UBox x - 1, y - 12, 2, 8, ink : E3.UBox x - 1, y + 5, 2, 8, ink
End Sub

' Bar x, y, w, h, v, vmax, c, bg: a bar in Layer 2: a box of bg, filled v / vmax of the way in c
Public Sub Bar(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal v As Integer, ByVal vmax As Integer, ByVal c As Integer, ByVal bg As Integer)
  E3.Box x, y, w, h, bg
  If v <= 0 Then Exit Sub
  If v > vmax Then v = vmax
  t = vmax \ 128 + 1                                ' (scaled down: (w - 2) x v must fit 16 bits)
  t = (w - 2) * (v \ t) \ (vmax \ t)
  E3.Box x + 1, y + 1, t, h - 2, c
End Sub

' Scanner x, y, w, h, frame, bg: the scanner in Layer 2: you in the middle, ahead up it, each
' object with a scanner colour (Obj3D.Mark) a dot (its place across and ahead / 1024)
Public Sub Scanner(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal frame As Integer, ByVal bg As Integer)
  E3.Box x, y, w, h, frame
  E3.Box x + 1, y + 1, w - 2, h - 2, bg
  E3.Dot x + w \ 2 - 1, y + h \ 2, 15
  E3.scene0 = 0 : E3.nobj = Obj3D.NOBJ
  E3.Radar x + w \ 2 - 1, y + h \ 2
End Sub
