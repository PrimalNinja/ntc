' HIVEBREAKER - a mech robot-swarm shooter for the ZX Spectrum Next (NTC BASIC + NTC3D)
'
' A robot Hive has taken the wasteland. You are a transforming battle mech: a TANK (low and fast, you see
' its treads and its one turret in the middle) or a WALKER (tall: you look down on things from high above
' the ground; slower, two guns firing from low at the sides), and you can jump in a burst that has to recharge. The swarm hunts you across the open ground; the six hive towers hold
' Berzerk-style chambers of sentries and turrets, and a reactor core at the end of each. Robots are
' greys and blues, shots are reds and yellows, power-up pods are pink (shield) and green (E.C.M. and
' a charged jump). Stay too long in a chamber and the Warden comes for you.
'
' Controls (the Spectrum's usual):
'   O / P            turn left / right          Q / A    throttle up / down (it holds your speed)
'   Space or Enter   fire                       S        transform: tank <-> walker
'   W                jump (then it recharges)   E        E.C.M.: wipes the robots' shots, hurts what's near
'   Kempston joystick: left / right turn, up / down throttle, fire, fire 2 = jump
'
' All the moving, the hits and the drawing are NTC3D's (Obj3D, E3, Fly3D, Hud3D, Radar3D): this file is
' only what's what, and what a hit does. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Option Turbo
Option NexData "HIVEBRK.DAT", 1

' ---- controls (Fly3D's bits are 1 - 8) and settings
Const K_FIRE = 64, K_ECM = 128, K_JUMP = 256, K_FORM = 512
Const NS = 36                               ' sites: 6 hives, 8 pylons, 6 silos, 6 pods, 10 mines
Const WORLD = 360                           ' the zone is WORLD x WORLD cells of 256 units (92000 units across)
Const EYE_T = 70, EYE_W = 280              ' your eye's height as a tank, as a walker
Const RW = 1400, RD = 1400, RH = 520       ' a chamber: half width, half depth, height

' ---- colours (a ramp x 16 + a shade)
Const C_HUD = 13 * 16 + 13, C_DIM = 13 * 16 + 7, C_RED = 2 * 16 + 11, C_GOLD = 6 * 16 + 14
Const C_CYAN = 7 * 16 + 13, C_BLU = 10 * 16 + 13, C_PANEL = 14 * 16 + 2, C_GRN = 4 * 16 + 12, C_PNK = 15 * 16 + 13

' ---- what things are (otype)
Const T_GRUNT = 1, T_HULK = 2, T_SCOUT = 3, T_ELECT = 4, T_PODP = 5, T_HIVE = 6, T_DOOR = 7, T_SCEN = 8
Const T_PODG = 9, T_EBOLT = 10, T_TURRET = 11, T_SENTRY = 12, T_CORE = 13, T_WARDEN = 14, T_PILLAR = 15
Const T_TANK = 16, T_ORB = 17

' ---- modes
Const M_TITLE = 0, M_OUT = 1, M_IN = 2, M_OVER = 3, M_WIN = 4

Dim dt As Integer, vflip As Integer, frames As Integer, gmode As Integer, keys As Integer
Dim score As Integer, hiscore As Integer, shield As Integer, lives As Integer, heat As Integer, ecm As Integer
Dim pods As Integer, cores As Integer, hurtT As Integer, cool As Integer, ecmT As Integer, flash As Integer
Dim lockd As Integer, regen As Integer, spT As Integer, godm As Integer, dbg As Integer, spwT As Integer, fcol As Integer
Dim ox As Integer, oz As Integer, ox0 As Integer, oz0 As Integer
Dim spd As Integer, smax As Integer, acc As Integer, tmax As Integer, trn As Integer   ' the throttle: speed, most, change a 50th; the turn
Dim mech As Integer, xf As Integer, xfk As Integer, jy As Integer, jv As Integer, jc As Integer, cam As Integer
Dim trk As Integer, fwdm As Integer, fwdr As Integer, yawPx As Integer, bmL As Integer, bmR As Integer, gside As Integer
Dim inHive As Integer, inRoom As Integer, locked As Integer, wardT As Integer, wardOn As Integer, exitT As Integer
Dim e As Integer, i As Integer, s As Integer, k As Integer, t As Integer, x As Integer, z As Integer, v As Integer
Dim sx(35) As Integer, sz(35) As Integer, sk(35) As Integer, so(35) As Integer, sd(35) As Integer
Dim rin(4) As Integer, rout(4) As Integer, ux(5) As Integer, uz(5) As Integer, ptab(19) As Integer
Dim hdead(5) As Integer, rclr(17) As Integer
Dim mstr As String, mink As Integer, mT As Integer, mdirty As Integer
Dim sScore As Integer, sHi As Integer, sCores As Integer, sEcm As Integer, sLives As Integer, sForm As Integer

InitGame
Do
  Title
  NewGame
  Do
    If gmode = M_OUT Then FrameOut Else FrameIn
  Loop While gmode = M_OUT Or gmode = M_IN
  EndScreen
Loop

' ================================================================ setup
Sub InitGame()
  E3.Init
  E3.nstar = 40
  E3.stymax = 80
  Obj3D.Init
  Fly3D.Init
  Obj3D.BoltModel E3Data.K_BOLT, 1, 2 * 16 + 14
  Obj3D.DebrisModel E3Data.K_SHARD, 1, 3 * 16 + 10, 1
  Obj3D.BlastModel E3Data.K_FIREB, 3 * 16 + 14
  Obj3D.blife = 55
  Hud3D.Ink 1, C_DIM : Hud3D.Ink 2, C_HUD : Hud3D.Ink 3, C_GOLD : Hud3D.Ink 4, C_RED
  Hud3D.Ink 5, C_CYAN : Hud3D.Ink 6, 15 * 16 + 15 : Hud3D.Ink 7, C_PNK
  Sfx.Init
  ' how far out a site comes into the world and goes again (in cells), by kind
  rin(0) = 52 : rout(0) = 64 : rin(1) = 32 : rout(1) = 42 : rin(2) = 32 : rout(2) = 42
  rin(3) = 26 : rout(3) = 36 : rin(4) = 26 : rout(4) = 36
  ' six directions about the middle (x 16)
  ux(0) = 16 : uz(0) = 0 : ux(1) = 8 : uz(1) = 14 : ux(2) = -8 : uz(2) = 14
  ux(3) = -16 : uz(3) = 0 : ux(4) = -8 : uz(4) = -14 : ux(5) = 8 : uz(5) = -14
  ' the scanner's colour for each kind of thing (0: not shown): robots blue and grey, shots red, pods pink and green
  ptab(T_GRUNT) = C_BLU : ptab(T_HULK) = 9 * 16 + 14 : ptab(T_SCOUT) = C_BLU : ptab(T_ELECT) = 10 * 16 + 9
  ptab(T_PODP) = C_PNK : ptab(T_PODG) = C_GRN : ptab(T_HIVE) = 1 * 16 + 12 : ptab(T_EBOLT) = C_RED
  ptab(T_TURRET) = C_BLU : ptab(T_SENTRY) = 1 * 16 + 13 : ptab(T_CORE) = C_GOLD : ptab(T_WARDEN) = 15
  ptab(T_TANK) = 1 * 16 + 13 : ptab(T_ORB) = C_BLU
  vflip = E3.vbl
  hiscore = 5000
End Sub

' NewGame: a new zone, you in the middle of it, a tank
Sub NewGame()
  score = 0 : lives = 3 : shield = 100 : heat = 0 : ecm = 3 : pods = 0 : cores = 0
  hurtT = 90 : cool = 0 : lockd = 0 : flash = 0 : godm = 0
  mech = 0 : xf = 0 : xfk = 1 : jy = 0 : jv = 0 : jc = 200
  For k = 0 To 5
    hdead(k) = 0
  Next
  For k = 0 To 17
    rclr(k) = 0
  Next
  MakeWorld
  StartOutside
  HudInit
  Msg "FIND THE HIVES. DESTROY THE CORES.", 3
