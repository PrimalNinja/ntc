' ESCORT - for the ZX Spectrum Next, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' A red convertible, an open road, and a fare who needs getting somewhere - fast. She waits by
' the road; pull up next to her, and she's in. Her stop is always straight ahead, but the road
' forks now and then (the signs say which way), there's traffic, oil, logs - and black cars
' that want her, and want you off the road. Your car has a few surprises of its own:
'   machine guns (forward), missiles (they find the black cars), an oil slick (behind you) and
'   a smoke screen (behind you: they lose you).
' Get her there, stop by the chequered flag, collect the fare. The clock is always running: each
' pick-up and each drop-off buys more time. Run out of time, or wreck the car, and it's over.
'
' Keys: O P (or Z C, 5 8, joystick): steer. Q (or S, 7, joystick up): accelerate.
'       A (or X, 6, joystick down): brake. Space (M, 0, fire): guns. N (fire 2): missile.
'       B: oil. V: smoke.
'
' The road and the sky are Layer 2, bent and striped line by line by the copper (Road.cls);
' everything by the road, on it and in it are sprites, drawn at 7 sizes (3 drawings x 1, 2, 4);
' the HUD is the tilemap; the engine and the rest are the AY.
Option Explicit
Option Turbo

Const NO = 22                            ' things by and on the road
Const HORN = 84                          ' the horizon on the flat
Const VMAX = 107                         ' 300 km/h (speeds in 64ths of a metre a frame)
Const CARD = 128                         ' your car is 8 metres ahead of the eye (16ths)
Const ROADW = 80, KERB = 92              ' the road's half width; to the kerbs' edge
Const SP_OBJ = 4, SP_CAR = 30, SP_PUFF = 32
' kinds
Const K_PALM = 1, K_BUSH = 2, K_PINE = 3, K_SIGNL = 4, K_SIGNR = 5, K_GORE = 6, K_CAR = 7, K_TRUCK = 8
Const K_OIL = 9, K_LOG = 10, K_DEST = 11, K_PUFF = 12, K_MISSILE = 13, K_GIRL = 14, K_ENEMY = 15
Const K_SHOT = 16, K_BOOM = 17, K_MYOIL = 18

Dim longText As String Max 80
' the things: kind, where (metres along the road + 64ths), across (1/128 of 6 m), speed, life,
' a timer, palette, how far from the eye this frame (16ths)
Dim okind(21) As Integer, oz(21) As Integer, ozf(21) As Integer, ox(21) As Integer, ov(21) As Integer
Dim ohp(21) As Integer, ot(21) As Integer, opal(21) As Integer, od(21) As Integer, ord(21) As Integer
Dim far(21) As Integer               ' how far, for sorting (gone: -30000, last)
' per kind: first pattern, the size the full drawing stands for, half its width, what hitting it does
' (0 nothing, 1 a crash, 2 a car, 3 oil, 4 a log, 5 a bush)
Dim kpat(18) As Integer, kfull(18) As Integer, khalf(18) As Integer, ksolid(18) As Integer
' planned things: where, kind, across (spawned when they come into view)
Dim pz(11) As Integer, pk(11) As Integer, px(11) As Integer
' you
Dim posM As Integer, posF As Integer, v As Integer, carx As Integer, camx As Integer, steer As Integer
Dim spinT As Integer, crashT As Integer, dmg As Integer, cool As Integer, smokeT As Integer
Dim nMis As Integer, nOil As Integer, nSmoke As Integer, misWas As Integer, oilWas As Integer, smkWas As Integer
' the road
Dim hor As Integer, curv As Integer, curT As Integer, hill As Integer, hillT As Integer, segEnd As Integer
Dim skyx As Integer, skyF As Integer
' the job
Dim mission As Integer, destZ As Integer, forkZ As Integer, forkSide As Integer, forkDone As Integer, forkWarn As Integer
Dim nextGirl As Integer, girlN As Integer, rideDmg As Integer, rideT As Integer, delivered As Integer
Dim nextScn As Integer, nextCar As Integer, nextHaz As Integer, enemyT As Integer
Dim money As Long, best As Long, timeLeft As Integer, over As Integer, why As Integer
Dim frames As Integer, msgT As Integer, hudT As Integer, demo As Integer
Dim i As Integer, k As Integer, n As Integer

Setup
Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Road.Init
Nx.Layers Nx.OrderSUL                    ' sprites over the HUD, the HUD over the road
Nx.Reg &H1C, 2                           ' the sprites cut to the paper under the HUD
Nx.Reg &H19, 16 : Nx.Reg &H19, 143 : Nx.Reg &H19, 48 : Nx.Reg &H19, 223
Nx.Reg &H15, Nx.RegGet(&H15) Or &H20
best = 500
Do
  Title
  Game
