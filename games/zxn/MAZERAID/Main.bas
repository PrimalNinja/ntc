' MAZERAID - a maze chase for the ZX Spectrum Next, in NTC BASIC (VB5 flavour)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' A beetle bot eats the power dots of a maze while four hover sentries hunt it. A power cell
' turns the tables for a few seconds. Each sentry hunts its own way: SPARK goes straight for the
' beetle, GLITCH for where it is heading, BOLT works with SPARK, DRIFT keeps its distance.
'
' Straight to the Next's hardware: the maze, the dots and the text are the tilemap (Tiles.cls),
' the beetle and the sentries hardware sprites (Spr.cls), the sound the AY (Sfx.cls). The art
' is in gfx/ - swap it with gfxtool.js.
'
' Keys: Q A O P or the cursor keys (5 6 7 8), or a Kempston joystick.
Option Explicit
Option Turbo

Const MX0 = 6, MY0 = 2               ' the maze's top left cell on the tilemap
Const MW = 27, MH = 27
' cells
Const C_EMPTY = 0, C_DOT = 1, C_POWER = 2, C_WALL = 3, C_DOOR = 4, C_PEN = 5
' sentry states
Const ST_PEN = 0, ST_LEAVE = 1, ST_ROAM = 2, ST_EYES = 3, ST_ENTER = 4
' sprite slots
Const SL_PLAYER = 0, SL_BODY = 1, SL_EYES = 5, SL_BONUS = 9, SL_PTS = 10

Dim cell(26, 26) As Byte
Dim edge(26, 26) As Byte
Dim m(26) As String Max 27
Dim ddx(3) As Integer, ddy(3) As Integer
' entities: 0 the beetle, 1-4 the sentries
Dim ex(4) As Integer, ey(4) As Integer, ed(4) As Integer, acc(4) As Integer
Dim st(4) As Integer, fr(4) As Integer, pwait(4) As Integer, cx(4) As Integer, cy(4) As Integer
Dim want As Integer, moving As Integer, panim As Integer, pwas As Integer
Dim score As Long, hiscore As Long, nextlife As Long
Dim lives As Integer, level As Integer, dots As Integer, eaten As Integer, over As Integer
Dim mode As Integer, mtimer As Integer, mphase As Integer, ftimer As Integer, chain As Integer
Dim bonust As Integer, bonusk As Integer, ptst As Integer, dying As Integer
Dim frames As Integer, seed As Integer, firewas As Integer, munch As Integer, siren As Integer
Dim i As Integer

ddx(0) = 1 : ddy(0) = 0 : ddx(1) = 0 : ddy(1) = 1 : ddx(2) = -1 : ddy(2) = 0 : ddx(3) = 0 : ddy(3) = -1
MazeData
Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Nx.Layers Nx.OrderSLU
hiscore = 2000
Do
  Title
  Play
  GameOver
Loop

' ---------------------------------------------------------------- the maze
Sub MazeData()
  m(0) = "###########################"
  m(1) = "#.........................#"
  m(2) = "#.###.###.###.###.###.###.#"
  m(3) = "#o###.###.###.###.###.###o#"
  m(4) = "#.###.###.###.###.###.###.#"
  m(5) = "#.....###.........###.....#"
  m(6) = "#.#######.###.###.#######.#"
  m(7) = "#.#######.###.###.#######.#"
  m(8) = "#.#######.###.###.#######.#"
  m(9) = "#.........................#"
  m(10) = "#####.###.### ###.###.#####"
  m(11) = "#####.###.###-###.###.#####"
  m(12) = "#####.###.#ppppp#.###.#####"
  m(13) = "      ....#ppppp#....      "
  m(14) = "#####.###.#ppppp#.###.#####"
  m(15) = "#####.###.#######.###.#####"
  m(16) = "#####.###.#######.###.#####"
  m(17) = "#............ ............#"
  m(18) = "#.#######.#######.#######.#"
  m(19) = "#.#######.#######.#######.#"
  m(20) = "#.#######.#######.#######.#"
  m(21) = "#.....###.........###.....#"
  m(22) = "#.###.#######.#######.###.#"
  m(23) = "#o###.#######.#######.###o#"
  m(24) = "#.###.#######.#######.###.#"
  m(25) = "#.........................#"
  m(26) = "###########################"
End Sub

