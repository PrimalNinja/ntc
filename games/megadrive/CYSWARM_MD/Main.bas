' CYBORG SWARM - a swarm shooter for the Sega Mega Drive / Genesis, in NTC BASIC (md platform)
' (c) 2026 Cyborg Unicorn Pty Ltd
'
' The swarm flies in, takes its places in the formation and dives at your fighter. Queens take
' two hits and can beam your fighter up: shoot the Queen while she dives and your fighter comes
' back as a second one beside you (twice the fire). Every fourth stage is a bonus stage.
' Pad: left / right to move, A, B or C to fire, Start to start (and to pause).

Option Explicit

' ---- sprites
Const SP_P1 = 0             ' the fighter
Const SP_P2 = 1             ' the second fighter (rescued)
Const SP_MIS = 2            ' missiles: 2-5
Const SP_EB = 6             ' enemy shots: 6-13
Const SP_BEAM = 14          ' the tractor beam: 14-19
Const SP_PEX = 64           ' the fighter's explosion
Const SP_POP = 65           ' a score shown where a Queen fell
Const SP_TITLE = 66         ' the title's enemies: 66-69

' ---- the playfield (pixels) and the fighter
Const PY = 200              ' the fighter's line
Const PXMIN = 12
Const PXMAX = 244
Const NMIS = 4
Const NEB = 8
Const HUDFONT = 600         ' the HUD's opaque font: tiles 632-726 (the swarm flies behind it)
Const HUDSPACE = 632 + Vdp.Front

' ---- game state
Dim score As Long, hi As Long, nextLife As Long
Dim lives As Integer, stage As Integer, bonusStage As Integer
Dim frames As Integer, phase As Integer, phaseT As Integer
Dim alive As Integer, entering As Integer
Dim padNow As Integer, padWas As Integer, paused As Integer

' the fighter: x in 1/16 pixels, state 0 flying, 1 exploding, 2 waiting, 3 being beamed up,
' 4 none left; dual = a second fighter on the right
Dim px As Integer, pstate As Integer, pt As Integer, dual As Integer, pspin As Integer, pyy As Integer
Dim mx(3) As Integer, my(3) As Integer, ma(3) As Integer
Dim bx(7) As Integer, by(7) As Integer, bdx(7) As Integer, bba(7) As Integer
Dim shots As Long, hits As Long

' the entries: for each enemy (its index) when it starts, its path, where from, mirrored
Dim qn As Integer, qi As Integer
Dim qe(39) As Integer, qt(39) As Integer, qp(39) As Integer, qx(39) As Integer, qy(39) As Integer, qa(39) As Integer, qm(39) As Integer

' the formation's sway and breathing, the dives
Dim swayD As Integer, breath As Integer, breathD As Integer, diveT As Integer
Dim cap(3) As Integer       ' Queen q has captured a fighter (it is enemy 40 + q)
Dim escK(3) As Integer      ' escorts a diving Queen has lost
Dim escN(3) As Integer      ' escorts she set off with

' the tractor beam: the Queen (-1 none), how long
Dim beamQ As Integer, beamT As Integer, freeing As Integer

' the score popup
Dim popT As Integer

' sound: a tune's notes (period, frames), where it is
Dim tune(63) As Integer, tuneN As Integer, tuneI As Integer, tuneW As Integer
Dim starY As Integer, starT As Integer
Dim starCol(5) As Integer
Dim i As Integer, k As Integer
Dim pexT As Integer, pexX As Integer, bonusHits As Integer

' ============================================================
' the start
' ============================================================
Vdp.Colors Gfx.Palettes(), 0, 64
Vdp.Tiles Gfx.Tiles(), 128, Gfx.N_TILES
Swarm.Init
starCol(0) = &HEEE: starCol(1) = &H0EE: starCol(2) = &HE0E: starCol(3) = &H0E0
starCol(4) = &HE88: starCol(5) = &H8CE
Vdp.LoadFont HUDFONT, 1, 15
MakeStars
hi = 20000
Randomize
Do
  Title
  Game
Loop

' ============================================================
' the title
' ============================================================
Sub Title()
  Dim w As Integer
  Cls
  Vdp.HideAll
  Psg.Quiet
  Logo 10, 3
  Vdp.TextPalette 1
  Locate 10, 10: Print "- SCORE ADVANCE -"
  Vdp.TextPalette 0
  Locate 16, 13: Print "50    100"
  Locate 16, 16: Print "80    160"
  Locate 16, 19: Print "150   400 - 1600"
  Vdp.TextPalette 2
  Locate 13, 12: Print "IN FORMATION  DIVING"
  Vdp.TextPalette 3
  Locate 3, 25: Print "(C) 2026 CYBORG UNICORN PTY LTD"
  Vdp.TextFont HUDFONT
  Vdp.TextPalette 1
  Locate 34, 1: Print "HIGH"
  Vdp.TextPalette 0
  ShowNum 33, 2, hi
  Vdp.TextFont 0
  Vdp.Sprite SP_TITLE, 88, 98, Vdp.Size16, Gfx.T_DRONE + Vdp.FlipY + Vdp.Palette * 2
  Vdp.Sprite SP_TITLE + 1, 88, 122, Vdp.Size16, Gfx.T_HORNET + Vdp.FlipY + Vdp.Palette * 2
  Vdp.Sprite SP_TITLE + 2, 88, 146, Vdp.Size16, Gfx.T_QUEEN + Vdp.FlipY + Vdp.Palette
  w = 0
  Do
    Frame
    Vdp.Update
    Psg.Update
    Stars
    w = w + 1
    If (w And 32) = 0 Then
      Vdp.TextPalette 2
      Locate 15, 22: Print "PUSH START"
    Else
      Locate 15, 22: Print "          "
    End If
    padWas = padNow
    padNow = Pad.Read(1)
  Loop Until ((padNow And Pad.Start) <> 0) And ((padWas And Pad.Start) = 0)
  Vdp.TextPalette 0
