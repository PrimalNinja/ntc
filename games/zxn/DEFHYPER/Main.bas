' DEFENDER HYPERSPACE - a Defender for the ZX Spectrum Next, done the Stargate way, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' The planet is 2048 pixels round (fly off one end and you come back on at the other). Landers
' come down for the ten humanoids and carry them up: get one to the top and it turns mutant. Shoot
' a lander carrying someone and they fall: catch them (you can carry as many as you like) and set
' them down. Lose them all and the planet blows up, and every lander turns mutant. Bombers lay
' mines, pods burst into swarmers, firebombers throw fireballs, dynamos shed space hums, Yllabian
' space guppies swarm, and take too long and the baiters, Phred and Big Red come for you.
' The Stargate: fly in and it takes you to a humanoid in trouble (or the far side of the planet);
' fly in to the right with four or more humanoids aboard, before wave 10, and you warp three
' waves on. Inviso: a cloak (while it lasts) that nothing can hurt, and that kills what it touches.
'
' Keys: Q A up and down, O P left and right (or 5 6 7 8, or a joystick). Space (or M, fire): laser.
'       B (or Enter, fire 2): smart bomb. I (or N): Inviso. H: hyperspace.
'
' The planet is Layer 2, drawn a column at a time as it comes into view and scrolled by the copper
' (Land.cls); the ship, the enemies, the humanoids and the explosions are sprites; the bullets
' and your laser are moved and checked in Z80 (Bul.cls); the scanner and the panel are the
' tilemap.
Option Explicit
Option Turbo

Const WORLD = 2048, HALF = 1024
Const NU = 32, NP = 10, NB = 8, NBOX = 24
' sprite slots (Bul has 54-127)
Const SP_SHIP = 0, SP_UFO = 2, SP_PEOPLE = 34, SP_BOOM = 44, SP_WIN = 52, SP_GATE = 53
' the enemies
Const K_LANDER = 1, K_MUTANT = 2, K_BOMBER = 3, K_POD = 4, K_SWARM = 5, K_BAITER = 6, K_FIREB = 7
Const K_FIREBALL = 8, K_DYNAMO = 9, K_HUM = 10, K_GUPPY = 11, K_PHRED = 12, K_BIGRED = 13, K_MUNCH = 14
' where you can fly (paper rows; the scanner is above), where the humanoids stand
Const YTOP = 44, YLOW = 176, GY = 177
Const PINK = 2, BLUE = 3
' the Stargate
Const GATEX = 1500, GATEY = 84

Dim longText As String Max 80
' the enemies: kind, x (world pixels), y, x speed (8ths), y speed, a timer, who they've got (-1
' none), when they fire next, x's 8ths, their box (-1 none)
Dim uk(31) As Integer, ux(31) As Integer, uy(31) As Integer, uvx(31) As Integer, uvy(31) As Integer
Dim ut(31) As Integer, ug(31) As Integer, uf(31) As Integer, ufr(31) As Integer, ub(31) As Integer
' a lander's humanoid in its sights (-1 none)
Dim utg(31) As Integer
' the scanner's row and the dot's place in it, for each row of the screen
Dim scR(255) As Byte, scS(255) As Byte
' to come this wave, by kind
Dim q(14) As Integer
' the humanoids: 0 gone, 1 walking, 2 carried up, 3 falling, 4 aboard your ship; x, y, way,
' fall speed, where they fell from, their box, their place aboard
Dim ps(9) As Integer, px(9) As Integer, py(9) As Integer, pd(9) As Integer, pv(9) As Integer
Dim pf(9) As Integer, pb(9) As Integer, pa(9) As Integer
' the hit boxes: who has each (-1 free)
Dim bo(23) As Integer
Dim bx(7) As Integer, by(7) As Integer, bt(7) As Integer, bnext As Integer
' you: x (8ths of a world pixel), y, speed (8ths a frame), facing
Dim hx As Integer, hy As Integer, hvx As Integer, face As Integer, alive As Integer, safe As Integer, deadT As Integer, cool As Integer
Dim smart As Integer, smartT As Integer, smartWas As Integer, hyperWas As Integer, hyperT As Integer, thrust As Integer
Dim aboard As Integer, catches As Integer, cloak As Integer, cloakOn As Integer, gateT As Integer, warp As Integer
Dim camX As Integer, pan As Integer
Dim score As Long, hiscore As Long, lives As Integer, wave As Integer, over As Integer, nextLife As Long
Dim frames As Integer, msgT As Integer, scoreDirty As Integer, waveT As Integer, planetGone As Integer, lastBonus As Long
Dim chaser As Integer, att As Integer, tc As Integer, me As Integer
' Sine1 divided by 2, 4, 24, 32; the scanner's column and dot for each 16 pixels from its left edge
Dim sn2(127) As Integer, sn4(127) As Integer, sn24(127) As Integer, sn32(127) As Integer
Dim scC(127) As Byte, scD(127) As Byte
Dim i As Integer, k As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Land.Init
Bul.Init GfxData.S_LASER
Bul.Limits 2000, 2000                   ' (the planet joins up end to end: no ends to stop at)
Nx.Layers Nx.OrderSUL                    ' sprites over the panel, the panel over the planet
Nx.Reg &H1C, 2                           ' the sprites cut to the paper (x halved: over the border)
Nx.Reg &H19, 16 : Nx.Reg &H19, 143 : Nx.Reg &H19, 32 : Nx.Reg &H19, 223
Nx.Reg &H15, Nx.RegGet(&H15) Or &H20
hiscore = 21270
For i = 0 To 255
  k = (i - 40) * 9 \ 145
  If k < 0 Then k = 0
  If k > 8 Then k = 8
  scR(i) = 5 + k \ 3 : scS(i) = (k Mod 3) * 4
Next
For i = 0 To 127
  k = Sine1(i)
  sn2(i) = k \ 2 : sn4(i) = k \ 4 : sn24(i) = k \ 24 : sn32(i) = k \ 32
Next
For i = 0 To 127
  scC(i) = 4 + i \ 4 : scD(i) = i And 3
Next
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

' a frame on: the counter kept 0 - 32767 (past that an Integer goes negative)
Sub Tick()
  frames = (frames + 1) And &H7FFF
End Sub

' ---------------------------------------------------------------- the panel and the scanner
Sub Hud()
  Tiles.Fill 0
  Tiles.Rect 0, 0, 40, 4, GfxData.T_HUD
  Tiles.Rect 4, 4, 32, 1, GfxData.T_SCANT
  Tiles.Rect 4, 5, 32, 2, GfxData.T_SCAN
  Tiles.Rect 4, 7, 32, 1, GfxData.T_SCANG
  Tiles.Rect 3, 4, 1, 4, GfxData.T_SCANS
  Tiles.Rect 36, 4, 1, 4, GfxData.T_SCANS
  Tiles.Text 4, 1, "SCORE"
  Tiles.Text 19, 1, "HI " & Right$("000000" & Trim$(Str$(hiscore)), 7)
  Tiles.Text 30, 1, "WAVE " & Trim$(Str$(wave))
  Tiles.Text 20, 2, "INV"
  ShowScore
  ShowLives
  ShowCloak
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

' the Inviso left: 10 blocks, 40 frames each
Sub ShowCloak()
  Dim n As Integer
  n = (cloak + 39) \ 40
  For k = 0 To 9
    If k < n Then Tiles.Put 24 + k, 2, GfxData.T_INV Else Tiles.Put 24 + k, 2, GfxData.T_INVE
  Next
End Sub

Sub AddScore(ByVal n As Long)
  score = score + n
  scoreDirty = 1
  If score >= nextLife Then
    ' every 10,000: a ship, a smart bomb, more Inviso
    nextLife = nextLife + 10000
    lives = lives + 1 : smart = smart + 1
    cloak = cloak + 120
    If cloak > 400 Then cloak = 400
    ShowLives : ShowCloak
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

' the scanner: the whole planet in 256 pixels (8 to 1), with you in the middle; every 4th frame
Sub Scanner()
  Dim n As Integer, base As Integer
  If (frames And 3) <> 1 Then Exit Sub
  Tiles.Rect 4, 5, 32, 2, GfxData.T_SCAN
  Tiles.Rect 4, 7, 32, 1, GfxData.T_SCANG
  base = Wrap(me - HALF)
  Dot base, GATEX, GATEY, 4
  For n = 0 To NP - 1
    If ps(n) > 0 And ps(n) < 4 Then Dot base, px(n), py(n), 3
  Next
  For n = 0 To NU - 1
    If uk(n) = K_LANDER Then
      Dot base, ux(n), uy(n), 1
    ElseIf uk(n) Then
      Dot base, ux(n), uy(n), 0
    End If
  Next
  If alive Then Dot base, me, hy, 2
  ' the part on the screen
  Spr.Put SP_WIN, ((camX - base) And (WORLD - 1)) \ 8 + 32, 44, GfxData.S_WINDOW, Spr.Scale2X
End Sub

Sub Dot(ByVal base As Integer, ByVal x As Integer, ByVal y As Integer, ByVal c As Integer)
  Dim r As Integer
  r = ((x - base) And (WORLD - 1)) \ 16
  y = y And 255
  Tiles.Put scC(r), scR(y), GfxData.T_DOT + c * 12 + scS(y) + scD(r)
End Sub

' ---------------------------------------------------------------- the title
Function FireDown() As Integer
  FireDown = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyM) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
