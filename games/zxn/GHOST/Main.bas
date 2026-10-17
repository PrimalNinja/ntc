' THE GHOST - Ghost Saga, Act 1: "We begin". A submarine game for the ZX Spectrum Next in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Mr Bad stole the Ghost Sub and took a new name: The Ghost. You are him. The Ten are your crew -
' and your lives: each hit on the hull loses one. A Russian and an American patrol are hunting the
' boat they lost. Sink the patrol, then take the Ghost Sub to the wreck: the signal is there.
'
' Keys: O P turn, Q A throttle up / down, K M rise / dive, Space torpedo, S sonar ping.
'       Kempston: left / right turn, up / down rise / dive, fire torpedo.
' Running fast is loud - they hear you further off. A ping shows them all on the radar for a
' while, and tells them all where you are.
'
' The sea floor is blocks drawn by Vox (filled faces on Layer 2, near to far, murk beyond 12
' blocks); the subs, torpedoes, fish and blasts are hardware sprites; the panel and the chessboard
' radar are the tilemap; the sound is the AY.
Option Explicit
Option Turbo

Const NE = 3, NT = 5, NF = 4, NB = 3
' sprite slots
Const SP_SIGHT = 0, SP_SUB = 1, SP_TORP = 4, SP_FISH = 9, SP_BLAST = 13, SP_RME = 20, SP_RSUB = 21, SP_RTORP = 24, SP_RGOAL = 29
' the view on screen (sprite coordinates) and the radar
Const VX0 = 32, VY0 = 48, RX0 = 224, RY0 = 48

Dim longText As String Max 120
' the Ghost Sub
Dim px As Integer, py As Integer, pz As Integer, yaw As Integer, pitch As Integer, thr As Integer
Dim crew As Integer, torps As Integer, reload As Integer, cool As Integer, pingT As Integer, pingCool As Integer
Dim noise As Integer, sunk As Integer, phase As Integer, layer As Integer, hitFlash As Integer
' the patrol: position, heading, life, state (0 sunk, 1 patrol, 2 hunting), cool-down, side (0 Russian, 1 American)
Dim ex(2) As Integer, ey(2) As Integer, ez(2) As Integer, eyaw(2) As Integer, est(2) As Integer, ecool(2) As Integer, eside(2) As Integer, eturn(2) As Integer
' torpedoes: position, velocity, life (0 = none), whose (0 the Ghost, 1 the patrol)
Dim tx(4) As Integer, ty(4) As Integer, tz(4) As Integer, tvx(4) As Integer, tvy(4) As Integer, tvz(4) As Integer, tlife(4) As Integer, town(4) As Integer
' fish
Dim fx(3) As Integer, fy(3) As Integer, fz(3) As Integer, fvx(3) As Integer, fvz(3) As Integer
' blasts
Dim bx(2) As Integer, by(2) As Integer, bz(2) As Integer, bt(2) As Integer
Dim t As Integer, tLast As Integer, dt As Integer, frames As Integer, fireWas As Integer, pingWas As Integer, thrWas As Integer
Dim i As Integer, j As Integer, k As Integer, d As Integer, s As Integer, c As Integer, a As Integer, msgT As Integer
Dim heardOnce As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Vox.Screen &HE3                    ' Layer 2 see-through except the view (the panels are the tilemap)
Vox.Load World.Base()
Vox.Colours World.Colours()
Vox.Build

Do
  Title
  NewGame
  Play
Loop

