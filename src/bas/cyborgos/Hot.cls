' Hot: CyborgOS's system keys, looked at 50 times a second whatever runs (an interrupt class:
' its Tick runs at the hypervisor's safe points, and a program in a bank gives the CPU back at
' every interrupt). Control held: 1-8 a slot to the front, ESC the TOP screen. Each new key
' while Control stays down counts (Control + 1, then 2, then 3 ...). Take() gives the last one
' (0 none) and clears it.
Option Class Interrupt 50
Private pend As Integer, last As Integer, ctl As Integer

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
    If Keys.Down(Keys.KeyEsc) Then k = 9
  End If
  If k <> 0 And k <> last Then pend = k
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
