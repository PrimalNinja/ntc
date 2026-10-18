' KO ALLEY - a one on one street fighting game for the ZX Spectrum Next, in NTC BASIC (VB5 flavour)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Two brawlers, best of three rounds, 99 seconds a round. Punch, kick, a low sweep, a jump kick,
' blocking (hold away from the other fighter), and an energy orb you can throw.
'
' Straight to the Next's hardware: each fighter is six hardware sprites (Spr.cls) shown twice
' the size (64 x 96), mirrored to face left; the alley, the health bars and the text are the
' tilemap (Tiles.cls); the sound the AY (Sfx.cls). The art is in gfx/ - swap it with gfxtool.js.
'
' Player 1: Q A O P (jump, crouch, left, right), Space punch, M kick, N orb; or Kempston 1
'           (fire punch, fire 2 kick, fire while crouching throws the orb).
' Player 2: 7 6 5 8 (jump, crouch, left, right), 0 punch, 9 kick, 4 orb; or Kempston 2.
' One player: the computer is player 2.
Option Explicit
Option Turbo

Const FLOOR = 224
Const XMIN = 36, XMAX = 284
' states
Const S_IDLE = 0, S_WALK = 1, S_CROUCH = 2, S_JUMP = 3, S_ATTACK = 4, S_BLOCK = 5, S_HIT = 6, S_DOWN = 7, S_WIN = 8
' attacks
Const A_PUNCH = 1, A_KICK = 2, A_LOW = 3, A_JKICK = 4, A_ORB = 5
' how an attack must be blocked
Const Z_MID = 0, Z_HIGH = 1, Z_LOW = 2, Z_OVER = 3

Dim fx(1) As Integer, fy(1) As Integer, fvx(1) As Integer, fvy(1) As Integer, face(1) As Integer
Dim fs(1) As Integer, ft(1) As Integer, fatk(1) As Integer, fhit(1) As Integer, hp(1) As Integer
Dim wins(1) As Integer, flash(1) As Integer, anim(1) As Integer, push(1) As Integer
' the buttons each fighter holds this frame (the keyboard, a joystick or the computer)
Dim bL(1) As Integer, bR(1) As Integer, bU(1) As Integer, bD(1) As Integer
Dim bP(1) As Integer, bK(1) As Integer, bS(1) As Integer
Dim wasP(1) As Integer, wasK(1) As Integer, wasS(1) As Integer
' the orbs
Dim ox(1) As Integer, oy(1) As Integer, ovx(1) As Integer, oon(1) As Integer
' the computer
Dim aiT As Integer, aiPlan As Integer, aiHold As Integer
Dim players As Integer, rnum As Integer, clock As Integer, tick As Integer, over As Integer, roundOver As Integer
Dim sparkT As Integer, sparkX As Integer, sparkY As Integer
Dim frames As Integer, seed As Integer, firewas As Integer
Dim i As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Nx.Layers Nx.OrderSLU
Do
  Title
  Match
Loop

' ---------------------------------------------------------------- input
Sub ReadPads()
  Dim j As Integer
  j = Keys.Joystick(0)
  bL(0) = Keys.Down(Keys.KeyO) Or ((j And Keys.JoyLeft) <> 0)
  bR(0) = Keys.Down(Keys.KeyP) Or ((j And Keys.JoyRight) <> 0)
  bU(0) = Keys.Down(Keys.KeyQ) Or ((j And Keys.JoyUp) <> 0)
  bD(0) = Keys.Down(Keys.KeyA) Or ((j And Keys.JoyDown) <> 0)
  bP(0) = Keys.Down(Keys.KeySpace) Or (((j And Keys.JoyFire1) <> 0) And Not bD(0))
  bK(0) = Keys.Down(Keys.KeyM) Or ((j And Keys.JoyFire2) <> 0)
  bS(0) = Keys.Down(Keys.KeyN) Or (((j And Keys.JoyFire1) <> 0) And bD(0))
  If players = 2 Then
    j = Keys.Joystick(1)
    bL(1) = Keys.Down(Keys.Key5) Or ((j And Keys.JoyLeft) <> 0)
    bR(1) = Keys.Down(Keys.Key8) Or ((j And Keys.JoyRight) <> 0)
    bU(1) = Keys.Down(Keys.Key7) Or ((j And Keys.JoyUp) <> 0)
    bD(1) = Keys.Down(Keys.Key6) Or ((j And Keys.JoyDown) <> 0)
    bP(1) = Keys.Down(Keys.Key0) Or (((j And Keys.JoyFire1) <> 0) And Not bD(1))
    bK(1) = Keys.Down(Keys.Key9) Or ((j And Keys.JoyFire2) <> 0)
    bS(1) = Keys.Down(Keys.Key4) Or (((j And Keys.JoyFire1) <> 0) And bD(1))
  Else
    Computer
  End If
