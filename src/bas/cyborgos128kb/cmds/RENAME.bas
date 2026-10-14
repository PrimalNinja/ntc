' RENAME: a file renamed, in CyborgOS (build for cpm, with CybDir.cls).
'   RENAME [v:]name newname           a name with no volume: this slot's drive; newname: NAME.EXT
' Only a file in the volume's FILES.DIR (only files added there are touched): the file on the
' disc and its entry both get the new name (its long name and the rest stay). A name that is
' taken already (on the disc or in FILES.DIR) is refused.
Option Explicit
Dim a As String Max 40, v As String Max 2, f As String Max 40, nn As String Max 40, sn As String Max 12
Dim o As Integer, p As Integer, r As Integer

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
If CybDir.Load(v) = False Then Print v; " has no FILES.DIR" : End
o = CybDir.Find(f)
If o < 0 Then Print v; f; ": not in FILES.DIR (RENAME renames only files listed there)" : End
sn = CybDir.DiscName(o)
If CybDir.Find(nn) >= 0 Or FileSystem.Exists(v + nn) Then Print v; nn; ": taken already" : End
r = FileSystem.Rename(v + sn, v + nn)
If FileSystem.Exists(v + nn) = False Then Print v; sn; ": not renamed ("; r; ")" : End
CybDir.RenameAt o, nn
r = CybDir.Save(v)
If r <> 0 Then Print v; "FILES.DIR not written ("; r; ")" : End
Print v; sn; " is "; v; nn; " now"
