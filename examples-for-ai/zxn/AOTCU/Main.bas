' ATTACK OF THE CYBORG UNICORNS - for the ZX Spectrum Next, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Giant cyborg unicorns are marching across the neon plain to the gate at its far left end. Fly
' your jet over them and shoot them down - each takes a lot of shooting, and goes from silver to
' pink to orange to red as it breaks up. They fire bolts from their horns. If one walks through
' the gate you lose a ship. Clear a wave and a bigger, faster one comes.
'
' Keys: Q A O P, or S X Z C, or the cursor keys (5 6 7 8): fly. Left / right turns the jet and
'       speeds it up that way. Space (or M, or Kempston fire): fire (hold it down).
'
' The landscape is one Layer 2 picture the hardware scrolls round (Scene.cls); the jet, the
' unicorns (4 sprites each, drawn twice the size) and the explosions are sprites; the bolts and
' shots are moved and checked in Z80 (Bul.cls); the HUD and the scanner are the tilemap, the
' scanner's dots sprites; the sound is the AY.
Option Explicit
Option Turbo

Const WORLD = 2048                       ' the plain is 2048 pixels long (8 screens)
Const NU = 7, NB = 8
' sprite slots (Bul has 50-127)
Const SP_SHIP = 0, SP_UNI = 1, SP_BOOM = 33, SP_WIN = 41, SP_DOTME = 42, SP_DOTU = 43
' where the jet can go (paper coordinates)
Const YTOP = 44, YLOW = 160

Dim longText As String Max 80
' the unicorns: on, x (8ths of a pixel over the plain), life, its most, how fast (8ths a frame),
' when it fires next, a hit flash
Dim uon(6) As Integer, ux(6) As Integer, uhp(6) As Integer, umax(6) As Integer, uspd(6) As Integer, ufire(6) As Integer, ufl(6) As Integer
Dim uy As Integer
' explosions: x over the plain, y, time, big
Dim bx(7) As Integer, by(7) As Integer, bt(7) As Integer, bbig(7) As Integer, bnext As Integer
' the jet: x (8ths of a pixel over the plain), y, speed (8ths a frame), facing (1 right, -1 left)
Dim sx As Integer, sy As Integer, svx As Integer, face As Integer, alive As Integer, inv As Integer, deadT As Integer, cool As Integer
Dim camX As Integer, pan As Integer
Dim score As Long, hiscore As Long, lives As Integer, wave As Integer, remain As Integer, over As Integer
Dim frames As Integer, msgT As Integer, scoreDirty As Integer, clearT As Integer
Dim i As Integer, k As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Scene.Init
Bul.Init GfxData.S_SHOT
Nx.Layers Nx.OrderSUL                    ' sprites over the HUD, the HUD over the landscape
Nx.Reg &H1C, 2                           ' the sprites cut to the paper (x halved: over the border)
Nx.Reg &H19, 16 : Nx.Reg &H19, 143 : Nx.Reg &H19, 32 : Nx.Reg &H19, 223
Nx.Reg &H15, Nx.RegGet(&H15) Or &H20
uy = Scene.GROUND - 31
hiscore = 20000
Do
  Title
  Game
Loop

' ---------------------------------------------------------------- the screen
Sub Hud()
  Tiles.Fill 0
  Tiles.Rect 4, 4, 32, 1, GfxData.T_HUD
  Tiles.Rect 4, 5, 32, 1, GfxData.T_SCANT
  Tiles.Rect 4, 6, 32, 1, GfxData.T_SCAN
  Tiles.Rect 4, 7, 32, 1, GfxData.T_SCANG
  ShowScore
  ShowLives
  Tiles.Text 20, 4, "WAVE " & Right$("0" & Trim$(Str$(wave)), 2)
End Sub

Sub ShowScore()
  Tiles.Text 4, 4, "SCORE " & Right$("000000" & Trim$(Str$(score)), 7)
  scoreDirty = 0
End Sub

Sub ShowLives()
  For k = 0 To 4
    If k < lives Then Tiles.Put 31 + k, 4, GfxData.T_LIFE Else Tiles.Put 31 + k, 4, GfxData.T_HUD
  Next
End Sub

' a message across the middle for t frames (0: until the next)
Sub Message(ByVal m As String, ByVal y As Integer, ByVal t As Integer)
  longText = m
  Tiles.Rect 4, y, 32, 1, 0
  Tiles.Text 4 + (32 - Len(longText)) \ 2, y, longText
  If t Then msgT = t
