' a "driver": its own page (Option Page in Main), a Tick 50 times a second, its state paged
Option Class Interrupt 50
Private Paged n As Integer
Public Sub Tick()
  n = n + 1
End Sub
Public Function Count() As Integer
  Count = n
End Function