End Sub

Function FirePressed() As Integer
  Dim f As Integer
  f = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyEnter) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
  FirePressed = f And Not firewas
  firewas = f
End Function

' ---------------------------------------------------------------- the computer (player 2)
Sub Computer()
  Dim d As Integer, r As Integer, fwdR As Integer
  bL(1) = 0 : bR(1) = 0 : bU(1) = 0 : bD(1) = 0 : bP(1) = 0 : bK(1) = 0 : bS(1) = 0
  If roundOver Then Exit Sub
  d = Abs(fx(1) - fx(0))
  fwdR = (fx(0) > fx(1))           ' the player is to the right
  ' a block when the player attacks close by (or an orb comes)
  If (fs(0) = S_ATTACK And d < 90) Or (oon(0) And Abs(ox(0) - fx(1)) < 70) Then
    If Rnd(100) < 40 + rnum * 10 Then
      aiPlan = 6 : aiT = 12
    End If
  End If
  If aiT <= 0 Then
    r = Rnd(100)
    If d > 150 Then
      If r < 18 And oon(1) = 0 Then aiPlan = 5 Else aiPlan = 1
      aiT = 10 + Rnd(10)
    ElseIf d > 70 Then
      If r < 55 Then
        aiPlan = 1
      ElseIf r < 67 Then
        aiPlan = 7
      ElseIf r < 77 And oon(1) = 0 Then
        aiPlan = 5
      Else
        aiPlan = 0
      End If
      aiT = 8 + Rnd(12)
    Else
      If r < 30 Then
        aiPlan = 2
      ElseIf r < 52 Then
        aiPlan = 3
      ElseIf r < 70 Then
        aiPlan = 4
      ElseIf r < 82 Then
        aiPlan = 8
      ElseIf r < 90 Then
        aiPlan = 7
      Else
        aiPlan = 0
      End If
      aiT = 10 + Rnd(10)
    End If
  End If
  aiT = aiT - 1
  Select Case aiPlan
    Case 1          ' walk in
      If fwdR Then bR(1) = -1 Else bL(1) = -1
    Case 2          ' punch
      bP(1) = (aiT And 7) = 0
    Case 3          ' kick
      bK(1) = (aiT And 7) = 0
    Case 4          ' sweep
      bD(1) = -1
      bK(1) = (aiT And 7) = 0
    Case 5          ' an orb
      bS(1) = -1
    Case 6          ' block: hold away
      If fwdR Then bL(1) = -1 Else bR(1) = -1
    Case 7          ' jump in
      bU(1) = -1
      If fwdR Then bR(1) = -1 Else bL(1) = -1
      If fy(1) < FLOOR - 30 Then bK(1) = -1
    Case 8          ' back off
      If fwdR Then bL(1) = -1 Else bR(1) = -1
  End Select
End Sub

