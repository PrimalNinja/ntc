' DANMAKU - a vertical scrolling bullet hell shooter for the ZX Spectrum Next, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Five stages, each with a boss at the end. Easy: clear every stage once. Medium: clear them all
' twice (the second loop is faster and meaner). Hard: twice through on one life.
'
' Keys: Q A O P move. Space (or Kempston fire): tap for a spread of shots, hold for the laser
'       (stronger, but you move slower). M (or Enter, or Kempston fire 2): a bomb - it clears
'       the bullets and hurts everything on screen.
' Kills in quick succession build the HIT chain: each kill scores more while it lasts.
'
' The background is Layer 2 blocks scrolled by the hardware (Bg.cls); the bullets and shots are
' hardware sprites moved and checked in Z80 (Bul.cls); the panel and the messages are the
' tilemap (on top); the sound is the AY.
Option Explicit
Option Turbo

Const NE = 20, NI = 3
' sprite slots (Bul has 50-127)
Const SP_PLAYER = 0, SP_LASER = 1, SP_FLARE = 11, SP_SPARK = 12, SP_EN = 13, SP_ITEM = 33, SP_BOSS = 36
Const BOXBOSS = 20
' enemy kinds
Const K_POP = 1, K_DART = 2, K_TANK = 3, K_TURRET = 4, K_CARRIER = 5, K_GUNSHIP = 6, K_BOOM = 7, K_BIGBOOM = 8
' a stage: waves until STAGELEN, the warning, the boss
Const STAGELEN = 2100, WARNAT = 2150, BOSSAT = 2300
' where the ship can go (sprite coordinates: the play area is 32-223 both ways)
Const XMIN = 40, XMAX = 216, YMIN = 44, YMAX = 214
' bullet colours (sprite palettes)
Const PINK = 2, BLUE = 3, GOLD = 4

Dim longText As String Max 120
' enemies: kind, position and speed (16ths of a pixel), life, timer, mode, when it fires, a hit flash
Dim ek(19) As Integer, ex(19) As Integer, ey(19) As Integer, evx(19) As Integer, evy(19) As Integer
Dim ehp(19) As Integer, et(19) As Integer, ea(19) As Integer, efire(19) As Integer, ef(19) As Integer
' each kind: life, score, half its box, sprite pattern, twice the size, in the air (hits the ship)
Dim khp(8) As Integer, kscore(8) As Integer, kbox(8) As Integer, kpat(8) As Integer, kbig(8) As Integer, kair(8) As Integer
' items: kind (1 power, 2 bomb, 3 score), position (pixels)
Dim ik(2) As Integer, ix(2) As Integer, iy(2) As Integer
' the boss
Dim bossOn As Integer, bossX As Integer, bossY As Integer, bossHP As Integer, bossMax As Integer, bossPh As Integer
Dim bossDie As Integer, bossVX As Integer, bossFl As Integer, bossBarV As Integer
' its two guns, per phase: type, interval, count, speed, spin, bullet, colour (3 phases x 2 x 7)
Dim em(41) As Integer, emT(1) As Integer, emAng(1) As Integer
' the map being made: the path's column, rows until it may turn, building tops waiting, a row
Dim pc As Integer, pturn As Integer, pend(11) As Integer, rowc(11) As Integer, noSpawn As Integer
' the ship
Dim px As Integer, py As Integer, alive As Integer, inv As Integer, deadT As Integer, power As Integer
Dim lives As Integer, bombs As Integer, bombT As Integer, fireHeld As Integer, burst As Integer, laserOn As Integer
Dim fireWas As Integer, bombWas As Integer, shotCool As Integer, laserHit As Integer, laserDmg As Integer, mx As Integer
Dim score As Long, hiscore As Long, nextExtend As Long
Dim chain As Integer, chainT As Integer, maxChain As Integer, gaugeWas As Integer
Dim mode As Integer, loopN As Integer, stage As Integer, stageT As Integer, frames As Integer, over As Integer
Dim cleared As Integer, clearT As Integer, msgT As Integer, waveT As Integer, sparkT As Integer, spdMul As Integer
Dim scoreDirty As Integer, altPal As Integer
Dim i As Integer, k As Integer

Setup
Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Bg.Init BgData.Blocks(), BgData.Colours()
Bul.Init GfxData.S_SHOT
Nx.Layers Nx.OrderUSL                   ' the tilemap on top (the panel, messages), sprites, Layer 2
Nx.Reg &H1C, 2                          ' the sprites cut to the play area (x halved: over the border)
Nx.Reg &H19, 16 : Nx.Reg &H19, 111 : Nx.Reg &H19, 32 : Nx.Reg &H19, 223
Nx.Reg &H15, Nx.RegGet(&H15) Or &H20
hiscore = 100000
Do
  Title
  Game
Loop

' ---------------------------------------------------------------- tables
Sub Setup()
  Kind K_POP, 3, 100, 9, GfxData.S_POP, 0, 1
  Kind K_DART, 5, 200, 9, GfxData.S_DART, 0, 1
  Kind K_TANK, 10, 300, 9, GfxData.S_TANK, 0, 0
  Kind K_TURRET, 16, 500, 9, GfxData.S_TURRET, 0, 0
  Kind K_CARRIER, 40, 1000, 17, GfxData.S_CARRIER, 1, 1
  Kind K_GUNSHIP, 130, 3000, 17, GfxData.S_GUNSHIP, 1, 1
End Sub

Sub Kind(ByVal kd As Integer, ByVal hp As Integer, ByVal sc As Integer, ByVal box As Integer, ByVal pat As Integer, ByVal big As Integer, ByVal air As Integer)
  khp(kd) = hp : kscore(kd) = sc : kbox(kd) = box : kpat(kd) = pat : kbig(kd) = big : kair(kd) = air
