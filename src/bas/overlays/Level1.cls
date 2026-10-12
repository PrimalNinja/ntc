' Level 1: built into LEVEL1.PAG. Its code is in a RAM page, its variables in the program.
Option Class Overlay "LEVEL1"
Public Function Play(ByVal score As Integer) As Integer
  Dim i As Integer
  Banner "Level 1"
  For i = 1 To 3
    Print "  room "; i
  Next
  Play = 100
End Function
