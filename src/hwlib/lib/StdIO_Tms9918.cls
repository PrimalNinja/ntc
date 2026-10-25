' StdIO - the console on a TMS9918 (MSX1, SC-3000, SG-1000): the project's own StdIO, so
' Print, Cls, Locate and Mode go to Tms9918's text. (Copied into a build as StdIO.cls.)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Public Sub PutStr(ByVal s As String Max 255)
  Tms9918.PutStr s
End Sub

Public Sub NewLine()
  Tms9918.NewLine
End Sub

Public Sub Cls()
  Tms9918.Cls
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  Tms9918.Locate x, y
End Sub

Public Sub Mode(ByVal m As Integer)
  Tms9918.Mode m
End Sub
