' Score: in no page, so in main RAM - every page can call it, and its variable is shared
Private t As Integer
Public Sub Add(ByVal n As Integer)
  t = t + n
End Sub
Public Function Total() As Integer
  Total = t
End Function