End Sub

' the logo: CYBORG on one line, SWARM under it, from column x, row y (2 x 2 cells a letter)
Sub Logo(ByVal x As Integer, ByVal y As Integer)
  LogoWord "CYBORG", x, y
  LogoWord "SWARM", x + 1, y + 2
End Sub

Sub LogoWord(ByVal w As String, ByVal x As Integer, ByVal y As Integer)
  Dim j As Integer, c As Integer, tl As Integer
  For j = 1 To Len(w)
    c = InStr(Gfx.LOGO_LETTERS, Mid$(w, j, 1)) - 1
    tl = Gfx.T_LOGO + c * 4 + Vdp.Palette * 2 + Vdp.Front
    Vdp.Cell Vdp.PlaneA, x + (j - 1) * 3, y, tl
    Vdp.Cell Vdp.PlaneA, x + (j - 1) * 3 + 1, y, tl + 1
    Vdp.Cell Vdp.PlaneA, x + (j - 1) * 3, y + 1, tl + 2
    Vdp.Cell Vdp.PlaneA, x + (j - 1) * 3 + 1, y + 1, tl + 3
  Next
End Sub

' ============================================================
' a game
' ============================================================
Sub Game()
  score = 0
  nextLife = 20000
  lives = 2
  stage = 0
  shots = 0
  hits = 0
  dual = 0
  For i = 0 To 3
    cap(i) = 0
  Next
  Cls
  Vdp.HideAll
  px = 128 * 16
  pstate = 0
  Hud
  NextStage
  Do
    Frame
    Vdp.Update
    Psg.Update
    padWas = padNow
    padNow = Pad.Read(1)
    If ((padNow And Pad.Start) <> 0) And ((padWas And Pad.Start) = 0) Then Pause
    Stars
    Player
    Missiles
    Swarm.ptx = px
    Swarm.pty = PY * 16
    Swarm.Step
    Formation
    EnemyShots
    Collide
    Entries
    Dives
    Beam
    FreeFighter
    Popup
    TuneUpdate
    Flow
    frames = frames + 1
  Loop Until phase = 9
End Sub

' Start: stop everything until Start again
Sub Pause()
  Psg.Quiet
  Vdp.TextPalette 2
  Locate 13, 14: Print "PAUSE"
  Do
    Frame
    padWas = padNow
    padNow = Pad.Read(1)
  Loop Until ((padNow And Pad.Start) <> 0) And ((padWas And Pad.Start) = 0)
  ClearRow 14
  Vdp.TextPalette 0
End Sub

' the stage's flow: 0 its name, 1 coming in and fighting, 2 cleared, 3 the bonus stage's score,
' 9 game over
Sub Flow()
  phaseT = phaseT + 1
  Select Case phase
    Case 0
      If phaseT = 150 Then
        ClearRow 14
        ClearRow 16
        phase = 1
        phaseT = 0
      End If
    Case 1
      If (qi >= qn) And (Remaining() = 0) And (beamQ < 0) And (freeing = 0) Then
        If OnScreen() = 0 Then
          phaseT = 0
          If bonusStage Then
            phase = 3
            BonusScore
          Else
            phase = 2
          End If
        End If
      End If
    Case 2
      If phaseT = 60 Then NextStage
    Case 3
      If phaseT = 240 Then
        ClearRow 12
        ClearRow 14
        ClearRow 16
        NextStage
      End If
  End Select
  ' one of two fighters hit: its explosion
  If pexT > 0 Then
    pexT = pexT + 1
    If pexT < 64 Then
      Vdp.Sprite SP_PEX, pexX - 16, PY - 16, Vdp.Size32, Gfx.T_PEXPL + (pexT \ 16) * 16 + Vdp.Palette
    Else
      Vdp.Hide SP_PEX
      pexT = 0
    End If
  End If
  ' the fighter
  If pstate = 1 Then
    pt = pt + 1
    If pt < 64 Then
      Vdp.Sprite SP_PEX, px \ 16 - 16, PY - 16, Vdp.Size32, Gfx.T_PEXPL + (pt \ 16) * 16 + Vdp.Palette
    Else
      Vdp.Hide SP_PEX
      pstate = 2
      pt = 0
    End If
  ElseIf pstate = 2 Then
    pt = pt + 1
    If pt = 30 Then
      If lives = 0 Then
        Vdp.TextPalette 1
        Locate 11, 14: Print "GAME  OVER"
        Vdp.TextPalette 0
        pstate = 4
        pt = 0
      End If
    End If
    If (pt > 90) And (lives > 0) And (OnScreen() = 0) And (beamQ < 0) And (freeing = 0) Then
      lives = lives - 1
      pstate = 0
      px = 128 * 16
      ShowLives
      Locate 13, 14: Print "      "
    ElseIf (pt = 60) And (lives > 0) Then
      ClearRow 14
      Vdp.TextPalette 3
      Locate 13, 14: Print "READY"
      Vdp.TextPalette 0
    End If
  ElseIf pstate = 4 Then
    pt = pt + 1
    If pt = 200 Then
      Vdp.HideAll
      Vdp.Update
      Psg.Quiet
      Results
      phase = 9
    End If
  End If
