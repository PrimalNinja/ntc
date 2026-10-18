Option Explicit
Public Shared As Integer

Public Sub BumpShared()
  Shared = Shared + 1
End Sub

Private Function Helper() As Integer
  Helper = 2
End Function

Public Function Mod2Helper() As Integer
  Mod2Helper = Helper()
End Function
