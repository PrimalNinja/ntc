' Overlay classes checks (regress.sh): cpcmin / cpcfw, 128K and 64K
Option RomEnable 7
Option Reserve &H4000, &H4000
Dim d As Integer, a As Integer, total As Integer
Print "loaded"; Level1.Loaded(); Level2.Loaded()
' a data page in the window: overlay calls must put it back
d = Memory.AllocPage(Memory.TypeUser)
If d > 0 Then a = Memory.SelectPage(d) : Poke Memory.WindowStart, 123
Level1.Run 5
Print "page in window"; Memory.CurrentPage() = d; " data"; Peek(Memory.WindowStart)
Print "twice"; Level1.Twice(21); " score"; Level1.Score
Print "level2"; Level2.Chain(10); " total"; total; " score"; Level1.Score
Print "pages"; Level1.Page() > 0; Level2.Page() > 0; " map "; Memory.Map(1, 6)
Print "unload"; Level1.Unload(); Level1.Loaded(); " again"; Level1.Unload()
Print "reload"; Level1.Twice(3); Level1.Loaded()
Print "data"; Peek(Memory.WindowStart); Memory.CurrentPage() = d
Print "done"
End

Sub AddTotal(ByVal n As Integer)
  total = total + n
End Sub
