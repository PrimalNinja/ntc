' HELI ATTACK - a Defender for the ZX Spectrum Next, with a helicopter, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' UFOs over the city, eight screens of it, end to end (fly off one end and you come back on at the
' other). Landers come down for the people on the ground and take them up: get one to the top and
' it turns into a mutant. Shoot a lander that's carrying someone, catch them as they fall and put
' them down again. Bombers lay mines, pods burst into swarmers, and take too long and the baiters
' come for you. Lose everyone on the ground and every lander turns mutant.
'
' Keys: Q A O P fly (or S X Z C, or 5 6 7 8, or a joystick). Space (or M, fire): shoot.
'       B (or Enter, fire 2): smart bomb - everything on the screen. H: hyperspace (you might not
'       come out of it in one piece).
'
' The city is one Layer 2 picture the hardware scrolls round (Scene.cls); the helicopter, the UFOs,
' the people and the explosions are sprites; the bullets and your tracers are moved and checked in
' Z80 (Bul.cls); the scanner and the panel are the tilemap.
Option Explicit
Option Turbo

Const WORLD = 2048, HALF = 1024
Const NU = 20, NP = 10, NB = 8
' sprite slots (Bul has 54-127)
Const SP_HELI = 0, SP_UFO = 2, SP_PEOPLE = 22, SP_BOOM = 32, SP_BEAM = 40, SP_WIN = 44, SP_HYPER = 45
' UFO kinds
Const K_LANDER = 1, K_MUTANT = 2, K_BOMBER = 3, K_POD = 4, K_SWARM = 5, K_BAITER = 6
' where you can fly (paper rows; the scanner is above)
Const YTOP = 44, YLOW = 168, GROUND = 176
Const PINK = 2, BLUE = 3

Dim longText As String Max 80
' the UFOs: kind, x (world pixels), y, x speed (8ths), y speed, a timer, who they've got (-1 none),
' when they fire next, x's 8ths
Dim uk(19) As Integer, ux(19) As Integer, uy(19) As Integer, uvx(19) As Integer, uvy(19) As Integer
Dim ut(19) As Integer, ug(19) As Integer, uf(19) As Integer, ufr(19) As Integer
' the people: 0 gone, 1 walking, 2 carried up, 3 falling, 4 hanging from you; x, y, way, fall speed
Dim ps(9) As Integer, px(9) As Integer, py(9) As Integer, pd(9) As Integer, pv(9) As Integer
Dim bx(7) As Integer, by(7) As Integer, bt(7) As Integer, bnext As Integer
' you: x (8ths of a world pixel), y, speed (8ths a frame), facing
Dim hx As Integer, hy As Integer, hvx As Integer, face As Integer, alive As Integer, inv As Integer, deadT As Integer, cool As Integer
Dim smart As Integer, smartT As Integer, smartWas As Integer, hyperWas As Integer, hyperT As Integer, carry As Integer
Dim camX As Integer, pan As Integer
Dim score As Long, hiscore As Long, lives As Integer, wave As Integer, over As Integer, nextLife As Long
Dim frames As Integer, msgT As Integer, scoreDirty As Integer, waveT As Integer, toCome As Integer, peopleLost As Integer
Dim i As Integer, k As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Scene.Init
Bul.Init GfxData.S_SHOT
Bul.Limits 2000, 2000                   ' (the city joins up end to end: no ends to stop at)
Nx.Layers Nx.OrderSUL                    ' sprites over the panel, the panel over the city
Nx.Reg &H1C, 2                           ' the sprites cut to the paper (x halved: over the border)
Nx.Reg &H19, 16 : Nx.Reg &H19, 143 : Nx.Reg &H19, 32 : Nx.Reg &H19, 223
Nx.Reg &H15, Nx.RegGet(&H15) Or &H20
hiscore = 20000
Do
  Title
  Game
Loop

' ---------------------------------------------------------------- the world joins up end to end
' where world x is on the screen (its paper x: -1024 .. 1023)
Function Sx(ByVal x As Integer) As Integer
  Sx = ((x - camX + WORLD + HALF) And (WORLD - 1)) - HALF
End Function

' from a to b the short way round (-1024 .. 1023)
Function Dif(ByVal a As Integer, ByVal b As Integer) As Integer
  Dif = ((b - a + WORLD + HALF) And (WORLD - 1)) - HALF
End Function

Function Wrap(ByVal x As Integer) As Integer
  Wrap = (x + WORLD) And (WORLD - 1)
End Function

' ---------------------------------------------------------------- the panel and the scanner
Sub Hud()
  Tiles.Fill 0
  Tiles.Rect 0, 0, 40, 4, GfxData.T_HUD
  Tiles.Rect 4, 4, 32, 1, GfxData.T_SCANT
  Tiles.Rect 4, 5, 32, 2, GfxData.T_SCAN
  Tiles.Rect 4, 7, 32, 1, GfxData.T_SCANG
  Tiles.Text 4, 1, "SCORE"
  Tiles.Text 20, 1, "HI " & Right$("000000" & Trim$(Str$(hiscore)), 7)
  Tiles.Text 32, 1, "W" & Right$("0" & Trim$(Str$(wave)), 2)
  ShowScore
  ShowLives
End Sub

Sub ShowScore()
  Tiles.Text 10, 1, Right$("000000" & Trim$(Str$(score)), 7)
  scoreDirty = 0
End Sub

Sub ShowLives()
  For k = 0 To 5
    If k < lives Then Tiles.Put 4 + k, 2, GfxData.T_LIFE Else Tiles.Put 4 + k, 2, GfxData.T_HUD
    If k < smart Then Tiles.Put 12 + k, 2, GfxData.T_SMART Else Tiles.Put 12 + k, 2, GfxData.T_HUD
  Next
End Sub

Sub AddScore(ByVal n As Long)
  score = score + n
  scoreDirty = 1
  If score >= nextLife Then
    nextLife = nextLife + 10000
    lives = lives + 1 : smart = smart + 1
    ShowLives
    Sfx.Play 1, 60, -1, 14, 30, 0
  End If
End Sub

' a message across the middle for t frames (0: until the next)
Sub Message(ByVal m As String, ByVal y As Integer, ByVal t As Integer)
  longText = m
  Tiles.Rect 4, y, 32, 1, 0
  Tiles.Text 4 + (32 - Len(longText)) \ 2, y, longText
  If t Then msgT = t
End Sub

Sub ClearMessages()
  Tiles.Rect 4, 9, 32, 18, 0
End Sub

' the scanner: the whole city in 256 pixels (8 to 1), with you in the middle; every 4th frame
Sub Scanner()
  Dim n As Integer, base As Integer
  If (frames And 3) <> 1 Then Exit Sub
  Tiles.Rect 4, 5, 32, 2, GfxData.T_SCAN
  Tiles.Rect 4, 7, 32, 1, GfxData.T_SCANG
  base = Wrap(hx \ 8 - HALF)
  For n = 0 To NP - 1
    If ps(n) Then Dot base, px(n), py(n), 1
  Next
  For n = 0 To NU - 1
    If uk(n) Then Dot base, ux(n), uy(n), 0
  Next
  If alive Then Dot base, hx \ 8, hy, 2
  ' the part on the screen
  Spr.Put SP_WIN, ((camX - base) And (WORLD - 1)) \ 8 + 32, 44, GfxData.S_WINDOW, Spr.Scale2X
End Sub

Sub Dot(ByVal base As Integer, ByVal x As Integer, ByVal y As Integer, ByVal c As Integer)
  Dim r As Integer, v As Integer
  r = (x - base) And (WORLD - 1)
  v = (y - 40) * 9 \ 141
  If v < 0 Then v = 0
  If v > 8 Then v = 8
  Tiles.Put 4 + r \ 64, 5 + v \ 3, GfxData.T_DOT + c * 12 + (v Mod 3) * 4 + (r And 63) \ 16
End Sub

' ---------------------------------------------------------------- the title
Function FireDown() As Integer
  FireDown = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyM) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
