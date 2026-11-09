' regress.sh: Option Memory Safe over several ranges - first fit, procedure by procedure, the fill
' goes on after the safe code (docs/memory-map.md rules 1 and 2)
' the memory map: two Safe ranges (first fit, procedure by procedure), the fill goes on after
' the safe code, the platform's firmware area is Reserved on its own
Option Memory Safe &H0100, &H0100     ' 256 bytes at #0100: too small for A or B, C fits
Option Memory Safe &H1000, &H0200     ' 512 bytes at #1000: A fits, B fits after it?
Option Memory Safe &H2000, &H0400     ' 1K at #2000: the rest
Option Safe "BIG" = Big
Dim r As Integer
r = Big.A(1)
Print "a "; r
r = Big.B(2)
Print "b "; r
r = Big.C(3)
Print "c "; r
Print "done"
End
