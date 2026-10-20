' CHAOTIC - an abstract shooter for the ZX Spectrum Next, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' You are the claw on the rim of a web of 16 lanes, seen down its length. Things climb up the
' lanes out of the middle, firing; you slide round the rim and shoot down the lanes. 16 webs,
' then round again faster. From DEFENDER HELLGATE: the pickups (P, big P, gems, G, N), the power
' levels, the GUARD, the smart bomb (the NOVA here) and the HIT chain. Every fourth level a CORE
' sits in the middle of the web and fills the screen with bullets.
'
' Keys: O P (or Q A on up-and-down edges, or the joystick) slide round the rim - left is left on
'       the screen wherever you are. Space (fire 1) fires (hold it). M (fire 2) the GUARD. N the NOVA.
'
' Layer 2 (Web.cls) holds the web, drawn once a level, and the particles (in Z80, over it);
' every line of the web is a palette colour of its own, so a lane lights up by changing a
' colour, not by drawing. The copper (Cop.cls) paints the background a line at a time and
' wobbles Layer 2. The things in the web, your shots and the pickups are sprites, three sizes by
' how far down the web they are; their bullets are sprites moved in Z80 (Bul.cls). The panel is
' the tilemap, in the top border.
Option Explicit
Option Turbo

Const NE = 20, NS = 8, NI = 6
' sprite slots (Bul has 64-127)
Const SP_CLAW = 0, SP_GUARD = 1, SP_SHOT = 2, SP_ITEM = 10, SP_EN = 16, SP_CORE = 40
' depth: 0 the middle, RIM the rim (64 steps of 64)
Const RIM = 4096
' the things in the web
Const K_SNAP = 1, K_POD = 2, K_SPIN = 3, K_PULS = 4, K_SEED = 5, K_FUSE = 6
' Layer 2's colour numbers: the spokes (17), the rim and inner edges (16), the rings, the particles'
' colour ramps (8 of 8)
Const C_SPOKE = 1, C_SEG = 20, C_RING = 40, C_RAMP = 64
Const R_FIRE = 64, R_ICE = 72, R_ACID = 80, R_VIOLET = 88, R_GOLD = 96, R_WHITE = 104, R_BLOOD = 112, R_PINK = 120
' bullet colours (sprite palettes)
Const B_PINK = 2, B_CYAN = 3, B_GOLD = 4, B_GREEN = 5
Const GUARDLEN = 100

' the web: lane k's middle at depth d (0-64) is at lx(k * 65 + d), ly(...)
Dim lx(1039) As Byte, ly(1039) As Byte
Dim rx(16) As Integer, ry(16) As Integer, ix(16) As Integer, iy(16) As Integer
Dim cdir(15) As Integer, dirX(15) As Integer, dirY(15) As Integer, tt(64) As Integer
Dim lcol(15) As Integer, lwas(15) As Integer, zap(15) As Integer, spWas(16) As Integer
Dim cX As Integer, cY As Integer, isClosed As Integer, shape As Integer, webC As Integer, hiC As Integer, ringC As Integer, ringB As Integer
' the things: kind, lane, depth (0 - RIM), speed, life, timer, on the rim, hit flash, an angle
Dim ek(19) As Integer, el(19) As Integer, ez(19) As Integer, ev(19) As Integer, ehp(19) As Integer
Dim et(19) As Integer, es(19) As Integer, ef(19) As Integer, ea(19) As Integer
' your shots: lane (-1 none), depth
Dim sl(7) As Integer, sz(7) As Integer
' pickups: kind (0 none; 1 P, 2 big P, 3 a gem, 4 G, 5 N), lane, depth, time on the rim
Dim ik(5) As Integer, il(5) As Integer, iz(5) As Integer, it(5) As Integer
' you
Dim ppos As Integer, plane As Integer, pX As Integer, pY As Integer, alive As Integer, inv As Integer, deadT As Integer
Dim power As Integer, pCount As Integer, pTotal As Integer, lives As Integer, novas As Integer, guards As Integer, guardT As Integer
Dim shotCool As Integer, novaWas As Integer, guardWas As Integer, fireAnim As Integer
Dim score As Long, hiscore As Long, nextExtend As Long
Dim chain As Integer, chainT As Integer, maxChain As Integer
' the level
Dim level As Integer, quota As Integer, spawned As Integer, spawnT As Integer, alivee As Integer, maxOn As Integer
Dim frames As Integer, wob As Integer, flashT As Integer, flashC As Integer, msgT As Integer, phase As Integer
Dim bulSpd As Integer, dirty As Integer, over As Integer, warpT As Integer
' the core
Dim bossOn As Integer, bossHP As Integer, bossMax As Integer, bossGap As Integer, bossT As Integer, bossAng As Integer
Dim bossDie As Integer, bossF As Integer, coreBeat As Integer
Dim i As Integer, k As Integer, t As Integer
Dim nm As String Max 12

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Bul.Init
L2On
Web.Init
Cop.Build 0, 0, 0
Nx.Layers Nx.OrderUSL                   ' the tilemap on top (the panel), the sprites, Layer 2
Ramps
hiscore = 50000
Do
  Title
  Game
Loop

' ---------------------------------------------------------------- the screen
' Layer 2 on: 256 x 192, bank 16, no scroll, the whole of it; colour 0 see-through
Sub L2On()
  Nx.Reg &H70, 0
  Nx.Reg &H12, 16
  Nx.Reg &H1C, 1
  Nx.Reg &H18, 0 : Nx.Reg &H18, 255 : Nx.Reg &H18, 0 : Nx.Reg &H18, 191
  Nx.Reg &H16, 0 : Nx.Reg &H17, 0
  Nx.Reg &H14, &HE3
  Out &H123B, 2
  Nx.PalEntry Nx.PalLayer2, 0, &HE3
End Sub

' the particles' 8 colour ramps (brightest first)
Sub Ramps()
  Ramp R_FIRE, "FCF8F4F0E0C08040"
  Ramp R_ICE, "BF9F5F1F170F0A05"
  Ramp R_ACID, "BDBC9C987C584C24"
  Ramp R_VIOLET, "F7D7B79B934A2501"
  Ramp R_GOLD, "FEFDFCF8F4D0A864"
  Ramp R_WHITE, "FFDBB6926D494924"
  Ramp R_BLOOD, "F4F0E0C0A0806020"
  Ramp R_PINK, "F7EFEBCAC6A56221"
End Sub

Sub Ramp(ByVal r As Integer, ByVal s As String)
  For k = 0 To 7
    Nx.PalEntry Nx.PalLayer2, r + k, Hx(s, k)
  Next
End Sub

' Hx(s, k): the k-th hex pair in s
Function Hx(ByVal s As String, ByVal k As Integer) As Integer
  Dim a As Integer, b As Integer
  a = Asc(Mid$(s, k * 2 + 1, 1)) : b = Asc(Mid$(s, k * 2 + 2, 1))
  If a > 57 Then a = a - 55 Else a = a - 48
  If b > 57 Then b = b - 55 Else b = b - 48
  Hx = a * 16 + b