End Function

Sub Title()
  Dim y As Integer
  Spr.HideRange 0, 54 : Spr.Show
  Bul.Reset : Bul.Show
  wave = 1 : lives = 3 : score = 0 : smart = 3
  Hud
  Message "H E L I   A T T A C K", 10, 0
  Message "SAVE THE CITY FROM THE UFOS", 12, 0
  Message "QAOP / SXZC / 5678  FLY", 15, 0
  Message "SPACE SHOOT   B SMART BOMB", 16, 0
  Message "H HYPERSPACE", 17, 0
  Message "CATCH THE PEOPLE THEY DROP!", 19, 0
  Message "(C) 2026 CYBORG UNICORN", 26, 0
  ' a lander comes for someone; you, flying by
  camX = 0 : y = 0 : face = 1 : hy = 144
  Do
    camX = Wrap(camX + 1)
    Scene.Scroll camX
    Spr.Put SP_HELI, 40 + 24 - 8, hy + 24, GfxData.S_HELI + ((frames \ 2) And 1) * 2, 0
    Spr.Put SP_HELI + 1, 40 + 24 + 8, hy + 24, GfxData.S_HELI + ((frames \ 2) And 1) * 2 + 1, 0
    Spr.Put SP_UFO, 200 + 24, 30 + (frames \ 4) Mod 8 + 24, GfxData.S_LANDER + (frames \ 8) Mod 2, 0
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1
    y = y + 1
    If y = 30 Then Message "PRESS SPACE", 23, 0
    If y = 60 Then Tiles.Rect 4, 23, 32, 1, 0 : y = 0
  Loop Until FireDown()
  Do
    Frame
  Loop While FireDown()
  ClearMessages
  Spr.HideRange 0, 54
  Sfx.Play 0, 200, -6, 15, 25, 0