End Function

' one of the cast: its sprite at tile column cx, row cy, its name and points beside it
Sub Cast(ByVal n As Integer, ByVal cx As Integer, ByVal cy As Integer, ByVal pat As Integer, ByVal fl As Integer, ByVal nm As String)
  Spr.Put SP_UFO + n, cx * 8 - 4, cy * 8 - 4, pat, fl
  Tiles.Text cx + 2, cy, nm
End Sub

Sub Title()
  Dim t As Integer, page As Integer, a As Integer
  Spr.HideRange 0, 54 : Spr.Show
  Bul.Reset : Bul.Show
  wave = 1 : lives = 3 : score = 0 : smart = 3 : cloak = 200 : planetGone = 0
  Land.Kill 0
  Hud
  t = 0 : page = 0 : camX = 0 : face = 1 : hy = 100
  Do
    If t = 0 Then
      ' the pages: the cast, then the keys
      Spr.HideRange 2, 52
      ClearMessages
      Message "D E F E N D E R", 9, 0
      Message "H Y P E R S P A C E", 10, 0
      If page = 0 Then
        Cast 0, 5, 13, GfxData.S_LANDER, 0, "LANDER    150"
        Cast 1, 5, 15, GfxData.S_MUTANT, 0, "MUTANT    150"
        Cast 2, 5, 17, GfxData.S_BOMBER, 0, "BOMBER    250"
        Cast 3, 5, 19, GfxData.S_POD, 0, "POD      1000"
        Cast 4, 5, 21, GfxData.S_SWARMER, 0, "SWARMER   150"
        Cast 5, 5, 23, GfxData.S_BAITER, 0, "BAITER    200"
        Cast 6, 5, 25, GfxData.S_FIREB, 0, "FIREBOMBER 250"
        Cast 7, 21, 13, GfxData.S_FIREBALL, 0, "FIREBALL 100"
        Cast 8, 21, 15, GfxData.S_DYNAMO, 0, "DYNAMO   200"
        Cast 9, 21, 17, GfxData.S_HUM, 0, "SPACE HUM 100"
        Cast 10, 21, 19, GfxData.S_GUPPY, 0, "GUPPY    200"
        Cast 11, 21, 21, GfxData.S_PHRED, 0, "PHRED    200"
        Cast 12, 21, 23, GfxData.S_PHRED, Spr.Pal * 6, "BIG RED  200"
        Cast 13, 21, 25, GfxData.S_MUNCHIE, 0, "MUNCHIE   50"
      Else
        Message "QA UP/DOWN   OP LEFT/RIGHT", 13, 0
        Message "(OR 5678, OR A JOYSTICK)", 14, 0
        Message "SPACE LASER   B SMART BOMB", 16, 0
        Message "I INVISO     H HYPERSPACE", 17, 0
        Message "SAVE THE HUMANOIDS!", 19, 0
        Message "FLY INTO THE STARGATE TO REACH", 21, 0
        Message "ONE IN TROUBLE. WITH 4 ABOARD", 22, 0
        Message "IT WARPS YOU 3 WAVES ON", 23, 0
        Message "(C) 2026 CYBORG UNICORN", 26, 0
        Cast 0, 10, 19, GfxData.S_HUMAN + 2, 0, ""
        Cast 1, 29, 19, GfxData.S_HUMAN + 2, Spr.MirrorX, ""
      End If
    End If
    ' the stars and the mountains going by, a ship flying through
    camX = Wrap(camX + 2)
    Land.View camX
    If page = 0 Then
      Spr.Put SP_SHIP, (t * 2) Mod 320 - 40, 92, GfxData.S_SHIP + 2 + ((frames \ 2) And 1) * 2, 0
      Spr.Put SP_SHIP + 1, (t * 2) Mod 320 - 24, 92, GfxData.S_SHIP + 3 + ((frames \ 2) And 1) * 2, 0
      ' the cast moving
      If (frames And 7) = 0 Then
        a = (frames \ 8) And 1
        Spr.Put SP_UFO, 36, 100, GfxData.S_LANDER + a, 0
        Spr.Put SP_UFO + 1, 36, 116, GfxData.S_MUTANT + a, 0
        Spr.Put SP_UFO + 3, 36, 148, GfxData.S_POD + a, 0
        Spr.Put SP_UFO + 6, 36, 196, GfxData.S_FIREB + a, 0
        Spr.Put SP_UFO + 8, 164, 116, GfxData.S_DYNAMO + a, 0
        Spr.Put SP_UFO + 10, 164, 148, GfxData.S_GUPPY + a, 0
        Spr.Put SP_UFO + 11, 164, 164, GfxData.S_PHRED + a, 0
        Spr.Put SP_UFO + 12, 164, 180, GfxData.S_PHRED + a, Spr.Pal * 6
      End If
    Else
      Spr.Hide SP_SHIP : Spr.Hide SP_SHIP + 1
    End If
    If (frames And 15) = 0 Then Land.Twinkle frames \ 16
    Frame
    Land.Upload
    Spr.Show
    Sfx.Update
    Tick
    t = t + 1
    If (t Mod 50) = 0 Then
      If (t \ 50) Mod 2 Then Message "PRESS SPACE", 28, 0 Else Tiles.Rect 4, 28, 32, 1, 0
    End If
    If t = 400 Then t = 0 : page = 1 - page
  Loop Until FireDown()
  Do
    Frame
  Loop While FireDown()
  ClearMessages
  Tiles.Rect 4, 28, 32, 1, 0
  Spr.HideRange 0, 54
  Sfx.Play 0, 200, -6, 15, 25, 0