Loop

' ---------------------------------------------------------------- tables
Sub Setup()
  Kind K_PALM, GfxData.S_PALM, 170, 10, 1
  Kind K_BUSH, GfxData.S_BUSH, 70, 30, 5
  Kind K_PINE, GfxData.S_PINE, 140, 10, 1
  Kind K_SIGNL, GfxData.S_SIGNL, 100, 10, 1
  Kind K_SIGNR, GfxData.S_SIGNR, 100, 10, 1
  Kind K_GORE, GfxData.S_GORE, 100, 30, 1
  Kind K_CAR, GfxData.S_CAR, 48, 24, 2
  Kind K_TRUCK, GfxData.S_TRUCK, 64, 32, 2
  Kind K_OIL, GfxData.S_OIL, 64, 30, 3
  Kind K_LOG, GfxData.S_LOG, 64, 32, 4
  Kind K_DEST, GfxData.S_DEST, 210, 0, 0
  Kind K_PUFF, GfxData.S_PUFF, 64, 0, 0
  Kind K_MISSILE, GfxData.S_MISSILE, 24, 0, 0
  Kind K_GIRL, GfxData.S_GIRL, 70, 0, 0
  Kind K_ENEMY, GfxData.S_CAR, 48, 24, 2
  Kind K_SHOT, GfxData.S_SHOT, 32, 0, 0
  Kind K_BOOM, GfxData.S_BOOM, 80, 0, 0
  Kind K_MYOIL, GfxData.S_OIL, 64, 0, 0
End Sub

Sub Kind(ByVal kd As Integer, ByVal pat As Integer, ByVal full As Integer, ByVal half As Integer, ByVal solid As Integer)
  kpat(kd) = pat : kfull(kd) = full : khalf(kd) = half : ksolid(kd) = solid
End Sub

' ---------------------------------------------------------------- the screen
Sub Hud()
  Tiles.Fill 0
  Tiles.Rect 4, 4, 32, 2, GfxData.T_HUD
  ShowTop
  ShowJob
  ShowKit
End Sub

Sub ShowTop()
  Dim f As Integer
  longText = "TIME " & Right$(" " & Trim$(Str$((timeLeft + 49) \ 50)), 2) & "  $" & Right$("0000" & Trim$(Str$(money)), 5)
  longText = longText & " " & Right$("  " & Trim$(Str$(v * 45 \ 16)), 3) & "KMH"
  Tiles.Text 4, 4, longText
  Tiles.Text 27, 4, "DMG"
  For k = 0 To 4
    f = dmg * 40 \ 100 - k * 8
    If f < 0 Then f = 0
    If f > 8 Then f = 8
    Tiles.Put 31 + k, 4, GfxData.T_DMG + f
  Next
End Sub

Sub ShowJob()
  If mission = 0 Then
    longText = "PICK HER UP     "
    If (frames And 32) = 0 Then longText = "                "
  Else
    longText = "DROP OFF " & Right$("    " & Trim$(Str$(destZ - posM)), 5) & "M "
  End If
  Tiles.Text 4, 5, longText
End Sub

Sub ShowKit()
  Tiles.Text 22, 5, "MSL" & Trim$(Str$(nMis)) & " OIL" & Trim$(Str$(nOil)) & " SMK" & Trim$(Str$(nSmoke))
End Sub

' a message across the middle for t frames (0: until the next)
Sub Message(ByVal m As String, ByVal y As Integer, ByVal t As Integer)
  longText = m
  Tiles.Rect 4, y, 32, 1, 0
  Tiles.Text 4 + (32 - Len(longText)) \ 2, y, longText
  If t Then msgT = t
End Sub

Sub ClearMessages()
  Tiles.Rect 4, 7, 32, 22, 0
End Sub

' ---------------------------------------------------------------- the title
Sub Title()
  Dim y As Integer
  Spr.HideRange 0, 40 : Spr.Show
  NewRun
  demo = 1
  Hud
  Tiles.Rect 4, 4, 32, 2, GfxData.T_HUD
  Tiles.Text 4, 4, "BEST $" & Trim$(Str$(best))
  Message "E  S  C  O  R  T", 8, 0
  Message "PICK HER UP. GET HER THERE.", 10, 0
  Message "STEER O P  GAS Q  BRAKE A", 12, 0
  Message "SPACE GUNS  N MISSILE", 13, 0
  Message "B OIL  V SMOKE", 14, 0
  Message "(C) 2026 CYBORG UNICORN", 26, 0
  y = 0
  Do
    DemoDrive
    Drive
    Frame
    Road.Show
    Spr.Show
    Road.ShowObj
    Sfx.Update
    frames = frames + 1
    y = y + 1
    If y = 30 Then Message "PRESS SPACE", 23, 0
    If y = 60 Then Tiles.Rect 4, 23, 32, 1, 0 : y = 0
  Loop Until FireDown()
  Do
    Frame
  Loop While FireDown()
  demo = 0
  ClearMessages
  Sfx.Play 0, 200, -6, 15, 25, 0
