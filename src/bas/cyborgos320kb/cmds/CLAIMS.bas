' CLAIMS: the hardware the programs have claimed, in CyborgOS (build for cpm, with CybSys.cls) -
' a program drives some hardware itself (FLOPPY the disc controller, a player the sound chip ...)
' and claims it first, so that no other slot's program touches it at the same time
'   CLAIMS                    each claim: its name, its unit, the slot and its program
'   CLAIMS TAKE name [unit]   taken back from the program that has it (unit 0 if not given):
'                             free for another program (the one that had it stops using it)
Option Explicit
Dim t(159) As Byte, a As String Max 40, nm As String Max 8, w As String Max 8
Dim i As Integer, j As Integer, s As Integer, n As Integer, u As Integer, r As Integer

a = UCase$(Trim$(System.CommandLine()))
If Left$(a, 5) = "TAKE " Then
  a = Trim$(Mid$(a, 6))
  i = InStr(a, " ")
  If i = 0 Then nm = a : u = 0 Else nm = Left$(a, i - 1) : u = Val(Mid$(a, i + 1))
  r = CybSys.Take(nm, u)
  If r = 255 Then Print "No room for it, or not CyborgOS" : End
  a = nm + " " + Trim$(Str$(u))
  If r = 0 Then Print a; " wasn't claimed" Else Print a; " taken from slot "; Trim$(Str$(r))
  End
End If
If a <> "" Then
  Print "CLAIMS                    the claims"
  Print "CLAIMS TAKE name [unit]   one taken back from its program"
  End
End If
CybSys.SetWord 2, VarPtr(t)
If CybSys.Ask(15, 4) <> 0 Then Print "CLAIMS needs CyborgOS" : End
n = 0
For i = 0 To 15
  s = t(i * 10)
  If s <> 0 Then
    w = ""
    For j = 2 To 9
      If t(i * 10 + j) > 32 Then w = w + Chr$(t(i * 10 + j))
    Next
    If n = 0 Then Print "NAME      UNIT  SLOT  PROGRAM"
    a = ""
    If CybSys.Ask(0, s) = 0 Then
      If CybSys.ByteAt(2) = 2 Then a = CybSys.TextAt(4) Else a = "command line"
    End If
    Print Left$(w + "          ", 10); Right$("   " + Trim$(Str$(t(i * 10 + 1))), 4); Right$("     " + Trim$(Str$(s)), 6); "  "; a
    n = n + 1
  End If
Next
If n = 0 Then Print "No claims"
