' RENAME: a file renamed, in CyborgOS (build for cpm).
'   RENAME [v:]name newname           a name with no volume: this slot's drive; newname: NAME.EXT
' Any file the drive has; a name that is taken already is refused.
Option Explicit
Dim a As String Max 40, v As String Max 2, f As String Max 40, nn As String Max 40
Dim p As Integer, r As Integer

a = UCase$(Trim$(System.CommandLine()))
p = InStr(a, " ")
If p = 0 Then Print "RENAME [v:]name newname" : End
nn = Trim$(Mid$(a, p + 1))
a = Left$(a, p - 1)
If Mid$(a, 2, 1) = ":" Then
  v = Left$(a, 2) : f = Mid$(a, 3)
Else
  v = FileSystem.CurrentVolume() + ":" : f = a
End If
If Mid$(nn, 2, 1) = ":" Then
  If Left$(nn, 2) <> v Then Print "RENAME can't move a file to another volume (COPY, then ERA)" : End
  nn = Mid$(nn, 3)
End If
p = InStr(nn, ".")
If nn = "" Or InStr(nn, " ") > 0 Or (p = 0 And Len(nn) > 8) Or (p > 9) Or (p > 0 And Len(nn) - p > 3) Then Print nn; ": not a disc name (NAME.EXT)" : End
If FileSystem.Exists(v + f) = 0 Then Print v; f; ": not found" : End
If FileSystem.Exists(v + nn) Then Print v; nn; ": taken already" : End
r = FileSystem.Rename(v + f, v + nn)
If FileSystem.Exists(v + nn) = False Then Print v; f; ": not renamed ("; r; ")" : End
Print v; f; " is "; v; nn; " now"