End Sub

' ---------------------------------------------------------------- a game
Sub Game()
  score = 0 : lives = 3 : wave = 1 : over = 0 : smart = 3 : nextLife = 10000 : cloak = 200
  planetGone = 0
  For k = 0 To NP - 1
    ps(k) = 1
  Next
  Do
    WaveRun
    If over Then Exit Do
    If warp Then wave = wave + 3 Else wave = wave + 1
  Loop
  Nx.PalEntry 1, 0, 0
  If score > hiscore Then hiscore = score
  Message "GAME OVER", 14, 0
  For k = 1 To 250
    Frame
    Land.Upload
    Sfx.Update
    If k > 50 And FireDown() Then Exit For
  Next
  ClearMessages
End Sub

' the humanoids back (the start, and waves 6, 11, 16 ...): spread along the ground
Sub People()
  For k = 0 To NP - 1
    ps(k) = 1 : px(k) = k * (WORLD \ NP) + Rnd(100) : py(k) = GY : pd(k) = 1 - 2 * Rnd(2) : pv(k) = 0
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

Function OnGround() As Integer
  Dim n As Integer
  n = 0
  For k = 0 To NP - 1
    If ps(k) = 1 Then n = n + 1
  Next
  OnGround = n
End Function

' this wave's line up (Stargate's own)
Sub LineUp()
  For k = 0 To 14
    q(k) = 0
  Next
  If wave Mod 10 = 5 Then
    ' the Yllabian Dogfight
    q(K_DYNAMO) = 6 : q(K_GUPPY) = 22 : q(K_SWARM) = 8
  ElseIf wave Mod 10 = 0 Then
    ' the Firebomber Showdown
    q(K_FIREB) = 13 : q(K_POD) = 6
  ElseIf wave = 1 Then
    q(K_LANDER) = 11 : q(K_DYNAMO) = 2 : q(K_FIREB) = 3
  ElseIf wave = 2 Then
    q(K_LANDER) = 10 : q(K_DYNAMO) = 2 : q(K_FIREB) = 3 : q(K_GUPPY) = 7
  ElseIf wave = 3 Then
    q(K_LANDER) = 10 : q(K_DYNAMO) = 2 : q(K_FIREB) = 6 : q(K_GUPPY) = 4 : q(K_POD) = 3
  ElseIf wave < 11 Then
    q(K_LANDER) = 17 : q(K_DYNAMO) = 3 : q(K_FIREB) = 3 : q(K_GUPPY) = 5 : q(K_POD) = 4
    If wave = 6 Then q(K_BOMBER) = 2
    If wave > 6 Then q(K_BOMBER) = 3
  Else
    q(K_LANDER) = 18 : q(K_DYNAMO) = 4 : q(K_FIREB) = 4 : q(K_GUPPY) = 3 : q(K_POD) = 4 : q(K_BOMBER) = 2
  End If
End Sub

Function ToCome() As Integer
  Dim n As Integer
  n = 0
  For k = 1 To 14
    n = n + q(k)
  Next
  ToCome = n
End Function

Function FreeSlots() As Integer
  Dim n As Integer, c As Integer
  c = 0
  For n = 0 To NU - 1
    If uk(n) = 0 Then c = c + 1
  Next
  FreeSlots = c
End Function

' one more of the others (not landers) in, if there's room
Sub Arrive()
  Dim kd As Integer
  If FreeSlots() < 7 Then Exit Sub
  For kd = 2 To 14
    If q(kd) > 0 Then
      q(kd) = q(kd) - 1
      NewUFO kd
      Exit Sub
    End If
  Next
End Sub

Sub WaveRun()
  Dim b As Long, t As Integer, clearT As Integer
  Spr.HideRange 0, 54
  Bul.Reset
  Nx.PalEntry 1, 0, 0
  For k = 0 To NB - 1
    bt(k) = 0
  Next
  For k = 0 To NU - 1
    uk(k) = 0 : ub(k) = -1
  Next
  For k = 0 To NBOX - 1
    bo(k) = -1
  Next
  If wave = 1 Or wave Mod 5 = 1 Or (warp And planetGone) Then
    If planetGone Or wave > 1 Then Message "THE PLANET IS RESTORED", 17, 100
    People
    planetGone = 0
  Else
    ' the survivors back on the ground
    For k = 0 To NP - 1
      If ps(k) Then ps(k) = 1 : py(k) = GY
    Next
  End If
  For k = 0 To NP - 1
    pb(k) = -1
  Next
  Land.Kill planetGone
  warp = 0
  LineUp
  ' the first landers, five; the rest of the line up as room allows
  For k = 1 To 5
    If q(K_LANDER) > 0 Then q(K_LANDER) = q(K_LANDER) - 1 : NewUFO K_LANDER
  Next
  For k = 1 To 14
    Arrive
  Next
  hx = 200 * 8 : hy = 100 : hvx = 0 : face = 1 : alive = 1 : safe = 100 : deadT = 0 : cool = 0 : smartT = 0
  aboard = 0 : catches = 0 : cloakOn = 0 : gateT = 0 : chaser = 0
  smartWas = 1 : hyperWas = 1 : hyperT = 0
  camX = 112 : pan = 0 : waveT = 0 : clearT = 0
  Hud
  Message "ATTACK WAVE " & Trim$(Str$(wave)), 13, 100
  If wave Mod 10 = 5 Then
    Message "YLLABIAN DOGFIGHT!", 15, 100
  ElseIf wave Mod 10 = 0 Then
    Message "FIREBOMBER SHOWDOWN!", 15, 100
  ElseIf planetGone Then
    Message "NO PLANET: MUTANTS!", 15, 100
  End If
  Do
    waveT = waveT + 1
    If waveT > 30000 Then waveT = 20000
    ' more landers, five at a time; the others as room allows
    If (waveT Mod 10) = 1 Then att = Attackers() : tc = ToCome()
    If q(K_LANDER) > 0 And ((waveT Mod 600) = 0 Or (att < 5 And (waveT Mod 50) = 0)) Then
      For k = 1 To 5
        If q(K_LANDER) > 0 And FreeSlots() > 4 Then q(K_LANDER) = q(K_LANDER) - 1 : NewUFO K_LANDER
      Next
    End If
    If (waveT Mod 40) = 20 Then Arrive
    ' too slow: a baiter, then Phred and Big Red
    If waveT > 2000 And (waveT Mod 450) = 0 Then
      chaser = chaser + 1
      If chaser Mod 3 = 1 Then
        NewUFO K_BAITER
      ElseIf chaser Mod 3 = 2 Then
        NewUFO K_PHRED
      Else
        NewUFO K_BIGRED
      End If
    End If
    You
    me = hx \ 8
    Camera
    UFOs
    Folk
    Gate
    Booms
    SmartUpdate
    If alive And hyperT = 0 Then Bul.Step Sx(me), hy + 1, pan Else Bul.Step 0, 0, pan
    If alive And safe = 0 And smartT = 0 And cloakOn = 0 And hyperT = 0 Then
      If Bul.Hit() Then Die
    End If
    DrawShip
    Scanner
    If scoreDirty And (frames And 3) = 0 Then ShowScore
    If msgT > 0 Then
      msgT = msgT - 1
      If msgT = 0 Then ClearMessages
    End If
    If (frames And 15) = 0 Then Land.Twinkle frames \ 16
    Land.View camX
    Frame
    Land.Upload
    Spr.Show
    Bul.Show
    Sfx.Update
    Tick
    If alive = 0 And deadT = 0 And lives = 0 Then over = 1 : Exit Sub
    If warp Then
      ' through the Stargate with four aboard: three waves on
      t = PeopleLeft()
      b = CLng(t) * 2000
      If b > 20000 Then b = 20000
      AddScore b
      ShowScore
      Spr.HideRange 0, 54
      k = Bul.Clear()
      Bul.Reset : Bul.Show : Spr.Show
      ClearMessages
      Message "S T A R G A T E   W A R P", 12, 0
      Message "BONUS " & Trim$(Str$(b)), 14, 0
      For k = 1 To 150
        If (k And 4) Then Nx.PalEntry 1, 0, (k * 37) And 255 Else Nx.PalEntry 1, 0, 0
        Frame
        Land.Upload
        Sfx.Update
      Next
      Nx.PalEntry 1, 0, 0
      ClearMessages
      Exit Sub
    End If
    ' all the attackers down (fireballs, hums, baiters, Phreds, Big Reds and munchies don't count)?
    If tc = 0 And att = 0 And waveT > 10 Then
      clearT = clearT + 1
      If clearT = 30 Then
        t = PeopleLeft()
        If wave Mod 10 = 5 Then
          b = 2500
        ElseIf wave < 5 Then
          b = CLng(wave) * 100 * t
        Else
          b = CLng(t) * 500
        End If
        AddScore b
        ShowScore
        Message "ATTACK WAVE " & Trim$(Str$(wave)) & " COMPLETED", 12, 0
        If wave Mod 10 = 5 Then
          Message "DOGFIGHT BONUS 2500", 14, 0
        Else
          Message "BONUS X " & Trim$(Str$(t)) & " = " & Trim$(Str$(b)), 14, 0
        End If
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
    Select Case uk(n)
      Case 0, K_FIREBALL, K_HUM, K_BAITER, K_PHRED, K_BIGRED, K_MUNCH
      Case Else
        c = c + 1
    End Select
  Next
  Attackers = c
