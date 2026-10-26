' ROCKS - NTC3D's example game: fly through a field of drifting rocks and shoot them, a beacon
' going round, drones swaying through and the odd hunter that turns after you and shoots back.
' (c) 2026 Cyborg Unicorn Pty Ltd
' Keys: S / X dive and climb, N / M roll, Space / V faster and slower, A or Enter fire.
' All the moving, the hits and the drawing are the framework's (Obj3D, Fly3D, Hud3D, E3): this is
' only what's what and what a hit does - the whole game is BASIC.
Option Explicit
Option Turbo
Option NexData "ROCKS.DAT", 1

Const K_FIRE = 64
Const C_HUD = 13 * 16 + 13, C_DIM = 13 * 16 + 7, C_RED = 2 * 16 + 11, C_GOLD = 6 * 16 + 14
Const C_CYAN = 7 * 16 + 13
Const T_ROCK = 1, T_BEACON = 2, T_DRONE = 3, T_HUNTER = 4, T_BOLT = 5

Dim keys As Integer, dt As Integer, vflip As Integer, frames As Integer
Dim score As Integer, shown As Integer, shield As Integer, cool As Integer, stm As Integer
Dim e As Integer, i As Integer, s As Integer, k As Integer, txerr As Integer

E3.Init
E3.nstar = 32                            ' (half the stars: they cost)
Obj3D.Init
Fly3D.Init
Obj3D.BoltModel E3Data.K_BOLT, 1, 12 * 16 + 14
Obj3D.DebrisModel E3Data.K_SHARD, 2, 3 * 16 + 10, 1     ' (its bits fall a little)
Obj3D.BlastModel E3Data.K_FIREBALL, 3 * 16 + 14
Obj3D.blife = 70
Hud3D.Ink 1, C_DIM : Hud3D.Ink 2, C_HUD : Hud3D.Ink 3, C_GOLD : Hud3D.Ink 4, C_RED
Do
  NewGame
  Do
    keys = ReadKeys()
    Fly3D.Steer keys, dt
    k = Fly3D.Rebase()
    Spawner
    If cool > 0 Then cool = cool - dt
    If (keys And K_FIRE) And cool <= 0 Then
      s = Obj3D.Fire(-1, 220)
      If s >= 0 Then Obj3D.otype(s) = T_BOLT
      cool = 8
    End If
    Obj3D.Update dt
    Events
    E3.Begin 0
    E3.Stars
    Obj3D.Draw
    Hud
    Sync
  Loop While shield > 0
  GameOver
Loop

' NewGame: the field, you in the middle of it
Sub NewGame()
  Obj3D.Clear
  E3.CamReset
  E3.CamPos 0, 0, 0
  Fly3D.Init
  Fly3D.spd = 1200 : Fly3D.smax = 2600
  score = 0 : shown = -1 : shield = 100 : stm = 0
  For k = 1 To 8
    Rock
  Next
  ' the beacon: round the middle, 6000 out, 10 256ths of a turn a second
  s = Obj3D.Spawn(E3Data.K_BEACON, 3, Obj3D.CL_SCENERY, 6000, 800, 0, C_GOLD)
  Obj3D.SetMover s, Obj3D.MV_ORBIT, 0
  Obj3D.opa(s) = 0 : Obj3D.opb(s) = 0 : Obj3D.odist(s) = 6000 : Obj3D.ospd(s) = 10
  Obj3D.otype(s) = T_BEACON : Obj3D.ouv(s) = 3 : Obj3D.Spin s, 6, 0 : Obj3D.Mark s, C_GOLD
  Hud3D.Wipe
  Hud3D.Text 4, 1, "SCORE", 1
  Hud3D.Text 4, 184, "SHIELD", 1
  Hud3D.Cross 128, 96, 2
End Sub

' Rock: a rock somewhere ahead of you, drifting, turning; put back ahead when you leave it behind
Sub Rock()
  s = Obj3D.Spawn(E3Data.K_ROCKA + Rnd(2), 3, Obj3D.CL_ENEMY, Fly3D.cx + Rnd(16000) - 8000, Fly3D.cy + Rnd(8000) - 4000, Fly3D.cz + 4000 + Rnd(9000), 6)
  If s < 0 Then Exit Sub
  Obj3D.SetMover s, Obj3D.MV_STRAIGHT, Obj3D.OF_WRAP
  Obj3D.SetVel s, Rnd(31) - 15, Rnd(21) - 10, Rnd(31) - 15
  Obj3D.opa(s) = Rnd(6000) - 3000 : Obj3D.opb(s) = Rnd(4000) - 2000
  Obj3D.Spin s, Rnd(5) - 2, Rnd(3) + 1
  Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_ROCK : Obj3D.ouv(s) = 2
  Obj3D.Mark s, C_RED
End Sub

