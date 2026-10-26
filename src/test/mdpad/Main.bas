' Pad.Read on a 6 button pad (md): the buttons held, printed every 30 frames (mdrun.py --pad
' holds them: X Y Z Mode as well as the 3 button ones)
Dim i As Integer, j As Integer
For i = 1 To 12
  For j = 1 To 30
    Frame
  Next
  Print "pad "; Pad.Read(1)
Next
