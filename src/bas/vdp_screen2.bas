' VDP class on any TMS9918 (sc3000, msx): Screen 2 and PSet by the CPU, VPoke / VPeek
Dim x As Integer, y As Integer
VDP.Screen 2
For x = 0 To 255
  y = 96 + (x - 128) * (x - 128) \ 200
  If y < 192 Then VDP.PSet x, y, 11
  VDP.PSet x, 96, (x \ 16) + 0
Next
For y = 0 To 191 Step 2
  VDP.PSet 128, y, 15
Next
Do : Loop Until Inkey <> 0
Mode 1
Print "VPeek(0) ="; VDP.VPeek(0)
