' build a 30 character string one character at a time, 200 times
Option Explicit
Dim s As String
Print "go"
Turbo On
Bench
Turbo Off
Print "turbo "; Len(s)
Print "go"
Bench
Print "normal "; Len(s)
End
Sub Bench()
  Dim i As Integer, j As Integer
  For i = 1 To 200
    s = ""
    For j = 1 To 30
      s = s + "x"
    Next
  Next
End Sub