' ---------------------------------------------------------------- the screen
Sub Alley()
  Dim x As Integer, y As Integer, h As Integer, t As Integer
  Tiles.Fill GfxData.T_SKY
  For x = 0 To 39
    If Rnd(3) = 0 Then Tiles.Put x, 4 + Rnd(4), GfxData.T_STARS
  Next
  ' buildings: blocks of height 3-7 rows over the wall
  x = 0
  Do While x < 40
    h = 3 + Rnd(5)
    For y = 12 - h To 11
      For t = x To x + 4
        If t < 40 Then
          If Rnd(3) = 0 Then Tiles.Put t, y, GfxData.T_WIN1 + Rnd(2) Else Tiles.Put t, y, GfxData.T_BUILD
        End If
      Next
    Next
    x = x + 5
  Loop
  ' the brick wall, the doorway, the sign, the pavement
  For y = 12 To 25
    For x = 0 To 39
      Tiles.Put x, y, GfxData.T_BRICK - ((x + y) Mod 7 = 0)
    Next
  Next
  Tiles.Rect 30, 17, 4, 9, GfxData.T_DOOR
  Tiles.Rect 6, 14, 10, 4, GfxData.T_SIGN + 4
  Tiles.Rect 6, 14, 10, 1, GfxData.T_SIGN
  Tiles.Rect 6, 17, 10, 1, GfxData.T_SIGN + 1
  Tiles.Rect 6, 15, 1, 2, GfxData.T_SIGN + 2
  Tiles.Rect 15, 15, 1, 2, GfxData.T_SIGN + 3
  Tiles.Text 8, 15, "BLUE"
  Tiles.Text 9, 16, "LAMP"
  Tiles.Rect 0, 26, 40, 2, GfxData.T_WALLB
  For y = 28 To 31
    For x = 0 To 39
      Tiles.Put x, y, GfxData.T_PAVE + Rnd(2)
    Next
  Next
  Tiles.Rect 0, 0, 40, 4, GfxData.T_DARK
End Sub

Sub HudNames()
  Tiles.Text 2, 0, "JAX"
  If players = 2 Then Tiles.Text 31, 0, "KANE 2P" Else Tiles.Text 31, 0, "KANE CPU"
  Hud
End Sub

Sub Hud()
  Dim k As Integer, n As Integer, t As Integer
  ' player 1's bar: cells 2-17, full from the left; player 2's: cells 22-37, full from the right
  n = (hp(0) * 128) \ 100
  For k = 0 To 15
    t = n - k * 8
    If t > 8 Then t = 8
    If t < 0 Then t = 0
    Tiles.Put 2 + k, 1, GfxData.T_BAR + t
  Next
  n = (hp(1) * 128) \ 100
  For k = 0 To 15
    t = n - k * 8
    If t > 8 Then t = 8
    If t < 0 Then t = 0
    Tiles.Put 37 - k, 1, GfxData.T_BARR + t
  Next
  For k = 0 To 1
    Tiles.Put 2 + k, 2, GfxData.T_ROUND - (wins(0) > k)
    Tiles.Put 37 - k, 2, GfxData.T_ROUND - (wins(1) > k)
  Next
  Clock1
End Sub

Sub Clock1()
  Tiles.Text 19, 1, Format$(clock, "00")
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
    Case "K": p = "55655"
    Case "O": p = "75557"
    Case "A": p = "25755"
    Case "L": p = "44447"
    Case "E": p = "74647"
    Case "Y": p = "55222"
    Case Else: p = "00000"
  End Select
  Glyph = Val(Mid$(p, r + 1, 1))
End Function

' a message in the middle (cleared with "")
Sub Banner(ByVal s As String)
  Tiles.Rect 10, 9, 20, 1, GfxData.T_DARK
  If s <> "" Then Tiles.Text 20 - Len(s) \ 2, 9, s Else Alley2
End Sub

' the sky row the banner covered, back (one row of the backdrop)
Sub Alley2()
  Dim x As Integer
  For x = 10 To 29
    Tiles.Put x, 9, Tiles.Get(x, 10)
  Next
End Sub

