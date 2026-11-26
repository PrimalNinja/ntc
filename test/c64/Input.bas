' typed input on the C64: a string, a number, then keys as they are pressed
Dim s As String, n As Integer, k As Integer, c As Integer
Input "name"; s
Input "number"; n
Print "["; s; "]"; n * 2
c = 0
Do While c < 3
  k = Inkey
  If k <> 0 Then
    Print "key "; k
    c = c + 1
  End If
Loop
Print "joy "; Joy.Read(2)
End