' Spawner: rocks kept up to 8, now and then a drone or a hunter
Sub Spawner()
  stm = stm - dt
  If stm > 0 Then Exit Sub
  stm = 100
  If Obj3D.Count(Obj3D.CL_ENEMY) < 10 Then Rock
  k = Rnd(3)
  If k = 0 Then
    ' a drone: swaying its way across ahead of you
    s = Obj3D.Spawn(E3Data.K_DRONE, 2, Obj3D.CL_ENEMY, Fly3D.cx - 5000, Fly3D.cy, Fly3D.cz + 7000, 4 * 16 + 10)
    If s >= 0 Then
      Obj3D.SetMover s, Obj3D.MV_WEAVE, Obj3D.OF_FACEVEL + Obj3D.OF_WRAP
      Obj3D.SetVel s, 50, 0, 0 : Obj3D.opa(s) = 30 : Obj3D.opb(s) = 20
      Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_DRONE : Obj3D.ouv(s) = 1 : Obj3D.Mark s, C_HUD
    End If
  ElseIf k = 1 Then
    ' a hunter: turns after you, shoots now and then
    s = Obj3D.Spawn(E3Data.K_HUNTER, 2, Obj3D.CL_ENEMY, Fly3D.cx + Rnd(4000) - 2000, Fly3D.cy + 2000, Fly3D.cz + 9000, 2 * 16 + 10)
    If s >= 0 Then
      Obj3D.SetMover s, Obj3D.MV_TURN, Obj3D.OF_FACECAM + Obj3D.OF_WRAP
      Obj3D.ospd(s) = 60 : Obj3D.ogun(s) = 60 : Obj3D.odist(s) = 2500   ' (it sits 2500 ahead of you)
      Obj3D.omask(s) = Obj3D.M_PLAYER : Obj3D.otype(s) = T_HUNTER : Obj3D.ouv(s) = 2 : Obj3D.Mark s, C_RED
    End If
  End If
End Sub

' Events: what Obj3D.Update found
Sub Events()
  Do
    e = Obj3D.NextEvent()
    If e = 0 Then Exit Do
    i = Obj3D.ea
    If e = Obj3D.EV_FIRE Then
      ' a hunter's gun is ready: a bolt at you, and again in a while
      s = Obj3D.Fire(i, 140)
      If s >= 0 Then Obj3D.otype(s) = T_BOLT
      Obj3D.ogun(i) = 80 + Rnd(60)
    ElseIf Obj3D.eb = 255 Then
      ' it hit you
      shield = shield - 15
      If Obj3D.otype(i) = T_BOLT Then
        Obj3D.Kill i
      Else
        Blast i
      End If
    ElseIf Obj3D.ocls(i) = Obj3D.CL_PBOLT Then
      ' your bolt hit something (still there: it may have gone up already this frame)
      s = Obj3D.eb
      If Obj3D.ocls(s) = Obj3D.CL_ENEMY Or Obj3D.ocls(s) = Obj3D.CL_SCENERY Then
        Obj3D.Kill i
        Obj3D.ouv(s) = Obj3D.ouv(s) - 1
        If Obj3D.ouv(s) <= 0 Then
          Select Case Obj3D.otype(s)
            Case T_ROCK: score = score + 10
            Case T_DRONE: score = score + 25
            Case T_HUNTER: score = score + 50
            Case T_BEACON: score = score + 100
          End Select
          Blast s
        End If
      End If
    End If
  Loop
End Sub

' Blast i: it blows up - bits flying, a fireball
Sub Blast(ByVal i As Integer)
  Obj3D.Pos i
  Obj3D.Burst Obj3D.px, Obj3D.py, Obj3D.pz, 4, Obj3D.ovx(i), Obj3D.ovy(i), Obj3D.ovz(i)
  Obj3D.Boom i, 3
End Sub

' Hud: the score (on the ULA, when it changes), the shield bar, the scanner
Sub Hud()
  If score <> shown Then
    Hud3D.Num 40, 1, score, 5, 2
    shown = score
  End If
  Hud3D.Bar 44, 182, 62, 8, shield, 100, C_HUD, C_DIM - 5
  Hud3D.Scanner 109, 165, 38, 26, C_DIM - 3, 0
End Sub

' GameOver: the shield's gone - a word, then again
Sub GameOver()
  Dim t As Integer
  Hud3D.Text 101, 92, "GAME OVER", 4
  t = 0
  Do While t < 150
    E3.Begin 0
    E3.Stars
    Obj3D.Update dt
    Obj3D.Draw
    Sync
    t = t + dt
  Loop
End Sub

' ReadKeys(): the controls as Fly3D's bits, K_FIRE for fire
Function ReadKeys() As Integer
  Dim r As Integer
  k = 0
  r = Inp(&HFDFE)                          ' A S D F G
  If (r And 1) = 0 Then k = k Or K_FIRE
  If (r And 2) = 0 Then k = k Or Fly3D.K_DIVE
  r = Inp(&HFEFE)                          ' Caps Z X C V
  If (r And 4) = 0 Then k = k Or Fly3D.K_CLIMB
  If (r And 16) = 0 Then k = k Or Fly3D.K_SLOWER
  r = Inp(&H7FFE)                          ' Space Sym M N B
  If (r And 1) = 0 Then k = k Or Fly3D.K_FASTER
  If (r And 4) = 0 Then k = k Or Fly3D.K_ROLLR
  If (r And 8) = 0 Then k = k Or Fly3D.K_ROLLL
  r = Inp(&HBFFE)                          ' Enter L K J H
  If (r And 1) = 0 Then k = k Or K_FIRE
  ReadKeys = k
End Function

' Sync: wait for the frame (3 frames a picture at most 16.7 a second), show the picture; dt: the
' 50ths gone
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
End Sub
