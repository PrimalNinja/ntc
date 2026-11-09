' regress.sh: Option Memory Reserved Skip - the gaps are left out of the file (packed, DISP), the
' start code moves the code above each gap up (lddr, highest first) before anything runs
' Reserved Skip: the file is packed, the start code moves the code above the gap up
Option Memory Reserved Skip &H0800, &H0400     ' a 1K gap at #0800: left out of the file
Option Memory Reserved Skip &H1800, &H0800     ' a 2K gap at #1800: left out too
Dim r As Integer, i As Integer
For i = 1 To 3
  r = r + F(i) + G(i)
Next
Print "r "; r
Print "done"
End
Function F(ByVal x As Integer) As Integer
  Dim t As Integer
  t = x
  t = t + x * 1 + 1 - x + 1 * x - 1 + x + 1
  t = t + x * 2 + 2 - x + 2 * x - 2 + x + 2
  t = t + x * 3 + 3 - x + 3 * x - 3 + x + 3
  t = t + x * 4 + 4 - x + 4 * x - 4 + x + 4
  t = t + x * 5 + 5 - x + 5 * x - 5 + x + 5
  t = t + x * 6 + 6 - x + 6 * x - 6 + x + 6
  F = t
End Function
Function G(ByVal x As Integer) As Integer
  Dim t As Integer
  t = x * 2
  t = t + x * 1 + 1 - x + 1 * x - 1 + x + 1
  t = t + x * 2 + 2 - x + 2 * x - 2 + x + 2
  t = t + x * 3 + 3 - x + 3 * x - 3 + x + 3
  G = t
End Function