' ---------------------------------------------------------------- the title
Sub Title()
  Dim k As Integer
  Spr.HideRange 0, 16
  Spr.Show
  Nx.Seed 1234
  Alley
  Tiles.Rect 6, 14, 10, 4, GfxData.T_BRICK          ' no sign on the title
  BigText 9, 5, "KO", 0
  BigText 19, 5, "ALLEY", 1
  Tiles.Rect 10, 12, 20, 5, GfxData.T_DARK
  Tiles.Text 11, 13, "1  ONE PLAYER V CPU"
  Tiles.Text 11, 15, "2  TWO PLAYERS"
  Tiles.Text 1, 28, "P1  Q A O P  SPACE PUNCH  M KICK  N ORB"
  Tiles.Text 1, 29, "P2  7 6 5 8  0 PUNCH  9 KICK  4 ORB"
  Tiles.Text 1, 30, "HOLD AWAY TO BLOCK  KEMPSTON 1 AND 2"
  ' the two fighters face off
  fx(0) = 44 : fy(0) = FLOOR : face(0) = 1 : fs(0) = S_IDLE : flash(0) = 0
  fx(1) = 276 : fy(1) = FLOOR : face(1) = -1 : fs(1) = S_IDLE : flash(1) = 0
  players = 0 : frames = 0
  Do
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1 : seed = seed + 1
    anim(0) = frames : anim(1) = frames + 7
    DrawFighter 0
    DrawFighter 1
    If Keys.Down(Keys.Key1) Then players = 1
    If Keys.Down(Keys.Key2) Then players = 2
    If FirePressed() Then players = 1
  Loop Until players > 0
  Nx.Seed seed
End Sub

' ---------------------------------------------------------------- a match: best of three
Sub Match()
  wins(0) = 0 : wins(1) = 0 : rnum = 1
  Do
    PlayRound
    rnum = rnum + 1
  Loop Until wins(0) = 2 Or wins(1) = 2
  If wins(0) = 2 Then Banner "JAX WINS THE MATCH" Else Banner "KANE WINS THE MATCH"
  Wait1 200
  Banner ""
End Sub

Sub Wait1(ByVal n As Integer)
  Dim k As Integer
  For k = 1 To n
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1
    anim(0) = anim(0) + 1 : anim(1) = anim(1) + 1
    DrawFighter 0
    DrawFighter 1
  Next
End Sub

Sub PlayRound()
  Dim n As Integer, w As Integer
  Alley
  Spr.HideRange 0, 16
  For n = 0 To 1
    fy(n) = FLOOR : fvx(n) = 0 : fvy(n) = 0 : fs(n) = S_IDLE : ft(n) = 0 : hp(n) = 100
    flash(n) = 0 : oon(n) = 0 : push(n) = 0 : wasP(n) = -1 : wasK(n) = -1 : wasS(n) = -1
    Spr.Hide 12 + n
  Next
  fx(0) = 100 : fx(1) = 220 : face(0) = 1 : face(1) = -1
  clock = 99 : tick = 0 : roundOver = 0 : aiT = 0 : sparkT = 0
  HudNames
  Banner "ROUND " & CStr(rnum)
  Wait1 70
  Banner "FIGHT"
  Sfx.Play 2, 80, -2, 15, 25, 0
  Wait1 30
  Banner ""
  Do
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1
    ReadPads
    For n = 0 To 1
      Fighter n
    Next
    Separate
    Orbs
    For n = 0 To 1
      anim(n) = anim(n) + 1
      DrawFighter n
    Next
    Sparks
    ' the clock
    tick = tick + 1
    If tick >= 50 And roundOver = 0 Then
      tick = 0
      If clock > 0 Then clock = clock - 1
      Clock1
      If clock = 0 Then roundOver = 1
    End If
    If roundOver Then roundOver = roundOver + 1
  Loop Until roundOver > 90
  ' who won it
  If hp(0) > hp(1) Then
    w = 0
  ElseIf hp(1) > hp(0) Then
    w = 1
  Else
    w = Rnd(2)
  End If
  wins(w) = wins(w) + 1
  If hp(w) > 0 Then fs(w) = S_WIN
  Hud
  If w = 0 Then Banner "JAX WINS" Else Banner "KANE WINS"
  Sfx.Play 0, 100, -3, 14, 40, 0
  Wait1 120
  Banner ""
End Sub