End Sub

' ---------------------------------------------------------------- a game
Sub Game()
  score = 0 : lives = 3 : wave = 1 : over = 0 : smart = 3 : nextLife = 10000
  For k = 0 To NP - 1
    ps(k) = 1
  Next
  Do
    WaveRun
    If over Then Exit Do
    wave = wave + 1
  Loop
  Nx.Reg &H70, 0
  If score > hiscore Then hiscore = score
  Message "GAME OVER", 14, 0
  For k = 1 To 250
    Frame
    Sfx.Update
    If k > 50 And FireDown() Then Exit For
  Next
  ClearMessages
End Sub

' the people back (every fifth wave, or at the start): spread along the ground
Sub People()
  For k = 0 To NP - 1
    ps(k) = 1 : px(k) = k * (WORLD \ NP) + Rnd(100) : py(k) = GROUND - 8 : pd(k) = 1 - 2 * Rnd(2) : pv(k) = 0
  Next
End Sub

Function PeopleLeft() As Integer
  Dim n As Integer
  n = 0
  For k = 0 To NP - 1
    If ps(k) Then n = n + 1
  Next
  PeopleLeft = n
End Function

Sub WaveRun()
  Dim b As Long, t As Integer, clearT As Integer
  Spr.HideRange 0, 54
  Bul.Reset
  For k = 0 To NB - 1
    bt(k) = 0
  Next
  For k = 0 To NU - 1
    uk(k) = 0
  Next
  If wave = 1 Or wave Mod 5 = 0 Then
    People
  Else
    ' the survivors back on the ground
    For k = 0 To NP - 1
      If ps(k) Then ps(k) = 1 : py(k) = GROUND - 8
    Next
  End If
  peopleLost = (PeopleLeft() = 0)
  ' the UFOs: landers come in groups of five; bombers and pods from the start
  toCome = 10 + wave * 2
  If toCome > 25 Then toCome = 25
  For k = 1 To 5 + wave
    If k <= 10 Then NewUFO K_LANDER
  Next
  If wave >= 2 Then
    For k = 1 To 1 + wave \ 2
      If k <= 4 Then NewUFO K_BOMBER
    Next
  End If
  If wave >= 3 Then
    For k = 1 To wave \ 2
      If k <= 3 Then NewUFO K_POD
    Next
  End If
  hx = 200 * 8 : hy = 100 : hvx = 0 : face = 1 : alive = 1 : inv = 100 : deadT = 0 : cool = 0 : smartT = 0 : carry = -1
  smartWas = 1 : hyperWas = 1 : hyperT = 0
  camX = 112 : pan = 0 : waveT = 0 : clearT = 0
  Hud
  Message "WAVE " & Trim$(Str$(wave)), 13, 100
  If peopleLost Then Message "THE CITY IS LOST: MUTANTS!", 15, 100 Else Message "SAVE THE PEOPLE!", 15, 100
  Do
    waveT = waveT + 1
    ' more landers, five at a time
    If toCome > 0 And ((waveT Mod 600) = 0 Or (Attackers() < 4 And (waveT Mod 50) = 0)) Then
      For k = 1 To 5
        If toCome > 0 Then NewUFO K_LANDER
      Next
    End If
    ' too slow: a baiter
    If waveT > 2500 And (waveT Mod 500) = 0 Then NewUFO K_BAITER
    You
    Camera
    UFOs
    Folk
    Booms
    SmartUpdate
    If alive Then Bul.Step Sx(hx \ 8), hy, pan Else Bul.Step 0, 0, pan
    If alive And inv = 0 And smartT = 0 Then
      If Bul.Hit() Then Die
    End If
    DrawHeli
    Scanner
    If scoreDirty And (frames And 3) = 0 Then ShowScore
    If msgT > 0 Then
      msgT = msgT - 1
      If msgT = 0 Then ClearMessages
    End If
    Frame
    Scene.Scroll camX
    Spr.Show
    Bul.Show
    Sfx.Update
    frames = frames + 1
    If alive = 0 And deadT = 0 And lives = 0 Then over = 1 : Exit Sub
    ' all the attackers down (baiters don't count)?
    If toCome = 0 And Attackers() = 0 Then
      clearT = clearT + 1
      If clearT = 30 Then
        t = PeopleLeft()
        b = CLng(wave) * 100 * t
        AddScore b
        Message "WAVE " & Trim$(Str$(wave)) & " CLEARED", 12, 0
        Message Trim$(Str$(t)) & " PEOPLE SAVED: BONUS " & Trim$(Str$(b)), 14, 0
        Sfx.Play 0, 100, -2, 15, 50, 0
      End If
      If clearT > 170 Then ClearMessages : Exit Sub
    End If
  Loop
