' STACKER - a falling block puzzle for the ZX Spectrum Next, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The seven four-block pieces fall into a well ten wide and twenty deep. Turn them and slide
' them so they fill whole rows: a full row goes. Two games: MARATHON (levels go up every ten
' rows, faster and faster) and SPRINT (forty rows, as quick as you can).
'
' Keys: O P left / right, A down a bit, Space drop, Q turn right, W turn left, H hold the piece
'       for later, M the music on / off. The joystick: left / right / down, up turns, fire drops.
'
' The well and the panels are the tilemap (Board.cls: a palette row a cell, so one block tile
' makes all seven colours); the picture behind is Layer 2.
Option Explicit
Option Turbo

Const BW = 10, BH = 22, WX = 15, WY = 4
' palette rows: 0 the frame / floor, 1-7 the pieces, 8 a flash, 9 grey, 10-13 words
Const C_WHITE = 10, C_YELLOW = 11, C_CYAN = 12, C_PINK = 13

Dim bd(219) As Byte, bag(6) As Integer, bagN As Integer, nq(2) As Integer
Dim cur As Integer, rot As Integer, cx As Integer, cy As Integer, gy As Integer
Dim hold As Integer, held As Integer, lockT As Integer, resets As Integer, fallT As Integer
Dim das As Integer, dasW As Integer, rotWas As Integer, dropWas As Integer, holdWas As Integer, musWas As Integer
Dim ox(3) As Integer, oy(3) As Integer, ogx(3) As Integer, ogy(3) As Integer, shown As Integer
Dim score As Long, lines As Integer, level As Integer, startLv As Integer, mode As Integer, over As Integer
Dim best(1) As Long, bestT As Long, timeF As Long, frames As Integer, music As Integer, musP As Integer, musT As Integer
Dim fullN As Integer, full(3) As Integer
Dim i As Integer, k As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Board.Init
L2.Init
Nx.Layers Nx.OrderSUL
Colours
startLv = 1 : mode = 0 : music = 1 : bestT = 0
Do
  TitleScr
  Game
Loop

' ---------------------------------------------------------------- set up
Sub Colours()
  Board.Pal 0, "00FF7F1B0E0125DB92490000000026E3"
  Board.Pal 1, "00FF7F1B0E0125DB92490000000026E3"
  Board.Pal 2, "00FFFDD86C0125DB92490000000026E3"
  Board.Pal 3, "00FFCF83410125DB92490000000026E3"
  Board.Pal 4, "00FF7D34080125DB92490000000026E3"
  Board.Pal 5, "00FFEEC0600125DB92490000000026E3"
  Board.Pal 6, "00FF7327020125DB92490000000026E3"
  Board.Pal 7, "00FFF5EC840125DB92490000000026E3"
  Board.Pal 8, "00FFFFFFFF0125DB92490000000026E3"
  Board.Pal 9, "00FFB692490125DB92490000000026E3"
  Board.Pal 10, "00FF00000000000000000000000026E3"
  Board.Pal 11, "00FC00000000000000000000000026E3"
  Board.Pal 12, "001F00000000000000000000000026E3"
  Board.Pal 13, "00EE00000000000000000000000026E3"
End Sub

' the picture behind: deep blue with faint squares
Sub Backdrop()
  Dim y As Integer, x As Integer
  L2.Rect 0, 0, 256, 192, 1
  For k = 0 To 30
    x = (k * 53) Mod 244 : y = (k * 97) Mod 180
    L2.Rect x, y, 8, 8, &H25
    L2.Rect x + 1, y + 1, 6, 6, 1
  Next
End Sub

' piece p in turn r: its four cells (x, y in a 4 x 4 box) as eight digits
Function Shape(ByVal p As Integer, ByVal r As Integer) As String
  Select Case p
  Case 0: Shape = Mid$("01112131202122230212223210111213", r * 8 + 1, 8)
  Case 1: Shape = Mid$("10201121102011211020112110201121", r * 8 + 1, 8)
  Case 2: Shape = Mid$("10011121101121120111211210011112", r * 8 + 1, 8)
  Case 3: Shape = Mid$("10200111101121221121021200011112", r * 8 + 1, 8)
  Case 4: Shape = Mid$("00101121201121120111122210011102", r * 8 + 1, 8)
  Case 5: Shape = Mid$("00011121102011120111212210110212", r * 8 + 1, 8)
  Case 6: Shape = Mid$("20011121101112220111210200101112", r * 8 + 1, 8)
  End Select