End Sub

' a row of the playfield cleared (its 32 columns)
Sub ClearRow(ByVal r As Integer)
  Locate 1, r
  Print Space$(32);
End Sub

' how many of the 40 are still there (any state)
Function Remaining() As Integer
  Dim j As Integer, c As Integer
  c = 0
  For j = 0 To 39
    If Swarm.es(j) <> 0 Then c = c + 1
  Next
  Remaining = c
End Function

' how many enemies are flying (not in the formation, not gone)
Function OnScreen() As Integer
  Dim j As Integer, c As Integer
  c = 0
  For j = 0 To 43
    If (Swarm.es(j) <> 0) And (Swarm.es(j) <> Swarm.S_FORM) And (Swarm.es(j) <> Swarm.S_HELD) Then c = c + 1
  Next
  OnScreen = c
End Function

' the next stage: its name and its entries
Sub NextStage()
  stage = stage + 1
  bonusStage = ((stage Mod 4) = 3)
  phase = 0
  phaseT = 0
  frames = 0
  beamQ = -1
  freeing = 0
  breath = 0
  breathD = 1
  swayD = 4
  Swarm.fcx = 128 * 16
  Swarm.sprx = 128
  Swarm.spry = 256
  diveT = 200
  For i = 0 To 43
    Swarm.es(i) = 0
    If i < 40 Then Swarm.eh(i) = 1
  Next
  For i = 0 To 3
    Swarm.eh(i) = 2
    Swarm.ek(i) = Swarm.K_QUEEN
    Swarm.ek(40 + i) = Swarm.K_FIGHTER
    Swarm.eo(40 + i) = i
  Next
  For i = 4 To 19
    Swarm.ek(i) = Swarm.K_HORNET
  Next
  For i = 20 To 39
    Swarm.ek(i) = Swarm.K_DRONE
  Next
  For i = 0 To NEB - 1
    bba(i) = 0
    Vdp.Hide SP_EB + i
  Next
  HideBeam
  Vdp.Hide SP_POP
  alive = 40
  bonusHits = 0
  If bonusStage Then
    BonusEntries
    Vdp.TextPalette 3
    Locate 11, 14: Print "BONUS STAGE"
    Vdp.TextPalette 0
    TuneStart 2
  Else
    StageEntries
    Vdp.TextPalette 3
    Locate 13, 14: Print "STAGE "; stage
    Vdp.TextPalette 0
    TuneStart 1
  End If
  If pstate = 0 Then
    Vdp.TextPalette 1
    Locate 13, 16: Print "READY"
    Vdp.TextPalette 0
  End If
  Hud
End Sub

' ============================================================
' the entries
' ============================================================
' a group: n enemies from the list s (their indices, "," between), from x, y facing a, on path p,
' mirrored m, the first at frame t0, then every dt frames
Sub Group(ByVal s As String, ByVal p As Integer, ByVal x0 As Integer, ByVal y0 As Integer, ByVal a As Integer, ByVal m As Integer, ByVal t0 As Integer, ByVal dt As Integer)
  Dim j As Integer, c As Integer, v As Integer
  j = 1
  c = 0
  Do While j <= Len(s)
    v = Val(Mid$(s, j))
    qe(qn) = v
    qt(qn) = t0 + c * dt
    qp(qn) = p
    qx(qn) = x0
    qy(qn) = y0
    qa(qn) = a
    qm(qn) = m
    qn = qn + 1
    c = c + 1
    Do While (j <= Len(s)) And (Mid$(s, j, 1) <> ",")
      j = j + 1
    Loop
    j = j + 1
  Loop
End Sub

' a normal stage: 5 waves of 8
Sub StageEntries()
  qn = 0
  qi = 0
  ' two columns from the top: Drones on the left, Hornets on the right
  Group "24,34,25,35", Paths.P_TOP, 104, -8, 512, 0, 0, 10
  Group "7,15,8,16", Paths.P_TOP, 152, -8, 512, 1, 0, 10
  ' Queens and Hornets from the bottom left
  Group "0,4,1,5,2,10,3,11", Paths.P_SIDE, -8, 184, 128, 0, 170, 9
  ' Hornets from the bottom right
  Group "6,12,9,13,14,17,18,19", Paths.P_SIDE, 264, 184, 896, 1, 330, 9
  ' Drones from the top right, then the top left
  Group "26,36,27,37,28,38,29,39", Paths.P_TOP, 152, -8, 512, 1, 490, 9
  Group "20,30,21,31,22,32,23,33", Paths.P_TOP, 104, -8, 512, 0, 650, 9
End Sub