' ---------------------------------------------------------------- the title: the Ghost Shell
Sub Title()
  Dim y As Integer
  Spr.HideRange 0, 32 : Spr.Show
  Tiles.Fill GfxData.T_PANEL
  Tiles.Text 6, 5, "CYBORGSHELL V1.0."
  Tiles.Text 6, 6, "BY PRIMALNINJA."
  Tiles.Text 6, 7, "LOCAL STORAGE IS AVAILABLE."
  Tiles.Text 6, 8, "YOU ARE LOGGED IN."
  Tiles.Text 6, 9, "READY."
  Tiles.Text 6, 11, "LOAD " & Chr$(34) & "THE GHOST" & Chr$(34)
  Tiles.Text 6, 12, "RUN"
  Tiles.Text 6, 14, "GHOST SAGA - ACT 1: WE BEGIN"
  Tiles.Text 6, 16, "FIRST, OPEN THE DOOR"
  Tiles.Text 6, 17, "SECOND, WATCH THE ROAD"
  Tiles.Text 6, 18, "THIRD, ERASE THE TRACE"
  Tiles.Text 6, 19, "...TENTH, MOVE."
  Tiles.Text 6, 21, "TEN FOR THE GHOST."
  Tiles.Text 6, 24, "O P TURN   Q A THROTTLE"
  Tiles.Text 6, 25, "K M RISE / DIVE"
  Tiles.Text 6, 26, "SPACE TORPEDO   S SONAR PING"
  Tiles.Text 6, 28, "PRESS SPACE TO DIVE"
  ' (Layer 2's view off while the title is up: see-through everywhere)
  Do
    Frame
    Sfx.Update
  Loop While Keys.Down(Keys.KeySpace)
  y = 0
  Do
    Frame
    y = y + 1
    If y = 25 Then Tiles.Text 6, 28, "                   "
    If y = 50 Then Tiles.Text 6, 28, "PRESS SPACE TO DIVE" : y = 0
  Loop Until Keys.Down(Keys.KeySpace) Or (Keys.Joystick(0) And Keys.JoyFire1)
  Sfx.Play 0, 60, 2, 15, 30, 0
End Sub

' ---------------------------------------------------------------- a new game
Sub NewGame()
  px = 2 * 256 + 128 : py = 6 * 256 + 128 : pz = 1 * 256 + 128 : yaw = 16 : pitch = -4 : thr = 1
  crew = 10 : torps = 6 : reload = 0 : cool = 0 : pingT = 0 : pingCool = 0 : sunk = 0 : phase = 0
  layer = -1 : hitFlash = 0 : heardOnce = 0 : msgT = 0 : fireWas = 1 : pingWas = 1 : thrWas = 1
  SetSub 0, 3 * 256 + 128, 6 * 256 + 128, 13 * 256 + 128, 64, 0
  SetSub 1, 13 * 256 + 128, 8 * 256 + 128, 13 * 256 + 128, 192, 1
  SetSub 2, 12 * 256 + 128, 13 * 256 + 128, 8 * 256 + 128, 128, 0
  For i = 0 To NT - 1
    tlife(i) = 0
  Next
  For i = 0 To NB - 1
    bt(i) = 0
  Next
  For i = 0 To NF - 1
    fx(i) = (2 + i * 4) * 256 + 77 : fy(i) = (4 + i) * 256 : fz(i) = (4 + (i * 5) Mod 9) * 256 : fvx(i) = 3 - i * 2 : fvz(i) = 2 + i
  Next
  Panel
End Sub

Sub SetSub(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal h As Integer, ByVal side As Integer)
  ex(n) = x : ey(n) = y : ez(n) = z : eyaw(n) = h : est(n) = 1 : ecool(n) = 100 + n * 50 : eside(n) = side : eturn(n) = 1
End Sub

' ---------------------------------------------------------------- the panel round the view
Sub Panel()
  Tiles.Fill GfxData.T_PANEL
  Tiles.Rect 4, 6, 24, 20, GfxData.T_BLACK          ' under the view (Layer 2 covers it)
  Tiles.Text 4, 4, "THE GHOST  ACT 1: WE BEGIN"
  Tiles.Text 28, 14, "DEPTH"
  Tiles.Text 28, 16, "SPEED"
  Tiles.Text 28, 18, "NOISE"
  Tiles.Text 28, 20, "TORPS"
  Tiles.Text 28, 22, "THE TEN"
  ShowSunk
  ShowCrew
  ShowTorps
  Say "SIGNAL LOCKED. DIVE, DIVE, DIVE!"
End Sub

Sub ShowSunk()
  Tiles.Text 28, 5, "SUNK " & Trim$(Str$(sunk)) & "/3"
End Sub

Sub ShowCrew()
  Dim n As Integer
  For n = 0 To 9
    If n < crew Then Tiles.Put 28 + (n Mod 5), 23 + n \ 5, GfxData.T_CREW Else Tiles.Put 28 + (n Mod 5), 23 + n \ 5, GfxData.T_CREWX
  Next
End Sub

Sub ShowTorps()
  Dim n As Integer
  For n = 0 To 5
    If n < torps Then Tiles.Put 28 + n, 21, GfxData.T_TORP Else Tiles.Put 28 + n, 21, GfxData.T_TUBE
  Next
End Sub

