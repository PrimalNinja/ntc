' SOL UNICORN - a 3D vector space shooter for the ZX Spectrum Next, in NTC BASIC (VB5 flavour)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The Space Cyborg Unicorns have taken the solar system. Start at Pluto and fight your way in to
' the Sun, one planet a level, warping between them. At each planet: beat its fighters, then
' take out the moon they have made into a death moon - fly its surface, blast its towers and
' its core - then face the Space Cyborg Unicorn that comes out of the wreck. Every planet has
' its real moons (Venus and Mercury have none: there the unicorns built a station). At the Sun,
' three unicorns at once.
'
' 3D wireframe as SOLAR (View.cls: the sums in Z80 with the Next's hardware multiplier; L2.cls:
' Layer 2, two buffers). The panels are the tilemap, the sights a hardware sprite, the sound the AY.
'
' Keys: Q A O P move the sights (the ship turns towards them), Space fire.
'       Kempston joystick: the sights, fire.
Option Explicit
Option Turbo

Const NF = 5, NB = 8, NT = 4, NSTAR = 14
Const LEVELS = 10
' phases of a level
Const PH_WARP = 0, PH_SPACE = 1, PH_APPROACH = 2, PH_SURFACE = 3, PH_CORE = 4, PH_BLAST = 5, PH_BOSS = 6, PH_CLEAR = 7
' colours (Layer 2)
Const C_FIGHTER = &HE0, C_BOLT = &HFC, C_LASER = &H1F, C_TOWER = &H9C, C_GRID = &H0E, C_CORE = &HF0, C_UNI = &HF3, C_HORN = &HFC

Dim longText As String Max 60
' the level: the planet and its moons (the planet's place: ahead, 4500 off)
Dim pname As String, prad As Integer, pcol As Integer, pring As Integer
Dim nm As Integer, mname(5) As String * 8, mrad(5) As Integer, mx(5) As Integer, my(5) As Integer, mz(5) As Integer
Dim dmoon As Integer
' fighters: position, velocity, life
Dim fpos(14) As Integer, fvx(4) As Integer, fvy(4) As Integer, fvz(4) As Integer, fon(4) As Integer, fcool(4) As Integer
' bolts (enemy shots coming at you): position, velocity
Dim bpos(23) As Integer, bvx(7) As Integer, bvy(7) As Integer, bvz(7) As Integer, bon(7) As Integer
' towers on the moon (x, z: the ground is y = -150)
Dim tx(3) As Integer, tz(3) As Integer, ton(3) As Integer, tcool(3) As Integer
' unicorns: where they circle, their turn, life
Dim ux(2) As Integer, uy(2) As Integer, uz(2) As Integer, ua(2) As Integer, uhp(2) As Integer, uon(2) As Integer, ucool(2) As Integer, uhit(2) As Integer
Dim uposx(2) As Integer, uposy(2) As Integer, uposz(2) As Integer
Dim fbas(8) As Integer, tbas(8) As Integer, ibas(8) As Integer
' stars, sparks
Dim sdx(13) As Integer, sdy(13) As Integer, sdz(13) As Integer
Dim pl(31) As Integer, ppx(31) As Integer, ppy(31) As Integer, pvx(31) As Integer, pvy(31) As Integer
Dim pnext As Integer
Dim wa(23) As Integer, wr(23) As Integer
' the player
Dim cx As Integer, cy As Integer, shield As Integer, ships As Integer, cool As Integer, firing As Integer
Dim score As Long, hiscore As Long
Dim level As Integer, phase As Integer, pt As Integer, kills As Integer, need As Integer, towersLeft As Integer
Dim coreZ As Integer, coreHp As Integer, scroll As Integer, nboss As Integer, bossMax As Integer
Dim over As Integer, won As Integer, dead As Integer, frames As Integer, seed As Integer, firewas As Integer, hudT As Integer
Dim i As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
L2.Init 0
View.Init
ibas(0) = 16384 : ibas(4) = 16384 : ibas(8) = 16384
hiscore = 20000
Do
  Title
  Play
  GameOver
Loop

' ---------------------------------------------------------------- the levels
Sub LevelData(ByVal lv As Integer)
  nm = 0 : pring = 0 : dmoon = 0
  Select Case lv
    Case 0
      pname = "PLUTO" : prad = 320 : pcol = &HB6
      Moon "CHARON", 170 : Moon "NIX", 40 : Moon "HYDRA", 45
      dmoon = 0
    Case 1
      pname = "NEPTUNE" : prad = 900 : pcol = &H1F : pring = 1
      Moon "PROTEUS", 60 : Moon "TRITON", 170 : Moon "NEREID", 40
      dmoon = 1
    Case 2
      pname = "URANUS" : prad = 950 : pcol = &H5F : pring = 1
      Moon "MIRANDA", 50 : Moon "ARIEL", 80 : Moon "UMBRIEL", 80 : Moon "TITANIA", 110 : Moon "OBERON", 105
      dmoon = 3
    Case 3
      pname = "SATURN" : prad = 1150 : pcol = &HF4 : pring = 2
      Moon "TETHYS", 70 : Moon "DIONE", 75 : Moon "RHEA", 90 : Moon "TITAN", 190 : Moon "IAPETUS", 85
      dmoon = 3
    Case 4
      pname = "JUPITER" : prad = 1400 : pcol = &HF0 : pring = 1
      Moon "IO", 110 : Moon "EUROPA", 100 : Moon "GANYMEDE", 160 : Moon "CALLISTO", 150
      dmoon = 1
    Case 5
      pname = "MARS" : prad = 500 : pcol = &HE0
      Moon "PHOBOS", 60 : Moon "DEIMOS", 45
      dmoon = 0
    Case 6
      pname = "EARTH" : prad = 560 : pcol = &H1B
      Moon "MOON", 180
      dmoon = 0
    Case 7
      pname = "VENUS" : prad = 540 : pcol = &HF8
      Moon "STATION", 130
      dmoon = 0
    Case 8
      pname = "MERCURY" : prad = 320 : pcol = &H92
      Moon "STATION", 120
      dmoon = 0
    Case Else
      pname = "THE SUN" : prad = 1700 : pcol = &HFC
  End Select