End Sub

' MakeWorld: the hives one to a sixth of a ring about the middle, the rest anywhere clear of them
Sub MakeWorld()
  For k = 0 To 5
    sk(k) = 0
    sx(k) = 180 + (ux(k) * (70 + Rnd(40))) \ 16 + Rnd(17) - 8
    sz(k) = 180 + (uz(k) * (70 + Rnd(40))) \ 16 + Rnd(17) - 8
  Next
  For k = 6 To NS - 1
    If k < 14 Then
      sk(k) = 1
    ElseIf k < 20 Then
      sk(k) = 2
    ElseIf k < 26 Then
      sk(k) = 3
    Else
      sk(k) = 4
    End If
    Do
      sx(k) = 14 + Rnd(WORLD - 28) : sz(k) = 14 + Rnd(WORLD - 28)
      t = 0
      For i = 0 To 5
        If Abs(sx(k) - sx(i)) < 9 And Abs(sz(k) - sz(i)) < 9 Then t = 1
      Next
      If Abs(sx(k) - 180) < 12 And Abs(sz(k) - 180) < 12 Then t = 1
    Loop While t <> 0
  Next
  ClearSites
End Sub

Sub ClearSites()
  For k = 0 To NS - 1
    so(k) = -1 : sd(k) = -1
  Next
End Sub

' StartOutside: the middle of the zone, facing north, a little way along
Sub StartOutside()
  Obj3D.Clear
  ClearSites
  ox = 180 : oz = 180
  E3.CamReset
  cam = EYE_T
  E3.CamPos 0, cam, 0
  Fly3D.Init
  smax = 900 : acc = 18 : spd = 300 : tmax = 360 : trn = 0
  Fly3D.rby = 0
  Fly3D.GetCam
  Obj3D.gy = 0
  spT = 0 : gmode = M_OUT
End Sub

' ================================================================ the outside
Sub FrameOut()
  keys = ReadKeys()
  ox0 = Fly3D.cx : oz0 = Fly3D.cz
  DriveTank
  k = Fly3D.Rebase()
  If k Then
    ox = ox + Fly3D.dx \ 256 : oz = oz + Fly3D.dz \ 256
    ox0 = ox0 - Fly3D.dx : oz0 = oz0 - Fly3D.dz
  End If
  Bounds
  Stream
  Spawner
  Common
  Obj3D.Update dt
  Events
  Shoot
  If (frames And 7) = 0 Then Sweep
  DrawOutside
  HudFrame
  Sync
End Sub

