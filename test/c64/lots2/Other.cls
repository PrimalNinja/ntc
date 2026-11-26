Private mBumps As Integer
Private mNote As String
Public Sub Bump()
  mBumps = mBumps + 1
  mNote = mNote + "+"
End Sub
Public Sub Report()
  Print "other="; mBumps; " "; mNote
End Sub
