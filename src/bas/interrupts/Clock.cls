' Clock: Tick once a second
Option Class Interrupt 1
Public Seconds As Integer
Public Sub Tick()
  Seconds = Seconds + 1
  Locate 30, 3 : Print Seconds; "s ";
End Sub
