' SIEGE - an alien invasion shooter for the ZX Spectrum Next, in NTC BASIC (VB5 flavour)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Straight to the Next's hardware, no ROM, no OS: the tilemap (Tiles.cls) draws the stars, the
' shields, the ground and the text; the hardware sprites (Spr.cls) are the aliens, the cannon,
' the shots; the AY (Sfx.cls) the sound. The art is in gfx/ - swap it with gfxtool.js.
'
' Keys: O / P or 5 / 8 (cursor left / right) move, Space / M / 0 fire. Kempston joystick too.
Option Explicit
Option Turbo

Const NCOL = 11, NROW = 5, NAL = 55
Const ADX = 18, ADY = 16             ' the formation's spacing
Const PY = 224                       ' the cannon's sprite y
Const SROW = 24                      ' the shields' top row (tiles 24-26)
Const GROW = 30                      ' the ground's row
Const SL_PLAYER = 55, SL_SHOT = 56, SL_BOMB = 57, SL_SAUCER = 60, SL_BOOM = 61, SL_ICON = 62

Dim alive(54) As Byte
Dim fx As Integer, fy As Integer, fdir As Integer, ftimer As Integer, fanim As Integer
Dim nalive As Integer, mincol As Integer, maxcol As Integer, maxrow As Integer
Dim px As Integer, pdead As Integer, lives As Integer, wave As Integer, over As Integer
Dim score As Long, hiscore As Long, nextlife As Long
Dim sx As Integer, sy As Integer, son As Integer
Dim bx(2) As Integer, by(2) As Integer, bon(2) As Integer, banim As Integer
Dim ux As Integer, uon As Integer, udir As Integer, utimer As Integer
Dim boomx As Integer, boomy As Integer, boomt As Integer, msgt As Integer, msgx As Integer
Dim firewas As Integer, note As Integer, frames As Integer, seed As Integer
Dim i As Integer, j As Integer, k As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Nx.Layers Nx.OrderSLU
hiscore = 1000
Do
  Title
  Play
  GameOver
Loop

' ---------------------------------------------------------------- input
Function KLeft() As Integer
  KLeft = Keys.Down(Keys.KeyO) Or Keys.Down(Keys.KeyLeft) Or ((Keys.Joystick(0) And Keys.JoyLeft) <> 0)
End Function

Function KRight() As Integer
  KRight = Keys.Down(Keys.KeyP) Or Keys.Down(Keys.KeyRight) Or ((Keys.Joystick(0) And Keys.JoyRight) <> 0)
End Function

Function KFire() As Integer
  KFire = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyM) Or Keys.Down(Keys.Key0) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
End Function

' fire pressed now and not last time
Function FirePressed() As Integer
  Dim f As Integer
  f = KFire()
  FirePressed = f And Not firewas
  firewas = f
End Function

' ---------------------------------------------------------------- the screen
Sub Stars()
  Dim n As Integer
  Tiles.Fill 0
  For n = 1 To 70
    Tiles.Put Rnd(40), 3 + Rnd(20), GfxData.T_STAR + Rnd(3)
  Next
  Tiles.Rect 0, GROW, 40, 2, GfxData.T_GROUND
  Tiles.Rect 0, GROW, 40, 1, GfxData.T_GROUNDTOP
End Sub

Sub Shields()
  Dim n As Integer, c As Integer
  For n = 0 To 3
    c = 6 + n * 8
    Tiles.Rect c, SROW, 4, 3, GfxData.T_SHIELD
    Tiles.Put c + 1, SROW + 2, 0
    Tiles.Put c + 2, SROW + 2, 0
  Next
End Sub

Sub Hud()
  Dim i As Integer
  Tiles.Text 1, 1, "SCORE " & Format$(score, "000000")
  Tiles.Text 16, 1, "HI " & Format$(hiscore, "000000")
  Tiles.Text 28, 1, "WAVE " & Format$(wave, "00")
  Tiles.Rect 35, 1, 4, 1, 0
  For i = 1 To lives - 1
    If i < 5 Then Tiles.Put 34 + i, 1, GfxData.T_LIFE
  Next
End Sub