' a bonus stage: 5 groups of 8 through and away, no shots
Sub BonusEntries()
  Dim g As Integer
  qn = 0
  qi = 0
  g = (stage \ 4) Mod 3
  Group "20,21,22,23,24,25,26,27", Paths.P_C1, 104, -8, 512, 2, 0, 8
  Group "4,5,6,7,8,9,10,11", Paths.P_C2, -8, 160, 200, 2, 150, 8
  Group "12,13,14,15,16,17,18,19", Paths.P_C2, 264, 160, 824, 3, 300, 8
  Group "0,28,1,29,2,30,3,31", Paths.P_C3 + g * 0, 152, -8, 512, 3, 450, 8
  Group "32,33,34,35,36,37,38,39", Paths.P_C4, -8, 40, 300, 2, 600, 8
End Sub

' the entries due now
Sub Entries()
  Do While qi < qn
    If (phase <> 1) Or (frames < qt(qi) + 150) Then Exit Sub
    i = qe(qi)
    Swarm.Launch i, qp(qi), qx(qi), qy(qi), qa(qi), qm(qi)
    If (i < 4) And cap(i) Then Swarm.es(40 + i) = Swarm.S_HELD
    qi = qi + 1
  Loop
End Sub

' ============================================================
' the formation: it sways while they come in, then breathes
' ============================================================
Sub Formation()
  If qi < qn Then
    Swarm.fcx = Swarm.fcx + swayD
    If (Swarm.fcx > 144 * 16) Or (Swarm.fcx < 112 * 16) Then swayD = -swayD
  Else
    If Swarm.fcx > 128 * 16 Then
      Swarm.fcx = Swarm.fcx - 4
    ElseIf Swarm.fcx < 128 * 16 Then
      Swarm.fcx = Swarm.fcx + 4
    End If
    If (frames And 1) = 0 Then
      breath = breath + breathD
      If (breath >= 32) Or (breath <= 0) Then breathD = -breathD
      Swarm.sprx = 128 + breath
      Swarm.spry = 256 + breath
    End If
  End If
End Sub

' ============================================================
' the fighter
' ============================================================
Sub Player()
  Dim v As Integer
  If pstate = 3 Then
    ' being beamed up: turning round, rising to the Queen
    pspin = pspin + 1
    If pyy > Swarm.ey(beamQ) \ 16 + 20 Then pyy = pyy - 1
    v = (pspin \ 3) And 15
    FighterSprite SP_P1, px \ 16, pyy, v, 1
    If (pyy <= Swarm.ey(beamQ) \ 16 + 20) Then Captured
    Exit Sub
  End If
  If pstate <> 0 Then
    Vdp.Hide SP_P1
    Vdp.Hide SP_P2
    Exit Sub
  End If
  If (padNow And Pad.Left) <> 0 Then px = px - 32
  If (padNow And Pad.Right) <> 0 Then px = px + 32
  If px < PXMIN * 16 Then px = PXMIN * 16
  If dual Then
    If px > (PXMAX - 16) * 16 Then px = (PXMAX - 16) * 16
  Else
    If px > PXMAX * 16 Then px = PXMAX * 16
  End If
  FighterSprite SP_P1, px \ 16, PY, 0, 0
  If dual Then
    FighterSprite SP_P2, px \ 16 + 16, PY, 0, 0
  Else
    Vdp.Hide SP_P2
  End If
  ' fire: A, B or C pressed
  If ((padNow And (Pad.A Or Pad.B Or Pad.C)) <> 0) And ((padWas And (Pad.A Or Pad.B Or Pad.C)) = 0) And (phase = 1) Then Fire
End Sub

' the fighter's sprite at x, y (its middle), facing direction dir (0-15: 0 up), red if captured
Sub FighterSprite(ByVal sp As Integer, ByVal x As Integer, ByVal y As Integer, ByVal dir As Integer, ByVal red As Integer)
  Dim f As Integer, fl As Integer
  If dir <= 4 Then
    f = dir: fl = 0
  ElseIf dir <= 8 Then
    f = 8 - dir: fl = Vdp.FlipY
  ElseIf dir <= 12 Then
    f = dir - 8: fl = Vdp.FlipX Or Vdp.FlipY
  Else
    f = 16 - dir: fl = Vdp.FlipX
  End If
  If red Then
    fl = fl + Vdp.Palette * 3
  Else
    fl = fl + Vdp.Palette
  End If
  Vdp.Sprite sp, x - 8, y - 8, Vdp.Size16, Gfx.T_FIGHTER + f * 4 + fl
End Sub

Sub Fire()
  Dim j As Integer, c As Integer, need As Integer
  need = 1
  If dual Then need = 2
  c = 0
  For j = 0 To NMIS - 1
    If ma(j) = 0 Then c = c + 1
  Next
  If c < need Then Exit Sub
  If (dual = 0) And (c < 3) Then Exit Sub      ' one fighter: 2 missiles at a time
  For j = 0 To NMIS - 1
    If (ma(j) = 0) And (need > 0) Then
      ma(j) = 1
      mx(j) = px
      If need = 1 And dual Then mx(j) = px + 256
      my(j) = (PY - 8) * 16
      need = need - 1
    End If
  Next
  shots = shots + 1
  Psg.Play 0, 160, 26, 11, 10
End Sub

Sub Missiles()
  Dim j As Integer
  For j = 0 To NMIS - 1
    If ma(j) Then
      my(j) = my(j) - 112
      If my(j) < 0 Then
        ma(j) = 0
        Vdp.Hide SP_MIS + j
      Else
        Vdp.Sprite SP_MIS + j, mx(j) \ 16 - 4, my(j) \ 16 - 4, Vdp.Size8, Gfx.T_MISSILE + Vdp.Palette
      End If
    End If
  Next