' ---------------------------------------------------------------- a fighter's frame
Sub Fighter(ByVal n As Integer)
  Dim o As Integer, fwd As Integer, back As Integer, pP As Integer, pK As Integer, pS As Integer
  o = 1 - n
  ' the buttons pressed this frame, not held
  pP = bP(n) And Not wasP(n) : wasP(n) = bP(n)
  pK = bK(n) And Not wasK(n) : wasK(n) = bK(n)
  pS = bS(n) And Not wasS(n) : wasS(n) = bS(n)
  If face(n) > 0 Then
    fwd = bR(n) : back = bL(n)
  Else
    fwd = bL(n) : back = bR(n)
  End If
  If flash(n) > 0 Then flash(n) = flash(n) - 1
  If push(n) <> 0 Then
    fx(n) = fx(n) + push(n)
    If push(n) > 0 Then push(n) = push(n) - 1 Else push(n) = push(n) + 1
  End If
  If roundOver And fs(n) <> S_DOWN And fs(n) <> S_JUMP Then
    fs(n) = S_IDLE
    Exit Sub
  End If
  Select Case fs(n)
    Case S_IDLE, S_WALK, S_CROUCH
      ' turn to face the other one
      If fx(o) > fx(n) Then face(n) = 1 Else face(n) = -1
      If pS And oon(n) = 0 Then
        StartAttack n, A_ORB
      ElseIf pP Then
        StartAttack n, A_PUNCH
      ElseIf pK And bD(n) Then
        StartAttack n, A_LOW
      ElseIf pK Then
        StartAttack n, A_KICK
      ElseIf bU(n) Then
        fs(n) = S_JUMP : fvy(n) = -40 : fvx(n) = 0
        If fwd Then fvx(n) = 3 * face(n)
        If back Then fvx(n) = -3 * face(n)
        Sfx.Play 0, 200, -8, 8, 6, 0
      ElseIf bD(n) Then
        fs(n) = S_CROUCH
      ElseIf fwd Then
        fs(n) = S_WALK : fx(n) = fx(n) + 2 * face(n)
      ElseIf back Then
        fs(n) = S_WALK : fx(n) = fx(n) - 2 * face(n)
      Else
        fs(n) = S_IDLE
      End If
    Case S_JUMP
      fvy(n) = fvy(n) + 3
      fy(n) = fy(n) + fvy(n) \ 4
      fx(n) = fx(n) + fvx(n)
      If (pK Or pP) And fatk(n) = 0 Then
        fatk(n) = A_JKICK : ft(n) = 0 : fhit(n) = 0
        Sfx.Play 0, 150, 10, 10, 6, 0
      End If
      If fatk(n) = A_JKICK Then
        ft(n) = ft(n) + 1
        If ft(n) > 3 And fhit(n) = 0 Then TryHit n
      End If
      If fy(n) >= FLOOR Then
        fy(n) = FLOOR : fs(n) = S_IDLE : fatk(n) = 0 : fvx(n) = 0
      End If
    Case S_ATTACK
      ft(n) = ft(n) + 1
      Attack n
    Case S_BLOCK, S_HIT
      ft(n) = ft(n) - 1
      If ft(n) <= 0 Then fs(n) = S_IDLE
    Case S_DOWN
      ft(n) = ft(n) + 1
  End Select
  If fx(n) < XMIN Then fx(n) = XMIN
  If fx(n) > XMAX Then fx(n) = XMAX
End Sub

Sub StartAttack(ByVal n As Integer, ByVal a As Integer)
  fs(n) = S_ATTACK : fatk(n) = a : ft(n) = 0 : fhit(n) = 0
  Sfx.Play 0, 120 + a * 30, 10, 9, 6, 0
End Sub

' the timing of each attack: startup, active to, recovery to (frames)
Sub Attack(ByVal n As Integer)
  Dim t As Integer
  t = ft(n)
  Select Case fatk(n)
    Case A_PUNCH
      If t >= 4 And t <= 7 And fhit(n) = 0 Then TryHit n
      If t >= 16 Then EndAttack n
    Case A_KICK
      If t >= 6 And t <= 9 And fhit(n) = 0 Then TryHit n
      If t >= 22 Then EndAttack n
    Case A_LOW
      If t >= 5 And t <= 8 And fhit(n) = 0 Then TryHit n
      If t >= 20 Then EndAttack n
    Case A_ORB
      If t = 10 Then
        oon(n) = 1 : ox(n) = fx(n) + 30 * face(n) : oy(n) = fy(n) - 70 : ovx(n) = 4 * face(n)
        Sfx.Play 1, 300, -6, 12, 20, 0
      End If
      If t >= 30 Then EndAttack n
  End Select