End Sub

Function Attackers() As Integer
  Dim n As Integer, c As Integer
  c = 0
  For n = 0 To NU - 1
    If uk(n) > 0 And uk(n) <> K_BAITER Then c = c + 1
  Next
  Attackers = c
End Function

' ---------------------------------------------------------------- you
Sub You()
  Dim j0 As Integer, mx As Integer, my As Integer, v As Integer, sb As Integer, hy1 As Integer
  If alive = 0 Then
    If deadT > 0 Then
      deadT = deadT - 1
      If deadT = 0 And lives > 0 Then
        alive = 1 : inv = 150 : hy = 100 : hvx = 0 : smart = 3 : ShowLives
      End If
    End If
    Exit Sub
  End If
  ' hyperspace: gone for a moment, then somewhere else (and maybe in pieces)
  If hyperT > 0 Then
    hyperT = hyperT - 1
    If hyperT = 0 Then
      hx = Rnd(WORLD) * 8 : hy = YTOP + Rnd(YLOW - YTOP) : hvx = 0
      camX = Wrap(hx \ 8 - 128) : pan = 0
      Spr.Hide SP_HYPER
      If Rnd(4) = 0 Then Die
    End If
    Exit Sub
  End If
  j0 = Keys.Joystick(0)
  mx = 0 : my = 0
  If Keys.Down(Keys.KeyO) Or Keys.Down(Keys.KeyZ) Or Keys.Down(Keys.KeyLeft) Or (j0 And Keys.JoyLeft) Then mx = -1
  If Keys.Down(Keys.KeyP) Or Keys.Down(Keys.KeyC) Or Keys.Down(Keys.KeyRight) Or (j0 And Keys.JoyRight) Then mx = 1
  If Keys.Down(Keys.KeyQ) Or Keys.Down(Keys.KeyS) Or Keys.Down(Keys.KeyUp) Or (j0 And Keys.JoyUp) Then my = -1
  If Keys.Down(Keys.KeyA) Or Keys.Down(Keys.KeyX) Or Keys.Down(Keys.KeyDown) Or (j0 And Keys.JoyDown) Then my = 1
  If mx <> 0 Then
    face = mx
    hvx = hvx + mx * 3
    If hvx > 40 Then hvx = 40
    If hvx < -40 Then hvx = -40
  Else
    If hvx > 0 Then hvx = hvx - 1
    If hvx < 0 Then hvx = hvx + 1
  End If
  hx = (hx + hvx + WORLD * 8) And (WORLD * 8 - 1)
  hy = hy + my * 2
  If hy < YTOP Then hy = YTOP
  If hy > YLOW Then hy = YLOW
  ' the gun
  If cool > 0 Then cool = cool - 1
  If FireDown() And cool = 0 Then
    v = face * 14 + hvx \ 8
    Bul.Shot Sx(hx \ 8) + face * 14, hy + 3, v, 0, GfxData.S_SHOT
    cool = 4
    Sfx.Play 0, 30, 4, 10, 4, 0
  End If
  ' a smart bomb
  sb = Keys.Down(Keys.KeyB) Or Keys.Down(Keys.KeyEnter) Or ((j0 And Keys.JoyFire2) <> 0)
  If sb And smartWas = 0 And smart > 0 And smartT = 0 Then
    smart = smart - 1 : ShowLives
    smartT = 40
    SmartBomb
    Sfx.Play 2, 31, 0, 15, 60, 1
  End If
  smartWas = sb
  ' hyperspace
  sb = Keys.Down(Keys.KeyH)
  If sb And hyperWas = 0 Then
    hyperT = 30
    Spr.Put SP_HYPER, Sx(hx \ 8) + 24, hy + 24, GfxData.S_STARS, Spr.Scale2
    If carry >= 0 Then ps(carry) = 3 : pv(carry) = 0 : carry = -1
    Sfx.Play 1, 20, 6, 14, 30, 0
  End If
  hyperWas = sb
  If inv > 0 Then inv = inv - 1
  ' someone hanging on: put them down near the ground
  If carry >= 0 Then
    px(carry) = hx \ 8 : py(carry) = hy + 14
    If hy >= YLOW - 4 Then
      ps(carry) = 1 : py(carry) = GROUND - 8
      AddScore 500
      Message "SAFE! 500", 20, 50
      Sfx.Play 1, 80, -3, 14, 20, 0
      carry = -1
    End If
  End If
