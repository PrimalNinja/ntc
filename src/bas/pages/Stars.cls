' Stars: copied into STAGE1 and STAGE2; a paged variable, so each copy counts its own
Private Paged n As Integer
Public Sub Add()
  n = n + 1
End Sub
Public Function Count() As Integer
  Count = n
End Function
