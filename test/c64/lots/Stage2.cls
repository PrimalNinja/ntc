' lot Two
Private mRuns As Integer
Private mPings As Integer
Private mName As String

Public Sub Run()
  mRuns = mRuns + 1
  mName = "two"
  Shared.Add Twice(7)
  Print "stage2 run"; mRuns; " pings"; mPings
End Sub

Public Sub Tick()
  mRuns = mRuns + 1000
End Sub

Public Sub Ping()
  mPings = mPings + 1
End Sub

Public Sub Show()
  Shared.Say mName + ":" + Str$(mRuns) + ":" + Str$(mPings)
End Sub

Private Function Twice(ByVal n As Integer) As Integer
  Twice = n * 2
End Function