' the cells from the text, the wall edges (a wall next to anything else), the dots counted
Sub BuildMaze()
  Dim x As Integer, y As Integer, ch As String, a As Integer, b As Integer, n As Integer
  dots = 0
  For y = 0 To MH - 1
    For x = 0 To MW - 1
      ch = Mid$(m(y), x + 1, 1)
      Select Case ch
        Case "#": n = C_WALL
        Case ".": n = C_DOT : dots = dots + 1
        Case "o": n = C_POWER : dots = dots + 1
        Case "-": n = C_DOOR
        Case "p": n = C_PEN
        Case Else: n = C_EMPTY
      End Select
      cell(x, y) = n
    Next
  Next
  For y = 0 To MH - 1
    For x = 0 To MW - 1
      n = 0
      If cell(x, y) = C_WALL Then
        For b = y - 1 To y + 1
          For a = x - 1 To x + 1
            If a >= 0 And a < MW And b >= 0 And b < MH Then
              If cell(a, b) <> C_WALL Then n = 1
            End If
          Next
        Next
      End If
      edge(x, y) = n
    Next
  Next
End Sub

Function IsEdge(ByVal x As Integer, ByVal y As Integer) As Integer
  IsEdge = 0
  If x < 0 Or x >= MW Or y < 0 Or y >= MH Then Exit Function
  IsEdge = edge(x, y)
End Function

Sub DrawMaze()
  Dim x As Integer, y As Integer, t As Integer, mk As Integer
  For y = 0 To MH - 1
    For x = 0 To MW - 1
      Select Case cell(x, y)
        Case C_WALL
          If edge(x, y) Then
            mk = 0
            If IsEdge(x, y - 1) Then mk = mk + 1
            If IsEdge(x + 1, y) Then mk = mk + 2
            If IsEdge(x, y + 1) Then mk = mk + 4
            If IsEdge(x - 1, y) Then mk = mk + 8
            t = GfxData.T_WALL + mk
          Else
            t = 0
          End If
        Case C_DOT: t = GfxData.T_DOT
        Case C_POWER: t = GfxData.T_POWER
        Case C_DOOR: t = GfxData.T_DOOR
        Case Else: t = 0
      End Select
      Tiles.Put MX0 + x, MY0 + y, t
    Next
  Next
End Sub

' can a thing go into cell x, y? who: 0 the beetle, 1 a sentry about, 2 a sentry using the door
Function CanGo(ByVal x As Integer, ByVal y As Integer, ByVal who As Integer) As Integer
  Dim c As Integer
  If x < 0 Or x >= MW Then
    CanGo = (y = 13)
    Exit Function
  End If
  If y < 0 Or y >= MH Then
    CanGo = 0
    Exit Function
  End If
  c = cell(x, y)
  Select Case c
    Case C_WALL: CanGo = 0
    Case C_DOOR, C_PEN: CanGo = (who = 2)
    Case Else: CanGo = -1
  End Select
End Function

' the cell a pixel coordinate is in (floor, also for the tunnel's negatives)
Function CellOf(ByVal v As Integer) As Integer
  CellOf = (v + 64) \ 8 - 8
End Function

' ---------------------------------------------------------------- input
Function Want4() As Integer
  Dim j As Integer
  j = Keys.Joystick(0)
  Want4 = -1
  If Keys.Down(Keys.KeyP) Or Keys.Down(Keys.KeyRight) Or (j And Keys.JoyRight) Then Want4 = 0
  If Keys.Down(Keys.KeyO) Or Keys.Down(Keys.KeyLeft) Or (j And Keys.JoyLeft) Then Want4 = 2
  If Keys.Down(Keys.KeyA) Or Keys.Down(Keys.KeyDown) Or (j And Keys.JoyDown) Then Want4 = 1
  If Keys.Down(Keys.KeyQ) Or Keys.Down(Keys.KeyUp) Or (j And Keys.JoyUp) Then Want4 = 3
End Function

Function FirePressed() As Integer
  Dim f As Integer
  f = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyEnter) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
  FirePressed = f And Not firewas
  firewas = f
End Function

