' ERA: a file deleted, in CyborgOS (build for cpm, with CybDir.cls).
'   ERA [v:]name                      a name with no volume: this slot's drive
' Only a file in the volume's FILES.DIR is deleted (only files added there are touched): the
' file on the disc and its entry both go.
Option Explicit
Dim a As String Max 40, v As String Max 2, f As String Max 40, sn As String Max 12
Dim o As Integer, r As Integer

a = UCase$(Trim$(System.CommandLine()))
If a = "" Or InStr(a, " ") > 0 Then Print "ERA [v:]name" : End
If Mid$(a, 2, 1) = ":" Then
  v = Left$(a, 2) : f = Mid$(a, 3)
Else
  v = FileSystem.CurrentVolume() + ":" : f = a
End If
If CybDir.Load(v) = False Then Print v; " has no FILES.DIR" : End
o = CybDir.Find(f)
If o < 0 Then Print v; f; ": not in FILES.DIR (ERA deletes only files listed there)" : End
sn = CybDir.DiscName(o)
r = FileSystem.Delete(v + sn)
If FileSystem.Exists(v + sn) Then Print v; sn; ": not deleted" : End
CybDir.Remove o
r = CybDir.Save(v)
If r <> 0 Then Print v; "FILES.DIR not written ("; r; ")" : End
Print v; sn; " deleted"
