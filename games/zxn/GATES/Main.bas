' GATES OF DOOM - for the ZX Spectrum Next, in NTC BASIC.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' After Jeff Minter's Hell Gate. Four laser guns run on rails round the edge of the arena, and you
' move them all at once, each pair the opposite way to each other: left / right moves the top and
' bottom guns across (one left, one right), up / down moves the side guns (one up, one down). Fire
' and all four shoot inwards together; where their lines cross are your four sights. Gates of Doom
' open in the arena and pour out demons that go for your guns: imps, wraiths, bouncing skulls,
' and fire fiends that spit fireballs. Shoot the gates shut and the demons down.
' Any gun hit is a life lost: a demon reaching it, a fireball, or the opposite gun's laser when
' the two line up. Every third wave cleared gives a life back (4 at most).
'
' Keys: Q A O P, or S X Z C, or the cursor keys (5 6 7 8): move the guns.
'       Space (or M, or Kempston fire): fire (hold it down).
'
' The arena is one Layer 2 picture (Arena.cls); the guns, the gates, the demons and the explosions
' are sprites; the shots and fireballs are moved and checked in Z80 (Bul.cls); the HUD is the
' tilemap; the sound is the AY.
Option Explicit
Option Turbo

Const NG = 4, NE = 14, NB = 8
' sprite slots (Bul has 50-127)
Const SP_GUN = 0, SP_CROSS = 4, SP_GATE = 5, SP_EN = 9, SP_BOOM = 23, SP_CROSS2 = 31
' the guns' targets for Bul (each gun can be hit by the gun opposite)
Const BOXGUN = 20
' demons
Const K_IMP = 1, K_WRAITH = 2, K_SKULL = 3, K_FIEND = 4
' where the guns run (paper coordinates: the gun's middle)
Const GXMIN = 28, GXMAX = 228, GYMIN = 44, GYMAX = 164

Dim longText As String Max 80
' the guns: 0 top, 1 bottom, 2 left, 3 right; the top / bottom ones at x = gx, the sides at y = gy
Dim galive(3) As Integer, gunX(3) As Integer, gunY(3) As Integer
Dim gx As Integer, gy As Integer, cool As Integer, lives As Integer, hitT As Integer
' the gates: open, where, life, its most, when the next demon comes, a hit flash
Dim gon(3) As Integer, gtx(3) As Integer, gty(3) As Integer, ghp(3) As Integer, gmax(3) As Integer, gspawn(3) As Integer, gfl(3) As Integer
' the demons: kind, position and speed (16ths of a pixel), life, timer, which gun it wants, a flash
Dim ek(13) As Integer, ex(13) As Integer, ey(13) As Integer, evx(13) As Integer, evy(13) As Integer
Dim ehp(13) As Integer, et(13) As Integer, etg(13) As Integer, efl(13) As Integer
' explosions
Dim bx(7) As Integer, by(7) As Integer, bt(7) As Integer, bbig(7) As Integer, bnext As Integer
Dim score As Long, hiscore As Long, wave As Integer, over As Integer, gatesOpen As Integer, demonCount As Integer
Dim frames As Integer, msgT As Integer, scoreDirty As Integer, clearT As Integer
Dim k As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Arena.Init
Bul.Init GfxData.S_SHOT
Nx.Layers Nx.OrderSUL                    ' sprites over the HUD, the HUD over the arena
Nx.Reg &H1C, 2                           ' the sprites cut to the arena (x halved: over the border)
Nx.Reg &H19, 16 : Nx.Reg &H19, 143 : Nx.Reg &H19, 48 : Nx.Reg &H19, 223
Nx.Reg &H15, Nx.RegGet(&H15) Or &H20
hiscore = 20000
Do
  Title
  Game
Loop

' ---------------------------------------------------------------- the screen
Sub Hud()
  Tiles.Fill 0
  Tiles.Rect 4, 4, 32, 1, GfxData.T_HUD
  Tiles.Rect 4, 5, 32, 1, GfxData.T_HUDB
  ShowScore
  ShowLives
  ShowGates
  Tiles.Text 16, 4, "WAVE " & Right$("0" & Trim$(Str$(wave)), 2)
End Sub

