Option Explicit
Option Page Pk = Art
Option Memory Reserved &H4000, &H4000
Dim r As Integer
Art.Fill
r = Art.Val()
Print "MEM"; Peek(&HA000)
Print "VAL"; r
End