End Function

' ---------------------------------------------------------------- you
Sub You()
  Dim j0 As Integer, mx As Integer, my As Integer, v As Integer, sb As Integer, n As Integer
  If alive = 0 Then
    If deadT > 0 Then
      deadT = deadT - 1
      If deadT = 0 And lives > 0 Then
        alive = 1 : safe = 150 : hy = 100 : hvx = 0 : ShowLives
      End If
    End If
    Exit Sub
  End If
  ' hyperspace: gone for a moment, then somewhere else (and maybe in pieces)
  If hyperT > 0 Then
    hyperT = hyperT - 1
    If hyperT = 0 Then
      hx = Rnd(WORLD) * 8 : hy = YTOP + Rnd(YLOW - YTOP) : hvx = 0
      camX = Wrap(hx \ 8 - 88) : face = 1 : pan = 0
      Spr.Hide SP_GATE
      If Rnd(5) = 0 Then Die
    End If
    Exit Sub
  End If
  j0 = Keys.Joystick(0)
  mx = 0 : my = 0
  If Keys.Down(Keys.KeyO) Or Keys.Down(Keys.KeyLeft) Or (j0 And Keys.JoyLeft) Then mx = -1
  If Keys.Down(Keys.KeyP) Or Keys.Down(Keys.KeyRight) Or (j0 And Keys.JoyRight) Then mx = 1
  If Keys.Down(Keys.KeyQ) Or Keys.Down(Keys.KeyUp) Or (j0 And Keys.JoyUp) Then my = -1
  If Keys.Down(Keys.KeyA) Or Keys.Down(Keys.KeyDown) Or (j0 And Keys.JoyDown) Then my = 1
  thrust = 0
  If mx <> 0 Then
    ' turn, and thrust
    face = mx : thrust = 1
    hvx = hvx + mx * 3
    If hvx > 52 Then hvx = 52
    If hvx < -52 Then hvx = -52
  Else
    If hvx > 0 Then hvx = hvx - 1
    If hvx < 0 Then hvx = hvx + 1
  End If
  hx = (hx + hvx + WORLD * 8) And (WORLD * 8 - 1)
  hy = hy + my * 3
  If hy < YTOP Then hy = YTOP
  If hy > YLOW Then hy = YLOW
  ' the laser
  If cool > 0 Then cool = cool - 1
  If FireDown() And cool = 0 Then
    v = face * 20
    Bul.Shot Sx(hx \ 8) + face * 18, hy + 1, v, 0, GfxData.S_LASER
    cool = 3
    Sfx.Play 0, 24, 3, 10, 4, 0
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
  ' Inviso: while it's held and there's some left
  If (Keys.Down(Keys.KeyI) Or Keys.Down(Keys.KeyN)) And cloak > 0 Then
    If cloakOn = 0 Then Sfx.Play 1, 300, -8, 11, 20, 0
    cloakOn = 1 : cloak = cloak - 1
    If (cloak Mod 40) = 0 Then ShowCloak
  Else
    If cloakOn Then ShowCloak
    cloakOn = 0
  End If
  ' hyperspace
  sb = Keys.Down(Keys.KeyH)
  If sb And hyperWas = 0 Then
    hyperT = 30
    Spr.Put SP_GATE, Sx(hx \ 8) + 16, hy + 16, GfxData.S_STARS, Spr.Scale2
    DropAll
    Sfx.Play 1, 20, 6, 14, 30, 0
  End If
  hyperWas = sb
  If safe > 0 Then safe = safe - 1
  ' down on the ground with humanoids aboard: they get off
  If aboard > 0 And hy >= YLOW - 2 Then
    For n = 0 To NP - 1
      If ps(n) = 4 Then
        ps(n) = 1 : py(n) = GY : px(n) = Wrap(hx \ 8 - face * (8 + pa(n) * 6))
        AddScore 500
      End If
    Next
    Message Trim$(Str$(aboard * 500)), 20, 50
    Sfx.Play 1, 80, -3, 14, 20, 0
    aboard = 0 : catches = 0
  End If