End Function

' ---------------------------------------------------------------- keys, frames
Function Way() As Integer
  Dim j As Integer
  j = Keys.Joystick(0)
  Way = 0
  If Keys.Down(Keys.KeyO) Or (j And Keys.JoyLeft) Then Way = -1
  If Keys.Down(Keys.KeyP) Or (j And Keys.JoyRight) Then Way = 1
End Function

Function Fire() As Integer
  Fire = 0
  If Keys.Down(Keys.KeySpace) Or (Keys.Joystick(0) And Keys.JoyFire1) Then Fire = 1
End Function

Sub Tick()
  Frame
  Spr.Show
  Tune
  Sfx.Update
  frames = frames + 1
  If mode = 1 And over = 0 Then timeF = timeF + 1
End Sub

Sub WaitF(ByVal t As Integer)
  Dim j As Integer
  For j = 1 To t
    Tick
  Next
End Sub

' ---------------------------------------------------------------- the music: an old Russian folk tune
' (notes: a letter and a length in eighths; a b c d e f g = A4 .. G5, h = A5, s / t = G#4 / G#5, r = rest)
Function Melody(ByVal part As Integer) As String
  If part < 2 Then
    Melody = "e2b1c1d2c1b1a2a1c1e2d1c1b3c1d2e2c2a2a4r1d2f1h2g1f1e3c1e2d1c1b2b1c1d2e2c2a2a2r2"
  Else
    Melody = "e4c4d4b4c4a4s4b2r2e4c4d4b4c2e2h4t8"
  End If
End Function

Sub Tune()
  Dim m As String Max 90, n As Integer, l As Integer, p As Integer
  If music = 0 Or over Then Exit Sub
  musT = musT - 1
  If musT > 0 Then Exit Sub
  m = Melody(musP \ 100)
  n = Asc(Mid$(m, musP Mod 100 + 1, 1))
  l = Val(Mid$(m, musP Mod 100 + 2, 1)) * 9
  Select Case Chr$(n)
  Case "a": p = 249
  Case "b": p = 221
  Case "c": p = 209
  Case "d": p = 186
  Case "e": p = 166
  Case "f": p = 157
  Case "g": p = 140
  Case "h": p = 124
  Case "s": p = 263
  Case "t": p = 132
  Case Else: p = 0
  End Select
  If p Then Sfx.Play 0, p, 0, 10, l - 1, 0
  musT = l
  musP = musP + 2
  If musP Mod 100 >= Len(m) Then
    musP = (musP \ 100 + 1) * 100
    If musP >= 300 Then musP = 0
  End If
End Sub

' ---------------------------------------------------------------- the title
Sub TitleScr()
  Dim v As Integer, was As Integer, a As Integer
  over = 1
  Spr.HideRange 0, 64
  Board.Clear
  Backdrop
  L2.Big 16, 12, "STACK", 6, &HFC, &HEC
  L2.Big 112, 66, "ER", 4, &H1F, &H0B
  Board.Text 6, 20, "FILL WHOLE ROWS TO CLEAR THEM.", C_WHITE
  Board.Text 3, 26, "O P MOVE  A DOWN  SPACE DROP", C_CYAN
  Board.Text 3, 27, "Q W TURN  H HOLD  M MUSIC ON/OFF", C_CYAN
  Board.Text 8, 31, "(C) 2026 CYBORG UNICORN", C_WHITE
  was = 1
  Do
    If mode = 0 Then
      Board.Text 8, 22, "<  MARATHON  >          ", C_YELLOW
      Board.Text 8, 23, "START AT LEVEL" & Str$(startLv) & " (Q A) ", C_WHITE
      Board.Text 8, 24, "BEST " & Right$("000000" & Mid$(Str$(best(0)), 2), 7) & "     ", C_PINK
    Else
      Board.Text 8, 22, "<   SPRINT   >          ", C_YELLOW
      Board.Text 8, 23, "40 ROWS AGAINST THE CLOCK", C_WHITE
      If bestT Then Board.Text 8, 24, "BEST " & Clock(bestT) & "        ", C_PINK Else Board.Text 8, 24, "                  ", C_PINK
    End If
    Board.Text 12, 29, "SPACE: START", C_YELLOW
    Do
      Tick
      a = frames
      ' a few blocks bobbing about
      For k = 0 To 6
        Spr.Put k, 24 + k * 40, 138 + Val(Mid$(" 0 1 2 3 2 1 0-1-2-3-2-1", ((a \ 5 + k * 2) Mod 12) * 2 + 1, 2)), GfxData.S_BIG, Spr.Pal * (k + 1)
      Next
      k = Rnd(10)
      v = 0
      If Way() < 0 Then v = 1
      If Way() > 0 Then v = 2
      If Keys.Down(Keys.KeyQ) Then v = 3
      If Keys.Down(Keys.KeyA) Then v = 4
      If Fire() Or Keys.Down(Keys.KeyEnter) Then v = 9
      If v = 0 Then was = 0
    Loop Until v <> 0 And was = 0
    was = 1
    If v = 1 Or v = 2 Then mode = 1 - mode
    If v = 3 And startLv < 15 Then startLv = startLv + 1
    If v = 4 And startLv > 1 Then startLv = startLv - 1
  Loop Until v = 9
  Spr.HideRange 0, 64
