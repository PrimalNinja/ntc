' SOLAR - a 3D vector space shooter in a small solar system, for the ZX Spectrum Next, in NTC
' BASIC (VB5 flavour)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Pirates have come to the Kestrel system: a yellow sun, four planets going round it, a ring of
' rocks. Fly your fighter among them and shoot the pirates down, wave after wave. Don't fly into
' the sun or a planet, and keep inside the system.
'
' Wireframe 3D as the CITY3D demo draws it: View.cls does the sums (camera, projection, models,
' cut at the camera - all Z80), L2.cls draws on Layer 2 with two buffers. The panels, the bars
' and the scanner are the tilemap; the sights and the scanner's blips are hardware sprites; the
' sound is the AY.
'
' Keys: Q / A pitch (nose down / up), O / P turn left / right, Z / X roll, Space fire,
'       M faster, N slower. Kempston joystick: pitch and turn, fire.
Option Explicit
Option Turbo

Const NE = 5, NB = 5, NSTAR = 12, NR = 4
Const WORLD = 8500
' colours (Layer 2: RRRGGGBB)
Const C_SUN = &HFC, C_SUN2 = &HF0, C_LASER = &HE0
Const C_STAR = &HB6

' the sun (0) and the planets (1-4): radius, orbit, angle, speed (256ths a turn x 64), colour
Dim br(4) As Integer, bo(4) As Integer, ba(4) As Integer, bsp(4) As Integer, bc(4) As Integer
Dim bx(4) As Integer, by(4) As Integer, bz(4) As Integer
' rocks: positions (fixed), their basis (all share one), kind
Dim rpos(17) As Integer, rbas(8) As Integer
' pirates: position (x, y, z) and basis (9) each
Dim epos(14) As Integer, ebas(44) As Integer
Dim eon(4) As Integer, ehp(4) As Integer, ek(4) As Integer, ecool(4) As Integer, eturn(4) As Integer, espd(4) As Integer
' stars: directions
Dim sdx(15) As Integer, sdy(15) As Integer, sdz(15) As Integer
' 2D sparks
Dim pl(31) As Integer, ppx(31) As Integer, ppy(31) As Integer, pvx(31) As Integer, pvy(31) As Integer
Dim pnext As Integer
Dim tbas(8) As Integer                  ' the title's ship
Dim speed As Integer, shield As Integer, heat As Integer, cool As Integer, firing As Integer
Dim score As Long, hiscore As Long
Dim wave As Integer, left1 As Integer, over As Integer, waveT As Integer, dead As Integer, lives As Integer
Dim frames As Integer, seed As Integer, firewas As Integer, warn As Integer, warnWas As Integer
Dim hudT As Integer, i As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
L2.Init 0
View.Init
Nx.Layers Nx.OrderSLU
Setup
hiscore = 5000
Do
  Title
  Play
  GameOver
Loop

' ---------------------------------------------------------------- the system
Sub Setup()
  Dim k As Integer
  br(0) = 900 : bo(0) = 0 : bc(0) = C_SUN
  br(1) = 220 : bo(1) = 2400 : bsp(1) = 90 : bc(1) = &H9B          ' a rock world
  br(2) = 380 : bo(2) = 4000 : bsp(2) = 60 : bc(2) = &H1F          ' an ocean world
  br(3) = 520 : bo(3) = 6000 : bsp(3) = 40 : bc(3) = &HF4          ' a ringed giant
  br(4) = 260 : bo(4) = 7600 : bsp(4) = 30 : bc(4) = &H5D          ' an ice world
  For k = 1 To 4
    ba(k) = k * 64 * 64 + 1000
  Next
  For k = 0 To 8
    rbas(k) = 0
  Next
  rbas(0) = 16384 : rbas(4) = 16384 : rbas(8) = 16384
  tbas(0) = 16384 : tbas(4) = 16384 : tbas(8) = 16384
End Sub