' a bar of v (0-64) at x, y over 8 cells
Sub Bar(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer)
  Dim n As Integer, f As Integer
  For n = 0 To 7
    f = v - n * 8
    If f < 0 Then f = 0
    If f > 8 Then f = 8
    Tiles.Put x + n, y, GfxData.T_BAR + f
  Next
End Sub

' a line of text at the bottom
Sub Say(ByVal m As String)
  longText = m
  Tiles.Rect 4, 26, 32, 2, GfxData.T_PANEL
  Tiles.Text 4, 26, Left$(longText, 32)
  If Len(longText) > 32 Then Tiles.Text 4, 27, Mid$(longText, 33, 32)
  msgT = 400
End Sub

' the chessboard: 8 x 8 squares of 2 x 2 blocks at the Ghost's depth (rock shown)
Sub Radar()
  Dim sx As Integer, sz As Integer, rock As Integer
  For sz = 0 To 7
    For sx = 0 To 7
      rock = Vox.GetBlock(sx * 2, layer, sz * 2) Or Vox.GetBlock(sx * 2 + 1, layer, sz * 2) Or Vox.GetBlock(sx * 2, layer, sz * 2 + 1) Or Vox.GetBlock(sx * 2 + 1, layer, sz * 2 + 1)
      If (sx + sz) And 1 Then
        If rock Then Tiles.Put 28 + sx, 13 - sz, GfxData.T_ROCKD Else Tiles.Put 28 + sx, 13 - sz, GfxData.T_SQD
      Else
        If rock Then Tiles.Put 28 + sx, 13 - sz, GfxData.T_ROCKL Else Tiles.Put 28 + sx, 13 - sz, GfxData.T_SQL
      End If
    Next
  Next
End Sub

' ---------------------------------------------------------------- the game
Sub Play()
  tLast = Vox.Ticks()
  Do
    t = Vox.Ticks()
    dt = t - tLast
    tLast = t
    If dt < 1 Then dt = 1
    If dt > 6 Then dt = 6
    Controls
    MoveGhost
    MovePatrol
    MoveTorps
    MoveFish
    For i = 0 To NB - 1
      If bt(i) > 0 Then bt(i) = bt(i) - dt
    Next
    If layer <> py \ 256 Then layer = py \ 256 : Radar
    Vox.Render px, py + 64, pz, yaw, pitch, Vox.Page()
    Sprites
    Hud
    Frame : Vox.Flip
    frames = frames + 1
    For i = 1 To dt
      Sfx.Update
    Next
    If crew <= 0 Then
      Say "THE TEN ARE GONE. THE GHOST IS ALONE."
      Ending
      Exit Sub
    End If
    If phase = 1 Then
      d = Abs(px - (12 * 256 + 128)) + Abs(py - 4 * 256) + Abs(pz - 11 * 256)
      If d < 500 Then
        Say "WE BEGIN. THE GHOST IS CALLING."
        Ending
        Exit Sub
      End If
    End If
  Loop
End Sub

Sub Ending()
  Dim n As Integer
  Sfx.Play 1, 40, 1, 15, 60, 0
  For n = 1 To 200
    Frame
    Sfx.Update
  Next
End Sub

Sub Controls()
  Dim j0 As Integer, fire As Integer, ping As Integer, up As Integer, down As Integer
  j0 = Keys.Joystick(0)
  If Keys.Down(Keys.KeyO) Or (j0 And Keys.JoyLeft) Then yaw = (yaw - 2 * dt) And 255
  If Keys.Down(Keys.KeyP) Or (j0 And Keys.JoyRight) Then yaw = (yaw + 2 * dt) And 255
  ' throttle: one step a press
  up = Keys.Down(Keys.KeyQ) : down = Keys.Down(Keys.KeyA)
  If up And thrWas = 0 And thr < 3 Then thr = thr + 1
  If down And thrWas = 0 And thr > 0 Then thr = thr - 1
  thrWas = up Or down
  pitch = -4
  If Keys.Down(Keys.KeyK) Or (j0 And Keys.JoyUp) Then MoveTo px, py + 8 * dt, pz : pitch = 6
  If Keys.Down(Keys.KeyM) Or (j0 And Keys.JoyDown) Then MoveTo px, py - 8 * dt, pz : pitch = -14
  fire = Keys.Down(Keys.KeySpace) Or (j0 And Keys.JoyFire1)
  If fire And fireWas = 0 And cool <= 0 And torps > 0 Then Shoot
  fireWas = fire
  ping = Keys.Down(Keys.KeyS)
  If ping And pingWas = 0 And pingCool <= 0 Then
    pingT = 400 : pingCool = 600
    Sfx.Play 2, 30, 0, 15, 40, 0
    Say "SONAR PING... PING..."
    For i = 0 To NE - 1
      If est(i) = 1 Then est(i) = 2
    Next
  End If
  pingWas = ping
