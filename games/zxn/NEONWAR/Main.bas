' NEONWAR - a twin stick neon arena shooter for the ZX Spectrum Next, in NTC BASIC (VB5 flavour)
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Vector graphics as the CITY3D demo draws them, on the Next's Layer 2 (L2.cls: 256 x 192, 256
' colours, two buffers, clipped lines). The floor grid, the frame and the text are the tilemap
' (Tiles.cls) under Layer 2, which is see-through where nothing is drawn. Spawn markers are
' hardware sprites, the sound the AY.
'
' Keys: S up, X down, Z left, C right, the cursor keys (5 6 7 8) fire that way (two at once: diagonals),
'       Space a smart bomb. A Kempston joystick moves; its fire button shoots the way you go.
' Enemies: pinwheels wander, diamonds hunt you, squares hunt and split in two when shot.
' Every 25 kills the multiplier goes up (to x10); losing a life sets it back to x1.
Option Explicit
Option Turbo

Const NE = 40, NB = 20, NP = 48, NS = 8
Const SP_SHIP = 8                       ' the ship's sprite (0-7: the spawn markers)
Const AW = 256, AH = 192                ' the arena: Layer 2's screen
' enemy kinds
Const K_WANDER = 1, K_DIAMOND = 2, K_SQUARE = 3, K_MINI = 4
' colours (Layer 2: RRRGGGBB)
Const C_SHIP = &HFF, C_SHOT = &HFC, C_WANDER = &HA7, C_DIAMOND = &H1F, C_SQUARE = &H1C, C_MINI = &H9D
Const C_BG = &HE3                        ' transparent: the tilemap's grid shows through

' shapes: one table of points (L2.Shape's form), so* the offsets
Dim shp(1499) As Byte
Dim shpn As Integer
Dim longText As String Max 120          ' (the longest string: the shape texts passed to MakeShape fit)
Dim soShip(7) As Integer, soWander(7) As Integer, soDiamond(1) As Integer, soSquare(3) As Integer, soMini(3) As Integer
Dim sn(15) As Integer
Dim dx8(7) As Integer, dy8(7) As Integer, wayt(8) As Integer
' enemies
Dim ek(39) As Integer, ex(39) As Integer, ey(39) As Integer, evx(39) As Integer, evy(39) As Integer
Dim ea(39) As Integer, et(39) As Integer, epx(39) As Integer, epy(39) As Integer, er(39) As Integer
Dim nen As Integer
' shots
Dim bon(19) As Integer, bx(19) As Integer, by(19) As Integer, bvx(19) As Integer, bvy(19) As Integer
' particles
Dim pl(47) As Integer, px(47) As Integer, py(47) As Integer, pvx(47) As Integer, pvy(47) As Integer, pc(47) As Integer
Dim pnext As Integer
' spawns on the way
Dim sk(7) As Integer, sxx(7) As Integer, syy(7) As Integer, st(7) As Integer
' the ship
Dim sx As Integer, sy As Integer, sdir As Integer, alive As Integer, inv As Integer, cool As Integer, dead As Integer
Dim score As Long, hiscore As Long, nextlife As Long
Dim lives As Integer, bombs As Integer, kills As Integer, mult As Integer, level As Integer, over As Integer
Dim frames As Integer, ltimer As Integer, wtimer As Integer, seed As Integer, firewas As Integer, bombwas As Integer
Dim hudDirty As Integer, sps As Integer
Dim i As Integer, j As Integer

Setup
Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
L2.Init C_BG
Nx.Layers Nx.OrderSLU
hiscore = 50000
Do
  Title
  Play
  GameOver
Loop

