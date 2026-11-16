' CAVEMAN ANTICS - a scrolling beat 'em up for the ZX Spectrum Next, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Oola's been carried off. Grog follows, club in hand, through five lands - the jungle, the tar
' pits, the volcano, the ice caves and the valley of the T-rex - fighting rival cavemen, raptors
' and pterodactyls all the way, with a big one at the end of each land. Beat the T-rex, find
' Oola, and ride home on Bronty the brontosaurus.
'
' Keys: O P left, right; Q A up, down (into the picture and out). Space (Kempston fire): hit -
'       hit, hit, then the club comes down (a knock-down). M (fire 2): jump; hit in the air for a
'       flying kick. Meat gives life back.
'
' The scenery is the tilemap, in three bands the copper scrolls at their own speeds (Scene.cls);
' the sky is Layer 2; the people and the dinosaurs are sprites, drawn nearest last.
Option Explicit
Option Turbo

' the actors: 0 Grog, 1-6 the others
Const NA = 7, NP = 4, NI = 3
' kinds
Const K_GROG = 1, K_BOG = 2, K_THUD = 3, K_ROCKY = 4, K_RAPTOR = 5, K_PTERO = 6
Const K_BIGBOG = 10, K_TRIKE = 11, K_QUEEN = 12, K_KING = 13, K_TREX = 14, K_OOLA = 15
' states
Const ST_WALK = 0, ST_ATK = 1, ST_HURT = 2, ST_FLY = 3, ST_DOWN = 4, ST_JUMP = 5, ST_DEAD = 6, ST_BOSS = 7
' the caveman's frames
Const F_STAND = 0, F_WALK = 1, F_JAB = 3, F_WINDUP = 4, F_SMASH = 5, F_JUMP = 6, F_KICK = 7
' attacks: jab, smash, kick, throw, bite, the T-rex's bite, a charge
Const A_JAB = 1, A_SMASH = 2, A_KICK = 3, A_THROW = 4, A_BITE = 5, A_CHOMP = 6
' sprite slots: shadows 0-6, pickups 7-9, the actors 10-72 (9 each), rocks 73-76, their
' shadows 77-80, sparks 81-82, the arrow 83, hearts 84-86
Const SP_SHADOW = 0, SP_ITEM = 7, SP_ACT = 10, SP_ROCK = 73, SP_RSH = 77, SP_SPARK = 81, SP_ARROW = 83, SP_HEART = 84
' the play: how far in and out the feet go
Const ZMIN = 132, ZMAX = 186, MAXHP = 32

Dim longText As String Max 80
Dim ak(6) As Integer, ax(6) As Integer, az(6) As Integer, ah(6) As Integer, avx(6) As Integer, avh(6) As Integer
Dim af(6) As Integer, ast(6) As Integer, at(6) As Integer, ahp(6) As Integer, amax(6) As Integer, acool(6) As Integer
Dim ain(6) As Integer, aat(6) As Integer, ahit(6) As Integer, afl(6) As Integer, aph(6) As Integer, order(6) As Integer
' rocks: kind (1 thrown, 2 falling), where, how fast
Dim rk(3) As Integer, rx(3) As Integer, rz(3) As Integer, rh(3) As Integer, rvx(3) As Integer
' meat on the ground
Dim mk(2) As Integer, mx(2) As Integer, mz(2) As Integer
Dim stage As Integer, zone As Integer, zoneCam As Integer, locked As Integer, waveLeft As Integer, bossOn As Integer
Dim cam As Integer, drawnF As Integer, drawnM As Integer, drawnN As Integer
Dim score As Long, hiscore As Long, lives As Integer, frames As Integer, over As Integer, msgT As Integer
Dim combo As Integer, comboT As Integer, hitWas As Integer, jumpWas As Integer, inv As Integer, goT As Integer
Dim sparkT As Integer, sparkX As Integer, sparkY As Integer, shakeT As Integer, foeShown As Integer, foeWas As Integer
Dim near As Integer, swinging As Integer, copWas As Integer, palF(15) As Integer
Dim scoreDirty As Integer, kingCalled As Integer, rescued As Integer
Dim i As Integer, k As Integer, n As Integer

Nx.Border 0
Tiles.Init
Spr.Init
Nx.Reg &H1C, 2                           ' the sprites cut to the paper (x halved: over the border)
Nx.Reg &H19, 16 : Nx.Reg &H19, 143 : Nx.Reg &H19, 32 : Nx.Reg &H19, 223
Nx.Reg &H15, Nx.RegGet(&H15) Or &H20
GfxData.Load
Sfx.Init
Scene.Init
Nx.Layers Nx.OrderSUL                    ' sprites over the tilemap over the sky
hiscore = 20000
For k = 0 To 15
  palF(k) = Spr.Pal * k
Next
Do
  Title
  Game
Loop

' ---------------------------------------------------------------- the lands
' a stage's colours: the sky (12), the far band (16), the ground (16), as hex pairs
Sub Colours()
  Select Case stage
    Case 1
      Scene.Sky "2F2F53537377979BBBBBDFDF", 1
      Scene.Pal 1, "734E2A25BBF0A49255300C0879440000"
      Scene.Pal 2, "D1AD8868447830FE92B649532A580C00"
    Case 2
      Scene.Sky "656589898DADB1D1D5D5F9F9", 1
      Scene.Pal 1, "AD896544F6F0A48E6C48242091200000"
      Scene.Pal 2, "8D69494424904CFE9292494900702800"
    Case 3
      Scene.Sky "404064648484A8A8C8C8ECEC", 0
      Scene.Pal 1, "65452020A9F8E86A45252000A4000000"
      Scene.Pal 2, "6A494525208440DA6D8E25F8E8884400"
    Case 4
      Scene.Sky "5353777777979BBBBBBBDFDF", 1
      Scene.Pal 1, "FFBB976EFFBF53DBBF77320AFF450000"
      Scene.Pal 2, "FFDFBB9773FFBBDA92974E7B33520900"
    Case Else
      Scene.Sky "42426666868AAAAECECEF2F2", 1
      Scene.Pal 1, "8B664621D3F0A48E2E0A050552200000"
      Scene.Pal 2, "D5B18D6944904CFE92B2494F26752C00"
  End Select
  ' row 3: the foe's life bar, in red
  Nx.PalEntry Nx.PalTiles, 48, 0 : Nx.PalEntry Nx.PalTiles, 51, &H49
  Nx.PalEntry Nx.PalTiles, 52, &HE4 : Nx.PalEntry Nx.PalTiles, 53, &H60
End Sub

Function LandName() As String
  Select Case stage
    Case 1
      LandName = "THE JUNGLE"
    Case 2
      LandName = "THE TAR PITS"
    Case 3
      LandName = "THE VOLCANO"
    Case 4
      LandName = "THE ICE CAVES"
    Case Else
      LandName = "T-REX VALLEY"
  End Select
End Function