' ---------------------------------------------------------------- text, the side panels
Sub Panels()
  Tiles.Text 0, 3, "SCORE"
  Tiles.Text 0, 4, Format$(score, "000000")
  Tiles.Text 0, 7, "HIGH"
  Tiles.Text 0, 8, Format$(hiscore, "000000")
  Tiles.Text 34, 3, "LEVEL"
  Tiles.Text 34, 4, Format$(level, "00") & "   "
  Tiles.Text 34, 7, "LIVES"
  Tiles.Rect 34, 8, 6, 1, 0
  For i = 1 To lives - 1
    If i < 6 Then Tiles.Put 33 + i, 8, GfxData.T_LIFE
  Next
End Sub

Sub BigText(ByVal x As Integer, ByVal y As Integer, ByVal s As String, ByVal colour As Integer)
  Dim n As Integer, r As Integer, b As Integer, bits As Integer, ch As String
  For n = 1 To Len(s)
    ch = Mid$(s, n, 1)
    For r = 0 To 4
      bits = Glyph(ch, r)
      For b = 0 To 2
        If bits And (4 \ (2 ^ b)) Then Tiles.Put x + b, y + r, GfxData.T_LOGO + colour
      Next
    Next
    x = x + 4
  Next
End Sub

Function Glyph(ByVal ch As String, ByVal r As Integer) As Integer
  Dim p As String
  Select Case ch
    Case "M": p = "57555"
    Case "A": p = "25755"
    Case "Z": p = "71247"
    Case "E": p = "74647"
    Case "R": p = "75654"
    Case "I": p = "72227"
    Case "D": p = "65556"
    Case Else: p = "00000"
  End Select
  Glyph = Val(Mid$(p, r + 1, 1))
End Function

' ---------------------------------------------------------------- the title
Sub Title()
  Dim k As Integer, n As Integer
  Spr.HideRange 0, 16
  Tiles.Fill 0
  BigText 5, 2, "MAZE", 0
  BigText 22, 2, "RAID", 1
  Tiles.Text 9, 9, "THE SENTRIES  -  WHO HUNTS"
  For n = 0 To 3
    Spr.Put SL_BODY + n, 72, 84 + n * 24, GfxData.S_SENTRY, Spr.Pal * n
    Spr.Put SL_EYES + n, 72, 84 + n * 24, GfxData.S_EYES, 0
  Next
  Tiles.Text 12, 11, "SPARK   STRAIGHT AT YOU"
  Tiles.Text 12, 14, "GLITCH  WHERE YOU GO"
  Tiles.Text 12, 17, "BOLT    WITH SPARK"
  Tiles.Text 12, 20, "DRIFT   KEEPS AWAY"
  Tiles.Put 11, 23, GfxData.T_DOT : Tiles.Text 13, 23, "10"
  Tiles.Put 18, 23, GfxData.T_POWER : Tiles.Text 20, 23, "50  POWER"
  Tiles.Text 7, 25, "Q A O P  OR CURSORS  MOVE"
  Tiles.Text 0, 0, "SCORE " & Format$(score, "000000")
  Tiles.Text 26, 0, "HI " & Format$(hiscore, "000000")
  Tiles.Text 7, 30, "NTC BASIC  ZX SPECTRUM NEXT"
  firewas = -1 : frames = 0
  Do
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1 : seed = seed + 1
    k = (frames \ 6) And 1
    For n = 0 To 3
      Spr.Put SL_BODY + n, 72, 84 + n * 24, GfxData.S_SENTRY + k, Spr.Pal * n
      Spr.Put SL_EYES + n, 72, 84 + n * 24, GfxData.S_EYES + ((frames \ 40 + n) And 3), 0
    Next
    Spr.Put SL_PLAYER, (frames * 2) Mod 340, 224, GfxData.S_RIGHT + ((frames \ 4) Mod 3), 0
    If (frames And 31) = 0 Then Tiles.Text 10, 27, "PRESS SPACE TO START"
    If (frames And 31) = 20 Then Tiles.Text 10, 27, "                    "
  Loop Until FirePressed()
  Nx.Seed seed
End Sub

' ---------------------------------------------------------------- a game
Sub Play()
  score = 0 : lives = 3 : level = 1 : over = 0 : nextlife = 10000
  NewLevel
  Do
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1
    If dying > 0 Then
      Dying1
    Else
      MovePlayer
      For i = 1 To 4
        MoveSentry i
      Next
      Catch
      Timers
      If eaten = dots Then LevelDone
    End If
    Draw
  Loop Until over
