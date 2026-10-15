' KILL: a slot's program stopped, in CyborgOS (build for cpm, with CybSys.cls)
'   KILL slot
Option Explicit
Dim a As String Max 20, r As Integer
a = Trim$(System.CommandLine())
r = CybSys.Ask(1, Val(a))
If r <> 0 Then Print "nothing running in slot "; a