End Sub

Sub EndAttack(ByVal n As Integer)
  fs(n) = S_IDLE : fatk(n) = 0
  If bD(n) Then fs(n) = S_CROUCH
End Sub

' does n's attack reach the other one now?
Sub TryHit(ByVal n As Integer)
  Dim o As Integer, reach As Integer, d As Integer, top As Integer, bot As Integer, z As Integer, dmg As Integer
  Dim otop As Integer
  o = 1 - n
  Select Case fatk(n)
    Case A_PUNCH: reach = 50 : top = 80 : bot = 56 : z = Z_MID : dmg = 6
    Case A_KICK: reach = 60 : top = 84 : bot = 60 : z = Z_HIGH : dmg = 10
    Case A_LOW: reach = 58 : top = 20 : bot = 0 : z = Z_LOW : dmg = 8
    Case Else: reach = 50 : top = 50 : bot = 20 : z = Z_OVER : dmg = 10
  End Select
  d = (fx(o) - fx(n)) * face(n)
  If d < 0 Or d > reach + 14 Then Exit Sub
  ' the height the attack covers (pixels above n's feet) against the other one's body
  If fs(o) = S_CROUCH Or (fs(o) = S_BLOCK And bD(o)) Then otop = 56 Else otop = 92
  If fs(o) = S_DOWN Then Exit Sub
  If (fy(n) - bot) < (fy(o) - otop) Then Exit Sub
  If (fy(n) - top) > fy(o) Then Exit Sub
  fhit(n) = 1
  Struck o, z, dmg, fx(n), fy(n) - (top + bot) \ 2
End Sub

' o is struck: blocked, or hurt
Sub Struck(ByVal o As Integer, ByVal z As Integer, ByVal dmg As Integer, ByVal hx As Integer, ByVal hy As Integer)
  Dim away As Integer, crouch As Integer, ok As Integer
  If face(o) > 0 Then away = bL(o) Else away = bR(o)
  crouch = bD(o)
  ok = 0
  If away And (fs(o) = S_IDLE Or fs(o) = S_WALK Or fs(o) = S_CROUCH Or fs(o) = S_BLOCK) Then
    Select Case z
      Case Z_MID: ok = 1
      Case Z_HIGH: ok = 1
      Case Z_LOW: ok = crouch
      Case Else: ok = Not crouch
    End Select
  End If
  sparkX = (hx + fx(o)) \ 2 : sparkY = hy : sparkT = 8
  If ok Then
    fs(o) = S_BLOCK : ft(o) = 10 : push(o) = -3 * face(o)
    hp(o) = hp(o) - 1
    Sfx.Play 1, 20, 0, 9, 5, 1
  Else
    hp(o) = hp(o) - dmg
    flash(o) = 6
    Sfx.Play 1, 8, 2, 15, 12, 1
    If hp(o) <= 0 Then
      hp(o) = 0 : fs(o) = S_DOWN : ft(o) = 0 : push(o) = -8 * face(o)
      If roundOver = 0 Then roundOver = 1
      Banner "K O"
      Sfx.Play 2, 300, 12, 15, 60, 0
    Else
      fs(o) = S_HIT : ft(o) = 16 : push(o) = -5 * face(o)
      If fy(o) < FLOOR Then fs(o) = S_JUMP : fatk(o) = 0
    End If
  End If
  Hud
End Sub

' the two can't stand in each other
Sub Separate()
  Dim d As Integer, m As Integer, l As Integer, r As Integer
  If fy(0) < FLOOR - 40 Or fy(1) < FLOOR - 40 Then Exit Sub
  If fx(0) <= fx(1) Then
    l = 0 : r = 1
  Else
    l = 1 : r = 0
  End If
  d = fx(r) - fx(l)
  If d < 36 Then
    m = (36 - d + 1) \ 2
    fx(l) = fx(l) - m : fx(r) = fx(r) + m
    If fx(l) < XMIN Then
      fx(l) = XMIN : fx(r) = XMIN + 36
    End If
    If fx(r) > XMAX Then
      fx(r) = XMAX : fx(l) = XMAX - 36
    End If
  End If
