' CRUNCH: a CyborgOS test program (build for cpm): sums 1 to 30000 with no BDOS call on the
' way - it only gives up the CPU when an interrupt stops it (at NTC's safe points)
Option Explicit
Dim i As Integer, x As Long
Print "Crunch - summing"
For i = 1 To 30000
  x = x + i
Next
Print "Crunch: "; x