End Sub

' ============================================================
' enemy shots
' ============================================================
Sub EnemyShots()
  Dim j As Integer, e As Integer, dy As Integer
  ' those that have just aimed may shoot
  For j = 0 To Swarm.fqn - 1
    e = Swarm.fq(j)
    If (bonusStage = 0) And (pstate = 0) And (Rnd(100) < 30 + stage * 6) Then
      If Swarm.ey(e) < 150 * 16 Then
        For k = 0 To NEB - 1
          If bba(k) = 0 Then
            bba(k) = 1
            bx(k) = Swarm.ex(e)
            by(k) = Swarm.ey(e) + 128
            dy = PY * 16 - by(k)
            If dy < 256 Then dy = 256
            bdx(k) = (px - bx(k)) \ (dy \ 64)
            If bdx(k) > 40 Then bdx(k) = 40
            If bdx(k) < -40 Then bdx(k) = -40
            Exit For
          End If
        Next
      End If
    End If
  Next
  Swarm.fqn = 0
  For j = 0 To NEB - 1
    If bba(j) Then
      bx(j) = bx(j) + bdx(j)
      by(j) = by(j) + 64
      If by(j) > 228 * 16 Then
        bba(j) = 0
        Vdp.Hide SP_EB + j
      Else
        Vdp.Sprite SP_EB + j, bx(j) \ 16 - 4, by(j) \ 16 - 4, Vdp.Size8, Gfx.T_EBULLET + Vdp.Palette * 2
      End If
    End If
  Next
End Sub

' ============================================================
' collisions
' ============================================================
Sub Collide()
  Dim j As Integer, e As Integer
  For j = 0 To NMIS - 1
    If ma(j) Then
      e = Swarm.Hit(mx(j), my(j), 7 * 16)
      If e >= 0 Then
        ma(j) = 0
        Vdp.Hide SP_MIS + j
        Shot e
      End If
    End If
  Next
  If pstate <> 0 Then Exit Sub
  ' the enemy shots, the enemies themselves
  For j = 0 To NEB - 1
    If bba(j) Then
      If Abs(bx(j) - px) < 6 * 16 And Abs(by(j) - PY * 16) < 8 * 16 Then
        bba(j) = 0
        Vdp.Hide SP_EB + j
        FighterHit 0
        Exit Sub
      End If
      If dual Then
        If Abs(bx(j) - px - 256) < 6 * 16 And Abs(by(j) - PY * 16) < 8 * 16 Then
          bba(j) = 0
          Vdp.Hide SP_EB + j
          FighterHit 1
          Exit Sub
        End If
      End If
    End If
  Next
  e = Swarm.Hit(px, PY * 16, 11 * 16)
  If e >= 0 Then
    If (Swarm.es(e) <> Swarm.S_FORM) And (Swarm.es(e) <> Swarm.S_HELD) Then
      Kill e, 0
      FighterHit 0
      Exit Sub
    End If
  End If
  If dual Then
    e = Swarm.Hit(px + 256, PY * 16, 11 * 16)
    If e >= 0 Then
      If (Swarm.es(e) <> Swarm.S_FORM) And (Swarm.es(e) <> Swarm.S_HELD) Then
        Kill e, 0
        FighterHit 1
      End If
    End If
  End If
End Sub

' a missile hit enemy e
Sub Shot(ByVal e As Integer)
  hits = hits + 1
  If (Swarm.ek(e) = Swarm.K_QUEEN) And (Swarm.eh(e) = 2) Then
    Swarm.eh(e) = 1
    Psg.Play 1, 80, 10, 13, 14
    Exit Sub
  End If
  Kill e, 1
End Sub

' enemy e gone (shot or crashed into the fighter)
Sub Kill(ByVal e As Integer, ByVal byShot As Integer)
  Dim s As Integer, pts As Integer, diving As Integer, q As Integer, c As Integer
  s = Swarm.es(e)
  diving = (s <> Swarm.S_FORM)
  Swarm.es(e) = Swarm.S_DYING
  Swarm.ef(e) = 0
  If e < 40 Then alive = alive - 1
  Psg.Play 3, 5, 0, 13, 18
  Select Case Swarm.ek(e)
    Case Swarm.K_DRONE
      pts = 50
      If diving Then pts = 100
    Case Swarm.K_HORNET
      pts = 80
      If diving Then pts = 160
      If s = Swarm.S_ESCORT Then
        q = Swarm.eo(e)
        escK(q) = escK(q) + 1
      End If
    Case Swarm.K_QUEEN
      pts = 150
      If diving Then
        pts = 400
        If escN(e) > 0 Then
          If escK(e) >= 2 Then
            pts = 1600
          ElseIf escK(e) = 1 Then
            pts = 800
          End If
        End If
        PopupAt e, pts
      End If
      If beamQ = e Then
        HideBeam
        beamQ = -1
        If pstate = 3 Then pstate = 0
      End If
      If cap(e) Then
        c = 40 + e
        cap(e) = 0
        If (s = Swarm.S_FORM) Or (pstate <> 0) Or dual Then
          ' in the formation: the fighter turns on you, and leaves
          Swarm.Dive c, Paths.P_ROGUE, 2
        Else
          ' diving: the fighter is free - it comes down beside yours
          Swarm.es(c) = Swarm.S_FREEFLY
          freeing = c
          pspin = 0
        End If
      End If
    Case Swarm.K_FIGHTER
      pts = 500
      If s = Swarm.S_HELD Then pts = 1000
      q = Swarm.eo(e)
      cap(q) = 0
      If freeing = e Then freeing = 0
  End Select
  If bonusStage Then
    pts = 100
    If byShot Then bonusHits = bonusHits + 1
  End If
  AddScore pts