End Sub

Sub NewLevel()
  BuildMaze
  Tiles.Fill 0
  DrawMaze
  eaten = 0
  Panels
  StartPositions
  Ready
End Sub

Sub StartPositions()
  Dim n As Integer
  ' the beetle under the pen, the sentries: SPARK over the door, the others in the pen
  ex(0) = 13 * 8 + 4 : ey(0) = 17 * 8 + 4 : ed(0) = 2 : want = 2 : moving = 1
  ex(1) = 13 * 8 + 4 : ey(1) = 9 * 8 + 4 : ed(1) = 2 : st(1) = ST_ROAM
  ex(2) = 13 * 8 + 4 : ey(2) = 13 * 8 + 4 : ed(2) = 3 : st(2) = ST_PEN
  ex(3) = 11 * 8 + 4 : ey(3) = 13 * 8 + 4 : ed(3) = 3 : st(3) = ST_PEN
  ex(4) = 15 * 8 + 4 : ey(4) = 13 * 8 + 4 : ed(4) = 3 : st(4) = ST_PEN
  pwait(1) = 0 : pwait(2) = 60 : pwait(3) = 300 : pwait(4) = 600
  For n = 0 To 4
    acc(n) = 0 : fr(n) = 0
  Next
  ' scatter corners
  cx(1) = 25 : cy(1) = -2 : cx(2) = 1 : cy(2) = -2 : cx(3) = 26 : cy(3) = 28 : cx(4) = 0 : cy(4) = 28
  mode = 0 : mphase = 0 : mtimer = 350 : ftimer = 0 : bonust = 0 : ptst = 0 : dying = 0 : siren = 0
  Spr.HideRange 0, 16
End Sub

' "READY" for two seconds
Sub Ready()
  Dim n As Integer
  Tiles.Text MX0 + 11, MY0 + 17, "READY"
  Draw
  Sfx.Play 0, 400, -6, 12, 40, 0
  For n = 1 To 100
    Frame
    Spr.Show
    Sfx.Update
    If n = 50 Then Sfx.Play 1, 300, -4, 12, 40, 0
  Next
  Tiles.Rect MX0 + 11, MY0 + 17, 5, 1, 0
End Sub

' ---------------------------------------------------------------- the beetle
Function Speed(ByVal n As Integer) As Integer
  Dim s As Integer, l As Integer
  l = level
  If l > 6 Then l = 6
  If n = 0 Then
    Speed = 19 + l
    Exit Function
  End If
  Select Case st(n)
    Case ST_EYES: s = 40
    Case ST_PEN, ST_LEAVE, ST_ENTER: s = 10
    Case Else
      If fr(n) Then
        s = 10
      Else
        s = 16 + l
        If ey(n) = 13 * 8 + 4 And (ex(n) < 44 Or ex(n) > 172) Then s = 9   ' the tunnel
      End If
  End Select
  Speed = s
End Function

Sub MovePlayer()
  Dim w As Integer, k As Integer
  w = Want4()
  If w >= 0 Then want = w
  ' turning back can happen anywhere
  If want = ((ed(0) + 2) And 3) Then
    ed(0) = want : moving = 1
  End If
  acc(0) = acc(0) + Speed(0)
  Do While acc(0) >= 16
    acc(0) = acc(0) - 16
    StepPlayer
  Loop
  If moving Then panim = panim + 1
End Sub

Sub StepPlayer()
  Dim tx As Integer, ty As Integer
  If (ex(0) And 7) = 4 And (ey(0) And 7) = 4 Then
    tx = CellOf(ex(0)) : ty = CellOf(ey(0))
    EatAt tx, ty
    If CanGo(tx + ddx(want), ty + ddy(want), 0) Then ed(0) = want
    moving = CanGo(tx + ddx(ed(0)), ty + ddy(ed(0)), 0)
    If moving = 0 Then Exit Sub
  End If
  If moving = 0 Then Exit Sub
  ex(0) = ex(0) + ddx(ed(0)) : ey(0) = ey(0) + ddy(ed(0))
  Wrap 0
End Sub

Sub Wrap(ByVal n As Integer)
  If ex(n) < -12 Then ex(n) = 228
  If ex(n) > 228 Then ex(n) = -12
End Sub