' DriveTank: the mech's driving. S changes between tank and walker (it takes a moment: the eye goes up
' or down); the tank is fast and low, the walker tall and slower. Q / A change the speed and it's kept
' (never reversing), the turn builds up and eases off, the camera's kept level. W jumps: a burst up
' that has to charge again. Obj3D's told your speed and way; the tracks and the ground dots their phases
Sub DriveTank()
  Dim ty As Integer, q As Integer
  If (keys And K_FORM) Then
    If xfk = 0 Then
      mech = 1 - mech : xfk = 1
      Sfx.Play 2, 500, -8, 14, 25, 0
      If mech Then Msg "WALKER: TALL, TWO GUNS, SLOWER", 5 Else Msg "TANK: ONE TURRET, LOW AND FAST", 5
    End If
  Else
    xfk = 0
  End If
  If mech Then
    xf = xf + dt
    If xf > 30 Then xf = 30
  Else
    xf = xf - dt
    If xf < 0 Then xf = 0
  End If
  smax = 900 - (xf * 280) \ 30
  tmax = 360 - (xf * 70) \ 30
  If spd > smax Then spd = smax
  ty = 0
  If keys And Fly3D.K_LEFT Then ty = -tmax
  If keys And Fly3D.K_RIGHT Then ty = tmax
  trn = trn + (ty - trn) * dt \ 5
  If Abs(trn) < 8 Then trn = 0
  E3.CamTurn -E3.cm(7) \ 4, trn * dt, E3.cm(1) \ 4
  If keys And Fly3D.K_FWD Then
    spd = spd + acc * dt
    If spd > smax Then spd = smax
  ElseIf keys And Fly3D.K_BACK Then
    spd = spd - acc * dt
    If spd < 0 Then spd = 0
  End If
  E3.CamMove spd * dt
  ' the jump: a burst up, then gravity; it charges again once you're down
  If (keys And K_JUMP) Then
    If jy = 0 And jv = 0 And jc >= 200 Then
      jv = 44 : jc = 0
      Sfx.Play 1, 20, 3, 15, 22, 1
    End If
  End If
  For q = 1 To dt
    If jy > 0 Or jv > 0 Then
      jv = jv - 2 : jy = jy + jv
      If jy <= 0 Then
        jy = 0 : jv = 0
        Sfx.Play 1, 14, 1, 13, 10, 1
      End If
    ElseIf jc < 200 Then
      jc = jc + 1
    End If
  Next
  Fly3D.GetCam
  cam = EYE_T + (xf * (EYE_W - EYE_T)) \ 30 + jy
  If gmode = M_IN Then
    If cam > RH - 60 Then cam = RH - 60
  End If
  E3.CamPos Fly3D.cx, cam, Fly3D.cz
  Fly3D.GetCam
  Obj3D.pvx = (E3.cm(6) \ 64) * (spd \ 64) \ 64
  Obj3D.pvy = (E3.cm(7) \ 64) * (spd \ 64) \ 64
  Obj3D.pvz = (E3.cm(8) \ 64) * (spd \ 64) \ 64
  Obj3D.hfx = Obj3D.hfx + (E3.cm(6) - Obj3D.hfx) \ 64 * dt
  Obj3D.hfy = Obj3D.hfy + (E3.cm(7) - Obj3D.hfy) \ 64 * dt
  Obj3D.hfz = Obj3D.hfz + (E3.cm(8) - Obj3D.hfz) \ 64 * dt
  ' the phases: tracks, the ground dots' rows and sideways sweep
  trk = (trk + (spd * dt) \ 600) Mod 48
  fwdm = fwdm + (spd * dt) \ 16
  Do While fwdm >= 480
    fwdm = fwdm - 480 : fwdr = (fwdr + 1) And 255
  Loop
  yawPx = (yawPx - (trn * dt) \ 128) And 255
End Sub

' Bounds: the edge of the zone: you can't go past it
Sub Bounds()
  Dim ax As Integer, az As Integer
  ax = ox + Fly3D.cx \ 256 : az = oz + Fly3D.cz \ 256
  If ax < 6 Then E3.CamPos (6 - ox) * 256, cam, Fly3D.cz
  If ax > WORLD - 6 Then E3.CamPos (WORLD - 6 - ox) * 256, cam, Fly3D.cz
  Fly3D.GetCam
  If az < 6 Then E3.CamPos Fly3D.cx, cam, (6 - oz) * 256
  If az > WORLD - 6 Then E3.CamPos Fly3D.cx, cam, (WORLD - 6 - oz) * 256
  Fly3D.GetCam
End Sub

' Stream: sites near you are in the world as objects, far ones aren't (half of them a frame)
Sub Stream()
  Dim rx As Integer, rz As Integer, d As Integer
  spT = 1 - spT
  For k = spT To NS - 1 Step 2
    If sk(k) < 9 Then
      rx = sx(k) - ox - Fly3D.cx \ 256
      rz = sz(k) - oz - Fly3D.cz \ 256
      d = Abs(rx)
      If Abs(rz) > d Then d = Abs(rz)
      If so(k) < 0 Then
        If d <= rin(sk(k)) Then SpawnSite k
      ElseIf d > rout(sk(k)) Then
        If so(k) >= 0 Then Obj3D.Kill so(k)
        If sd(k) >= 0 Then Obj3D.Kill sd(k)
        so(k) = -1 : sd(k) = -1
      End If
    End If
  Next
End Sub

' SpawnSite q: site q's object (a hive's door too) into the world
Sub SpawnSite(ByVal q As Integer)
  Dim kd As Integer
  x = (sx(q) - ox) * 256 : z = (sz(q) - oz) * 256
  kd = sk(q)
  If kd = 0 Then
    s = Obj3D.Spawn(E3Data.K_HIVE, 3, Obj3D.CL_SCENERY, x, 400, z, C_DIM)
    If s < 0 Then Exit Sub
    Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_HIVE : Obj3D.ouv(s) = q
    so(q) = s
    If hdead(q) Then
      t = Obj3D.Spawn(E3Data.K_DOORX, 3, Obj3D.CL_SCENERY, x, 192, z - 728, C_DIM)
    Else
      t = Obj3D.Spawn(E3Data.K_DOOR, 3, Obj3D.CL_SCENERY, x, 192, z - 728, C_CYAN)
    End If
    If t >= 0 Then
      If hdead(q) = 0 Then Obj3D.omask(t) = Obj3D.M_PLAYER
      Obj3D.otype(t) = T_DOOR : Obj3D.ouv(t) = q
      sd(q) = t
    End If
  ElseIf kd = 1 Then
    s = Obj3D.Spawn(E3Data.K_PYLON, 2, Obj3D.CL_SCENERY, x, 320, z, C_DIM)
    If s >= 0 Then Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_SCEN : so(q) = s
  ElseIf kd = 2 Then
    s = Obj3D.Spawn(E3Data.K_SILO, 3, Obj3D.CL_SCENERY, x, 320, z, C_DIM)
    If s >= 0 Then Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_SCEN : so(q) = s
  ElseIf kd = 3 Then
    s = MakePod(x, z, q And 1)
    If s >= 0 Then
      Obj3D.ouv(s) = q : so(q) = s
    End If
  ElseIf kd = 4 Then
    s = Obj3D.Spawn(E3Data.K_ELECT, 1, Obj3D.CL_SCENERY, x, 140, z, C_BLU)
    If s >= 0 Then
      Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_ELECT : Obj3D.ouv(s) = q
      Obj3D.Spin s, 3, 0 : so(q) = s
    End If
  End If
End Sub

' MakePod x, z, pink: a pod (pink: shield, green: E.C.M. and a charged jump) hovering and turning; its slot (or -1)
Function MakePod(ByVal px As Integer, ByVal pz As Integer, ByVal pk As Integer) As Integer
  Dim q As Integer
  If pk Then
    q = Obj3D.Spawn(E3Data.K_PODP, 1, Obj3D.CL_SCENERY, px, 130, pz, C_PNK)
    t = T_PODP
  Else
    q = Obj3D.Spawn(E3Data.K_PODG, 1, Obj3D.CL_SCENERY, px, 130, pz, C_GRN)
    t = T_PODG
  End If
  If q >= 0 Then
    Obj3D.omask(q) = Obj3D.M_PLAYER : Obj3D.otype(q) = t : Obj3D.Spin q, 4, 0
  End If
  MakePod = q
End Function

' DropPod x, z: a kill leaves a pod now and then
Sub DropPod(ByVal px As Integer, ByVal pz As Integer)
  If Rnd(5) <> 0 Then Exit Sub
  s = MakePod(px, pz, Rnd(2))
  If s >= 0 Then
    Obj3D.ouv(s) = -1 : Obj3D.olife(s) = 700
  End If
End Sub

' Spawner: the swarm: robots come out of the dark all round you, more of them (and more kinds) the more cores are gone:
' grunts and tank-bots from the start, scouts after one core, orbs and hulks after two
Sub Spawner()
  Dim n As Integer
  spwT = spwT - dt
  If spwT > 0 Then Exit Sub
  spwT = 60 - cores * 6
  n = 4 + cores
  If Obj3D.Count(Obj3D.CL_ENEMY) >= n Then Exit Sub
  Do
    x = Rnd(24000) - 12000 : z = Rnd(24000) - 12000
  Loop Until Abs(x) > 8000 Or Abs(z) > 8000
  x = x + Fly3D.cx : z = z + Fly3D.cz
  k = Rnd(10)
  If k >= 6 And k < 8 And cores = 0 Then k = 1
  If k >= 8 And cores < 2 Then k = 7 * cores
  If k < 4 Then
    s = Obj3D.Spawn(E3Data.K_GRUNT, 1, Obj3D.CL_ENEMY, x, 100, z, C_BLU)
    If s < 0 Then Exit Sub
    Obj3D.SetMover s, Obj3D.MV_HUNT, 0
    Obj3D.odist(s) = 700 : Obj3D.opa(s) = 30 : Obj3D.opb(s) = -1 : Obj3D.otm(s) = 100 + Rnd(100)
    Obj3D.otype(s) = T_GRUNT : Obj3D.ouv(s) = 1
  ElseIf k < 6 Then
    s = Obj3D.Spawn(E3Data.K_TANK, 1, Obj3D.CL_ENEMY, x, 60, z, C_BLU)
    If s < 0 Then Exit Sub
    Obj3D.SetMover s, Obj3D.MV_HUNT, Obj3D.OF_GUNANY
    Obj3D.odist(s) = 1500 : Obj3D.opa(s) = 22 : Obj3D.opb(s) = -1 : Obj3D.otm(s) = 200 : Obj3D.ogun(s) = 90 + Rnd(90)
    Obj3D.otype(s) = T_TANK : Obj3D.ouv(s) = 3
  ElseIf k < 8 Then
    s = Obj3D.Spawn(E3Data.K_SCOUT, 1, Obj3D.CL_ENEMY, x, 140, z, C_BLU)
    If s < 0 Then Exit Sub
    Obj3D.SetMover s, Obj3D.MV_CIRCLE, Obj3D.OF_GUNANY
    Obj3D.odist(s) = 3200 : Obj3D.ospd(s) = 14 + Rnd(10) : Obj3D.opa(s) = 40 : Obj3D.ogun(s) = 90 + Rnd(80)
    If Rnd(2) Then Obj3D.ospd(s) = -Obj3D.ospd(s)
    Obj3D.otype(s) = T_SCOUT : Obj3D.ouv(s) = 2
  ElseIf k < 9 Then
    s = Obj3D.Spawn(E3Data.K_ORB, 1, Obj3D.CL_ENEMY, x, 170, z, C_BLU)
    If s < 0 Then Exit Sub
    Obj3D.SetMover s, Obj3D.MV_CIRCLE, Obj3D.OF_GUNANY
    Obj3D.odist(s) = 2200 : Obj3D.ospd(s) = 9 + Rnd(6) : Obj3D.opa(s) = 34 : Obj3D.ogun(s) = 60 + Rnd(60)
    If Rnd(2) Then Obj3D.ospd(s) = -Obj3D.ospd(s)
    Obj3D.otype(s) = T_ORB : Obj3D.ouv(s) = 4 : Obj3D.Spin s, 5, 2
  Else
    s = Obj3D.Spawn(E3Data.K_HULK, 1, Obj3D.CL_ENEMY, x, 112, z, C_DIM)
    If s < 0 Then Exit Sub
    Obj3D.SetMover s, Obj3D.MV_HUNT, 0
    Obj3D.odist(s) = 500 : Obj3D.opa(s) = 15 : Obj3D.opb(s) = -1 : Obj3D.otm(s) = 300
    Obj3D.otype(s) = T_HULK : Obj3D.ouv(s) = 6
  End If
  Obj3D.omask(s) = Obj3D.M_PLAYER + Obj3D.M_SCENERY
End Sub

' Sweep: robots that have lost you are put back in the dark
Sub Sweep()
  For i = 0 To Obj3D.NOBJ - 1
    If Obj3D.ocls(i) = Obj3D.CL_ENEMY Then
      Obj3D.Pos i
      If Abs(Obj3D.px - Fly3D.cx) > 20000 Or Abs(Obj3D.pz - Fly3D.cz) > 20000 Then Obj3D.Kill i
    End If
  Next
End Sub

' DrawOutside: the sky, the horizon glow, the mountains, the ground's dots, everything
Sub DrawOutside()
  If flash > 0 Then
    E3.Begin2 fcol * 16 + 14, fcol * 16 + 10, 96
    flash = flash - 1
  Else
    Sky
    DrawDots 8 * 16 + 13, 8 * 16 + 10
  End If
  Obj3D.Draw
End Sub

' Sky: the night sky, its glow at the horizon, the stars and the mountains
Sub Sky()
  E3.Begin2 11 * 16 + 2, 8 * 16 + 3, 96
  E3.Box 0, 62, 256, 14, 11 * 16 + 5
  E3.Box 0, 76, 256, 9, 5 * 16 + 5
  E3.Box 0, 85, 256, 6, 5 * 16 + 9
  E3.Box 0, 91, 256, 5, 3 * 16 + 5
  E3.Box 0, 96, 256, 4, 8 * 16 + 8
  E3.Stars
  E3.Skyline E3Data.SkyAt, E3Data.NSky, 96
End Sub

' DrawDots near, far: dots on the ground, in rows going by as you go (seven rows 480 units apart, each
' with dots a world 500 apart across, seen from your eye's height: y = 96 + eye * 128 / distance). It's a
' drawing trick: the rows are always square to the way you face, and turning sweeps them sideways
Sub DrawDots(ByVal cn As Integer, ByVal cf As Integer)
  Dim r As Integer, d As Integer, y As Integer, sp As Integer, dx As Integer, ph As Integer, h As Integer, ri As Integer, n As Integer
  For r = 1 To 7
    d = r * 480 - fwdm
    If d > 160 Then
      y = 96 + ((cam \ 8) * 64) \ (d \ 16)
      If y < 156 Then
        sp = 32000 \ (d \ 2)
        If sp < 8 Then sp = 8
        ri = r + fwdr
        ph = (yawPx + ri * 37) Mod sp
        dx = ph : n = 0
        Do While dx < 254
          h = (ri * 29 + n * 13 + ri * n) And 7
          If h < 4 Then
            If d < 1700 Then E3.Dot dx + h - 2, y, cn Else E3.Box dx + h - 2, y, 1, 1, cf
          End If
          dx = dx + sp : n = n + 1
        Loop
      End If
    End If
  Next
End Sub

' ================================================================ the hives
Sub EnterHive(ByVal h As Integer)
  Obj3D.Clear
  ClearSites
  inHive = h : exitT = 0
  If spd > 400 Then spd = 400
  gmode = M_IN
  EnterRoom 0, 0
  Msg "HIVE " & CStr(h + 1) & ": FIND THE CORE", 5
  Sfx.Play 2, 400, -6, 14, 30, 0
End Sub

' EnterRoom r, fromNorth: chamber r (0 - 2) of the hive; you stand at its south door (or its north door)
Sub EnterRoom(ByVal r As Integer, ByVal fromN As Integer)
  Obj3D.Clear
  inRoom = r : wardT = 0 : wardOn = 0 : hurtT = 60
  E3.CamReset
  If fromN Then
    E3.CamPos 0, cam, RD - 260
    E3.CamTurn 0, 25736, 0
    E3.CamTurn 0, 25736, 0
  Else
    E3.CamPos 0, cam, 260 - RD
  End If
  Fly3D.Reset
  Fly3D.GetCam
  If spd > 250 Then spd = 250
  ox0 = Fly3D.cx : oz0 = Fly3D.cz
  locked = 0
  Pillars
  If rclr(inHive * 3 + r) = 0 Then
    locked = 1
    If r = 0 Then
      For k = 1 To 2 + cores \ 2
        Sentry Rnd(2000) - 1000, 300 + Rnd(700)
      Next
    ElseIf r = 1 Then
      Turret 1150, 1150 : Turret -1150, 1150 : Turret 1150, -100 : Turret -1150, -100
      For k = 1 To 1 + cores \ 2
        Sentry Rnd(2000) - 1000, 400 + Rnd(700)
      Next
      For k = 1 To 1 + cores \ 3
        TankBot Rnd(1600) - 800, 500 + Rnd(500)
      Next
    Else
      s = Obj3D.Spawn(E3Data.K_CORE, 1, Obj3D.CL_SCENERY, 0, 150, 650, 3 * 16 + 14)
      If s >= 0 Then
        Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_CORE : Obj3D.ouv(s) = 12
        Obj3D.Spin s, 3, 1
      End If
      Turret 1050, 1050 : Turret -1050, 1050 : Turret 1050, 250 : Turret -1050, 250
      For k = 1 To 1 + cores \ 3
        Sentry Rnd(1600) - 800, -200 + Rnd(500)
      Next
      For k = 1 To cores \ 2
        TankBot Rnd(1600) - 800, -200 + Rnd(400)
      Next
    End If
  End If
  If r = 2 Then locked = 0
End Sub

Sub Pillars()
  If inRoom = 0 Then
    Pillar -750, 150 : Pillar 750, 150 : Pillar -750, 850 : Pillar 750, 850
  ElseIf inRoom = 1 Then
    Pillar -450, 450 : Pillar 450, 450
  Else
    Pillar -500, -300 : Pillar 500, -300
  End If
End Sub

Sub Pillar(ByVal px As Integer, ByVal pz As Integer)
  s = Obj3D.Spawn(E3Data.K_PILLAR, 2, Obj3D.CL_SCENERY, px, 240, pz, C_DIM)
  If s >= 0 Then Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_PILLAR
End Sub

Sub Sentry(ByVal px As Integer, ByVal pz As Integer)
  s = Obj3D.Spawn(E3Data.K_GRUNT, 1, Obj3D.CL_ENEMY, px, 100, pz, C_BLU)
  If s < 0 Then Exit Sub
  Obj3D.SetMover s, Obj3D.MV_HUNT, Obj3D.OF_GUNANY
  Obj3D.odist(s) = 600 : Obj3D.opa(s) = 12 + cores : Obj3D.opb(s) = -1 : Obj3D.otm(s) = 200
  Obj3D.ogun(s) = 80 + Rnd(120)
  Obj3D.omask(s) = Obj3D.M_PLAYER + Obj3D.M_SCENERY
  Obj3D.otype(s) = T_SENTRY : Obj3D.ouv(s) = 2
End Sub

Sub TankBot(ByVal px As Integer, ByVal pz As Integer)
  s = Obj3D.Spawn(E3Data.K_TANK, 1, Obj3D.CL_ENEMY, px, 60, pz, C_BLU)
  If s < 0 Then Exit Sub
  Obj3D.SetMover s, Obj3D.MV_HUNT, Obj3D.OF_GUNANY
  Obj3D.odist(s) = 900 : Obj3D.opa(s) = 11 + cores : Obj3D.opb(s) = -1 : Obj3D.otm(s) = 300 : Obj3D.ogun(s) = 100 + Rnd(100)
  Obj3D.omask(s) = Obj3D.M_PLAYER + Obj3D.M_SCENERY
  Obj3D.otype(s) = T_TANK : Obj3D.ouv(s) = 3
End Sub

Sub Turret(ByVal px As Integer, ByVal pz As Integer)
  s = Obj3D.Spawn(E3Data.K_TURRET, 1, Obj3D.CL_ENEMY, px, 60, pz, C_BLU)
  If s < 0 Then Exit Sub
  Obj3D.SetMover s, Obj3D.MV_STILL, Obj3D.OF_FACECAM + Obj3D.OF_GUNANY
  Obj3D.ogun(s) = 60 + Rnd(150)
  Obj3D.omask(s) = Obj3D.M_PLAYER
  Obj3D.otype(s) = T_TURRET : Obj3D.ouv(s) = 3
End Sub

' FrameIn: a chamber
Sub FrameIn()
  keys = ReadKeys()
  ox0 = Fly3D.cx : oz0 = Fly3D.cz
  DriveTank
  If Fly3D.cx < 70 - RW Then E3.CamPos 70 - RW, cam, Fly3D.cz : spd = 0
  If Fly3D.cx > RW - 70 Then E3.CamPos RW - 70, cam, Fly3D.cz : spd = 0
  If Fly3D.cz < 70 - RD Then E3.CamPos Fly3D.cx, cam, 70 - RD
  If Fly3D.cz > RD - 70 Then E3.CamPos Fly3D.cx, cam, RD - 70
  Fly3D.GetCam
  If Abs(Fly3D.cx) >= 260 Then
    If Fly3D.cz <= 72 - RD Or Fly3D.cz >= RD - 72 Then spd = 0
  End If
  If Fly3D.cz >= RD - 72 And locked <> 0 Then spd = 0
  If Fly3D.cz >= RD - 72 And inRoom = 2 Then spd = 0
  Common
  Obj3D.Update dt
  Events
  Shoot
  If gmode <> M_IN Then Exit Sub
  ' the doors
  If Abs(Fly3D.cx) < 260 Then
    If Fly3D.cz <= 72 - RD Then
      If inRoom = 0 Or exitT > 0 Then
        LeaveHive
      Else
        EnterRoom inRoom - 1, 1
      End If
      Exit Sub
    End If
    If Fly3D.cz >= RD - 72 And inRoom < 2 And locked = 0 Then
      EnterRoom inRoom + 1, 0
      Exit Sub
    End If
  End If
  If locked And inRoom < 2 Then
    If Obj3D.Count(Obj3D.CL_ENEMY) = 0 Then
      locked = 0 : rclr(inHive * 3 + inRoom) = 1
      Msg "CHAMBER CLEAR. THE DOOR IS OPEN.", 2
      Sfx.Play 2, 200, -4, 13, 24, 0
    End If
  End If
  ' stay too long and the Warden comes
  If exitT > 0 Then
    exitT = exitT - dt
    If (frames And 3) = 0 Then flash = 2 : fcol = 3
    If exitT <= 0 Then LeaveHive
  Else
    wardT = wardT + dt
    If wardT > 2200 And wardOn = 0 Then SpawnWarden
  End If
  DrawRoom
  HudFrame
  Sync
End Sub

Sub SpawnWarden()
  wardOn = 1
  s = Obj3D.Spawn(E3Data.K_WARDEN, 1, Obj3D.CL_SCENERY, -Fly3D.cx, 110, RD - 200, 15)
  If s < 0 Then Exit Sub
  Obj3D.SetMover s, Obj3D.MV_HUNT, 0
  Obj3D.odist(s) = 300 : Obj3D.opa(s) = 17 : Obj3D.opb(s) = -1 : Obj3D.otm(s) = 400
  Obj3D.omask(s) = Obj3D.M_PLAYER
  Obj3D.otype(s) = T_WARDEN : Obj3D.ouv(s) = 999 : Obj3D.Spin s, 6, 3
  Msg "THE WARDEN HAS FOUND YOU!", 4
  Sfx.Play 2, 600, 10, 15, 40, 0
End Sub

' CoreDown: the reactor's gone: a few seconds of shaking, then out
Sub CoreDown()
  hdead(inHive) = 1 : cores = cores + 1
  score = score + 2500
  rclr(inHive * 3 + 2) = 1
  exitT = 150
  shield = shield + 30 : If shield > 100 Then shield = 100
  Msg "REACTOR " & CStr(cores) & " DESTROYED! GET OUT!", 3
  Sfx.Play 1, 4, 1, 15, 40, 1
  Sfx.Play 2, 1500, 15, 15, 40, 0
End Sub

' LeaveHive: back outside, at the hive's door, facing away from it
Sub LeaveHive()
  Obj3D.Clear
  ClearSites
  ox = sx(inHive) : oz = sz(inHive) - 4
  E3.CamReset
  E3.CamPos 0, cam, 0
  E3.CamTurn 0, 25736, 0
  E3.CamTurn 0, 25736, 0
  smax = 900
  spd = 200
  Fly3D.Reset
  Fly3D.GetCam
  gmode = M_OUT : exitT = 0 : flash = 0 : spwT = 40 : hurtT = 60
  If cores >= 6 Then gmode = M_WIN
  Sfx.Play 2, 300, -3, 13, 20, 0
End Sub

' DrawRoom: walls, door panels, the floor's dots, everything
Sub DrawRoom()
  If flash > 0 Then
    E3.Begin2 fcol * 16 + 12, fcol * 16 + 8, 96
    flash = flash - 1
  Else
    E3.Begin2 14 * 16 + 3, 14 * 16 + 5, 96
  End If
  DrawDots 14 * 16 + 10, 14 * 16 + 8
  ' the walls, clockwise from inside: north, east, south, west
  SetPc 9 * 16 + 8, 9 * 16 + 6
  Wall -RW, RD, RW, RD, 0, RH : Wall RW, -RD, -RW, -RD, 0, RH
  SetPc 9 * 16 + 10, 9 * 16 + 8
  E3.VQuad RW, 0, RH, RD, -RD : E3.VQuad -RW, 0, RH, -RD, RD
  ' the doors: north (on to the next chamber), south (back)
  If inRoom < 2 Then
    If locked Then
      SetPc 2 * 16 + 8, 2 * 16 + 10
    Else
      SetPc 4 * 16 + 9, 4 * 16 + 12
    End If
    Wall -240, RD - 3, 240, RD - 3, 0, 320
  End If
  SetPc 7 * 16 + 8, 7 * 16 + 11
  Wall 240, 3 - RD, -240, 3 - RD, 0, 320
  Obj3D.Draw
End Sub

' SetPc a, b: E3.pc's colour pair: a on the even pixels, b on the odd ones
Sub SetPc(ByVal a As Integer, ByVal b As Integer)
  E3.pc = a + b * 256
End Sub

' Wall xa, za, xb, zb, y0, y1: an upright wall from (xa, za) to (xb, zb), drawn in the colours pc
Sub Wall(ByVal xa As Integer, ByVal za As Integer, ByVal xb As Integer, ByVal zb As Integer, ByVal y0 As Integer, ByVal y1 As Integer)
  E3.wq(0) = xa : E3.wq(1) = y1 : E3.wq(2) = za
  E3.wq(3) = xb : E3.wq(4) = y1 : E3.wq(5) = zb
  E3.wq(6) = xb : E3.wq(7) = y0 : E3.wq(8) = zb
  E3.wq(9) = xa : E3.wq(10) = y0 : E3.wq(11) = za
  E3.Quad3
End Sub

' ================================================================ what's common to both
' Common: the controls that aren't the driving, the timers
Sub Common()
  If hurtT > 0 Then hurtT = hurtT - dt
  If cool > 0 Then cool = cool - dt
  If ecmT > 0 Then ecmT = ecmT - dt
  If heat > 0 Then
    heat = heat - dt
    If heat < 0 Then heat = 0
  End If
  If lockd Then
    If heat < 30 Then lockd = 0
  End If
  If (keys And K_ECM) Then DoECM
  regen = regen + dt
  If regen > 80 Then
    regen = 0
    If shield < 100 Then shield = shield + 1
  End If
  If godm Then shield = 100
  If dbg Then DbgHook
  If shield <= 0 Then Died
End Sub

' Shoot: the guns: whatever's under the cross hairs, nearest first, is hit at once (a drawn beam). The
' walker's two guns (low at the sides, not drawn) fire in turn, quickly, one hit each; the tank's turret fires slower and hits for three
Sub Shoot()
  Dim dm As Integer
  If (keys And K_FIRE) = 0 Or cool > 0 Or lockd <> 0 Then Exit Sub
  If xf > 0 And xf < 30 Then Exit Sub
  If mech Then
    cool = 4 : heat = heat + 7 : dm = 1
    If gside Then bmR = 2 Else bmL = 2
    gside = 1 - gside
  Else
    cool = 7 : heat = heat + 14 : dm = 3
    bmL = 2
  End If
  Sfx.Play 0, 30, 9, 13, 6, 0
  ' a gun looks along a line raised or lowered by your eye: first the one that meets the ground 700 ahead (close
  ' things, from a tall walker), then the one for 2200 ahead
  Obj3D.pky = (100 - cam) * 128 \ 700
  s = Obj3D.Pick(Obj3D.M_ENEMY + Obj3D.M_SCENERY, 9000)
  If s < 0 Then
    Obj3D.pky = (100 - cam) * 128 \ 2200
    s = Obj3D.Pick(Obj3D.M_ENEMY + Obj3D.M_SCENERY, 9000)
  End If
  If s >= 0 Then LaserHit s, dm
  If heat >= 100 Then
    lockd = 1
    Msg "GUNS OVERHEATED", 4
  End If
End Sub

' DoECM: E.C.M.: every shot of theirs gone, everything in sight hurt
Sub DoECM()
  If ecm <= 0 Or ecmT > 0 Then Exit Sub
  ecm = ecm - 1 : ecmT = 40 : flash = 2 : fcol = 12
  Sfx.Play 2, 80, 6, 15, 30, 0
  For i = 0 To Obj3D.NOBJ - 1
    k = Obj3D.ocls(i)
    If k = Obj3D.CL_EBOLT Then
      Obj3D.Kill i
    ElseIf k = Obj3D.CL_ENEMY Then
      Obj3D.ouv(i) = Obj3D.ouv(i) - 3
      If Obj3D.ouv(i) <= 0 Then Kills i Else Spark i
    End If
  Next
End Sub

' Hurt n: shields down by n (not again for a moment)
Sub Hurt(ByVal n As Integer)
  If hurtT > 0 Then Exit Sub
  shield = shield - n : hurtT = 40 : flash = 2 : fcol = 2
  Sfx.Play 2, 300, 24, 15, 12, 0
End Sub

' Died: out of shield
Sub Died()
  lives = lives - 1
  Sfx.Play 1, 6, 1, 15, 50, 1
  If lives <= 0 Then
    gmode = M_OVER
    Exit Sub
  End If
  shield = 100 : heat = 0 : lockd = 0 : hurtT = 200
  If gmode = M_IN Then
    EnterRoom inRoom, 0
  Else
    For i = 0 To Obj3D.NOBJ - 1
      If Obj3D.ocls(i) = Obj3D.CL_ENEMY Or Obj3D.ocls(i) = Obj3D.CL_EBOLT Then Obj3D.Kill i
    Next
  End If
  Msg "SHIELDS DOWN. REPAIRED.", 4
End Sub

' ================================================================ hits
Sub Events()
  Do
    e = Obj3D.NextEvent()
    If e = 0 Then Exit Do
    i = Obj3D.ea
    If Obj3D.ocls(i) <> 0 Then
      If e = Obj3D.EV_FIRE Then
        s = Obj3D.Fire(i, 70)
        If s >= 0 Then Obj3D.otype(s) = T_EBOLT
        If Obj3D.otype(i) = T_TURRET Then Obj3D.ogun(i) = 70 + Rnd(70) Else Obj3D.ogun(i) = 90 + Rnd(90)
        Sfx.Play 0, 90, 5, 9, 8, 0
      ElseIf Obj3D.eb = 255 Then
        HitYou i
      ElseIf Obj3D.ocls(i) = Obj3D.CL_ENEMY Then
        If Obj3D.otype(Obj3D.eb) <> T_WARDEN Then Shove i, Obj3D.eb
      End If
    End If
  Loop
End Sub

' HitYou q: object q has reached you
Sub HitYou(ByVal q As Integer)
  t = Obj3D.otype(q)
  If t = T_EBOLT Then
    Obj3D.Kill q
    Hurt 8
  ElseIf t = T_GRUNT Or t = T_SCOUT Or t = T_SENTRY Or t = T_TANK Or t = T_ORB Then
    Hurt 12
    Blast q
  ElseIf t = T_HULK Then
    Hurt 20
  ElseIf t = T_WARDEN Then
    Hurt 25
  ElseIf t = T_ELECT Then
    Hurt 15
    sk(Obj3D.ouv(q)) = 99
    Blast q
  ElseIf t = T_PODP Or t = T_PODG Then
    k = Obj3D.ouv(q)
    If k >= 0 Then
      sk(k) = 99 : so(k) = -1
    End If
    Obj3D.Kill q
    pods = pods + 1 : score = score + 200
    If t = T_PODP Then
      shield = shield + 35 : If shield > 100 Then shield = 100
      Msg "PINK POD: SHIELD +35", 7
    Else
      If ecm < 9 Then ecm = ecm + 1
      jc = 200 : heat = 0 : lockd = 0
      Msg "GREEN POD: E.C.M. +1, JUMP CHARGED", 2
    End If
    Sfx.Play 0, 150, -10, 14, 20, 0
  ElseIf t = T_DOOR Then
    EnterHive Obj3D.ouv(q)
  Else
    ' something solid: back you go, slower
    E3.CamPos ox0, cam, oz0
    Fly3D.GetCam
    spd = spd \ 2
  End If
End Sub

' LaserHit q, dm: your guns have hit object q for dm
Sub LaserHit(ByVal q As Integer, ByVal dm As Integer)
  t = Obj3D.otype(q)
  If t = T_ELECT Then
    sk(Obj3D.ouv(q)) = 99
    Kills q
  ElseIf t = T_GRUNT Or t = T_HULK Or t = T_SCOUT Or t = T_SENTRY Or t = T_TURRET Or t = T_TANK Or t = T_ORB Then
    Obj3D.ouv(q) = Obj3D.ouv(q) - dm
    If Obj3D.ouv(q) <= 0 Then
      Kills q
    Else
      Spark q
      Sfx.Play 1, 12, 1, 11, 6, 1
    End If
  ElseIf t = T_CORE Then
    Obj3D.ouv(q) = Obj3D.ouv(q) - dm
    Spark q
    Sfx.Play 1, 4, 1, 14, 10, 1
    If Obj3D.ouv(q) <= 0 Then
      Blast q
      CoreDown
    End If
  ElseIf t <> T_PODP And t <> T_PODG Then
    Spark q
  End If
End Sub

' Kills q: a robot (or a mine) blown up for its points
Sub Kills(ByVal q As Integer)
  t = Obj3D.otype(q)
  If t = T_GRUNT Then
    score = score + 100
  ElseIf t = T_SCOUT Then
    score = score + 200
  ElseIf t = T_HULK Then
    score = score + 500
  ElseIf t = T_SENTRY Then
    score = score + 250
  ElseIf t = T_TURRET Then
    score = score + 150
  ElseIf t = T_TANK Or t = T_ORB Then
    score = score + 300
  ElseIf t = T_ELECT Then
    score = score + 50
  End If
  Obj3D.Pos q
  If gmode = M_OUT And t <> T_ELECT Then DropPod Obj3D.px, Obj3D.pz
  Blast q
End Sub

' Blast q: it blows up: bits flying, a fireball (and it's no longer anything that counts)
Sub Blast(ByVal q As Integer)
  Obj3D.Pos q
  Obj3D.Burst Obj3D.px, Obj3D.py, Obj3D.pz, 3, Obj3D.ovx(q), Obj3D.ovy(q), Obj3D.ovz(q)
  Obj3D.Boom q, 0
  Obj3D.ocls(q) = Obj3D.CL_DEBRIS
  Obj3D.omask(q) = 0
  Sfx.Play 1, 8, 1, 15, 22, 1
