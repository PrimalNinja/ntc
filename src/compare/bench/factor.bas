' Prime factors of 2..1500 by trial division, counted
Option Explicit
Const TOP = 1500
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
  Dim i As Integer, m As Integer, d As Integer
  cnt = 0
  For i = 2 To TOP
    m = i
    d = 2
    Do While d * d <= m
      If m Mod d = 0 Then
        cnt = cnt + 1
        m = m \ d
      Else
        d = d + 1
      End If
    Loop
    cnt = cnt + 1
  Next
End Sub
