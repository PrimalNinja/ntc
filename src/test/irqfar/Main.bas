' a ROM set: interrupts (Count, 300 a second) while Memory and List run - in another ROM of the
' set when it is split - and their results stay right
Dim h As Long, n As Long, i As Integer, s As Long, p As Long, r As Integer
h = List.Create(4)
For i = 1 To 400
  n = List.Append(h)
  List.SetWord n, 0, i
Next
p = Memory.Alloc(100)
For i = 1 To 300
  Memory.WriteWord p, i
  s = s + Memory.ReadWord(p)
Next
n = List.First(h)
Do While n <> 0
  s = s + List.GetWord(n, 0)
  n = List.NextOf(n)
Loop
r = Memory.Free(p)
Print "sum"; s; " count"; List.Count(h)
If Count.N > 20 Then Print "ticks ok" Else Print "ticks"; Count.N
Print "done"
