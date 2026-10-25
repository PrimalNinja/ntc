' StdIO - the console on a V9990 (MSX GFX9000, CPC V9990 boards): the project's own StdIO, so
' Print, Cls, Locate and Mode go to V9990's text. (Copied into a build as StdIO.cls.)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Public Sub PutStr(ByVal s As String Max 255)
  V9990.PutStr s
End Sub

Public Sub NewLine()
  V9990.NewLine
End Sub

Public Sub Cls()
  V9990.Cls
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  V9990.Locate x, y
End Sub

Public Sub Mode(ByVal m As Integer)
  V9990.Mode m
End Sub