End Sub

' Spark q: a hit that didn't kill
Sub Spark(ByVal q As Integer)
  Obj3D.Pos q
  Obj3D.Burst Obj3D.px, Obj3D.py, Obj3D.pz, 1, 0, 0, 0
End Sub

' Shove q, b: robot q has walked into scenery b: put it back out of it
Sub Shove(ByVal q As Integer, ByVal b As Integer)
  Dim dx As Integer, dz As Integer, w As Integer, qy As Integer
  Obj3D.Pos q
  dx = Obj3D.px : qy = Obj3D.py : dz = Obj3D.pz
  Obj3D.Pos b
  dx = dx - Obj3D.px : dz = dz - Obj3D.pz
  w = Obj3D.ohw(b) + Obj3D.ohw(q) + 30
  If Abs(dx) >= Abs(dz) Then
    If dx < 0 Then dx = -w Else dx = w
    Obj3D.Move q, Obj3D.px + dx, qy, Obj3D.pz + dz
  Else
    If dz < 0 Then dz = -w Else dz = w
    Obj3D.Move q, Obj3D.px + dx, qy, Obj3D.pz + dz
  End If
End Sub

' ================================================================ the mech and the HUD
' Barrel bx, tx, lit, dy: the tank's turret barrel from the bottom of the view up to its muzzle, which points at the
' cross hairs (dy: how far it's sunk as you rise)
Sub Barrel(ByVal bxc As Integer, ByVal txc As Integer, ByVal lit As Integer, ByVal dy As Integer)
  E3.pvx(0) = txc - 3 : E3.pvy(0) = 118 + dy : E3.pvx(1) = txc + 3 : E3.pvy(1) = 118 + dy
  E3.pvx(2) = bxc + 10 : E3.pvy(2) = 158 + dy : E3.pvx(3) = bxc - 10 : E3.pvy(3) = 158 + dy
  E3.Poly 4, 14 * 16 + 9
  If lit > 0 Then
    E3.Box txc - 4, 114 + dy, 8, 5, 12 * 16 + 14
  Else
    E3.Box txc - 4, 115 + dy, 8, 4, 1 * 16 + 12
  End If