End Sub

' the view: you a third of the way in from the side you're leaving
Sub Camera()
  Dim want As Integer, was As Integer, d As Integer
  was = camX
  If face > 0 Then want = Wrap(hx \ 8 - 88) Else want = Wrap(hx \ 8 - 168)
  d = Dif(camX, want)
  If d > 7 Then d = 7
  If d < -7 Then d = -7
  camX = Wrap(camX + d)
  pan = Dif(was, camX)
End Sub

Sub DrawHeli()
  Dim fl As Integer, x As Integer, a As Integer, b As Integer
  If alive = 0 Or hyperT > 0 Or (inv And 4) <> 0 Then
    Spr.Hide SP_HELI : Spr.Hide SP_HELI + 1
  Else
    x = Sx(hx \ 8)
    a = GfxData.S_HELI + ((frames \ 2) And 1) * 2
    If face < 0 Then
      fl = Spr.MirrorX : b = a : a = a + 1
    Else
      fl = 0 : b = a + 1
    End If
    Spr.Put SP_HELI, x + 24 - 8, hy + 24, a, fl
    Spr.Put SP_HELI + 1, x + 24 + 8, hy + 24, b, fl
  End If
  If Bul.Sparked() Then Sfx.Play 1, 8, 2, 9, 3, 1
End Sub

Sub Die()
  alive = 0 : deadT = 100 : lives = lives - 1 : ShowLives
  Boom hx \ 8, hy
  Boom hx \ 8 - 10, hy - 6
  Boom hx \ 8 + 10, hy + 6
  k = Bul.Clear()
  If carry >= 0 Then ps(carry) = 3 : pv(carry) = 0 : carry = -1
  Spr.Hide SP_HELI : Spr.Hide SP_HELI + 1
  Sfx.Play 2, 31, 0, 15, 70, 1
  Sfx.Play 1, 300, 10, 15, 50, 0
End Sub

' every UFO on the screen goes, and every bullet
Sub SmartBomb()
  Dim n As Integer, x As Integer
  For n = 0 To NU - 1
    If uk(n) Then
      x = Sx(ux(n))
      If x > -8 And x < 264 Then KillUFO n
    End If
  Next
  k = Bul.Clear()
End Sub

Sub SmartUpdate()
  If smartT = 0 Then Exit Sub
  smartT = smartT - 1
  If smartT = 0 Then Nx.Reg &H70, 0 Else Nx.Reg &H70, (smartT \ 3) And 15
End Sub

' ---------------------------------------------------------------- the UFOs
Sub NewUFO(ByVal kd As Integer)
  Dim n As Integer, m As Integer
  m = -1
  For n = 0 To NU - 1
    If uk(n) = 0 And m < 0 Then m = n
  Next
  If m < 0 Then Exit Sub
  If kd = K_LANDER And peopleLost Then kd = K_MUTANT
  uk(m) = kd : ug(m) = -1 : ut(m) = Rnd(100) : ufr(m) = 0
  uf(m) = 60 + Rnd(120)
  ' somewhere off the screen
  ux(m) = Wrap(camX + 300 + Rnd(WORLD - 600))
  uy(m) = 50 + Rnd(70)
  uvx(m) = 4 + Rnd(6)
  If Rnd(2) Then uvx(m) = -uvx(m)
  uvy(m) = 0
  If kd = K_LANDER Then toCome = toCome - 1
  If kd = K_BAITER Then ux(m) = Wrap(hx \ 8 + 200 * face) : uy(m) = hy
  If kd = K_SWARM Then uvx(m) = 0