' a big word in logo blocks: 3 x 5 letters, each a row of bits
Sub BigText(ByVal x As Integer, ByVal y As Integer, ByVal s As String, ByVal colour As Integer)
  Dim n As Integer, r As Integer, b As Integer, bits As Integer, ch As String
  For n = 1 To Len(s)
    ch = Mid$(s, n, 1)
    For r = 0 To 4
      bits = Glyph(ch, r)
      For b = 0 To 2
        If bits And (4 \ (2 ^ b)) Then
          Tiles.Put x + b, y + r, GfxData.T_LOGO + colour
        End If
      Next
    Next
    x = x + 4
  Next
End Sub

' the rows of a 3 x 5 letter (bit 2 = left)
Function Glyph(ByVal ch As String, ByVal r As Integer) As Integer
  Dim p As String
  Select Case ch
    Case "S": p = "74717"
    Case "I": p = "72227"
    Case "E": p = "74647"
    Case "G": p = "74557"
    Case "A": p = "25755"
    Case "M": p = "57555"
    Case "O": p = "75557"
    Case "V": p = "55552"
    Case "R": p = "75654"
    Case "W": p = "55575"
    Case Else: p = "00000"
  End Select
  Glyph = Val(Mid$(p, r + 1, 1))
End Function

' ---------------------------------------------------------------- the title
Sub Title()
  Spr.HideRange 0, 64
  Stars
  BigText 10, 4, "SIEGE", 0
  Tiles.Text 11, 11, "DEFEND THE GROUND"
  Spr.Put 0, 112, 104, GfxData.S_SAUCER, 0
  Tiles.Text 17, 13, "= ??? MYSTERY"
  Spr.Put 1, 112, 120, GfxData.S_ALIENA, Spr.Pal * 3
  Tiles.Text 17, 15, "= 30 POINTS"
  Spr.Put 2, 112, 136, GfxData.S_ALIENB, Spr.Pal * 1
  Tiles.Text 17, 17, "= 20 POINTS"
  Spr.Put 3, 112, 152, GfxData.S_ALIENC, Spr.Pal * 2
  Tiles.Text 17, 19, "= 10 POINTS"
  Tiles.Text 6, 23, "O P  5 8  MOVE   SPACE  FIRE"
  Tiles.Text 10, 26, "PRESS FIRE TO START"
  Tiles.Text 1, 1, "SCORE " & Format$(score, "000000")
  Tiles.Text 16, 1, "HI " & Format$(hiscore, "000000")
  Tiles.Text 7, 28, "NTC BASIC  ZX SPECTRUM NEXT"
  frames = 0
  firewas = -1
  Do
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1
    seed = seed + 1
    k = (frames \ 16) And 1
    Spr.Put 1, 112, 120, GfxData.S_ALIENA + k, Spr.Pal * 3
    Spr.Put 2, 112, 136, GfxData.S_ALIENB + k, Spr.Pal * 1
    Spr.Put 3, 112, 152, GfxData.S_ALIENC + k, Spr.Pal * 2
    If (frames And 31) = 0 Then Tiles.Text 10, 26, "PRESS FIRE TO START"
    If (frames And 31) = 20 Then Tiles.Text 10, 26, "                   "
  Loop Until FirePressed()
  Nx.Seed seed
End Sub

' ---------------------------------------------------------------- a game
Sub Play()
  score = 0 : lives = 3 : wave = 1 : over = 0 : nextlife = 1500
  NewWave
  Do
    Frame
    Spr.Show
    Sfx.Update
    frames = frames + 1
    If pdead > 0 Then
      PlayerDying
    Else
      MovePlayer
      MoveShot
      StepFormation
      MoveBombs
      DropBombs
    End If
    MoveSaucer
    Effects
    If nalive = 0 And pdead = 0 Then
      wave = wave + 1
      NewWave
    End If
  Loop Until over
End Sub

