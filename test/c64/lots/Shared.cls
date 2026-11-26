' in no lot: always in memory, called from anywhere
Private mTotal As Integer
Private mCalls As Integer

Public Sub Add(ByVal n As Integer)
  mTotal = mTotal + n
  mCalls = mCalls + 1
End Sub

Public Function Total() As Integer
  Total = mTotal
End Function

Public Function Calls() As Integer
  Calls = mCalls
End Function

Public Sub Say(ByVal s As String)
  Print "say "; s
End Sub
