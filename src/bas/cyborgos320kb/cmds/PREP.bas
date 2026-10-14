' PREP: an empty FILES.DIR made on a volume, in CyborgOS (build for cpm, with CybDir.cls), so CD
' can go there and COPY can put files there.
'   PREP v                            "B" or "B:"
' A volume that has a FILES.DIR already is left as it is. Made, then looked for again. The new
' FILES.DIR is one 128 byte record of unused entries (zeros), not an empty file: a disc ROM may
' not open a file with nothing in it.
Option Explicit
Dim z(127) As Byte                ' (arrays start at 0)
Dim a As String Max 40, v As String Max 2
Dim r As Integer, x As Integer

a = UCase$(Trim$(System.CommandLine()))
If Len(a) = 2 And Right$(a, 1) = ":" Then a = Left$(a, 1)
If Len(a) <> 1 Then Print "PREP v (a volume: A, B ...)" : End
v = a + ":"
If FileSystem.Exists(v + "FILES.DIR") Then Print v; " has a FILES.DIR already" : End
r = FileSystem.Save(v + "FILES.DIR", VarPtr(z), 128)
x = FileSystem.Exists(v + "FILES.DIR")
If x And CybDir.Load(v) Then
  Print v; "FILES.DIR made (no entries)"
ElseIf r <> 0 Then
  Print v; "FILES.DIR could not be written ("; r; ")"
ElseIf x = 0 Then
  Print v; "FILES.DIR written, but not found again"
Else
  Print v; "FILES.DIR written and found, but not read"
End If