End Sub

' the fighter (or the second one: side 1) is hit
Sub FighterHit(ByVal side As Integer)
  Psg.Play 3, 6, 0, 15, 60
  Psg.Play 1, 300, 6, 14, 60
  If dual Then
    ' one of the two: the other flies on
    dual = 0
    pexX = px \ 16
    If side = 1 Then
      pexX = pexX + 16
    Else
      px = px + 256
    End If
    Vdp.Hide SP_P2
    pexT = 1
    Exit Sub
  End If
  pstate = 1
  pt = 0
  Vdp.Hide SP_P1
End Sub

' ============================================================
' dives
' ============================================================
Sub Dives()
  Dim e As Integer, tries As Integer, c As Integer, flying As Integer, m As Integer, q As Integer
  If bonusStage Or (phase <> 1) Or (qi < qn) Or (pstate <> 0) Then Exit Sub
  diveT = diveT - 1
  If diveT > 0 Then Exit Sub
  diveT = 70 - stage * 4
  If diveT < 24 Then diveT = 24
  flying = OnScreen()
  If flying >= 2 + stage \ 2 Then Exit Sub
  ' pick one in the formation
  For tries = 1 To 8
    e = Rnd(40)
    If Swarm.es(e) = Swarm.S_FORM Then Exit For
  Next
  If Swarm.es(e) <> Swarm.S_FORM Then Exit Sub
  m = 0
  If ((e >= 4) And (e < 20) And (((e - 4) Mod 8) >= 4)) Or ((e >= 20) And (((e - 20) Mod 10) >= 5)) Or ((e < 4) And (e >= 2)) Then m = 1
  Select Case Swarm.ek(e)
    Case Swarm.K_DRONE
      Swarm.Dive e, Paths.P_DRONE, m
    Case Swarm.K_HORNET
      Swarm.Dive e, Paths.P_HORNET, m
    Case Swarm.K_QUEEN
      If (cap(e) = 0) And (dual = 0) And (beamQ < 0) And (freeing = 0) And (Rnd(100) < 45) Then
        ' down to beam the fighter up
        Swarm.Dive e, Paths.P_BEAM, m
        Swarm.tx(e) = px
        If Swarm.tx(e) < 40 * 16 Then Swarm.tx(e) = 40 * 16
        If Swarm.tx(e) > 216 * 16 Then Swarm.tx(e) = 216 * 16
        Swarm.ty(e) = 120 * 16
        beamQ = e
        beamT = -1
      Else
        ' with up to two Hornets beside her
        Swarm.Dive e, Paths.P_QUEEN, m
        escN(e) = 0
        escK(e) = 0
        For q = 4 To 11
          If (Swarm.es(q) = Swarm.S_FORM) And (escN(e) < 2) Then
            c = (q - 4) + 1
            If Abs(c - (e + 3)) <= 1 Then
              Swarm.es(q) = Swarm.S_ESCORT
              Swarm.eo(q) = e
              Swarm.tx(q) = 256 - 512 * escN(e)
              Swarm.ty(q) = Paths.P_ESCAPE
              escN(e) = escN(e) + 1
            End If
          End If
        Next
      End If
  End Select
  Psg.Play 2, 100, 3, 7, 40
End Sub

' ============================================================
' the tractor beam
' ============================================================
Sub Beam()
  Dim q As Integer, bxx As Integer, byy As Integer, pieces As Integer, j As Integer, v As Integer
  If beamQ < 0 Then Exit Sub
  q = beamQ
  If Swarm.es(q) <> Swarm.S_BEAM Then
    If beamT >= 0 Then HideBeam: beamQ = -1
    Exit Sub
  End If
  beamT = beamT + 1
  If pstate = 3 Then
    ' a fighter on its way up: the beam stays until it arrives
    If beamT > 150 Then beamT = 150
  End If
  pieces = 0
  If beamT < 150 Then
    pieces = beamT \ 14 + 1
  ElseIf beamT < 192 Then
    pieces = 3 - (beamT - 150) \ 14
  End If
  If pieces > 3 Then pieces = 3
  bxx = Swarm.ex(q) \ 16
  byy = Swarm.ey(q) \ 16 + 8
  For j = 0 To 2
    If j < pieces Then
      v = Gfx.T_BEAM + j * 12 + Vdp.Palette * 3
      Vdp.Sprite SP_BEAM + j * 2, bxx - 24, byy + j * 32, 11, v
      Vdp.Sprite SP_BEAM + j * 2 + 1, bxx, byy + j * 32, 11, v + Vdp.FlipX
    Else
      Vdp.Hide SP_BEAM + j * 2
      Vdp.Hide SP_BEAM + j * 2 + 1
    End If
  Next
  ' the beam's colours run down it, and it warbles
  If (beamT And 3) = 0 Then
    v = (beamT \ 4) And 3
    Vdp.Color 48 + 9 + v, &HEEC
    Vdp.Color 48 + 9 + ((v + 1) And 3), &HC84
    Vdp.Color 48 + 9 + ((v + 2) And 3), &HE62
    Vdp.Color 48 + 9 + ((v + 3) And 3), &HA40
    If pieces > 0 Then Psg.Play 2, 60 + (beamT And 4) * 8, 0, 9, 6
  End If
  ' caught?
  If (pstate = 0) And (pieces = 3) And (beamT < 150) And (dual = 0) Then
    If Abs(px - Swarm.ex(q)) < 20 * 16 Then
      pstate = 3
      pspin = 0
      pyy = PY
      Psg.Play 1, 120, 4, 12, 90
    End If
  End If
  If beamT = 192 Then
    HideBeam
    beamQ = -1
    Swarm.Dive q, Paths.P_UP, 0
    Swarm.ea(q) = 0
  End If