End Sub

' Beam tx, ty: the beam from a muzzle (at tx, ty) to the cross hairs
Sub Beam(ByVal txc As Integer, ByVal tyc As Integer)
  E3.pvx(0) = 127 : E3.pvy(0) = 97 : E3.pvx(1) = 129 : E3.pvy(1) = 97
  E3.pvx(2) = txc + 2 : E3.pvy(2) = tyc : E3.pvx(3) = txc - 2 : E3.pvy(3) = tyc
  E3.Poly 4, 12 * 16 + 14
End Sub

' DrawMech: your machine at the bottom of the view. As a tank you see its tread pods (the treads running
' with your speed) and its one turret in the middle; as a walker you're tall and see none of it: the
' tank's parts sink out of sight as you rise, and the two guns are only beams from low at the sides.
' The panel's drawn over what goes below row 158
Sub DrawMech()
  Dim j As Integer, lx As Integer, y As Integer, sn As Integer, sep As Integer, q As Integer, ty As Integer
  sep = (xf * 70) \ 30
  ty = 114 + (xf * 42) \ 30
  If bmL > 0 Then Beam 128 - sep, ty
  If bmR > 0 Then Beam 128 + sep, ty
  If xf > 15 Then
    If bmL > 0 Then E3.Box 125 - sep, ty - 2, 7, 5, 12 * 16 + 14
    If bmR > 0 Then E3.Box 125 + sep, ty - 2, 7, 5, 12 * 16 + 14
  End If
  If xf < 28 Then
    sn = xf * 2
    For j = 0 To 1
      If j = 0 Then lx = 0 Else lx = 200
      E3.Box lx, 112 + sn, 56, 56, 14 * 16 + 5
      E3.Box lx, 108 + sn, 56, 6, 1 * 16 + 10
      For q = 0 To 2
        y = 118 + sn + ((trk + q * 16) Mod 48)
        E3.Box lx + 4, y, 48, 4, 14 * 16 + 10
      Next
    Next
    Barrel 128, 128, bmL, sn
    E3.Box 98, 144 + sn, 60, 14, 1 * 16 + 8
    E3.Box 98, 144 + sn, 60, 3, 1 * 16 + 13
    E3.Box 108, 136 + sn, 40, 9, 1 * 16 + 10
  End If
  If bmL > 0 Then bmL = bmL - 1
  If bmR > 0 Then bmR = bmR - 1