Sub EatAt(ByVal tx As Integer, ByVal ty As Integer)
  Dim n As Integer
  If tx < 0 Or tx >= MW Then Exit Sub
  Select Case cell(tx, ty)
    Case C_DOT
      cell(tx, ty) = C_EMPTY
      Tiles.Put MX0 + tx, MY0 + ty, 0
      eaten = eaten + 1
      AddScore 10
      munch = 1 - munch
      Sfx.Play 0, 260 + munch * 60, -20, 10, 4, 0
      If eaten = 70 Or eaten = 170 Then
        bonust = 500 : bonusk = (level - 1) And 3
      End If
    Case C_POWER
      cell(tx, ty) = C_EMPTY
      Tiles.Put MX0 + tx, MY0 + ty, 0
      eaten = eaten + 1
      AddScore 50
      ftimer = 420 - level * 40
      If ftimer < 90 Then ftimer = 90
      chain = 0
      For n = 1 To 4
        If st(n) = ST_ROAM Then
          fr(n) = 1
          ed(n) = (ed(n) + 2) And 3
        End If
      Next
  End Select
End Sub

Sub AddScore(ByVal n As Integer)
  score = score + n
  If score >= nextlife Then
    nextlife = nextlife + 10000
    If lives < 6 Then lives = lives + 1
    Sfx.Play 2, 100, -2, 15, 40, 0
  End If
  If score > hiscore Then hiscore = score
  Tiles.Text 0, 4, Format$(score, "000000")
  Tiles.Text 0, 8, Format$(hiscore, "000000")
End Sub

' ---------------------------------------------------------------- the sentries
Sub MoveSentry(ByVal n As Integer)
  acc(n) = acc(n) + Speed(n)
  Do While acc(n) >= 16
    acc(n) = acc(n) - 16
    StepSentry n
  Loop
End Sub

Sub StepSentry(ByVal n As Integer)
  Select Case st(n)
    Case ST_PEN
      ' bob up and down until its time comes
      If ey(n) <= 12 * 8 + 6 Then ed(n) = 1
      If ey(n) >= 13 * 8 + 2 Then ed(n) = 3
      ey(n) = ey(n) + ddy(ed(n))
      If pwait(n) <= 0 Then st(n) = ST_LEAVE
    Case ST_LEAVE
      ' to the middle, then up and out of the door
      If ex(n) < 108 Then
        ex(n) = ex(n) + 1 : ed(n) = 0
      ElseIf ex(n) > 108 Then
        ex(n) = ex(n) - 1 : ed(n) = 2
      Else
        ey(n) = ey(n) - 1 : ed(n) = 3
        If ey(n) <= 9 * 8 + 4 Then
          ey(n) = 9 * 8 + 4 : st(n) = ST_ROAM : ed(n) = 2 : fr(n) = 0
        End If
      End If
    Case ST_ENTER
      ey(n) = ey(n) + 1 : ed(n) = 1
      If ey(n) >= 13 * 8 + 4 Then
        st(n) = ST_LEAVE : fr(n) = 0
      End If
    Case Else
      If (ex(n) And 7) = 4 And (ey(n) And 7) = 4 Then
        If st(n) = ST_EYES And ex(n) = 108 And ey(n) = 9 * 8 + 4 Then
          st(n) = ST_ENTER
          Exit Sub
        End If
        Choose4 n
      End If
      ex(n) = ex(n) + ddx(ed(n)) : ey(n) = ey(n) + ddy(ed(n))
      Wrap n
  End Select
End Sub

