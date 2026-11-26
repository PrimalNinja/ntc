' Option Lot: two lots of code, each with its own variables, and a class in no lot that both use
Option Lot One = Stage1
Option Lot Two = Stage2
Dim i As Integer
Print "start"
Stage1.Run
Stage2.Run
Stage1.Run
For i = 1 To 3
  Stage1.Tick
  Stage2.Tick
Next
Print "total="; Shared.Total(); " calls="; Shared.Calls()
Stage1.Show
Stage2.Show
Print "lots="; System.Lots()
End
