' TYPE: a text file shown, in CyborgOS (build for cpm, with CybDir.cls).
'   TYPE [v:]name                     a name with no volume: this slot's drive
' Only a file in the volume's FILES.DIR (only files added there are touched). The text ends at
' the end of the file or its first ^Z (#1A).
Option Explicit
Dim a As String Max 40, v As String Max 2, f As String Max 40, sn As String Max 12
Dim o As Integer, h As Integer, r As Integer

a = UCase$(Trim$(System.CommandLine()))
If a = "" Or InStr(a, " ") > 0 Then Print "TYPE [v:]name" : End
If Mid$(a, 2, 1) = ":" Then
  v = Left$(a, 2) : f = Mid$(a, 3)
Else
  v = FileSystem.CurrentVolume() + ":" : f = a
End If
If CybDir.Load(v) = False Then Print v; " has no FILES.DIR" : End
o = CybDir.Find(f)
If o < 0 Then Print v; f; ": not in FILES.DIR (TYPE shows only files listed there)" : End
sn = CybDir.DiscName(o)
h = FileSystem.Open(v + sn, FileSystem.ForRead)
If h < 0 Then Print v; sn; ": not on the disc" : End
Do While Not FileSystem.Eof(h)
  Print FileSystem.ReadLine(h)
Loop
r = FileSystem.Close(h)