End Sub

' the title's car drives itself: down the middle at a steady speed
Sub DemoDrive()
  steer = 0
  If carx < -8 Then steer = 1
  If carx > 8 Then steer = -1
  If v < 70 Then v = v + 1
End Sub

Function FireDown() As Integer
  FireDown = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyM) Or Keys.Down(Keys.Key0) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
End Function

' ---------------------------------------------------------------- a run
Sub NewRun()
  For n = 0 To NO - 1
    okind(n) = 0 : ord(n) = n : far(n) = -30000
  Next
  For n = 0 To 11
    pk(n) = 0
  Next
  posM = 100 : posF = 0 : v = 0 : carx = 0 : camx = 0 : spinT = 0 : crashT = 0 : dmg = 0 : smokeT = 0
  hor = HORN : curv = 0 : curT = 0 : hill = 0 : hillT = 0 : segEnd = 300 : skyx = 0 : skyF = 0
  mission = 0 : nextGirl = 400 : girlN = -1 : forkZ = 0 : delivered = 0
  nextScn = 100 : nextCar = 500 : nextHaz = 900 : enemyT = 300
  money = 0 : timeLeft = 3000 : over = 0
  nMis = 3 : nOil = 3 : nSmoke = 3
  ' the roadside to start with
  Do While nextScn < posM + 320
    AddScenery
  Loop
End Sub

Sub Game()
  Dim y As Integer
  NewRun
  Spr.HideRange 0, 40
  Hud
  Message "SHE'S WAITING UP THE ROAD", 10, 150
  misWas = 1 : oilWas = 1 : smkWas = 1
  Do
    Controls
    Drive
    If (frames And 7) = 0 Then ShowTop
    If (frames And 15) = 8 Then ShowJob
    If msgT > 0 Then
      msgT = msgT - 1
      If msgT = 0 Then ClearMessages
    End If
    Frame
    Road.Show
    Spr.Show
    Road.ShowObj
    Sfx.Update
    frames = frames + 1
    If timeLeft > 4950 Then timeLeft = 4950
    If timeLeft > 0 Then timeLeft = timeLeft - 1
    If timeLeft = 0 Then over = 1 : why = 0
    If dmg >= 100 Then over = 1 : why = 1
  Loop Until over
  ' the end: the car rolls to a stop
  ShowTop
  If why = 0 Then Message "OUT OF TIME", 12, 0 Else Message "WRECKED", 12, 0
  Message "YOU MADE $" & Trim$(Str$(money)), 14, 0
  If money > best Then best = money : Message "THE BEST YET", 16, 0
  For y = 1 To 250
    steer = 0
    If v > 0 Then v = v - 1
    Drive
    Frame
    Road.Show
    Spr.Show
    Road.ShowObj
    Sfx.Update
    frames = frames + 1
    If y > 60 And FireDown() Then Exit For
  Next
  Do
    Frame
  Loop While FireDown()
  ClearMessages
End Sub

