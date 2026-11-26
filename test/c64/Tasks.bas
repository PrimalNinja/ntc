' the Task class: tasks taking turns, sleeping, ending
Dim n(15) As Integer
Dim i As Integer, t As Integer, a As Integer, b As Integer, c As Integer
Dim s As String

Sub Counter()
  Dim me As Integer
  Do
    me = Task.Id()
    n(me) = n(me) + 1
    Task.Yield
  Loop
End Sub

Sub Sleeper()
  Do
    n(15) = n(15) + 1
    Task.Sleep 10
  Loop
End Sub

Sub Once()
  s = s + "once "
End Sub

a = Task.Start(AddressOf Counter)
b = Task.Start(AddressOf Counter)
c = Task.Start(AddressOf Sleeper)
Print "ids="; a; b; c; " count="; Task.Count()
For i = 1 To 100
  Task.Yield
Next
Print "turns="; n(a); n(b)
t = Task.Start(AddressOf Once)
Task.Yield
Task.Yield
Print "s="; s; "count="; Task.Count()
Task.Stop a
For i = 1 To 50
  Task.Yield
Next
Print "after stop="; n(a); n(b)
t = Ticks
Task.Sleep 50
Print "slept="; (Ticks - t >= 50) And (Ticks - t <= 52); " sleeper="; (n(15) >= 5) And (n(15) <= 7)
End