' the planets a step on round their orbits (the sun stays put)
Sub Orbits()
  Dim k As Integer, a As Integer
  bx(0) = 0 : by(0) = 0 : bz(0) = 0
  For k = 1 To 4
    ba(k) = ba(k) + bsp(k)
    a = (ba(k) \ 64) And 255
    bx(k) = View.FMul(bo(k), Models.Sine((a + 64) And 255))
    bz(k) = View.FMul(bo(k), Models.Sine(a))
    by(k) = bx(k) \ 8
  Next
End Sub

Sub NewStars()
  Dim k As Integer
  For k = 0 To NSTAR - 1
    sdx(k) = Rnd(16001) - 8000 : sdy(k) = Rnd(16001) - 8000 : sdz(k) = Rnd(16001) - 8000
  Next
End Sub

' the rocks: a ring between the ocean world and the giant
Sub Rocks()
  Dim k As Integer, a As Integer
  For k = 0 To NR - 1
    a = k * 64 + Rnd(30)
    rpos(k * 3) = CLng(5000) * Models.Sine((a + 64) And 255) \ 16384
    rpos(k * 3 + 1) = Rnd(600) - 300
    rpos(k * 3 + 2) = CLng(5000) * Models.Sine(a) \ 16384
  Next
End Sub

' ---------------------------------------------------------------- input
Function FirePressed() As Integer
  Dim f As Integer
  f = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyEnter) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
  FirePressed = f And Not firewas
  firewas = f
End Function

' ---------------------------------------------------------------- the panels
Sub Panels()
  Dim x As Integer, y As Integer
  Tiles.Fill GfxData.T_BLACK
  ' the scanner: cells 12-27, rows 28-31
  For y = 28 To 31
    For x = 12 To 27
      If y = 28 Then
        Tiles.Put x, y, GfxData.T_SCANT
      ElseIf y = 31 Then
        Tiles.Put x, y, GfxData.T_SCANB
      ElseIf y = 30 Then
        Tiles.Put x, y, GfxData.T_SCANC
      Else
        Tiles.Put x, y, GfxData.T_SCAN
      End If
    Next
  Next
  Tiles.Rect 11, 28, 1, 4, GfxData.T_SCANL
  Tiles.Rect 28, 28, 1, 4, GfxData.T_SCANR
  Tiles.Rect 0, 28, 11, 4, GfxData.T_PANEL
  Tiles.Rect 29, 28, 11, 4, GfxData.T_PANEL
  Tiles.Text 1, 1, "SHIELD"
  Tiles.Text 15, 1, "LASER"
  Tiles.Text 28, 1, "SPEED"
  Tiles.Text 1, 29, "SCORE"
  Tiles.Text 30, 29, "WAVE"
  Hud
End Sub

Sub Bar(ByVal x As Integer, ByVal v As Integer, ByVal t As Integer)
  Dim k As Integer, n As Integer
  n = v * 48 \ 100
  For k = 0 To 5
    If n >= 8 Then
      Tiles.Put x + k, 1, t + 8
    ElseIf n > 0 Then
      Tiles.Put x + k, 1, t + n
    Else
      Tiles.Put x + k, 1, t
    End If
    n = n - 8
  Next
End Sub

Sub Hud()
  Bar 8, shield, GfxData.T_BARG
  Bar 21, heat, GfxData.T_BARO
  Bar 34, speed, GfxData.T_BARG
  Tiles.Text 1, 30, Format$(score, "0000000")
  Tiles.Text 30, 30, Format$(wave, "00") & " " & CStr(left1) & " "
  Tiles.Text 30, 31, "SHIPS " & CStr(lives)
End Sub

Sub Message(ByVal s As String)
  Tiles.Rect 6, 3, 28, 1, GfxData.T_BLACK
  If s <> "" Then Tiles.Text 20 - Len(s) \ 2, 3, s
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
    Case "S": p = "74717"
    Case "O": p = "75557"
    Case "L": p = "44447"
    Case "A": p = "25755"
    Case "R": p = "75654"
    Case Else: p = "00000"
  End Select
  Glyph = Val(Mid$(p, r + 1, 1))
