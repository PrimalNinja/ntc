Option Class Overlay
' calls the other overlay class and the main program
Public Function Chain(ByVal n As Integer) As Integer
  Level1.Run n
  AddTotal n * 3
  Chain = Level1.Twice(n) + 1
End Function