Sub ShowScore()
  Tiles.Text 4, 4, Right$("000000" & Trim$(Str$(score)), 7)
  scoreDirty = 0
End Sub

Sub ShowLives()
  For k = 0 To 3
    If k < lives Then Tiles.Put 32 + k, 4, GfxData.T_GUN Else Tiles.Put 32 + k, 4, GfxData.T_HUD
  Next
End Sub

Sub ShowGates()
  For k = 0 To 3
    If k < gatesOpen Then Tiles.Put 25 + k, 4, GfxData.T_GATE Else Tiles.Put 25 + k, 4, GfxData.T_HUD
  Next
End Sub

Sub Message(ByVal m As String, ByVal y As Integer, ByVal t As Integer)
  longText = m
  Tiles.Rect 4, y, 32, 1, 0
  Tiles.Text 4 + (32 - Len(longText)) \ 2, y, longText
  If t Then msgT = t
End Sub

Sub ClearMessages()
  Tiles.Rect 4, 6, 32, 22, 0
End Sub

Function FireDown() As Integer
  FireDown = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyM) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
End Function

' ---------------------------------------------------------------- the title
Sub Title()
  Dim y As Integer
  Spr.HideRange 0, 50 : Spr.Show
  Bul.Reset : Bul.Show
  wave = 1 : score = 0 : lives = 3 : hitT = 0
  For k = 0 To 3
    galive(k) = 1
  Next
  Hud
  Tiles.Rect 4, 4, 32, 1, GfxData.T_HUD
  Tiles.Text 4, 4, "HI " & Right$("000000" & Trim$(Str$(hiscore)), 7)
  Message "G A T E S   O F   D O O M", 9, 0
  Message "FOUR GUNS. ONE HAND.", 11, 0
  Message "LEFT/RIGHT  TOP + BOTTOM GUNS", 13, 0
  Message "UP/DOWN     THE SIDE GUNS", 14, 0
  Message "EACH PAIR GOES OPPOSITE WAYS", 15, 0
  Message "QAOP  SXZC  5678  JOYSTICK", 17, 0
  Message "SPACE  ALL FOUR FIRE", 18, 0
  Message "SHOOT THE GATES SHUT", 20, 0
  Message "ANY GUN HIT IS A LIFE LOST", 21, 0
  Message "EVEN BY ITS OWN TWIN", 22, 0
  gx = 128 : gy = 104
  y = 0
  Do
    PlaceGuns
    DrawGuns
    Frame
    Spr.Show
    Sfx.Update
    y = y + 1
    gx = 128 + (y And 63) - 32
    If y = 30 Then Message "PRESS SPACE", 25, 0
    If y = 60 Then Tiles.Rect 4, 25, 32, 1, 0 : y = 0
  Loop Until FireDown()
  Do
    Frame
  Loop While FireDown()
  ClearMessages
  Sfx.Play 0, 300, -10, 15, 30, 0
End Sub

' ---------------------------------------------------------------- a game
Sub Game()
  score = 0 : wave = 1 : over = 0 : lives = 3
  For k = 0 To 3
    galive(k) = 1
  Next
  Do
    WaveRun
    If over Then Exit Do
    wave = wave + 1
  Loop
  If score > hiscore Then hiscore = score
  Message "THE GATES OF DOOM HAVE WON", 13, 0
  Message "GAME OVER", 15, 0
  For k = 1 To 250
    Frame
    Sfx.Update
    If k > 50 And FireDown() Then Exit For
  Next
  ClearMessages
End Sub