End Sub

Function Clock(ByVal f As Long) As String
  Dim s As Long, cs As Long
  s = f \ 50 : cs = (f Mod 50) * 2
  Clock = Mid$(Str$(s \ 60), 2) & ":" & Right$("0" & Mid$(Str$(s Mod 60), 2), 2) & "." & Right$("0" & Mid$(Str$(cs), 2), 2)
End Function

' ---------------------------------------------------------------- a game
Sub Game()
  Board.Clear
  Backdrop
  For i = 0 To 219
    bd(i) = 0
  Next
  score = 0 : lines = 0 : level = startLv : timeF = 0 : over = 0
  If mode = 1 Then level = 1
  hold = -1 : bagN = 7 : musP = 0 : musT = 1
  Well
  For k = 0 To 2
    nq(k) = NextPiece()
  Next
  Panels
  NewPiece
  Do
    Tick
    If mode = 1 Then
      If frames Mod 5 = 0 Then Board.Text 3, 21, Clock(timeF) & " ", C_YELLOW
    End If
    Controls
    If over Then Exit Do
    If mode = 1 And lines >= 40 Then Exit Do
  Loop
  Sfx.Quiet
  If over Then
    ' the well fills with grey from the bottom
    For k = BH - 1 To 2 Step -1
      For i = 0 To BW - 1
        Board.Put WX + i, WY + k, GfxData.T_BLOCK, 9
      Next
      Sfx.Play 1, 100 + k * 20, 0, 10, 3, 1
      WaitF 3
    Next
    Board.Text WX + 1, WY + 10, "GAME OVER", C_PINK
    If mode = 0 And score > best(0) Then best(0) = score : Board.Text WX, WY + 12, "BEST SCORE", C_YELLOW
  Else
    over = 1
    Board.Text 3, 21, Clock(timeF) & " ", C_YELLOW
    Board.Text WX + 1, WY + 10, "40 ROWS!", C_YELLOW
    Board.Text WX + 1, WY + 12, Clock(timeF), C_WHITE
    If bestT = 0 Or timeF < bestT Then bestT = timeF : Board.Text WX + 1, WY + 14, "BEST TIME", C_PINK
    For k = 0 To 4
      Sfx.Play 0, 200 - k * 30, 0, 13, 10, 0
      WaitF 10
    Next
  End If
  WaitF 100
  Do
    Tick
  Loop Until Fire() Or Keys.Down(Keys.KeyEnter)
  Do
    Tick
  Loop While Fire()
End Sub

' the well's frame and floor
Sub Well()
  Board.Put WX - 1, WY + 1, GfxData.T_FRAME, 0
  Board.Put WX + BW, WY + 1, GfxData.T_FRAME + 2, 0
  For i = 0 To BW - 1
    Board.Put WX + i, WY + 1, GfxData.T_FRAME + 1, 0
    Board.Put WX + i, WY + BH, GfxData.T_FRAME + 6, 0
  Next
  For k = 2 To BH - 1
    Board.Put WX - 1, WY + k, GfxData.T_FRAME + 3, 0
    Board.Put WX + BW, WY + k, GfxData.T_FRAME + 4, 0
    For i = 0 To BW - 1
      Board.Put WX + i, WY + k, GfxData.T_FLOOR, 0
    Next
  Next
  Board.Put WX - 1, WY + BH, GfxData.T_FRAME + 5, 0
  Board.Put WX + BW, WY + BH, GfxData.T_FRAME + 7, 0
