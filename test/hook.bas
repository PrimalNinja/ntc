Dim n As Integer, i As Integer, a As Integer, b As Integer
Interrupt Tick
Do While n < 5
  i = i + 1
Loop
Interrupt Off
a = n
For i = 1 To 3000
Next
b = n
Print "hook ran"; (a = b); (n >= 5)
End
Sub Tick()
  n = n + 1
End Sub