End Function

' Sync: the frame: wait for it, then (in the top border, before the picture starts) the copper's
' list, the particles moved and drawn (one Layer 2 screen: done while it isn't being shown, they
' don't flicker), the sprites; the next frame's copper made
Sub Sync()
  Frame
  Cop.Show
  Web.Step
  Spr.Show
  Bul.Show
  Sfx.Update
  frames = frames + 1
  phase = (phase + 1) And 255
  If wob > 0 Then wob = wob - 1
  If flashT > 0 Then flashT = flashT - 1
  t = wob * 2
  If t > 64 Then t = 64
  If flashT > 0 Then Cop.Build phase, t, flashC Else Cop.Build phase, t, 0
End Sub

' Flash c, n: the background colour c for n frames; and a wobble
Sub Flash(ByVal c As Integer, ByVal n As Integer, ByVal w As Integer)
  flashC = c : flashT = n
  If w > wob Then wob = w
End Sub

' ---------------------------------------------------------------- the web
' MakeWeb n: web n (0-15): its points, its lanes' middles at every depth, its look
Sub MakeWeb(ByVal n As Integer)
  Dim a As Integer, b As Integer, d As Integer, x0 As Integer, y0 As Integer, x1 As Integer, y1 As Integer
  Dim p As Integer
  shape = n
  a = Shapes.Webs() + n * Shapes.REC
  For k = 0 To 16
    rx(k) = Peek(a + k) : ry(k) = Peek(a + 17 + k) : ix(k) = Peek(a + 34 + k) : iy(k) = Peek(a + 51 + k)
  Next
  isClosed = Peek(a + 68)
  For k = 0 To 15
    cdir(k) = Peek(a + 72 + k)
    x0 = rx(k + 1) - rx(k) : y0 = ry(k + 1) - ry(k)
    dirX(k) = 0 : dirY(k) = 0
    If Abs(x0) * 3 >= Abs(y0) Then dirX(k) = Sgn(x0)
    If Abs(y0) * 3 >= Abs(x0) Then dirY(k) = Sgn(y0)
  Next
  cX = 0 : cY = 0
  For k = 0 To 15
    cX = cX + ix(k) : cY = cY + iy(k)
  Next
  cX = cX \ 16 : cY = cY \ 16
  b = Shapes.Depth()
  For d = 0 To 64
    tt(d) = Peek(b + d)
  Next
  For k = 0 To 15
    x0 = (ix(k) + ix(k + 1)) \ 2 : y0 = (iy(k) + iy(k + 1)) \ 2
    x1 = (rx(k) + rx(k + 1)) \ 2 : y1 = (ry(k) + ry(k + 1)) \ 2
    p = k * 65
    For d = 0 To 64
      lx(p + d) = x0 + ((x1 - x0) * (tt(d) \ 2)) \ 128
      ly(p + d) = y0 + ((y1 - y0) * (tt(d) \ 2)) \ 128
    Next
  Next
End Sub

' the web's colours for level lv: 4 looks, round and round
Sub WebLook(ByVal lv As Integer)
  Select Case ((lv - 1) \ 4) Mod 4
    Case 0
      webC = &H17 : hiC = &HFC : ringC = &H06 : ringB = &H2F
      GradSet 0
    Case 1
      webC = &HE0 : hiC = &HFC : ringC = &H40 : ringB = &HA4
      GradSet 1
    Case 2
      webC = &H1C : hiC = &HFF : ringC = &H08 : ringB = &H5D
      GradSet 2
    Case Else
      webC = &HC7 : hiC = &HFC : ringC = &H42 : ringB = &HAB
      GradSet 3
  End Select
  For k = 0 To 16
    Nx.PalEntry Nx.PalLayer2, C_SPOKE + k, webC
    spWas(k) = webC
  Next
  For k = 0 To 15
    Nx.PalEntry Nx.PalLayer2, C_SEG + k, webC
    lwas(k) = webC
  Next
  For k = 0 To 3
    Nx.PalEntry Nx.PalLayer2, C_RING + k, ringC
  Next
End Sub

' the background's band of colours: 8 dark ones, up and down (each 8 lines deep: it rolls)
Sub GradSet(ByVal g As Integer)
  Dim c As Integer, h As Integer, st As String
  Select Case g
    Case 0 : st = "000001010202060A"
    Case 1 : st = "0020202140416162"
    Case 2 : st = "000404050809090D"
    Case Else : st = "0001212122424363"
  End Select
  For k = 0 To 255
    h = k And 63
    If h > 31 Then h = 63 - h
    c = Hx(st, h \ 4)
    Cop.Grad k, c
  Next
End Sub

' DrawWeb: the web on the (cleared) screen, a lane at a time with a frame between (so it grows)
Sub DrawWeb(ByVal slow As Integer)
  Dim r As Integer, d As Integer, x0 As Integer, y0 As Integer, x1 As Integer, y1 As Integer, nk As Integer
  If isClosed Then nk = 15 Else nk = 16
  ' the rings
  For r = 0 To 2
    If r = 0 Then d = 22
    If r = 1 Then d = 38
    If r = 2 Then d = 52
    For k = 0 To 15
      x0 = ix(k) + ((rx(k) - ix(k)) * (tt(d) \ 2)) \ 128
      y0 = iy(k) + ((ry(k) - iy(k)) * (tt(d) \ 2)) \ 128
      x1 = ix(k + 1) + ((rx(k + 1) - ix(k + 1)) * (tt(d) \ 2)) \ 128
      y1 = iy(k + 1) + ((ry(k + 1) - iy(k + 1)) * (tt(d) \ 2)) \ 128
      Web.Line x0, y0, x1, y1, C_RING + r
    Next
  Next
  For k = 0 To nk
    Web.Line ix(k), iy(k), rx(k), ry(k), C_SPOKE + k
    If k < 16 Then
      Web.Line ix(k), iy(k), ix(k + 1), iy(k + 1), C_SEG + k
      Web.Line rx(k), ry(k), rx(k + 1), ry(k + 1), C_SEG + k
    End If
    If slow Then Sync : Sfx.Play 2, 400 - k * 20, 0, 8, 3, 0
  Next
End Sub

' Lights: the lanes' colours this frame - yours lit, a pulsar's zapping, the rings pulsing out
Sub Lights()
  Dim c As Integer, a As Integer, b As Integer
  For k = 0 To 15
    c = webC
    If alive And k = plane Then c = hiC
    If zap(k) Then
      If frames And 2 Then c = &HFF Else c = &HE0
    End If
    lcol(k) = c
    If c <> lwas(k) Then Nx.PalEntry Nx.PalLayer2, C_SEG + k, c : lwas(k) = c
  Next
  For k = 0 To 16
    a = k - 1 : b = k
    If a < 0 Then
      If isClosed Then a = 15 Else a = 0
    End If
    If b > 15 Then
      If isClosed Then b = 0 Else b = 15
    End If
    c = lcol(b)
    If lcol(a) <> webC Then c = lcol(a)
    If lcol(b) <> webC Then c = lcol(b)
    If c <> spWas(k) Then Nx.PalEntry Nx.PalLayer2, C_SPOKE + k, c : spWas(k) = c
  Next
  ' a ring of light running out along the web
  If (frames And 3) = 0 Then
    a = (frames \ 4) Mod 6
    For k = 0 To 2
      If k = a Then c = ringB Else c = ringC
      Nx.PalEntry Nx.PalLayer2, C_RING + k, c
    Next
  End If