' the mountains' height at far column c (1-8 cells)
Function MtH(ByVal c As Integer) As Integer
  Dim a As Integer, b As Integer
  a = Abs(((c + stage * 5) Mod 24) - 12)
  b = Abs(((c * 3 + 5) Mod 14) - 7)
  MtH = 1 + a * 5 \ 12 + b \ 3
  If stage = 3 Then MtH = MtH + 1
End Function

' a little hash for where things go
Function Hs(ByVal c As Integer, ByVal r As Integer) As Integer
  Hs = ((c * 37 + r * 91 + stage * 13 + (c \ 7) * 11) And 32767) Mod 61
End Function

' far column c into the map (paper rows 3-11: map rows 7-15)
Sub FarCol(ByVal c As Integer)
  Dim h As Integer, hl As Integer, hr As Integer, r As Integer, x As Integer, t As Integer
  x = (c + 400) Mod 40
  h = MtH(c) : hl = MtH(c - 1) : hr = MtH(c + 1)
  For r = 0 To 8
    If r < 9 - h Then
      t = 0
      If stage = 3 And r = 8 - h And h >= hl And h >= hr Then t = GfxData.T_MT_SMOKE
    ElseIf r = 9 - h Then
      If h > hl And h > hr Then
        If stage = 3 Then t = GfxData.T_MT_CRATER Else t = GfxData.T_MT_TOP
      ElseIf h > hl Then
        t = GfxData.T_MT_SL
      ElseIf h > hr Then
        t = GfxData.T_MT_SR
      Else
        t = GfxData.T_MT_TOP
      End If
    Else
      If (Hs(c, r) And 3) = 0 Then t = GfxData.T_MT_FILL2 Else t = GfxData.T_MT_FILL
      If stage = 3 And Hs(c, r) < 6 Then t = GfxData.T_MT_LAVA
    End If
    Scene.Put x, 7 + r, t, 1
  Next
End Sub

' the jungle in the middle distance (paper rows 12-14: map rows 16-18)
Sub MidCol(ByVal c As Integer)
  Dim x As Integer, t As Integer
  x = (c + 400) Mod 40
  If Hs(c, 1) < 8 Then t = GfxData.T_CAN_PALM Else t = GfxData.T_CAN_TOP0 + (c Mod 3)
  Scene.Put x, 16, t, 1
  If Hs(c, 2) < 20 Then t = GfxData.T_CAN_FILL2 Else t = GfxData.T_CAN_FILL
  Scene.Put x, 17, t, 1
  Scene.Put x, 18, GfxData.T_CAN_FILL, 1
End Sub

' the ground (paper rows 15-23: map rows 19-27)
Sub NearCol(ByVal c As Integer)
  Dim x As Integer, r As Integer, t As Integer, h As Integer
  x = (c + 400) Mod 40
  If Hs(c, 0) < 30 Then t = GfxData.T_GR_EDGE Else t = GfxData.T_GR_EDGE2
  Scene.Put x, 19, t, 2
  For r = 1 To 8
    h = Hs(c, r)
    If h < 30 Then
      t = GfxData.T_GR_FILL
    ElseIf h < 44 Then
      t = GfxData.T_GR_FILL2
    ElseIf h < 54 Then
      t = GfxData.T_GR_FILL3
    ElseIf h = 54 And (c And 3) = 0 Then
      t = GfxData.T_GR_ROCK
    ElseIf h = 55 And (c And 7) = 0 Then
      t = GfxData.T_GR_SKULL
    ElseIf h = 56 Then
      t = GfxData.T_GR_STONES
    ElseIf h = 57 And r < 3 Then
      t = GfxData.T_GR_FERN
    Else
      t = GfxData.T_GR_FILL
    End If
    ' things two cells wide: bones, puddles (on even columns, with the next one)
    If (Hs(c And &HFFFE, r + 20) Mod 59) = 0 And ((c \ 2) And 3) = 0 Then
      If c And 1 Then t = GfxData.T_GR_BONER Else t = GfxData.T_GR_BONEL
    ElseIf (Hs(c And &HFFFE, r + 40) Mod 53) = 0 And r > 2 And ((c \ 2) And 3) = 1 Then
      If c And 1 Then t = GfxData.T_GR_PUDR Else t = GfxData.T_GR_PUDL
    End If
    Scene.Put x, 19 + r, t, 2
  Next
End Sub

' the whole scenery for the camera where it is
Sub DrawAll()
  For k = 0 To 39
    FarCol cam \ 32 + k - 2 : MidCol cam \ 16 + k - 2 : NearCol cam \ 8 + k - 2
  Next
  drawnF = cam \ 32 + 38 : drawnM = cam \ 16 + 38 : drawnN = cam \ 8 + 38
End Sub

' as the camera moves: the columns coming on, drawn in the border first
Sub Scroll()
  Do While drawnF < cam \ 32 + 37
    FarCol drawnF : drawnF = drawnF + 1
  Loop
  Do While drawnM < cam \ 16 + 37
    MidCol drawnM : drawnM = drawnM + 1
  Loop
  Do While drawnN < cam \ 8 + 37
    NearCol drawnN : drawnN = drawnN + 1
  Loop
  ' the copper's list again only when something moved
  k = cam + (shakeT And 2)
  If k <> copWas Then
    copWas = k
    Scene.Copper (cam \ 4) Mod 320, (cam \ 2) Mod 320, k Mod 320
  End If
End Sub

' ---------------------------------------------------------------- the panel (paper rows 0-2)
Sub Panel()
  Scene.Rect 0, 0, 40, 7, GfxData.T_PANEL, 0
  Scene.Text 4, 4, "GROG", 0
  Scene.Text 29, 4, "SC", 0
  ShowLife : ShowLives : ShowScore
End Sub

Sub Bar(ByVal x As Integer, ByVal y As Integer, ByVal v As Integer, ByVal p As Integer)
  Dim f As Integer
  For k = 0 To 7
    f = v - k * 4
    If f < 0 Then f = 0
    If f > 4 Then f = 4
    Scene.Put x + k, y, GfxData.T_BAR + f * 2, p
  Next
End Sub

Sub ShowLife()
  Bar 9, 4, ahp(0), 0
End Sub

Sub ShowLives()
  For k = 0 To 3
    If k < lives Then Scene.Put 18 + k, 4, GfxData.T_LIFE, 0 Else Scene.Put 18 + k, 4, GfxData.T_PANEL, 0
  Next
End Sub

Sub ShowScore()
  Scene.Text 30, 4, Right$("000000" & Trim$(Str$(score)), 6), 0
  scoreDirty = 0
End Sub

' the foe last hit: its name and life
Sub ShowFoe(ByVal a As Integer)
  If a < 0 Then
    Scene.Rect 4, 5, 32, 1, GfxData.T_PANEL, 0
    foeShown = -1
    Exit Sub
  End If
  If a <> foeShown Then
    Scene.Rect 4, 5, 32, 1, GfxData.T_PANEL, 0
    Scene.Text 4, 5, FoeName(ak(a)), 0
    foeShown = a
  End If
  Bar 17, 5, (ahp(a) * 32) \ amax(a), 3
