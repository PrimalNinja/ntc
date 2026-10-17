' L2TEST - are Layer 2's two buffers swapped in step with the screen?
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Drawn as NEON WAR draws: each frame the lines drawn on this buffer last time are taken off
' (L2.Clear), a spinning star and 4 boxes are drawn, the frame is waited for, the buffers swap.
' If the swap is in step with the screen the shapes are SOLID; if not they blink or vanish.
' Two ways of waiting for the frame (key W swaps them):
'   F  Frame: NTC's own - waits for raster line 192 (NextReg #1E / #1F), the picture's end
'   R  the raster wrapping round: waits until the line number goes back down (the frame's start,
'      whichever line the count starts from)
' Keys 1-4: 3.5 / 7 / 14 / 28MHz.
Option Explicit
Option Turbo

Dim mode As Integer, t As Integer, a As Integer, b As Integer, k As Integer, x As Integer, y As Integer, wWas As Integer
Dim sn(15) As Integer

sn(0) = 0 : sn(1) = 24 : sn(2) = 45 : sn(3) = 59 : sn(4) = 64 : sn(5) = 59 : sn(6) = 45 : sn(7) = 24
For k = 8 To 15
  sn(k) = -sn(k - 8)
Next
Cls
L2.Init &HE3                           ' see-through: the text shows where nothing is drawn
Nx.Layers Nx.OrderLUS
Nx.Reg &H07, 3
mode = 0
Status
Do
  L2.Clear
  For k = 0 To 7
    a = (t \ 2 + k * 2) And 15
    L2.Line 128, 110, 128 + sn((a + 4) And 15), 110 + sn(a), &HFF
  Next
  For k = 0 To 3
    x = 20 + k * 60 : y = 150 + sn((t + k * 4) And 15) \ 4
    L2.Line x, y, x + 30, y, &H1C
    L2.Line x + 30, y, x + 30, y + 20, &H1C
    L2.Line x + 30, y + 20, x, y + 20, &H1C
    L2.Line x, y + 20, x, y, &H1C
  Next
  If mode = 0 Then
    Frame
  Else
    WaitWrap
  End If
  L2.Flip
  t = t + 1
  If Keys.Down(Keys.KeyW) Then
    If wWas = 0 Then mode = 1 - mode : Status
    wWas = 1
  Else
    wWas = 0
  End If
  If Keys.Down(Keys.Key1) Then Nx.Reg &H07, 0 : Status
  If Keys.Down(Keys.Key2) Then Nx.Reg &H07, 1 : Status
  If Keys.Down(Keys.Key3) Then Nx.Reg &H07, 2 : Status
  If Keys.Down(Keys.Key4) Then Nx.Reg &H07, 3 : Status
Loop

' wait for the raster line to wrap round (it goes back down: a new frame)
Sub WaitWrap()
  Dim p As Integer, q As Integer
  p = Nx.Raster()
  Do
    q = Nx.Raster()
    If q < p Then Exit Do
    p = q
  Loop
End Sub

Sub Status()
  Locate 0, 0
  Print "L2TEST  W: sync way   1-4: speed"
  If mode = 0 Then Print "sync: F  Frame (line 192)    " Else Print "sync: R  raster wrap         "
  Print "speed: "; Trim$(Str$(Nx.RegGet(&H07) And 3)); "  (0 = 3.5MHz, 3 = 28MHz)"
  Print "solid shapes = in step; blinking = not"
End Sub