End Sub

' LaneX(l, z), LaneY(l, z): where lane l's middle at depth z is (pixels)
Function LaneX(ByVal l As Integer, ByVal z As Integer) As Integer
  If z > RIM Then z = RIM
  If z < 0 Then z = 0
  LaneX = lx(l * 65 + z \ 64)
End Function

Function LaneY(ByVal l As Integer, ByVal z As Integer) As Integer
  If z > RIM Then z = RIM
  If z < 0 Then z = 0
  LaneY = ly(l * 65 + z \ 64)
End Function

' the lane next to l, way w (-1, 1): -1 off the end of an open web
Function Next1(ByVal l As Integer, ByVal w As Integer) As Integer
  l = l + w
  If isClosed Then
    Next1 = l And 15
  ElseIf l < 0 Or l > 15 Then
    Next1 = -1
  Else
    Next1 = l
  End If
End Function

' the way (-1, 0, 1) from lane a towards lane b, the short way round
Function Toward(ByVal a As Integer, ByVal b As Integer) As Integer
  Dim d As Integer
  d = b - a
  If isClosed Then
    If d > 8 Then d = d - 16
    If d < -8 Then d = d + 16
  End If
  Toward = Sgn(d)
End Function

' ---------------------------------------------------------------- the panel
Sub Panel()
  Tiles.Rect 0, 0, 40, 3, GfxData.T_PANEL
  Tiles.Rect 0, 3, 40, 1, GfxData.T_PANELB
  Tiles.Text 1, 1, "SCORE"
  Tiles.Text 26, 0, "HI"
  Tiles.Text 1, 2, "LV"
  Tiles.Text 9, 2, "POW"
  Tiles.Text 19, 2, "HIT"
  ScoreText
  HudText
End Sub

Sub ScoreText()
  Tiles.Text 7, 1, Right$("0000000" & Mid$(Str$(score), 2), 8)
  Tiles.Text 29, 0, Right$("0000000" & Mid$(Str$(hiscore), 2), 8)
End Sub

Sub HudText()
  Dim g As Integer
  Tiles.Text 4, 2, Right$(" " & CStr(level), 3)
  Tiles.Rect 13, 2, 5, 1, GfxData.T_PANEL
  For k = 0 To 4
    If k < power - 1 Then g = 4 Else g = 0
    If k = power - 1 Then g = pCount \ 2
    If g > 4 Then g = 4
    If k < power Then Tiles.Put 13 + k, 2, GfxData.T_PGAUGE + g Else Tiles.Put 13 + k, 2, GfxData.T_PGAUGE
  Next
  Tiles.Rect 26, 1, 13, 2, GfxData.T_PANEL
  For k = 0 To 5
    If k < lives - 1 Then Tiles.Put 26 + k, 1, GfxData.T_LIFE
  Next
  For k = 0 To 5
    If k < novas Then Tiles.Put 26 + k, 2, GfxData.T_NOVA
    If k < guards Then Tiles.Put 33 + k, 2, GfxData.T_GUARDT
  Next
  ChainText
End Sub

Sub ChainText()
  Dim g As Integer
  g = chainT \ 8
  If g > 8 Then g = 8
  Tiles.Put 23, 2, GfxData.T_GAUGE + g
  If chain > 1 Then Tiles.Text 24, 2, Left$(CStr(chain) & " ", 2) Else Tiles.Text 24, 2, "  "
End Sub

Sub AddScore(ByVal n As Long)
  score = score + n
  If score > hiscore Then hiscore = score
  If score >= nextExtend Then
    nextExtend = nextExtend + 40000
    If lives < 6 Then lives = lives + 1 : Msg "EXTRA CLAW", 60 : Sfx.Play 2, 60, -1, 15, 30, 0
    HudText
  End If
  ScoreText
End Sub

' Msg s, t: a line in the middle of the screen for t frames
Sub Msg(ByVal s As String, ByVal t As Integer)
  Tiles.Rect 4, 15, 32, 1, 0
  Tiles.Text 20 - Len(s) \ 2, 15, s
  msgT = t
End Sub

Sub MsgOff()
  Tiles.Rect 4, 15, 32, 1, 0
  Tiles.Rect 4, 17, 32, 1, 0
  msgT = 0
End Sub

' ---------------------------------------------------------------- the game
Sub Game()
  score = 0 : lives = 4 : novas = 2 : guards = 3 : power = 1 : pCount = 0 : pTotal = 0
  nextExtend = 40000 : chain = 0 : chainT = 0 : maxChain = 0 : level = 1 : over = 0
  Tiles.Fill 0
  Panel
  StartLevel 1
  Do
    Play
    If over Then Exit Do
    Warp
    level = level + 1
    StartLevel 0
  Loop
  GameOver
End Sub

' StartLevel first: the web for this level drawn, everything cleared
Sub StartLevel(ByVal first As Integer)
  Clean
  MakeWeb (level - 1) Mod 16
  WebLook level
  Web.Clear
  Web.Kill
  HudText
  Msg "LEVEL " & CStr(level), 120
  nm = WebName(shape)
  Tiles.Text 20 - Len(nm) \ 2, 17, nm
  DrawWeb 1
  quota = 14 + level * 2
  If quota > 60 Then quota = 60
  maxOn = 4 + level \ 2
  If maxOn > 16 Then maxOn = 16
  bulSpd = 14 + level
  If bulSpd > 40 Then bulSpd = 40
  spawned = 0 : spawnT = 60 : bossOn = 0 : bossDie = 0 : coreBeat = 0
  ppos = 8 : plane = 0
  If isClosed = 0 Then ppos = 8 * 16 + 8 : plane = 8
  Spawn5
  alive = 1 : inv = 90 : deadT = 0 : guardT = 0
End Sub

' Spawn5: if the first lane's at the top, start at the bottom
Sub Spawn5()
  Dim best As Integer, by As Integer
  best = plane : by = -1
  For k = 0 To 15
    If LaneY(k, RIM) > by Then by = LaneY(k, RIM) : best = k
  Next
  plane = best : ppos = best * 16 + 8
End Sub

Function WebName(ByVal n As Integer) As String
  Select Case n
    Case 0 : WebName = "CIRCLE"
    Case 1 : WebName = "SQUARE"
    Case 2 : WebName = "CROSS"
    Case 3 : WebName = "FLAT"
    Case 4 : WebName = "STAR"
    Case 5 : WebName = "VEE"
    Case 6 : WebName = "TRIANGLE"
    Case 7 : WebName = "BOW TIE"
    Case 8 : WebName = "U"
    Case 9 : WebName = "HEART"
    Case 10 : WebName = "STEPS"
    Case 11 : WebName = "HEXAGON"
    Case 12 : WebName = "WAVE"
    Case 13 : WebName = "PEANUT"
    Case 14 : WebName = "DOUBLE VEE"
    Case Else : WebName = "DIAMOND"
  End Select