End Sub

' everyone aboard falls off (hyperspace, the ship lost)
Sub DropAll()
  Dim n As Integer
  For n = 0 To NP - 1
    If ps(n) = 4 Then ps(n) = 3 : pv(n) = 0 : pf(n) = py(n)
  Next
  aboard = 0 : catches = 0
End Sub

' the view: you a quarter of the way in from the side you're leaving (the ship slides across
' when you turn)
Sub Camera()
  Dim want As Integer, was As Integer, d As Integer
  was = camX
  If face > 0 Then want = Wrap(me - 72) Else want = Wrap(me - 184)
  d = Dif(camX, want)
  If d > 9 Then d = 9
  If d < -9 Then d = -9
  camX = Wrap(camX + d)
  pan = Dif(was, camX)
End Sub

Sub DrawShip()
  Dim fl As Integer, x As Integer, a As Integer, b As Integer
  If alive = 0 Or hyperT > 0 Or (safe And 4) <> 0 Then
    Spr.Hide SP_SHIP : Spr.Hide SP_SHIP + 1
  Else
    x = Sx(me)
    If thrust Then a = GfxData.S_SHIP + 2 + ((frames \ 2) And 1) * 2 Else a = GfxData.S_SHIP
    fl = 0
    If cloakOn Then fl = Spr.Pal * 4
    If face < 0 Then
      fl = fl + Spr.MirrorX : b = a : a = a + 1
    Else
      b = a + 1
    End If
    Spr.Put SP_SHIP, x + 24 - 8, hy + 24, a, fl
    Spr.Put SP_SHIP + 1, x + 24 + 8, hy + 24, b, fl
  End If
  If Bul.Sparked() Then Sfx.Play 1, 8, 2, 9, 3, 1
End Sub

Sub Die()
  alive = 0 : deadT = 110 : lives = lives - 1 : ShowLives
  cloakOn = 0
  Boom hx \ 8, hy
  Boom hx \ 8 - 12, hy - 6
  Boom hx \ 8 + 12, hy + 6
  Boom hx \ 8, hy - 10
  k = Bul.Clear()
  DropAll
  Spr.Hide SP_SHIP : Spr.Hide SP_SHIP + 1
  smartT = 20
  Sfx.Play 2, 31, 0, 15, 70, 1
  Sfx.Play 1, 300, 10, 15, 50, 0
End Sub

' every enemy on the screen goes, and every bullet
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

' the screen flashing (a smart bomb, the planet going, the Stargate): Layer 2's black, white
' every other few frames
Sub SmartUpdate()
  If smartT = 0 Then Exit Sub
  smartT = smartT - 1
  If smartT > 0 And (smartT And 2) <> 0 Then Nx.PalEntry 1, 0, &HFF Else Nx.PalEntry 1, 0, 0
End Sub

' ---------------------------------------------------------------- the Stargate
Sub Gate()
  Dim x As Integer, n As Integer, best As Integer, by_ As Integer
  If gateT > 0 Then gateT = gateT - 1
  x = Sx(GATEX)
  If x > -24 And x < 280 Then
    If (frames And 4) Then n = Spr.Pal * 7 Else n = 0
    Spr.Put SP_GATE, x + 16, GATEY + 16, GfxData.S_GATE + ((frames \ 4) And 1), Spr.Scale2 + n
  ElseIf hyperT = 0 Then
    Spr.Hide SP_GATE
  End If
  If alive = 0 Or hyperT > 0 Or gateT > 0 Then Exit Sub
  If Abs(Dif(GATEX, me)) > 12 Or Abs(hy - GATEY) > 12 Then Exit Sub
  ' in!
  gateT = 120
  Sfx.Play 1, 30, 8, 15, 40, 0
  Sfx.Play 0, 400, -12, 13, 40, 0
  If aboard >= 4 And wave < 10 And face > 0 Then
    warp = 1
    Exit Sub
  End If
  ' a humanoid falling, then one being carried off (the one nearest the top), else the far side
  best = -1 : by_ = 999
  For n = 0 To NP - 1
    If ps(n) = 3 And best < 0 Then best = n
  Next
  If best >= 0 Then
    hx = Wrap(px(best) - face * 60) * 8 : hy = py(best) - 10
  Else
    For n = 0 To NU - 1
      If uk(n) = K_LANDER And ug(n) >= 0 Then
        If uy(n) < by_ Then by_ = uy(n) : best = n
      End If
    Next
    If best >= 0 Then
      hx = Wrap(ux(best) - face * 70) * 8 : hy = uy(best)
    Else
      hx = Wrap(hx \ 8 + HALF) * 8
    End If
  End If
  If hy < YTOP Then hy = YTOP
  If hy > YLOW Then hy = YLOW
  If face > 0 Then camX = Wrap(hx \ 8 - 72) Else camX = Wrap(hx \ 8 - 184)
  pan = 0 : me = hx \ 8
  k = Bul.Clear()
  smartT = 12
  Message "STARGATE", 20, 40
End Sub

' ---------------------------------------------------------------- the boxes the laser hits
Function BoxFor(ByVal own As Integer) As Integer
  Dim b As Integer
  For b = 0 To NBOX - 1
    If bo(b) < 0 Then
      bo(b) = own
      k = Bul.Hits(b)                   ' (nothing left over from before)
      BoxFor = b
      Exit Function
    End If
  Next
  BoxFor = -1
End Function

Sub BoxFree(ByVal b As Integer)
  If b < 0 Then Exit Sub
  Bul.Off b
  bo(b) = -1
End Sub

' ---------------------------------------------------------------- the enemies
Sub NewUFO(ByVal kd As Integer)
  Dim n As Integer, m As Integer
  m = -1
  For n = 0 To NU - 1
    If uk(n) = 0 And m < 0 Then m = n
  Next
  If m < 0 Then Exit Sub
  If kd = K_LANDER And planetGone Then kd = K_MUTANT
  uk(m) = kd : ug(m) = -1 : ut(m) = Rnd(100) : ufr(m) = 0 : ub(m) = -1 : utg(m) = -1
  uf(m) = 60 + Rnd(120)
  ' somewhere off the screen
  ux(m) = Wrap(camX + 300 + Rnd(WORLD - 600))
  uy(m) = 56 + Rnd(70)
  uvx(m) = 4 + Rnd(6)
  If Rnd(2) Then uvx(m) = -uvx(m)
  uvy(m) = 0
  Select Case kd
    Case K_BAITER, K_PHRED, K_BIGRED
      ux(m) = Wrap(hx \ 8 + 220 * face) : uy(m) = hy
    Case K_GUPPY
      uvx(m) = 0 : uvy(m) = 0
    Case K_FIREB
      uvx(m) = 12 : uvy(m) = 1
      If Rnd(2) Then uvx(m) = -12
    Case K_SWARM
      uvx(m) = 0
    Case K_BOMBER, K_POD, K_DYNAMO
      uvx(m) = uvx(m) \ 2
  End Select
End Sub

' a child (swarmer, fireball, hum, munchie) from x, y: its slot or -1
Function Spawn(ByVal kd As Integer, ByVal x As Integer, ByVal y As Integer) As Integer
  Dim n As Integer
  Spawn = -1
  For n = 0 To NU - 1
    If uk(n) = 0 Then
      uk(n) = kd : ux(n) = Wrap(x) : uy(n) = y : uvx(n) = 0 : uvy(n) = 0
      ut(n) = 0 : ug(n) = -1 : uf(n) = 40 + Rnd(60) : ufr(n) = 0 : ub(n) = -1
      Spawn = n
      Exit Function
    End If
  Next
End Function

Sub KillUFO(ByVal n As Integer)
  Dim pts As Integer, j As Integer
  Boom ux(n), uy(n)
  Select Case uk(n)
    Case K_LANDER, K_MUTANT, K_SWARM
      pts = 150
    Case K_BOMBER, K_FIREB
      pts = 250
    Case K_POD
      pts = 1000
    Case K_FIREBALL, K_HUM
      pts = 100
    Case K_MUNCH
      pts = 50
    Case Else
      pts = 200
  End Select
  ' a lander with someone: they fall
  If ug(n) >= 0 Then
    j = ug(n)
    ps(j) = 3 : pv(j) = 0 : pf(j) = py(j)
    ug(n) = -1
  End If
  ' a pod: swarmers
  If uk(n) = K_POD Then
    For j = 1 To 4 + Rnd(4)
      k = Spawn(K_SWARM, ux(n) + Rnd(16) - 8, uy(n) + Rnd(16) - 8)
    Next
  End If
  uk(n) = 0
  BoxFree ub(n) : ub(n) = -1
  Spr.Hide SP_UFO + n
  AddScore pts
  Sfx.Play 2, 20 + Rnd(10), 4, 14, 18, 1
End Sub

Sub UFOs()
  Dim n As Integer, x As Integer, h As Integer, d As Integer, pat As Integer, fl As Integer, j As Integer
  Dim best As Integer, bd As Integer, hw As Integer, hh As Integer, sx_ As Integer
  sx_ = Sx(me)
  For n = 0 To NU - 1
    If uk(n) Then
      ut(n) = ut(n) + 1
      If ut(n) > 30000 Then ut(n) = 0
      ' shot?
      If ub(n) >= 0 Then
        h = Bul.Hits(ub(n))
        If h > 0 Then KillUFO n
      End If
    End If
    If uk(n) Then
      d = Dif(ux(n), me)                     ' you, from it
      hw = 7 : hh = 6 : fl = 0
      Select Case uk(n)
        Case K_LANDER
          If ug(n) >= 0 Then
            ' going up with someone
            If (ut(n) And 1) = 0 Then uy(n) = uy(n) - 1
            j = ug(n) : px(j) = ux(n) : py(j) = uy(n) + 12
            If uy(n) <= YTOP - 6 Then
              ' at the top: they're gone, and it's a mutant now
              ps(j) = 0 : ug(n) = -1 : uk(n) = K_MUTANT
              Spr.Hide SP_PEOPLE + j
              BoxFree pb(j) : pb(j) = -1
              Message "MUTANT!", 20, 40
              Sfx.Play 1, 200, 20, 14, 30, 0
              If PeopleLeft() = 0 Then PlanetGoes
            End If
          Else
            ' drifting; now and then it picks someone on the ground below
            MoveX n
            ' (looked for every 16 frames: the nearest on the ground, close by)
            best = utg(n)
            If best >= 0 Then
              If ps(best) <> 1 Then best = -1
            End If
            If (ut(n) And 15) = 0 Then
              best = -1 : bd = 40
              For j = 0 To NP - 1
                If ps(j) = 1 Then
                  h = Abs(Dif(ux(n), px(j)))
                  If h < bd Then bd = h : best = j
                End If
              Next
            End If
            utg(n) = best
            If best < 0 Or (ut(n) And 511) < 150 Then
              ' no one below (or not yet): wander up and down
              If (ut(n) And 31) = 0 Then uvy(n) = Rnd(3) - 1
              uy(n) = uy(n) + uvy(n)
              If uy(n) < 56 Then uy(n) = 56
              If uy(n) > 130 Then uy(n) = 130
            ElseIf (ut(n) And 1) = 0 Then
              ' down to them
              ux(n) = Wrap(ux(n) + Sgn(Dif(ux(n), px(best))))
              If uy(n) < GY - 12 Then uy(n) = uy(n) + 1
              If uy(n) >= GY - 12 And Abs(Dif(ux(n), px(best))) < 3 Then
                ug(n) = best : ps(best) = 2
                Sfx.Play 1, 400, -20, 13, 30, 0
                If OnGround() = 0 Then
                  Message "PLANET SURFACE UNSTABLE!", 18, 100
                ElseIf Abs(Sx(ux(n))) < 300 Then
                  Message "HUMANOID!", 20, 40
                End If
              End If
            End If
          End If
          pat = GfxData.S_LANDER - ((ut(n) And 8) <> 0)
          If (uf(n) <= 0) Then Shoot n, 14 + wave, 0
        Case K_MUTANT
          ' straight at you, jittering
          If (ut(n) And 1) = 0 Then
            ux(n) = Wrap(ux(n) + Sgn(d) * 3 + Rnd(3) - 1)
            uy(n) = uy(n) + Sgn(hy - uy(n)) * 2 + Rnd(5) - 2
          End If
          If uy(n) < YTOP Then uy(n) = YTOP
          If uy(n) > YLOW Then uy(n) = YLOW
          pat = GfxData.S_MUTANT - ((ut(n) And 4) <> 0)
          If (ut(n) And 4) Then fl = Spr.Pal * 5
          If (uf(n) <= 0) Then Shoot n, 18 + wave, 1
        Case K_BOMBER
          MoveX n
          uy(n) = 90 + sn2((ut(n)) And 127)
          If (ut(n) And 31) = 0 And Sx(ux(n)) > 8 And Sx(ux(n)) < 248 Then Bul.Fire Sx(ux(n)), uy(n), 0, 0, GfxData.S_MINE, 0
          pat = GfxData.S_BOMBER - ((ut(n) And 8) <> 0)
        Case K_POD
          MoveX n
          uy(n) = 80 + sn4((ut(n) + n * 30) And 127)
          pat = GfxData.S_POD - ((ut(n) And 8) <> 0)
        Case K_SWARM
          ' fast at you across, overshooting, undulating
          uvx(n) = uvx(n) + Sgn(d)
          If uvx(n) > 30 Then uvx(n) = 30
          If uvx(n) < -30 Then uvx(n) = -30
          MoveX n
          uy(n) = uy(n) + Sgn(hy - uy(n)) + sn32((ut(n) * 4) And 127)
          If uy(n) < YTOP Then uy(n) = YTOP
          If uy(n) > YLOW Then uy(n) = YLOW
          pat = GfxData.S_SWARMER - ((ut(n) And 4) <> 0) : hw = 5 : hh = 4
          If (uf(n) <= 0) Then Shoot n, 20, 0
        Case K_BAITER
          ' keeps up with you, and shoots straight
          ux(n) = Wrap(ux(n) + Sgn(d) * 3 + hvx \ 8)
          uy(n) = uy(n) + Sgn(hy - 20 - uy(n))
          pat = GfxData.S_BAITER - ((ut(n) And 4) <> 0) : hh = 3
          If (uf(n) <= 0) Then Shoot n, 26, 0 : uf(n) = 30 + Rnd(30)
        Case K_FIREB
          ' zig zag; from wave 2, fireballs
          MoveX n
          uy(n) = uy(n) + uvy(n)
          If (ut(n) And 63) = 0 Then
            uvy(n) = Rnd(2) * 2 - 1
            If Rnd(3) = 0 Then uvx(n) = -uvx(n)
          End If
          If uy(n) < 56 Then uvy(n) = 1
          If uy(n) > 150 Then uvy(n) = -1
          pat = GfxData.S_FIREB - ((ut(n) And 4) <> 0)
          If uf(n) <= 0 Then
            uf(n) = 90 + Rnd(90) - wave * 4
            If uf(n) < 40 Then uf(n) = 40
            If wave >= 2 And Abs(Sx(ux(n)) - 128) < 128 And alive Then Fireball n
          End If
        Case K_FIREBALL
          ' straight on, then gone
          MoveX n
          uy(n) = uy(n) + uvy(n)
          pat = GfxData.S_FIREBALL - ((ut(n) And 2) <> 0) : hw = 4 : hh = 4
          If ut(n) > 100 Or uy(n) < YTOP Or uy(n) > YLOW + 8 Then
            uk(n) = 0 : BoxFree ub(n) : ub(n) = -1 : Spr.Hide SP_UFO + n
          End If
        Case K_DYNAMO
          ' drifts; sheds space hums
          MoveX n
          uy(n) = 96 + sn2((ut(n) + n * 20) And 127)
          pat = GfxData.S_DYNAMO - ((ut(n) And 8) <> 0)
          If uf(n) <= 0 Then
            uf(n) = 150 + Rnd(100)
            If Abs(Sx(ux(n)) - 128) < 200 And FreeSlots() > 3 Then
              j = Spawn(K_HUM, ux(n), uy(n))
              If j >= 0 Then Sfx.Play 1, 40, -2, 11, 10, 0
            End If
          End If
        Case K_HUM
          ' after you, wobbling
          If (ut(n) And 1) = 0 Then
            ux(n) = Wrap(ux(n) + Sgn(d) * 2 + Rnd(3) - 1)
            uy(n) = uy(n) + Sgn(hy - uy(n)) + Rnd(3) - 1
          End If
          pat = GfxData.S_HUM - ((ut(n) And 2) <> 0) : hw = 4 : hh = 4
        Case K_GUPPY
          ' a swarm, homing in, wiggling
          uvx(n) = uvx(n) + Sgn(d)
          If uvx(n) > 22 Then uvx(n) = 22
          If uvx(n) < -22 Then uvx(n) = -22
          MoveX n
          If (ut(n) And 1) = 0 Then uy(n) = uy(n) + Sgn(hy - uy(n))
          uy(n) = uy(n) + sn24((ut(n) * 3 + n * 16) And 127)
          If uy(n) < YTOP Then uy(n) = YTOP
          If uy(n) > YLOW Then uy(n) = YLOW
          pat = GfxData.S_GUPPY - ((ut(n) And 4) <> 0)
          If uvx(n) < 0 Then fl = Spr.MirrorX
          If (uf(n) <= 0) Then Shoot n, 16 + wave, 0 : uf(n) = uf(n) + 60
        Case K_PHRED, K_BIGRED
          ' fast after you; spits munchies
          ux(n) = Wrap(ux(n) + Sgn(d) * 3 + hvx \ 16)
          uy(n) = uy(n) + Sgn(hy - uy(n))
          pat = GfxData.S_PHRED - ((ut(n) And 4) <> 0)
          If d < 0 Then fl = Spr.MirrorX
          If uk(n) = K_BIGRED Then fl = fl + Spr.Pal * 6
          If uf(n) <= 0 Then
            uf(n) = 90 + Rnd(60)
            If FreeSlots() > 3 Then j = Spawn(K_MUNCH, ux(n), uy(n))
          End If
        Case K_MUNCH
          ' small, quick, after you
          ux(n) = Wrap(ux(n) + Sgn(d) * 2 + Sgn(d) * (ut(n) And 1))
          uy(n) = uy(n) + Sgn(hy - uy(n))
          pat = GfxData.S_MUNCHIE - ((ut(n) And 4) <> 0) : hw = 4 : hh = 4
          If d < 0 Then fl = Spr.MirrorX
          If ut(n) > 600 Then uk(n) = 0 : BoxFree ub(n) : ub(n) = -1 : Spr.Hide SP_UFO + n
      End Select
      uf(n) = uf(n) - 1
    End If
    If uk(n) Then
      ' on the screen: the sprite, the target box; you running into it
      x = Sx(ux(n))
      If x > -16 And x < 272 Then
        Spr.Put SP_UFO + n, x + 24, uy(n) + 24, pat, fl
        If x > 2 And x < 254 Then
          If ub(n) < 0 Then ub(n) = BoxFor(n)
          If ub(n) >= 0 Then Bul.Box ub(n), x, uy(n), hw, hh
        Else
          BoxFree ub(n) : ub(n) = -1
        End If
        If alive And hyperT = 0 Then
          If Abs(x - sx_) < 14 And Abs(uy(n) - hy) < 8 Then
            If cloakOn Then
              KillUFO n
            ElseIf safe = 0 Then
              KillUFO n
              Die
            End If
          End If
        End If
      Else
        Spr.Hide SP_UFO + n
        BoxFree ub(n) : ub(n) = -1
      End If
    End If
  Next
End Sub

' enemy n moves across uvx(n) eighths of a pixel (its eighths kept in ufr)
Sub MoveX(ByVal n As Integer)
  Dim f As Integer, m As Integer
  f = ufr(n) + uvx(n) : m = 0
  Do While f >= 8
    f = f - 8 : m = m + 1
  Loop
  Do While f <= -8
    f = f + 8 : m = m - 1
  Loop
  ufr(n) = f
  If m Then ux(n) = (ux(n) + m + WORLD) And (WORLD - 1)
End Sub

' a firebomber throws a fireball at you
Sub Fireball(ByVal n As Integer)
  Dim j As Integer, d As Integer
  j = Spawn(K_FIREBALL, ux(n), uy(n))
  If j < 0 Then Exit Sub
  d = Dif(ux(n), hx \ 8)
  uvx(j) = Sgn(d) * (24 + wave * 2)
  If uvx(j) > 40 Then uvx(j) = 40
  If uvx(j) < -40 Then uvx(j) = -40
  uvy(j) = Sgn(hy - uy(n))
  Sfx.Play 1, 60, 6, 12, 12, 0
End Sub

' a sine wave: -64 .. 64 over 128 frames
Function Sine1(ByVal t As Integer) As Integer
  Dim u As Integer
  u = t And 127
  If u < 64 Then Sine1 = u * 2 - 64 Else Sine1 = 192 - u * 2
End Function

' enemy n shoots at you (if it's on the screen): kind 0 one bullet, 1 a pair, 2 a fan of 3
Sub Shoot(ByVal n As Integer, ByVal sp As Integer, ByVal kind As Integer)
  Dim x As Integer, a As Integer
  uf(n) = 80 + Rnd(80) - wave * 3
  If uf(n) < 25 Then uf(n) = 25
  If alive = 0 Or hyperT > 0 Then Exit Sub
  x = Sx(ux(n))
  If x < 0 Or x > 256 Then Exit Sub
  If Abs(x - Sx(me)) < 20 Then Exit Sub        ' (not point blank)
  a = Bul.Aim(x, uy(n), Sx(me), hy)
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

