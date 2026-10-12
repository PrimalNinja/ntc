' Level1: page STAGE1, with its own copies of Maths and Stars
Public Sub Play()
  Dim i As Integer
  For i = 1 To 3
    Score.Add Maths.Square(i)
    Stars.Add
  Next
  Print "Level 1: score "; Score.Total(); ", stars here "; Stars.Count()
End Sub