End Function

' everything off the web
Sub Clean()
  For k = 0 To NE - 1
    ek(k) = 0
  Next
  For k = 0 To NS - 1
    sl(k) = -1
  Next
  For k = 0 To NI - 1
    ik(k) = 0
  Next
  For k = 0 To 15
    zap(k) = 0
  Next
  Bul.Reset
  Spr.HideRange 0, 64
  bossOn = 0 : bossDie = 0
End Sub

' Play: the level, until it's cleared (or you're out of claws)
Sub Play()
  Do
    Sync
    Controls
    Shots
    Things
    If bossOn Then Core
    Items
    Bul.Step pX, pY, 3
    If Bul.Hit() And alive And inv = 0 And guardT = 0 Then Die
    If guardT > 0 Then
      guardT = guardT - 1
      t = Bul.Clear()
      If t > 0 Then GuardEat t
    End If
    Lights
    Draw
    If chainT > 0 Then
      chainT = chainT - 1
      If (chainT And 7) = 0 Then ChainText
      If chainT = 0 Then chain = 0 : ChainText
    End If
    If msgT > 0 Then
      msgT = msgT - 1
      If msgT = 0 Then MsgOff
    End If
    If alive = 0 Then
      deadT = deadT - 1
      If deadT = 0 Then
        If lives = 0 Then over = 1 : Exit Sub
        Respawn
      End If
    End If
    ' more of them
    spawnT = spawnT - 1
    If spawnT <= 0 And alive Then
      spawnT = 50 - level * 2
      If spawnT < 14 Then spawnT = 14
      If spawned < quota And alivee < maxOn Then NewThing : spawned = spawned + 1
    End If
    ' done: all spawned, none left - or the core, every fourth level
    If spawned >= quota And alivee = 0 And alive And bossOn = 0 Then
      If (level Mod 4) = 0 And coreBeat = 0 Then
        StartCore
      Else
        Exit Do
      End If
    End If
  Loop
End Sub

' ---------------------------------------------------------------- you
Sub Controls()
  Dim j As Integer, mv As Integer, lf As Integer, rt As Integer, up As Integer, dn As Integer
  Dim f As Integer, a As Integer, b As Integer, w As Integer
  If inv > 0 Then inv = inv - 1
  If alive = 0 Then Exit Sub
  j = Keys.Joystick(0)
  lf = Keys.Down(Keys.KeyO) Or (j And Keys.JoyLeft)
  rt = Keys.Down(Keys.KeyP) Or (j And Keys.JoyRight)
  up = Keys.Down(Keys.KeyQ) Or (j And Keys.JoyUp)
  dn = Keys.Down(Keys.KeyA) Or (j And Keys.JoyDown)
  mv = 0
  If rt Then mv = mv + dirX(plane)
  If lf Then mv = mv - dirX(plane)
  If dn Then mv = mv + dirY(plane)
  If up Then mv = mv - dirY(plane)
  If mv > 0 Then ppos = ppos + 4
  If mv < 0 Then ppos = ppos - 4
  If isClosed Then
    ppos = ppos And 255
  Else
    If ppos < 8 Then ppos = 8
    If ppos > 248 Then ppos = 248
  End If
  ' no key: settle on the lane's middle
  If mv = 0 Then
    a = ppos And 15
    If a < 8 Then ppos = ppos + 1
    If a > 8 Then ppos = ppos - 1
    If isClosed Then ppos = ppos And 255
  End If
  plane = ppos \ 16
  ' where that is: between this lane's middle and the next one's
  a = (ppos And 15) - 8
  pX = LaneX(plane, RIM) : pY = LaneY(plane, RIM)
  If a <> 0 Then
    w = Next1(plane, Sgn(a))
    If w >= 0 Then
      pX = pX + ((LaneX(w, RIM) - pX) * Abs(a)) \ 16
      pY = pY + ((LaneY(w, RIM) - pY) * Abs(a)) \ 16
    End If
  End If
  ' fire
  f = Keys.Down(Keys.KeySpace) Or ((j And Keys.JoyFire1) <> 0)
  If shotCool > 0 Then shotCool = shotCool - 1
  If f And shotCool = 0 Then
    FireShot plane
    If power = 5 Or (power >= 3 And (frames And 1)) Then
      w = Next1(plane, -1)
      If w >= 0 Then FireShot w
      w = Next1(plane, 1)
      If w >= 0 Then FireShot w
    End If
    Select Case power
      Case 1 : shotCool = 8
      Case 2 : shotCool = 6
      Case 3 : shotCool = 6
      Case Else : shotCool = 4
    End Select
    fireAnim = 3
    Sfx.Play 0, 40, 6, 11, 5, 0
  End If
  ' the guard
  b = Keys.Down(Keys.KeyM) Or ((j And Keys.JoyFire2) <> 0)
  If b And guardWas = 0 And guards > 0 And guardT = 0 Then
    guards = guards - 1 : guardT = GUARDLEN
    Sfx.Play 2, 30, 2, 15, 30, 0
    Msg "GUARD", 40
    HudText
  End If
  guardWas = b
  ' the nova
  b = Keys.Down(Keys.KeyN)
  If b And novaWas = 0 And novas > 0 Then Nova
  novaWas = b
End Sub

Sub FireShot(ByVal l As Integer)
  Dim n As Integer
  For n = 0 To NS - 1
    If sl(n) < 0 Then
      sl(n) = l : sz(n) = RIM
      Exit Sub
    End If
  Next
End Sub

' Shots: down their lanes; a thing in the lane near enough is hit
Sub Shots()
  Dim n As Integer, e As Integer, sp As Integer, dmg As Integer
  sp = 230
  If power >= 4 Then sp = 300
  For n = 0 To NS - 1
    If sl(n) >= 0 Then
      sz(n) = sz(n) - sp
      If sz(n) <= 0 Then
        If bossOn And bossDie = 0 Then CoreShot sl(n)
        sl(n) = -1
      Else
        e = 0
        Do While e < NE
          If ek(e) > 0 Then
            If el(e) = sl(n) And ez(e) >= sz(n) - 120 And ez(e) <= sz(n) + sp + 120 Then
              dmg = 1
              If power = 5 Then dmg = 2
              Hurt e, dmg
              sl(n) = -1
              e = NE
            End If
          End If
          e = e + 1
        Loop
      End If
    End If
  Next
End Sub

Sub Die()
  Dim n As Integer
  alive = 0 : deadT = 110 : lives = lives - 1
  If power > 1 Then power = power - 1
  pCount = 0
  chain = 0 : chainT = 0
  Web.Burst pX, pY, 50, R_GOLD, 64, 0, 50
  Web.Burst pX, pY, 32, R_WHITE, 48, 1, 40
  Web.Burst pX, pY, 40, R_FIRE, 28, 0, 70
  Flash &HE0, 6, 40
  Sfx.Play 1, 1200, 30, 15, 60, 1
  Sfx.Play 2, 300, 12, 15, 50, 0
  t = Bul.Clear()
  Spr.Hide SP_CLAW : Spr.Hide SP_GUARD
  ' everything back down the web
  For n = 0 To NE - 1
    If ek(n) > 0 Then
      ez(n) = ez(n) \ 3 : es(n) = 0
    End If
  Next
  HudText
End Sub

Sub Respawn()
  alive = 1 : inv = 120
  Spawn5
  For k = 0 To 15
    zap(k) = 0
  Next
End Sub

Sub GuardEat(ByVal n As Integer)
  Dim j As Integer
  AddScore 10 * n
  pTotal = pTotal + n
  For j = 1 To n \ 4
    NewItem 3, (plane + Rnd(5) + 14) Mod 16, RIM - 600 - Rnd(800)
  Next
End Sub

' Nova: every thing on the web gone (the core: a chunk off), every bullet too
Sub Nova()
  Dim n As Integer
  novas = novas - 1
  Msg "NOVA", 50
  Flash &HFF, 4, 50
  Sfx.Play 1, 2000, 40, 15, 70, 1
  For n = 0 To NE - 1
    If ek(n) > 0 Then Boom n, 0
  Next
  t = Bul.Clear()
  AddScore 10 * t
  Web.Burst 128, 100, 48, R_WHITE, 64, 1, 50
  Web.Burst 128, 100, 40, R_ICE, 40, 3, 30
  If bossOn And bossDie = 0 Then
    bossHP = bossHP - bossMax \ 5
    If bossHP <= 0 Then CoreDown
  End If
  HudText
End Sub

' ---------------------------------------------------------------- the things
Sub NewThing()
  Dim n As Integer, kd As Integer, r As Integer
  n = FreeThing()
  If n < 0 Then Exit Sub
  r = Rnd(100)
  kd = K_SNAP
  If level >= 2 And r < 25 Then kd = K_POD
  If level >= 3 And r >= 25 And r < 40 Then kd = K_SPIN
  If level >= 5 And r >= 40 And r < 52 Then kd = K_SEED
  If level >= 7 And r >= 52 And r < 60 Then kd = K_PULS
  If level >= 9 And r >= 60 And r < 68 Then kd = K_FUSE
  Put1 n, kd, Rnd(16), 0
End Sub

Function FreeThing() As Integer
  Dim n As Integer
  For n = 0 To NE - 1
    If ek(n) = 0 Then FreeThing = n : Exit Function
  Next
  FreeThing = -1
End Function

' Put1 n, kind, lane, depth: thing n
Sub Put1(ByVal n As Integer, ByVal kd As Integer, ByVal l As Integer, ByVal z As Integer)
  ek(n) = kd : el(n) = l : ez(n) = z : es(n) = 0 : ef(n) = 0 : ea(n) = Rnd(256)
  et(n) = 30 + Rnd(60)
  Select Case kd
    Case K_SNAP : ev(n) = 10 + level * 2 : ehp(n) = 1
    Case K_POD : ev(n) = 7 + level : ehp(n) = 2
    Case K_SPIN : ev(n) = 12 + level : ehp(n) = 2
    Case K_PULS : ev(n) = 9 + level : ehp(n) = 3
    Case K_SEED : ev(n) = 10 + level : ehp(n) = 3 + level \ 4 : et(n) = 1200 + Rnd(1600)
    Case Else : ev(n) = 24 + level * 2 : ehp(n) = 1
  End Select
  If ev(n) > 60 Then ev(n) = 60
End Sub

' Hurt n, d: thing n takes d
Sub Hurt(ByVal n As Integer, ByVal d As Integer)
  ehp(n) = ehp(n) - d
  ef(n) = 4
  If ehp(n) <= 0 Then
    Boom n, 1
  Else
    Sfx.Play 1, 200, -10, 10, 4, 1
  End If
End Sub

' Boom n, drops: thing n blown up (drops: its pickups too)
Sub Boom(ByVal n As Integer, ByVal drops As Integer)
  Dim x As Integer, y As Integer, sc As Integer, r As Integer, l As Integer, m As Integer
  x = LaneX(el(n), ez(n)) : y = LaneY(el(n), ez(n))
  Select Case ek(n)
    Case K_SNAP : sc = 150 : r = R_BLOOD
    Case K_POD : sc = 200 : r = R_VIOLET
    Case K_SPIN : sc = 250 : r = R_ACID
    Case K_PULS : sc = 300 : r = R_ICE
    Case K_SEED : sc = 500 : r = R_FIRE
    Case Else : sc = 750 : r = R_PINK
  End Select
  ' the size of the bang: the nearer, the bigger
  m = 12 + ez(n) \ 160
  Web.Burst x, y, m, r, 20 + ez(n) \ 128, 0, 30
  If ez(n) > 2400 Then Web.Burst x, y, 12, R_WHITE, 44, 1, 22
  Sfx.Play 1, 600 + Rnd(400), 20, 14, 18, 1
  ' a pod lets out its two snappers
  If ek(n) = K_POD And drops Then
    l = el(n)
    ek(n) = 0
    m = Next1(l, -1)
    If m < 0 Then m = l
    Put1 n, K_SNAP, m, ez(n)
    m = FreeThing()
    If m >= 0 Then
      x = Next1(l, 1)
      If x < 0 Then x = l
      Put1 m, K_SNAP, x, ez(n)
    End If
  Else
    If drops Then Drop el(n), ez(n), ek(n)
    ek(n) = 0
  End If
  ' the HIT chain
  If chainT > 0 Then chain = chain + 1 Else chain = 1
  If chain > maxChain Then maxChain = chain
  chainT = 64
  ChainText
  AddScore sc + 10 * chain
End Sub

' Drop l, z, kind: what a thing leaves (DEFENDER HELLGATE's pickups)
Sub Drop(ByVal l As Integer, ByVal z As Integer, ByVal kd As Integer)
  Dim r As Integer
  r = Rnd(100)
  If kd = K_SEED Or kd = K_PULS Then r = r \ 2
  If r < 4 Then
    NewItem 2, l, z
  ElseIf r < 26 Then
    NewItem 1, l, z
  ElseIf r < 38 Then
    NewItem 3, l, z
  ElseIf r < 40 Then
    NewItem 4, l, z
  ElseIf r < 42 Then
    NewItem 5, l, z
  End If