End Sub

Sub KillUFO(ByVal n As Integer)
  Dim pts As Integer, j As Integer
  Boom ux(n), uy(n)
  Select Case uk(n)
    Case K_LANDER
      pts = 150
    Case K_MUTANT
      pts = 150
    Case K_BOMBER
      pts = 250
    Case K_POD
      pts = 1000
    Case K_SWARM
      pts = 150
    Case Else
      pts = 200
  End Select
  ' a lander with someone: they fall
  If ug(n) >= 0 Then
    ps(ug(n)) = 3 : pv(ug(n)) = 0
    ug(n) = -1
  End If
  ' a pod: swarmers
  If uk(n) = K_POD Then
    For j = 1 To 3 + Rnd(3)
      Swarmer ux(n), uy(n)
    Next
  End If
  uk(n) = 0
  Bul.Off n
  Spr.Hide SP_UFO + n
  Spr.Hide SP_BEAM + (n And 3)
  AddScore pts
  Sfx.Play 2, 20 + Rnd(10), 4, 14, 18, 1
End Sub

Sub Swarmer(ByVal x As Integer, ByVal y As Integer)
  Dim n As Integer
  For n = 0 To NU - 1
    If uk(n) = 0 Then
      uk(n) = K_SWARM : ux(n) = Wrap(x + Rnd(16) - 8) : uy(n) = y + Rnd(16) - 8 : uvx(n) = 0 : uvy(n) = 0
      ut(n) = Rnd(50) : ug(n) = -1 : uf(n) = 40 + Rnd(60) : ufr(n) = 0
      Exit Sub
    End If
  Next
End Sub

