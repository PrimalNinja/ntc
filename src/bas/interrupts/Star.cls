' Star: Tick every frame, moving a star along the top line
Option Class Interrupt Frame
Public Moves As Integer
Dim x As Integer
Public Sub Tick()
  Locate x + 1, 1 : Print " ";
  x = (x + 1) Mod 39
  Locate x + 1, 1 : Print "*";
  Moves = Moves + 1
End Sub