' at a cell's middle: the way out that gets nearest the target (not back the way it came)
Sub Choose4(ByVal n As Integer)
  Dim tx As Integer, ty As Integer, gx As Integer, gy As Integer, d As Integer, best As Integer
  Dim bd As Integer, dist As Integer, ax As Integer, ay As Integer, who As Integer, back As Integer
  Dim px As Integer, py As Integer, pd As Integer, k As Integer
  tx = CellOf(ex(n)) : ty = CellOf(ey(n))
  back = (ed(n) + 2) And 3
  who = 1
  If st(n) = ST_EYES Then who = 2
  If fr(n) And st(n) = ST_ROAM Then
    ' scared: any way but back, at random
    k = Rnd(4)
    For d = 0 To 3
      best = (k + d) And 3
      If best <> back And CanGo(tx + ddx(best), ty + ddy(best), who) Then
        ed(n) = best
        Exit Sub
      End If
    Next
    ed(n) = back
    Exit Sub
  End If
  ' the target
  px = CellOf(ex(0)) : py = CellOf(ey(0)) : pd = ed(0)
  If st(n) = ST_EYES Then
    gx = 13 : gy = 9
  ElseIf mode = 0 Then
    gx = cx(n) : gy = cy(n)
  Else
    Select Case n
      Case 1
        gx = px : gy = py
      Case 2
        gx = px + 4 * ddx(pd) : gy = py + 4 * ddy(pd)
      Case 3
        ax = px + 2 * ddx(pd) : ay = py + 2 * ddy(pd)
        gx = 2 * ax - CellOf(ex(1)) : gy = 2 * ay - CellOf(ey(1))
      Case Else
        If (tx - px) * (tx - px) + (ty - py) * (ty - py) > 64 Then
          gx = px : gy = py
        Else
          gx = cx(n) : gy = cy(n)
        End If
    End Select
  End If
  best = -1 : bd = 32767
  ' the order up, left, down, right settles ties
  For k = 0 To 3
    d = Choose(k + 1, 3, 2, 1, 0)
    If d <> back Then
      If CanGo(tx + ddx(d), ty + ddy(d), who) Then
        ax = tx + ddx(d) - gx : ay = ty + ddy(d) - gy
        If ax > 100 Or ax < -100 Then ax = 100
        If ay > 100 Or ay < -100 Then ay = 100
        dist = ax * ax + ay * ay
        If dist < bd Then
          bd = dist : best = d
        End If
      End If
    End If
  Next
  If best < 0 Then best = back
  ed(n) = best
End Sub

' ---------------------------------------------------------------- meeting, timers
Sub Catch()
  Dim n As Integer
  For n = 1 To 4
    If Abs(ex(n) - ex(0)) < 7 And Abs(ey(n) - ey(0)) < 7 Then
      If st(n) = ST_ROAM Then
        If fr(n) Then
          ' caught a scared one
          st(n) = ST_EYES : fr(n) = 0
          AddScore 200 * (2 ^ chain)
          Spr.Put SL_PTS, 40 + ex(n), 8 + ey(n), GfxData.S_PTS + chain, 0
          ptst = 50
          If chain < 3 Then chain = chain + 1
          Sfx.Play 1, 400, -16, 15, 20, 0
        Else
          dying = 120
          Sfx.Quiet
          Sfx.Play 0, 150, 6, 15, 90, 0
          Exit Sub
        End If
      End If
    End If
  Next
  ' the bonus item
  If bonust > 0 Then
    If Abs(ex(0) - 108) < 6 And ey(0) = 17 * 8 + 4 Then
      bonust = 0
      AddScore 100 * Choose(bonusk + 1, 1, 3, 5, 10)
      Spr.Hide SL_BONUS
      Sfx.Play 2, 80, 2, 15, 25, 0
    End If
  End If
End Sub

Sub Timers()
  Dim n As Integer
  For n = 2 To 4
    If st(n) = ST_PEN Then pwait(n) = pwait(n) - 1
  Next
  If ftimer > 0 Then
    ftimer = ftimer - 1
    If ftimer = 0 Then
      For n = 1 To 4
        fr(n) = 0
      Next
    End If
    siren = siren + 1
    If (siren And 15) = 0 Then Sfx.Play 2, 180, -8, 8, 15, 0
  Else
    ' scatter, chase ... (the times go on in turn, the last chase for ever)
    mtimer = mtimer - 1
    If mtimer = 0 And mphase < 5 Then
      mphase = mphase + 1
      mode = mphase And 1
      mtimer = Choose(mphase + 1, 350, 1000, 350, 1000, 250, 32000)
      For n = 1 To 4
        If st(n) = ST_ROAM Then ed(n) = (ed(n) + 2) And 3
      Next
    End If
  End If
  If bonust > 0 Then
    bonust = bonust - 1
    If bonust = 0 Then Spr.Hide SL_BONUS
  End If
  If ptst > 0 Then
    ptst = ptst - 1
    If ptst = 0 Then Spr.Hide SL_PTS
  End If
  ' the power cells flash
  If (frames And 15) = 0 Then PowerTiles GfxData.T_POWER
  If (frames And 15) = 8 Then PowerTiles GfxData.T_POWER + 1
