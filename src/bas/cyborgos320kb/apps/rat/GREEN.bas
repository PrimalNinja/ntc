' GREEN: the greenhouse bridge - the board's sensors to RAT, its answer to the relays
Option Explicit
Const ADCSEL = &HF8E0                         ' your board: the ADC's channel select
Const ADCDAT = &HF8E1                         ' its reading, 0-255
Const RELAYS = &HF8E2                         ' the outputs: bit 0 pump, 1 fan, 2 lamp
Dim a As String Max 128, t As Integer, ch As Integer, r As Integer, b As Integer
r = CybSys.Claim("IO", 0)                     ' (the board: this program's alone)
If r <> 0 Then Print "The IO board is in use by slot"; r : End
Do
  a = "~GREEN water:" + Lv(0) + " cool:" + Lv2(1) + " lamp:" + Lv(2) + " wait"
  a = CybSys.PortCall("RAT", a)
  If CybSys.PortStatus() <> 0 Then Print "No RAT (RUN 2 MODEL GREEN, RUN 3 RAT)" : Exit Do
  b = 0
  If Left$(a, 5) = "water" Then b = 1
  If Left$(a, 4) = "cool" Then b = 2
  If Left$(a, 4) = "lamp" Then b = 4
  Out RELAYS, b
  Print a
  t = CybSys.Clock()
  Do While CybSys.Clock() - t < 1500          ' every 5 seconds; Q stops it
    ch = Inkey
    If ch = 81 Or ch = 113 Then Exit Do
  Loop
  If ch = 81 Or ch = 113 Then Exit Do
Loop
Out RELAYS, 0                                 ' (everything off at the end)
r = CybSys.Release("IO", 0)
End

' channel c's reading as a level 0-100
Function Lv(ByVal c As Integer) As String
  Out ADCSEL, c
  Lv = Trim$(Str$(((Inp(ADCDAT) And 255) * 100) \ 255))
End Function

' the same, turned over (high is bad: temperature)
Function Lv2(ByVal c As Integer) As String
  Lv2 = Trim$(Str$(100 - Val(Lv(c))))
End Function