End Sub

' Things: every thing in the web, a frame on
Sub Things()
  Dim n As Integer, x As Integer, y As Integer, a As Integer, w As Integer
  alivee = 0
  For k = 0 To 15
    zap(k) = 0
  Next
  For n = 0 To NE - 1
    If ek(n) > 0 Then
      alivee = alivee + 1
      If ef(n) > 0 Then ef(n) = ef(n) - 1
      et(n) = et(n) - 1
      x = LaneX(el(n), ez(n)) : y = LaneY(el(n), ez(n))
      Select Case ek(n)
        Case K_SNAP
          If es(n) = 0 Then
            ez(n) = ez(n) + ev(n)
            If ez(n) >= RIM Then ez(n) = RIM : es(n) = 1 : et(n) = 20
            If et(n) <= 0 Then
              et(n) = 90 - level * 3
              If et(n) < 30 Then et(n) = 30
              If ez(n) > 800 And alive Then Bul.Fire x, y, Bul.Aim(x, y, pX, pY), bulSpd, GfxData.S_BULLET, B_PINK
            End If
          Else
            ' on the rim: it flips along towards you
            If et(n) <= 0 Then
              et(n) = 26 - level
              If et(n) < 8 Then et(n) = 8
              w = Toward(el(n), plane)
              If w <> 0 Then
                a = Next1(el(n), w)
                If a >= 0 Then el(n) = a
              End If
            End If
          End If
        Case K_POD
          ez(n) = ez(n) + ev(n)
          If ez(n) >= RIM Then Boom n, 1
        Case K_SPIN
          ez(n) = ez(n) + ev(n)
          ea(n) = (ea(n) + 7) And 255
          If et(n) <= 0 Then
            et(n) = 40 - level
            If et(n) < 14 Then et(n) = 14
            ' a three-armed spiral
            Bul.Fire x, y, ea(n), bulSpd - 2, GfxData.S_BULLET + 2, B_GREEN
            Bul.Fire x, y, (ea(n) + 85) And 255, bulSpd - 2, GfxData.S_BULLET + 2, B_GREEN
            Bul.Fire x, y, (ea(n) + 170) And 255, bulSpd - 2, GfxData.S_BULLET + 2, B_GREEN
            ' and it slips to the next lane
            a = Next1(el(n), 1 - Rnd(2) * 2)
            If a >= 0 Then el(n) = a
          End If
          If ez(n) >= RIM Then ek(n) = K_SNAP : es(n) = 1 : ez(n) = RIM : ehp(n) = 1
        Case K_PULS
          If ez(n) < 2700 Then ez(n) = ez(n) + ev(n)
          ' pulsing: its lane is live for 40 frames in 140
          a = (frames + n * 37) Mod 140
          If a < 40 Then
            zap(el(n)) = 1
            If a = 0 Then Ring x, y, 8, ea(n), bulSpd - 4, B_CYAN : Sfx.Play 2, 20, 0, 12, 40, 1
          End If
        Case K_SEED
          If ez(n) < et(n) \ 1 And es(n) = 0 Then
            ez(n) = ez(n) + ev(n)
          Else
            If es(n) = 0 Then es(n) = 2 : ea(n) = 0
            ea(n) = ea(n) + 1
            a = 84 - level * 2
            If a < 34 Then a = 34
            If ea(n) >= a Then
              ea(n) = 0
              w = 8 + level \ 2
              If w > 16 Then w = 16
              Ring x, y, w, frames And 255, bulSpd - 3, B_GOLD
            End If
          End If
        Case Else
          ' a fuse: fast, hopping lanes; on the rim it hunts you
          If es(n) = 0 Then
            ez(n) = ez(n) + ev(n)
            If et(n) <= 0 Then
              et(n) = 16
              a = Next1(el(n), 1 - Rnd(2) * 2)
              If a >= 0 Then el(n) = a
            End If
            If ez(n) >= RIM Then ez(n) = RIM : es(n) = 1
          ElseIf et(n) <= 0 Then
            et(n) = 6
            w = Toward(el(n), plane)
            If w <> 0 Then
              a = Next1(el(n), w)
              If a >= 0 Then el(n) = a
            End If
          End If
      End Select
      ' on the rim, in your lane: it's got you (the guard burns it)
      If ek(n) > 0 And alive And ez(n) >= RIM - 64 And el(n) = plane Then
        If guardT > 0 Or inv > 0 Then
          If guardT > 0 Then Boom n, 1
        Else
          Boom n, 0
          Die
        End If
      End If
    End If
  Next
  ' a pulsar's lane with you in it
  If alive And zap(plane) And inv = 0 And guardT = 0 Then Die