End Sub

' ---------------------------------------------------------------- the title
Sub Title()
  Dim y As Integer
  Spr.HideRange 0, 50 : Spr.Show
  Bul.Reset : Bul.Show
  stage = 1 : loopN = 1
  StartMap
  noSpawn = 1
  Panel
  Tiles.Text 9, 6, "D A N M A K U"
  Tiles.Text 7, 8, "BULLET HELL SHOOTER"
  Tiles.Text 5, 11, "1  EASY"
  Tiles.Text 8, 12, "EVERY STAGE ONCE"
  Tiles.Text 5, 14, "2  MEDIUM"
  Tiles.Text 8, 15, "EVERY STAGE TWICE"
  Tiles.Text 5, 17, "3  HARD"
  Tiles.Text 8, 18, "TWICE ON ONE LIFE"
  Tiles.Text 5, 21, "Q A O P   MOVE"
  Tiles.Text 5, 22, "SPACE     TAP: SHOT"
  Tiles.Text 5, 23, "          HOLD: LASER"
  Tiles.Text 5, 24, "M         BOMB"
  mode = 0 : y = 0
  Do
    If Bg.Phase() = 0 Then MakeRow
    Frame
    Bg.Scroll
    Sfx.Update
    y = y + 1
    If y = 30 Then Tiles.Text 9, 26, "PRESS 1, 2 OR 3"
    If y = 60 Then Tiles.Rect 4, 26, 24, 1, 0 : y = 0
    If Keys.Down(Keys.Key1) Then mode = 1
    If Keys.Down(Keys.Key2) Then mode = 2
    If Keys.Down(Keys.Key3) Then mode = 3
  Loop Until mode > 0
  Sfx.Play 0, 80, -2, 15, 25, 0
End Sub

' the panel on the right and round the edge; the play area see-through
Sub Panel()
  Tiles.Fill GfxData.T_PANEL
  Tiles.Rect 4, 4, 24, 24, 0
  For k = 4 To 27
    Tiles.Put 28, k, GfxData.T_PANELL
  Next
  Tiles.Text 29, 4, "SCORE"
  Tiles.Text 29, 7, "HI"
  Tiles.Text 29, 10, "STAGE"
  Tiles.Text 29, 13, "LIFE"
  Tiles.Text 29, 16, "BOMB"
  Tiles.Text 29, 19, "HIT"
  Tiles.Text 29, 23, "MAX HIT"
  ShowHi
End Sub

Sub ShowScore()
  Tiles.Text 29, 5, Right$("0000000" & Trim$(Str$(score)), 7)
  scoreDirty = 0
End Sub

Sub ShowHi()
  Tiles.Text 29, 8, Right$("0000000" & Trim$(Str$(hiscore)), 7)
End Sub

Sub ShowStage()
  Tiles.Text 29, 11, Trim$(Str$(loopN)) & "-" & Trim$(Str$(stage)) & "    "
  If mode = 1 Then Tiles.Text 29, 26, "EASY  "
  If mode = 2 Then Tiles.Text 29, 26, "MEDIUM"
  If mode = 3 Then Tiles.Text 29, 26, "HARD  "
End Sub

Sub ShowLives()
  For k = 0 To 5
    If k < lives Then Tiles.Put 29 + k, 14, GfxData.T_LIFE Else Tiles.Put 29 + k, 14, GfxData.T_PANEL
  Next
End Sub

Sub ShowBombs()
  For k = 0 To 5
    If k < bombs Then Tiles.Put 29 + k, 17, GfxData.T_BOMB Else Tiles.Put 29 + k, 17, GfxData.T_PANEL
  Next
End Sub

Sub ShowChain()
  Tiles.Text 29, 20, Trim$(Str$(chain)) & "    "
  Tiles.Text 29, 24, Trim$(Str$(maxChain)) & "    "
End Sub

' the chain gauge: 6 cells, 48 steps
Sub ShowGauge()
  Dim v As Integer, f As Integer
  v = chainT * 48 \ 90
  If v = gaugeWas Then Exit Sub
  gaugeWas = v
  For k = 0 To 5
    f = v - k * 8
    If f < 0 Then f = 0
    If f > 8 Then f = 8
    Tiles.Put 29 + k, 21, GfxData.T_GAUGE + f
  Next
End Sub

' a message across the middle of the play area for t frames
Sub Message(ByVal m As String, ByVal t As Integer)
  longText = m
  Tiles.Rect 4, 14, 24, 1, 0
  Tiles.Text 4 + (24 - Len(longText)) \ 2, 14, longText
  msgT = t
End Sub

' ---------------------------------------------------------------- the background
' a stage's look: its colours, and the whole screen drawn
Sub StartMap()
  Bg.Theme stage - 1
  Nx.Seed stage * 31 + loopN * 7
  pc = 5 : pturn = 0
  For k = 0 To 11
    pend(k) = 0
  Next
  noSpawn = 1
  For k = 1 To 192
    If Bg.Phase() = 0 Then MakeRow
    Bg.Scroll
  Next
  noSpawn = 0
End Sub

' the stage's ground
Function Ground() As Integer
  Dim r As Integer
  r = Rnd(16)
  If stage = 1 Then
    If r < 8 Then
      Ground = BgData.B_G1
    ElseIf r < 12 Then
      Ground = BgData.B_G2
    ElseIf r < 15 Then
      Ground = BgData.B_G3
    Else
      Ground = BgData.B_TREES
    End If
  ElseIf stage = 3 Then
    If r < 8 Then
      Ground = BgData.B_PLATE
    ElseIf r < 12 Then
      Ground = BgData.B_PLATE2
    ElseIf r < 15 Then
      Ground = BgData.B_GRILLE
    Else
      Ground = BgData.B_STRIPE
    End If
  ElseIf stage = 4 Then
    If r < 12 Then
      Ground = BgData.B_DARK
    ElseIf r < 14 Then
      Ground = BgData.B_PLATE
    ElseIf r < 15 Then
      Ground = BgData.B_PLATE2
    Else
      Ground = BgData.B_STRIPE
    End If
  Else
    If r < 7 Then
      Ground = BgData.B_G1
    ElseIf r < 11 Then
      Ground = BgData.B_G2
    ElseIf r < 15 Then
      Ground = BgData.B_G3
    Else
      Ground = BgData.B_CRATER
    End If
  End If
