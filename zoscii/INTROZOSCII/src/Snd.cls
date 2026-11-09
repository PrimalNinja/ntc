' Snd - a beep on the AY chip's channel C. Call Frame once a frame. (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Private t As Integer, p As Integer

Private Sub W(ByVal r As Integer, ByVal v As Integer)
  Out &HFFFD, r
  Out &HBFFD, v
End Sub

Public Sub Init()
  Dim i As Integer
  For i = 0 To 13
    W i, 0
  Next
  W 7, &H38
End Sub

' Beep n: a short note, n 1 (low) .. 12
Public Sub Beep(ByVal n As Integer)
  p = 700 - n * 45
  W 4, p And 255
  W 5, p \ 256
  W 10, 10
  For t = 1 To 5
    Vid.Sync
  Next
  W 10, 0
End Sub

Public Sub Frame()
  If t > 0 Then
    t = t - 1
    If t = 0 Then W 10, 0
  End If
End Sub
