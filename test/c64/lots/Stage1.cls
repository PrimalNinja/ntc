' lot One
Private mRuns As Integer
Private mName As String
Private mSum As Integer

Public Sub Run()
  Dim i As Integer
  mRuns = mRuns + 1
  mName = "one"
  For i = 1 To 4
    Helper i
  Next
  Shared.Add 10
  Stage2.Ping
  Print "stage1 run"; mRuns; " sum"; mSum
End Sub

Public Sub Tick()
  mRuns = mRuns + 100
End Sub

Public Sub Show()
  Shared.Say mName + "/" + Str$(mRuns) + "/" + Str$(mSum)
End Sub

Private Sub Helper(ByVal k As Integer)
  mSum = mSum + k
End Sub