End Sub

Sub PowerTiles(ByVal t As Integer)
  If cell(1, 3) = C_POWER Then Tiles.Put MX0 + 1, MY0 + 3, t
  If cell(25, 3) = C_POWER Then Tiles.Put MX0 + 25, MY0 + 3, t
  If cell(1, 23) = C_POWER Then Tiles.Put MX0 + 1, MY0 + 23, t
  If cell(25, 23) = C_POWER Then Tiles.Put MX0 + 25, MY0 + 23, t
End Sub

' ---------------------------------------------------------------- drawing
Sub Draw()
  Dim n As Integer, p As Integer, f As Integer, x As Integer, y As Integer, a As Integer
  ' the beetle
  If dying = 0 Then
    a = (panim \ 3) And 3
    If a = 3 Then a = 1
    If ed(0) = 0 Or ed(0) = 2 Then p = GfxData.S_RIGHT + a Else p = GfxData.S_UP + a
    f = 0
    If ed(0) = 2 Then f = Spr.MirrorX
    If ed(0) = 1 Then f = Spr.MirrorY
    PutAt SL_PLAYER, ex(0), ey(0), p, f
  End If
  For n = 1 To 4
    x = ex(n) : y = ey(n)
    If st(n) = ST_EYES Or st(n) = ST_ENTER Then
      Spr.Hide SL_BODY + n - 1
    ElseIf fr(n) Then
      f = 0
      If ftimer < 100 And (frames And 8) Then f = Spr.Pal * 4
      PutAt SL_BODY + n - 1, x, y, GfxData.S_SCARED + ((frames \ 4) And 1), f
    Else
      PutAt SL_BODY + n - 1, x, y, GfxData.S_SENTRY + ((frames \ 4) And 1), Spr.Pal * (n - 1)
    End If
    If fr(n) And st(n) = ST_ROAM Then
      Spr.Hide SL_EYES + n - 1
    Else
      PutAt SL_EYES + n - 1, x, y, GfxData.S_EYES + ed(n), 0
    End If
  Next
  If bonust > 0 Then PutAt SL_BONUS, 108, 17 * 8 + 4, GfxData.S_BONUS + bonusk, 0
End Sub

' a sprite centred on maze pixel x, y (hidden in the tunnel's far ends)
Sub PutAt(ByVal slot As Integer, ByVal x As Integer, ByVal y As Integer, ByVal p As Integer, ByVal f As Integer)
  If x < -4 Or x > 220 Then
    Spr.Hide slot
  Else
    Spr.Put slot, MX0 * 8 + x - 8, MY0 * 8 + y - 8, p, f
  End If
End Sub

' ---------------------------------------------------------------- losing a life, a level done
Sub Dying1()
  Dim n As Integer
  dying = dying - 1
  If dying > 90 Then Exit Sub
  If dying = 90 Then Spr.HideRange SL_BODY, 10
  If dying > 30 Then
    n = (90 - dying) \ 10
    If n > 5 Then n = 5
    PutAt SL_PLAYER, ex(0), ey(0), GfxData.S_DIE + n, 0
  ElseIf dying = 30 Then
    Spr.Hide SL_PLAYER
  End If
  If dying = 0 Then
    lives = lives - 1
    If lives = 0 Then
      over = 1
    Else
      Panels
      StartPositions
      Ready
    End If
  End If
End Sub

Sub LevelDone()
  Dim n As Integer
  Spr.HideRange SL_BODY, 10
  Sfx.Quiet
  For n = 1 To 120
    Frame
    Spr.Show
    ' the walls flash
    If (n And 15) = 0 Then Nx.PalEntry Nx.PalTiles, 2, &HFF
    If (n And 15) = 8 Then Nx.PalEntry Nx.PalTiles, 2, &H2F
  Next
  Nx.PalEntry Nx.PalTiles, 2, &H2F
  level = level + 1
  NewLevel
End Sub

Sub GameOver()
  Dim n As Integer
  Tiles.Text MX0 + 9, MY0 + 17, "GAME  OVER"
  For n = 1 To 200
    Frame
    Spr.Show
    Sfx.Update
    If n > 50 And FirePressed() Then Exit For
  Next
  Sfx.Quiet
End Sub
