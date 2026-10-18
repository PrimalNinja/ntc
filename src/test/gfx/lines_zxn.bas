' Graphics on the ZX Spectrum Next (Layer 2) - regress.sh counts the pixels of the buffer shown
' (NTC_SHOT): ARG 1 one buffer: a line along the top (320 pixels) and down the left (200), XOR -
' the corner they share off again: 518; ARG 2 double buffering: a line drawn twice on the buffer
' not shown (off again), then one of 91 pixels, flipped: 91
Option PressAnyKeyOnEnd
Dim a As Integer
a = Inkey
Do While a = 0 : a = Inkey : Loop
Graphics.Pen 1
If a = 49 Then
  Graphics.Line 0, 0, 319, 0
  Graphics.Line 0, 0, 0, 199
  Graphics.Line 400, 0, 0, 0       ' (an end off the screen: not drawn)
Else
  Graphics.DoubleBuffer 1
  Graphics.Line 5, 5, 300, 190
  Graphics.Line 300, 190, 5, 5     ' (the same line again, from the other end: off)
  Graphics.Line 10, 10, 100, 50
  Graphics.Flip
End If
Print "width"; Graphics.Width(); " back"; Graphics.Back(); " buffering"; Graphics.Buffering()