End Sub

' a moon of this planet: round it, spread out
Sub Moon(ByVal nme As String, ByVal r As Integer)
  Dim a As Integer, d As Integer
  mname(nm) = nme : mrad(nm) = r
  a = nm * 53 + 20 : d = prad + 700 + nm * 380
  mx(nm) = View.FMul(d, Models.Sine((a + 64) And 255))
  my(nm) = View.FMul(d \ 3, Models.Sine(a))
  mz(nm) = 3200 + View.FMul(d \ 2, Models.Sine(a + 32))
  nm = nm + 1
End Sub

' ---------------------------------------------------------------- input
Function FirePressed() As Integer
  Dim f As Integer
  f = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyEnter) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
  FirePressed = f And Not firewas
  firewas = f
End Function

' the sights: 4 pixels a frame, the ship turns when they are off the middle (when it may turn)
Sub Sights(ByVal canTurn As Integer)
  Dim j As Integer, p As Integer, y As Integer
  j = Keys.Joystick(0)
  If Keys.Down(Keys.KeyO) Or (j And Keys.JoyLeft) Then cx = cx - 4
  If Keys.Down(Keys.KeyP) Or (j And Keys.JoyRight) Then cx = cx + 4
  If Keys.Down(Keys.KeyQ) Or (j And Keys.JoyUp) Then cy = cy - 4
  If Keys.Down(Keys.KeyA) Or (j And Keys.JoyDown) Then cy = cy + 4
  If cx < 16 Then cx = 16
  If cx > 240 Then cx = 240
  If cy < 16 Then cy = 16
  If cy > 176 Then cy = 176
  If canTurn Then
    p = 0 : y = 0
    If cx > 176 Then y = 1
    If cx < 80 Then y = -1
    If cy < 56 Then p = 1
    If cy > 136 Then p = -1
    If p <> 0 Or y <> 0 Then View.TurnB View.CamBasis(), p, y, 0
  End If
  ' fire
  If cool > 0 Then cool = cool - 1
  firing = 0
  If (Keys.Down(Keys.KeySpace) Or (j And Keys.JoyFire1)) And cool = 0 And dead = 0 Then
    firing = 1 : cool = 4
    Sfx.Play 0, 28, 5, 12, 6, 0
  End If
End Sub

' is a thing at (x, y, z), size s, under the sights? (when firing)
Function OnTarget(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal s As Integer) As Integer
  Dim r As Integer
  OnTarget = 0
  If View.Project(x, y, z) Then
    If View.pz < 7000 Then
      r = View.MulDiv(s, 128, View.pz) + 6
      If Abs(View.px - cx) < r And Abs(View.py - cy) < r Then OnTarget = -1
    End If
  End If
End Function

' ---------------------------------------------------------------- panels and text
Sub Panels()
  Tiles.Fill GfxData.T_BLACK
  Tiles.Rect 0, 0, 40, 4, GfxData.T_PANEL
  Tiles.Rect 0, 28, 40, 4, GfxData.T_PANEL
  Tiles.Text 1, 1, "SHIELD"
  Tiles.Text 26, 1, "SCORE"
  Tiles.Text 1, 29, "SHIPS"
  Hud
End Sub

Sub Bar(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer, ByVal cells As Integer, ByVal t As Integer)
  Dim k As Integer, n As Integer
  n = v
  For k = 0 To cells - 1
    If n >= 8 Then
      Tiles.Put x + k, y, t + 8
    ElseIf n > 0 Then
      Tiles.Put x + k, y, t + n
    Else
      Tiles.Put x + k, y, t
    End If
    n = n - 8
  Next
End Sub