' ---------------------------------------------------------------- tables, shapes
Sub Setup()
  Dim k As Integer
  ' sin x 64, 16 steps round
  sn(0) = 0 : sn(1) = 24 : sn(2) = 45 : sn(3) = 59 : sn(4) = 64 : sn(5) = 59 : sn(6) = 45 : sn(7) = 24
  For k = 8 To 15
    sn(k) = -sn(k - 8)
  Next
  ' 8 ways: 0 right, then clockwise (y goes down the screen)
  For k = 0 To 7
    dx8(k) = Cs(k * 2) : dy8(k) = sn(k * 2)
  Next
  wayt(0) = 5 : wayt(1) = 6 : wayt(2) = 7 : wayt(3) = 4 : wayt(4) = -1 : wayt(5) = 0 : wayt(6) = 3 : wayt(7) = 2 : wayt(8) = 1
  shpn = 0
  For k = 0 To 7
    soShip(k) = MakeShape("8 0 -6 -6 -2 0 -6 6 8 0 P -2 0 -4 0", k * 2, 64)
    soWander(k) = MakeShape("0 0 7 -3 7 3 0 0 -7 3 -7 -3 0 0 P 0 -6 0 6", k * 2, 64)
  Next
  soDiamond(0) = MakeShape("0 -7 5 0 0 7 -5 0 0 -7", 0, 64)
  soDiamond(1) = MakeShape("0 -6 4 0 0 6 -4 0 0 -6 P 0 -3 2 0 0 3 -2 0 0 -3", 0, 64)
  For k = 0 To 3
    soSquare(k) = MakeShape("-6 -6 6 -6 6 6 -6 6 -6 -6 P -6 -6 6 6 P 6 -6 -6 6", k, 64)
    soMini(k) = MakeShape("-3 -3 3 -3 3 3 -3 3 -3 -3", k, 64)
  Next
End Sub

Function Cs(ByVal a As Integer) As Integer
  Cs = sn((a + 4) And 15)
End Function

' a shape from "x y x y ... P x y ...", turned by ang (16ths of a turn) and scaled (64 = 1):
' its offset in shp
Function MakeShape(ByVal s As String, ByVal ang As Integer, ByVal sc As Integer) As Integer
  Dim p As Integer, q As Integer, tok As String, n As Integer, start As Integer
  Dim x As Integer, y As Integer, rx As Integer, ry As Integer, havex As Integer, c As Integer, sg As Integer
  start = shpn
  shpn = shpn + 1
  n = 0 : havex = 0
  c = Cs(ang) : sg = sn(ang And 15)
  s = s & " "
  p = 1
  Do While p <= Len(s)
    q = InStr(p, s, " ")
    If q = 0 Then Exit Do
    tok = Mid$(s, p, q - p)
    p = q + 1
    If tok = "P" Then
      shp(shpn) = 128 : shp(shpn + 1) = 0 : shpn = shpn + 2 : n = n + 1
    ElseIf tok <> "" Then
      If havex = 0 Then
        x = Val(tok) : havex = 1
      Else
        y = Val(tok) : havex = 0
        rx = ((x * c - y * sg) \ 8) * sc \ 512
        ry = (x * sg + y * c) \ 8 * sc \ 512
        shp(shpn) = rx And 255 : shp(shpn + 1) = ry And 255
        shpn = shpn + 2 : n = n + 1
      End If
    End If
  Loop
  shp(start) = n
  MakeShape = start
End Function

' ---------------------------------------------------------------- input
Function FirePressed() As Integer
  Dim f As Integer
  f = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyEnter) Or ((Keys.Joystick(0) And Keys.JoyFire1) <> 0)
  FirePressed = f And Not firewas
  firewas = f
End Function

' a way from -1 / 0 / 1 across and down: 0-7, or -1 for none
Function Way(ByVal x As Integer, ByVal y As Integer) As Integer
  Way = wayt((y + 1) * 3 + x + 1)
End Function

' ---------------------------------------------------------------- the screen round the arena
Sub Arena()
  Dim x As Integer, y As Integer, t As Integer
  Tiles.Fill 0
  For y = 4 To 27
    For x = 4 To 35
      If (y And 1) = 0 Then
        If (x And 1) = 0 Then t = GfxData.T_GRIDC Else t = GfxData.T_GRIDT
      Else
        If (x And 1) = 0 Then t = GfxData.T_GRIDL Else t = GfxData.T_GRIDN
      End If
      Tiles.Put x, y, t
    Next
  Next
  Tiles.Rect 4, 3, 32, 1, GfxData.T_FRAMET
  Tiles.Rect 4, 28, 32, 1, GfxData.T_FRAMEB
  Tiles.Rect 3, 4, 1, 24, GfxData.T_FRAMEL
  Tiles.Rect 36, 4, 1, 24, GfxData.T_FRAMER
  Tiles.Put 3, 3, GfxData.T_CORNER : Tiles.Put 36, 3, GfxData.T_CORNER + 1
  Tiles.Put 3, 28, GfxData.T_CORNER + 2 : Tiles.Put 36, 28, GfxData.T_CORNER + 3