Sub WaveRun()
  Dim n As Integer, b As Long
  Spr.HideRange 0, 50
  Bul.Reset
  For k = 0 To NE - 1
    ek(k) = 0
  Next
  For k = 0 To NB - 1
    bt(k) = 0
  Next
  n = 1 + wave \ 2
  If n > NG Then n = NG
  For k = 0 To NG - 1
    gon(k) = 0
    If k < n Then
      gon(k) = 1
      gtx(k) = 64 + Rnd(128) : gty(k) = 64 + Rnd(80)
      gmax(k) = 20 + wave * 4 : ghp(k) = gmax(k)
      gspawn(k) = 40 + k * 50
      gfl(k) = 0
    End If
  Next
  gatesOpen = n : demonCount = 0
  gx = 72 : gy = 70 : cool = 0 : hitT = 60
  Hud
  Message "WAVE " & Trim$(Str$(wave)), 12, 120
  If n = 1 Then Message "A GATE OF DOOM IS OPENING", 14, 120 Else Message Trim$(Str$(n)) & " GATES OF DOOM ARE OPENING", 14, 120
  Sfx.Play 2, 400, 6, 15, 60, 0
  clearT = 0
  Do
    GunsMove
    Gates
    Demons
    Booms
    Bul.Step 0, 0, 0
    GunHits
    DrawGuns
    If scoreDirty And (frames And 3) = 0 Then ShowScore
    If msgT > 0 Then
      msgT = msgT - 1
      If msgT = 0 Then ClearMessages
    End If
    Frame
    Spr.Show
    Bul.Show
    Sfx.Update
    frames = frames + 1
    If lives = 0 Then
      clearT = clearT + 1
      If clearT > 100 Then over = 1 : Exit Sub
    ElseIf gatesOpen = 0 And demonCount = 0 Then
      clearT = clearT + 1
      If clearT = 30 Then
        b = wave * 2000
        AddScore b
        Message "WAVE " & Trim$(Str$(wave)) & " CLEARED", 12, 0
        Message "BONUS " & Trim$(Str$(b)), 14, 0
        If (wave Mod 3) = 0 And lives < 4 Then
          lives = lives + 1 : ShowLives
          Message "AN EXTRA LIFE", 16, 0
        End If
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

' ---------------------------------------------------------------- the guns
Sub GunsMove()
  Dim j0 As Integer, mx As Integer, my As Integer
  j0 = Keys.Joystick(0)
  mx = 0 : my = 0
  If Keys.Down(Keys.KeyO) Or Keys.Down(Keys.KeyZ) Or Keys.Down(Keys.KeyLeft) Or (j0 And Keys.JoyLeft) Then mx = -1
  If Keys.Down(Keys.KeyP) Or Keys.Down(Keys.KeyC) Or Keys.Down(Keys.KeyRight) Or (j0 And Keys.JoyRight) Then mx = 1
  If Keys.Down(Keys.KeyQ) Or Keys.Down(Keys.KeyS) Or Keys.Down(Keys.KeyUp) Or (j0 And Keys.JoyUp) Then my = -1
  If Keys.Down(Keys.KeyA) Or Keys.Down(Keys.KeyX) Or Keys.Down(Keys.KeyDown) Or (j0 And Keys.JoyDown) Then my = 1
  If hitT > 0 Then hitT = hitT - 1
  gx = gx + mx * 3 : gy = gy + my * 3
  If gx < GXMIN Then gx = GXMIN
  If gx > GXMAX Then gx = GXMAX
  If gy < GYMIN Then gy = GYMIN
  If gy > GYMAX Then gy = GYMAX
  PlaceGuns
  If cool > 0 Then cool = cool - 1
  If FireDown() And cool = 0 And lives > 0 And hitT < 30 Then
    Bul.Shot gunX(0), 36, 0, 9
    Bul.Shot gunX(1), 172, 0, -9
    Bul.Shot 20, gunY(2), 9, 0
    Bul.Shot 236, gunY(3), -9, 0
    cool = 6
    Sfx.Play 0, 22, 3, 9, 4, 0
  End If
End Sub

Sub PlaceGuns()
  gunX(0) = gx : gunY(0) = 24
  gunX(1) = 256 - gx : gunY(1) = 184              ' the bottom gun goes the other way
  gunX(2) = 8 : gunY(2) = gy
  gunX(3) = 248 : gunY(3) = 208 - gy             ' the right gun goes the other way
End Sub