End Function

' ---------------------------------------------------------------- the title
Sub Title()
  Dim k As Integer, m As Integer
  Spr.HideRange 0, 32
  Spr.Show
  L2.Wipe
  Frame : L2.Flip
  L2.Wipe
  Nx.Layers Nx.OrderUSL                     ' the title's text over Layer 2
  Tiles.Fill GfxData.T_BLACK
  Tiles.Rect 4, 4, 32, 24, 0                ' see-through: Layer 2 shows
  BigText 10, 0, "SOLAR", 0
  Tiles.Text 3, 28, "Q A PITCH  O P TURN  Z X ROLL"
  Tiles.Text 3, 29, "SPACE FIRE  M FASTER  N SLOWER"
  Tiles.Text 3, 30, "KEMPSTON: STEER AND FIRE"
  Tiles.Text 3, 31, "HI " & Format$(hiscore, "0000000") & "    PRESS SPACE"
  View.Init
  View.SetCam 0, 0, -700
  m = 0 : frames = 0 : firewas = -1
  Do
    L2.Clear
    View.TurnB VarPtr(tbas), 0, 1, (frames \ 64) And 1
    If (frames And 127) = 0 Then m = (m + 1) Mod 4
    View.Begin
    View.Model 0, 0, 0, Models.Base() + Choose(m + 1, Models.M_KESTREL, Models.M_DART, Models.M_HORNET, Models.M_MANTIS), VarPtr(tbas)
    L2.Lines View.Count, View.Table, Choose(m + 1, &H1F, &HE0, &HFC, &HE3 - 2)
    Frame
    L2.Flip
    Sfx.Update
    frames = frames + 1 : seed = seed + 1
    Tiles.Text 12, 26, Choose(m + 1, "YOUR KESTREL   ", "DART   PIRATE  ", "HORNET PIRATE  ", "MANTIS PIRATE  ")
  Loop Until FirePressed()
  Nx.Seed seed
End Sub

' ---------------------------------------------------------------- a game
Sub Play()
  Dim k As Integer
  score = 0 : wave = 0 : over = 0 : dead = 0 : lives = 3
  StartShip
  NewStars
  Rocks
  For k = 0 To 31
    pl(k) = 0
  Next
  L2.Wipe
  Frame : L2.Flip
  L2.Wipe
  Nx.Layers Nx.OrderSLU
  Panels
  Spr.Put 0, 152, 120, GfxData.S_CROSS, 0
  waveT = 50
  For k = 0 To NE - 1
    eon(k) = 0
  Next
  left1 = 0
  Do
    L2.Clear
    Orbits
    If dead = 0 Then Steer Else Dying
    Stars
    Bodies
    RockField
    Pirates
    Sparks
    Laser
    Hazards
    Scanner
    Waves
    hudT = hudT + 1
    If (hudT And 7) = 0 Then Hud
    Frame
    L2.Flip
    Spr.Show
    Sfx.Update
    frames = frames + 1
  Loop Until over
End Sub

' the ship at the start: out past the ice world, the sun ahead to the right
Sub StartShip()
  shield = 100 : heat = 0 : speed = 20
  View.Init
  View.SetCam -5200, 400, -6200
  View.TurnB View.CamBasis(), 0, 2, 0
  View.TurnB View.CamBasis(), 0, 2, 0
  View.TurnB View.CamBasis(), 0, 2, 0
  View.TurnB View.CamBasis(), 0, 2, 0
  View.TurnB View.CamBasis(), 0, 2, 0
End Sub

