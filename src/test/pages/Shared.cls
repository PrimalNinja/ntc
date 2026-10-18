' in LEVEL1 and LEVEL2 (a copy in each); labels inside (For, GoTo, GoSub) are renamed in the copy
Public Function Sum(ByVal n As Integer) As Integer
  Dim i As Integer, t As Integer
  For i = 1 To n
    t = t + i
  Next
  If t > 5 Then GoTo big
  Sum = t
  Exit Function
big:
  GoSub addone
  Sum = t
  Exit Function
addone:
  t = t + 1
  Return
End Function
Public Function Odd(ByVal n As Integer) As Integer
  Odd = n Mod 2
End Function
' a call to a class only in LEVEL1: local from LEVEL1's copy, a page switch from LEVEL2's
Public Function Ext(ByVal n As Integer) As Integer
  If n > 100 Then GoTo done
  n = n + OnlyOne.Ten()
done:
  Ext = n
End Function