' ---------------------------------------------------------------- you
Sub Controls()
  Dim j0 As Integer, mx As Integer, my As Integer, b As Integer
  j0 = Keys.Joystick(0)
  mx = 0 : my = 0
  If Keys.Down(Keys.KeyO) Or Keys.Down(Keys.KeyZ) Or Keys.Down(Keys.Key5) Or (j0 And Keys.JoyLeft) Then mx = -1
  If Keys.Down(Keys.KeyP) Or Keys.Down(Keys.KeyC) Or Keys.Down(Keys.Key8) Or (j0 And Keys.JoyRight) Then mx = 1
  If Keys.Down(Keys.KeyQ) Or Keys.Down(Keys.KeyS) Or Keys.Down(Keys.Key7) Or (j0 And Keys.JoyUp) Then my = -1
  If Keys.Down(Keys.KeyA) Or Keys.Down(Keys.KeyX) Or Keys.Down(Keys.Key6) Or (j0 And Keys.JoyDown) Then my = 1
  steer = mx
  If crashT > 0 Then steer = 0 : my = 0
  ' the pedals
  If my < 0 Then
    If v < VMAX And (frames And 1) = 0 Then v = v + 1
    If v < 30 Then v = v + 1               ' off the line quicker
  ElseIf my > 0 Then
    v = v - 3
  ElseIf (frames And 7) = 0 Then
    v = v - 1
  End If
  If v < 0 Then v = 0
  ' the guns: two tracers up the road
  If cool > 0 Then cool = cool - 1
  If FireDown() And cool = 0 And crashT = 0 Then
    n = NewObj(K_SHOT, posM + 9, carx - 18)
    If n >= 0 Then ov(n) = v + 180 : ot(n) = 22
    n = NewObj(K_SHOT, posM + 9, carx + 18)
    If n >= 0 Then ov(n) = v + 180 : ot(n) = 22
    cool = 7
    Sfx.Play 1, 20, 3, 10, 3, 1
  End If
  ' a missile
  b = Keys.Down(Keys.KeyN) Or ((j0 And Keys.JoyFire2) <> 0)
  If b And misWas = 0 And crashT = 0 Then
    If nMis > 0 Then
      n = NewObj(K_MISSILE, posM + 9, carx)
      If n >= 0 Then ov(n) = v + 120 : ot(n) = 100 : nMis = nMis - 1 : ShowKit : Sfx.Play 2, 60, 4, 13, 30, 1
    Else
      Sfx.Play 1, 400, 0, 8, 6, 0
    End If
  End If
  misWas = b
  ' an oil slick, left behind you
  b = Keys.Down(Keys.KeyB)
  If b And oilWas = 0 Then
    If nOil > 0 Then
      n = NewObj(K_MYOIL, posM + 5, carx)
      If n >= 0 Then nOil = nOil - 1 : ShowKit : Sfx.Play 2, 200, 10, 12, 15, 1
    Else
      Sfx.Play 1, 400, 0, 8, 6, 0
    End If
  End If
  oilWas = b
  ' the smoke screen
  b = Keys.Down(Keys.KeyV)
  If b And smkWas = 0 Then
    If nSmoke > 0 And smokeT = 0 Then
      smokeT = 150 : nSmoke = nSmoke - 1 : ShowKit : Sfx.Play 2, 31, 0, 12, 40, 1
    Else
      Sfx.Play 1, 400, 0, 8, 6, 0
    End If
  End If
  smkWas = b
End Sub

' a frame of driving: the car, the road, the things on it, the job
Sub Drive()
  Dim off As Integer, zpos As Integer
  ' along the road
  posF = posF + v
  Do While posF >= 64
    posF = posF - 64 : posM = posM + 1
    Metre
  Loop
  ' across: steering, the bends pushing you out, oil spinning you
  If spinT > 0 Then
    spinT = spinT - 1
    steer = 1 - 2 * ((spinT \ 6) And 1)
  End If
  If crashT > 0 Then
    crashT = crashT - 1
    If carx > ROADW - 20 Then carx = carx - 4
    If carx < 20 - ROADW Then carx = carx + 4
  End If
  carx = carx + steer * (2 + v \ 14)
  carx = carx - curv * v \ 3000
  If carx > 220 Then carx = 220
  If carx < -220 Then carx = -220
  off = (carx > KERB Or carx < -KERB)
  If off And v > 40 Then v = v - 2         ' on the grass
  ' the eye follows you a third of the way across
  camx = carx \ 3
  ' the sky turns with the bends
  skyF = skyF + curv * v \ 64
  skyx = (skyx + skyF \ 96) And 255
  skyF = skyF Mod 96
  zpos = ((posM And 1023) * 16 + posF \ 4) And 16383
  Road.Build hor, curv, camx, zpos, skyx
  ' the engine
  If (frames And 3) = 0 Then Sfx.Play 0, 380 - v * 3, 0, 7 + v \ 30, 6, 0
  Things
  DrawCar off
  If demo = 0 Then Job
  If smokeT > 0 Then smokeT = smokeT - 1
End Sub

' each metre: the road changes (bends, hills), things are put ahead
Sub Metre()
  ' bends and hills, a little each metre
  If curv < curT Then curv = curv + 1
  If curv > curT Then curv = curv - 1
  If (posM And 3) = 0 Then
    If hill < hillT Then hill = hill + 1
    If hill > hillT Then hill = hill - 1
    hor = HORN - hill
  End If
  If posM >= segEnd Then NewSegment
  If posM + 320 >= nextScn Then AddScenery
  If posM + 450 >= nextCar Then Traffic
  If posM + 450 >= nextHaz Then Hazard
  For i = 0 To 11
    If pk(i) Then
      If posM + 450 >= pz(i) Then
        n = NewObj(pk(i), pz(i), px(i))
        pk(i) = 0
      End If
    End If
  Next
  ' the black cars come when she's with you
  If mission = 1 And demo = 0 Then
    If enemyT > 0 Then enemyT = enemyT - 1
    If enemyT = 0 Then NewEnemy
  End If
