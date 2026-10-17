' RATS: the rat in a box - RAT's sample (CyborgOS). Four corners: BED, FOOD, PLAY, TV. RATS keeps
' the rat's health (food, energy, fun - each runs down as time goes) and asks RAT what it does
' next: "RATMODEL bed:<energy> food:<food> play tv". The rat (r) walks to the corner RAT picks and
' does it: FOOD fills food, BED fills energy, PLAY and TV some fun. Low food or energy (a
' necessity) wins over what it likes; what it likes grows the more it does it (RATMODEL.MDL's
' L weights, saved by MODEL).
'   RUN 2 MODEL RATMODEL : RUN 3 RAT : RATS [n]      (n: that many decisions, then it ends; Q quits)
Option Explicit
Option Terminal VT52
Const W = 60                                  ' the box: columns 1-W, rows 3-H
Const H = 18
Dim cx(3) As Integer, cy(3) As Integer, cn(3) As String Max 5
Dim food As Integer, energy As Integer, fun As Integer
Dim rx As Integer, ry As Integer, tx As Integer, ty As Integer, c As Integer, n As Integer, mx As Integer
Dim tk As Integer
Dim rp As String Max 128, tg As String Max 15, v As Integer, j As Integer, k As Integer, i As Integer

cn(0) = "BED" : cx(0) = 2 : cy(0) = 4
cn(1) = "FOOD" : cx(1) = W - 5 : cy(1) = 4
cn(2) = "PLAY" : cx(2) = 2 : cy(2) = H - 1
cn(3) = "TV" : cx(3) = W - 5 : cy(3) = H - 1
mx = Val(CybSys.Tail())
food = 60 : energy = 70 : fun = 30
rx = W \ 2 : ry = (H + 3) \ 2
Box
Do
  rp = CybSys.PortCall("RAT", "RATMODEL bed:" + Trim$(Str$(energy)) + " food:" + Trim$(Str$(food)) + " play tv")
  If CybSys.PortStatus() <> 0 Then
    Locate 1, H + 2
    Print "No RAT service (RUN 2 MODEL RATMODEL, RUN 3 RAT)"
    End
  End If
  j = InStr(rp, " ")
  If j = 0 Then tg = rp : v = 0 Else tg = Left$(rp, j - 1) : v = Val(Mid$(rp, j + 1))
  c = -1
  For i = 0 To 3
    If UCase$(tg) = cn(i) Then c = i
  Next
  n = n + 1
  Locate 1, H + 2
  Print n; ": "; rp; "          "
  If c >= 0 Then
    tx = cx(c) + 1 : ty = cy(c) + 1           ' (beside the corner's name)
    If c = 1 Or c = 3 Then tx = cx(c) - 1
    Do While rx <> tx Or ry <> ty             ' walk there: a step at a time, time passing
      Locate rx, ry : Print " ";
      If rx < tx Then rx = rx + 1
      If rx > tx Then rx = rx - 1
      If ry < ty Then ry = ry + 1
      If ry > ty Then ry = ry - 1
      Locate rx, ry : Print "r";
      Tick 1
      If Quit() Then Exit Do
    Loop
    For k = 1 To 5                            ' do it
      If c = 0 Then energy = energy + 20
      If c = 1 Then food = food + 20
      If c = 2 Then fun = fun + 8
      If c = 3 Then fun = fun + 5
      Tick 0
    Next
  End If
  If mx > 0 And n >= mx Then Exit Do
  If Quit() Then Exit Do
Loop
Locate 1, H + 3
Print "RATS:"; n; " decisions"
End

' time passing: the health runs down (a point every 3 steps; walking: energy faster), the status line shown again
Sub Tick(ByVal walk As Integer)
  Dim t As Integer
  tk = tk + 1
  If tk Mod 3 = 0 Then food = food - 1 : energy = energy - 1 : fun = fun - 1
  If walk > 0 And tk Mod 4 = 0 Then energy = energy - 1
  If food > 100 Then food = 100
  If energy > 100 Then energy = 100
  If fun > 100 Then fun = 100
  If food < 0 Then food = 0
  If energy < 0 Then energy = 0
  If fun < 0 Then fun = 0
  Locate 1, 1
  Print "RATS  food"; food; "  energy"; energy; "  fun"; fun; "    "
  t = CybSys.Clock()
  Do While CybSys.Clock() - t < 15            ' (1/20 s a step)
  Loop
End Sub

' Q pressed?
Function Quit() As Integer
  Dim ch As Integer
  ch = Inkey
  Quit = (ch = 81 Or ch = 113)
End Function

' the box and its corners
Sub Box()
  Dim y As Integer
  Cls
  Locate 1, 2 : Print "+"; String$(W - 2, "-"); "+"
  For y = 3 To H
    Locate 1, y : Print "|"; : Locate W, y : Print "|"
  Next
  Locate 1, H + 1 : Print "+"; String$(W - 2, "-"); "+"
  For y = 0 To 3
    Locate cx(y), cy(y) : Print cn(y);
  Next
  Locate rx, ry : Print "r";
End Sub