End Sub

Function FoeName(ByVal kd As Integer) As String
  Select Case kd
    Case K_BOG
      FoeName = "BOG"
    Case K_THUD
      FoeName = "THUD"
    Case K_ROCKY
      FoeName = "ROCKY"
    Case K_RAPTOR
      FoeName = "RAPTOR"
    Case K_PTERO
      FoeName = "PTERO"
    Case K_BIGBOG
      FoeName = "BIG BOG"
    Case K_TRIKE
      FoeName = "TRICERATOPS"
    Case K_QUEEN
      FoeName = "PTERO QUEEN"
    Case K_KING
      FoeName = "KING THUD"
    Case Else
      FoeName = "T-REX"
  End Select
End Function

Sub Message(ByVal m As String, ByVal t As Integer)
  longText = m
  Scene.Rect 4, 6, 32, 1, GfxData.T_PANEL, 0
  Scene.Text 4 + (32 - Len(longText)) \ 2, 6, longText, 0
  msgT = t
End Sub

Sub AddScore(ByVal v As Integer)
  score = score + v
  scoreDirty = 1
End Sub

' ---------------------------------------------------------------- the title
Sub Title()
  Dim y As Integer
  stage = 1 : cam = 0 : shakeT = 0
  Spr.HideRange 0, 90 : Spr.Show
  Colours
  DrawAll
  Scene.Rect 0, 0, 40, 7, GfxData.T_PANEL, 0
  Scene.Text 13, 4, "CAVEMAN ANTICS", 0
  Scene.Text 7, 6, "HI " & Right$("000000" & Trim$(Str$(hiscore)), 6), 0
  Scene.Text 8, 20, "OOLA'S BEEN CARRIED OFF!", 0
  Scene.Text 8, 22, "OPQA   WALK", 0
  Scene.Text 8, 23, "SPACE  HIT (3RD HIT: SMASH)", 0
  Scene.Text 8, 24, "M      JUMP (+SPACE: KICK)", 0
  Scene.Text 8, 26, "(C) 2026 CYBORG UNICORN", 0
  ' Grog and a raptor, showing off
  Scene.Copper 0, 0, 0
  y = 0
  Do
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1
    y = y + 1
    DrawMan 0, 124, 150, (frames \ 8) Mod 3, 1, 0, 0
    DrawGroup 10, GfxData.S_TREX + ((frames \ 16) And 1) * 9, 3, 3, 196, 150, 1, 9, 0
    If y = 25 Then Scene.Text 13, 18, "PRESS SPACE", 0
    If y = 50 Then Scene.Text 13, 18, "           ", 0 : y = 0
  Loop Until Keys.Down(Keys.KeySpace) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
  Do
    Frame
  Loop While Keys.Down(Keys.KeySpace)
  Spr.HideRange 0, 90
End Sub

' ---------------------------------------------------------------- a game
Sub Game()
  score = 0 : lives = 3 : over = 0 : stage = 1
  Do
    Land
    If over Then Exit Do
    If stage = 5 Then
      Ending
      Exit Do
    End If
    stage = stage + 1
  Loop
  If score > hiscore Then hiscore = score
  If over Then
    Message "GAME OVER", 200
    For k = 1 To 200
      Frame
      Sfx.Update
    Next
  End If
End Sub

' one land: six stretches of fighting, the big one at the end
Sub Land()
  For k = 0 To NA - 1
    ak(k) = 0
  Next
  For k = 0 To NP - 1
    rk(k) = 0
  Next
  For k = 0 To NI - 1
    mk(k) = 0
  Next
  Spr.HideRange 0, 90
  cam = 0 : zone = 0 : zoneCam = 0 : locked = 1 : bossOn = 0 : kingCalled = 0 : rescued = 0
  Colours
  DrawAll
  Panel
  ak(0) = K_GROG : ax(0) = 40 : az(0) = 160 : ah(0) = 0 : af(0) = 1 : ast(0) = ST_WALK : ahp(0) = MAXHP : amax(0) = MAXHP
  aph(0) = 0 : inv = 60 : hitWas = 1 : jumpWas = 1
  ShowLife
  foeShown = -2 : ShowFoe -1
  waveLeft = Wave()
  Message "STAGE " & Trim$(Str$(stage)) & " - " & LandName(), 150
  Do
    Spawner
    Player
    Engage
    For k = 1 To NA - 1
      If ak(k) Then Foe k
    Next
    Rocks
    Meat
    Camera
    Draw
    If msgT > 0 Then
      msgT = msgT - 1
      If msgT = 0 Then Scene.Rect 4, 6, 32, 1, GfxData.T_PANEL, 0
    End If
    If scoreDirty And (frames And 7) = 0 Then ShowScore
    Frame
    Scroll
    Spr.Show
    Sfx.Update
    frames = frames + 1
    If shakeT > 0 Then shakeT = shakeT - 1
    If over Then Exit Sub
    If rescued > 0 Then
      rescued = rescued + 1
      If rescued > 200 Then Exit Sub
    End If
    If bossOn = 2 And stage < 5 Then
      ' the big one beaten: a moment, then on
      goT = goT + 1
      If goT > 180 Then Exit Sub
    End If
  Loop
End Sub

' how many come in this stretch
Function Wave() As Integer
  Wave = 3 + zone + stage \ 2
End Function

' foes come in from the edges while the stretch has more; the big one at the last
Sub Spawner()
  Dim live As Integer, a As Integer, kd As Integer, r As Integer
  If locked = 0 Then Exit Sub
  live = 0
  For k = 1 To NA - 1
    If ak(k) And ast(k) <> ST_DEAD Then live = live + 1
  Next
  If zone = 5 Then
    If bossOn = 0 And live = 0 Then
      bossOn = 1
      a = Spawn(BossKind(), cam + 220, 160)
      Message "LOOK OUT! " & FoeName(BossKind()), 120
      Sfx.Play 2, 400, 0, 15, 40, 1
      Exit Sub
    End If
    If bossOn = 1 And live = 0 Then
      bossOn = 2 : goT = 0
      AddScore 5000
      If stage = 5 Then
        a = Spawn(K_OOLA, cam + 230, 160)
        Message "OOLA!", 100
      Else
        Message FoeName(BossKind()) & " BEATEN!", 150
      End If
    End If
    Exit Sub
  End If
  If waveLeft > 0 And live < 2 + stage \ 2 And (frames And 31) = 0 Then
    r = Rnd(10)
    kd = K_BOG
    Select Case stage
      Case 1
        If r < 3 And zone >= 2 Then kd = K_RAPTOR
      Case 2
        If r < 3 Then kd = K_THUD
        If r >= 7 Then kd = K_RAPTOR
      Case 3
        If r < 3 Then kd = K_THUD
        If r >= 4 And r < 6 Then kd = K_ROCKY
        If r >= 7 Then kd = K_PTERO
      Case 4
        If r < 3 Then kd = K_THUD
        If r >= 4 And r < 6 Then kd = K_ROCKY
        If r >= 7 Then kd = K_RAPTOR
      Case Else
        If r < 2 Then kd = K_THUD
        If r = 3 Then kd = K_ROCKY
        If r >= 5 And r < 7 Then kd = K_RAPTOR
        If r >= 8 Then kd = K_PTERO
    End Select
    If Rnd(2) Then a = Spawn(kd, cam - 24, ZMIN + Rnd(ZMAX - ZMIN)) Else a = Spawn(kd, cam + 280, ZMIN + Rnd(ZMAX - ZMIN))
    If a > 0 Then waveLeft = waveLeft - 1
  End If
  If waveLeft = 0 And live = 0 Then
    ' the stretch is clear: go on
    locked = 0 : goT = 0
    zone = zone + 1
    zoneCam = zone * 256
    Sfx.Play 1, 60, -2, 13, 20, 0
  End If