End Sub

' the Ghost Sub moves to x, y, z unless a block is in the way
Sub MoveTo(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer)
  If x < 96 Or x > 4000 Or z < 96 Or z > 4000 Or y < 96 Or y > 3900 Then Exit Sub
  If Vox.Solid(x, y, z) Then Exit Sub
  If Vox.Solid(x, y + 96, z) Then Exit Sub
  px = x : py = y : pz = z
End Sub

Sub MoveGhost()
  s = thr * 5 * dt
  If s Then MoveTo px + Vox.Sine(yaw) * s \ 127, py, pz + Vox.Sine(yaw + 64) * s \ 127
  noise = thr * 16 + 8
  If cool > 0 Then cool = cool - dt
  If pingT > 0 Then pingT = pingT - dt
  If pingCool > 0 Then pingCool = pingCool - dt
  If hitFlash > 0 Then hitFlash = hitFlash - dt
  If msgT > 0 Then
    msgT = msgT - dt
    If msgT <= 0 Then Tiles.Rect 4, 26, 32, 2, GfxData.T_PANEL
  End If
  If torps < 6 Then
    reload = reload + dt
    If reload > 250 Then reload = 0 : torps = torps + 1 : ShowTorps
  End If
End Sub

Sub Shoot()
  For k = 0 To NT - 1
    If tlife(k) <= 0 Then
      tx(k) = px : ty(k) = py : tz(k) = pz
      tvx(k) = Vox.Sine(yaw) * 36 \ 127 : tvy(k) = 0 : tvz(k) = Vox.Sine(yaw + 64) * 36 \ 127
      tlife(k) = 160 : town(k) = 0
      torps = torps - 1 : cool = 30 : ShowTorps
      Sfx.Play 1, 0, 0, 13, 20, 1
      Exit Sub
    End If
  Next
End Sub

' ---------------------------------------------------------------- the patrol
Sub MovePatrol()
  Dim n As Integer, dx As Integer, dy As Integer, dz As Integer, hear As Integer, sp As Integer, fwx As Integer, fwz As Integer, cr As Integer, dot As Integer
  For n = 0 To NE - 1
    If est(n) Then
      dx = px - ex(n) : dy = py - ey(n) : dz = pz - ez(n)
      d = Abs(dx) + Abs(dy) + Abs(dz)
      hear = 700 + noise * 30
      If pingT > 0 Then hear = 3000
      If d < hear And est(n) = 1 Then
        est(n) = 2
        If heardOnce = 0 Then heardOnce = 1 : Say "SONAR PING... TARGET: YOU." : Sfx.Play 2, 40, 0, 12, 30, 0
      End If
      If est(n) = 2 And d > hear + 2000 Then est(n) = 1
      fwx = Vox.Sine(eyaw(n)) : fwz = Vox.Sine(eyaw(n) + 64)
      sp = 3
      If est(n) = 2 Then
        sp = 5
        ' turn towards the Ghost (the cross product's sign), rise or dive to his depth
        cr = fwx * (dz \ 32) - fwz * (dx \ 32)
        If cr > 0 Then eyaw(n) = (eyaw(n) - dt) And 255 Else eyaw(n) = (eyaw(n) + dt) And 255
        If dy > 64 And Vox.Solid(ex(n), ey(n) + 200, ez(n)) = 0 Then ey(n) = ey(n) + 3 * dt
        If dy < -64 And Vox.Solid(ex(n), ey(n) - 200, ez(n)) = 0 Then ey(n) = ey(n) - 3 * dt
        ' fire when facing him, near, and in sight
        dot = fwx * (dx \ 32) + fwz * (dz \ 32)
        If ecool(n) > 0 Then ecool(n) = ecool(n) - dt
        If ecool(n) <= 0 And d < 2600 And dot > 0 Then
          If Vox.Sight(ex(n), ey(n), ez(n), px, py, pz) Then EnemyShot n, dx, dy, dz, d : ecool(n) = 220
        End If
      End If
      ' ahead blocked (or the map's edge): turn away
      If Vox.Solid(ex(n) + fwx * 3, ey(n), ez(n) + fwz * 3) Then
        ' hunting: over the top if there's water above, else turn away
        If est(n) = 2 And ey(n) < 3700 And Vox.Solid(ex(n), ey(n) + 300, ez(n)) = 0 Then
          ey(n) = ey(n) + 8 * dt
        Else
          eyaw(n) = (eyaw(n) + 48 * eturn(n)) And 255
          If (t And 7) = 0 Then eturn(n) = -eturn(n)
        End If
      Else
        ex(n) = ex(n) + fwx * sp * dt \ 127 : ez(n) = ez(n) + fwz * sp * dt \ 127
      End If
    End If
  Next
