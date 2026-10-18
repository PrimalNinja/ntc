' Level2: page Stage2, with its own copies of Maths and Stars
Public Sub Play()
  Score.Add Maths.Square(10)
  Stars.Add
  Print "Level 2: score "; Score.Total(); ", stars here "; Stars.Count()
End Sub