End Function

' the next row of blocks: ground, the path winding up the screen, buildings and things on it
Sub MakeRow()
  Dim c As Integer, r As Integer, tc As Integer, lo As Integer, hi As Integer, busy As Integer, n As Integer
  busy = 0
  For c = 0 To 11
    If pend(c) Then
      rowc(c) = pend(c) : pend(c) = 0 : busy = 1
    Else
      rowc(c) = Ground()
    End If
  Next
  If pturn > 0 Then pturn = pturn - 1
  If pturn = 0 And busy = 0 And Rnd(100) < 14 Then
    tc = pc + (2 + Rnd(3)) * (1 - 2 * Rnd(2))
    If tc < 1 Then tc = 1 + Rnd(2)
    If tc > 10 Then tc = 10 - Rnd(2)
    If tc = pc Then
      If pc > 5 Then tc = pc - 2 Else tc = pc + 2
    End If
    If tc < pc Then
      rowc(pc) = BgData.B_PSW : rowc(tc) = BgData.B_PNE : lo = tc + 1 : hi = pc - 1
    Else
      rowc(pc) = BgData.B_PSE : rowc(tc) = BgData.B_PNW : lo = pc + 1 : hi = tc - 1
    End If
    For c = lo To hi
      rowc(c) = BgData.B_PH
    Next
    pc = tc : pturn = 3
  Else
    rowc(pc) = BgData.B_PV
  End If
  ' on the ground: buildings (two by two), pads with guns, the stage's own things
  If busy = 0 Then
    c = 0
    Do While c < 12
      If rowc(c) <= BgData.B_G3 Or rowc(c) >= BgData.B_PLATE Then
        r = Rnd(100)
        If r < 5 And c < 11 Then
          If rowc(c + 1) <= BgData.B_G3 Or rowc(c + 1) >= BgData.B_PLATE Then
            If rowc(c + 1) <> BgData.B_PV Then
              rowc(c) = BgData.B_BBL : rowc(c + 1) = BgData.B_BBR
              pend(c) = BgData.B_BTL : pend(c + 1) = BgData.B_BTR
              c = c + 1
            End If
          End If
        ElseIf r < 6 + (stage + 1) \ 2 Then
          rowc(c) = BgData.B_PAD
          If noSpawn = 0 And stageT < STAGELEN - 100 Then
            n = Spawn(K_TURRET, 40 + c * 16, 24)
          End If
        ElseIf r < 10 Then
          If stage = 1 Then
            rowc(c) = BgData.B_TANKS
          ElseIf stage = 2 Then
            rowc(c) = BgData.B_VENT
          ElseIf stage = 3 Then
            rowc(c) = BgData.B_TOWER
          ElseIf stage = 4 Then
            rowc(c) = BgData.B_TOWER
          Else
            rowc(c) = BgData.B_CRATER
          End If
        End If
      End If
      c = c + 1
    Loop
  End If
  For c = 0 To 11
    Bg.Cell c, rowc(c)
  Next
End Sub

' ---------------------------------------------------------------- a game
Sub Game()
  If mode = 3 Then lives = 1 Else lives = 3
  bombs = 3 : power = 1 : score = 0 : chain = 0 : maxChain = 0 : loopN = 1 : stage = 1 : over = 0
  nextExtend = 500000
  Do
    StageRun
    If over Then Exit Do
    stage = stage + 1
    If stage > 5 Then
      If mode = 1 Or loopN = 2 Then
        Ending "ALL CLEAR!"
        Exit Sub
      End If
      loopN = 2 : stage = 1
    End If
  Loop
  Ending "GAME OVER"
End Sub

Sub Ending(ByVal m As String)
  Dim n As Integer, f As Integer, up As Integer
  If score > hiscore Then hiscore = score
  ShowHi
  Spr.HideRange 0, 50
  Bul.Reset
  Tiles.Rect 4, 4, 24, 1, 0
  Message m, 0
  If longText = "ALL CLEAR!" Then
    Tiles.Text 6, 16, "YOU BEAT THEM ALL"
    Sfx.Play 0, 100, -3, 15, 60, 0
  End If
  ' 6 seconds, or Space (or fire) after the first second: let go of it first, then press it
  up = 0
  For n = 1 To 300
    If Bg.Phase() = 0 Then MakeRow
    Frame
    Bg.Scroll
    Spr.Show
    Bul.Show
    Sfx.Update
    f = Keys.Down(Keys.KeySpace) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
    If f = 0 Then
      up = 1
    ElseIf up And n > 50 Then
      Exit Sub
    End If
  Next
End Sub