End Sub

Function BossKind() As Integer
  BossKind = K_BIGBOG + stage - 1
End Function

Function Spawn(ByVal kd As Integer, ByVal x As Integer, ByVal z As Integer) As Integer
  Dim a As Integer
  For a = 1 To NA - 1
    If ak(a) = 0 Then
      ak(a) = kd : ax(a) = x : az(a) = z : ah(a) = 0 : avx(a) = 0 : avh(a) = 0
      If x < cam + 128 Then af(a) = 1 Else af(a) = -1
      ast(a) = ST_WALK : at(a) = 0 : acool(a) = 30 + Rnd(40) : afl(a) = 0 : ahit(a) = 0 : ain(a) = 0
      Select Case kd
        Case K_BOG
          ahp(a) = 10 : aph(a) = 2
        Case K_THUD
          ahp(a) = 16 : aph(a) = 3
        Case K_ROCKY
          ahp(a) = 10 : aph(a) = 4
        Case K_RAPTOR
          ahp(a) = 8 : aph(a) = 5 + Rnd(2)
        Case K_PTERO
          ahp(a) = 6 : aph(a) = 7 : ah(a) = 70
        Case K_BIGBOG
          ahp(a) = 60 : aph(a) = 12
        Case K_TRIKE
          ahp(a) = 70 : aph(a) = 8 : ast(a) = ST_BOSS
        Case K_QUEEN
          ahp(a) = 60 : aph(a) = 7 : ah(a) = 70
        Case K_KING
          ahp(a) = 90 : aph(a) = 13
        Case K_TREX
          ahp(a) = 120 : aph(a) = 9
        Case Else
          ahp(a) = 1 : aph(a) = 11 : af(a) = -1
      End Select
      amax(a) = ahp(a)
      Spawn = a
      Exit Function
    End If
  Next
  Spawn = 0
End Function

Function Big(ByVal a As Integer) As Integer
  Big = 0
  If ak(a) >= K_BIGBOG And ak(a) <= K_TREX Then Big = 1
End Function

Function IsMan(ByVal kd As Integer) As Integer
  IsMan = 0
  If kd <= K_ROCKY Or kd = K_BIGBOG Or kd = K_KING Then IsMan = 1
End Function

' ---------------------------------------------------------------- the camera
Sub Camera()
  Dim sx As Integer, lim As Integer
  If locked = 0 Then
    sx = ax(0) - cam
    If sx > 140 Then cam = cam + 2
    If cam >= zoneCam Then cam = zoneCam : locked = 1 : waveLeft = Wave()
    goT = goT + 1
    If (goT And 31) < 20 Then Spr.Put SP_ARROW, 270, 100, GfxData.S_ARROW, 0 Else Spr.Hide SP_ARROW
  Else
    Spr.Hide SP_ARROW
  End If
  If ax(0) < cam + 12 Then ax(0) = cam + 12
  If ax(0) > cam + 244 Then ax(0) = cam + 244
End Sub

' ---------------------------------------------------------------- Grog
Sub Player()
  Dim j0 As Integer, hitK As Integer, jumpK As Integer, mxv As Integer, mz As Integer
  If inv > 0 Then inv = inv - 1
  If afl(0) > 0 Then afl(0) = afl(0) - 1          ' (the hit flash wears off)
  If ast(0) = ST_WALK And ah(0) > 0 Then Air 0
  If comboT > 0 Then comboT = comboT - 1 Else combo = 0
  j0 = Keys.Joystick(0)
  hitK = Keys.Down(Keys.KeySpace) Or ((j0 And Keys.JoyFire1) <> 0)
  jumpK = Keys.Down(Keys.KeyM) Or ((j0 And Keys.JoyFire2) <> 0)
  mxv = 0 : mz = 0
  If Keys.Down(Keys.KeyO) Or (j0 And Keys.JoyLeft) Then mxv = -1
  If Keys.Down(Keys.KeyP) Or (j0 And Keys.JoyRight) Then mxv = 1
  If Keys.Down(Keys.KeyQ) Or (j0 And Keys.JoyUp) Then mz = -1
  If Keys.Down(Keys.KeyA) Or (j0 And Keys.JoyDown) Then mz = 1
  Select Case ast(0)
    Case ST_WALK
      If mxv <> 0 Then af(0) = mxv
      ax(0) = ax(0) + mxv * 2 : az(0) = az(0) + mz
      If az(0) < ZMIN Then az(0) = ZMIN
      If az(0) > ZMAX Then az(0) = ZMAX
      If mxv <> 0 Or mz <> 0 Then at(0) = at(0) + 1
      If hitK And hitWas = 0 Then
        ast(0) = ST_ATK : ahit(0) = 0 : avx(0) = 0
        If combo >= 2 Then
          aat(0) = A_SMASH : at(0) = 0 : combo = 0 : comboT = 0
          Sfx.Play 0, 300, 20, 12, 10, 1
        Else
          aat(0) = A_JAB : at(0) = 0 : combo = combo + 1 : comboT = 30
          Sfx.Play 0, 200, 30, 10, 5, 1
        End If
      ElseIf jumpK And jumpWas = 0 Then
        ast(0) = ST_JUMP : avh(0) = 8 : avx(0) = mxv * 2 : aat(0) = 0 : ahit(0) = 0
        Sfx.Play 0, 120, -6, 10, 6, 0
      End If
    Case ST_ATK
      at(0) = at(0) + 1
      Attack 0
      If aat(0) = A_JAB And at(0) >= 12 Then ast(0) = ST_WALK
      If aat(0) = A_SMASH And at(0) >= 24 Then ast(0) = ST_WALK
    Case ST_JUMP
      ax(0) = ax(0) + avx(0)
      If hitK And hitWas = 0 And aat(0) = 0 Then aat(0) = A_KICK : ahit(0) = 0 : Sfx.Play 0, 200, 20, 10, 6, 1
      If aat(0) = A_KICK Then Attack 0
      Air 0
      If ah(0) = 0 Then ast(0) = ST_WALK : aat(0) = 0 : Dust ax(0), az(0)
    Case Else
      Knocked 0
  End Select
  hitWas = hitK : jumpWas = jumpK
