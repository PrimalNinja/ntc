Private mCount As Integer
Private mNote As String
Public Sub Go()
  mNote = "w"
  Do While mCount < 5
    mCount = mCount + 1
    mNote = mNote + "."
    Task.Yield
  Loop
End Sub
Public Sub Report()
  Print "worker="; mCount; " "; mNote
End Sub
