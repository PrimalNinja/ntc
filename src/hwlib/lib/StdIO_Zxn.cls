' StdIO - the console on a ZX Spectrum Next's Layer 2 (the vector tests): the project's own StdIO, so
' Print, Cls, Locate and Mode go to Zxn's text. (Copied into a build as StdIO.cls.)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Public Sub PutStr(ByVal s As String Max 255)
  Zxn.PutStr s
End Sub

Public Sub NewLine()
  Zxn.NewLine
End Sub

Public Sub Cls()
  Zxn.Cls
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  Zxn.Locate x, y
End Sub

Public Sub Mode(ByVal m As Integer)
  Zxn.Mode m
End Sub