Sub NewWave()
  Dim n As Integer
  Spr.HideRange 0, 64
  Stars
  Shields
  For n = 0 To NAL - 1
    alive(n) = 1
  Next
  nalive = NAL : mincol = 0 : maxcol = NCOL - 1 : maxrow = NROW - 1
  n = wave - 1
  If n > 5 Then n = 5
  fx = 40 : fy = 40 + n * 8 : fdir = 2 : ftimer = 1 : fanim = 0
  px = 152 : pdead = 0 : son = 0 : uon = 0 : utimer = 600 + Rnd(600)
  For n = 0 To 2
    bon(n) = 0
  Next
  boomt = 0 : msgt = 0
  Hud
  DrawFormation
  Spr.Put SL_PLAYER, px, PY, GfxData.S_PLAYER, 0
  ' "WAVE n" for a moment
  Tiles.Text 16, 16, "WAVE " & Format$(wave, "00")
  For n = 1 To 90
    Frame
    Spr.Show
    Sfx.Update
  Next
  Tiles.Text 16, 16, "        "
End Sub

' every alien's sprite where the formation is now
Sub DrawFormation()
  Dim r As Integer, c As Integer, n As Integer, x As Integer, y As Integer, pat As Integer, fl As Integer
  n = 0
  y = fy
  For r = 0 To NROW - 1
    Select Case r
      Case 0: pat = GfxData.S_ALIENA : fl = Spr.Pal * 3
      Case 1, 2: pat = GfxData.S_ALIENB : fl = Spr.Pal * 1
      Case Else: pat = GfxData.S_ALIENC : fl = Spr.Pal * 2
    End Select
    pat = pat + fanim
    x = fx
    For c = 0 To NCOL - 1
      If alive(n) Then Spr.Put n, x, y, pat, fl
      n = n + 1
      x = x + ADX
    Next
    y = y + ADY
  Next
End Sub

Sub StepFormation()
  Dim drop As Integer, edge As Integer
  ftimer = ftimer - 1
  If ftimer > 0 Then Exit Sub
  ftimer = nalive \ 4 + 1
  drop = 0
  If fdir > 0 Then
    edge = fx + maxcol * ADX + 16 + fdir
    If edge > 312 Then drop = 1
  Else
    edge = fx + mincol * ADX + fdir
    If edge < 8 Then drop = 1
  End If
  If drop Then
    fy = fy + 8
    fdir = -fdir
  Else
    fx = fx + fdir
  End If
  fanim = 1 - fanim
  ' the march: four notes going down
  Sfx.Play 2, 700 + note * 90, 0, 11, 4, 0
  note = (note + 1) And 3
  DrawFormation
  ' low enough to eat the shields, or to land
  If fy + maxrow * ADY + 14 >= SROW * 8 Then EatShields
  If fy + maxrow * ADY + 13 >= PY + 2 Then
    over = 1
    Sfx.Play 1, 20, 1, 15, 60, 1
  End If
End Sub

' the bottom row of aliens wipes out the shield bricks it touches
Sub EatShields()
  Dim c As Integer, x As Integer, y As Integer, t As Integer, n As Integer, dx As Integer, dy As Integer
  y = fy + maxrow * ADY
  For c = mincol To maxcol
    n = maxrow * NCOL + c
    If alive(n) Then
      x = fx + c * ADX
      For dy = 2 To 14 Step 6
        For dx = 1 To 15 Step 7
          t = Tiles.At(x + dx, y + dy)
          If t >= GfxData.T_SHIELD And t < GfxData.T_SHIELD + 4 Then Tiles.Put (x + dx) \ 8, (y + dy) \ 8, 0
        Next
      Next
    End If
  Next
End Sub

Sub MovePlayer()
  If KLeft() And px > 8 Then px = px - 2
  If KRight() And px < 296 Then px = px + 2
  Spr.Put SL_PLAYER, px, PY, GfxData.S_PLAYER, 0
  If FirePressed() And son = 0 Then
    son = 1 : sx = px : sy = PY - 8
    Sfx.Play 0, 60, 6, 12, 10, 0
  End If
End Sub

