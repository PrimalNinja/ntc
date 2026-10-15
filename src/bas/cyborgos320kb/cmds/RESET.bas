' RESET: a slot as before its command line was first opened (its program, if any, stopped), in
' CyborgOS (build for cpm, with CybSys.cls)
'   RESET [slot]                     no slot: this one
Option Explicit
Dim a As String Max 20, r As Integer
a = Trim$(System.CommandLine())
r = CybSys.Ask(2, Val(a))
If r = 255 Then Print "no slot "; a Else If a <> "" Then Print "slot "; a; " reset"