Sub Hud()
  Dim t As Integer, k As Integer
  Bar 8, 1, shield * 48 \ 100, 6, GfxData.T_BARG
  Tiles.Text 16, 1, Left$(pname & "         ", 9)
  Tiles.Text 32, 1, Format$(score, "0000000")
  Tiles.Text 7, 29, CStr(ships) & " "
  ' what is left to do
  Select Case phase
    Case PH_SPACE
      Tiles.Text 11, 29, "FIGHTERS LEFT " & Format$(need - kills, "00") & "      "
    Case PH_SURFACE
      Tiles.Text 11, 29, "TOWERS LEFT   " & Format$(towersLeft, "00") & "      "
    Case PH_CORE
      Tiles.Text 11, 29, "CORE "
      Bar 16, 29, coreHp * 2, 6, GfxData.T_BARO
      Tiles.Text 22, 29, "      "
    Case PH_BOSS
      t = 0
      For k = 0 To 2
        If uon(k) Then t = t + uhp(k)
      Next
      Tiles.Text 11, 29, "UNICORN "
      Bar 19, 29, t * 64 \ bossMax, 8, GfxData.T_BARO
    Case Else
      Tiles.Text 11, 29, "                       "
  End Select
End Sub

Sub Message(ByVal s As String)
  Tiles.Rect 1, 2, 38, 1, GfxData.T_PANEL
  If s <> "" Then Tiles.Text 20 - Len(s) \ 2, 2, s
End Sub

Sub Message2(ByVal s As String)
  Tiles.Rect 1, 30, 38, 1, GfxData.T_PANEL
  If s <> "" Then Tiles.Text 20 - Len(s) \ 2, 30, s
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
    Case "U": p = "55557"
    Case "N": p = "75555"
    Case "I": p = "72227"
    Case "C": p = "74447"
    Case "R": p = "75654"
    Case Else: p = "00000"
  End Select
  Glyph = Val(Mid$(p, r + 1, 1))
End Function

' ---------------------------------------------------------------- the title
Sub Title()
  Dim m As Integer
  Spr.HideRange 0, 16
  Spr.Show
  L2.Wipe
  Frame : L2.Flip
  L2.Wipe
  Nx.Layers Nx.OrderUSL
  Tiles.Fill GfxData.T_BLACK
  Tiles.Rect 4, 4, 32, 24, 0
  BigText 14, 1, "SOL", 0
  BigText 6, 7, "UNICORN", 1
  Tiles.Text 2, 25, "PLUTO TO THE SUN. TEN WORLDS, THEIR"
  Tiles.Text 2, 26, "DEATH MOONS AND THE CYBORG UNICORNS."
  Tiles.Text 2, 28, "Q A O P  AIM   SPACE  FIRE   KEMPSTON"
  Tiles.Text 2, 30, "HI " & Format$(hiscore, "0000000") & "        PRESS SPACE"
  View.Init
  View.SetCam 0, 0, -1000
  For m = 0 To 8
    tbas(m) = 0
  Next
  tbas(0) = 16384 : tbas(4) = 16384 : tbas(8) = 16384
  frames = 0 : firewas = -1
  Do
    L2.Clear
    View.TurnB VarPtr(tbas), 0, 1, 0
    View.Begin
    View.Model 0, 100, 0, Models.Base() + Models.M_UNIHEAD, VarPtr(tbas)
    L2.Lines View.Count, View.Table, C_UNI
    View.Begin
    View.Model 0, 100, 0, Models.Base() + Models.M_UNIPARTS, VarPtr(tbas)
    L2.Lines View.Count, View.Table, C_HORN
    Frame
    L2.Flip
    Sfx.Update
    frames = frames + 1 : seed = seed + 1
  Loop Until FirePressed()
  Nx.Seed seed
  Nx.Layers Nx.OrderSLU
End Sub

' ---------------------------------------------------------------- a game
Sub Play()
  score = 0 : ships = 3 : over = 0 : won = 0 : level = 0
  Panels
  NewStars
  For i = 0 To 31
    pl(i) = 0
  Next
  StartLevel
  Do
    L2.Clear
    firing = 0
    Select Case phase
      Case PH_WARP: Warp
      Case PH_SPACE: Space1
      Case PH_APPROACH: Approach
      Case PH_SURFACE, PH_CORE: Surface
      Case PH_BLAST: Blast
      Case PH_BOSS: Boss
      Case PH_CLEAR: Cleared
    End Select
    Bolts
    Sparks
    Laser
    If dead > 0 Then Dying
    hudT = hudT + 1
    If (hudT And 15) = 0 Then Hud
    Frame
    L2.Flip
    Spr.Show
    Sfx.Update
    frames = frames + 1
  Loop Until over
End Sub

Sub StartLevel()
  Dim k As Integer
  LevelData level
  phase = PH_WARP : pt = 0
  For k = 0 To NF - 1
    fon(k) = 0
  Next
  For k = 0 To NB - 1
    bon(k) = 0
  Next
  For k = 0 To 23
    wa(k) = Rnd(256) : wr(k) = 4 + Rnd(40)
  Next
  cx = 128 : cy = 96 : shield = 100
  Spr.Hide 0
  Message "WARP TO " & pname
  Message2 "LEVEL " & CStr(level + 1) & " OF " & CStr(LEVELS)
  Sfx.Play 2, 600, -12, 13, 60, 0
  Hud
End Sub