End Sub

' up and down: ah, avh (gravity 1 a frame)
Sub Air(ByVal a As Integer)
  ah(a) = ah(a) + avh(a)
  avh(a) = avh(a) - 1
  If ah(a) <= 0 Then ah(a) = 0 : avh(a) = 0
End Sub

' hurt, flying, down, dead: anyone
Sub Knocked(ByVal a As Integer)
  at(a) = at(a) + 1
  Select Case ast(a)
    Case ST_HURT
      If at(a) >= 14 Then ast(a) = ST_WALK : at(a) = 0
    Case ST_FLY
      ax(a) = ax(a) + avx(a)
      Air a
      If ah(a) = 0 Then
        ast(a) = ST_DOWN : at(a) = 0
        Dust ax(a), az(a)
        Sfx.Play 2, 31, 0, 12, 8, 1
      End If
    Case ST_DOWN
      If at(a) >= 40 Then
        If ahp(a) <= 0 Then
          ast(a) = ST_DEAD : at(a) = 0
        Else
          ast(a) = ST_WALK : at(a) = 0
          If a = 0 Then inv = 60
        End If
      End If
    Case ST_DEAD
      If at(a) >= 40 Then
        If a = 0 Then
          lives = lives - 1 : ShowLives
          If lives <= 0 Then
            over = 1
          Else
            ast(0) = ST_WALK : ahp(0) = MAXHP : ShowLife : inv = 120 : ah(0) = 60
          End If
        Else
          ak(a) = 0
          Spr.Hide SP_SHADOW + a
          If foeShown = a Then ShowFoe -1
        End If
      End If
  End Select
  If az(a) < ZMIN Then az(a) = ZMIN
  If az(a) > ZMAX Then az(a) = ZMAX
End Sub

' a's attack: is it on, and on whom?
Sub Attack(ByVal a As Integer)
  Dim reach As Integer, dmg As Integer, knock As Integer, live As Integer, t As Integer, dx As Integer, dz As Integer, zr As Integer
  If ahit(a) Then Exit Sub
  live = 0 : knock = 0 : zr = 9
  Select Case aat(a)
    Case A_JAB
      If at(a) >= 4 And at(a) <= 7 Then live = 1
      reach = 28 : dmg = 2
    Case A_SMASH
      If at(a) >= 11 And at(a) <= 15 Then live = 1
      reach = 36 : dmg = 6 : knock = 1
    Case A_KICK
      live = 1 : reach = 26 : dmg = 5 : knock = 1
    Case A_BITE
      If at(a) >= 6 And at(a) <= 10 Then live = 1
      reach = 30 : dmg = 4
    Case A_CHOMP
      If at(a) >= 16 And at(a) <= 22 Then live = 1
      reach = 76 : dmg = 10 : knock = 1 : zr = 16
  End Select
  If live = 0 Then Exit Sub
  If Big(a) Then reach = reach * 2 : dmg = dmg + 2 : zr = 16
  If a = 0 Then
    For t = 1 To NA - 1
      If ak(t) And ak(t) <> K_OOLA And ast(t) <> ST_DEAD And ast(t) <> ST_DOWN And ast(t) <> ST_FLY Then
        dx = (ax(t) - ax(0)) * af(0) : dz = Abs(az(t) - az(0))
        If Big(t) Then dz = dz - 8 : dx = dx - 16
        If dx > -6 And dx < reach And dz < zr And ah(t) - ah(0) < 44 Then
          ahit(0) = 1
          Hurt t, dmg, knock, af(0)
          comboT = 30
          AddScore dmg * 10
        End If
      End If
    Next
  Else
    If ast(0) = ST_DEAD Or ast(0) = ST_DOWN Or ast(0) = ST_FLY Or inv > 0 Then Exit Sub
    dx = (ax(0) - ax(a)) * af(a) : dz = Abs(az(0) - az(a))
    If dx > -6 And dx < reach And dz < zr And ah(0) < 30 Then
      ahit(a) = 1
      Hurt 0, dmg, knock, af(a)
    End If
  End If
End Sub