End Sub

Sub Hud()
  Dim k As Integer
  Tiles.Text 4, 1, "SCORE " & Format$(score, "0000000")
  Tiles.Text 19, 1, "X" & CStr(mult) & " "
  Tiles.Rect 24, 1, 12, 1, 0
  For k = 1 To lives
    If k <= 6 Then Tiles.Put 23 + k, 1, GfxData.T_LIFE
  Next
  For k = 1 To bombs
    If k <= 5 Then Tiles.Put 36 - k, 1, GfxData.T_BOMB
  Next
  Tiles.Text 4, 30, "HI " & Format$(hiscore, "0000000")
  Tiles.Text 26, 30, "LEVEL " & Format$(level, "00")
  hudDirty = 0
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
    Case "N": p = "75555"
    Case "E": p = "74647"
    Case "O": p = "75557"
    Case "W": p = "55575"
    Case "A": p = "25755"
    Case "R": p = "75654"
    Case Else: p = "00000"
  End Select
  Glyph = Val(Mid$(p, r + 1, 1))
End Function

' ---------------------------------------------------------------- the title
Sub Title()
  Dim k As Integer, a As Integer
  Spr.HideRange 0, 16
  Spr.Show
  L2.Wipe
  Frame : L2.Flip
  L2.Wipe
  Tiles.Fill 0
  BigText 8, 3, "NEON", 0
  BigText 25, 3, "WAR", 1
  Tiles.Text 8, 10, "S X Z C      MOVE U D L R"
  Tiles.Text 8, 12, "CURSOR KEYS  FIRE THAT WAY"
  Tiles.Text 8, 14, "SPACE        SMART BOMB"
  Tiles.Text 8, 16, "JOYSTICK     MOVE, FIRE"
  Tiles.Text 12, 20, "PINWHEEL     25"
  Tiles.Text 12, 22, "DIAMOND      50"
  Tiles.Text 12, 24, "SQUARE      100"
  Tiles.Text 4, 1, "SCORE " & Format$(score, "0000000")
  Tiles.Text 4, 30, "HI " & Format$(hiscore, "0000000")
  Tiles.Text 26, 30, "NTC BASIC"
  firewas = -1 : frames = 0
  Do
    L2.Clear
    a = frames And 7
    L2.Shape 42, 132, VarPtr(shp) + soWander(a), C_WANDER
    L2.Shape 42, 148, VarPtr(shp) + soDiamond((frames \ 8) And 1), C_DIAMOND
    L2.Shape 42, 164, VarPtr(shp) + soSquare((frames \ 4) And 3), C_SQUARE
    L2.Shape 220, 148, VarPtr(shp) + soShip((frames \ 8) And 7), C_SHIP
    Frame
    L2.Flip
    Sfx.Update
    frames = frames + 1 : seed = seed + 1
    If (frames And 31) = 0 Then Tiles.Text 10, 27, "PRESS SPACE TO START"
    If (frames And 31) = 20 Then Tiles.Text 10, 27, "                    "
  Loop Until FirePressed()
  Nx.Seed seed
  bombwas = -1
End Sub

' ---------------------------------------------------------------- a game
Sub Play()
  Dim k As Integer
  score = 0 : lives = 3 : bombs = 3 : kills = 0 : mult = 1 : level = 1 : over = 0 : nextlife = 75000
  For k = 0 To NE - 1
    ek(k) = 0
  Next
  For k = 0 To NB - 1
    bon(k) = 0
  Next
  For k = 0 To NP - 1
    pl(k) = 0
  Next
  For k = 0 To NS - 1
    st(k) = 0
  Next
  nen = 0
  Arena
  L2.Wipe
  Frame : L2.Flip
  L2.Wipe
  Hud
  sx = 128 * 16 : sy = 96 * 16 : sdir = 6 : alive = 1 : inv = 100 : dead = 0
  ltimer = 0 : wtimer = 60 : frames = 0
  Do
    L2.Clear
    If alive Then
      MoveShip
    Else
      dead = dead - 1
      If dead = 0 Then Respawn
    End If
    MoveShots
    MoveEnemies
    Spawns
    Particles
    If alive Then DrawShip Else Spr.Hide SP_SHIP
    If hudDirty Then Hud
    Frame
    L2.Flip
    Spr.Show
    Sfx.Update
    frames = frames + 1
    ltimer = ltimer + 1
    If ltimer >= 900 Then
      ltimer = 0 : level = level + 1 : hudDirty = 1
    End If
  Loop Until over
