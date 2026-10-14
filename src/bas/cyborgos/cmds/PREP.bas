' PREP: an empty FILES.DIR made on a volume, in CyborgOS (build for cpm, with CybDir.cls), so CD
' can go there and COPY can put files there.
'   PREP v                            "B" or "B:"
' A volume that has a FILES.DIR already is left as it is. Made, then looked for again.
Option Explicit
Dim a As String Max 40, v As String Max 2
Dim r As Integer

a = UCase$(Trim$(System.CommandLine()))
If Len(a) = 2 And Right$(a, 1) = ":" Then a = Left$(a, 1)
If Len(a) <> 1 Then Print "PREP v (a volume: A, B ...)" : End
v = a + ":"
If FileSystem.Exists(v + "FILES.DIR") Then Print v; " has a FILES.DIR already" : End
r = FileSystem.Save(v + "FILES.DIR", 0, 0)
If FileSystem.Exists(v + "FILES.DIR") And CybDir.Load(v) Then
  Print v; "FILES.DIR made (no entries)"
Else
  Print v; "FILES.DIR could not be made ("; r; ")"
End If