End Sub

Sub HideBeam()
  Dim j As Integer
  For j = 0 To 5
    Vdp.Hide SP_BEAM + j
  Next
End Sub

' the fighter has reached the Queen: it is hers now
Sub Captured()
  Dim q As Integer
  q = beamQ
  cap(q) = 1
  Swarm.es(40 + q) = Swarm.S_HELD
  Swarm.ek(40 + q) = Swarm.K_FIGHTER
  Swarm.eo(40 + q) = q
  Vdp.Hide SP_P1
  HideBeam
  beamQ = -1
  Swarm.Dive q, Paths.P_UP, 0
  Swarm.ea(q) = 0
  Vdp.TextPalette 1
  Locate 9, 14: Print "FIGHTER CAPTURED"
  Vdp.TextPalette 0
  pstate = 2
  pt = 0
  Psg.Play 2, 200, 8, 12, 60
End Sub

' a freed fighter coming down to dock beside the fighter
Sub FreeFighter()
  Dim c As Integer, tx As Integer, ty As Integer
  If freeing = 0 Then Exit Sub
  c = freeing
  If pstate <> 0 Then
    ' no fighter to join: it flies away
    Swarm.Dive c, Paths.P_ROGUE, 2
    freeing = 0
    Exit Sub
  End If
  pspin = pspin + 1
  tx = px + 256
  ty = PY * 16
  If Swarm.ex(c) < tx - 32 Then Swarm.ex(c) = Swarm.ex(c) + 32
  If Swarm.ex(c) > tx + 32 Then Swarm.ex(c) = Swarm.ex(c) - 32
  If Abs(Swarm.ex(c) - tx) <= 32 Then Swarm.ex(c) = tx
  If Swarm.ey(c) < ty Then Swarm.ey(c) = Swarm.ey(c) + 32
  If Swarm.ey(c) > ty Then Swarm.ey(c) = ty
  Swarm.ea(c) = (pspin * 32) And 1023
  If (Swarm.ex(c) = tx) And (Swarm.ey(c) = ty) Then
    Swarm.es(c) = 0
    freeing = 0
    dual = 1
    Psg.Play 2, 120, -3, 12, 40
  End If
End Sub

' ============================================================
' score, lives, the HUD
' ============================================================
Sub AddScore(ByVal p As Integer)
  score = score + p
  If score >= nextLife Then
    lives = lives + 1
    If nextLife = 20000 Then
      nextLife = 70000
    Else
      nextLife = nextLife + 70000
    End If
    ShowLives
    Psg.Play 2, 200, -6, 12, 30
  End If
  If score > hi Then hi = score
  Vdp.TextFont HUDFONT
  Vdp.TextPalette 0
  ShowNum 33, 5, score
  If score = hi Then ShowNum 33, 2, hi
  Vdp.TextFont 0
End Sub

' a Long right aligned in 7 columns from column x, row y
Sub ShowNum(ByVal x As Integer, ByVal y As Integer, ByVal v As Long)
  Dim s As String
  s = "       " & CStr(v)
  Locate x, y
  Print Right$(s, 7);
End Sub

Sub Hud()
  Vdp.Fill Vdp.PlaneA, 32, 0, 8, 28, HUDSPACE
  Vdp.TextFont HUDFONT
  Vdp.TextPalette 1
  Locate 34, 1: Print "HIGH"
  Locate 34, 4: Print "1UP"
  Vdp.TextPalette 0
  ShowNum 33, 2, hi
  ShowNum 33, 5, score
  Vdp.TextPalette 2
  Locate 34, 8: Print "STAGE"
  Vdp.TextPalette 0
  ShowNum 33, 9, stage
  Vdp.TextFont 0
  Flags
  ShowLives
End Sub

' the reserve fighters, bottom right
Sub ShowLives()
  Dim j As Integer, x As Integer, y As Integer, tl As Integer
  For j = 0 To 5
    x = 33 + (j Mod 3) * 2
    y = 24 + (j \ 3) * 2
    If j < lives Then
      tl = Gfx.T_LIFE + Vdp.Palette + Vdp.Front
      Vdp.Cell Vdp.PlaneA, x, y, tl
      Vdp.Cell Vdp.PlaneA, x + 1, y, tl + 1
      Vdp.Cell Vdp.PlaneA, x, y + 1, tl + 2
      Vdp.Cell Vdp.PlaneA, x + 1, y + 1, tl + 3
    Else
      Vdp.Fill Vdp.PlaneA, x, y, 2, 2, HUDSPACE
    End If
  Next