End Sub

' a box at x, y (inside w x h) with a title
Sub Box(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer, ByVal t As String)
  Dim a As Integer, b As Integer
  Board.Put x - 1, y - 1, GfxData.T_FRAME, 0 : Board.Put x + w, y - 1, GfxData.T_FRAME + 2, 0
  Board.Put x - 1, y + h, GfxData.T_FRAME + 5, 0 : Board.Put x + w, y + h, GfxData.T_FRAME + 7, 0
  For a = 0 To w - 1
    Board.Put x + a, y - 1, GfxData.T_FRAME + 1, 0 : Board.Put x + a, y + h, GfxData.T_FRAME + 6, 0
  Next
  For b = 0 To h - 1
    Board.Put x - 1, y + b, GfxData.T_FRAME + 3, 0 : Board.Put x + w, y + b, GfxData.T_FRAME + 4, 0
    For a = 0 To w - 1
      Board.Put x + a, y + b, GfxData.T_PANEL, 0
    Next
  Next
  Board.Text x, y - 2, t, C_WHITE
End Sub

Sub Panels()
  Box 3, 8, 6, 4, "HOLD"
  Box 28, 8, 6, 12, "NEXT"
  Box 3, 16, 9, 6, ""
  If mode = 0 Then Board.Text 1, 4, "MARATHON", C_YELLOW Else Board.Text 1, 4, "SPRINT 40", C_YELLOW
  Stats
  ShowNext
  ShowHold
End Sub

Sub Stats()
  Board.Text 3, 16, "SCORE", C_WHITE
  Board.Text 3, 17, Right$("0000000" & Mid$(Str$(score), 2), 7), C_YELLOW
  Board.Text 3, 18, "ROWS" & Right$("    " & Str$(lines), 5), C_CYAN
  Board.Text 3, 19, "LEVEL" & Right$("   " & Str$(level), 4), C_CYAN
  If mode = 1 Then Board.Text 3, 20, "TIME", C_WHITE
End Sub

' piece p drawn small at x, y (tiles), or cleared
Sub Mini(ByVal p As Integer, ByVal x As Integer, ByVal y As Integer)
  Dim s As String Max 8, j As Integer, up As Integer
  For j = 0 To 11
    Board.Put x + j Mod 4, y + j \ 4, GfxData.T_PANEL, 0
  Next
  If p < 0 Then Exit Sub
  s = Shape(p, 0)
  up = 0
  If p = 0 Then up = 1
  For j = 0 To 3
    Board.Put x + Val(Mid$(s, j * 2 + 1, 1)), y + Val(Mid$(s, j * 2 + 2, 1)) - up, GfxData.T_BLOCK, p + 1
  Next
End Sub

Sub ShowNext()
  For k = 0 To 2
    Mini nq(k), 29, 9 + k * 4
  Next
End Sub

Sub ShowHold()
  Mini hold, 4, 9
End Sub

' the next piece from the bag (each bag holds all seven, in a shuffled order)
Function NextPiece() As Integer
  Dim j As Integer, t As Integer, r As Integer
  If bagN >= 7 Then
    For j = 0 To 6
      bag(j) = j
    Next
    For j = 6 To 1 Step -1
      r = Rnd(j + 1)
      t = bag(j) : bag(j) = bag(r) : bag(r) = t
    Next
    bagN = 0
  End If
  NextPiece = bag(bagN)
  bagN = bagN + 1
End Function

Sub NewPiece()
  cur = nq(0) : nq(0) = nq(1) : nq(1) = nq(2) : nq(2) = NextPiece()
  ShowNext
  Spawn
  held = 0
End Sub

Sub Spawn()
  rot = 0 : cx = 3 : cy = 0
  If cur = 0 Then cy = 0
  lockT = 0 : resets = 0 : fallT = 0 : shown = 0
  If Fits(cx, cy, rot) = 0 Then over = 1 : Exit Sub
  ' (drop into view straight away)
  If Fits(cx, cy + 1, rot) Then cy = cy + 1
  Show
End Sub