End Sub

' Ring x, y, n, a0, spd, pal: n bullets evenly round from x, y
Sub Ring(ByVal x As Integer, ByVal y As Integer, ByVal n As Integer, ByVal a0 As Integer, ByVal sp As Integer, ByVal pal As Integer)
  Dim j As Integer
  For j = 0 To n - 1
    Bul.Fire x, y, (a0 + j * 256 \ n) And 255, sp, GfxData.S_BULLET + 1, pal
  Next
End Sub

' ---------------------------------------------------------------- pickups
Sub NewItem(ByVal kd As Integer, ByVal l As Integer, ByVal z As Integer)
  Dim n As Integer
  For n = 0 To NI - 1
    If ik(n) = 0 Then
      ik(n) = kd : il(n) = l : iz(n) = z : it(n) = 0
      Exit Sub
    End If
  Next
End Sub

' Items: they float up their lanes to the rim, then slide towards you; touch to take
Sub Items()
  Dim n As Integer, w As Integer
  For n = 0 To NI - 1
    If ik(n) > 0 Then
      If iz(n) < RIM Then
        iz(n) = iz(n) + 48
        If iz(n) > RIM Then iz(n) = RIM
      Else
        it(n) = it(n) + 1
        If it(n) > 240 Then ik(n) = 0
        If (it(n) And 7) = 0 And alive Then
          w = Toward(il(n), plane)
          If w <> 0 Then
            w = Next1(il(n), w)
            If w >= 0 Then il(n) = w
          End If
        End If
      End If
      If ik(n) > 0 And alive And il(n) = plane And iz(n) >= RIM - 400 Then Take n
    End If
  Next
End Sub

Sub Take(ByVal n As Integer)
  Select Case ik(n)
    Case 1
      pCount = pCount + 1 : pTotal = pTotal + 1
      AddScore 100
      If pCount >= 10 Then pCount = 0 : PowerUp
      If (pTotal Mod 25) = 0 Then guards = guards + 1 : Msg "GUARD +1", 40
      Sfx.Play 2, 120, -4, 13, 8, 0
    Case 2
      PowerUp
      Sfx.Play 2, 200, -6, 15, 20, 0
    Case 3
      AddScore 500 + 50 * chain
      Sfx.Play 2, 60, -1, 13, 10, 0
    Case 4
      guards = guards + 1 : Msg "GUARD +1", 40
      Sfx.Play 2, 80, -2, 14, 16, 0
    Case Else
      novas = novas + 1 : Msg "NOVA +1", 40
      Sfx.Play 2, 80, -2, 14, 16, 0
  End Select
  Web.Burst pX, pY, 8, R_GOLD, 20, 1, 10
  ik(n) = 0
  HudText
End Sub

Sub PowerUp()
  If power < 5 Then
    power = power + 1
    If power = 5 Then Msg "MAXIMUM POWER", 60 Else Msg "POWER UP", 40
  Else
    AddScore 2000
    Msg "2000", 30
  End If
  HudText
End Sub