' ---------------------------------------------------------------- the warp
Sub Warp()
  Dim k As Integer, a As Integer, r As Integer, r2 As Integer, c As Integer, s As Integer
  pt = pt + 1
  View.Begin
  For k = 0 To 23
    a = wa(k) : r = wr(k)
    r2 = r + r \ 4 + 2
    c = Models.Sine((a + 64) And 255) : s = Models.Sine(a)
    View.Line 128 + View.FMul(r, c), 96 + View.FMul(r, s), 128 + View.FMul(r2, c), 96 + View.FMul(r2, s)
    wr(k) = r2
    If r2 > 200 Then
      wa(k) = Rnd(256) : wr(k) = 4 + Rnd(10)
    End If
  Next
  L2.Lines View.Count, View.Table, &HFF
  If pt = 120 Then
    ' arrived: the planet ahead
    View.Init
    phase = PH_SPACE : pt = 0 : kills = 0
    need = 6 + level
    If level = LEVELS - 1 Then need = 12
    Message pname
    Message2 ""
    Spr.Put 0, 32 + cx - 8, 32 + cy - 8, GfxData.S_CROSS, 0
    Hud
  End If
End Sub

' ---------------------------------------------------------------- the backdrop: stars, the planet, its moons
Sub NewStars()
  Dim k As Integer
  For k = 0 To NSTAR - 1
    sdx(k) = Rnd(16001) - 8000 : sdy(k) = Rnd(16001) - 8000 : sdz(k) = Rnd(16001) - 8000
  Next
End Sub

Sub Stars()
  Dim k As Integer
  For k = 0 To NSTAR - 1
    If View.Dir(sdx(k), sdy(k), sdz(k)) Then L2.Plot View.px, View.py, &HB6
  Next
End Sub

Sub Backdrop()
  Dim k As Integer, r As Integer, x As Integer, y As Integer
  Stars
  If View.Project(0, 0, 3200) Then
    r = View.MulDiv(prad, 128, View.pz)
    x = View.px : y = View.py
    View.Begin
    View.Ellipse x, y, r, r
    If level = LEVELS - 1 Then
      ' the sun: a second ring and rays
      View.Ellipse x, y, r * 3 \ 4, r * 3 \ 4
      View.Line x - r * 3 \ 2, y, x - r * 9 \ 8, y
      View.Line x + r * 3 \ 2, y, x + r * 9 \ 8, y
      View.Line x, y - r * 3 \ 2, x, y - r * 9 \ 8
      View.Line x, y + r * 3 \ 2, x, y + r * 9 \ 8
    Else
      If r > 16 Then View.Ellipse x, y, r, r \ 3
      If r > 28 Then View.Ellipse x, y, r \ 3, r
    End If
    L2.Lines View.Count, View.Table, pcol
    If pring Then
      View.Begin
      If pring = 2 Then
        View.Ellipse x, y, r * 9 \ 4, r * 2 \ 3
        View.Ellipse x, y, r * 7 \ 4, r \ 2
      Else
        View.Ellipse x, y, r * 3 \ 2, r \ 4
      End If
      L2.Lines View.Count, View.Table, &HB5
    End If
  End If
  For k = 0 To nm - 1
    If View.Project(mx(k), my(k), mz(k)) Then
      r = View.MulDiv(mrad(k), 128, View.pz)
      If r <= 1 Then
        L2.Plot View.px, View.py, &HDB
      Else
        View.Begin
        View.Ellipse View.px, View.py, r, r
        If k = dmoon And phase = PH_SPACE And r > 3 Then
          ' the death moon: its dish and its trench
          View.Ellipse View.px + r \ 3, View.py - r \ 3, r \ 3, r \ 3
          View.Line View.px - r, View.py, View.px + r, View.py
        End If
        L2.Lines View.Count, View.Table, IIf(k = dmoon, &HE7, &HDB)
      End If
    End If
  Next
End Sub

' ---------------------------------------------------------------- phase: the fighters
Sub Space1()
  Dim k As Integer, n As Integer
  Sights 1
  Backdrop
  pt = pt + 1
  n = 2 + level \ 3
  If n > NF Then n = NF
  For k = 0 To n - 1
    If fon(k) = 0 And pt > 40 + k * 30 And kills + Active() < need Then NewFighter k
  Next
  Fighters
  For k = 0 To NF - 1
    If fon(k) Then
      Pointer fpos(k * 3), fpos(k * 3 + 1), fpos(k * 3 + 2), GfxData.S_LOCK
      Exit For
    End If
  Next
  If k = NF Then Spr.Hide 1
  If kills >= need Then
    Spr.Hide 1
    If level = LEVELS - 1 Then
      StartBoss 3
    Else
      phase = PH_APPROACH : pt = 0
      Message "DEATH MOON: " & RTrim$(mname(dmoon))
      Message2 "BLOW UP ITS TOWERS AND ITS CORE"
      Sfx.Play 2, 900, -20, 14, 50, 0
    End If
    Hud
  End If
End Sub

Function Active() As Integer
  Dim k As Integer
  Active = 0
  For k = 0 To NF - 1
    If fon(k) Then Active = Active + 1
  Next
End Function