Sub MoveShot()
  Dim tx As Integer, ty As Integer, c As Integer, r As Integer, n As Integer, t As Integer, b As Integer
  If son = 0 Then Exit Sub
  sy = sy - 6
  tx = sx + 7 : ty = sy + 4
  If ty < 16 Then
    son = 0 : Spr.Hide SL_SHOT : Exit Sub
  End If
  ' a shield
  t = Tiles.At(tx, ty)
  If t >= GfxData.T_SHIELD And t < GfxData.T_SHIELD + 4 Then
    Damage tx, ty, t
    son = 0 : Spr.Hide SL_SHOT : Exit Sub
  End If
  ' an alien
  If tx >= fx And ty >= fy Then
    c = (tx - fx) \ ADX : r = (ty - fy) \ ADY
    If c < NCOL And r < NROW Then
      n = r * NCOL + c
      If alive(n) And tx - fx - c * ADX <= 14 And ty - fy - r * ADY <= 13 Then
        KillAlien n, c, r
        son = 0 : Spr.Hide SL_SHOT : Exit Sub
      End If
    End If
  End If
  ' the saucer
  If uon Then
    If tx >= ux + 1 And tx <= ux + 14 And ty >= 20 And ty <= 30 Then
      HitSaucer
      son = 0 : Spr.Hide SL_SHOT : Exit Sub
    End If
  End If
  ' a bomb
  For b = 0 To 2
    If bon(b) Then
      If Abs(tx - bx(b) - 7) <= 2 And ty >= by(b) + 4 And ty <= by(b) + 14 Then
        bon(b) = 0 : Spr.Hide SL_BOMB + b
        son = 0 : Spr.Hide SL_SHOT
        Boom bx(b), by(b)
        Exit Sub
      End If
    End If
  Next
  Spr.Put SL_SHOT, sx, sy, GfxData.S_SHOT, 0
End Sub

Sub Damage(ByVal x As Integer, ByVal y As Integer, ByVal t As Integer)
  If t = GfxData.T_SHIELD + 3 Then
    Tiles.Put x \ 8, y \ 8, 0
  Else
    Tiles.Put x \ 8, y \ 8, t + 1
  End If
End Sub

Sub KillAlien(ByVal n As Integer, ByVal c As Integer, ByVal r As Integer)
  Dim m As Integer
  alive(n) = 0
  Spr.Hide n
  nalive = nalive - 1
  Select Case r
    Case 0: AddScore 30
    Case 1, 2: AddScore 20
    Case Else: AddScore 10
  End Select
  Boom fx + c * ADX, fy + r * ADY
  Sfx.Play 1, 6, 1, 14, 14, 1
  ' the formation's edges now
  mincol = NCOL : maxcol = -1 : maxrow = -1
  For m = 0 To NAL - 1
    If alive(m) Then
      c = m Mod NCOL : r = m \ NCOL
      If c < mincol Then mincol = c
      If c > maxcol Then maxcol = c
      If r > maxrow Then maxrow = r
    End If
  Next
End Sub

Sub AddScore(ByVal n As Integer)
  score = score + n
  If score >= nextlife Then
    nextlife = nextlife + 1500
    If lives < 5 Then lives = lives + 1
    Sfx.Play 0, 100, -4, 15, 30, 0
  End If
  If score > hiscore Then hiscore = score
  Hud
End Sub

Sub Boom(ByVal x As Integer, ByVal y As Integer)
  boomx = x : boomy = y : boomt = 12
End Sub

' ---------------------------------------------------------------- the bombs
Sub DropBombs()
  Dim b As Integer, c As Integer, r As Integer, n As Integer, rate As Integer
  rate = 3 + wave
  If Rnd(100) >= rate Then Exit Sub
  For b = 0 To 2
    If bon(b) = 0 Then Exit For
  Next
  If b > 2 Then Exit Sub
  ' a column: half the time the one over the cannon
  If Rnd(2) = 0 Then
    c = (px + 8 - fx) \ ADX
    If c < 0 Or c >= NCOL Then c = mincol + Rnd(maxcol - mincol + 1)
  Else
    c = mincol + Rnd(maxcol - mincol + 1)
  End If
  For r = NROW - 1 To 0 Step -1
    n = r * NCOL + c
    If alive(n) Then
      bon(b) = 1 : bx(b) = fx + c * ADX : by(b) = fy + r * ADY + 8
      Exit Sub
    End If
  Next
End Sub