End Sub

Sub HudInit()
  Hud3D.Wipe
  Hud3D.Text 4, 1, "SCORE", 1
  Hud3D.Text 164, 1, "HI", 1
  Hud3D.Text 4, 161, "SP", 1
  Hud3D.Text 4, 169, "SH", 1
  Hud3D.Text 4, 177, "LT", 1
  Hud3D.Text 4, 185, "JP", 1
  Hud3D.Text 168, 161, "CORES", 1
  Hud3D.Text 168, 169, "FORM", 1
  Hud3D.Text 168, 177, "E.C.M.", 1
  Hud3D.Text 168, 185, "LIVES", 1
  Hud3D.Cross 128, 96, 2
  sScore = -1 : sHi = -1 : sCores = -1 : sEcm = -1 : sLives = -1 : sForm = -1
  mT = 0 : mdirty = 0
End Sub

' Msg s, ink: a line of text up top for a few seconds
Sub Msg(ByVal q As String, ByVal ic As Integer)
  mstr = q : mink = ic : mT = 160 : mdirty = 1
End Sub

' HudFrame: the numbers when they change, the machine, the gauges and the scanner every picture
Sub HudFrame()
  If score > hiscore Then hiscore = score
  If score <> sScore Then Hud3D.Num 40, 1, score, 6, 2 : sScore = score
  If hiscore <> sHi Then Hud3D.Num 180, 1, hiscore, 6, 1 : sHi = hiscore
  If cores <> sCores Then Hud3D.Num 204, 161, cores, 1, 5 : Hud3D.Text 210, 161, "/6", 1 : sCores = cores
  If mech <> sForm Then
    Hud3D.Clear 169, 204, 250
    If mech Then Hud3D.Text 204, 169, "WALKER", 5 Else Hud3D.Text 204, 169, "TANK", 5
    sForm = mech
  End If
  If ecm <> sEcm Then Hud3D.Num 210, 177, ecm, 1, 2 : sEcm = ecm
  If lives <> sLives Then Hud3D.Num 204, 185, lives, 1, 2 : sLives = lives
  If mdirty Then
    Hud3D.Clear 17, 0, 255
    Hud3D.Text (256 - Len(mstr) * 6) \ 2, 17, mstr, mink
    mdirty = 0
  End If
  If mT > 0 Then
    mT = mT - dt
    If mT <= 0 Then Hud3D.Clear 17, 0, 255
  End If
  DrawMech
  E3.Box 0, 158, 256, 34, C_PANEL
  Hud3D.Bar 18, 161, 70, 6, spd, 900, C_CYAN, C_DIM - 5
  Hud3D.Bar 18, 169, 70, 6, shield, 100, C_HUD, C_DIM - 5
  If lockd Then Hud3D.Bar 18, 177, 70, 6, heat, 100, C_RED, C_DIM - 5 Else Hud3D.Bar 18, 177, 70, 6, heat, 100, C_GOLD, C_DIM - 5
  If jc >= 200 Then Hud3D.Bar 18, 185, 70, 5, 200, 200, C_GRN, C_DIM - 5 Else Hud3D.Bar 18, 185, 70, 5, jc, 200, C_PNK, C_DIM - 5
  Radar3D.Scanner 96, 160, 64, 31, C_DIM, 0, 440, 1000, 900, VarPtr(ptab)
  If gmode = M_OUT Then Compass