End Sub

Sub Orbs()
  Dim n As Integer, o As Integer
  For n = 0 To 1
    If oon(n) Then
      o = 1 - n
      ox(n) = ox(n) + ovx(n)
      If ox(n) < 0 Or ox(n) > 320 Then
        oon(n) = 0 : Spr.Hide 12 + n
      ElseIf oon(o) And Abs(ox(n) - ox(o)) < 12 Then
        ' two orbs meet
        oon(n) = 0 : oon(o) = 0 : Spr.Hide 12 : Spr.Hide 13
        sparkX = ox(n) : sparkY = oy(n) : sparkT = 10
        Sfx.Play 1, 5, 1, 15, 15, 1
      ElseIf Abs(ox(n) - fx(o)) < 18 And fs(o) <> S_DOWN And fy(o) > oy(n) + 8 And fy(o) - 92 < oy(n) Then
        oon(n) = 0 : Spr.Hide 12 + n
        If fs(o) = S_CROUCH And oy(n) < fy(o) - 60 Then
          ' ducked under it
        Else
          Struck o, Z_MID, 12, ox(n), oy(n)
        End If
      Else
        Spr.Put 12 + n, ox(n) - 16, oy(n) - 16, GfxData.S_ORB + ((frames \ 3) And 1), Spr.Scale2 + Spr.Pal * (n * 3)
      End If
    End If
  Next
End Sub

Sub Sparks()
  If sparkT > 0 Then
    sparkT = sparkT - 1
    If sparkT = 0 Then
      Spr.Hide 14
    Else
      Spr.Put 14, sparkX - 16, sparkY - 16, GfxData.S_SPARK + ((sparkT \ 2) And 1), Spr.Scale2
    End If
  End If
End Sub

' the six sprites of fighter n, for its state
Sub DrawFighter(ByVal n As Integer)
  Dim p As Integer, x0 As Integer, y0 As Integer, fl As Integer, c As Integer, r As Integer, s As Integer, cx As Integer
  Select Case fs(n)
    Case S_IDLE: p = GfxData.S_IDLE + ((anim(n) \ 16) And 1) * 6
    Case S_WALK: p = GfxData.S_WALK + ((anim(n) \ 8) And 1) * 6
    Case S_CROUCH: p = GfxData.S_CROUCH
    Case S_JUMP
      If fatk(n) = A_JKICK Then p = GfxData.S_KICK Else p = GfxData.S_JUMP
    Case S_ATTACK
      Select Case fatk(n)
        Case A_PUNCH
          If ft(n) < 10 Then p = GfxData.S_PUNCH Else p = GfxData.S_IDLE
        Case A_KICK
          If ft(n) < 14 Then p = GfxData.S_KICK Else p = GfxData.S_IDLE
        Case A_LOW
          If ft(n) < 14 Then p = GfxData.S_LOWKICK Else p = GfxData.S_CROUCH
        Case Else: p = GfxData.S_SPECIAL
      End Select
    Case S_BLOCK: p = GfxData.S_BLOCK
    Case S_HIT: p = GfxData.S_HIT
    Case S_DOWN
      If ft(n) < 12 Then p = GfxData.S_HIT Else p = GfxData.S_DOWN
    Case Else: p = GfxData.S_WIN
  End Select
  fl = Spr.Scale2 + Spr.Pal * n
  If flash(n) > 0 And (flash(n) And 2) Then fl = Spr.Scale2 + Spr.Pal * 2
  If face(n) < 0 Then fl = fl + Spr.MirrorX
  x0 = fx(n) - 32 : y0 = fy(n) - 96
  s = n * 6
  For r = 0 To 2
    For c = 0 To 1
      If face(n) > 0 Then cx = x0 + c * 32 Else cx = x0 + 32 - c * 32
      Spr.Put s, cx, y0 + r * 32, p, fl
      s = s + 1 : p = p + 1
    Next
  Next
End Sub