' a fighter, far ahead of where you look, coming in
Sub NewFighter(ByVal k As Integer)
  Dim b As Integer, d As Integer, lx As Integer, ly As Integer
  b = View.CamBasis()
  d = 3000 + Rnd(800)
  lx = Rnd(1601) - 800 : ly = Rnd(1001) - 500
  ' place = forward * d + right * lx + up * ly
  fpos(k * 3) = View.FMul(Deek(b + 12), d) + View.FMul(Deek(b), lx) + View.FMul(Deek(b + 6), ly)
  fpos(k * 3 + 1) = View.FMul(Deek(b + 14), d) + View.FMul(Deek(b + 2), lx) + View.FMul(Deek(b + 8), ly)
  fpos(k * 3 + 2) = View.FMul(Deek(b + 16), d) + View.FMul(Deek(b + 4), lx) + View.FMul(Deek(b + 10), ly)
  fon(k) = 1 : fcool(k) = 30 + Rnd(40)
  fvx(k) = 0 : fvy(k) = 0 : fvz(k) = 0
End Sub

Sub Fighters()
  Dim k As Integer, k3 As Integer, x As Integer, y As Integer, z As Integer, d As Integer, sp As Integer
  ' they all face you: the camera's basis turned round
  For k = 0 To 8
    fbas(k) = -Deek(View.CamBasis() + k * 2)
  Next
  fbas(3) = -fbas(3) : fbas(4) = -fbas(4) : fbas(5) = -fbas(5)
  sp = 3 + level \ 3
  For k = 0 To NF - 1
    If fon(k) Then
      k3 = k * 3
      x = fpos(k3) : y = fpos(k3 + 1) : z = fpos(k3 + 2)
      d = Abs(x)
      If Abs(y) > d Then d = Abs(y)
      If Abs(z) > d Then d = Abs(z)
      ' in towards you, weaving
      fvx(k) = fvx(k) - Sgn(x) * sp + (Models.Sine((frames * 4 + k * 50) And 255) \ 2048)
      fvy(k) = fvy(k) - Sgn(y) * sp + (Models.Sine((frames * 3 + k * 70) And 255) \ 2048)
      fvz(k) = fvz(k) - Sgn(z) * sp
      If Abs(fvx(k)) > 40 Then fvx(k) = Sgn(fvx(k)) * 40
      If Abs(fvy(k)) > 40 Then fvy(k) = Sgn(fvy(k)) * 40
      If Abs(fvz(k)) > 40 Then fvz(k) = Sgn(fvz(k)) * 40
      x = x + fvx(k) : y = y + fvy(k) : z = z + fvz(k)
      fpos(k3) = x : fpos(k3 + 1) = y : fpos(k3 + 2) = z
      If d < 260 Then
        ' it flew past: round again
        NewFighter k
      Else
        fcool(k) = fcool(k) - 1
        If fcool(k) <= 0 And d < 2800 Then
          fcool(k) = 50 + Rnd(60) - level * 3
          Fire x, y, z, 30 + level * 2
        End If
        If firing Then
          If OnTarget(x, y, z, 110) Then
            fon(k) = 0 : kills = kills + 1
            Spark View.px, View.py, &HFF, 12
            Spark View.px, View.py, &HE0, 8
            Sfx.Play 1, 20, 1, 15, 30, 1
            AddScore 150 + level * 25
            Hud
          End If
        End If
        If fon(k) Then
          View.Begin
          View.Model x, y, z, Models.Base() + Models.M_SHARD, VarPtr(fbas)
          L2.Lines View.Count, View.Table, C_FIGHTER
        End If
      End If
    End If
  Next
End Sub

' ---------------------------------------------------------------- bolts: the enemy's shots, which you can shoot
Sub Fire(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal sp As Integer)
  Dim k As Integer, d As Integer
  For k = 0 To NB - 1
    If bon(k) = 0 Then
      bpos(k * 3) = x : bpos(k * 3 + 1) = y : bpos(k * 3 + 2) = z
      d = Abs(x)
      If Abs(y) > d Then d = Abs(y)
      If Abs(z) > d Then d = Abs(z)
      If d < 1 Then d = 1
      bvx(k) = -View.MulDiv(x, sp, d) : bvy(k) = -View.MulDiv(y, sp, d) : bvz(k) = -View.MulDiv(z, sp, d)
      bon(k) = 1
      Sfx.Play 1, 90, 10, 10, 8, 0
      Exit Sub
    End If
  Next
End Sub

Sub Bolts()
  Dim k As Integer, k3 As Integer, x As Integer, y As Integer, z As Integer, d As Integer, r As Integer, px As Integer, py As Integer
  View.Begin
  For k = 0 To NB - 1
    If bon(k) Then
      k3 = k * 3
      x = bpos(k3) + bvx(k) : y = bpos(k3 + 1) + bvy(k) : z = bpos(k3 + 2) + bvz(k)
      bpos(k3) = x : bpos(k3 + 1) = y : bpos(k3 + 2) = z
      d = Abs(x)
      If Abs(y) > d Then d = Abs(y)
      If Abs(z) > d Then d = Abs(z)
      If d < 70 Then
        ' it got you
        bon(k) = 0
        Hurt 6 + level
      ElseIf View.Project(x, y, z) Then
        px = View.px : py = View.py
        r = View.MulDiv(40, 128, View.pz) + 2
        If r > 30 Then r = 30
        If firing And Abs(px - cx) < r + 6 And Abs(py - cy) < r + 6 Then
          bon(k) = 0
          Spark px, py, C_BOLT, 6
          AddScore 25
        Else
          View.Line px - r, py, px + r, py
          View.Line px, py - r, px, py + r
          View.Line px - r \ 2, py - r \ 2, px + r \ 2, py + r \ 2
          View.Line px - r \ 2, py + r \ 2, px + r \ 2, py - r \ 2
        End If
      Else
        bon(k) = 0
      End If
    End If
  Next
  L2.Lines View.Count, View.Table, C_BOLT