' the guns turned to face in: top as drawn, bottom flipped, the sides turned
Sub DrawGuns()
  For k = 0 To 3
    If lives > 0 And (hitT And 4) = 0 Then
      If k = 0 Then
        Spr.Put SP_GUN, gunX(0) + 24, gunY(0) + 24, GfxData.S_GUN, 0
      ElseIf k = 1 Then
        Spr.Put SP_GUN + 1, gunX(1) + 24, gunY(1) + 24, GfxData.S_GUN, Spr.MirrorY
      ElseIf k = 2 Then
        Spr.Put SP_GUN + 2, gunX(2) + 24, gunY(2) + 24, GfxData.S_GUN, Spr.Rotate Or Spr.MirrorX
      Else
        Spr.Put SP_GUN + 3, gunX(3) + 24, gunY(3) + 24, GfxData.S_GUN, Spr.Rotate
      End If
    Else
      Spr.Hide SP_GUN + k
    End If
  Next
  ' the four places the lines cross
  Spr.Put SP_CROSS, gunX(0) + 24, gunY(2) + 24, GfxData.S_CROSS, 0
  Spr.Put SP_CROSS2, gunX(0) + 24, gunY(3) + 24, GfxData.S_CROSS, 0
  Spr.Put SP_CROSS2 + 1, gunX(1) + 24, gunY(2) + 24, GfxData.S_CROSS, 0
  Spr.Put SP_CROSS2 + 2, gunX(1) + 24, gunY(3) + 24, GfxData.S_CROSS, 0
End Sub

' a gun hit by a fireball, or by the gun opposite's laser (they line up in the middle)
Sub GunHits()
  Dim h As Integer
  For k = 0 To 3
    h = Bul.Hits(BOXGUN + k)
    If Bul.Near(gunX(k), gunY(k)) Then h = h + 1
    If h Then LoseLife k
    Bul.Box BOXGUN + k, gunX(k), gunY(k), 7, 7
  Next
End Sub

' any gun hit: a life gone; the demons and fireballs cleared
Sub LoseLife(ByVal g As Integer)
  Dim m As Integer
  If hitT > 0 Or lives = 0 Then Exit Sub
  lives = lives - 1 : ShowLives
  hitT = 90
  Boom gunX(g), gunY(g), 1
  m = Bul.Clear()
  For m = 0 To NE - 1
    If ek(m) Then
      Boom ex(m) \ 16, ey(m) \ 16, 0
      ek(m) = 0 : Bul.Off m : Spr.Hide SP_EN + m
    End If
  Next
  demonCount = 0
  Sfx.Play 2, 31, 0, 15, 60, 1
  Sfx.Play 1, 300, 10, 15, 40, 0
  If lives > 0 Then Message "A GUN IS HIT!", 17, 80
End Sub

' ---------------------------------------------------------------- the gates
Sub Gates()
  Dim n As Integer, h As Integer, fl As Integer, m As Integer, kd As Integer, r As Integer
  For n = 0 To NG - 1
    If gon(n) Then
      h = Bul.Hits(16 + n)
      If h > 0 Then
        ghp(n) = ghp(n) - h : gfl(n) = 1
        AddScore 10 * h
        Sfx.Play 1, 50, -3, 11, 4, 0
        If ghp(n) <= 0 Then
          gon(n) = 0 : gatesOpen = gatesOpen - 1 : ShowGates
          Bul.Off 16 + n
          Spr.Hide SP_GATE + n
          Boom gtx(n), gty(n), 1
          Boom gtx(n) - 12, gty(n) - 10, 0
          Boom gtx(n) + 12, gty(n) + 8, 0
          AddScore 1000 * wave
          Sfx.Play 2, 31, 0, 15, 50, 1
          Sfx.Play 0, 500, -12, 15, 40, 0
        End If
      End If
      If gon(n) Then
        Bul.Box 16 + n, gtx(n), gty(n), 15, 15
        ' hit: it glows red-hot for a frame (and stays red-hot when nearly shut)
        If gfl(n) Or ghp(n) * 3 < gmax(n) Then fl = Spr.Pal * 2 Else fl = 0
        gfl(n) = 0
        Spr.Put SP_GATE + n, gtx(n) + 16, gty(n) + 16, GfxData.S_GATE + ((frames \ 4) And 3), fl Or Spr.Scale2
        ' it sends out a demon now and then
        gspawn(n) = gspawn(n) - 1
        If gspawn(n) <= 0 Then
          r = 120 - wave * 10
          If r < 40 Then r = 40
          gspawn(n) = r + Rnd(50)
          r = Rnd(10)
          kd = K_IMP
          If wave >= 2 And r >= 6 Then kd = K_WRAITH
          If wave >= 3 And r = 8 Then kd = K_SKULL
          If wave >= 4 And r = 9 Then kd = K_FIEND
          m = Spawn(kd, gtx(n), gty(n))
          If wave >= 5 Then m = Spawn(K_IMP, gtx(n), gty(n))
          If m >= 0 Then Sfx.Play 2, 200, -8, 12, 16, 0
        End If
      End If
    End If
  Next