End Sub

Sub ClearMessages()
  Tiles.Rect 4, 8, 32, 20, 0
End Sub

' ---------------------------------------------------------------- the title
Sub Title()
  Dim y As Integer, cx As Integer
  Spr.HideRange 0, 50 : Spr.Show
  Bul.Reset : Bul.Show
  wave = 1 : lives = 3 : score = 0
  Hud
  Tiles.Rect 4, 4, 32, 1, GfxData.T_HUD
  Tiles.Text 4, 4, "HI " & Right$("000000" & Trim$(Str$(hiscore)), 7)
  Message "ATTACK OF THE", 9, 0
  Message "CYBORG UNICORNS", 10, 0
  Message "STOP THEM BEFORE THE GATE", 12, 0
  Message "QAOP / SXZC / 5678  FLY", 14, 0
  Message "SPACE  FIRE", 15, 0
  Message "(C) 2026 CYBORG UNICORN", 26, 0
  ' a unicorn walking by while you wait
  For k = 0 To NU - 1
    uon(k) = 0
  Next
  uon(0) = 1 : ux(0) = 300 * 8 : uhp(0) = 1 : umax(0) = 1 : uspd(0) = 3 : ufl(0) = 0
  camX = 0 : y = 0
  Do
    camX = camX + 1
    If camX >= WORLD - 256 Then camX = 0
    ux(0) = ux(0) - uspd(0)
    If ux(0) \ 8 < camX - 40 Then ux(0) = (camX + 320) * 8
    DrawUnicorn 0
    Frame
    Scene.Scroll camX
    Spr.Show
    Sfx.Update
    y = y + 1
    If y = 30 Then Message "PRESS SPACE", 27, 0
    If y = 60 Then Tiles.Rect 4, 27, 32, 1, 0 : y = 0
  Loop Until FireDown()
  Do
    Frame
  Loop While FireDown()
  Tiles.Rect 4, 8, 32, 20, 0
  Sfx.Play 0, 200, -6, 15, 25, 0
End Sub

Function FireDown() As Integer
  FireDown = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyM) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
End Function

' ---------------------------------------------------------------- a game
Sub Game()
  score = 0 : lives = 3 : wave = 1 : over = 0
  Do
    WaveRun
    If over Then Exit Do
    wave = wave + 1
  Loop
  If score > hiscore Then hiscore = score
  Message "GAME OVER", 14, 0
  For k = 1 To 250
    Frame
    Sfx.Update
    If k > 50 And FireDown() Then Exit For
  Next
  ClearMessages
End Sub

' one wave: until every unicorn is down, or the last ship is lost
Sub WaveRun()
  Dim n As Integer, b As Long
  Spr.HideRange 0, 50
  Bul.Reset
  For k = 0 To NB - 1
    bt(k) = 0
  Next
  n = 3 + wave
  If n > NU Then n = NU
  For k = 0 To NU - 1
    uon(k) = 0
    If k < n Then
      uon(k) = 1
      ux(k) = (WORLD - 120 - k * 190 - Rnd(60)) * 8
      umax(k) = 16 + wave * 4 : uhp(k) = umax(k)
      uspd(k) = 2 + wave \ 2 + Rnd(2)
      If uspd(k) > 7 Then uspd(k) = 7
      ufire(k) = 100 + Rnd(100)
      ufl(k) = 0
    End If
  Next
  remain = n
  sx = 80 * 8 : sy = 100 : svx = 0 : face = 1 : alive = 1 : inv = 100 : deadT = 0 : cool = 0
  camX = 0 : pan = 0
  Hud
  Message "WAVE " & Trim$(Str$(wave)), 13, 120
  Message Trim$(Str$(n)) & " CYBORG UNICORNS COMING", 15, 120
  clearT = 0
  Do
    PlayerMove
    Camera
    Unicorns
    Booms
    If alive Then Bul.Step sx \ 8 - camX, sy, pan Else Bul.Step 0, 0, pan
    If alive And inv = 0 Then
      If Bul.Hit() Then Die
    End If
    DrawShip
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
    If remain = 0 Then
      clearT = clearT + 1
      If clearT = 30 Then
        b = wave * 1000
        AddScore b
        Message "WAVE " & Trim$(Str$(wave)) & " CLEARED", 13, 0
        Message "BONUS " & Trim$(Str$(b)), 15, 0
        Sfx.Play 0, 100, -2, 15, 50, 0
      End If
      If clearT > 170 Then ClearMessages : Exit Sub
    End If
  Loop