Sub Steer()
  Dim p As Integer, y As Integer, r As Integer, j As Integer
  j = Keys.Joystick(0)
  If Keys.Down(Keys.KeyQ) Or (j And Keys.JoyDown) Then p = -1
  If Keys.Down(Keys.KeyA) Or (j And Keys.JoyUp) Then p = 1
  If Keys.Down(Keys.KeyO) Or (j And Keys.JoyLeft) Then y = -1
  If Keys.Down(Keys.KeyP) Or (j And Keys.JoyRight) Then y = 1
  If Keys.Down(Keys.KeyZ) Then r = -1
  If Keys.Down(Keys.KeyX) Then r = 1
  If p <> 0 Or y <> 0 Or r <> 0 Then View.TurnB View.CamBasis(), p, y, r
  If Keys.Down(Keys.KeyM) And speed < 100 Then speed = speed + 2
  If Keys.Down(Keys.KeyN) And speed > 0 Then speed = speed - 2
  View.Move View.CamPos(), View.CamBasis(), speed
  ' fire
  If cool > 0 Then cool = cool - 1
  firing = 0
  If (Keys.Down(Keys.KeySpace) Or (j And Keys.JoyFire1)) And cool = 0 And heat < 92 Then
    firing = 1 : cool = 3 : heat = heat + 7
    Sfx.Play 0, 30, 6, 12, 6, 0
  ElseIf heat > 0 Then
    heat = heat - 1
  End If
End Sub

Sub Stars()
  Dim k As Integer
  For k = 0 To NSTAR - 1
    If View.Dir(sdx(k), sdy(k), sdz(k)) Then L2.Plot View.px, View.py, C_STAR
  Next
End Sub

' the sun and the planets: a circle, and an equator and a meridian for a globe
Sub Bodies()
  Dim k As Integer, r As Integer, x As Integer, y As Integer
  For k = 0 To 4
    If View.Project(bx(k), by(k), bz(k)) Then
      If View.pz > 40 Then
        r = View.MulDiv(br(k), 128, View.pz)
        If r > 1 And r < 2000 Then
          x = View.px : y = View.py
          View.Begin
          View.Ellipse x, y, r, r
          If k = 0 Then
            View.Ellipse x, y, r * 3 \ 4, r * 3 \ 4
            L2.Lines View.Count, View.Table, C_SUN
            View.Begin
            View.Line x - r * 3 \ 2, y, x - r * 9 \ 8, y
            View.Line x + r * 3 \ 2, y, x + r * 9 \ 8, y
            View.Line x, y - r * 3 \ 2, x, y - r * 9 \ 8
            View.Line x, y + r * 3 \ 2, x, y + r * 9 \ 8
            L2.Lines View.Count, View.Table, C_SUN2
          Else
            If r > 16 Then View.Ellipse x, y, r, r \ 3
            If r > 28 Then View.Ellipse x, y, r \ 3, r
            If k = 3 Then View.Ellipse x, y, r * 7 \ 4, r \ 2
            L2.Lines View.Count, View.Table, bc(k)
          End If
        ElseIf r <= 1 Then
          L2.Plot View.px, View.py, bc(k)
        End If
      End If
    End If
  Next
End Sub

Sub RockField()
  Dim k As Integer
  View.TurnB VarPtr(rbas), 1, 0, 0
  View.Begin
  For k = 0 To NR - 1
    If View.Project(rpos(k * 3), rpos(k * 3 + 1), rpos(k * 3 + 2)) Then
      If View.pz < 3500 Then
        View.Model rpos(k * 3), rpos(k * 3 + 1), rpos(k * 3 + 2), Models.Base() + Models.M_ROCK, VarPtr(rbas)
      Else
        L2.Plot View.px, View.py, &H92
      End If
    End If
  Next
  L2.Lines View.Count, View.Table, &H92
End Sub