End Sub

' ---------------------------------------------------------------- the demonCount
Function Spawn(ByVal kd As Integer, ByVal x As Integer, ByVal y As Integer) As Integer
  Dim m As Integer, g As Integer, t As Integer
  For m = 0 To NE - 1
    If ek(m) = 0 Then
      ek(m) = kd : ex(m) = x * 16 : ey(m) = y * 16 : et(m) = 0 : efl(m) = 0
      ' it wants a gun that's still there
      g = Rnd(4)
      For t = 1 To 4
        If galive(g) = 0 Then g = (g + 1) And 3
      Next
      etg(m) = g
      evx(m) = Rnd(33) - 16 : evy(m) = Rnd(33) - 16
      If kd = K_IMP Then ehp(m) = 1
      If kd = K_WRAITH Then ehp(m) = 2
      If kd = K_SKULL Then
        ehp(m) = 3 : evx(m) = 20 + wave * 2 : evy(m) = 16 + wave * 2
        If Rnd(2) Then evx(m) = -evx(m)
      End If
      If kd = K_FIEND Then ehp(m) = 8
      demonCount = demonCount + 1
      Spawn = m
      Exit Function
    End If
  Next
  Spawn = -1
End Function

Sub Demons()
  Dim m As Integer, kd As Integer, x As Integer, y As Integer, h As Integer, fl As Integer, pat As Integer
  Dim tx As Integer, ty As Integer, sp As Integer, g As Integer, a As Integer
  For m = 0 To NE - 1
    kd = ek(m)
    If kd Then
      x = ex(m) \ 16 : y = ey(m) \ 16
      g = etg(m)
      If galive(g) = 0 Then
        g = (g + 1) And 3
        etg(m) = g
      End If
      tx = gunX(g) : ty = gunY(g)
      sp = 20 + wave * 3
      If kd = K_IMP Then
        ' homes in, wobbling
        If tx > x Then evx(m) = evx(m) + 2 Else evx(m) = evx(m) - 2
        If ty > y Then evy(m) = evy(m) + 2 Else evy(m) = evy(m) - 2
        evx(m) = Clamp(evx(m), sp) : evy(m) = Clamp(evy(m), sp)
      ElseIf kd = K_WRAITH Then
        ' straight at it, faster, swaying
        If tx > x Then evx(m) = evx(m) + 4 Else evx(m) = evx(m) - 4
        If ty > y Then evy(m) = evy(m) + 4 Else evy(m) = evy(m) - 4
        evx(m) = Clamp(evx(m), sp + 10) : evy(m) = Clamp(evy(m), sp + 10)
      ElseIf kd = K_SKULL Then
        ' bounces round the whole arena, spitting now and then
        If (x < 12 And evx(m) < 0) Or (x > 244 And evx(m) > 0) Then evx(m) = -evx(m)
        If (y < 28 And evy(m) < 0) Or (y > 180 And evy(m) > 0) Then evy(m) = -evy(m)
        If (et(m) Mod 120) = 119 Then Spit x, y, g
      Else
        ' drifts slowly, spitting fire
        If tx > x Then evx(m) = evx(m) + 1 Else evx(m) = evx(m) - 1
        If ty > y Then evy(m) = evy(m) + 1 Else evy(m) = evy(m) - 1
        evx(m) = Clamp(evx(m), 8) : evy(m) = Clamp(evy(m), 8)
        If (et(m) Mod 70) = 69 Then Spit x, y, g
      End If
      ex(m) = ex(m) + evx(m) : ey(m) = ey(m) + evy(m)
      et(m) = et(m) + 1
      x = ex(m) \ 16 : y = ey(m) \ 16
      If x < 4 Then x = 4 : ex(m) = 64
      If x > 251 Then x = 251 : ex(m) = 251 * 16
      If y < 20 Then y = 20 : ey(m) = 320
      If y > 187 Then y = 187 : ey(m) = 187 * 16
      ' shot
      h = Bul.Hits(m)
      If h > 0 Then
        ehp(m) = ehp(m) - h : efl(m) = 1
        If ehp(m) <= 0 Then
          KillDemon m, kd, x, y
          kd = 0
        End If
      End If
      If kd Then
        ' at a gun: the gun and the demon both go
        For a = 0 To 3
          If galive(a) Then
            If Abs(x - gunX(a)) < 11 And Abs(y - gunY(a)) < 11 Then
              LoseLife a
              If ek(m) Then ek(m) = 0 : demonCount = demonCount - 1 : Bul.Off m : Spr.Hide SP_EN + m
              Boom x, y, 0
              kd = 0
              Exit For
            End If
          End If
        Next
      End If
      If kd Then
        If kd = K_FIEND Then Bul.Box m, x, y, 14, 14 Else Bul.Box m, x, y, 8, 8
        If efl(m) Then fl = Spr.Pal : efl(m) = 0 Else fl = 0
        If kd = K_IMP Then
          Spr.Put SP_EN + m, x + 24, y + 24, GfxData.S_IMP + ((frames \ 4) And 1), fl
        ElseIf kd = K_WRAITH Then
          Spr.Put SP_EN + m, x + 24, y + 24, GfxData.S_WRAITH + ((frames \ 6) And 1), fl
        ElseIf kd = K_SKULL Then
          Spr.Put SP_EN + m, x + 24, y + 24, GfxData.S_SKULL, fl
        Else
          Spr.Put SP_EN + m, x + 16, y + 16, GfxData.S_FIEND + ((et(m) \ 10) And 1), fl Or Spr.Scale2
        End If
      End If
    End If
  Next