' ---------------------------------------------------------------- the core
Sub StartCore()
  bossOn = 1 : bossDie = 0
  bossMax = 60 + level * 10
  bossHP = bossMax : bossT = 0 : bossAng = 0 : bossGap = Rnd(16)
  Msg "WARNING: THE CORE", 120
  Sfx.Play 2, 800, -8, 15, 80, 0
  Flash &HE0, 3, 20
End Sub

' CoreShot l: a shot reached the middle down lane l: through the gap it hurts
Sub CoreShot(ByVal l As Integer)
  Dim x As Integer, y As Integer
  x = LaneX(l, 0) : y = LaneY(l, 0)
  If l = bossGap Then
    bossHP = bossHP - 1 : bossF = 3
    Web.Burst x, y, 4, R_FIRE, 30, 0, 12
    Sfx.Play 1, 300, -20, 12, 4, 1
    AddScore 50
    If bossHP <= 0 Then CoreDown
  Else
    Web.Burst x, y, 2, R_ICE, 16, 0, 8
  End If
End Sub

' Core: the core's guns. Its gap goes round; it fires harder as it's hurt
Sub Core()
  Dim x As Integer, y As Integer, ph As Integer, n As Integer
  x = cX : y = cY
  If bossDie > 0 Then
    bossDie = bossDie - 1
    If (bossDie And 3) = 0 Then Web.Burst x - 30 + Rnd(60), y - 30 + Rnd(60), 20, R_FIRE + (Rnd(4) * 8), 50, 0, 40 : Sfx.Play 1, 900, 30, 15, 20, 1
    If bossDie = 0 Then bossOn = 0 : HideCore
    Exit Sub
  End If
  bossT = bossT + 1
  If bossF > 0 Then bossF = bossF - 1
  If (bossT Mod 150) = 0 Then bossGap = (bossGap + 1 + Rnd(3)) And 15
  ph = 1
  If bossHP < bossMax * 2 \ 3 Then ph = 2
  If bossHP < bossMax \ 3 Then ph = 3
  ' twin spirals
  If (bossT Mod 6) = 0 Then
    bossAng = (bossAng + 11) And 255
    Bul.Fire x, y, bossAng, bulSpd - 4, GfxData.S_BULLET, B_PINK
    Bul.Fire x, y, (bossAng + 128) And 255, bulSpd - 4, GfxData.S_BULLET, B_PINK
  End If
  ' rings
  If ph >= 2 And (bossT Mod 60) = 0 Then Ring x, y, 16, bossT And 255, bulSpd - 6, B_GOLD
  ' aimed fans
  If ph >= 3 And (bossT Mod 45) = 20 And alive Then
    n = Bul.Aim(x, y, pX, pY)
    Bul.Fire x, y, n, bulSpd, GfxData.S_BULLET + 2, B_CYAN
    Bul.Fire x, y, (n + 12) And 255, bulSpd, GfxData.S_BULLET + 2, B_CYAN
    Bul.Fire x, y, (n - 12) And 255, bulSpd, GfxData.S_BULLET + 2, B_CYAN
  End If
  ' snappers out of it
  If (bossT Mod 200) = 100 And alivee < 6 Then
    n = FreeThing()
    If n >= 0 Then Put1 n, K_SNAP, Rnd(16), 200
  End If
End Sub

Sub CoreDown()
  bossDie = 90 : bossHP = 0 : coreBeat = 1
  Msg "CORE DESTROYED", 90
  AddScore 5000 * (level \ 4)
  Flash &HFF, 6, 60
  t = Bul.Clear()
  For k = 0 To 5
    NewItem 2 + (k And 1), Rnd(16), 400
  Next
End Sub

Sub HideCore()
  For k = 0 To 3
    Spr.Hide SP_CORE + k
  Next
End Sub

' ---------------------------------------------------------------- drawing
Sub Draw()
  Dim n As Integer, x As Integer, y As Integer, d As Integer, p As Integer, fl As Integer, c As Integer
  ' you: the claw, turned to point in
  If alive Then
    If inv > 0 And (frames And 2) Then
      Spr.Hide SP_CLAW
    Else
      c = cdir(plane)
      If fireAnim > 0 Then fireAnim = fireAnim - 1 : p = 1 Else p = 0
      If (c And 1) = 0 Then
        p = p + GfxData.S_CLAW
        Select Case c
          Case 0 : fl = 0
          Case 2 : fl = Spr.Rotate
          Case 4 : fl = Spr.MirrorY
          Case Else : fl = Spr.Rotate + Spr.MirrorX
        End Select
      Else
        p = p + GfxData.S_CLAWD
        Select Case c
          Case 1 : fl = 0
          Case 3 : fl = Spr.MirrorY
          Case 5 : fl = Spr.MirrorX + Spr.MirrorY
          Case Else : fl = Spr.MirrorX
        End Select
      End If
      Spr.Put SP_CLAW, pX + 24, pY + 24, p, fl
    End If
    If guardT > 0 Then
      Spr.Put SP_GUARD, pX + 16, pY + 16, GfxData.S_GUARD, Spr.Scale2 + Spr.Pal * (frames And 1) * 3
    Else
      Spr.Hide SP_GUARD
    End If
  End If
  ' your shots
  For n = 0 To NS - 1
    If sl(n) >= 0 Then
      x = LaneX(sl(n), sz(n)) : y = LaneY(sl(n), sz(n))
      If sz(n) > 1800 Then p = GfxData.S_SHOT Else p = GfxData.S_SHOT + 1
      Spr.Put SP_SHOT + n, x + 24, y + 24, p, 0
    Else
      Spr.Hide SP_SHOT + n
    End If
  Next
  ' the pickups
  For n = 0 To NI - 1
    If ik(n) > 0 Then
      x = LaneX(il(n), iz(n)) : y = LaneY(il(n), iz(n))
      Select Case ik(n)
        Case 1 : p = GfxData.S_ITEM + ((frames \ 8) And 1)
        Case 2 : p = GfxData.S_BIGP
        Case 3 : p = GfxData.S_GEM
        Case 4 : p = GfxData.S_GITEM
        Case Else : p = GfxData.S_NITEM
      End Select
      If it(n) > 180 And (frames And 2) Then Spr.Hide SP_ITEM + n Else Spr.Put SP_ITEM + n, x + 24, y + 24, p, 0
    Else
      Spr.Hide SP_ITEM + n
    End If
  Next
  ' the things: small far down, twice the size near the rim
  For n = 0 To NE - 1
    If ek(n) > 0 Then
      x = LaneX(el(n), ez(n)) : y = LaneY(el(n), ez(n))
      d = ez(n) \ 64
      Select Case ek(n)
        Case K_SNAP : p = GfxData.S_SNAP
        Case K_POD : p = GfxData.S_POD
        Case K_SPIN : p = GfxData.S_SPIN
        Case K_PULS : p = GfxData.S_PULS
        Case K_SEED : p = GfxData.S_SEED
        Case Else : p = GfxData.S_FUSE - 1
      End Select
      fl = 0
      If level > 16 Then fl = Spr.Pal * (6 + (level \ 16) Mod 2)
      If ef(n) > 0 Then fl = Spr.Pal
      If d < 22 Then
        Spr.Put SP_EN + n, x + 24, y + 24, p, fl
      Else
        p = p + 1 + ((frames \ 6) And 1)
        If ek(n) = K_PULS And zap(el(n)) Then p = GfxData.S_PULS + 2
        If ek(n) = K_SPIN And ((frames \ 4) And 1) Then fl = fl + Spr.Rotate
        If d >= 50 Then
          Spr.Put SP_EN + n, x + 16, y + 16, p, fl + Spr.Scale2
        Else
          Spr.Put SP_EN + n, x + 24, y + 24, p, fl
        End If
      End If
    Else
      Spr.Hide SP_EN + n
    End If
  Next
  ' the core: 32 x 32 shown twice the size (4 sprites of 16 x 16 at 2x)
  If bossOn And bossDie = 0 Then
    x = cX : y = cY
    p = GfxData.S_CORE + ((frames \ 10) And 1) * 4
    If bossF > 0 Then fl = Spr.Pal * 8 Else fl = 0
    Spr.Put SP_CORE, x, y, p, fl + Spr.Scale2
    Spr.Put SP_CORE + 1, x + 32, y, p + 1, fl + Spr.Scale2
    Spr.Put SP_CORE + 2, x, y + 32, p + 2, fl + Spr.Scale2
    Spr.Put SP_CORE + 3, x + 32, y + 32, p + 3, fl + Spr.Scale2
    ' its gap: that lane glows
    If (frames And 4) Then
      If lcol(bossGap) = webC Then Nx.PalEntry Nx.PalLayer2, C_SEG + bossGap, &HFF : lwas(bossGap) = &HFF
    End If
  End If
