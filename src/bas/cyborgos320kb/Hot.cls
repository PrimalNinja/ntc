' Hot: CyborgOS's system keys, looked at 50 times a second whatever runs (an interrupt class:
' its Tick runs at the hypervisor's safe points, and a program in a bank gives the CPU back at
' every interrupt). Control held: 1-9, 0 (10) a slot to the front, ESC the TOP screen. Each new
' key while Control stays down counts (Control + 1, then 2, then 3 ...). With more than 10 slots
' (Slots n), the same number pressed twice within DOUBLE ticks is slot 10 + that number: a
' single press then waits that long (or until Control is let go, or another key comes) before
' it counts. Take() gives the last one (0 none, 1-16 a slot, TOPKEY) and clears it.
Option Class Interrupt 50
Public Const TOPKEY = 99
Const DOUBLE = 15                       ' ticks (0.3 s) for the second press of a double tap
Private pend As Integer, last As Integer, ctl As Integer, ns As Integer
Private one As Integer, age As Integer  ' a single press waiting to see if a second one comes

Public Sub Slots(ByVal n As Integer)
  ns = n
End Sub

Public Sub Tick()
  Dim k As Integer
  ctl = Keys.Down(Keys.KeyControl)
  If ctl Then
    If Keys.Down(64) Then k = 1
    If Keys.Down(65) Then k = 2
    If Keys.Down(57) Then k = 3
    If Keys.Down(56) Then k = 4
    If Keys.Down(49) Then k = 5
    If Keys.Down(48) Then k = 6
    If Keys.Down(41) Then k = 7
    If Keys.Down(40) Then k = 8
    If Keys.Down(33) Then k = 9
    If Keys.Down(32) Then k = 10
    If Keys.Down(Keys.KeyEsc) Then k = TOPKEY
  End If
  If k <> 0 And k <> last Then
    If k = TOPKEY Or ns <= 10 Then
      If one <> 0 Then one = 0
      pend = k                          ' at once (no double taps to wait for)
    ElseIf one = k Then
      one = 0
      If k + 10 <= ns Then pend = k + 10 Else pend = k  ' the second press: slot 11-20
    Else
      If one <> 0 Then pend = one       ' another number: the waiting one counts now
      one = k : age = 0
    End If
  End If
  If one <> 0 Then
    age = age + 1
    If age > DOUBLE Or ctl = 0 Then pend = one : one = 0    ' no second press (or Control let go)
  End If
  last = k
End Sub

Public Function Take() As Integer
  Take = pend
  pend = 0
End Function

' Control(): True while Control is held (keys typed then are system keys, not for the programs)
Public Function Control() As Integer
  Control = ctl
End Function
