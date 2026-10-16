' ERA: files deleted, in CyborgOS (build for cpm, with CybDir.cls).
'   ERA [v:]name                      a name with no volume: this slot's drive
'   ERA [v:]pattern                   * any characters, ? any one (*.BAK, T*): each file that fits
' Any file the drive has (its own directory: UniDOS's folder, a RAM disc's). A folder is left
' alone (RMDIR)
Option Explicit
Dim a As String Max 40, v As String Max 2, f As String Max 40, sn As String Max 12
Dim i As Integer, r As Integer, k As Integer

a = UCase$(Trim$(System.CommandLine()))
If a = "" Or InStr(a, " ") > 0 Then Print "ERA [v:]name   ERA [v:]pattern" : End
If Mid$(a, 2, 1) = ":" Then
  v = Left$(a, 2) : f = Mid$(a, 3)
Else
  v = FileSystem.CurrentVolume() + ":" : f = a
End If
If InStr(f, "*") = 0 And InStr(f, "?") = 0 Then  ' one file
  sn = f
  If FileSystem.Exists(v + sn) = 0 And InStr(f, ".") = 0 Then sn = f + ".COM"
  If FileSystem.Exists(v + sn) = 0 Then Print v; f; ": not found" : End
  Gone sn
  End
End If
If CybDir.LoadAll(v) = False Then Print v; ": its files can't be listed (UniDOS, or a RAM disc)" : End
k = 0
For i = 0 To CybDir.Count() - 1
  If CybDir.Match(i, f) Then Gone CybDir.DiscName(i) : k = k + 1
Next
If k = 0 Then Print v; f; ": no file fits"
End

' file s deleted, a line saying so
Sub Gone(ByVal s As String)
  r = FileSystem.Delete(v + s)
  If FileSystem.Exists(v + s) Then Print v; s; ": not deleted" Else Print v; s; " deleted"
End Sub