End Sub

Sub Hurt(ByVal n As Integer)
  If dead > 0 Then Exit Sub
  shield = shield - n
  Nx.PalEntry Nx.PalTiles, 0, &H60
  Sfx.Play 1, 6, 1, 15, 15, 1
  If shield <= 0 Then
    shield = 0
    dead = 100
    Spark 128, 96, &HFF, 20
    Spark 128, 96, &HE0, 12
    Sfx.Play 0, 200, 10, 15, 80, 0
    Message "SHIP LOST"
  End If
  Hud
End Sub

Sub Dying()
  Dim k As Integer
  dead = dead - 1
  Nx.PalEntry Nx.PalTiles, 0, (dead And 4) * 24
  If dead = 0 Then
    Nx.PalEntry Nx.PalTiles, 0, 0
    ships = ships - 1
    If ships = 0 Then
      over = 1
    Else
      shield = 100
      For k = 0 To NB - 1
        bon(k) = 0
      Next
      Message pname
      Hud
    End If
  End If
End Sub

' ---------------------------------------------------------------- your lasers
Sub Laser()
  If (frames And 3) = 0 And dead = 0 Then Nx.PalEntry Nx.PalTiles, 0, 0
  If firing = 0 Then Exit Sub
  L2.Line 8, 191, cx - 2, cy + 2, C_LASER
  L2.Line 247, 191, cx + 2, cy + 2, C_LASER
End Sub

' ---------------------------------------------------------------- phase: closing in on the death moon
Sub Approach()
  Dim r As Integer, z As Integer
  Sights 0
  Stars
  pt = pt + 1
  z = 6000 - pt * 40
  If View.Project(0, 0, z) Then
    r = View.MulDiv(mrad(dmoon) * 6, 128, View.pz)
    View.Begin
    View.Ellipse View.px, View.py, r, r
    View.Ellipse View.px + r \ 3, View.py - r \ 3, r \ 3, r \ 3
    View.Ellipse View.px + r \ 3, View.py - r \ 3, r \ 8, r \ 8
    View.Line View.px - r, View.py, View.px + r, View.py
    View.Ellipse View.px, View.py, r, r \ 3
    L2.Lines View.Count, View.Table, &HE7
  End If
  If pt >= 120 Then
    View.Init
    phase = PH_SURFACE : pt = 0 : scroll = 0
    towersLeft = 4 + level \ 2
    For r = 0 To NT - 1
      ton(r) = 0
    Next
    Message RTrim$(mname(dmoon)) & " - THE SURFACE"
    Message2 ""
    Hud
  End If
End Sub

' ---------------------------------------------------------------- phase: over the surface - towers, then the core
Sub Surface()
  Dim k As Integer, z As Integer, n As Integer
  Sights 0
  pt = pt + 1
  scroll = scroll + 30
  ' the ground: grids from the camera on (cross lines every 160 units: moved by the scroll)
  View.Begin
  z = -(scroll Mod 160)
  For k = 0 To 4
    View.Model 0, -150, z + k * 480, Models.Base() + Models.M_GRID, VarPtr(ibas)
  Next
  L2.Lines View.Count, View.Table, C_GRID
  L2.Line 0, 96 + 2, 255, 96 + 2, &H0E
  If phase = PH_SURFACE Then
    ' the towers come at you
    n = 0
    For k = 0 To NT - 1
      If ton(k) Then n = n + 1
    Next
    For k = 0 To NT - 1
      If ton(k) = 0 And towersLeft - n > 0 And Rnd(40) = 0 Then
        ton(k) = 1 : tx(k) = Rnd(1001) - 500 : tz(k) = 3200 : tcool(k) = 20 + Rnd(40)
        n = n + 1
      End If
    Next
    View.Begin
    For k = 0 To NT - 1
      If ton(k) Then
        tz(k) = tz(k) - 30
        If tz(k) < 150 Then
          ' gone past: it comes round again
          ton(k) = 0
        Else
          tcool(k) = tcool(k) - 1
          If tcool(k) <= 0 And tz(k) < 2600 Then
            tcool(k) = 40 + Rnd(40) - level * 2
            Fire tx(k), -150 + 320, tz(k), 32 + level * 2
          End If
          If firing Then
            If OnTarget(tx(k), -150 + 200, tz(k), 150) Then
              ton(k) = 0 : towersLeft = towersLeft - 1
              Spark View.px, View.py, &HFF, 12
              Spark View.px, View.py, C_TOWER, 8
              Sfx.Play 1, 24, 1, 15, 30, 1
              AddScore 300 + level * 50
              Hud
            End If
          End If
          If ton(k) Then View.Model tx(k), -150, tz(k), Models.Base() + Models.M_TOWER, VarPtr(ibas)
        End If
      End If
    Next
    L2.Lines View.Count, View.Table, C_TOWER
    If towersLeft = 0 Then
      phase = PH_CORE : coreZ = 4200 : coreHp = 5 + level \ 2
      Message "THE CORE - HIT IT " & CStr(coreHp) & " TIMES"
      Hud
    End If
  Else
    ' the core: hit it before it passes
    coreZ = coreZ - 25
    If firing Then
      If OnTarget(0, -150 + 250, coreZ, 260) Then
        coreHp = coreHp - 1
        Spark View.px, View.py, C_CORE, 6
        Sfx.Play 1, 10, 1, 13, 10, 1
        Hud
        If coreHp <= 0 Then
          phase = PH_BLAST : pt = 0
          Message RTrim$(mname(dmoon)) & " IS DESTROYED"
          AddScore 5000 + level * 1000
          Sfx.Play 1, 31, 0, 15, 100, 1
          Sfx.Play 2, 400, 10, 15, 90, 0
          Exit Sub
        End If
      End If
    End If
    If coreZ < 300 Then
      coreZ = 4200
      Message "MISSED - ROUND AGAIN"
    End If
    View.Begin
    View.Model 0, -150, coreZ, Models.Base() + Models.M_CORE, VarPtr(ibas)
    L2.Lines View.Count, View.Table, C_CORE
    If View.Project(0, -150 + 250, coreZ) Then
      View.Begin
      n = View.MulDiv(300, 128, View.pz)
      View.Ellipse View.px, View.py, n, n \ 2
      L2.Lines View.Count, View.Table, &HE7
    End If
  End If