End Sub

Sub NewSegment()
  Dim r As Integer
  segEnd = posM + 150 + Rnd(300)
  r = Rnd(10)
  If r < 3 Then
    curT = 0
  ElseIf r < 6 Then
    curT = 40 + Rnd(30)
  Else
    curT = 70 + Rnd(50)
  End If
  If Rnd(2) Then curT = -curT
  r = Rnd(6)
  hillT = 0
  If r = 1 Then hillT = 10
  If r = 2 Then hillT = -8
  If r = 3 Then hillT = 6
End Sub

Sub AddScenery()
  Dim r As Integer, kd As Integer, side As Integer
  r = Rnd(10)
  kd = K_PALM
  If r > 5 Then kd = K_BUSH
  If r = 9 Then kd = K_PINE
  side = 1 - 2 * Rnd(2)
  n = NewObj(kd, nextScn, side * (115 + Rnd(130)))
  If Rnd(2) = 0 Then n = NewObj(K_PALM, nextScn + 5, -side * (120 + Rnd(100)))
  nextScn = nextScn + 18 + Rnd(16)
End Sub

Sub Traffic()
  Dim kd As Integer
  kd = K_CAR
  If Rnd(4) = 0 Then kd = K_TRUCK
  n = NewObj(kd, nextCar, 40 - 80 * Rnd(2))
  If n >= 0 Then
    ov(n) = 35 + Rnd(30)
    If kd = K_CAR Then opal(n) = 1 + Rnd(3)
  End If
  nextCar = nextCar + 250 + Rnd(250)
End Sub

Sub Hazard()
  Dim kd As Integer
  kd = K_OIL
  If Rnd(3) = 0 Then kd = K_LOG
  n = NewObj(kd, nextHaz, (Rnd(3) - 1) * 44)
  nextHaz = nextHaz + 450 + Rnd(400) - delivered * 30
  If nextHaz < posM + 700 Then nextHaz = posM + 700
End Sub

Sub NewEnemy()
  Dim c As Integer, m As Integer
  c = 0
  For m = 0 To NO - 1
    If okind(m) = K_ENEMY Then c = c + 1
  Next
  enemyT = 200 + Rnd(300) - delivered * 15
  If enemyT < 120 Then enemyT = 120
  If c > delivered \ 2 Or c >= 3 Then Exit Sub
  n = NewObj(K_ENEMY, posM - 30, (Rnd(3) - 1) * 44)
  If n >= 0 Then
    ov(n) = v + 20 : ohp(n) = 4 : opal(n) = 4 : ot(n) = 0
    Message "THEY'RE BEHIND YOU!", 10, 80
    Sfx.Play 2, 300, -8, 13, 40, 0
  End If
End Sub

' a free thing of a kind, at z (metres) and x; -1 if there's no room
Function NewObj(ByVal kd As Integer, ByVal z As Integer, ByVal x As Integer) As Integer
  Dim m As Integer
  NewObj = -1
  For m = 0 To NO - 1
    If okind(m) = 0 Then
      okind(m) = kd : oz(m) = z : ozf(m) = 0 : ox(m) = x : ov(m) = 0 : ohp(m) = 1 : ot(m) = 0 : opal(m) = 0
      od(m) = (z - posM) * 16
      NewObj = m
      Exit Function
    End If
  Next
End Function

' ---------------------------------------------------------------- the things
Sub Things()
  Dim q As Integer, d As Integer, kd As Integer, rel As Integer, dx As Integer, pf As Integer
  pf = posF \ 4
  For q = 0 To NO - 1
    kd = okind(q)
    If kd Then
      If ov(q) Then
        ozf(q) = ozf(q) + ov(q)
        Do While ozf(q) >= 64
          ozf(q) = ozf(q) - 64 : oz(q) = oz(q) + 1
        Loop
      End If
      If ozf(q) Then d = (oz(q) - posM) * 16 + ozf(q) \ 4 - pf Else d = (oz(q) - posM) * 16 - pf
      od(q) = d
      If kd = K_ENEMY Then
        Enemy q, d
      ElseIf kd = K_SHOT Then
        ot(q) = ot(q) - 1
        If ot(q) <= 0 Then okind(q) = 0 Else ShotHits q
      ElseIf kd = K_MISSILE Then
        ot(q) = ot(q) - 1
        If ot(q) <= 0 Then okind(q) = 0 Else Missile q
      ElseIf kd = K_BOOM Then
        ot(q) = ot(q) + 1
        If ot(q) >= 16 Then okind(q) = 0
      End If
      kd = okind(q)
      far(q) = d
      ' gone behind
      If kd And kd <> K_ENEMY And d < -64 Then okind(q) = 0 : kd = 0
      If kd = 0 Then far(q) = -30000
      ' hitting it
      If kd Then
        rel = d - CARD
        If rel > -24 And rel < 24 And crashT = 0 And ksolid(kd) > 0 Then
          dx = Abs(ox(q) - carx)
          If dx < khalf(kd) + 22 Then Hit q, kd, dx
        End If
      End If
    End If
  Next