' one stage, from the scroll in to the boss beaten (or the last life lost)
Sub StageRun()
  For k = 0 To NE - 1
    ek(k) = 0
  Next
  For k = 0 To NI - 1
    ik(k) = 0
  Next
  bossOn = 0 : bossBarV = 0
  Spr.HideRange 0, 50
  Bul.Reset
  If loopN = 2 Then spdMul = 5 Else spdMul = 4
  If stage >= 3 Then altPal = Spr.Pal * 10 Else altPal = 0
  stageT = 0
  StartMap
  Panel
  ShowScore : ShowStage : ShowLives : ShowBombs : ShowChain : gaugeWas = -1 : ShowGauge
  px = 128 : py = 200 : alive = 1 : inv = 100 : deadT = 0 : laserOn = 0 : burst = 0 : bombT = 0
  fireWas = 1 : bombWas = 1 : laserHit = -1
  waveT = 90 : cleared = 0 : clearT = 0 : sparkT = 0
  If loopN = 2 And stage = 1 Then
    Message "SECOND LOOP - STAGE 1", 180
  Else
    Message "STAGE " & Trim$(Str$(stage)), 150
  End If
  Do
    stageT = stageT + 1
    Waves
    PlayerMove
    LaserUpdate
    Enemies
    BossUpdate
    Items
    BombUpdate
    If alive Then Bul.Step px, py Else Bul.Step 0, 0
    If alive And inv = 0 And bombT = 0 Then
      If Bul.Hit() Then Die
    End If
    If chainT > 0 Then
      chainT = chainT - 1
      If chainT = 0 Then chain = 0 : ShowChain
    End If
    DrawPlayer
    If (frames And 3) = 0 Then
      If scoreDirty Then ShowScore
      ShowGauge
      If bossOn Then BossBar
    End If
    If msgT > 0 Then
      msgT = msgT - 1
      If msgT = 0 Then Tiles.Rect 4, 14, 24, 1, 0
    End If
    If Bg.Phase() = 0 Then MakeRow
    Frame
    Bg.Scroll
    Spr.Show
    Bul.Show
    Sfx.Update
    frames = frames + 1
    If alive = 0 And deadT = 0 And lives = 0 Then over = 1 : Exit Sub
    If cleared Then
      clearT = clearT + 1
      If clearT = 1 Then Message "STAGE CLEAR", 160
      If clearT > 170 Then Exit Sub
    End If
  Loop
End Sub

Sub AddScore(ByVal n As Long)
  score = score + n
  scoreDirty = 1
  If mode < 3 And score >= nextExtend Then
    lives = lives + 1 : ShowLives
    nextExtend = nextExtend + 1000000
    Sfx.Play 1, 60, -1, 15, 40, 0
  End If
End Sub

' ---------------------------------------------------------------- the ship
Sub PlayerMove()
  Dim j0 As Integer, my As Integer, sp As Integer, fire As Integer, bomb As Integer
  If alive = 0 Then
    If deadT > 0 Then
      deadT = deadT - 1
      If deadT = 0 And lives > 0 Then
        alive = 1 : px = 128 : py = YMAX : inv = 150 : bombs = 3 : ShowBombs
      End If
    End If
    Exit Sub
  End If
  j0 = Keys.Joystick(0)
  mx = 0 : my = 0
  If Keys.Down(Keys.KeyO) Or (j0 And Keys.JoyLeft) Then mx = -1
  If Keys.Down(Keys.KeyP) Or (j0 And Keys.JoyRight) Then mx = 1
  If Keys.Down(Keys.KeyQ) Or (j0 And Keys.JoyUp) Then my = -1
  If Keys.Down(Keys.KeyA) Or (j0 And Keys.JoyDown) Then my = 1
  If laserOn Then sp = 1 Else sp = 2
  px = px + mx * sp : py = py + my * sp
  If px < XMIN Then px = XMIN
  If px > XMAX Then px = XMAX
  If py < YMIN Then py = YMIN
  If py > YMAX Then py = YMAX
  ' tap: a burst of shots; hold: the laser
  fire = Keys.Down(Keys.KeySpace) Or ((j0 And Keys.JoyFire1) <> 0)
  If fire Then
    fireHeld = fireHeld + 1
    If fireWas = 0 Then burst = 14
    If fireHeld > 14 Then laserOn = 1
  Else
    fireHeld = 0 : laserOn = 0
  End If
  fireWas = fire
  If burst > 0 Then burst = burst - 1
  If shotCool > 0 Then shotCool = shotCool - 1
  If laserOn = 0 And burst > 0 And shotCool = 0 Then
    Bul.Shot px - 4, py - 10, 0
    Bul.Shot px + 4, py - 10, 0
    If power >= 2 Then
      Bul.Shot px - 8, py - 6, -1
      Bul.Shot px + 8, py - 6, 1
    End If
    If power >= 3 Then
      Bul.Shot px - 10, py - 2, -2
      Bul.Shot px + 10, py - 2, 2
    End If
    shotCool = 5
    Sfx.Play 0, 40, 6, 9, 3, 0
  End If
  If laserOn And (frames And 3) = 0 Then Sfx.Play 0, 18, 1, 8, 4, 1
  bomb = Keys.Down(Keys.KeyM) Or Keys.Down(Keys.KeyEnter) Or ((j0 And Keys.JoyFire2) <> 0)
  If bomb And bombWas = 0 And bombs > 0 And bombT = 0 Then
    bombs = bombs - 1 : ShowBombs
    bombT = 60
    Sfx.Play 2, 31, 0, 15, 60, 1
  End If
  bombWas = bomb
  If inv > 0 Then inv = inv - 1
End Sub

Sub DrawPlayer()
  Dim fr As Integer
  If alive = 0 Or (inv And 4) <> 0 Then
    Spr.Hide SP_PLAYER
  Else
    If mx < 0 Then
      fr = 1
    ElseIf mx > 0 Then
      fr = 2
    Else
      fr = 0
    End If
    Spr.Put SP_PLAYER, px - 8, py - 8, GfxData.S_PLAYER + fr, 0
  End If
  If sparkT > 0 Then sparkT = sparkT - 1
  If Bul.Sparked() Then
    sparkT = 3
    Spr.Put SP_SPARK, Bul.SparkX() - 8, Bul.SparkY() - 8, GfxData.S_SPARK, 0
  ElseIf sparkT = 0 Then
    Spr.Hide SP_SPARK
  End If
