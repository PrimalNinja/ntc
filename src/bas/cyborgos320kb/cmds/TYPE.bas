' TYPE: a text file shown, in CyborgOS (build for cpm).
'   TYPE [v:]name                     a name with no volume: this slot's drive
' Any file the drive has. The text ends at the end of the file or its first ^Z (#1A).
Option Explicit
Dim a As String Max 40, v As String Max 2, f As String Max 40
Dim h As Integer, r As Integer

a = UCase$(Trim$(System.CommandLine()))
If a = "" Or InStr(a, " ") > 0 Then Print "TYPE [v:]name" : End
If Mid$(a, 2, 1) = ":" Then
  v = Left$(a, 2) : f = Mid$(a, 3)
Else
  v = FileSystem.CurrentVolume() + ":" : f = a
End If
h = FileSystem.Open(v + f, FileSystem.ForRead)
If h < 0 Then Print v; f; ": not found" : End
Do While Not FileSystem.Eof(h)
  Print FileSystem.ReadLine(h)
Loop
r = FileSystem.Close(h)