Sub UFOs()
  Dim n As Integer, x As Integer, h As Integer, d As Integer, pat As Integer, fl As Integer, j As Integer, best As Integer, bd As Integer
  For n = 0 To NU - 1
    If uk(n) Then
      ut(n) = ut(n) + 1
      ' shot?
      h = Bul.Hits(n)
      If h > 0 Then KillUFO n
    End If
    If uk(n) Then
      d = Dif(ux(n), hx \ 8)                 ' you, from it
      Select Case uk(n)
        Case K_LANDER
          If ug(n) >= 0 Then
            ' going up with someone
            uy(n) = uy(n) - 1
            j = ug(n) : px(j) = ux(n) : py(j) = uy(n) + 14
            Spr.Put SP_BEAM + (n And 3), Sx(ux(n)) + 24, uy(n) + 24 + 8, GfxData.S_BEAM, 0
            If uy(n) <= YTOP - 8 Then
              ' at the top: they're gone, and it's a mutant now
              ps(j) = 0 : ug(n) = -1 : uk(n) = K_MUTANT
              Spr.Hide SP_BEAM + (n And 3)
              Message "A MUTANT!", 20, 40
              Sfx.Play 1, 200, 20, 14, 30, 0
              If PeopleLeft() = 0 Then LostCity
            End If
          Else
            ' drifting; now and then it picks someone on the ground below
            ufr(n) = ufr(n) + uvx(n)
            ux(n) = Wrap(ux(n) + ufr(n) \ 8) : ufr(n) = ufr(n) Mod 8
            best = -1 : bd = 40
            For j = 0 To NP - 1
              If ps(j) = 1 Then
                If Abs(Dif(ux(n), px(j))) < bd Then bd = Abs(Dif(ux(n), px(j))) : best = j
              End If
            Next
            If best < 0 Then
              ' no one below: wander up and down
              If (ut(n) Mod 40) = 0 Then uvy(n) = Rnd(3) - 1
              uy(n) = uy(n) + uvy(n)
              If uy(n) < 50 Then uy(n) = 50
              If uy(n) > 130 Then uy(n) = 130
            ElseIf (ut(n) Mod 2) = 0 Then
              ' down to them
              ux(n) = Wrap(ux(n) + Sgn(Dif(ux(n), px(best))))
              uy(n) = uy(n) + 1
              If uy(n) >= GROUND - 24 And Abs(Dif(ux(n), px(best))) < 4 Then
                ug(n) = best : ps(best) = 2
                Sfx.Play 1, 400, -20, 13, 30, 0
                If Abs(Sx(ux(n))) < 300 Then Message "THEY'VE GOT SOMEONE!", 20, 40
              End If
            End If
          End If
          pat = GfxData.S_LANDER + (ut(n) \ 8) Mod 2 : fl = 0
          If (uf(n) <= 0) Then Shoot n, 14 + wave, 0
        Case K_MUTANT
          ' straight at you, jittering
          If (ut(n) And 1) = 0 Then
            ux(n) = Wrap(ux(n) + Sgn(d) * 2 + Rnd(3) - 1)
            uy(n) = uy(n) + Sgn(hy - uy(n)) * 1 + Rnd(3) - 1
          End If
          If uy(n) < YTOP Then uy(n) = YTOP
          If uy(n) > YLOW Then uy(n) = YLOW
          pat = GfxData.S_MUTANT + (ut(n) \ 4) Mod 2 : fl = Spr.Pal * 4
          If (uf(n) <= 0) Then Shoot n, 18 + wave, 1
        Case K_BOMBER
          ufr(n) = ufr(n) + uvx(n) \ 2
          ux(n) = Wrap(ux(n) + ufr(n) \ 8) : ufr(n) = ufr(n) Mod 8
          uy(n) = 80 + Sine1(ut(n)) \ 3
          If (ut(n) Mod 70) = 0 And Sx(ux(n)) > 8 And Sx(ux(n)) < 248 Then Bul.Fire Sx(ux(n)), uy(n), 0, 0, GfxData.S_MINE, 0
          pat = GfxData.S_BOMBER + (ut(n) \ 8) Mod 2 : fl = 0
        Case K_POD
          ufr(n) = ufr(n) + uvx(n) \ 2
          ux(n) = Wrap(ux(n) + ufr(n) \ 8) : ufr(n) = ufr(n) Mod 8
          uy(n) = 70 + Sine1(ut(n) + n * 30) \ 4
          pat = GfxData.S_POD + (ut(n) \ 8) Mod 2 : fl = 0
        Case K_SWARM
          ' fast at you across, overshooting
          uvx(n) = uvx(n) + Sgn(d)
          If uvx(n) > 28 Then uvx(n) = 28
          If uvx(n) < -28 Then uvx(n) = -28
          ufr(n) = ufr(n) + uvx(n)
          ux(n) = Wrap(ux(n) + ufr(n) \ 8) : ufr(n) = ufr(n) Mod 8
          uy(n) = uy(n) + Sgn(hy - uy(n))
          pat = GfxData.S_SWARMER + (ut(n) \ 4) Mod 2
          If uvx(n) > 0 Then fl = Spr.MirrorX Else fl = 0
          If (uf(n) <= 0) Then Shoot n, 20, 0
        Case K_BAITER
          ' keeps up with you, and shoots fans
          ux(n) = Wrap(ux(n) + Sgn(d) * 3 + hvx \ 8)
          uy(n) = uy(n) + Sgn(hy - 20 - uy(n))
          pat = GfxData.S_BAITER + (ut(n) \ 4) Mod 2 : fl = 0
          If (uf(n) <= 0) Then Shoot n, 22, 2
      End Select
      uf(n) = uf(n) - 1
      ' on the screen: the sprite, the target box; you running into it
      x = Sx(ux(n))
      If x > -16 And x < 272 Then
        Spr.Put SP_UFO + n, x + 24, uy(n) + 24, pat, fl
        If x > 4 And x < 252 Then Bul.Box n, x, uy(n), 9, 8 Else Bul.Off n
        If alive And inv = 0 And hyperT = 0 Then
          If Abs(x - (Sx(hx \ 8))) < 16 And Abs(uy(n) - hy) < 10 Then
            KillUFO n
            Die
          End If
        End If
      Else
        Spr.Hide SP_UFO + n
        Bul.Off n
        If uk(n) = K_LANDER And ug(n) >= 0 Then Spr.Hide SP_BEAM + (n And 3)
      End If
    End If
  Next
End Sub

' a sine wave: -64 .. 64 over 128 frames
Function Sine1(ByVal t As Integer) As Integer
  Dim u As Integer
  u = t And 127
  If u < 64 Then Sine1 = u * 2 - 64 Else Sine1 = 192 - u * 2
