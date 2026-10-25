' V9990 class: a bit map screen on a V9990 (msx9990, or msx with a GFX9000 / Video9000;
' cpc9990, or any CPC platform with a V9990 through the AMSDAP adapter or the Powergraph)
Dim i As Integer
V9990.Screen 1
For i = 0 To 15
  V9990.Box i * 16, 0, 16, 20, i
Next
For i = 0 To 255 Step 8
  V9990.Line 128, 116, i, 30, (i \ 8) And 15
  V9990.Line 128, 116, i, 211, ((i \ 8) + 4) And 15
Next
V9990.Copy 0, 0, 0, 24, 128, 20
V9990.PSet 10, 200, 15
Do : Loop Until Inkey <> 0