End Sub

Sub EnemyShot(ByVal n As Integer, ByVal dx As Integer, ByVal dy As Integer, ByVal dz As Integer, ByVal dd As Integer)
  Dim m As Integer
  For m = 0 To NT - 1
    If tlife(m) <= 0 Then
      dd = dd \ 16 + 1
      tx(m) = ex(n) : ty(m) = ey(n) : tz(m) = ez(n)
      tvx(m) = (dx \ 16) * 30 \ dd : tvy(m) = (dy \ 16) * 30 \ dd : tvz(m) = (dz \ 16) * 30 \ dd
      tlife(m) = 200 : town(m) = 1
      Sfx.Play 1, 0, 0, 10, 20, 1
      Exit Sub
    End If
  Next
End Sub

' ---------------------------------------------------------------- torpedoes, blasts, fish
Sub MoveTorps()
  Dim n As Integer, m As Integer
  For n = 0 To NT - 1
    If tlife(n) > 0 Then
      tx(n) = tx(n) + tvx(n) * dt : ty(n) = ty(n) + tvy(n) * dt : tz(n) = tz(n) + tvz(n) * dt
      tlife(n) = tlife(n) - dt
      If Vox.Solid(tx(n), ty(n), tz(n)) Then
        Blast tx(n), ty(n), tz(n) : tlife(n) = 0
      ElseIf town(n) = 0 Then
        For m = 0 To NE - 1
          If est(m) Then
            If Abs(tx(n) - ex(m)) + Abs(ty(n) - ey(m)) + Abs(tz(n) - ez(m)) < 260 Then
              Blast ex(m), ey(m), ez(m) : tlife(n) = 0 : est(m) = 0
              sunk = sunk + 1 : ShowSunk
              If sunk = 3 Then
                phase = 1
                Say "TEN FOR THE GHOST! THE PATROL IS DOWN. TO THE WRECK."
              Else
                Say "TARGET DOWN."
              End If
            End If
          End If
        Next
      ElseIf Abs(tx(n) - px) + Abs(ty(n) - py) + Abs(tz(n) - pz) < 240 Then
        Blast tx(n), ty(n), tz(n) : tlife(n) = 0
        crew = crew - 1 : ShowCrew : hitFlash = 30
        Say "HULL HIT! ONE OF THE TEN IS DOWN."
      End If
    End If
  Next
End Sub

Sub Blast(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer)
  Dim n As Integer
  For n = 0 To NB - 1
    If bt(n) <= 0 Then
      bx(n) = x : by(n) = y : bz(n) = z : bt(n) = 30
      Sfx.Play 0, 20, 1, 15, 40, 1
      Exit Sub
    End If
  Next
End Sub

Sub MoveFish()
  Dim n As Integer
  For n = 0 To NF - 1
    If Vox.Solid(fx(n) + fvx(n) * 20, fy(n), fz(n) + fvz(n) * 20) Then
      fvx(n) = -fvx(n) : fvz(n) = -fvz(n)
    Else
      fx(n) = fx(n) + fvx(n) * dt : fz(n) = fz(n) + fvz(n) * dt
    End If
  Next
End Sub

