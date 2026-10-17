' ASK port message: a port called (CyborgOS) - the message sent, its answer printed: a service
' tried from the command line (ASK RAT RATMODEL food:10 tv, ASK NPC Q seen=wolf action?)
Option Explicit
Dim t As String Max 72, p As String Max 8, k As Integer, a As String Max 128
t = Trim$(CybSys.Tail())
k = InStr(t, " ")
If t = "" Or k = 0 Then Print "ASK port message: the port called, its answer printed" : End
p = UCase$(Left$(t, k - 1))
a = CybSys.PortCall(p, Trim$(Mid$(t, k + 1)))
If CybSys.PortStatus() <> 0 Then Print "No port "; p : End
Print a