Sub MoveBombs()
  Dim b As Integer, tx As Integer, ty As Integer, t As Integer
  banim = banim + 1
  For b = 0 To 2
    If bon(b) Then
      by(b) = by(b) + 3
      tx = bx(b) + 7 : ty = by(b) + 12
      If ty >= GROW * 8 Then
        bon(b) = 0 : Spr.Hide SL_BOMB + b
      Else
        t = Tiles.At(tx, ty)
        If t >= GfxData.T_SHIELD And t < GfxData.T_SHIELD + 4 Then
          Damage tx, ty, t
          bon(b) = 0 : Spr.Hide SL_BOMB + b
        ElseIf tx >= px + 1 And tx <= px + 14 And ty >= PY + 3 And ty <= PY + 13 Then
          bon(b) = 0 : Spr.Hide SL_BOMB + b
          KillPlayer
        Else
          Spr.Put SL_BOMB + b, bx(b), by(b), GfxData.S_BOMB + ((banim \ 4) And 1), 0
        End If
      End If
    End If
  Next
End Sub

Sub KillPlayer()
  pdead = 100
  son = 0 : Spr.Hide SL_SHOT
  Sfx.Play 1, 31, 0, 15, 70, 1
  Sfx.Play 0, 300, 12, 13, 50, 0
End Sub

Sub PlayerDying()
  Dim b As Integer
  pdead = pdead - 1
  If pdead > 20 Then
    Spr.Put SL_PLAYER, px, PY, GfxData.S_PDIE + ((pdead \ 5) And 1), 0
  Else
    Spr.Hide SL_PLAYER
  End If
  If pdead = 0 Then
    lives = lives - 1
    For b = 0 To 2
      bon(b) = 0 : Spr.Hide SL_BOMB + b
    Next
    If lives = 0 Then
      over = 1
    Else
      px = 152
      Spr.Put SL_PLAYER, px, PY, GfxData.S_PLAYER, 0
    End If
    Hud
  End If
End Sub

' ---------------------------------------------------------------- the saucer
Sub MoveSaucer()
  If uon = 0 Then
    utimer = utimer - 1
    If utimer <= 0 And nalive > 7 And pdead = 0 Then
      uon = 1
      If Rnd(2) Then
        ux = 0 : udir = 1
      Else
        ux = 304 : udir = -1
      End If
    End If
    Exit Sub
  End If
  ux = ux + udir
  If ux < 0 Or ux > 304 Then
    uon = 0 : utimer = 900 + Rnd(600) : Spr.Hide SL_SAUCER : Exit Sub
  End If
  Spr.Put SL_SAUCER, ux, 18, GfxData.S_SAUCER, 0
  If (frames And 7) = 0 Then Sfx.Play 2, 120 + (frames And 8) * 6, 0, 9, 6, 0
End Sub

Sub HitSaucer()
  Dim pts As Integer
  pts = Choose(Rnd(4) + 1, 50, 100, 150, 300)
  uon = 0 : utimer = 900 + Rnd(600)
  Spr.Hide SL_SAUCER
  Boom ux, 18
  AddScore pts
  msgx = ux \ 8 : msgt = 60
  If msgx > 36 Then msgx = 36
  Tiles.Text msgx, 3, CStr(pts)
  Sfx.Play 1, 12, -1, 15, 30, 1
End Sub

' ---------------------------------------------------------------- explosions, messages
Sub Effects()
  If boomt > 0 Then
    boomt = boomt - 1
    If boomt = 0 Then
      Spr.Hide SL_BOOM
    Else
      Spr.Put SL_BOOM, boomx, boomy, GfxData.S_BOOM + ((boomt \ 4) And 1), 0
    End If
  End If
  If msgt > 0 Then
    msgt = msgt - 1
    If msgt = 0 Then Tiles.Text msgx, 3, "   "
  End If
End Sub

' ---------------------------------------------------------------- the end of a game
Sub GameOver()
  Dim n As Integer
  Tiles.Text 15, 15, "GAME  OVER"
  Hud
  For n = 1 To 200
    Frame
    Spr.Show
    Sfx.Update
    If n > 50 And FirePressed() Then Exit For
  Next
  Sfx.Quiet
End Sub