End Function

' UFO n shoots at you (if it's on the screen): kind 0 one bullet, 1 a pair, 2 a fan of 3
Sub Shoot(ByVal n As Integer, ByVal sp As Integer, ByVal kind As Integer)
  Dim x As Integer, a As Integer
  uf(n) = 70 + Rnd(70) - wave * 3
  If uf(n) < 25 Then uf(n) = 25
  If alive = 0 Then Exit Sub
  x = Sx(ux(n))
  If x < 0 Or x > 256 Then Exit Sub
  a = Bul.Aim(x, uy(n), Sx(hx \ 8), hy)
  If kind = 0 Then
    Bul.Fire x, uy(n), a, sp, GfxData.S_BULLET, PINK
  ElseIf kind = 1 Then
    Bul.Fire x, uy(n), a, sp, GfxData.S_BULLET, PINK
    Bul.Fire x, uy(n), (a + 8) And 255, sp, GfxData.S_BULLET, PINK
  Else
    Bul.Fire x, uy(n), a, sp, GfxData.S_BULLET + 1, BLUE
    Bul.Fire x, uy(n), (a + 14) And 255, sp, GfxData.S_BULLET + 1, BLUE
    Bul.Fire x, uy(n), (a - 14) And 255, sp, GfxData.S_BULLET + 1, BLUE
  End If
End Sub

' everyone's gone: every lander turns mutant
Sub LostCity()
  Dim n As Integer
  peopleLost = 1
  For n = 0 To NU - 1
    If uk(n) = K_LANDER Then uk(n) = K_MUTANT
  Next
  Message "THE CITY IS LOST!", 13, 100
  Sfx.Play 2, 40, 10, 15, 80, 1
End Sub

' ---------------------------------------------------------------- the people
Sub Folk()
  Dim n As Integer, x As Integer, pat As Integer, fl As Integer
  For n = 0 To NP - 1
    Select Case ps(n)
      Case 1
        ' walking about
        If (frames And 3) = 0 Then px(n) = Wrap(px(n) + pd(n))
        If Rnd(300) = 0 Then pd(n) = -pd(n)
        pat = GfxData.S_PERSON + (frames \ 8) Mod 2
      Case 3
        ' falling: from up high it's the end of them, unless you catch them
        pv(n) = pv(n) + 1
        py(n) = py(n) + pv(n) \ 8
        If py(n) >= GROUND - 8 Then
          py(n) = GROUND - 8
          If pv(n) > 22 Then
            ps(n) = 0 : Boom px(n), py(n)
            Spr.Hide SP_PEOPLE + n
            If PeopleLeft() = 0 Then LostCity
          Else
            ps(n) = 1 : AddScore 250
          End If
        End If
        ' caught?
        If ps(n) = 3 And alive And carry < 0 Then
          If Abs(Dif(hx \ 8, px(n))) < 14 And Abs(hy + 12 - py(n)) < 12 Then
            ps(n) = 4 : carry = n
            AddScore 500
            Message "CAUGHT! 500", 20, 50
            Sfx.Play 1, 100, -4, 14, 20, 0
          End If
        End If
        pat = GfxData.S_PERSON + 2
      Case 2, 4
        pat = GfxData.S_PERSON + 2
    End Select
    If ps(n) Then
      x = Sx(px(n))
      If pd(n) < 0 Then fl = Spr.MirrorX Else fl = 0
      If x > -16 And x < 272 Then Spr.Put SP_PEOPLE + n, x + 24, py(n) + 24, pat, fl Else Spr.Hide SP_PEOPLE + n
    Else
      Spr.Hide SP_PEOPLE + n
    End If
  Next
End Sub

' ---------------------------------------------------------------- explosions
Sub Boom(ByVal x As Integer, ByVal y As Integer)
  bx(bnext) = x : by(bnext) = y : bt(bnext) = 16
  bnext = (bnext + 1) And 7
End Sub

Sub Booms()
  Dim n As Integer, x As Integer
  For n = 0 To NB - 1
    If bt(n) > 0 Then
      bt(n) = bt(n) - 1
      x = Sx(bx(n))
      If bt(n) = 0 Or x < -16 Or x > 272 Then
        Spr.Hide SP_BOOM + n
      Else
        Spr.Put SP_BOOM + n, x + 24, by(n) + 24, GfxData.S_BOOM + (15 - bt(n)) \ 4, 0
      End If
    End If
  Next
End Sub