' t is hit for d (knock: knocked down), from dir
Sub Hurt(ByVal t As Integer, ByVal d As Integer, ByVal knock As Integer, ByVal dir As Integer)
  ahp(t) = ahp(t) - d
  afl(t) = 6
  sparkT = 6 : sparkX = ax(t) - dir * 4 : sparkY = az(t) - ah(t) - 28
  If Big(t) Then sparkY = sparkY - 20
  If t = 0 Then
    ShowLife
    combo = 0
    Sfx.Play 2, 60, 6, 14, 10, 1
  Else
    ShowFoe t
    Sfx.Play 1, 40, 4, 14, 8, 1
  End If
  If ahp(t) <= 0 Then
    ahp(t) = 0 : knock = 1
    If t > 0 Then
      AddScore 100 + 400 * Big(t)
      If Rnd(4) = 0 And Big(t) = 0 Then DropMeat ax(t), az(t)
    End If
  End If
  If Big(t) Then
    ' the big ones don't go down (until they're beaten)
    If ahp(t) <= 0 Then ast(t) = ST_DOWN : at(t) = 0 : shakeT = 30 : Sfx.Play 2, 31, 0, 15, 50, 1
    Exit Sub
  End If
  If knock Then
    ast(t) = ST_FLY : at(t) = 0 : avx(t) = dir * 3 : avh(t) = 5 : ah(t) = ah(t) + 1
  Else
    ast(t) = ST_HURT : at(t) = 0 : ax(t) = ax(t) + dir * 3
  End If
  ' a pterodactyl hit falls
  If ak(t) = K_PTERO And ast(t) = ST_HURT Then ast(t) = ST_FLY : avh(t) = 0 : avx(t) = dir * 2
End Sub

Sub Dust(ByVal x As Integer, ByVal z As Integer)
  sparkT = -8 : sparkX = x : sparkY = z - 10
End Sub

' ---------------------------------------------------------------- the others
' who takes Grog on: the nearest (the rest hang back); how many are swinging now
Sub Engage()
  Dim a As Integer, d As Integer, best As Integer
  near = 0 : best = 9999 : swinging = 0
  For a = 1 To NA - 1
    If ak(a) Then
      If ast(a) = ST_ATK Then swinging = swinging + 1
      If ast(a) = ST_WALK Then
        d = Abs(ax(a) - ax(0)) + Abs(az(a) - az(0)) * 2
        If d < best Then best = d : near = a
      End If
    End If
  Next
End Sub

Sub Foe(ByVal a As Integer)
  Dim kd As Integer, dx As Integer, dz As Integer, tx As Integer, side As Integer
  kd = ak(a)
  If afl(a) > 0 Then afl(a) = afl(a) - 1
  If acool(a) > 0 Then acool(a) = acool(a) - 1
  If kd = K_OOLA Then
    ' Oola: waiting for Grog
    If rescued = 0 And Abs(ax(0) - ax(a)) < 30 And Abs(az(0) - az(a)) < 12 Then
      rescued = 1
      Message "OOLA: MY HERO!", 200
      Sfx.Play 0, 100, -3, 14, 40, 0
    End If
    Exit Sub
  End If
  If ast(a) <> ST_WALK And ast(a) <> ST_ATK And ast(a) <> ST_BOSS Then
    Knocked a
    Exit Sub
  End If
  dx = ax(0) - ax(a) : dz = az(0) - az(a)
  If ast(a) = ST_ATK Then
    at(a) = at(a) + 1
    Attack a
    If aat(a) = A_THROW And at(a) = 8 Then Throw a
    side = 24
    If aat(a) = A_CHOMP Then side = 32
    If at(a) >= side Then ast(a) = ST_WALK : at(a) = 0
    Exit Sub
  End If
  Select Case kd
    Case K_BOG, K_THUD, K_ROCKY, K_BIGBOG, K_KING
      ' stand off to one side of Grog, then swing
      If dx > 0 Then side = -1 Else side = 1
      If kd = K_ROCKY Then
        tx = ax(0) + side * 70
      ElseIf a = near Or Big(a) Then
        tx = ax(0) + side * (26 + Big(a) * 30)
      Else
        tx = ax(0) + side * 60
      End If
      If ax(a) < tx - 2 Then ax(a) = ax(a) + 1
      If ax(a) > tx + 2 Then ax(a) = ax(a) - 1
      If (frames And 1) Or kd = K_THUD Then
        If az(a) < az(0) Then az(a) = az(a) + 1
        If az(a) > az(0) Then az(a) = az(a) - 1
      End If
      If dx > 0 Then af(a) = 1 Else af(a) = -1
      at(a) = at(a) + 1
      If acool(a) = 0 And Abs(ax(a) - tx) < 6 And Abs(dz) < 4 And ast(0) <> ST_DEAD And swinging < 1 + stage \ 4 And inv = 0 Then
        swinging = swinging + 1
        ast(a) = ST_ATK : at(a) = 0 : ahit(a) = 0
        If kd = K_ROCKY Then
          aat(a) = A_THROW
        ElseIf Rnd(3) = 0 Or kd = K_THUD Or Big(a) Then
          aat(a) = A_SMASH
        Else
          aat(a) = A_JAB
        End If
        acool(a) = 40 + Rnd(50) - stage * 4
        If Big(a) Then acool(a) = 50
      End If
      ' King Thud calls for help
      If kd = K_KING And kingCalled = 0 And ahp(a) * 2 < amax(a) Then
        kingCalled = 1
        n = Spawn(K_THUD, cam - 20, 150) : n = Spawn(K_BOG, cam + 276, 175)
        Message "KING THUD CALLS FOR HELP!", 100
      End If
    Case K_RAPTOR
      ax(a) = ax(a) + af(a) * 3
      at(a) = at(a) + 1
      If az(a) < az(0) Then az(a) = az(a) + 1
      If az(a) > az(0) Then az(a) = az(a) - 1
      If dx * af(a) > 0 And dx * af(a) < 30 And Abs(dz) < 6 And acool(a) = 0 Then
        ast(a) = ST_ATK : aat(a) = A_BITE : at(a) = 0 : ahit(a) = 0 : acool(a) = 50
        Sfx.Play 1, 80, 10, 12, 6, 0
      End If
      ' run on past Grog, then turn round (at the latest at the screen's edges)
      If dx * af(a) < -70 Then af(a) = -af(a)
      If ax(a) > cam + 280 Then af(a) = -1
      If ax(a) < cam - 24 Then af(a) = 1
    Case K_PTERO, K_QUEEN
      ' high over Grog; now and then down at him
      If ast(a) = ST_BOSS Then
        at(a) = at(a) + 1
        If at(a) < 18 Then
          ah(a) = ah(a) - 3
        Else
          ah(a) = ah(a) + 3
        End If
        If ah(a) < 30 And Abs(dx) < 20 + Big(a) * 20 And Abs(dz) < 10 + Big(a) * 6 And inv = 0 And ast(0) < ST_FLY Then
          Hurt 0, 4 + Big(a) * 4, Big(a), af(a)
        End If
        If ah(a) >= 70 Then ah(a) = 70 : ast(a) = ST_WALK : acool(a) = 60 + Rnd(60)
      Else
        If dx > 4 Then ax(a) = ax(a) + 2 : af(a) = 1
        If dx < -4 Then ax(a) = ax(a) - 2 : af(a) = -1
        If az(a) < az(0) Then az(a) = az(a) + 1
        If az(a) > az(0) Then az(a) = az(a) - 1
        If acool(a) = 0 And Abs(dx) < 30 Then ast(a) = ST_BOSS : at(a) = 0
        If kd = K_QUEEN And (frames And 63) = 0 Then Drop ax(0), az(0)
      End If
    Case K_TRIKE
      ' paw the ground (lining up with Grog), then charge across; dazed at the far side
      at(a) = at(a) + 1
      If acool(a) > 0 Then
        If az(a) < az(0) Then az(a) = az(a) + 1
        If az(a) > az(0) Then az(a) = az(a) - 1
        If (acool(a) And 7) = 0 Then shakeT = 4 : Sfx.Play 2, 300, 0, 10, 4, 1
      Else
        If avx(a) = 0 Then avx(a) = af(a) * 5 : Sfx.Play 2, 200, 10, 15, 30, 1
        ax(a) = ax(a) + avx(a)
        If Abs(dx) < 34 And Abs(dz) < 14 And inv = 0 And ast(0) < ST_FLY Then Hurt 0, 8, 1, af(a)
        If (ax(a) > cam + 230 And avx(a) > 0) Or (ax(a) < cam + 26 And avx(a) < 0) Then
          avx(a) = 0 : af(a) = -af(a) : acool(a) = 120 : shakeT = 16
          Sfx.Play 2, 31, 0, 15, 20, 1
        End If
      End If
    Case K_TREX
      ' plod towards Grog; a bite when close; a roar now and then
      If dx > 0 Then af(a) = 1 Else af(a) = -1
      If Abs(dx) > 60 And (frames And 1) Then ax(a) = ax(a) + af(a)
      If az(a) < az(0) And (frames And 3) = 0 Then az(a) = az(a) + 1
      If az(a) > az(0) And (frames And 3) = 0 Then az(a) = az(a) - 1
      at(a) = at(a) + 1
      If acool(a) = 0 And Abs(dx) < 80 And Abs(dz) < 16 Then
        ast(a) = ST_ATK : aat(a) = A_CHOMP : at(a) = 0 : ahit(a) = 0 : acool(a) = 70
        Sfx.Play 2, 500, -10, 15, 30, 1
      End If
      If (at(a) Mod 400) = 399 Then shakeT = 40 : Message "ROOOAAAR!", 60 : Sfx.Play 2, 600, -8, 15, 50, 1
  End Select
  If ast(a) = ST_WALK Or ast(a) = ST_BOSS Then
    ' once on the screen, they stay on it (raptors and pterodactyls may fly on past)
    If ax(a) >= cam + 8 And ax(a) <= cam + 248 Then ain(a) = 1
    If ain(a) And kd <> K_RAPTOR And kd <> K_PTERO And kd <> K_QUEEN Then
      If ax(a) < cam + 8 Then ax(a) = cam + 8
      If ax(a) > cam + 248 Then ax(a) = cam + 248
    End If
    If ax(a) < cam - 40 And locked Then ax(a) = cam - 40
    If ax(a) > cam + 296 And locked Then ax(a) = cam + 296
    If az(a) < ZMIN Then az(a) = ZMIN
    If az(a) > ZMAX Then az(a) = ZMAX
  End If