End Sub

' ---------------------------------------------------------------- the moon blows up
Sub Blast()
  pt = pt + 1
  If pt = 1 Then Spr.Hide 0
  Stars
  If (pt And 7) = 0 Then
    Spark 64 + Rnd(128), 48 + Rnd(96), Choose(Rnd(4) + 1, &HFF, &HFC, &HF0, &HE0), 10
    Nx.PalEntry Nx.PalTiles, 0, IIf((pt And 8) = 0, &H24, 0)
  End If
  If pt >= 110 Then
    Nx.PalEntry Nx.PalTiles, 0, 0
    StartBoss 1
  End If
End Sub

' ---------------------------------------------------------------- phase: the unicorns
Sub StartBoss(ByVal n As Integer)
  Dim k As Integer, b As Integer
  phase = PH_BOSS : pt = 0 : nboss = n
  b = View.CamBasis()
  bossMax = 0
  For k = 0 To 2
    uon(k) = (k < n)
    If uon(k) Then
      ' a point ahead of you that it circles
      ux(k) = View.FMul(Deek(b + 12), 1300) + (k - 1) * View.FMul(Deek(b), 800)
      uy(k) = View.FMul(Deek(b + 14), 1300) + (k - 1) * View.FMul(Deek(b + 2), 800)
      uz(k) = View.FMul(Deek(b + 16), 1300) + (k - 1) * View.FMul(Deek(b + 4), 800)
      ua(k) = k * 85 : uhp(k) = 30 + level * 4 : ucool(k) = 60 + k * 30 : uhit(k) = 0
      If n > 1 Then uhp(k) = 40
      bossMax = bossMax + uhp(k)
    End If
  Next
  If n = 1 Then
    Message "A SPACE CYBORG UNICORN"
  Else
    Message "THREE SPACE CYBORG UNICORNS"
  End If
  Message2 ""
  Sfx.Play 2, 1200, -30, 15, 70, 0
  Hud
End Sub