End Sub

Sub AddScore(ByVal n As Long)
  score = score + n
  scoreDirty = 1
End Sub

' ---------------------------------------------------------------- the jet
Sub PlayerMove()
  Dim j0 As Integer, mx As Integer, my As Integer
  If alive = 0 Then
    If deadT > 0 Then
      deadT = deadT - 1
      If deadT = 0 And lives > 0 Then
        alive = 1 : inv = 120 : sy = 100 : svx = 0
        sx = (camX + 128) * 8
      End If
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
    svx = svx + mx * 3
    If svx > 40 Then svx = 40
    If svx < -40 Then svx = -40
  Else
    If svx > 0 Then svx = svx - 1
    If svx < 0 Then svx = svx + 1
  End If
  sx = sx + svx
  If sx < 64 Then sx = 64 : svx = 0
  If sx > (WORLD - 8) * 8 Then sx = (WORLD - 8) * 8 : svx = 0
  sy = sy + my * 2
  If sy < YTOP Then sy = YTOP
  If sy > YLOW Then sy = YLOW
  If cool > 0 Then cool = cool - 1
  If FireDown() And cool = 0 Then
    Bul.Shot sx \ 8 - camX + face * 8, sy + 1, face * 14 + svx \ 8
    cool = 5
    Sfx.Play 0, 30, 4, 10, 4, 0
  End If
  If inv > 0 Then inv = inv - 1
End Sub

' the view: the jet a third of the way in from the side it's leaving
Sub Camera()
  Dim want As Integer, was As Integer
  was = camX
  If face > 0 Then want = sx \ 8 - 88 Else want = sx \ 8 - 168
  If want < 0 Then want = 0
  If want > WORLD - 256 Then want = WORLD - 256
  If want > camX + 7 Then
    camX = camX + 7
  ElseIf want < camX - 7 Then
    camX = camX - 7
  Else
    camX = want
  End If
  pan = camX - was
End Sub

Sub DrawShip()
  Dim fl As Integer
  If alive = 0 Or (inv And 4) <> 0 Then
    Spr.Hide SP_SHIP
  Else
    If face < 0 Then fl = Spr.MirrorX Else fl = 0
    Spr.Put SP_SHIP, sx \ 8 - camX + 24, sy + 24, GfxData.S_SHIP + ((frames \ 3) And 1), fl
  End If
  If Bul.Sparked() Then Sfx.Play 1, 8, 2, 9, 3, 1
End Sub

Sub Die()
  alive = 0 : deadT = 100 : lives = lives - 1 : ShowLives
  Boom sx \ 8, sy, 1
  Boom sx \ 8 - 10, sy - 6, 0
  Boom sx \ 8 + 10, sy + 6, 0
  k = Bul.Clear()
  Spr.Hide SP_SHIP
  Sfx.Play 2, 31, 0, 15, 70, 1
  Sfx.Play 1, 300, 10, 15, 50, 0
End Sub

' ---------------------------------------------------------------- the unicorns
Sub Unicorns()
  Dim n As Integer, x As Integer, h As Integer, a As Integer, sp As Integer
  For n = 0 To NU - 1
    If uon(n) Then
      ux(n) = ux(n) - uspd(n)
      x = ux(n) \ 8 - camX                 ' its middle on the screen
      ' through the gate
      If ux(n) < 0 Then
        Message "ONE BROKE THROUGH THE GATE!", 14, 120
        ux(n) = (WORLD - 60) * 8
        If alive Then Die Else lives = lives - 1 : ShowLives
        If lives < 0 Then lives = 0
      End If
      ' shot
      h = Bul.Hits(n)
      If h > 0 Then
        uhp(n) = uhp(n) - h
        If (frames And 3) = 0 Then ufl(n) = 1
        AddScore 10 * h
        Sfx.Play 1, 60, -4, 11, 4, 0
        If uhp(n) <= 0 Then
          Kill n
        End If
      End If
      If uon(n) Then
        If x > 8 And x < 248 Then Bul.Box n, x, uy + 4, 26, 26 Else Bul.Off n
        ' its horn fires at you
        ufire(n) = ufire(n) - 1
        If ufire(n) <= 0 Then
          a = 130 - wave * 8
          If a < 45 Then a = 45
          ufire(n) = a + Rnd(50)
          If alive And x > 16 And x < 240 Then
            sp = 18 + wave * 2
            If sp > 40 Then sp = 40
            a = Bul.Aim(x - 26, uy - 28, sx \ 8 - camX, sy)
            Bul.Fire x - 26, uy - 28, a, sp, GfxData.S_BOLT, 0
            If wave >= 3 Then
              Bul.Fire x - 26, uy - 28, a - 12, sp, GfxData.S_BOLT, 0
              Bul.Fire x - 26, uy - 28, a + 12, sp, GfxData.S_BOLT, 0
            End If
            Sfx.Play 2, 120, -6, 12, 14, 0
          End If
        End If
        ' running into it
        If alive And inv = 0 Then
          If Abs(sx \ 8 - camX - x) < 26 And Abs(sy - uy) < 28 Then Die
        End If
        DrawUnicorn n
      End If
    End If
  Next