End Sub

' Compass: the hives still standing, as blips on the scanner's edge where they're out of its range
Sub Compass()
  Dim rx As Integer, rz As Integer, a As Integer, b As Integer
  If (frames And 8) Then Exit Sub
  For k = 0 To 5
    If hdead(k) = 0 Then
      rx = sx(k) - ox - Fly3D.cx \ 256
      rz = sz(k) - oz - Fly3D.cz \ 256
      a = (rx * (E3.cm(0) \ 256) + rz * (E3.cm(2) \ 256)) \ 128
      b = (rx * (E3.cm(6) \ 256) + rz * (E3.cm(8) \ 256)) \ 128
      If Abs(a) > 29 Or Abs(b) > 13 Then
        If Abs(a) * 13 >= Abs(b) * 29 Then
          b = b * 29 \ Abs(a)
          If a < 0 Then a = -29 Else a = 29
        Else
          a = a * 13 \ Abs(b)
          If b < 0 Then b = -13 Else b = 13
        End If
        E3.Dot 127 + a, 175 - b, 1 * 16 + 13
      End If
    End If
  Next
End Sub

' ================================================================ screens
' CText y, s, ink: a line of HUD text in the middle of the screen
Sub CText(ByVal y As Integer, ByVal q As String, ByVal ic As Integer)
  Hud3D.Text (256 - Len(q) * 6) \ 2, y, q, ic