' does the current piece fit at x, y in turn r
Function Fits(ByVal x As Integer, ByVal y As Integer, ByVal r As Integer) As Integer
  Dim s As String Max 8, j As Integer, a As Integer, b As Integer
  s = Shape(cur, r)
  Fits = 1
  For j = 0 To 3
    a = x + Asc(Mid$(s, j * 2 + 1, 1)) - 48 : b = y + Asc(Mid$(s, j * 2 + 2, 1)) - 48
    If a < 0 Or a >= BW Or b >= BH Then Fits = 0 : Exit Function
    If b >= 0 Then
      If bd(b * BW + a) Then Fits = 0 : Exit Function
    End If
  Next
End Function

' ---------------------------------------------------------------- drawing the piece and its ghost
Sub Show()
  Dim s As String Max 8, j As Integer, a As Integer, b As Integer
  ' off with the old
  If shown Then
    For j = 0 To 3
      Cell ogx(j), ogy(j)
      Cell ox(j), oy(j)
    Next
  End If
  gy = cy
  Do While Fits(cx, gy + 1, rot)
    gy = gy + 1
  Loop
  s = Shape(cur, rot)
  For j = 0 To 3
    a = cx + Asc(Mid$(s, j * 2 + 1, 1)) - 48 : b = Asc(Mid$(s, j * 2 + 2, 1)) - 48
    ogx(j) = a : ogy(j) = gy + b
    ox(j) = a : oy(j) = cy + b
  Next
  For j = 0 To 3
    If ogy(j) >= 2 Then Board.Put WX + ogx(j), WY + ogy(j), GfxData.T_GHOST, cur + 1
  Next
  For j = 0 To 3
    If oy(j) >= 2 Then Board.Put WX + ox(j), WY + oy(j), GfxData.T_BLOCK, cur + 1
  Next
  shown = 1
End Sub

' redraw a cell of the well from what's in it
Sub Cell(ByVal x As Integer, ByVal y As Integer)
  Dim c As Integer
  If y < 2 Then Exit Sub
  c = bd(y * BW + x)
  If c Then Board.Put WX + x, WY + y, GfxData.T_BLOCK, c Else Board.Put WX + x, WY + y, GfxData.T_FLOOR, 0
End Sub

' ---------------------------------------------------------------- playing
Function Gravity() As Integer
  Dim l As Integer
  l = level
  If l > 20 Then l = 20
  Gravity = Val(Mid$("4036322823191511070504040403030302020201", (l - 1) * 2 + 1, 2))
End Function

Sub Controls()
  Dim w As Integer, j As Integer, t As Integer, moved As Integer, drop As Integer
  moved = 0
  ' left / right: once, then repeating after a moment
  w = Way()
  If w <> 0 Then
    If w <> dasW Then
      dasW = w : das = 0
      If Fits(cx + w, cy, rot) Then cx = cx + w : moved = 1 : Sfx.Play 1, 400, 0, 6, 2, 0
    Else
      das = das + 1
      If das >= 10 And das Mod 2 = 0 Then
        If Fits(cx + w, cy, rot) Then cx = cx + w : moved = 1
      End If
    End If
  Else
    dasW = 0
  End If
  ' turning (with a nudge sideways or up if it won't fit)
  t = 0
  If Keys.Down(Keys.KeyQ) Or (Keys.Joystick(0) And Keys.JoyUp) Then t = 1
  If Keys.Down(Keys.KeyW) Then t = 3
  If t And rotWas = 0 Then
    If Turn((rot + t) And 3) Then moved = 1 : Sfx.Play 1, 300, -10, 7, 3, 0
  End If
  rotWas = t
  ' hold
  If Keys.Down(Keys.KeyH) Then
    If holdWas = 0 And held = 0 Then
      HideCur
      If hold < 0 Then
        hold = cur : ShowHold : NewPiece
      Else
        j = hold : hold = cur : cur = j : ShowHold : Spawn
      End If
      held = 1
      Sfx.Play 2, 150, 10, 9, 6, 0
      holdWas = 1
      Exit Sub
    End If
    holdWas = 1
  Else
    holdWas = 0
  End If
  ' the music
  If Keys.Down(Keys.KeyM) Then
    If musWas = 0 Then music = 1 - music : Sfx.Quiet
    musWas = 1
  Else
    musWas = 0
  End If
  ' a hard drop
  If Fire() Then
    If dropWas = 0 Then
      dropWas = 1
      Points CLng(gy - cy) * 2
      cy = gy
      Show
      Sfx.Play 2, 60, 4, 13, 6, 1
      Lock
      Exit Sub
    End If
  Else
    dropWas = 0
  End If
  ' falling: faster while A (or down) is held
  drop = Gravity()
  If Keys.Down(Keys.KeyA) Or (Keys.Joystick(0) And Keys.JoyDown) Then
    If drop > 2 Then drop = 2
  End If
  fallT = fallT + 1
  If fallT >= drop Then
    fallT = 0
    If Fits(cx, cy + 1, rot) Then
      cy = cy + 1 : moved = 1 : lockT = 0
      If drop = 2 And Gravity() > 2 Then Points 1
    End If
  End If
  ' resting on something: it locks after a moment (moving it puts that off, up to 15 times)
  If Fits(cx, cy + 1, rot) = 0 Then
    lockT = lockT + 1
    If moved And resets < 15 Then lockT = 0 : resets = resets + 1
    If lockT >= 30 Then Lock : Exit Sub
  End If
  If moved Then Show
