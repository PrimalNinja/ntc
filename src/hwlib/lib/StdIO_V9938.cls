' StdIO - the console on a V9938 (MSX2): the project's own StdIO, so Print, Cls, Locate and Mode go
' to V9938's text. (Copied into a build as StdIO.cls.)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Public Sub PutStr(ByVal s As String Max 255)
  V9938.PutStr s
End Sub

Public Sub NewLine()
  V9938.NewLine
End Sub

Public Sub Cls()
  V9938.Cls
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  V9938.Locate x, y
End Sub

Public Sub Mode(ByVal m As Integer)
  V9938.Mode m
End Sub
