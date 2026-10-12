' Level 1: page LEVEL1, built into OVERLAYS.001. Its code is in a RAM page, its variables in the program.
Option Class Overlay Level1
Public Function Play(ByVal score As Integer) As Integer
  Dim i As Integer
  Banner "Level 1"
  For i = 1 To 3
    Print "  room "; i
  Next
  Play = 100
End Function
Public Function Bonus() As Integer
  Bonus = 50
End Function
