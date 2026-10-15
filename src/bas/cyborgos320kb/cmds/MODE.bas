' MODE: this slot's screen mode, in CyborgOS (build for cpm, with CybSys.cls). The slot's console
' is cleared at the new size; each slot has its own (the screen follows the slot in front).
' Programs get the size with BDOS 49 (CP/M 3's system control block: #1A the width - 1, #1C the
' rows), as MODE does here
'   MODE        the mode now and the modes
'   MODE m      2, S, W, UW, P or F
Option Explicit
Dim a As String Max 20, m As Integer, r As Integer
Dim pb(3) As Byte                 ' BDOS 49's block: the offset, 0 (get), a word
a = UCase$(Trim$(System.CommandLine()))
m = -1
If a = "2" Then m = 0
If a = "S" Then m = 1
If a = "W" Then m = 2
If a = "UW" Then m = 3
If a = "P" Then m = 4
If a = "F" Then m = 5
If m >= 0 Then
  r = CybSys.Ask(9, m)
  If r <> 0 Then Print "MODE needs CyborgOS 320K"
  End
End If
r = CybSys.Ask(9, 255)
If r > 5 Then Print "MODE needs CyborgOS 320K" : End
If a <> "" Then Print "MODE "; a; ": no such mode"
Print "MODE 2   80 x 25"
Print "MODE S   84 x 24: 80 x 24 and a status strip on the right"
Print "MODE W   88 x 23"
Print "MODE UW  96 x 21"
Print "MODE P   64 x 32"
Print "MODE F   84 x 24: all of it the console (no strip)"
Print "Now: MODE "; Trim$(Mid$("2 S W UWP F ", r * 2 + 1, 2)); " - the console ";
pb(0) = &H1A : r = CybSys.Bdos(49, VarPtr(pb))
Print Trim$(Str$(r + 1)); " x ";
pb(0) = &H1C : r = CybSys.Bdos(49, VarPtr(pb))
Print Trim$(Str$(r))