' ---------------------------------------------------------------- pirates
Sub Waves()
  Dim k As Integer, n As Integer
  If left1 > 0 Or dead > 0 Then Exit Sub
  waveT = waveT - 1
  If waveT = 30 Then
    wave = wave + 1
    Message "WAVE " & CStr(wave) & " - PIRATES INCOMING"
    Sfx.Play 2, 400, -12, 12, 30, 0
  End If
  If waveT > 0 Then Exit Sub
  n = wave + 1
  If n > NE Then n = NE
  For k = 0 To n - 1
    AddPirate k
  Next
  left1 = n
  waveT = 120
  If shield < 100 Then shield = shield + 25
  If shield > 100 Then shield = 100
  Message ""
End Sub

Sub AddPirate(ByVal n As Integer)
  Dim a As Integer, d As Integer, b As Integer, k As Integer
  ' somewhere 2500-4000 away from the camera, inside the system
  a = Rnd(256) : d = 2500 + Rnd(1500)
  epos(n * 3) = View.CamX() + CLng(d) * Models.Sine((a + 64) And 255) \ 16384
  epos(n * 3 + 1) = View.CamY() + Rnd(1600) - 800
  epos(n * 3 + 2) = View.CamZ() + CLng(d) * Models.Sine(a) \ 16384
  For k = 0 To 2
    If epos(n * 3 + k) > WORLD - 500 Then epos(n * 3 + k) = WORLD - 500
    If epos(n * 3 + k) < 500 - WORLD Then epos(n * 3 + k) = 500 - WORLD
  Next
  b = n * 9
  For k = 0 To 8
    ebas(b + k) = 0
  Next
  ebas(b) = 16384 : ebas(b + 4) = 16384 : ebas(b + 8) = 16384
  eon(n) = 1 : ecool(n) = 60 + Rnd(60) : eturn(n) = 0
  ek(n) = Rnd(3)
  If wave < 2 Then ek(n) = 0
  ehp(n) = 2 + ek(n) * 2
  espd(n) = 24 + ek(n) * 6 + wave * 2
  If espd(n) > 60 Then espd(n) = 60
End Sub

Sub Pirates()
  Dim n As Integer, b As Integer, p As Integer, y As Integer, d As Integer, dx As Integer, dy As Integer, dz As Integer
  Dim m As Integer, c As Integer, n3 As Integer
  For n = 0 To NE - 1
    If eon(n) Then
      n3 = n * 3
      b = VarPtr(ebas) + n * 18
      dx = View.CamX() - epos(n3) : dy = View.CamY() - epos(n3 + 1) : dz = View.CamZ() - epos(n3 + 2)
      d = Abs(dx)
      If Abs(dy) > d Then d = Abs(dy)
      If Abs(dz) > d Then d = Abs(dz)
      ' steer: towards the player, or away for a while when too close
      View.Local b, dx, dy, dz
      p = 0 : y = 0
      If ((n + frames) And 1) Then
        ' (it thinks every other frame)
      ElseIf eturn(n) > 0 Then
        eturn(n) = eturn(n) - 1
        p = 1 : y = 1
      Else
        If View.lx > View.lz \ 8 Or View.lz < 0 Then y = 1
        If View.lx < -(View.lz \ 8) Then y = -1
        If View.ly > View.lz \ 8 Then p = 1
        If View.ly < -(View.lz \ 8) Then p = -1
        If d < 350 Then eturn(n) = 40
      End If
      If p <> 0 Or y <> 0 Then View.TurnB b, p * 2, y * 2, 0
      View.Move VarPtr(epos) + n * 6, b, espd(n)
      ' fire when lined up and near
      If ecool(n) > 0 Then ecool(n) = ecool(n) - 1
      If ecool(n) = 0 And d < 2600 And View.lz > 0 And dead = 0 Then
        If Abs(View.lx) < View.lz \ 5 And Abs(View.ly) < View.lz \ 5 Then
          ecool(n) = 40 + Rnd(40) - wave * 3
          If ecool(n) < 15 Then ecool(n) = 15
          If View.Project(epos(n3), epos(n3 + 1), epos(n3 + 2)) Then
            L2.Line View.px, View.py, 128 + Rnd(40) - 20, 150, &HE7
          End If
          Sfx.Play 1, 60, 8, 12, 10, 0
          If Rnd(100) < 70 - d \ 50 Then
            shield = shield - 6 - ek(n) * 2
            Nx.PalEntry Nx.PalTiles, 0, &H60    ' the panels flash red
            If shield <= 0 Then
              shield = 0 : PlayerDies
            End If
          End If
        End If
      End If
      ' drawn: far off, a dot
      c = Choose(ek(n) + 1, &HE0, &HFC, &HE3 - 2)
      If View.Project(epos(n3), epos(n3 + 1), epos(n3 + 2)) Then
        If View.pz > 4000 Then
          L2.Plot View.px, View.py, c
        Else
          View.Begin
          m = Choose(ek(n) + 1, Models.M_DART, Models.M_HORNET, Models.M_MANTIS)
          View.Model epos(n3), epos(n3 + 1), epos(n3 + 2), Models.Base() + m, b
          L2.Lines View.Count, View.Table, c
        End If
      End If
    End If
  Next
  If (frames And 3) = 0 Then Nx.PalEntry Nx.PalTiles, 0, 0