End Sub

' the stage flags (a big one for 5)
Sub Flags()
  Dim j As Integer, s As Integer, c As Integer, tl As Integer
  Vdp.Fill Vdp.PlaneA, 33, 11, 7, 6, HUDSPACE
  s = stage
  c = 0
  Do While (s >= 5) And (c < 7)
    tl = Gfx.T_FLAG5 + Vdp.Front
    Vdp.Cell Vdp.PlaneA, 33 + c, 11, tl
    Vdp.Cell Vdp.PlaneA, 33 + c, 12, tl + 1
    s = s - 5
    c = c + 1
  Loop
  Do While (s > 0) And (c < 7)
    tl = Gfx.T_FLAG1 + Vdp.Front
    Vdp.Cell Vdp.PlaneA, 33 + c, 11, tl
    Vdp.Cell Vdp.PlaneA, 33 + c, 12, tl + 1
    s = s - 1
    c = c + 1
  Loop
End Sub

' the bonus stage's result
Sub BonusScore()
  Dim b As Long
  If bonusHits >= 40 Then
    b = 10000
  Else
    b = bonusHits * 100
  End If
  Vdp.TextPalette 3
  Locate 8, 12: Print "NUMBER OF HITS  "; bonusHits
  If bonusHits >= 40 Then
    Vdp.TextPalette 1
    Locate 12, 14: Print "PERFECT !"
  End If
  Vdp.TextPalette 2
  Locate 8, 16: Print "BONUS  "; b
  Vdp.TextPalette 0
  score = score + b
  AddScore 0
  TuneStart 3
End Sub

' the score a Queen was worth, where she fell
Sub PopupAt(ByVal e As Integer, ByVal p As Integer)
  Dim tl As Integer
  Select Case p
    Case 400: tl = 0
    Case 800: tl = 1
    Case 1600: tl = 2
    Case Else: Exit Sub
  End Select
  Vdp.Sprite SP_POP, Swarm.ex(e) \ 16 - 12, Swarm.ey(e) \ 16 - 4, 12, Gfx.T_POP + tl * 4 + Vdp.Palette * 2 + Vdp.Front
  popT = 60
End Sub

Sub Popup()
  If popT > 0 Then
    popT = popT - 1
    If popT = 0 Then Vdp.Hide SP_POP
  End If
End Sub

' the game's end: shots, hits, the ratio
Sub Results()
  Dim r As Long
  Cls
  Vdp.TextPalette 1
  Locate 13, 8: Print "- RESULTS -"
  Vdp.TextPalette 2
  Locate 8, 12: Print "SHOTS FIRED"
  Locate 8, 15: Print "NUMBER OF HITS"
  Locate 8, 18: Print "HIT-MISS RATIO"
  Vdp.TextPalette 0
  ShowNum 25, 12, shots
  ShowNum 25, 15, hits
  r = 0
  If shots > 0 Then r = (hits * 1000) \ shots
  Locate 27, 18: Print r \ 10; "."; r Mod 10; " %"
  For i = 1 To 300
    Frame
    Stars
  Next
End Sub

' ============================================================
' the stars: plane B, scrolled down, twinkling
' ============================================================
Sub MakeStars()
  Dim j As Integer
  For j = 1 To 110
    Vdp.Cell Vdp.PlaneB, Rnd(32), Rnd(32), Gfx.T_STAR + Rnd(6)
  Next
End Sub

Sub Stars()
  If pstate <> 1 Then
    starY = starY - 1
    Vdp.ScrollY Vdp.PlaneB, starY
  End If
  starT = starT + 1
  If (starT And 7) = 0 Then
    k = (starT \ 8) Mod 6
    Vdp.Color 9 + k, 0
    Vdp.Color 9 + ((k + 3) Mod 6), starCol(k)
  End If
End Sub

' ============================================================
' tunes (the PSG's tone channel 2): period, frames ... 0
' ============================================================
Sub TuneStart(ByVal which As Integer)
  Dim s As String
  Select Case which
    Case 1
      s = "214,8,170,8,143,8,107,16,143,8,107,24,0,8,127,8,143,8,160,8,170,16,214,24"
    Case 2
      s = "143,6,127,6,113,6,107,6,113,6,127,6,143,12,107,12,95,12,85,24"
    Case 3
      s = "107,6,0,2,107,6,0,2,107,6,95,6,85,6,80,24"
  End Select
  tuneN = 0
  k = 1
  Do While k <= Len(s)
    tune(tuneN) = Val(Mid$(s, k))
    tuneN = tuneN + 1
    Do While (k <= Len(s)) And (Mid$(s, k, 1) <> ",")
      k = k + 1
    Loop
    k = k + 1
  Loop
  tuneI = 0
  tuneW = 0
End Sub

Sub TuneUpdate()
  If tuneI >= tuneN Then Exit Sub
  If tuneW > 0 Then
    tuneW = tuneW - 1
    Exit Sub
  End If
  If tune(tuneI) > 0 Then Psg.Play 2, tune(tuneI), 0, 11, tune(tuneI + 1)
  tuneW = tune(tuneI + 1) - 1
  tuneI = tuneI + 2
End Sub
