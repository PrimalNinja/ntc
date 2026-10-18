' a project's own console: it replaces the platform's StdIO, and Print, Input,
' Inkey, Inkey$, Cls and Locate in the rest of the project call these methods
Public Lines As Integer

Public Sub PutStr(ByVal s As String)
  Print "<"; UCase$(s); ">";
End Sub

Public Sub NewLine()
  Print
  Lines = Lines + 1
End Sub

Public Sub GetLine(s As String)
  Input s
  s = s & "!"
End Sub

Public Function GetKey() As Integer
  GetKey = 81
End Function

Public Sub Cls()
  Print "[cls]"
End Sub

Public Sub Locate(ByVal x As Integer, ByVal y As Integer)
  Print "[at "; x; ","; y; "]";
End Sub
