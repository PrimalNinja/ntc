' PS: the slots, in CyborgOS (build for cpm, with CybSys.cls): each slot's state - "-" (not open),
' "command line", or the program it runs; * the slot in front; then the hardware it has claimed
' (CLAIMS), in [ ]
Option Explicit
Dim s As Integer, a As String Max 60, t(159) As Byte, c As String Max 40, i As Integer, j As Integer
CybSys.SetWord 2, VarPtr(t)
If CybSys.Ask(15, 4) <> 0 Then Print "PS needs CyborgOS" : End
s = 1
Do While CybSys.Ask(0, s) <> 255
  If CybSys.ByteAt(2) = 0 Then
    a = "-"
  ElseIf CybSys.ByteAt(2) = 1 Then
    a = "command line"
  Else
    a = CybSys.TextAt(4)
  End If
  c = ""
  For i = 0 To 15
    If t(i * 10) = s And Len(c) < 30 Then
      If c <> "" Then c = c + ", "
      For j = 2 To 9
        If t(i * 10 + j) > 32 Then c = c + Chr$(t(i * 10 + j))
      Next
      c = c + " " + Trim$(Str$(t(i * 10 + 1)))
    End If
  Next
  If c <> "" Then a = a + "  [" + c + "]"
  If CybSys.ByteAt(3) Then Print Right$("  " + Trim$(Str$(s)), 3); " * "; a Else Print Right$("  " + Trim$(Str$(s)), 3); "   "; a
  s = s + 1
Loop
If s = 1 Then Print "PS needs CyborgOS"