End Sub

' unicorn n's four sprites (two by two, each drawn twice the size), coloured by its damage
Sub DrawUnicorn(ByVal n As Integer)
  Dim x As Integer, y As Integer, f As Integer, fl As Integer, ci As Integer, cj As Integer, px As Integer, slot As Integer
  slot = SP_UNI + n * 4
  x = ux(n) \ 8 - camX
  If x < -40 Or x > 300 Then
    Spr.HideRange slot, 4
    Exit Sub
  End If
  f = ((ux(n) \ 8) \ 5) And 3
  fl = Spr.Scale2 Or (Spr.Pal * ((umax(n) - uhp(n)) * 4 \ (umax(n) + 1)))
  If ufl(n) > 0 Then ufl(n) = ufl(n) - 1 : fl = Spr.Scale2 Or (Spr.Pal * 4)
  For cj = 0 To 1
    For ci = 0 To 1
      px = x - 32 + ci * 32 + 32
      If px < 0 Or px > 319 Then
        Spr.Hide slot + cj * 2 + ci
      Else
        Spr.Put slot + cj * 2 + ci, px, uy - 32 + cj * 32 + 32, GfxData.S_UNICORN + f * 4 + cj * 2 + ci, fl
      End If
    Next
  Next
End Sub

Sub Kill(ByVal n As Integer)
  Dim x As Integer
  uon(n) = 0 : remain = remain - 1
  Bul.Off n
  Spr.HideRange SP_UNI + n * 4, 4
  x = ux(n) \ 8
  Boom x, uy, 1
  Boom x - 18, uy - 16, 1
  Boom x + 16, uy - 6, 0
  Boom x - 6, uy + 18, 0
  AddScore 500 * wave
  Sfx.Play 2, 31, 0, 15, 50, 1
  Sfx.Play 0, 40, 8, 14, 40, 0
End Sub

' ---------------------------------------------------------------- explosions
Sub Boom(ByVal x As Integer, ByVal y As Integer, ByVal big As Integer)
  bx(bnext) = x : by(bnext) = y : bt(bnext) = 16 : bbig(bnext) = big
  bnext = (bnext + 1) And 7
End Sub

Sub Booms()
  Dim n As Integer, x As Integer
  For n = 0 To NB - 1
    If bt(n) > 0 Then
      bt(n) = bt(n) - 1
      x = bx(n) - camX
      If bt(n) = 0 Or x < -16 Or x > 272 Then
        Spr.Hide SP_BOOM + n
      ElseIf bbig(n) Then
        Spr.Put SP_BOOM + n, x + 16, by(n) + 16, GfxData.S_BOOM + (15 - bt(n)) \ 4, Spr.Scale2
      Else
        Spr.Put SP_BOOM + n, x + 24, by(n) + 24, GfxData.S_BOOM + (15 - bt(n)) \ 4, 0
      End If
    End If
  Next
End Sub

' ---------------------------------------------------------------- the scanner
' the whole plain in 256 pixels (8 to 1): you, the unicorns, the part on screen
Sub Scanner()
  Dim n As Integer
  Spr.Put SP_WIN, camX \ 8 + 32, 42, GfxData.S_WINDOW, Spr.Scale2X
  If alive Then
    Spr.Put SP_DOTME, sx \ 64 + 24, 12 + (sy - 36) * 14 \ 130 + 24, GfxData.S_DOT, 0
  Else
    Spr.Hide SP_DOTME
  End If
  For n = 0 To NU - 1
    If uon(n) Then
      Spr.Put SP_DOTU + n, ux(n) \ 64 + 24, 12 + (uy - 36) * 14 \ 130 + 24, GfxData.S_DOT + 1, 0
    Else
      Spr.Hide SP_DOTU + n
    End If
  Next
End Sub