End Sub

Function Clamp(ByVal v As Integer, ByVal lim As Integer) As Integer
  If v > lim Then
    Clamp = lim
  ElseIf v < -lim Then
    Clamp = -lim
  Else
    Clamp = v
  End If
End Function

' a fireball from x, y at gun g
Sub Spit(ByVal x As Integer, ByVal y As Integer, ByVal g As Integer)
  Dim sp As Integer
  If galive(g) = 0 Then Exit Sub
  sp = 16 + wave * 2
  If sp > 36 Then sp = 36
  Bul.Fire x, y, Bul.Aim(x, y, gunX(g), gunY(g)), sp, GfxData.S_FIRE, 0
  Sfx.Play 2, 80, 4, 11, 10, 1
End Sub

Sub KillDemon(ByVal m As Integer, ByVal kd As Integer, ByVal x As Integer, ByVal y As Integer)
  ek(m) = 0 : demonCount = demonCount - 1
  Bul.Off m
  Spr.Hide SP_EN + m
  If kd = K_FIEND Then
    Boom x, y, 1
    AddScore 500
  Else
    Boom x, y, 0
    If kd = K_IMP Then AddScore 100
    If kd = K_WRAITH Then AddScore 150
    If kd = K_SKULL Then AddScore 200
  End If
  Sfx.Play 1, 20, 1, 13, 12, 1
End Sub

' ---------------------------------------------------------------- explosions
Sub Boom(ByVal x As Integer, ByVal y As Integer, ByVal big As Integer)
  bx(bnext) = x : by(bnext) = y : bt(bnext) = 16 : bbig(bnext) = big
  bnext = (bnext + 1) And 7
End Sub

Sub Booms()
  Dim n As Integer
  For n = 0 To NB - 1
    If bt(n) > 0 Then
      bt(n) = bt(n) - 1
      If bt(n) = 0 Then
        Spr.Hide SP_BOOM + n
      ElseIf bbig(n) Then
        Spr.Put SP_BOOM + n, bx(n) + 16, by(n) + 16, GfxData.S_BOOM + (15 - bt(n)) \ 4, Spr.Scale2
      Else
        Spr.Put SP_BOOM + n, bx(n) + 24, by(n) + 24, GfxData.S_BOOM + (15 - bt(n)) \ 4, 0
      End If
    End If
  Next
End Sub
