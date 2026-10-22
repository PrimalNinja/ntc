' BOUNCE - balls bouncing round the screen: one CyborgOS program, the same .CYB file, with
' graphics on the Amstrad CPC and on the ZX Spectrum Next. A demo of how to do it.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
'   BOUNCE [n]      (n balls, 1-8: 8 if not given; in any slot; Q quits; Shift / Control + a number goes to another slot and back)
'
' The game itself (the balls, the walls, the timing, the keys) is written once, here. The
' screen is two classes with the same Subs - Init, Enter, Leave, Ball, Show, Done:
'   ZxnScr.cls  the Next: hardware sprites over the slot's own console
'   CpcScr.cls  the CPC: two screens in main RAM, drawn in turn, a compiled sprite
' and CybSys.Host() picks one when it runs (0 the CPC, 1 the Next). NTC's System values are
' fixed when the program is compiled; the .CYB is the same file on both, so it has to ask.
'
' The rule that lets it share the machine: it touches the screen only while its slot is in
' front. After every turn it gives away (Yield) it asks whether it still is (Front); when it
' has gone behind it gives the screen back (Leave) and draws nothing until it's in front again;
' then it sets the screen up again (Enter) and carries on.
Option Explicit
Option Turbo

Dim N As Integer                         ' balls: 8, or BOUNCE n (1-8)
Const XMIN = 8, XMAX = 292, YMIN = 12, YMAX = 180    ' where a ball's top left may be

Dim bx(7) As Integer, by(7) As Integer, dx(7) As Integer, dy(7) As Integer
Dim host As Integer, me As Integer, shown As Integer, last As Integer, k As Integer, i As Integer
Dim frames As Integer, quit As Integer

N = Val(System.CommandLine())
If N < 1 Or N > 8 Then N = 8
host = CybSys.Host()
If host = 255 Then Print "BOUNCE needs CyborgOS" : End
me = MySlot()
If host = 1 Then
  ZxnScr.Init
  Print "BOUNCE on the ZX Spectrum Next: sprites over the console. Q quits."
Else
  If CpcScr.Init() = 0 Then Print "BOUNCE: this slot's RAM setting not found" : End
End If

For i = 0 To N - 1
  bx(i) = XMIN + Rnd(70) * 4 : by(i) = YMIN + Rnd(YMAX - YMIN)
  If Rnd(2) Then dx(i) = 4 Else dx(i) = -4
  dy(i) = 1 + Rnd(2) : If Rnd(2) Then dy(i) = -dy(i)
Next

shown = 0
last = CybSys.Clock()
Do
  WaitFrame
  For i = 0 To N - 1
    bx(i) = bx(i) + dx(i)
    If bx(i) < XMIN Or bx(i) > XMAX Then dx(i) = -dx(i) : bx(i) = bx(i) + dx(i) * 2
    by(i) = by(i) + dy(i)
    If by(i) < YMIN Or by(i) > YMAX Then dy(i) = -dy(i) : by(i) = by(i) + dy(i) * 2
    If host = 1 Then ZxnScr.Ball i, bx(i), by(i) Else CpcScr.Ball i, bx(i), by(i)
  Next
  If host = 1 Then ZxnScr.Show Else CpcScr.Show
  frames = frames + 1
  If Peek(&HF681) <> 0 Then             ' a key for this slot (CyborgOS puts it there)
    k = Inkey
    If k = 81 Or k = 113 Then quit = 1
  End If
Loop Until quit

If host = 1 Then ZxnScr.Done N Else CpcScr.Done N
Print "BOUNCE: "; frames; " frames"
End

' WaitFrame: 1/50 s since the last frame (CyborgOS's clock: 300 a second), giving the CPU to
' the other slots meanwhile - and the screen given back / taken again as the slot goes behind /
' comes to the front
Sub WaitFrame()
  Do
    If CybSys.Bdos(12, 0) = 0 Then        ' Yield: BDOS 12 ends the slot's turn
    End If
    If Front() Then
      If shown = 0 Then
        If host = 1 Then ZxnScr.Enter Else CpcScr.Enter
        shown = 1
      End If
      If CybSys.Clock() - last >= 6 Then Exit Do
    ElseIf shown Then
      If host = 1 Then ZxnScr.Leave Else CpcScr.Leave
      shown = 0
    End If
  Loop
  last = CybSys.Clock()
End Sub

' Front: 1 while this slot is the one on the screen (BDOS 131 op 0: a slot's line; byte 3)
Function Front() As Integer
  If CybSys.Ask(0, me) = 0 Then
  End If
  Front = CybSys.ByteAt(3)
End Function

' MySlot: this slot's number, from its status strip text in its own bank ("[7] " at #F68A)
Function MySlot() As Integer
  Dim a As Integer, n As Integer
  n = 0
  a = &HF68B
  Do While Peek(a) >= 48 And Peek(a) <= 57
    n = n * 10 + Peek(a) - 48
    a = a + 1
  Loop
  MySlot = n
End Function
