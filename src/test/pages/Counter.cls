' in LEVEL1 and LEVEL2: its paged variable is separate in each copy; main uses the home copy (LEVEL1)
Private Paged n As Integer
Private Paged t As String

Public Function Bump() As Integer
  n = n + 1
  t = t + "*"
  Bump = n
End Function
Public Function Marks() As String
  Marks = t
End Function
