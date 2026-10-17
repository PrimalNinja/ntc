' WATCH [port] [prop=value ...]: NEURAL's sample - decisions from CyborgOS's own numbers (free=
' the free memory in K, progs= the programs running). Every 2 seconds it asks the net (the port:
' SYS when none - RUN 2 NEURAL SYS) what goes with them now, and shows it; Q quits. With
' prop=value words it trains instead: now's numbers and those, learnt once (WATCH say=busy)
'   RUN 2 NEURAL SYS : WATCH          (SYS.NN: free=, progs= and say=)
Option Explicit
Dim t As String Max 72, p As String Max 8, w As String Max 72, a As String Max 128, q As String Max 128
Dim k As Integer, ch As Integer, c As Integer, fr As Integer, pg As Integer, n As Integer

t = Trim$(CybSys.Tail())
p = "SYS"
k = InStr(t, " ")
If k = 0 Then w = t Else w = Left$(t, k - 1)
If w <> "" And InStr(w, "=") = 0 Then         ' (a port first)
  p = UCase$(w)
  If k = 0 Then t = "" Else t = Trim$(Mid$(t, k + 1))
End If
If t <> "" Then
  Stats
  a = CybSys.PortCall(p, "T " + q + " " + t)
  If CybSys.PortStatus() <> 0 Then Print "No port "; p; " (RUN 2 NEURAL SYS)" : End
  Print q; " "; t; ": "; a
  End
End If
Print "WATCH: asking "; p; " every 2 seconds (Q quits)"
Do
  Stats
  a = CybSys.PortCall(p, "Q " + q)
  If CybSys.PortStatus() <> 0 Then Print "No port "; p; " (RUN 2 NEURAL SYS)" : End
  n = n + 1
  Print n; ": "; q; " -> "; a
  c = CybSys.Clock()
  Do While CybSys.Clock() - c < 600
    ch = Inkey
    If ch = 81 Or ch = 113 Then Exit Do
  Loop
  If ch = 81 Or ch = 113 Then Exit Do
Loop
End

' now's numbers, as prop=value words in q: free= (K), progs= (the slots running a program)
Sub Stats()
  Dim s As Integer, j As Integer, x As String Max 60
  fr = 0
  If CybSys.Ask(7, 0) <> 255 Then
    x = CybSys.TextAt(8)                      ' ("Total memory: 576 KB   Free memory: 224 KB")
    j = InStr(x, "Free memory:")
    If j > 0 Then fr = Val(Mid$(x, j + 12))
  End If
  pg = 0
  s = 1
  Do While CybSys.Ask(0, s) <> 255
    If CybSys.ByteAt(2) >= 2 Then pg = pg + 1
    s = s + 1
  Loop
  q = "free=" + Trim$(Str$(fr)) + " progs=" + Trim$(Str$(pg))
End Sub