Sub Boss()
  Dim k As Integer, x As Integer, y As Integer, z As Integer, a As Integer, b As Integer, c As Integer, left1 As Integer, left2 As Integer
  Sights 1
  Backdrop
  pt = pt + 1
  ' they face you
  b = View.CamBasis()
  For k = 0 To 8
    fbas(k) = -Deek(b + k * 2)
  Next
  fbas(3) = -fbas(3) : fbas(4) = -fbas(4) : fbas(5) = -fbas(5)
  left1 = 0
  For k = 0 To 2
    If uon(k) Then
      left1 = left1 + 1
      ua(k) = (ua(k) + 2) And 255
      a = ua(k)
      ' round the point: across, and up and down at twice the rate
      c = View.FMul(560, Models.Sine((a + 64) And 255))
      left2 = View.FMul(280, Models.Sine((a * 2) And 255))
      x = ux(k) + View.FMul(Deek(b), c) + View.FMul(Deek(b + 6), left2)
      y = uy(k) + View.FMul(Deek(b + 2), c) + View.FMul(Deek(b + 8), left2)
      z = uz(k) + View.FMul(Deek(b + 4), c) + View.FMul(Deek(b + 10), left2)
      uposx(k) = x : uposy(k) = y : uposz(k) = z
      ' its horn fires
      ucool(k) = ucool(k) - 1
      If ucool(k) <= 0 Then
        ucool(k) = 45 + Rnd(40) - level * 2
        Fire x, y + 300, z, 34 + level * 2
      End If
      If firing And uhit(k) = 0 Then
        If OnTarget(x, y, z, 330) Then
          uhp(k) = uhp(k) - 1 : uhit(k) = 4
          Spark View.px + Rnd(20) - 10, View.py + Rnd(20) - 10, C_UNI, 5
          Sfx.Play 1, 14, 1, 12, 8, 1
          AddScore 50
          Hud
          If uhp(k) <= 0 Then
            uon(k) = 0
            Spark View.px, View.py, &HFF, 16
            Spark View.px, View.py, C_UNI, 12
            Spark View.px, View.py, C_HORN, 8
            Sfx.Play 1, 31, 0, 15, 90, 1
            Sfx.Play 2, 60, 6, 15, 80, 0
            AddScore 10000 + level * 2500
          End If
        End If
      End If
      If uhit(k) > 0 Then uhit(k) = uhit(k) - 1
      If uon(k) Then
        c = C_UNI
        If uhit(k) And 2 Then c = &HFF
        View.Begin
        View.Model x, y, z, Models.Base() + Models.M_UNIHEAD, VarPtr(fbas)
        L2.Lines View.Count, View.Table, c
        View.Begin
        View.Model x, y, z, Models.Base() + Models.M_UNIPARTS, VarPtr(fbas)
        L2.Lines View.Count, View.Table, C_HORN
      End If
    End If
  Next
  For k = 0 To 2
    If uon(k) Then
      Pointer uposx(k), uposy(k), uposz(k), GfxData.S_ICON
      Exit For
    End If
  Next
  If left1 = 0 Then
    Spr.Hide 1
    phase = PH_CLEAR : pt = 0
    If level = LEVELS - 1 Then
      Message "THE SUN IS FREE - THE UNICORNS ARE BEATEN"
    Else
      Message "UNICORN DOWN - " & pname & " IS FREE"
    End If
    Hud
  End If
End Sub

' a level done: a moment, then the warp to the next (or the end)
Sub Cleared()
  Sights 1
  Backdrop
  pt = pt + 1
  If pt >= 150 Then
    If ships < 5 Then ships = ships + 1
    level = level + 1
    If level >= LEVELS Then
      won = 1 : over = 1
    Else
      StartLevel
    End If
  End If
End Sub

Sub AddScore(ByVal n As Long)
  score = score + n
  If score > hiscore Then hiscore = score
End Sub

' ---------------------------------------------------------------- a pointer at the screen's edge to a target out of sight
Sub Pointer(ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal pat As Integer)
  Dim px As Integer, py As Integer, ax As Integer, ay As Integer
  If View.Project(x, y, z) Then
    If View.px >= 0 And View.px < 256 And View.py >= 0 And View.py < 192 Then
      Spr.Hide 1
      Exit Sub
    End If
  End If
  ' which way: the target in the camera's terms, pushed out to the edge
  View.Local View.CamBasis(), x - View.CamX(), y - View.CamY(), z - View.CamZ()
  ax = View.lx : ay = -View.ly
  If View.lz < 0 And Abs(ax) < 64 And Abs(ay) < 64 Then ax = 64
  px = 128 : py = 96
  If Abs(ax) * 3 > Abs(ay) * 4 Then
    px = 128 + Sgn(ax) * 116 : py = 96 + View.MulDiv(ay, 116, Abs(ax))
  Else
    py = 96 + Sgn(ay) * 84 : px = 128 + View.MulDiv(ax, 84, Abs(ay) + 1)
  End If
  If py < 12 Then py = 12
  If py > 180 Then py = 180
  If px < 12 Then px = 12
  If px > 244 Then px = 244
  Spr.Put 1, 32 + px - 8, 32 + py - 8, pat, 0
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
  View.Begin
  For k = 0 To 31
    If pl(k) Then
      pl(k) = pl(k) - 1
      ppx(k) = ppx(k) + pvx(k) : ppy(k) = ppy(k) + pvy(k)
      x = ppx(k) \ 16 : y = ppy(k) \ 16
      View.Line x, y, x - pvx(k) \ 16, y - pvy(k) \ 16
    End If
  Next
  L2.Lines View.Count, View.Table, Choose((frames And 3) + 1, &HFF, &HFC, &HF0, &HE0)
  ' the sights: red over something that can be hit
  If phase <> PH_WARP And phase <> PH_BLAST Then
    Spr.Put 0, 32 + cx - 8, 32 + cy - 8, GfxData.S_CROSS + firing, 0
  End If
End Sub

' ---------------------------------------------------------------- the end
Sub GameOver()
  Dim n As Integer
  Spr.HideRange 0, 16
  If won Then
    Message "YOU FREED THE SOLAR SYSTEM"
    Message2 "SCORE " & Format$(score, "0000000")
  Else
    Message "GAME OVER"
  End If
  For n = 1 To 250
    L2.Clear
    Stars
    Sparks
    If won And (n And 15) = 0 Then Spark 32 + Rnd(192), 32 + Rnd(128), &HFF, 8
    Frame
    L2.Flip
    Spr.Show
    Sfx.Update
    If n > 60 And FirePressed() Then Exit For
  Next
  Nx.PalEntry Nx.PalTiles, 0, 0
  Sfx.Quiet
End Sub