End Sub

' ---------------------------------------------------------------- between levels: the warp
' Warp: you dive down the web into the next one: stars rush out, the web goes
Sub Warp()
  Dim n As Integer, x As Integer, y As Integer, s As Integer
  Msg "SUPERZAP", 100
  AddScore 1000 * level
  Sfx.Play 2, 30, 4, 15, 100, 0
  t = Bul.Clear()
  x = LaneX(plane, RIM) : y = LaneY(plane, RIM)
  For n = 0 To 99
    Sync
    ' the claw falls in, smaller as it goes
    s = RIM - n * 41
    x = LaneX(plane, s) : y = LaneY(plane, s)
    If n < 60 Then
      If s > 2000 Then Spr.Put SP_CLAW, x + 24, y + 24, GfxData.S_CLAW, 0 Else Spr.Put SP_CLAW, x + 24, y + 24, GfxData.S_SHOT + 1, 0
    Else
      Spr.Hide SP_CLAW
    End If
    Spr.Hide SP_GUARD
    For k = 0 To NS - 1
      Spr.Hide SP_SHOT + k
    Next
    If (n And 1) = 0 Then Web.Burst LaneX(Rnd(16), 0), LaneY(Rnd(16), 0), 3, R_ICE + (n And 8) * 2, 6, 2, 60
    If n > 40 Then wob = 6
    Lights
  Next
  Web.Kill
  Spr.HideRange 0, 64
  MsgOff
End Sub

' ---------------------------------------------------------------- the title and the end
Sub Title()
  Dim y As Integer, a As Integer
  Clean
  Tiles.Fill 0
  level = 1 : score = 0
  Panel
  MakeWeb 0
  WebLook 1
  Web.Clear
  Web.Kill
  DrawWeb 0
  VText 52, 70, "CHAOTIC", 4, C_RING + 3
  Tiles.Text 13, 22, "PRESS SPACE"
  Tiles.Text 3, 25, "O P  SLIDE ROUND   SPACE  FIRE"
  Tiles.Text 3, 26, "M    GUARD         N      NOVA"
  Tiles.Text 3, 29, "(C) 2026 CYBORG UNICORN PTY LTD"
  y = 0
  Do
    Sync
    y = y + 1
    plane = (y \ 20) And 15
    alive = 1
    Lights
    alive = 0
    ' the name: every colour in turn
    Nx.PalEntry Nx.PalLayer2, C_RING + 3, Hx("FFFCF8F0E0E2E7C79F1F1B1D3D7DFDFE", (y \ 3) And 15)
    If (y And 7) = 0 Then Web.Burst LaneX(Rnd(16), 0), LaneY(Rnd(16), 0), 6, R_FIRE + Rnd(8) * 8, 10, 2, 50
    If (y And 63) = 0 Then Web.Burst 128, 100, 24, R_PINK, 40, 1, 30 : wob = 12
    a = Keys.Joystick(0)
    If y > 30 And (Keys.Down(Keys.KeySpace) Or (a And Keys.JoyFire1)) Then Exit Do
  Loop
  Do
    Sync
    a = Keys.Joystick(0)
  Loop While Keys.Down(Keys.KeySpace) Or (a And Keys.JoyFire1)
  Tiles.Fill 0
End Sub

Sub GameOver()
  Dim y As Integer
  Spr.HideRange 0, 64
  t = Bul.Clear()
  Msg "GAME OVER", 0
  Tiles.Text 12, 17, "SCORE " & Mid$(Str$(score), 2)
  Tiles.Text 12, 18, "LEVEL " & CStr(level)
  Tiles.Text 12, 19, "BEST CHAIN " & CStr(maxChain)
  For y = 0 To 250
    Sync
    Bul.Step 0, 0, 0
    If (y And 15) = 0 Then Web.Burst 40 + Rnd(176), 40 + Rnd(110), 20, R_FIRE + Rnd(8) * 8, 40, 0, 40
  Next
  Tiles.Fill 0
End Sub

' VText x, y, s, z, c: big letters drawn in lines (only the title's: C H A O T I), z pixels a unit
Sub VText(ByVal x As Integer, ByVal y As Integer, ByVal s As String, ByVal z As Integer, ByVal c As Integer)
  Dim j As Integer, st As String, q As Integer, a As Integer
  For j = 1 To Len(s)
    Select Case Mid$(s, j, 1)
      Case "C" : st = "400000060646"
      Case "H" : st = "000640460343"
      Case "A" : st = "062020461333"
      Case "O" : st = "0040404646060600"
      Case "T" : st = "40002026"
      Case "I" : st = "400020260646"
      Case Else : st = ""
    End Select
    For q = 0 To Len(st) \ 4 - 1
      a = q * 4 + 1
      Web.Line x + Dg(st, a) * z, y + Dg(st, a + 1) * z, x + Dg(st, a + 2) * z, y + Dg(st, a + 3) * z, c
      Web.Line x + Dg(st, a) * z + 1, y + Dg(st, a + 1) * z, x + Dg(st, a + 2) * z + 1, y + Dg(st, a + 3) * z, c
    Next
    x = x + 6 * z
  Next
End Sub

Function Dg(ByVal s As String, ByVal i As Integer) As Integer
  Dg = Asc(Mid$(s, i, 1)) - 48
End Function
