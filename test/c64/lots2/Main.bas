' a task that runs inside a lot, taking turns with the main program, which calls another lot
Option Lot A = Worker
Option Lot B = Other
Dim i As Integer, t As Integer
t = Task.Start(AddressOf Worker.Go)
For i = 1 To 5
  Other.Bump
  Task.Yield
Next
Task.Yield
Worker.Report
Other.Report
Print "tasks="; Task.Count()
End
