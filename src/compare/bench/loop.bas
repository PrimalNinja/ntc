' an empty counted loop, 10000 times
Option Explicit
Dim cnt As Integer
Print "go"
Turbo On
Bench
Turbo Off
Print "turbo "; cnt
Print "go"
Bench
Print "normal "; cnt
End
Sub Bench()
  Dim i As Integer
  For i = 1 To 10000
  Next
  cnt = i
End Sub