End Sub

' the lasers: two beams to the sights, and what they hit
Sub Laser()
  Dim n As Integer, s As Integer
  If firing = 0 Then Exit Sub
  L2.Line 8, 191, 126, 98, C_LASER
  L2.Line 247, 191, 130, 98, C_LASER
  For n = 0 To NE - 1
    If eon(n) Then
      If View.Project(epos(n * 3), epos(n * 3 + 1), epos(n * 3 + 2)) Then
        If View.pz < 6000 Then
          s = View.MulDiv(100, 128, View.pz) + 4
          If Abs(View.px - 128) < s And Abs(View.py - 96) < s Then
            ehp(n) = ehp(n) - 1
            Spark View.px, View.py, &HFC, 4
            Sfx.Play 1, 4, 1, 12, 6, 1
            If ehp(n) <= 0 Then
              eon(n) = 0 : left1 = left1 - 1
              Spark View.px, View.py, &HFF, 14
              Spark View.px, View.py, &HE8, 10
              Sfx.Play 1, 24, 1, 15, 40, 1
              score = score + 100 * (ek(n) + 1) * (wave + 1) \ 2 + 50
              If score > hiscore Then hiscore = score
              Hud
            End If
            Exit For
          End If
        End If
      End If
    End If
  Next
End Sub

' too near the sun or a planet, or out of the system
Sub Hazards()
  Dim k As Integer, d As Integer, dx As Integer, dy As Integer, dz As Integer, w As Integer
  If dead Then Exit Sub
  w = 0
  For k = 0 To 4
    dx = Abs(View.CamX() - bx(k)) : dy = Abs(View.CamY() - by(k)) : dz = Abs(View.CamZ() - bz(k))
    d = dx
    If dy > d Then d = dy
    If dz > d Then d = dz
    If d < br(k) Then
      shield = 0 : PlayerDies : Exit Sub
    End If
    If k = 0 And d < 1800 Then
      w = 1
      If (frames And 3) = 0 Then shield = shield - 1
      If shield <= 0 Then
        shield = 0 : PlayerDies : Exit Sub
      End If
    End If
  Next
  If Abs(View.CamX()) > WORLD Or Abs(View.CamY()) > WORLD Or Abs(View.CamZ()) > WORLD Then
    w = 2
    ' turned back in
    View.SetCam View.CamX() * 15 \ 16, View.CamY() * 15 \ 16, View.CamZ() * 15 \ 16
  End If
  If w <> warnWas Then
    If w = 1 Then Message "TOO HOT - THE SUN"
    If w = 2 Then Message "EDGE OF THE SYSTEM"
    If w = 0 Then Message ""
    warnWas = w
  End If
End Sub

