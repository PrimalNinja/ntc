' PS: the slots, in CyborgOS (build for cpm, with CybSys.cls): each slot's state - "-" (not open),
' "command line", or the program it runs; * the slot in front
Option Explicit
Dim s As Integer, a As String Max 20
s = 1
Do While CybSys.Ask(0, s) <> 255
  If CybSys.ByteAt(2) = 0 Then
    a = "-"
  ElseIf CybSys.ByteAt(2) = 1 Then
    a = "command line"
  Else
    a = CybSys.TextAt(4)
  End If
  If CybSys.ByteAt(3) Then Print Right$("  " + Trim$(Str$(s)), 3); " * "; a Else Print Right$("  " + Trim$(Str$(s)), 3); "   "; a
  s = s + 1
Loop
If s = 1 Then Print "PS needs CyborgOS"