End Sub

' you hit thing q
Sub Hit(ByVal o As Integer, ByVal kd As Integer, ByVal dx As Integer)
  Dim s As Integer
  s = ksolid(kd)
  If s = 1 Then
    ' a tree, a sign, the barrier: a crash
    Boom oz(o), ox(o)
    v = 0 : crashT = 50 : dmg = dmg + 20 : rideDmg = 1
    If carx > ox(o) Then carx = carx + 20 Else carx = carx - 20
    Message "CRASH!", 10, 50
    Sfx.Play 2, 31, 0, 15, 50, 1
    Sfx.Play 1, 600, 10, 14, 30, 0
  ElseIf s = 2 Then
    ' a car: from behind, it slows you; from the side, it pushes you
    If v > ov(o) - 4 Then
      v = ov(o) - 10
      If v < 0 Then v = 0
      ov(o) = ov(o) + 6
      dmg = dmg + 5 : rideDmg = 1
      If carx > ox(o) Then carx = carx + 14 Else carx = carx - 14
      If okind(o) = K_ENEMY Then ohp(o) = ohp(o) - 1
      Sfx.Play 2, 31, 0, 13, 12, 1
    End If
  ElseIf s = 3 Then
    If spinT = 0 Then spinT = 48 : v = v * 3 \ 4 : Message "OIL!", 10, 40 : Sfx.Play 1, 50, 6, 13, 30, 1
  ElseIf s = 4 Then
    v = v \ 3 : dmg = dmg + 12 : rideDmg = 1
    Boom oz(o), ox(o)
    okind(o) = 0
    Message "BANG!", 10, 40
    Sfx.Play 2, 31, 0, 15, 30, 1
  ElseIf s = 5 Then
    If v > 30 Then v = v - 12
    dmg = dmg + 1
    ozf(o) = 0 : oz(o) = posM + 5        ' (once)
  End If
End Sub

' a black car: it catches you up, comes alongside and rams you - unless the smoke hides you, or it
' runs over your oil
Sub Enemy(ByVal o As Integer, ByVal d As Integer)
  Dim rel As Integer, m As Integer, dx As Integer
  rel = d - CARD
  If smokeT > 0 And rel < 0 Then
    ov(o) = v - 30
    If ov(o) < 0 Then ov(o) = 0
    ox(o) = ox(o) + 3 - Rnd(7)
  ElseIf rel < -40 Then
    ov(o) = v + 22
  ElseIf rel > 80 Then
    ov(o) = v - 14
  Else
    ov(o) = v + 1 - (rel \ 16)
    ' at your side: in for the ram
    dx = carx - ox(o)
    If dx > 4 Then ox(o) = ox(o) + 3
    If dx < -4 Then ox(o) = ox(o) - 3
    If ot(o) > 0 Then ot(o) = ot(o) - 1
    If Abs(dx) < 52 And Abs(rel) < 40 And ot(o) = 0 And crashT = 0 Then
      If dx > 0 Then carx = carx + 34 : ox(o) = ox(o) - 10 Else carx = carx - 34 : ox(o) = ox(o) + 10
      dmg = dmg + 4 : rideDmg = 1 : ot(o) = 25
      Sfx.Play 2, 31, 0, 14, 15, 1
    End If
  End If
  If ov(o) < 0 Then ov(o) = 0
  ' your oil
  For m = 0 To NO - 1
    If okind(m) = K_MYOIL Then
      If Abs(oz(m) - oz(o)) < 3 And Abs(ox(m) - ox(o)) < 44 Then
        okind(m) = 0
        KillEnemy o, "SPUN OUT!"
        Exit Sub
      End If
    End If
  Next
  If ohp(o) <= 0 Then KillEnemy o, "GOT ONE!" : Exit Sub
  ' too far back: it gives up
  If rel < -2400 Or rel > 12000 Then okind(o) = 0
