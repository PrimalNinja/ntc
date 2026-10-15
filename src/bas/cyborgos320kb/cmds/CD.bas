' CD: this slot's drive, in CyborgOS (build for cpm)
'   CD [drive]                       "B" or "B:"; none: shows it. (B: alone on the command line is
'                                    CD B.) The drive needs a FILES.DIR (PREP makes one). Not Z:
'                                    the system drive is CyborgOS's own
Option Explicit
Dim a As String Max 20, r As Integer
a = UCase$(Trim$(System.CommandLine()))
If Len(a) = 2 And Right$(a, 1) = ":" Then a = Left$(a, 1)
If a <> "" Then
  If Len(a) <> 1 Or a < "A" Or a > "P" Then
    Print a; ": no such drive"
  ElseIf FileSystem.Exists(a + ":FILES.DIR") = 0 Then
    Print a; ": no such drive, or no FILES.DIR there"
  Else
    r = FileSystem.SelectVolume(a)
  End If
End If
Print "drive "; FileSystem.CurrentVolume()
