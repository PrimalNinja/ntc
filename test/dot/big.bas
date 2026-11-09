' a Large Model dot command: .big args
Dim s As String
Dim p As Integer, n As Integer, i As Integer
s = System.CommandLine()
Print "Large: ["; s; "]"
Print "pages "; Memory.Pages(); " model "; Memory.Model()
p = Memory.AllocPage(Memory.TypeUser)
Print "page "; p
If p > 0 Then
  Memory.SelectPage p
  For i = 0 To 9
    Poke &H4000 + i, i * 3
  Next
  n = 0
  For i = 0 To 9
    n = n + Peek(&H4000 + i)
  Next
  Print "sum "; n
  Memory.FreePage p
End If
Print "done"
End
