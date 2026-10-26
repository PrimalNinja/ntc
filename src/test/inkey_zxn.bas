' Inkey on the ZX Spectrum Next: the cursor keys (Caps Shift + 5-8, which the Next's cursor keys
' are) give the CPC firmware's codes - left 242, up 240, down 241, right 243; Caps + 0 is DEL (127)
Dim k As Integer, n As Integer
Do
  k = Inkey
  If k <> 0 Then Print k; " "; : n = n + 1
Loop Until n = 5
Print
Print "done"