End Sub

Sub KillEnemy(ByVal o As Integer, ByVal m As String)
  Boom oz(o), ox(o)
  okind(o) = 0
  money = money + 50
  Message m & " +$50", 10, 50
  Sfx.Play 2, 31, 0, 15, 50, 1
End Sub

' a tracer: does it hit a car?
Sub ShotHits(ByVal o As Integer)
  Dim m As Integer, kd As Integer
  For m = 0 To NO - 1
    kd = okind(m)
    If kd = K_ENEMY Or kd = K_CAR Or kd = K_TRUCK Then
      If Abs(od(m) - od(o)) < 48 And Abs(ox(m) - ox(o)) < khalf(kd) + 6 Then
        okind(o) = 0
        If kd = K_ENEMY Then
          ohp(m) = ohp(m) - 1
          opal(m) = 5
          Sfx.Play 1, 30, 2, 12, 4, 1
        End If
        Exit Sub
      End If
    End If
  Next
End Sub

' a missile: it steers for the nearest black car ahead
Sub Missile(ByVal o As Integer)
  Dim m As Integer, bm As Integer, bd As Integer
  bm = -1 : bd = 30000
  For m = 0 To NO - 1
    If okind(m) = K_ENEMY Then
      If od(m) > od(o) - 32 And od(m) - od(o) < bd Then bd = od(m) - od(o) : bm = m
    End If
  Next
  If bm >= 0 Then
    If ox(bm) > ox(o) + 4 Then ox(o) = ox(o) + 6
    If ox(bm) < ox(o) - 4 Then ox(o) = ox(o) - 6
    If bd < 48 And Abs(ox(bm) - ox(o)) < 40 Then
      okind(o) = 0
      KillEnemy bm, "BULLSEYE!"
    End If
  End If
End Sub

Sub Boom(ByVal z As Integer, ByVal x As Integer)
  Dim m As Integer
  m = NewObj(K_BOOM, z, x)
  If m >= 0 Then ot(m) = 0
End Sub

' ---------------------------------------------------------------- the job
Sub Job()
  Dim d As Integer, rel As Integer, fare As Integer
  If mission = 0 Then
    ' her, by the road
    If girlN < 0 And posM + 450 >= nextGirl Then
      girlN = NewObj(K_GIRL, nextGirl, 130)
    End If
    If girlN >= 0 Then
      If okind(girlN) <> K_GIRL Then
        girlN = -1
      Else
        rel = od(girlN) - CARD
        If rel < 320 And rel > -40 And v < 12 And carx > 30 Then
          ' she's in
          okind(girlN) = 0 : girlN = -1
          mission = 1 : rideDmg = 0 : rideT = 0
          destZ = posM + 1800 + Rnd(1500) + delivered * 150
          timeLeft = timeLeft + 750
          enemyT = 250
          PlanFork
          Message "SHE'S IN! STRAIGHT AHEAD, " & Trim$(Str$(destZ - posM)) & "M", 10, 120
          ShowJob
          Sfx.Play 0, 80, -2, 14, 30, 0
        ElseIf rel < -60 Then
          okind(girlN) = 0 : girlN = -1
          nextGirl = posM + 500
          Message "YOU DROVE RIGHT PAST HER!", 10, 90
        End If
      End If
    End If
  Else
    rideT = rideT + 1
    ' the fork: a warning, then which side were you?
    If forkZ > 0 And forkWarn = 0 And posM >= forkZ - 420 Then
      forkWarn = 1
      If forkSide = 0 Then Message "THE ROAD SPLITS: KEEP LEFT", 10, 150 Else Message "THE ROAD SPLITS: KEEP RIGHT", 10, 150
    End If
    If forkZ > 0 And forkDone = 0 And posM > forkZ + 130 Then
      forkDone = 1
      If (forkSide = 0 And carx > 0) Or (forkSide = 1 And carx < 0) Then
        destZ = destZ + 1000
        Message "WRONG WAY! THE LONG WAY ROUND", 10, 120
        Sfx.Play 1, 400, 4, 12, 30, 0
      Else
        Message "THAT'S THE WAY", 10, 60
      End If
    End If
    ' the flag
    If destZ - posM < 450 And girlN < 0 Then girlN = NewObj(K_DEST, destZ, 112)
    If girlN >= 0 Then
      If okind(girlN) = K_DEST Then
        rel = od(girlN) - CARD
        If rel < 320 And rel > -60 And v < 12 Then
          ' there: the fare
          fare = 100 + (3000 - rideT) \ 25
          If fare < 50 Then fare = 50
          If rideDmg = 0 Then fare = fare + 50 : Message "NOT A SCRATCH: TIP $50", 12, 120
          money = money + fare
          timeLeft = timeLeft + 1250
          delivered = delivered + 1
          nMis = 3 : nOil = 3 : nSmoke = 3 : ShowKit
          dmg = dmg - 15
          If dmg < 0 Then dmg = 0
          okind(girlN) = 0 : girlN = -1 : mission = 0
          nextGirl = posM + 450
          Message "THANKS, DRIVER! +$" & Trim$(Str$(fare)), 10, 120
          Sfx.Play 0, 100, -3, 15, 50, 0
          ShowJob
        ElseIf rel < -80 Then
          okind(girlN) = 0 : girlN = -1
          money = money - 20
          If money < 0 Then money = 0
          mission = 0 : nextGirl = posM + 450
          Message "TOO FAR! SHE WALKS. -$20", 10, 120
          ShowJob
        End If
      Else
        girlN = -1
      End If
    End If
  End If