' ---------------------------------------------------------------- the sprites
' an object at x, y, z as sprite slot n: in the view if it's ahead, near enough, and nothing is
' in the way; the further, the smaller (8x, 4x, 2x, 1x for size 1 of a block)
Sub Show3D(ByVal n As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal pat As Integer, ByVal flags As Integer, ByVal big As Integer)
  Dim zz As Integer, sc As Integer, half As Integer, qx As Integer, qy As Integer
  If Vox.Project(x, y, z) = 0 Then Spr.Hide n : Exit Sub
  zz = Vox.SZ()
  qx = Vox.SX() : qy = Vox.SY()
  If zz > 3000 Or qx < 0 Or qx > 95 Or qy < 0 Or qy > 79 Then Spr.Hide n : Exit Sub
  If Vox.Sight(px, py + 64, pz, x, y, z) = 0 Then Spr.Hide n : Exit Sub
  zz = zz \ big
  If zz < 500 Then
    half = 32
  ElseIf zz < 1000 Then
    half = 16
  Else
    half = 8
  End If
  ' kept inside the view: smaller if it would stick out, gone if it still does
  Do While half > 8 And (qx * 2 < half Or qx * 2 + half > 192 Or qy * 2 < half Or qy * 2 + half > 160)
    half = half \ 2
  Loop
  If qx * 2 < half Or qx * 2 + half > 192 Or qy * 2 < half Or qy * 2 + half > 160 Then Spr.Hide n : Exit Sub
  If half = 32 Then
    sc = Spr.Scale4
  ElseIf half = 16 Then
    sc = Spr.Scale2
  Else
    sc = 0
  End If
  Spr.Put n, VX0 + qx * 2 - half, VY0 + qy * 2 - half, pat, flags Or sc
End Sub

Sub Sprites()
  Dim n As Integer, rel As Integer, pat As Integer, fl As Integer, vis As Integer
  Spr.Put SP_SIGHT, VX0 + 96 - 8, VY0 + 80 - 8, GfxData.S_SIGHT, 0
  For n = 0 To NE - 1
    If est(n) Then
      rel = (eyaw(n) - yaw) And 255
      pat = GfxData.S_RSUB + eside(n) * 2 : fl = 0
      If rel < 24 Or rel > 232 Or (rel > 104 And rel < 152) Then
        pat = pat + 1
      ElseIf rel < 128 Then
        fl = Spr.MirrorX
      End If
      Show3D SP_SUB + n, ex(n), ey(n), ez(n), pat, fl, 1
      ' on the radar: when pinged, near, or hunting close
      d = Abs(px - ex(n)) + Abs(py - ey(n)) + Abs(pz - ez(n))
      vis = pingT > 0 Or d < 1400
      If vis Then Spr.Put SP_RSUB + n, RX0 + ex(n) \ 64 - 8, RY0 + 63 - ez(n) \ 64 - 8, GfxData.S_RDOT + eside(n), 0 Else Spr.Hide SP_RSUB + n
    Else
      Spr.Hide SP_SUB + n : Spr.Hide SP_RSUB + n
    End If
  Next
  For n = 0 To NT - 1
    If tlife(n) > 0 Then
      If town(n) Then pat = GfxData.S_TORP + 1 Else pat = GfxData.S_TORP
      Show3D SP_TORP + n, tx(n), ty(n), tz(n), pat, 0, 3
      Spr.Put SP_RTORP + n, RX0 + tx(n) \ 64 - 8, RY0 + 63 - tz(n) \ 64 - 8, GfxData.S_TDOT, 0
    Else
      Spr.Hide SP_TORP + n : Spr.Hide SP_RTORP + n
    End If
  Next
  For n = 0 To NF - 1
    Show3D SP_FISH + n, fx(n), fy(n), fz(n), GfxData.S_FISH + ((t \ 8 + n) And 1), 0, 1
  Next
  For n = 0 To NB - 1
    If bt(n) > 0 Then
      Show3D SP_BLAST + n, bx(n), by(n), bz(n), GfxData.S_BLAST + 2 - bt(n) \ 11, 0, 1
    Else
      Spr.Hide SP_BLAST + n
    End If
  Next
  Spr.Put SP_RME, RX0 + px \ 64 - 8, RY0 + 63 - pz \ 64 - 8, GfxData.S_ME, 0
  If phase = 1 And (t And 16) Then
    Spr.Put SP_RGOAL, RX0 + 12 * 4 + 2 - 8, RY0 + 63 - 11 * 4 - 8, GfxData.S_GOAL, 0
  Else
    Spr.Hide SP_RGOAL
  End If
  Spr.Show
End Sub

' depth, speed, noise; the panels go red for a moment when the hull is hit
Sub Hud()
  Tiles.Text 28, 15, Trim$(Str$((4096 - py) \ 26)) & "M  "
  Bar 28, 17, thr * 21
  Bar 28, 19, noise
  If hitFlash > 0 Then
    Nx.PalEntry Nx.PalTiles, 6, &HE0
  Else
    Nx.PalEntry Nx.PalTiles, 6, &H01
  End If
End Sub