End Sub

Sub MoveShip()
  Dim mx As Integer, my As Integer, fx As Integer, fy As Integer, w As Integer, j As Integer, b As Integer
  j = Keys.Joystick(0)
  If Keys.Down(Keys.KeyC) Or (j And Keys.JoyRight) Then mx = 1
  If Keys.Down(Keys.KeyZ) Or (j And Keys.JoyLeft) Then mx = -1
  If Keys.Down(Keys.KeyX) Or (j And Keys.JoyDown) Then my = 1
  If Keys.Down(Keys.KeyS) Or (j And Keys.JoyUp) Then my = -1
  w = Way(mx, my)
  If w >= 0 Then
    sx = sx + dx8(w) \ 2
    sy = sy + dy8(w) \ 2
    If sx < 6 * 16 Then sx = 6 * 16
    If sx > (AW - 7) * 16 Then sx = (AW - 7) * 16
    If sy < 6 * 16 Then sy = 6 * 16
    If sy > (AH - 7) * 16 Then sy = (AH - 7) * 16
    sdir = w
  End If
  ' fire: the cursor keys, or the joystick's button the way it moves
  If Keys.Down(Keys.KeyRight) Then fx = 1
  If Keys.Down(Keys.KeyLeft) Then fx = -1
  If Keys.Down(Keys.KeyDown) Then fy = 1
  If Keys.Down(Keys.KeyUp) Then fy = -1
  w = Way(fx, fy)
  If w < 0 And (j And Keys.JoyFire1) Then w = sdir
  If cool > 0 Then cool = cool - 1
  If w >= 0 And cool = 0 Then
    Shoot w
    If level > 3 Then
      Shoot (w + 1) And 7
      Shoot (w + 7) And 7
    End If
    cool = 5
    Sfx.Play 0, 40, 4, 9, 4, 0
  End If
  ' a smart bomb
  b = Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyM)
  If b And Not bombwas And bombs > 0 Then
    bombs = bombs - 1 : hudDirty = 1
    SmartBomb 1
  End If
  bombwas = b
  If inv > 0 Then inv = inv - 1
End Sub

Sub Shoot(ByVal w As Integer)
  Dim k As Integer
  For k = 0 To NB - 1
    If bon(k) = 0 Then
      bon(k) = 1
      bx(k) = sx : by(k) = sy
      bvx(k) = dx8(w) * 5 / 4 : bvy(k) = dy8(w) * 5 / 4
      Exit Sub
    End If
  Next
End Sub

Sub DrawShip()
  Dim c As Integer
  ' a hardware sprite (sprite 8), not Layer 2 lines: the hardware draws it every frame, whatever
  ' the drawing is doing; while it can't be hurt it flashes (palette 1: cyan)
  c = 0
  If inv > 0 And (frames And 4) Then c = Spr.Pal
  Spr.Put SP_SHIP, sx \ 16 + 32 - 8, sy \ 16 + 32 - 8, GfxData.S_SHIP + sdir, c
End Sub

Sub MoveShots()
  Dim k As Integer, x As Integer, y As Integer, h As Integer
  For k = 0 To NB - 1
    If bon(k) Then
      bx(k) = bx(k) + bvx(k) : by(k) = by(k) + bvy(k)
      x = bx(k) \ 16 : y = by(k) \ 16
      If x < 1 Or x > AW - 2 Or y < 1 Or y > AH - 2 Then
        bon(k) = 0
      Else
        h = HitTest(x, y)
        If h >= 0 Then
          bon(k) = 0
          ShotEnemy h
        Else
          L2.Line x, y, (bx(k) - bvx(k)) \ 16, (by(k) - bvy(k)) \ 16, C_SHOT
        End If
      End If
    End If
  Next
End Sub