Sub PlayerDies()
  dead = 120
  Spark 128, 96, &HFF, 20
  Spark 128, 96, &HE0, 12
  Sfx.Play 1, 31, 0, 15, 90, 1
  Sfx.Play 0, 200, 10, 15, 80, 0
  Message "SHIP LOST"
  Hud
End Sub

Sub Dying()
  Dim k As Integer
  dead = dead - 1
  Nx.PalEntry Nx.PalTiles, 0, (dead And 4) * 24
  If dead = 0 Then
    lives = lives - 1
    If lives = 0 Then
      over = 1
    Else
      ' a new ship; the pirates go back a way
      StartShip
      For k = 0 To NE - 1
        If eon(k) Then AddPirate k
      Next
      Nx.PalEntry Nx.PalTiles, 0, 0
      Message ""
      Hud
    End If
  End If
End Sub

' ---------------------------------------------------------------- sparks (on the screen)
Sub Spark(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer, ByVal n As Integer)
  Dim k As Integer, a As Integer
  For k = 1 To n
    a = Rnd(256)
    pl(pnext) = 10 + Rnd(14)
    ppx(pnext) = x * 16 : ppy(pnext) = y * 16
    pvx(pnext) = Models.Sine((a + 64) And 255) * (1 + Rnd(4)) \ 512
    pvy(pnext) = Models.Sine(a) * (1 + Rnd(4)) \ 512
    pnext = (pnext + 1) And 31
  Next
End Sub

Sub Sparks()
  Dim k As Integer, x As Integer, y As Integer
  For k = 0 To 31
    If pl(k) Then
      pl(k) = pl(k) - 1
      ppx(k) = ppx(k) + pvx(k) : ppy(k) = ppy(k) + pvy(k)
      x = ppx(k) \ 16 : y = ppy(k) \ 16
      L2.Line x, y, x - pvx(k) \ 16, y - pvy(k) \ 16, Choose((k And 3) + 1, &HFF, &HFC, &HF0, &HE0)
    End If
  Next
End Sub

' ---------------------------------------------------------------- the scanner
' a blip for each pirate, planet and the sun: across = right, up the scanner = ahead
Sub Scanner()
  Dim n As Integer, s As Integer
  For n = 0 To NE - 1
    s = 10 + n
    If eon(n) Then
      Blip s, epos(n * 3), epos(n * 3 + 1), epos(n * 3 + 2), GfxData.S_BLIP, 1
    Else
      Spr.Hide s
    End If
  Next
  For n = 0 To 4
    If n = 0 Then
      Blip 20, 0, 0, 0, GfxData.S_SBLIP, 0
    Else
      Blip 20 + n, bx(n), by(n), bz(n), GfxData.S_PBLIP, 0
    End If
  Next
End Sub

Sub Blip(ByVal s As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal pat As Integer, ByVal stalk As Integer)
  Dim bx1 As Integer, by1 As Integer
  View.Local View.CamBasis(), x - View.CamX(), y - View.CamY(), z - View.CamZ()
  bx1 = View.lx \ 128 : by1 = View.lz \ 512
  If bx1 > 60 Or bx1 < -60 Or by1 > 13 Or by1 < -13 Then
    Spr.Hide s
    Exit Sub
  End If
  If stalk Then
    If View.ly > 300 Then pat = pat + 1
    If View.ly < -300 Then pat = pat + 2
  End If
  Spr.Put s, 160 + bx1 - 8, 240 - by1 - 8, pat, 0
End Sub

' ---------------------------------------------------------------- the end
Sub GameOver()
  Dim n As Integer
  Message "GAME OVER"
  Spr.HideRange 0, 32
  For n = 1 To 150
    L2.Clear
    Stars
    Bodies
    Sparks
    Frame
    L2.Flip
    Spr.Show
    Sfx.Update
    If n > 50 And FirePressed() Then Exit For
  Next
  Nx.PalEntry Nx.PalTiles, 0, 0
  Sfx.Quiet
End Sub
