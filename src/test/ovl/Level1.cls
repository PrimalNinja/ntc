Option Class Overlay "LEVEL1"
Public Score As Integer
Public Sub Run(ByVal n As Integer)
  Score = Score + n
  Print "run"; n
End Sub
Public Function Twice(ByVal n As Integer) As Integer
  Twice = n * 2
End Function
