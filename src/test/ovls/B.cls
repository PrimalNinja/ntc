Option Class Overlay "OVB.PAG"           ' a file name of its own (with an extension); A is numbered (MAIN.001)
Public Function Chain(ByVal x As Integer) As Integer
  Chain = A.Twice(x) + A.Twice(1)
End Function
Public Function Mid(ByVal x As Integer) As Integer
  Note "B"
  Mid = A.Twice(x) + 10
  Note "B again"
End Function