End Sub

' a fork somewhere on the way (if it's far enough): signs, then the barrier down the middle
Sub PlanFork()
  Dim kd As Integer, m As Integer
  forkZ = 0 : forkDone = 0 : forkWarn = 0
  If destZ - posM < 1500 Then Exit Sub
  forkZ = posM + 700 + Rnd(500)
  forkSide = Rnd(2)
  If forkSide = 0 Then kd = K_SIGNL Else kd = K_SIGNR
  Plan 0, forkZ - 260, kd, 125
  Plan 1, forkZ - 260, kd, -125
  Plan 2, forkZ - 130, kd, 125
  Plan 3, forkZ - 130, kd, -125
  For m = 0 To 7
    Plan 4 + m, forkZ + m * 18, K_GORE, 0
  Next
End Sub

Sub Plan(ByVal i As Integer, ByVal z As Integer, ByVal kd As Integer, ByVal x As Integer)
  pz(i) = z : pk(i) = kd : px(i) = x
End Sub

' ---------------------------------------------------------------- drawing
' the things, far ones first (the near ones over them: one pass of sorting a frame keeps them so),
' then your car
Sub DrawCar(ByVal off As Integer)
  Dim x As Integer, y As Integer, pat As Integer, j As Integer, t As Integer, s As Integer
  ' one pass of sorting
  For j = 0 To NO - 2
    If far(ord(j + 1)) > far(ord(j)) Then t = ord(j) : ord(j) = ord(j + 1) : ord(j + 1) = t
  Next
  For j = 0 To NO - 1
    DrawObj ord(j), j
  Next
  ' your car: at the bottom, 8 metres ahead of the eye
  x = 128 + Road.Shift(111) + (carx \ 2) * 111 \ 64
  y = 190
  If off And (frames And 2) Then y = 189
  If crashT > 0 And (frames And 4) Then
    Spr.HideRange SP_CAR, 2
  Else
    pat = GfxData.S_PCAR
    If steer < 0 Then pat = pat + 2
    If steer > 0 Then pat = pat + 4
    If mission = 1 Then pat = pat + 6
    Spr.Put SP_CAR, x, y, pat, Spr.Scale2
    Spr.Put SP_CAR + 1, x + 32, y, pat + 1, Spr.Scale2
  End If
  ' the smoke screen: puffs behind you
  For j = 0 To 3
    If smokeT > 0 And smokeT > j * 30 Then
      s = (frames * 3 + j * 40) And 127
      Spr.Put SP_PUFF + j, x - 24 + j * 30 + (s And 15), 160 + (s \ 8), GfxData.S_PUFF + 2, Spr.Scale2
    Else
      Spr.Hide SP_PUFF + j
    End If
  Next
End Sub

' thing o as roadside sprite j (Road works out where and how big)
Sub DrawObj(ByVal o As Integer, ByVal j As Integer)
  Dim kd As Integer, pat As Integer, fl As Integer
  kd = okind(o)
  If kd = 0 Or kd = K_MYOIL Then
    Road.Obj j, 0, 0, 0, 0, 0
    Exit Sub
  End If
  pat = kpat(kd)
  fl = Spr.Pal * opal(o)
  If kd = K_GIRL And (frames And 16) <> 0 Then pat = pat + 3
  If kd = K_BOOM Then pat = pat + ot(o) \ 4 : fl = fl Or 1
  If kd = K_SHOT Then fl = fl Or 1
  If kd = K_ENEMY And opal(o) = 5 Then opal(o) = 4      ' hit: one white frame
  Road.Obj j, od(o), ox(o), pat, fl, kfull(kd)
End Sub