End Sub

Sub Title()
  Obj3D.Clear
  E3.CamReset
  E3.CamPos 0, 100, 0
  Fly3D.Init
  Hud3D.Wipe
  s = Obj3D.Spawn(E3Data.K_HIVE, 3, Obj3D.CL_SCENERY, 600, 420, 5600, C_DIM)
  Obj3D.Spin s, 2, 0
  s = Obj3D.Spawn(E3Data.K_CORE, 1, Obj3D.CL_SCENERY, -900, 260, 2600, C_GOLD)
  Obj3D.Spin s, 5, 2
  s = Obj3D.Spawn(E3Data.K_GRUNT, 1, Obj3D.CL_SCENERY, 150, 100, 1500, C_BLU)
  Obj3D.Spin s, 3, 0
  CText 113, "O/P TURN  Q/A SPEED  SPACE FIRE", 5
  CText 121, "S TRANSFORM  W JUMP  E ECM", 5
  CText 137, "DESTROY THE REACTOR CORES IN SIX HIVES", 3
  CText 145, "PINK PODS: SHIELD. GREEN: ECM + JUMP", 7
  CText 169, "KEMPSTON JOYSTICK SUPPORTED", 1
  CText 185, "(C) 2026 CYBORG UNICORN PTY LTD", 1
  k = 0
  Do
    keys = ReadKeys()
    If k = 0 Then
      If (keys And K_FIRE) = 0 Then k = 1
    End If
    Obj3D.Update dt
    Sky
    Obj3D.Draw
    E3.txs = 3
    E3.Text 36, 20, "HIVEBREAKER", 12 * 16 + 14
    E3.txs = 1
    E3.Text 38, 50, "A MECH SWARM SHOOTER FOR THE NEXT", 7 * 16 + 12
    If (frames And 32) Then E3.Text 70, 100, "PRESS FIRE TO START", 6 * 16 + 14
    Sync
  Loop Until k = 1 And (keys And K_FIRE)
  Hud3D.Wipe
End Sub

Sub EndScreen()
  Dim n As Integer
  Hud3D.Wipe
  If gmode = M_WIN Then
    score = score + shield * 10 + pods * 200
    CText 57, "THE HIVE IS SILENT", 3
    CText 73, "ALL SIX CORES ARE GONE", 2
    CText 105, "BONUS: SHIELDS X10, PODS X200", 5
  Else
    CText 73, "GAME OVER", 4
  End If
  CText 89, "FINAL SCORE " & CStr(score), 2
  If score > hiscore Then
    hiscore = score
    CText 121, "NEW HIGH SCORE!", 3
  End If
  n = 0
  Do While n < 300
    DrawOutside
    Sync
    n = n + dt
  Loop
End Sub

' ================================================================ the rest
' ReadKeys(): the controls as Fly3D's bits (K_FWD faster, K_BACK slower, K_LEFT, K_RIGHT) and K_FIRE, K_ECM, K_JUMP, K_FORM
Function ReadKeys() As Integer
  Dim r As Integer, q As Integer
  q = 0
  r = Inp(&H7FFE)                          ' Space Sym M N B
  If (r And 1) = 0 Then q = q Or K_FIRE
  r = Inp(&HFBFE)                          ' Q W E R T
  If (r And 1) = 0 Then q = q Or Fly3D.K_FWD
  If (r And 2) = 0 Then q = q Or K_JUMP
  If (r And 4) = 0 Then q = q Or K_ECM
  r = Inp(&HFDFE)                          ' A S D F G
  If (r And 1) = 0 Then q = q Or Fly3D.K_BACK
  If (r And 2) = 0 Then q = q Or K_FORM
  r = Inp(&HDFFE)                          ' P O I U Y
  If (r And 1) = 0 Then q = q Or Fly3D.K_RIGHT
  If (r And 2) = 0 Then q = q Or Fly3D.K_LEFT
  r = Inp(&HBFFE)                          ' Enter L K J H
  If (r And 1) = 0 Then q = q Or K_FIRE
  r = Inp(&H1F)                            ' Kempston: right left down up fire fire2
  If r <> 255 Then
    If r And 1 Then q = q Or Fly3D.K_RIGHT
    If r And 2 Then q = q Or Fly3D.K_LEFT
    If r And 4 Then q = q Or Fly3D.K_BACK
    If r And 8 Then q = q Or Fly3D.K_FWD
    If r And 16 Then q = q Or K_FIRE
    If r And 32 Then q = q Or K_JUMP
  End If
  ReadKeys = q
End Function

' Sync: wait for the frame (3 frames a picture at most 16.7 a second), show the picture; dt: the 50ths gone
Sub Sync()
  E3.Poll
  Do While E3.vbl - vflip < 3
    E3.WaitWrap
  Loop
  Frame
  E3.Poll
  E3.Flip
  dt = E3.vbl - vflip
  vflip = E3.vbl
  If dt > 6 Then dt = 6
  frames = frames + 1
  For i = 1 To dt
    Sfx.Update
  Next
End Sub

' DbgHook: what the tests poke into dbg: 1 to hive 0, 2 into it, 3 god mode, 4 the next chamber, 6 the Warden
' now, 7 five cores gone, 8 / 11 a green / pink pod ahead, 9 a mine, 12 one of each robot ahead
Sub DbgHook()
  v = dbg : dbg = 0
  If v = 1 Or v = 8 Or v = 9 Or v = 11 Then
    k = 0
    If v = 8 Then k = 20
    If v = 9 Then k = 26
    If v = 11 Then k = 21
    ox = sx(k) : oz = sz(k) - 6
    If v = 1 Then oz = sz(k) - 10
    E3.CamReset
    E3.CamPos 0, cam, 0
    Fly3D.Reset
    Fly3D.GetCam
    ClearSites
    Obj3D.Clear
  ElseIf v = 2 Then
    EnterHive 0
  ElseIf v = 3 Then
    godm = 1
  ElseIf v = 4 Then
    If gmode = M_IN Then
      rclr(inHive * 3 + inRoom) = 1
      If inRoom < 2 Then EnterRoom inRoom + 1, 0
    End If
  ElseIf v = 6 Then
    wardT = 2300
  ElseIf v = 7 Then
    cores = 5
  ElseIf v = 12 Then
    ' one of each robot standing in a row ahead of you, looking at you
    For k = 0 To 4
      x = Fly3D.cx + (k - 2) * 380 : z = Fly3D.cz + 800
      If k = 0 Then
        s = Obj3D.Spawn(E3Data.K_GRUNT, 1, Obj3D.CL_SCENERY, x, 100, z, C_BLU)
      ElseIf k = 1 Then
        s = Obj3D.Spawn(E3Data.K_TANK, 1, Obj3D.CL_SCENERY, x, 60, z, C_BLU)
      ElseIf k = 2 Then
        s = Obj3D.Spawn(E3Data.K_ORB, 1, Obj3D.CL_SCENERY, x, 170, z, C_BLU)
      ElseIf k = 3 Then
        s = Obj3D.Spawn(E3Data.K_SCOUT, 1, Obj3D.CL_SCENERY, x, 140, z, C_BLU)
      Else
        s = Obj3D.Spawn(E3Data.K_HULK, 1, Obj3D.CL_SCENERY, x, 112, z, C_DIM)
      End If
      If s >= 0 Then Obj3D.SetMover s, Obj3D.MV_STILL, Obj3D.OF_FACECAM
    Next
  End If
End Sub
