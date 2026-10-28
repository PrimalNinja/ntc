' Graphics: lines in mode 0, 1 and 2, on #C000 and #4000 (double buffering), XOR - regress.sh
' sums of the top character row's bytes on each screen; the same lines drawn again: 0
Dim m As Integer, k As Integer, r(19) As Long
For m = 0 To 2
  Mode m
  Graphics.Pen 3
  Lines
  r(k) = Sum(&HC000) : k = k + 1
  Graphics.DoubleBuffer 1
  Lines
  r(k) = Sum(&H4000) : k = k + 1
  Lines
  r(k) = Sum(&H4000) : k = k + 1
  Graphics.DoubleBuffer 0
  Lines
  r(k) = Sum(&HC000) : k = k + 1
Next
Mode 1
For m = 0 To 2
  Print "mode"; m; ":"; r(m * 4); " "; r(m * 4 + 1); " "; r(m * 4 + 2); " "; r(m * 4 + 3)
Next
Sub Lines()
  Dim j As Integer
  For j = 0 To 7 : Graphics.Line j * 3, 0, j * 5 + 40, 7 : Next
  Graphics.Line 0, 7, Graphics.Width() - 1, 0
End Sub
Function Sum(ByVal base As Integer) As Long
  Dim y As Integer, x As Integer
  Sum = 0
  For y = 0 To 7
    For x = 0 To 79 : Sum = Sum + Peek(base + y * &H800 + x) * (x + 1) : Next
  Next
End Function