End Sub

' the laser: the nearest target above, the beam up to it
Sub LaserUpdate()
  Dim top As Integer, y As Integer
  laserHit = -1
  If laserOn = 0 Or alive = 0 Then
    Spr.HideRange SP_LASER, 11
    Exit Sub
  End If
  laserHit = Bul.Laser(px, py - 8)
  top = Bul.LaserTop()
  laserDmg = 1 + (power - 1) * (frames And 1)
  For k = 0 To 9
    y = top + k * 16
    If y < py - 20 Then
      Spr.Put SP_LASER + k, px - 8, y, GfxData.S_LASER, 0
    ElseIf k = 9 Or y >= py - 4 Then
      Spr.Hide SP_LASER + k
    Else
      Spr.Put SP_LASER + k, px - 8, py - 28, GfxData.S_LASER, 0
    End If
  Next
  If laserHit >= 0 Then
    If frames And 2 Then
      Spr.Put SP_FLARE, px - 8, top - 10, GfxData.S_LASER + 1, 0
    Else
      Spr.Put SP_FLARE, px - 8, top - 10, GfxData.S_LASER + 1, Spr.MirrorX
    End If
  Else
    Spr.Hide SP_FLARE
  End If
End Sub

Sub Die()
  Dim n As Integer
  alive = 0 : deadT = 100 : lives = lives - 1 : ShowLives
  laserOn = 0 : burst = 0
  n = Spawn(K_BIGBOOM, px, py)
  n = Bul.Clear()
  chain = 0 : chainT = 0 : ShowChain
  If power > 1 Then power = power - 1
  Spr.Hide SP_PLAYER
  Spr.HideRange SP_LASER, 11
  Sfx.Play 2, 31, 0, 15, 70, 1
  Sfx.Play 1, 200, 12, 15, 50, 0
End Sub

Sub BombUpdate()
  Dim n As Integer
  If bombT = 0 Then Exit Sub
  bombT = bombT - 1
  n = Bul.Clear()
  If bombT = 0 Then
    Bg.Theme stage - 1
  ElseIf (bombT And 4) <> 0 Then
    Bg.Theme 5
  Else
    Bg.Theme stage - 1
  End If
End Sub

' ---------------------------------------------------------------- the waves
Sub Waves()
  Dim r As Integer, n As Integer, x As Integer, m As Integer, gap As Integer
  If stageT >= STAGELEN Then
    If stageT = WARNAT Then
      Message "WARNING!  A BIG ONE", 140
      Sfx.Play 2, 300, 0, 15, 30, 0
    End If
    If stageT = WARNAT + 40 Or stageT = WARNAT + 80 Then Sfx.Play 2, 300, 0, 15, 30, 0
    If stageT = BOSSAT Then StartBoss
    Exit Sub
  End If
  If stageT = 600 Or stageT = 1500 Then n = Spawn(K_CARRIER, 64 + Rnd(128), 8)
  If stage >= 2 And stageT = 1100 Then n = Spawn(K_GUNSHIP, 128, 8)
  If stage >= 4 And stageT = 1800 Then n = Spawn(K_GUNSHIP, 80 + Rnd(96), 8)
  waveT = waveT - 1
  If waveT > 0 Then Exit Sub
  gap = 110 - stage * 10
  If loopN = 2 Then gap = gap - 15
  waveT = gap
  r = Rnd(100)
  If stage = 1 And r >= 70 And r < 85 Then r = r + 15     ' no darts in stage 1
  If r < 30 Then
    ' a line of small fighters
    x = 48 + Rnd(40)
    For m = 0 To 3 + stage \ 2
      n = Spawn(K_POP, x + m * 24, 16)
      If n >= 0 Then ea(n) = 0
    Next
  ElseIf r < 50 Then
    ' a column, weaving
    x = 64 + Rnd(128)
    For m = 0 To 4
      n = Spawn(K_POP, x, 16 - m * 18)
      If n >= 0 Then ea(n) = 1
    Next
  ElseIf r < 70 Then
    ' down one side, then across
    If Rnd(2) Then x = 52 Else x = 204
    For m = 0 To 3
      n = Spawn(K_POP, x, 16 - m * 20)
      If n >= 0 Then
        If x < 128 Then ea(n) = 2 Else ea(n) = 3
      End If
    Next
  ElseIf r < 85 Then
    ' two divers
    n = Spawn(K_DART, 56 + Rnd(30), 16)
    n = Spawn(K_DART, 170 + Rnd(30), 16)
  Else
    ' tanks up the path and on the ground
    n = Spawn(K_TANK, 40 + pc * 16, 16)
    n = Spawn(K_TANK, 40 + Rnd(12) * 16, 16)
  End If
End Sub

' a new enemy of kind kd at x, y (pixels): its number, or -1 when there's no room
Function Spawn(ByVal kd As Integer, ByVal x As Integer, ByVal y As Integer) As Integer
  Dim m As Integer
  For m = 0 To NE - 1
    If ek(m) = 0 Then
      ek(m) = kd : ex(m) = x * 16 + 8 : ey(m) = y * 16 + 8 : evx(m) = 0 : evy(m) = 0
      ehp(m) = khp(kd) : et(m) = 0 : ea(m) = 0 : ef(m) = 0
      If loopN = 2 Then ehp(m) = ehp(m) + ehp(m) \ 4
      efire(m) = -1
      If kd = K_POP Then
        evy(m) = 20
        If Rnd(5) < stage + loopN Then efire(m) = 30 + Rnd(50)
      ElseIf kd = K_DART Then
        evy(m) = 46 : evx(m) = (px - x) * 16 \ 44
      ElseIf kd = K_TANK Then
        evy(m) = 12 : efire(m) = 40 + Rnd(40)
      ElseIf kd = K_TURRET Then
        evy(m) = 16 : efire(m) = 30 + Rnd(40)
      ElseIf kd = K_CARRIER Then
        evy(m) = 9
      ElseIf kd = K_GUNSHIP Then
        evy(m) = 24
      End If
      Spawn = m
      Exit Function
    End If
  Next
  Spawn = -1
