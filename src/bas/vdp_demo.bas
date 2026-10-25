' VDP class: a V9938 / V9958 graphics screen (msx MSX2 and up, msxcard; cpc, cpcmin, cpcfw,
' cpccard with an MSX V9938 card through the AMSDAP adapter). Screen 5, boxes, lines, a copy
Dim i As Integer
VDP.Screen 5
For i = 0 To 15
  VDP.Box i * 16, 0, 16, 20, i
Next
For i = 0 To 255 Step 8
  VDP.Line 128, 116, i, 30, (i \ 8) And 15
  VDP.Line 128, 116, i, 211, ((i \ 8) + 4) And 15
Next
VDP.Copy 0, 0, 0, 24, 128, 20
VDP.PSet 10, 200, 15
Print "Point:"; VDP.Point(10, 200)
Do : Loop Until Inkey <> 0
Mode 1
Print "Back to text. Point was"; VDP.Point(10, 200)