End Sub

' ---------------------------------------------------------------- rocks
Sub Throw(ByVal a As Integer)
  For n = 0 To NP - 1
    If rk(n) = 0 Then
      rk(n) = 1 : rx(n) = ax(a) + af(a) * 12 : rz(n) = az(a) : rh(n) = 30 : rvx(n) = af(a) * 3
      Exit Sub
    End If
  Next
End Sub

' a rock falling (from the Ptero Queen) on x, z
Sub Drop(ByVal x As Integer, ByVal z As Integer)
  For n = 0 To NP - 1
    If rk(n) = 0 Then
      rk(n) = 2 : rx(n) = x : rz(n) = z : rh(n) = 150 : rvx(n) = 0
      Exit Sub
    End If
  Next
End Sub

Sub Rocks()
  Dim sx As Integer
  For n = 0 To NP - 1
    If rk(n) Then
      rx(n) = rx(n) + rvx(n)
      If rk(n) = 2 Then rh(n) = rh(n) - 3
      sx = rx(n) - cam
      If sx < -16 Or sx > 272 Or rh(n) < 0 Then
        rk(n) = 0 : Spr.Hide SP_ROCK + n : Spr.Hide SP_RSH + n
      Else
        If Abs(rx(n) - ax(0)) < 10 And Abs(rz(n) - az(0)) < 7 And rh(n) - ah(0) < 40 And rh(n) >= ah(0) - 4 And inv = 0 And ast(0) < ST_FLY Then
          If rvx(n) < 0 Then sx = -1 Else sx = 1
          Hurt 0, 4, rk(n) - 1, sx
          rk(n) = 0 : Spr.Hide SP_ROCK + n : Spr.Hide SP_RSH + n
        Else
          Spr.Put SP_ROCK + n, sx + 24, rz(n) - rh(n) + 24, GfxData.S_ROCK, 0
          Spr.Put SP_RSH + n, sx + 24, rz(n) + 22, GfxData.S_SHADOW, 0
        End If
      End If
    End If
  Next
End Sub

' ---------------------------------------------------------------- meat
Sub DropMeat(ByVal x As Integer, ByVal z As Integer)
  For n = 0 To NI - 1
    If mk(n) = 0 Then mk(n) = 1 : mx(n) = x : mz(n) = z : Exit Sub
  Next
End Sub

Sub Meat()
  Dim sx As Integer
  For n = 0 To NI - 1
    If mk(n) Then
      sx = mx(n) - cam
      If Abs(mx(n) - ax(0)) < 14 And Abs(mz(n) - az(0)) < 8 And ah(0) < 8 Then
        mk(n) = 0 : Spr.Hide SP_ITEM + n
        ahp(0) = ahp(0) + 12
        If ahp(0) > MAXHP Then ahp(0) = MAXHP
        ShowLife
        AddScore 50
        Sfx.Play 1, 100, -5, 13, 10, 0
      ElseIf sx < -20 Then
        mk(n) = 0 : Spr.Hide SP_ITEM + n
      Else
        Spr.Put SP_ITEM + n, sx + 24, mz(n) + 16, GfxData.S_MEAT, 0
      End If
    End If
  Next
End Sub

' ---------------------------------------------------------------- drawing
' everyone, nearest last (on top): a sort by how far down the feet are
Sub Draw()
  Dim m As Integer, a As Integer, b As Integer, j As Integer
  m = 0
  For a = 0 To NA - 1
    If ak(a) Then order(m) = a : m = m + 1
  Next
  For a = 1 To m - 1
    b = order(a) : j = a - 1
    Do While j >= 0
      If az(order(j)) <= az(b) Then Exit Do
      order(j + 1) = order(j) : j = j - 1
    Loop
    order(j + 1) = b
  Next
  For a = 0 To m - 1
    DrawActor order(a), a
  Next
  For a = m To NA - 1
    Spr.HideRange SP_ACT + a * 9, 9
  Next
  ' sparks and dust
  If sparkT > 0 Then
    sparkT = sparkT - 1
    Spr.Put SP_SPARK, sparkX - cam + 24, sparkY + 24, GfxData.S_SPARK, (sparkT And 2) * 4
  ElseIf sparkT < 0 Then
    sparkT = sparkT + 1
    Spr.Put SP_SPARK, sparkX - cam + 24, sparkY + 24, GfxData.S_DUST, 0
  Else
    Spr.Hide SP_SPARK
  End If
  If rescued > 0 Then
    For k = 0 To 2
      Spr.Put SP_HEART + k, ax(0) - cam + 20 + k * 12, az(0) - 60 - ((rescued * 2 + k * 20) Mod 40) + 32, GfxData.S_HEART, 0
    Next
  End If
End Sub