End Function

' ---------------------------------------------------------------- bullets
Sub Shoot(ByVal x As Integer, ByVal y As Integer, ByVal a As Integer, ByVal spd As Integer, ByVal pat As Integer, ByVal pal As Integer)
  If y < 36 Or y > 216 Then Exit Sub
  Bul.Fire x, y, a And 255, spd * spdMul \ 4, GfxData.S_BULLET + pat, pal
End Sub

' n bullets fanned round the way to the ship, step apart
Sub Fan(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer, ByVal stp As Integer, ByVal spd As Integer, ByVal pat As Integer, ByVal pal As Integer)
  Dim a As Integer, m As Integer
  If alive Then a = Bul.Aim(x, y, px, py) Else a = 0
  a = a - (n - 1) * stp \ 2
  For m = 1 To n
    Shoot x, y, a, spd, pat, pal
    a = a + stp
  Next
End Sub

' n bullets all round, starting at way a
Sub Ring(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer, ByVal a As Integer, ByVal spd As Integer, ByVal pat As Integer, ByVal pal As Integer)
  Dim m As Integer, st As Integer
  st = 256 \ n
  For m = 1 To n
    Shoot x, y, a, spd, pat, pal
    a = a + st
  Next
End Sub

' ---------------------------------------------------------------- the enemies
Sub Enemies()
  Dim m As Integer, kd As Integer, x As Integer, y As Integer, h As Integer, fl As Integer, pat As Integer, half As Integer, gone As Integer
  For m = 0 To NE - 1
    kd = ek(m)
    If kd >= K_BOOM Then
      et(m) = et(m) + 1
      ey(m) = ey(m) + evy(m)
      If et(m) >= 16 Then
        ek(m) = 0 : Spr.Hide SP_EN + m
      ElseIf kd = K_BIGBOOM Then
        Spr.Put SP_EN + m, ex(m) \ 16 - 16, ey(m) \ 16 - 16, GfxData.S_BOOM + et(m) \ 4, Spr.Scale2
      Else
        Spr.Put SP_EN + m, ex(m) \ 16 - 8, ey(m) \ 16 - 8, GfxData.S_BOOM + et(m) \ 4, 0
      End If
    ElseIf kd > 0 Then
      Move m, kd
      x = ex(m) \ 16 : y = ey(m) \ 16
      gone = 0
      If y > 240 Or x < 12 Or x > 244 Then gone = 1
      If y < 0 And et(m) > 40 Then gone = 1
      If gone Then
        ek(m) = 0 : Spr.Hide SP_EN + m : Bul.Off m
      Else
        h = Bul.Hits(m)
        If laserHit = m Then h = h + laserDmg
        If bombT > 0 And y >= 32 Then h = h + 2
        If h > 0 And y >= 30 Then
          ehp(m) = ehp(m) - h : ef(m) = 2 : chainT = 90
        End If
        If ehp(m) <= 0 Then
          Kill m, kd, x, y
        Else
          If y >= 20 Then Bul.Box m, x, y, kbox(kd), kbox(kd) Else Bul.Off m
          fl = altPal
          If ef(m) > 0 Then ef(m) = ef(m) - 1 : fl = Spr.Pal
          pat = kpat(kd)
          If kd = K_POP Then pat = pat + ((frames \ 4) And 1)
          If kbig(kd) Then
            Spr.Put SP_EN + m, x - 16, y - 16, pat, fl Or Spr.Scale2
            half = 13
          Else
            Spr.Put SP_EN + m, x - 8, y - 8, pat, fl
            half = 6
          End If
          ' flying into the ship
          If kair(kd) And alive And inv = 0 And bombT = 0 Then
            If Abs(x - px) < half And Abs(y - py) < half Then Die
          End If
        End If
      End If
    End If
  Next
End Sub

' how each kind moves and shoots
Sub Move(ByVal m As Integer, ByVal kd As Integer)
  Dim x As Integer, y As Integer, t As Integer
  t = et(m)
  x = ex(m) \ 16 : y = ey(m) \ 16
  If kd = K_POP Then
    If ea(m) = 1 Then
      If (t \ 24) And 1 Then evx(m) = 14 Else evx(m) = -14
    ElseIf ea(m) >= 2 And y > 96 And evy(m) > 8 Then
      evy(m) = 8
      If ea(m) = 2 Then evx(m) = 30 Else evx(m) = -30
    End If
    If t = efire(m) Then
      If loopN = 2 Then Fan x, y, 3, 14, 22, 0, PINK Else Fan x, y, 1, 0, 22, 0, PINK
    End If
  ElseIf kd = K_DART Then
    evy(m) = evy(m) - 1
    If evy(m) = 0 Then Fan x, y, 3 + loopN - 1, 12, 26, 2, GOLD
  ElseIf kd = K_TANK Then
    If t = efire(m) Then
      Fan x, y, loopN, 10, 22, 0, BLUE
      efire(m) = t + 90 - stage * 6
    End If
  ElseIf kd = K_TURRET Then
    If t = efire(m) Then
      Ring x, y, 6 + stage + loopN * 2, t And 31, 18, 0, PINK
      efire(m) = t + 120 - stage * 8
    End If
  ElseIf kd = K_CARRIER Then
    If loopN = 2 And (t And 63) = 63 Then Fan x, y, 2, 20, 24, 1, BLUE
  ElseIf kd = K_GUNSHIP Then
    If ea(m) = 0 Then
      If y >= 76 Then ea(m) = 1 : evy(m) = 0 : et(m) = 0 : t = 0
    ElseIf ea(m) = 1 Then
      If (t Mod (8 - stage \ 2)) = 0 Then
        Shoot x, y + 8, t * 5, 20, 0, PINK
        Shoot x, y + 8, t * 5 + 128, 20, 0, PINK
      End If
      If (t Mod 50) = 25 Then Fan x, y + 8, 5, 10, 28, 1, BLUE
      If t > 420 Then ea(m) = 2 : evy(m) = -14
    End If
  End If
  ex(m) = ex(m) + evx(m) : ey(m) = ey(m) + evy(m)
  et(m) = et(m) + 1