' the first enemy within its size of x, y, or -1 (Z80: it runs for every shot every frame)
Function HitTest(ByVal x As Integer, ByVal y As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (ht_x), de
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (ht_y), de
            ld de, 0                ; DE = the offset of enemy n (n * 2)
            ld b, {NE}
ht_lp:
            ld hl, {ek}
            add hl, de
            ld a, (hl)
            or a
            jr z, ht_nx
            ld hl, {er}
            add hl, de
            ld c, (hl)              ; its size
            ld hl, {epx}
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld a, (ht_x)
            sub l
            ld l, a
            ld a, (ht_x + 1)
            sbc a, h
            ld h, a                 ; HL = x - epx
            bit 7, h
            jr z, ht_p1
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
ht_p1:
            ld a, h
            or a
            jr nz, ht_nx
            ld a, c
            cp l
            jr c, ht_nx
            ld hl, {epy}
            add hl, de
            ld a, (hl)
            inc hl
            ld h, (hl)
            ld l, a
            ld a, (ht_y)
            sub l
            ld l, a
            ld a, (ht_y + 1)
            sbc a, h
            ld h, a
            bit 7, h
            jr z, ht_p2
            xor a
            sub l
            ld l, a
            sbc a, a
            sub h
            ld h, a
ht_p2:
            ld a, h
            or a
            jr nz, ht_nx
            ld a, c
            cp l
            jr c, ht_nx
            srl d                   ; a hit: n = offset / 2
            rr e
            jr ht_set
ht_nx:
            inc de
            inc de
            djnz ht_lp
            ld de, -1
ht_set:
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
            ret
ht_x:       dw 0
ht_y:       dw 0
#endasm
End Function

' ---------------------------------------------------------------- enemies
Sub AddEnemy(ByVal k As Integer, ByVal x As Integer, ByVal y As Integer)
  Dim n As Integer
  For n = 0 To NE - 1
    If ek(n) = 0 Then
      ek(n) = k : ex(n) = x * 16 : ey(n) = y * 16 : evx(n) = 0 : evy(n) = 0 : ea(n) = Rnd(8) : et(n) = 0
      epx(n) = x : epy(n) = y
      Select Case k
        Case K_WANDER
          er(n) = 7
          evx(n) = Rnd(33) - 16 : evy(n) = Rnd(33) - 16
        Case K_DIAMOND: er(n) = 6
        Case K_SQUARE: er(n) = 7
        Case Else: er(n) = 4
      End Select
      nen = nen + 1
      Exit Sub
    End If
  Next
End Sub

Sub MoveEnemies()
  Dim n As Integer, k As Integer, x As Integer, y As Integer, d As Integer, sp As Integer
  For n = 0 To NE - 1
    k = ek(n)
    If k Then
      Select Case k
        Case K_WANDER
          et(n) = et(n) + 1
          If et(n) >= 50 Then
            et(n) = 0 : evx(n) = Rnd(33) - 16 : evy(n) = Rnd(33) - 16
          End If
          If (frames And 1) Then ea(n) = (ea(n) + 1) And 7
        Case K_DIAMOND
          sp = 18 + level * 2
          If sp > 34 Then sp = 34
          If sx > ex(n) Then evx(n) = evx(n) + 2 Else evx(n) = evx(n) - 2
          If sy > ey(n) Then evy(n) = evy(n) + 2 Else evy(n) = evy(n) - 2
          If evx(n) > sp Then evx(n) = sp
          If evx(n) < -sp Then evx(n) = -sp
          If evy(n) > sp Then evy(n) = sp
          If evy(n) < -sp Then evy(n) = -sp
          ea(n) = (frames \ 8) And 1
        Case Else
          sp = 14
          If k = K_MINI Then sp = 24
          d = sx - ex(n)
          If d > 16 Then
            evx(n) = sp
          ElseIf d < -16 Then
            evx(n) = -sp
          Else
            evx(n) = 0
          End If
          d = sy - ey(n)
          If d > 16 Then
            evy(n) = sp
          ElseIf d < -16 Then
            evy(n) = -sp
          Else
            evy(n) = 0
          End If
          If (frames And 3) = 0 Then ea(n) = (ea(n) + 1) And 3
      End Select
      ex(n) = ex(n) + evx(n) : ey(n) = ey(n) + evy(n)
      If ex(n) < 6 * 16 Then
        ex(n) = 6 * 16 : evx(n) = -evx(n)
      End If
      If ex(n) > (AW - 7) * 16 Then
        ex(n) = (AW - 7) * 16 : evx(n) = -evx(n)
      End If
      If ey(n) < 6 * 16 Then
        ey(n) = 6 * 16 : evy(n) = -evy(n)
      End If
      If ey(n) > (AH - 7) * 16 Then
        ey(n) = (AH - 7) * 16 : evy(n) = -evy(n)
      End If
      x = ex(n) \ 16 : y = ey(n) \ 16
      epx(n) = x : epy(n) = y
      Select Case k
        Case K_WANDER: L2.Shape x, y, VarPtr(shp) + soWander(ea(n)), C_WANDER
        Case K_DIAMOND: L2.Shape x, y, VarPtr(shp) + soDiamond(ea(n)), C_DIAMOND
        Case K_SQUARE: L2.Shape x, y, VarPtr(shp) + soSquare(ea(n)), C_SQUARE
        Case Else: L2.Shape x, y, VarPtr(shp) + soMini(ea(n)), C_MINI
      End Select
      ' touching the ship
      If alive And inv = 0 Then
        If Abs(x - sx \ 16) < er(n) + 3 And Abs(y - sy \ 16) < er(n) + 3 Then ShipHit
      End If
    End If
  Next
End Sub

Sub ShotEnemy(ByVal n As Integer)
  Dim k As Integer, x As Integer, y As Integer, pts As Integer, c As Integer
  k = ek(n) : x = epx(n) : y = epy(n)
  ek(n) = 0 : nen = nen - 1
  Select Case k
    Case K_WANDER: pts = 25 : c = C_WANDER
    Case K_DIAMOND: pts = 50 : c = C_DIAMOND
    Case K_SQUARE: pts = 100 : c = C_SQUARE
    Case Else: pts = 50 : c = C_MINI
  End Select
  Burst x, y, c, 10
  Sfx.Play 1, 10, 1, 13, 12, 1
  If k = K_SQUARE Then
    AddEnemy K_MINI, x - 6, y - 4
    AddEnemy K_MINI, x + 6, y + 4
  End If
  kills = kills + 1
  If kills Mod 25 = 0 And mult < 10 Then
    mult = mult + 1
    Sfx.Play 2, 120, -6, 13, 20, 0
  End If
  AddScore CLng(pts) * mult
End Sub

Sub AddScore(ByVal n As Long)
  score = score + n
  If score >= nextlife Then
    nextlife = nextlife + 75000
    If lives < 6 Then lives = lives + 1
    If bombs < 5 Then bombs = bombs + 1
  End If
  If score > hiscore Then hiscore = score
  hudDirty = 1
End Sub

' every enemy blown up (points only for a smart bomb: give 1)
Sub SmartBomb(ByVal pts As Integer)
  Dim n As Integer
  For n = 0 To NE - 1
    If ek(n) Then
      If pts Then AddScore 10
      Burst epx(n), epy(n), &HFF, 3
      ek(n) = 0
    End If
  Next
  nen = 0
  For n = 0 To NS - 1
    st(n) = 0
    Spr.Hide n
  Next
  Sfx.Play 1, 31, 0, 15, 50, 1
  Sfx.Play 2, 60, 6, 14, 40, 0
End Sub

Sub ShipHit()
  alive = 0 : dead = 100
  Burst sx \ 16, sy \ 16, C_SHIP, 24
  Burst sx \ 16, sy \ 16, C_SHOT, 16
  SmartBomb 0
  Sfx.Play 0, 200, 10, 15, 80, 0
  mult = 1 : kills = 0
End Sub

Sub Respawn()
  lives = lives - 1
  hudDirty = 1
  If lives = 0 Then
    over = 1
  Else
    alive = 1 : inv = 100 : sx = 128 * 16 : sy = 96 * 16
  End If
End Sub

' ---------------------------------------------------------------- spawning
Sub Spawns()
  Dim n As Integer, c As Integer, k As Integer, x As Integer, y As Integer, a As Integer, w As Integer
  ' the markers count down, then the enemy appears
  For n = 0 To NS - 1
    If st(n) > 0 Then
      st(n) = st(n) - 1
      If st(n) = 0 Then
        Spr.Hide n
        AddEnemy sk(n), sxx(n), syy(n)
      Else
        Spr.Put n, sxx(n) + 32 - 8, syy(n) + 32 - 8, GfxData.S_SPAWN + ((st(n) \ 4) And 1), 0
      End If
    End If
  Next
  If alive = 0 Then Exit Sub
  wtimer = wtimer - 1
  If wtimer > 0 Then Exit Sub
  w = 150 - level * 10
  If w < 50 Then w = 50
  wtimer = w
  If nen > 24 Then Exit Sub
  c = Rnd(5)
  If level < 2 And c > 2 Then c = Rnd(2)
  Select Case c
    Case 0          ' pinwheels anywhere
      For n = 1 To 3 + level \ 2
        Spot x, y
        Queue K_WANDER, x, y
      Next
    Case 1          ' diamonds in the corners
      Queue K_DIAMOND, 16, 16
      Queue K_DIAMOND, AW - 17, 16
      Queue K_DIAMOND, 16, AH - 17
      Queue K_DIAMOND, AW - 17, AH - 17
    Case 2          ' squares at one side
      a = Rnd(2) * (AW - 40) + 20
      For n = 0 To 2
        Queue K_SQUARE, a, 40 + n * 56
      Next
    Case 3          ' a ring of diamonds round the ship
      For n = 0 To 7
        x = sx \ 16 + dx8(n) * 3 / 2 : y = sy \ 16 + dy8(n) * 3 / 2
        If x < 10 Then x = 10
        If x > AW - 11 Then x = AW - 11
        If y < 10 Then y = 10
        If y > AH - 11 Then y = AH - 11
        Queue K_DIAMOND, x, y
      Next
    Case Else       ' a mixed bunch
      For n = 1 To 4
        Spot x, y
        Queue Choose(Rnd(3) + 1, K_WANDER, K_DIAMOND, K_SQUARE), x, y
      Next
  End Select
  Sfx.Play 2, 300, -10, 10, 25, 0
End Sub

' somewhere not too near the ship
Sub Spot(x As Integer, y As Integer)
  Dim t As Integer
  For t = 1 To 10
    x = 12 + Rnd(AW - 24) : y = 12 + Rnd(AH - 24)
    If Abs(x - sx \ 16) + Abs(y - sy \ 16) > 70 Then Exit Sub
  Next
End Sub

Sub Queue(ByVal k As Integer, ByVal x As Integer, ByVal y As Integer)
  Dim n As Integer
  For n = 0 To NS - 1
    If st(n) = 0 Then
      sk(n) = k : sxx(n) = x : syy(n) = y : st(n) = 40
      Exit Sub
    End If
  Next
  AddEnemy k, x, y          ' no marker free: straight in
End Sub

' ---------------------------------------------------------------- particles
Sub Burst(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer, ByVal n As Integer)
  Dim k As Integer, a As Integer
  For k = 1 To n
    a = Rnd(16)
    pl(pnext) = 12 + Rnd(14)
    px(pnext) = x * 16 : py(pnext) = y * 16
    pvx(pnext) = Cs(a) * (2 + Rnd(4)) / 4 : pvy(pnext) = sn(a) * (2 + Rnd(4)) / 4
    pc(pnext) = c
    pnext = pnext + 1
    If pnext >= NP Then pnext = 0
  Next
End Sub

Sub Particles()
  Dim k As Integer, x As Integer, y As Integer
  For k = 0 To NP - 1
    If pl(k) Then
      pl(k) = pl(k) - 1
      px(k) = px(k) + pvx(k) : py(k) = py(k) + pvy(k)
      x = px(k) \ 16 : y = py(k) \ 16
      L2.Line x, y, x - pvx(k) \ 16, y - pvy(k) \ 16, pc(k)
    End If
  Next
End Sub

' ---------------------------------------------------------------- the end
Sub GameOver()
  Dim n As Integer
  Tiles.Text 15, 15, "GAME  OVER"
  Hud
  For n = 1 To 150
    L2.Clear
    Particles
    Frame
    L2.Flip
    Sfx.Update
    If n > 50 And FirePressed() Then Exit For
  Next
  Sfx.Quiet
End Sub