' actor a drawn in the a-th group of sprite slots (r: its place in the order)
Sub DrawActor(ByVal a As Integer, ByVal r As Integer)
  Dim kd As Integer, sx As Integer, sy As Integer, fr As Integer, p As Integer, sl As Integer, sc As Integer, mir As Integer
  kd = ak(a)
  sl = SP_ACT + r * 9
  sx = ax(a) - cam + 32 : sy = az(a) - ah(a) + 32
  p = aph(a)
  If afl(a) > 0 And (afl(a) And 2) Then p = 1
  If a = 0 And inv > 0 And (inv And 4) Then
    Spr.HideRange sl, 9 : Spr.Hide SP_SHADOW
    Exit Sub
  End If
  If ast(a) = ST_DEAD And (at(a) And 4) Then
    Spr.HideRange sl, 9 : Spr.Hide SP_SHADOW + a
    Exit Sub
  End If
  If af(a) < 0 Then mir = 1 Else mir = 0
  sc = Big(a)
  ' the shadow on the ground
  If sc Then
    Spr.Put SP_SHADOW + a, sx - 16, az(a) + 32 - 12, GfxData.S_SHADOW, Spr.Scale2X
  Else
    Spr.Put SP_SHADOW + a, sx - 8, az(a) + 32 - 12, GfxData.S_SHADOW, 0
  End If
  If ast(a) = ST_DOWN Or (ast(a) = ST_DEAD) Then
    If IsMan(kd) Then
      DrawGroup sl, GfxData.S_DOWN, 3, 2, sx, sy, 1 - mir, p, sc
      Exit Sub
    End If
  End If
  Select Case kd
    Case K_RAPTOR
      fr = (at(a) \ 4) And 1
      If ast(a) = ST_ATK Then fr = 2
      DrawGroup sl, GfxData.S_RAPTOR + fr * 4, 2, 2, sx, sy, mir, p, 0
    Case K_PTERO, K_QUEEN
      fr = (frames \ 6) And 1
      DrawGroup sl, GfxData.S_PTERO + fr * 2, 2, 1, sx, sy - 8 * (1 + sc), mir, p, sc
    Case K_TRIKE
      fr = (frames \ 6) And 1
      If avx(a) = 0 And acool(a) = 0 Then fr = 0
      DrawGroup sl, GfxData.S_TRIKE + fr * 6, 3, 2, sx, sy, mir, p, 1
    Case K_TREX
      fr = (at(a) \ 12) And 1
      If ast(a) = ST_ATK Then
        fr = 0
        If at(a) > 10 Then fr = 1
      ElseIf ast(a) = ST_DOWN Or ast(a) = ST_DEAD Then
        fr = 1
      End If
      DrawGroup sl, GfxData.S_TREX + fr * 9, 3, 3, sx, sy, mir, p, 1
    Case K_OOLA
      DrawGroup sl, GfxData.S_OOLA, 2, 3, sx, sy, mir, p, 0
    Case Else
      DrawMan sl, sx, sy, ManFrame(a), mir, p, sc
  End Select
End Sub

Function ManFrame(ByVal a As Integer) As Integer
  Dim f As Integer
  f = F_STAND
  Select Case ast(a)
    Case ST_WALK
      If a > 0 Or at(a) > 0 Then f = (at(a) \ 6) Mod 4
      If f = 3 Then f = 0
      If a = 0 Then
        If (Keys.Down(Keys.KeyO) Or Keys.Down(Keys.KeyP) Or Keys.Down(Keys.KeyQ) Or Keys.Down(Keys.KeyA)) = 0 And (Keys.Joystick(0) And 15) = 0 Then f = F_STAND
      End If
    Case ST_ATK
      If aat(a) = A_JAB Or aat(a) = A_THROW Then
        If at(a) < 9 Then f = F_JAB
      ElseIf aat(a) = A_SMASH Then
        If at(a) < 10 Then f = F_WINDUP Else f = F_SMASH
      End If
    Case ST_JUMP
      If aat(a) = A_KICK Then f = F_KICK Else f = F_JUMP
    Case ST_HURT, ST_FLY
      f = 8
  End Select
  ManFrame = f
End Function

' a caveman: frame f (8: hurt) at screen sx, sy (the feet)
Sub DrawMan(ByVal sl As Integer, ByVal sx As Integer, ByVal sy As Integer, ByVal f As Integer, ByVal mir As Integer, ByVal p As Integer, ByVal sc As Integer)
  If f = 8 Then
    DrawGroup sl, GfxData.S_HURT, 2, 3, sx, sy, mir, p, sc
  Else
    DrawGroup sl, GfxData.S_MAN + f * 6, 2, 3, sx, sy, mir, p, sc
  End If
End Sub

' w x h cells from pattern b, their bottom middle at sx, sy; mirrored (mir 1), palette p, twice
' the size (sc 1); the rest of the group's 9 slots hidden
Sub DrawGroup(ByVal sl As Integer, ByVal b As Integer, ByVal w As Integer, ByVal h As Integer, ByVal sx As Integer, ByVal sy As Integer, ByVal mir As Integer, ByVal p As Integer, ByVal sc As Integer)
  Dim cx As Integer, cy As Integer, x0 As Integer, y As Integer, cs As Integer, fl As Integer, q As Integer, x As Integer, dx As Integer
  ' (additions only: the multiplies are slow)
  fl = palF(p)
  If sc Then
    cs = 32 : fl = fl Or Spr.Scale2
    If w = 3 Then x0 = sx - 48 Else x0 = sx - 32
    y = sy - 32 : If h > 1 Then y = y - 32
    If h > 2 Then y = y - 32
  Else
    cs = 16
    If w = 3 Then x0 = sx - 24 Else x0 = sx - 16
    y = sy - 16 : If h > 1 Then y = y - 16
    If h > 2 Then y = y - 16
  End If
  dx = cs
  If mir Then
    fl = fl Or Spr.MirrorX
    x0 = x0 + cs : If w = 3 Then x0 = x0 + cs
    dx = -cs
  End If
  q = 0
  For cy = 1 To h
    x = x0
    For cx = 1 To w
      If x < -32 Or x > 320 Or y > 256 Then
        Spr.Hide sl + q
      Else
        Spr.Put sl + q, x, y, b + q, fl
      End If
      q = q + 1 : x = x + dx
    Next
    y = y + cs
  Next
  If q < 9 Then Spr.HideRange sl + q, 9 - q
End Sub

' ---------------------------------------------------------------- the ending: the ride home
Sub Ending()
  Dim t As Integer, bob As Integer
  For k = 0 To NA - 1
    ak(k) = 0
  Next
  Spr.HideRange 0, 90
  stage = 1 : cam = 0
  Colours
  Scene.Sky "656589898DADB1D1D5D5F9F9", 1
  DrawAll
  Scene.Rect 0, 0, 40, 7, GfxData.T_PANEL, 0
  For t = 0 To 899
    cam = cam + 1
    bob = (t \ 8) And 1
    DrawGroup SP_ACT, GfxData.S_BRONTO, 3, 3, 120, 216 - bob, 0, 10, 1
    DrawGroup SP_ACT + 9, GfxData.S_MAN, 2, 3, 118, 176 - bob, 0, 0, 0
    DrawGroup SP_ACT + 18, GfxData.S_OOLA, 2, 3, 98, 174 - bob, 0, 11, 0
    For k = 0 To 2
      Spr.Put SP_HEART + k, 100 + k * 14, 124 - ((t + k * 24) Mod 70), GfxData.S_HEART, 0
    Next
    If t = 10 Then Scene.Text 8, 4, "GROG BEAT THE T-REX", 0
    If t = 200 Then Scene.Text 8, 5, "AND OOLA IS SAFE", 0
    If t = 400 Then Scene.Text 6, 6, "THEY RIDE HOME ON BRONTY", 0
    If t = 650 Then Scene.Rect 0, 4, 40, 3, GfxData.T_PANEL, 0 : Scene.Text 16, 5, "THE END", 0
    Frame
    Scroll
    Spr.Show
    Sfx.Update
    If t = 650 Then Sfx.Play 0, 100, -2, 15, 60, 0
  Next
  Spr.HideRange 0, 90
End Sub