End Sub

Sub Kill(ByVal m As Integer, ByVal kd As Integer, ByVal x As Integer, ByVal y As Integer)
  chain = chain + 1 : chainT = 90
  If chain > maxChain Then maxChain = chain
  ShowChain
  AddScore kscore(kd) + chain * 20
  Bul.Off m
  If kd = K_CARRIER Then
    If power < 3 Then Drop 1, x, y Else Drop 2, x, y
  End If
  If kd = K_GUNSHIP Then Drop 3, x, y
  ' the second loop: they shoot back as they die
  If loopN = 2 And kair(kd) And alive Then Fan x, y, 1, 0, 26, 2, GOLD
  ek(m) = K_BOOM + kbig(kd) : et(m) = 0 : evx(m) = 0 : ex(m) = x * 16 : ey(m) = y * 16
  If kair(kd) Then evy(m) = 6 Else evy(m) = 16
  If kbig(kd) Then Sfx.Play 1, 31, 0, 15, 30, 1 Else Sfx.Play 1, 20, 1, 13, 12, 1
End Sub

' ---------------------------------------------------------------- items
Sub Drop(ByVal kind As Integer, ByVal x As Integer, ByVal y As Integer)
  Dim n As Integer
  For n = 0 To NI - 1
    If ik(n) = 0 Then
      ik(n) = kind : ix(n) = x : iy(n) = y
      Exit Sub
    End If
  Next
End Sub

Sub Items()
  Dim n As Integer
  For n = 0 To NI - 1
    If ik(n) Then
      If (frames And 1) = 0 Then iy(n) = iy(n) + 1
      If iy(n) > 232 Then
        ik(n) = 0 : Spr.Hide SP_ITEM + n
      ElseIf alive And Abs(ix(n) - px) < 14 And Abs(iy(n) - py) < 14 Then
        If ik(n) = 1 Then
          If power < 3 Then power = power + 1 Else AddScore 5000
        ElseIf ik(n) = 2 Then
          If bombs < 6 Then bombs = bombs + 1 : ShowBombs
        Else
          AddScore 10000 * loopN
        End If
        ik(n) = 0 : Spr.Hide SP_ITEM + n
        Sfx.Play 1, 120, -8, 14, 14, 0
      Else
        Spr.Put SP_ITEM + n, ix(n) - 8, iy(n) - 8, GfxData.S_ITEM + ik(n) - 1, 0
      End If
    End If
  Next
End Sub

' ---------------------------------------------------------------- the boss
Sub StartBoss()
  Dim s As String
  bossOn = 1 : bossX = 128 : bossY = 8 : bossPh = 0 : bossDie = 0 : bossVX = 1 : bossFl = 0
  bossMax = 400 + stage * 200
  If loopN = 2 Then bossMax = bossMax + bossMax \ 2
  bossHP = bossMax
  ' the guns: type (1 ring, 2 aimed fan, 3 spiral, 4 spray, 5 wall), interval, count, speed,
  ' spin, bullet (0 small, 1 big, 2 star), colour - two guns a phase, three phases
  If stage = 1 Then
    s = "2 50 5 22 10 0 2 1 90 12 18 5 1 3 3 5 2 24 9 0 2 2 70 3 30 8 2 4 1 26 16 20 8 0 2 3 7 3 20 -7 1 3"
  ElseIf stage = 2 Then
    s = "3 6 2 22 7 0 2 2 60 7 24 8 1 3 5 44 9 24 0 1 4 2 32 3 32 6 0 2 3 4 3 24 11 0 2 1 50 20 18 4 1 3"
  ElseIf stage = 3 Then
    s = "1 22 10 22 6 0 3 2 45 5 28 9 2 4 3 4 4 22 5 0 2 5 50 11 24 0 1 3 3 5 3 26 -9 0 2 3 5 3 26 9 0 3"
  ElseIf stage = 4 Then
    s = "2 9 1 40 0 2 4 1 60 24 16 5 0 3 1 18 18 22 7 0 2 2 40 7 30 6 1 4 3 3 4 24 7 0 2 2 26 5 34 8 2 4"
  Else
    s = "3 4 3 24 9 0 2 1 40 20 20 6 1 3 3 3 4 22 -6 0 3 2 22 5 32 8 2 4 3 3 5 24 7 0 2 1 20 24 22 5 1 3"
  End If
  Numbers s
  Spr.HideRange SP_BOSS, 12
End Sub

' the boss's numbers from a text of numbers apart by spaces
Sub Numbers(ByVal s As String)
  Dim p As Integer, q As Integer, n As Integer
  longText = s & " "
  p = 1 : n = 0
  Do While p <= Len(longText) And n < 42
    q = InStr(p, longText, " ")
    If q = 0 Then Exit Do
    em(n) = Val(Mid$(longText, p, q - p))
    n = n + 1
    p = q + 1
  Loop
End Sub