' no humanoids left: the planet blows up, and every lander turns mutant
Sub PlanetGoes()
  Dim n As Integer
  planetGone = 1
  Land.Kill 1
  For n = 0 To NU - 1
    If uk(n) = K_LANDER Then uk(n) = K_MUTANT
  Next
  smartT = 45
  Message "THE PLANET HAS EXPLODED!", 13, 120
  Sfx.Play 2, 40, 10, 15, 90, 1
  Sfx.Play 0, 500, 12, 15, 90, 1
End Sub

' ---------------------------------------------------------------- the humanoids
Sub Folk()
  Dim n As Integer, x As Integer, pat As Integer, fl As Integer, j As Integer
  For n = 0 To NP - 1
    ' shot by your laser (carried up, or falling)?
    If pb(n) >= 0 Then
      If Bul.Hits(pb(n)) > 0 And (ps(n) = 2 Or ps(n) = 3) Then
        Boom px(n), py(n)
        For j = 0 To NU - 1
          If ug(j) = n Then ug(j) = -1
        Next
        ps(n) = 0
        Sfx.Play 1, 300, 20, 13, 25, 0
        Message "HUMANOID KILLED", 20, 40
        If PeopleLeft() = 0 Then PlanetGoes
      End If
    End If
    Select Case ps(n)
      Case 1
        ' walking about
        If (frames And 3) = 0 Then px(n) = Wrap(px(n) + pd(n))
        If (frames And 15) = n Then
          If Rnd(20) = 0 Then pd(n) = -pd(n)
        End If
        pat = GfxData.S_HUMAN - ((frames And 8) <> 0)
      Case 3
        ' falling: from up high it's the end of them, unless you catch them
        pv(n) = pv(n) + 1
        py(n) = py(n) + pv(n) \ 10
        If py(n) >= GY Then
          py(n) = GY
          If GY - pf(n) > 60 Then
            ps(n) = 0 : Boom px(n), py(n)
            Spr.Hide SP_PEOPLE + n
            Sfx.Play 1, 200, 30, 13, 25, 0
            If PeopleLeft() = 0 Then PlanetGoes
          Else
            ps(n) = 1 : AddScore 250
            Message "250", 20, 30
          End If
        End If
        ' caught?
        If ps(n) = 3 And alive And hyperT = 0 Then
          If Abs(Dif(me, px(n))) < 14 And Abs(hy + 10 - py(n)) < 12 Then
            ps(n) = 4 : pa(n) = aboard : aboard = aboard + 1
            catches = catches + 1
            If catches > 4 Then catches = 4
            AddScore 500 * catches
            Message Trim$(Str$(500 * catches)), 20, 50
            Sfx.Play 1, 100, -4, 14, 20, 0
          End If
        End If
        pat = GfxData.S_HUMAN + 2
      Case 2
        pat = GfxData.S_HUMAN + 2
      Case 4
        ' aboard: hanging under the ship, one behind the other
        px(n) = Wrap(me - face * (4 + pa(n) * 6)) : py(n) = hy + 11
        pat = GfxData.S_HUMAN + 2
    End Select
    If ps(n) Then
      x = Sx(px(n))
      If pd(n) < 0 Then fl = Spr.MirrorX Else fl = 0
      If x > -16 And x < 272 And (ps(n) <> 4 Or (alive And hyperT = 0)) Then
        Spr.Put SP_PEOPLE + n, x + 24, py(n) + 24, pat, fl
        If (ps(n) = 2 Or ps(n) = 3) And x > 2 And x < 254 Then
          If pb(n) < 0 Then pb(n) = BoxFor(100 + n)
          If pb(n) >= 0 Then Bul.Box pb(n), x, py(n), 2, 4
        Else
          BoxFree pb(n) : pb(n) = -1
        End If
      Else
        Spr.Hide SP_PEOPLE + n
        BoxFree pb(n) : pb(n) = -1
      End If
    Else
      Spr.Hide SP_PEOPLE + n
      BoxFree pb(n) : pb(n) = -1
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