End Sub

Function Turn(ByVal r As Integer) As Integer
  Dim j As Integer, kx As Integer, ky As Integer
  Turn = 0
  For j = 0 To 7
    kx = Val(Mid$(" 0-1 1 0-1 1-2 2", j * 2 + 1, 2)) : ky = Val(Mid$(" 0 0 0-1-1-1 0 0", j * 2 + 1, 2))
    If j >= 6 And cur <> 0 Then Exit Function
    If Fits(cx + kx, cy + ky, r) Then
      cx = cx + kx : cy = cy + ky : rot = r : Turn = 1
      Exit Function
    End If
  Next
End Function

Sub HideCur()
  Dim j As Integer
  If shown Then
    For j = 0 To 3
      Cell ogx(j), ogy(j)
      Cell ox(j), oy(j)
    Next
  End If
  shown = 0
End Sub

' the piece stays where it is: full rows go, the next piece comes
Sub Lock()
  Dim j As Integer, y As Integer, x As Integer, n As Integer, f As Integer, w As Integer
  For j = 0 To 3
    If oy(j) >= 0 Then bd(oy(j) * BW + ox(j)) = cur + 1
  Next
  For j = 0 To 3
    Cell ogx(j), ogy(j)
    Cell ox(j), oy(j)
  Next
  shown = 0
  Sfx.Play 2, 80, 2, 9, 4, 1
  ' full rows?
  n = 0
  For y = 0 To BH - 1
    f = 1
    For x = 0 To BW - 1
      If bd(y * BW + x) = 0 Then f = 0 : Exit For
    Next
    If f Then full(n) = y : n = n + 1
  Next
  If n > 0 Then
    ' they flash, then go
    For w = 0 To 15
      For j = 0 To n - 1
        For x = 0 To BW - 1
          If w Mod 4 < 2 Then Board.Put WX + x, WY + full(j), GfxData.T_BLOCK, 8 Else Cell x, full(j)
        Next
      Next
      If w = 0 Then
        If n = 4 Then Sfx.Play 0, 100, -3, 15, 30, 0 Else Sfx.Play 1, 200, -8, 13, 15, 0
      End If
      Tick
    Next
    For j = 0 To n - 1
      For y = full(j) To 1 Step -1
        For x = 0 To BW - 1
          bd(y * BW + x) = bd((y - 1) * BW + x)
        Next
      Next
      For x = 0 To BW - 1
        bd(x) = 0
      Next
    Next
    For y = 2 To BH - 1
      For x = 0 To BW - 1
        Cell x, y
      Next
    Next
    lines = lines + n
    Points CLng(Val(Mid$("010030050080", (n - 1) * 3 + 1, 3))) * 10 * level
    If mode = 0 And lines \ 10 + startLv > level Then
      level = lines \ 10 + startLv
      Sfx.Play 2, 50, -2, 14, 30, 0
    End If
    Stats
  End If
  WaitF 4
  NewPiece
End Sub

Sub Points(ByVal n As Long)
  score = score + n
  Board.Text 3, 17, Right$("0000000" & Mid$(Str$(score), 2), 7), C_YELLOW
End Sub