Sub BossUpdate()
  Dim h As Integer, ph As Integer, e As Integer, b As Integer, fl As Integer, cx As Integer, cy As Integer, n As Integer
  If bossOn = 0 Then Exit Sub
  If bossDie > 0 Then
    bossDie = bossDie - 1
    If (bossDie And 7) = 0 Then
      n = Spawn(K_BIGBOOM, bossX - 28 + Rnd(56), bossY - 20 + Rnd(40))
      Sfx.Play 1, 31, 0, 15, 20, 1
    End If
    If bossDie = 40 Then
      Spr.HideRange SP_BOSS, 12
      For n = 0 To 5
        e = Spawn(K_BIGBOOM, bossX - 24 + Rnd(48), bossY - 16 + Rnd(32))
      Next
      Sfx.Play 2, 31, 0, 15, 60, 1
    End If
    If bossDie > 40 Then DrawBoss Spr.Pal * (bossDie And 1)
    If bossDie = 0 Then bossOn = 0 : cleared = 1 : Tiles.Rect 4, 4, 24, 1, 0
    Exit Sub
  End If
  If bossPh = 0 Then
    bossY = bossY + 1
    If bossY >= 84 Then bossPh = 1 : Phase
  Else
    If frames And 1 Then
      bossX = bossX + bossVX
      If bossX < 88 Or bossX > 168 Then bossVX = -bossVX
    End If
    h = Bul.Hits(BOXBOSS)
    If laserHit = BOXBOSS Then h = h + laserDmg
    If bombT > 0 Then h = h + 1
    If h > 0 Then bossHP = bossHP - h : bossFl = 1 : chainT = 90
    If bossHP <= 0 Then
      BossDown
      Exit Sub
    End If
    If bossHP * 3 > bossMax * 2 Then
      ph = 1
    ElseIf bossHP * 3 > bossMax Then
      ph = 2
    Else
      ph = 3
    End If
    If ph <> bossPh Then bossPh = ph : Phase
    For e = 0 To 1
      emT(e) = emT(e) - 1
      If emT(e) <= 0 Then Gun e
    Next
  End If
  If bossY >= 40 Then Bul.Box BOXBOSS, bossX, bossY, 32, 24 Else Bul.Off BOXBOSS
  fl = Spr.Pal * (4 + stage)
  If bossFl And (frames And 7) = 0 Then fl = Spr.Pal
  bossFl = 0
  DrawBoss fl
  If alive And inv = 0 And bombT = 0 Then
    If Abs(px - bossX) < 26 And Abs(py - bossY) < 18 Then Die
  End If
End Sub

' the boss's 12 sprites (4 x 3)
Sub DrawBoss(ByVal fl As Integer)
  Dim cx As Integer, cy As Integer, b As Integer, y As Integer
  b = GfxData.S_BOSS1 + (stage - 1) * 12
  For cy = 0 To 2
    y = bossY - 24 + cy * 16
    For cx = 0 To 3
      If y < 0 Then
        Spr.Hide SP_BOSS + cy * 4 + cx
      Else
        Spr.Put SP_BOSS + cy * 4 + cx, bossX - 32 + cx * 16, y, b + cy * 4 + cx, fl
      End If
    Next
  Next
End Sub

' a new phase: its guns' timers
Sub Phase()
  emT(0) = 30 : emT(1) = 50 : emAng(0) = 0 : emAng(1) = 64
End Sub

' gun e of this phase fires
Sub Gun(ByVal e As Integer)
  Dim o As Integer, typ As Integer, cnt As Integer, spd As Integer, spin As Integer, pat As Integer, pal As Integer, m As Integer, x As Integer, y As Integer
  o = (bossPh - 1) * 14 + e * 7
  typ = em(o) : cnt = em(o + 2) : spd = em(o + 3) : spin = em(o + 4) : pat = em(o + 5) : pal = em(o + 6)
  emT(e) = em(o + 1)
  If loopN = 2 Then emT(e) = emT(e) * 3 \ 4
  If emT(e) < 2 Then emT(e) = 2
  x = bossX : y = bossY + 16
  If typ = 1 Then
    Ring x, y, cnt, emAng(e), spd, pat, pal
    emAng(e) = emAng(e) + spin
  ElseIf typ = 2 Then
    Fan x, y, cnt, spin, spd, pat, pal
  ElseIf typ = 3 Then
    Ring x, y, cnt, emAng(e), spd, pat, pal
    emAng(e) = emAng(e) + spin
  ElseIf typ = 4 Then
    For m = 1 To cnt
      Shoot x, y, 192 + Rnd(128), spd, pat, pal
    Next
  Else
    For m = 0 To cnt - 1
      Shoot bossX - 48 + m * 96 \ (cnt - 1), y, 0, spd, pat, pal
    Next
  End If
End Sub

Sub BossDown()
  Dim n As Integer, bonus As Long
  bossDie = 150
  Bul.Off BOXBOSS
  n = Bul.Clear()
  bonus = 50000
  bonus = bonus * stage * loopN + n * 100
  AddScore bonus
  chain = chain + 1 : chainT = 90
  If chain > maxChain Then maxChain = chain
  ShowChain
  bonus = chain
  AddScore bonus * 500
  Message "BOSS DOWN!", 120
End Sub

' its life across the top of the play area
Sub BossBar()
  Dim v As Integer, f As Integer
  If bossPh = 0 Or bossDie > 0 Then Exit Sub
  v = bossHP * 11 \ (bossMax \ 16)
  If v = bossBarV Then Exit Sub
  bossBarV = v
  For k = 0 To 21
    f = v - k * 8
    If f < 0 Then f = 0
    If f > 8 Then f = 8
    Tiles.Put 5 + k, 4, GfxData.T_GAUGE + f
  Next
End Sub
