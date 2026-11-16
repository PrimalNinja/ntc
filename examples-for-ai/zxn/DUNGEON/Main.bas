' DUNGEON DEEP - a Dungeon Master style dungeon crawl for the ZX Spectrum Next, in NTC BASIC:
' four heroes, ten levels of maze seen through their eyes, monsters in groups of one to three,
' turn by turn. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
'
' Each step is a turn: the monsters that have seen you come after you. Meet them and it's a fight,
' round by round: each hero fights, casts a spell, guards, drinks a potion, or you all run.
' Find the stairs down on each level (taking them, the party rests: the hurt are healed some, the
' fallen get up). On the tenth level, the dragon.
'
' Keys: Q forward, A back, O turn left, P turn right, Space open a door / a chest, M the map,
'       U a potion for whoever's hurt most, H Oswin's healing spell, R rest a while.
'       In a fight: Q A choose, Space pick, O P the target.
'
' The view is drawn on Layer 2 at each step (L2.cls); the monsters, the heroes' faces and the
' things are sprites, drawn 1x, 2x or 4x by how far away they are; the words and the map are
' the tilemap (Board.cls: a colour per cell).
Option Explicit
Option Turbo

Const NG = 24, LEVELS = 10, NMT = 20
' the view: the middle of the picture (Layer 2), the edges of the cells going away
Const CX = 128, CY = 64
' text colours (tilemap palette rows)
Const C_WHITE = 0, C_GOLD = 1, C_RED = 2, C_BLUE = 3, C_GREY = 4, C_HI = 5, C_GREEN = 6
' sprite slots: the monsters 0-11 (3 x 4), the heroes' faces 12-27, a thing 28, effects 29-31, the pointer 32
Const SL_MON = 0, SL_HERO = 12, SL_THING = 28, SL_FX = 29, SL_PTR = 32

Dim txt As String Max 80
' the level: 32 x 32 cells: 0 floor, 1 wall, 2 a door, 4 the stairs down, 6 a chest
Dim mp(1023) As Byte, seen(1023) As Byte, q(1023) As Integer, dist(1023) As Byte
Dim hw(5) As Integer, hh(5) As Integer
' the party: hp, most hp, mp, most mp, attack, defence, level, xp, guarding
Dim hhp(3) As Integer, hmx(3) As Integer, hmp(3) As Integer, hmm(3) As Integer, hat(3) As Integer, hdf(3) As Integer
Dim hlv(3) As Integer, hxp(3) As Integer, hgd(3) As Integer
' the monster kinds: shape, colour row, hp, attack, defence, xp, gold, the first level they're on
Dim ms(19) As Integer, mrow(19) As Integer, mhp(19) As Integer, mat(19) As Integer, mdf(19) As Integer, mxp(19) As Integer, mlv(19) As Integer
' the groups on this level: where, kind, how many, each one's hp, awake
Dim gx(23) As Integer, gy(23) As Integer, gk(23) As Integer, gc(23) As Integer, gh(71) As Integer, gw(23) As Integer
Dim px As Integer, py As Integer, pd As Integer, lvl As Integer, gold As Long, potions As Integer, steps As Integer
Dim over As Integer, won As Integer, frames As Integer, keyT As Integer, firWas As Integer, logY As Integer
Dim seedL As Long, stx(255) As Integer, sty(255) As Integer
Dim i As Integer, k As Integer, n As Integer, t As Integer

Nx.Border 0
Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Board.Init
L2.Init
Nx.Layers Nx.OrderSUL
Nx.Reg &H4A, 0
Colours
Setup
Do
  TitleScr
  Game
Loop

' ---------------------------------------------------------------- set up
Sub Colours()
  ' (the tile palette: 0 black, 1 white/ink, 2 panel, 5 red, 6 blue, 7 gold ...: each row's ink)
  Board.Pal 0, "00FF258DD6E453F858924005B22400E3"
  Board.Pal 1, "00F8258DD6E453F858924005B22400E3"
  Board.Pal 2, "00E9258DD6E453F858924005B22400E3"
  Board.Pal 3, "0077258DD6E453F858924005B22400E3"
  Board.Pal 4, "0092258DD6E453F858924005B22400E3"
  Board.Pal 5, "00FFA48DD6E453F858924005B22440E3"
  Board.Pal 6, "007D258DD6E453F858924005B22400E3"
End Sub

Sub Mon(ByVal m As Integer, ByVal sh As Integer, ByVal r As Integer, ByVal hp As Integer, ByVal at As Integer, ByVal df As Integer, ByVal xp As Integer, ByVal lv As Integer)
  ms(m) = sh : mrow(m) = r : mhp(m) = hp : mat(m) = at : mdf(m) = df : mxp(m) = xp : mlv(m) = lv
End Sub

Sub Setup()
  ' the view's cell edges: half widths and half heights at 0.5, 1.5, 2.5 ... cells away
  hw(0) = 128 : hw(1) = 72 : hw(2) = 44 : hw(3) = 31 : hw(4) = 24 : hw(5) = 19
  hh(0) = 64 : hh(1) = 40 : hh(2) = 25 : hh(3) = 18 : hh(4) = 14 : hh(5) = 11
  ' kind, shape (art), colours, hp, attack, defence, xp, the first level
  Mon 0, 0, 4, 6, 3, 0, 3, 1        ' GIANT RAT
  Mon 1, 1, 5, 5, 3, 0, 3, 1        ' BAT
  Mon 2, 2, 1, 10, 4, 1, 6, 2       ' GOBLIN
  Mon 3, 7, 1, 14, 4, 0, 6, 2       ' SLIME
  Mon 4, 3, 3, 16, 6, 2, 10, 3      ' SKELETON
  Mon 5, 4, 5, 14, 7, 1, 10, 3      ' GIANT SPIDER
  Mon 6, 2, 2, 22, 8, 2, 15, 4      ' HOBGOBLIN
  Mon 7, 1, 2, 16, 8, 1, 13, 4      ' VAMPIRE BAT
  Mon 8, 5, 4, 40, 11, 3, 25, 5     ' OGRE
  Mon 9, 6, 7, 22, 9, 6, 22, 5      ' GHOST
  Mon 10, 9, 3, 45, 13, 4, 32, 6    ' MUMMY
  Mon 11, 7, 2, 35, 14, 2, 30, 6    ' LAVA SLIME
  Mon 12, 5, 1, 60, 16, 5, 42, 7    ' TROLL
  Mon 13, 6, 6, 40, 15, 7, 44, 7    ' WRAITH
  Mon 14, 8, 2, 70, 19, 6, 60, 8    ' DEMON
  Mon 15, 4, 6, 55, 19, 6, 55, 8    ' PHASE SPIDER
  Mon 16, 10, 9, 80, 21, 7, 80, 9   ' LICH
  Mon 17, 8, 5, 90, 23, 8, 90, 9    ' SHADOW DEMON
  Mon 18, 11, 8, 420, 28, 9, 2000, 10 ' THE DRAGON
  Mon 19, 9, 2, 60, 18, 5, 50, 10   ' FIRE MUMMY
End Sub

Function MonName(ByVal m As Integer) As String
  Select Case m
    Case 0
      MonName = "GIANT RAT"
    Case 1
      MonName = "BAT"
    Case 2
      MonName = "GOBLIN"
    Case 3
      MonName = "SLIME"
    Case 4
      MonName = "SKELETON"
    Case 5
      MonName = "GIANT SPIDER"
    Case 6
      MonName = "HOBGOBLIN"
    Case 7
      MonName = "VAMPIRE BAT"
    Case 8
      MonName = "OGRE"
    Case 9
      MonName = "GHOST"
    Case 10
      MonName = "MUMMY"
    Case 11
      MonName = "LAVA SLIME"
    Case 12
      MonName = "TROLL"
    Case 13
      MonName = "WRAITH"
    Case 14
      MonName = "DEMON"
    Case 15
      MonName = "PHASE SPIDER"
    Case 16
      MonName = "LICH"
    Case 17
      MonName = "SHADOW DEMON"
    Case 18
      MonName = "THE DRAGON"
    Case Else
      MonName = "FIRE MUMMY"
  End Select
End Function

Function HeroName(ByVal h As Integer) As String
  HeroName = RTrim$(Mid$("BRAN KIRA OSWINMAEVE", h * 5 + 1, 5))
End Function

' ---------------------------------------------------------------- keys and frames
' 1 up, 2 down, 3 left, 4 right, 5 Space, 6 M, 7 U, 8 H, 9 R (a new press each)
Function Key() As Integer
  Dim j As Integer, v As Integer
  j = Keys.Joystick(0)
  v = 0
  If Keys.Down(Keys.KeyQ) Or (j And Keys.JoyUp) Then v = 1
  If Keys.Down(Keys.KeyA) Or (j And Keys.JoyDown) Then v = 2
  If Keys.Down(Keys.KeyO) Or (j And Keys.JoyLeft) Then v = 3
  If Keys.Down(Keys.KeyP) Or (j And Keys.JoyRight) Then v = 4
  If Keys.Down(Keys.KeySpace) Or (j And Keys.JoyFire1) Then v = 5
  If Keys.Down(Keys.KeyM) Or (j And Keys.JoyFire2) Then v = 6
  If Keys.Down(Keys.KeyU) Then v = 7
  If Keys.Down(Keys.KeyH) Then v = 8
  If Keys.Down(Keys.KeyR) Then v = 9
  If v = 0 Then firWas = 0 : Key = 0 : Exit Function
  If v = firWas Then
    ' held: moving repeats slowly
    keyT = keyT - 1
    If keyT <= 0 And v <= 2 Then keyT = 10 : Key = v Else Key = 0
    Exit Function
  End If
  firWas = v : keyT = 16 : Key = v
End Function

Sub Tick()
  Frame
  Spr.Show
  Sfx.Update
  frames = frames + 1
End Sub

Sub WaitF(ByVal t As Integer)
  Dim j As Integer
  For j = 1 To t
    Tick
  Next
End Sub

Function WaitKey() As Integer
  Dim v As Integer
  Do
    Tick
    v = Key()
  Loop Until v >= 5
  WaitKey = v
End Function

' a repeatable random number 0 .. n-1 (a level is always the same)
Function RndS(ByVal n As Integer) As Integer
  seedL = (seedL * 1103515245 + 12345) And &H7FFFFFFF
  RndS = CInt((seedL \ 65536) Mod n)
End Function

' ---------------------------------------------------------------- the screen: the log, the party
' a line in the message log (rows 26-30, the oldest scrolls off)
Sub Say(ByVal s As String, ByVal c As Integer)
  Dim y As Integer
  If logY > 4 Then
    ' scroll: the log's text again one line up (simplest: clear and restart at the top)
    Board.Rect 1, 26, 38, 5, GfxData.T_PANEL, 0
    logY = 0
  End If
  Board.Text 2, 26 + logY, Left$(s, 36), c
  logY = logY + 1
End Sub

Sub ClearLog()
  Board.Rect 1, 26, 38, 5, GfxData.T_PANEL, 0
  logY = 0
End Sub

Sub Frame1(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal h As Integer)
  Board.Rect x + 1, y + 1, w - 2, h - 2, GfxData.T_PANEL, 0
  Board.Rect x + 1, y, w - 2, 1, GfxData.T_FT, 0
  Board.Rect x + 1, y + h - 1, w - 2, 1, GfxData.T_FB, 0
  Board.Rect x, y + 1, 1, h - 2, GfxData.T_FL, 0
  Board.Rect x + w - 1, y + 1, 1, h - 2, GfxData.T_FR, 0
  Board.Put x, y, GfxData.T_FTL, 0 : Board.Put x + w - 1, y, GfxData.T_FTR, 0
  Board.Put x, y + h - 1, GfxData.T_FBL, 0 : Board.Put x + w - 1, y + h - 1, GfxData.T_FBR, 0
End Sub

Sub Bar(ByVal x As Integer, ByVal y As Integer, ByVal w As Integer, ByVal v As Integer, ByVal mx As Integer, ByVal b As Integer)
  Dim p As Integer, j As Integer
  If mx <= 0 Then mx = 1
  If v < 0 Then v = 0
  p = (CLng(v) * w * 8) \ mx
  For j = 0 To w - 1
    If p >= 8 Then
      Board.Put x + j, y, b + 8, 0 : p = p - 8
    Else
      Board.Put x + j, y, b + p, 0 : p = 0
    End If
  Next
End Sub

' the whole screen's frame: the top line, the party, the log
Sub Screen1()
  Board.Clear
  Board.Rect 0, 0, 40, 4, GfxData.T_PANEL, 0
  Frame1 0, 20, 40, 12
  Party
  Top
  ClearLog
End Sub

Sub Top()
  Board.Rect 0, 1, 40, 2, GfxData.T_PANEL, 0
  Board.Text 1, 1, "LEVEL" & Str$(lvl), C_GOLD
  Board.Text 10, 1, "FACING " & Mid$("NORTHEAST SOUTH WEST ", pd * 5 + 1, 5), C_WHITE
  Board.Put 25, 1, GfxData.T_GOLD, 0 : Board.Text 26, 1, Format$(gold, "0"), C_GOLD
  Board.Put 33, 1, GfxData.T_POTION, 0 : Board.Text 34, 1, CStr(potions), C_RED
  Board.Text 1, 2, "Q A O P MOVE  M MAP  U H R  SPACE OPEN", C_GREY
End Sub

' the four heroes: a face, the name, HP and MP
Sub Party()
  Dim h As Integer, x As Integer, c As Integer
  For h = 0 To 3
    x = 1 + h * 10
    Board.Rect x, 21, 9, 4, GfxData.T_PANEL, 0
    If hhp(h) > 0 Then c = C_GOLD Else c = C_GREY
    Board.Text x + 4, 21, HeroName(h), c
    Board.Text x + 4, 22, "L" & CStr(hlv(h)), C_WHITE
    Bar x + 4, 23, 5, hhp(h), hmx(h), GfxData.T_BARH
    If hmm(h) > 0 Then Bar x + 4, 24, 5, hmp(h), hmm(h), GfxData.T_BARM
    Face h, 0
  Next
End Sub

' hero h's face (fl: the flash palette: hurt)
Sub Face(ByVal h As Integer, ByVal fl As Integer)
  Dim x As Integer, y As Integer, p As Integer, f As Integer
  x = (1 + h * 10) * 8 : y = 21 * 8
  p = GfxData.S_HERO + h * 4
  f = 0
  If fl Then f = Spr.Pal * 10
  If hhp(h) <= 0 Then f = Spr.Pal * 5
  Spr.Put SL_HERO + h * 4, x, y, p, f : Spr.Put SL_HERO + h * 4 + 1, x + 16, y, p + 1, f
  Spr.Put SL_HERO + h * 4 + 2, x, y + 16, p + 2, f : Spr.Put SL_HERO + h * 4 + 3, x + 16, y + 16, p + 3, f
End Sub

' ---------------------------------------------------------------- the title
Sub TitleScr()
  Dim j As Integer
  Board.Clear
  Spr.HideRange 0, 40
  ' a gloomy corridor behind the title
  lvl = 1 : MakeLevel 1
  px = 1 : py = 1 : pd = 2
  View
  L2.Big 16, 8, "DUNGEON", 4, &HFC, &HA8
  L2.Big 64, 44, "DEEP", 4, &HFC, &HA8
  Frame1 0, 20, 40, 12
  Board.Text 3, 21, "FOUR HEROES. TEN LEVELS. ONE DRAGON.", C_GOLD
  Board.Text 3, 23, "Q A MOVE  O P TURN  SPACE OPEN", C_WHITE
  Board.Text 3, 24, "M MAP  U POTION  H HEAL  R REST", C_WHITE
  Board.Text 3, 26, "IN A FIGHT: Q A CHOOSE, SPACE PICK", C_WHITE
  Board.Text 3, 28, "SPACE TO BEGIN", C_HI
  Board.Text 3, 30, "(C) 2026 CYBORG UNICORN", C_GREY
  MonPic 0, 2, 48, 92, 2, 0
  MonPic 1, 4, 128, 92, 2, 0
  MonPic 2, 9, 208, 92, 2, 0
  Do
    Tick
  Loop Until Key() = 5
  Spr.HideRange 0, 40
  Sfx.Play 0, 200, -6, 14, 25, 0
End Sub

' ---------------------------------------------------------------- a game
Sub Game()
  Dim h As Integer
  ' the heroes: Bran the fighter, Kira the ninja, Oswin the priest, Maeve the wizard
  hmx(0) = 40 : hmm(0) = 0 : hat(0) = 8 : hdf(0) = 3
  hmx(1) = 30 : hmm(1) = 0 : hat(1) = 7 : hdf(1) = 2
  hmx(2) = 28 : hmm(2) = 12 : hat(2) = 4 : hdf(2) = 2
  hmx(3) = 22 : hmm(3) = 16 : hat(3) = 3 : hdf(3) = 1
  For h = 0 To 3
    hhp(h) = hmx(h) : hmp(h) = hmm(h) : hlv(h) = 1 : hxp(h) = 0 : hgd(h) = 0
  Next
  gold = 0 : potions = 3 : over = 0 : won = 0 : steps = 0
  lvl = 1
  Do
    PlayLevel
  Loop Until over Or won
  Ending
End Sub

Sub Ending()
  Board.Rect 1, 26, 38, 5, GfxData.T_PANEL, 0
  logY = 0
  If won Then
    L2.Rect 0, 0, 256, 128, 0
    L2.Big 24, 20, "VICTORY", 3, &HFC, &HF0
    Say "THE DRAGON IS DEAD! THE DUNGEON IS YOURS.", C_GOLD
    Say "GOLD: " & Format$(gold, "0") & "   STEPS: " & CStr(steps), C_WHITE
  Else
    L2.Rect 0, 0, 256, 128, 0
    L2.Big 40, 40, "R.I.P.", 4, &HB6, &H6D
    Say "THE PARTY HAS FALLEN ON LEVEL" & Str$(lvl) & ".", C_RED
    Say "GOLD: " & Format$(gold, "0"), C_WHITE
  End If
  Spr.HideRange 0, 12
  Say "SPACE", C_HI
  WaitF 50
  k = WaitKey()
End Sub

' ---------------------------------------------------------------- the levels
Function Cell(ByVal x As Integer, ByVal y As Integer) As Integer
  If x < 0 Or x > 31 Or y < 0 Or y > 31 Then
    Cell = 1
  Else
    Cell = mp(y * 32 + x)
  End If
End Function

' level lv: a maze of corridors with loops, rooms, doors; the stairs down far from the start;
' chests in the dead ends; the monsters
Sub MakeLevel(ByVal lv As Integer)
  Dim x As Integer, y As Integer, sp As Integer, d As Integer, nx As Integer, ny As Integer, j As Integer, tries As Integer
  Dim w As Integer, h As Integer, far As Integer, fc As Integer, head As Integer, tail As Integer, c As Integer
  seedL = lv * 7919 + 17
  For j = 0 To 1023
    mp(j) = 1 : seen(j) = 0
  Next
  ' the maze: a walk that turns back when it's stuck
  x = 1 : y = 1 : mp(33) = 0 : sp = 0 : stx(0) = 1 : sty(0) = 1
  Do
    ' a way not dug yet
    tries = 0 : d = RndS(4)
    Do
      nx = x + Way(d, 0) * 2 : ny = y + Way(d, 1) * 2
      If nx > 0 And nx < 31 And ny > 0 And ny < 31 Then
        If mp(ny * 32 + nx) = 1 Then Exit Do
      End If
      d = (d + 1) And 3 : tries = tries + 1
    Loop Until tries = 4
    If tries < 4 Then
      mp((y + Way(d, 1)) * 32 + x + Way(d, 0)) = 0
      mp(ny * 32 + nx) = 0
      sp = sp + 1 : stx(sp) = nx : sty(sp) = ny
      x = nx : y = ny
    Else
      sp = sp - 1
      If sp >= 0 Then x = stx(sp) : y = sty(sp)
    End If
  Loop Until sp < 0
  ' loops: walls knocked through
  For j = 1 To 45
    x = 1 + RndS(29) : y = 1 + RndS(29)
    If mp(y * 32 + x) = 1 Then
      If (Cell(x - 1, y) = 0 And Cell(x + 1, y) = 0 And Cell(x, y - 1) = 1 And Cell(x, y + 1) = 1) Or (Cell(x, y - 1) = 0 And Cell(x, y + 1) = 0 And Cell(x - 1, y) = 1 And Cell(x + 1, y) = 1) Then mp(y * 32 + x) = 0
    End If
  Next
  ' rooms
  For j = 1 To 4
    w = 3 + RndS(2) * 2 : h = 3 + RndS(2) * 2
    x = 1 + RndS(14) * 2 : y = 1 + RndS(14) * 2
    If x + w < 31 And y + h < 31 Then
      For ny = y To y + h - 1
        For nx = x To x + w - 1
          mp(ny * 32 + nx) = 0
        Next
      Next
    End If
  Next
  ' doors: in corridors, between two floors
  For j = 1 To 14
    x = 1 + RndS(29) : y = 1 + RndS(29)
    If mp(y * 32 + x) = 0 And (x + y) Mod 2 = 1 Then
      If (Cell(x - 1, y) = 0 And Cell(x + 1, y) = 0 And Cell(x, y - 1) = 1 And Cell(x, y + 1) = 1) Or (Cell(x, y - 1) = 0 And Cell(x, y + 1) = 0 And Cell(x - 1, y) = 1 And Cell(x + 1, y) = 1) Then mp(y * 32 + x) = 2
    End If
  Next
  mp(33) = 0
  ' the stairs: the furthest place from the start
  For j = 0 To 1023
    dist(j) = 255
  Next
  head = 0 : tail = 0 : q(0) = 33 : dist(33) = 0 : tail = 1 : far = 33
  Do While head < tail
    c = q(head) : head = head + 1
    far = c
    For d = 0 To 3
      j = c + Way(d, 0) + Way(d, 1) * 32
      If mp(j) <> 1 And dist(j) = 255 Then
        If dist(c) < 254 Then dist(j) = dist(c) + 1 Else dist(j) = 254
        q(tail) = j : tail = tail + 1
      End If
    Next
  Loop
  mp(far) = 4
  ' chests: in dead ends
  fc = 0
  For j = 1 To 300
    x = 1 + RndS(30) : y = 1 + RndS(30)
    c = y * 32 + x
    If mp(c) = 0 And c <> 33 And fc < 6 Then
      n = 0
      For d = 0 To 3
        If Cell(x + Way(d, 0), y + Way(d, 1)) = 1 Then n = n + 1
      Next
      If n = 3 Then mp(c) = 6 : fc = fc + 1
    End If
  Next
  ' the monsters: groups of 1 to 3, away from the start
  For j = 0 To NG - 1
    gk(j) = -1
  Next
  n = 9 + lv
  If n > NG - 1 Then n = NG - 1
  For j = 0 To n - 1
    For tries = 1 To 50
      x = 1 + RndS(30) : y = 1 + RndS(30)
      c = y * 32 + x
      If mp(c) = 0 And dist(c) > 8 And dist(c) < 255 And GroupAt(x, y) < 0 Then Exit For
    Next
    If tries <= 50 Then NewGroup j, x, y, PickKind(lv), lv
  Next
  ' the dragon, on the last level, on its hoard: where the stairs would be
  If lv = LEVELS Then
    mp(far) = 0
    NewGroup NG - 1, far And 31, far \ 32, 18, lv
    gc(NG - 1) = 1
  End If
  ' the rest is luck again
  seedL = seedL + frames
End Sub

Function PickKind(ByVal lv As Integer) As Integer
  Dim m As Integer
  ' mostly this level's own two kinds, sometimes the level before's
  If lv = LEVELS Then
    m = 16 + RndS(2)
    If RndS(3) = 0 Then m = 19
    PickKind = m
    Exit Function
  End If
  m = (lv - 1) * 2 + RndS(2)
  If lv > 1 And RndS(3) = 0 Then m = m - 2
  PickKind = m
End Function

Sub NewGroup(ByVal j As Integer, ByVal x As Integer, ByVal y As Integer, ByVal m As Integer, ByVal lv As Integer)
  Dim c As Integer
  gx(j) = x : gy(j) = y : gk(j) = m : gw(j) = 0
  gc(j) = 1 + RndS(3)
  For c = 0 To 2
    gh(j * 3 + c) = mhp(m)
  Next
End Sub

Function GroupAt(ByVal x As Integer, ByVal y As Integer) As Integer
  Dim j As Integer
  GroupAt = -1
  For j = 0 To NG - 1
    If gk(j) >= 0 Then
      If gx(j) = x And gy(j) = y Then GroupAt = j
    End If
  Next
End Function

' facing d (0 north, 1 east, 2 south, 3 west): xy 0 the x step, 1 the y step
Function Way(ByVal d As Integer, ByVal xy As Integer) As Integer
  Way = 0
  If xy = 0 Then
    If d = 1 Then Way = 1
    If d = 3 Then Way = -1
  Else
    If d = 0 Then Way = -1
    If d = 2 Then Way = 1
  End If
End Function

' ---------------------------------------------------------------- a level
Sub PlayLevel()
  Dim v As Integer, nx As Integer, ny As Integer, c As Integer, g As Integer, moved As Integer
  MakeLevel lvl
  px = 1 : py = 1
  If Cell(2, 1) <> 1 Then pd = 1 Else pd = 2
  Screen1
  View
  If lvl = 1 Then
    Say "THE STAIRS CLOSE BEHIND YOU.", C_WHITE
    Say "THE ONLY WAY OUT IS DOWN.", C_WHITE
  Else
    Say "LEVEL" & Str$(lvl) & ". IT GETS COLDER.", C_WHITE
  End If
  If lvl = LEVELS Then Say "SOMETHING HUGE BREATHES IN THE DARK...", C_RED
  Do
    v = Key()
    moved = 0
    Select Case v
      Case 1, 2
        If v = 1 Then nx = px + Way(pd, 0) : ny = py + Way(pd, 1) Else nx = px - Way(pd, 0) : ny = py - Way(pd, 1)
        c = Cell(nx, ny)
        g = GroupAt(nx, ny)
        If g >= 0 Then
          Fight g
        ElseIf c = 0 Or c = 4 Then
          px = nx : py = ny : moved = 1
        ElseIf c = 2 Then
          Say "A DOOR. SPACE OPENS IT.", C_GREY
          Sfx.Play 0, 600, 0, 8, 4, 0
        ElseIf c = 6 Then
          Say "A CHEST. SPACE OPENS IT.", C_GREY
        Else
          Sfx.Play 0, 600, 0, 8, 4, 0
        End If
      Case 3
        pd = (pd + 3) And 3 : moved = 2
      Case 4
        pd = (pd + 1) And 3 : moved = 2
      Case 5
        Use1
      Case 6
        Map
        View
      Case 7
        Potion1
      Case 8
        Heal1
      Case 9
        Rest1
        moved = 1
    End Select
    If moved Then
      If moved = 1 Then steps = steps + 1 : Sfx.Play 0, 900, 0, 6, 3, 1
      Top
      View
      If moved = 1 Then Monsters
      ' the stairs
      If Cell(px, py) = 4 Then
        Say "STAIRS DOWN! SPACE: DOWN, Q A O P: STAY", C_GOLD
        Do
          Tick
          v = Key()
        Loop Until v
        If v = 5 Then
          Down1
          Exit Sub
        End If
      End If
    End If
    If v = 0 Then Tick
  Loop Until over Or won
End Sub

' down the stairs: the party rests (the fallen get up), then the next level
Sub Down1()
  Dim h As Integer
  For h = 0 To 3
    If hhp(h) <= 0 Then hhp(h) = 1
    hhp(h) = hhp(h) + hmx(h) \ 2
    If hhp(h) > hmx(h) Then hhp(h) = hmx(h)
    hmp(h) = hmp(h) + hmm(h) \ 2
    If hmp(h) > hmm(h) Then hmp(h) = hmm(h)
  Next
  Sfx.Play 0, 300, 4, 13, 40, 0
  lvl = lvl + 1
End Sub

' Space: open the door or the chest in front
Sub Use1()
  Dim nx As Integer, ny As Integer, c As Integer, r As Integer, h As Integer
  nx = px + Way(pd, 0) : ny = py + Way(pd, 1)
  c = Cell(nx, ny)
  If c = 2 Then
    mp(ny * 32 + nx) = 0
    Say "THE DOOR CREAKS OPEN.", C_WHITE
    Sfx.Play 0, 500, -10, 12, 20, 1
    View
  ElseIf c = 6 Then
    mp(ny * 32 + nx) = 0
    r = Rnd(100)
    Sfx.Play 0, 150, -3, 13, 20, 0
    If r < 40 Then
      n = 10 + Rnd(20) * lvl
      gold = gold + n
      Say "A CHEST: " & CStr(n) & " GOLD!", C_GOLD
    ElseIf r < 70 Then
      potions = potions + 1 + Rnd(2)
      Say "A CHEST: HEALING POTIONS!", C_RED
    ElseIf r < 85 Then
      h = Rnd(2)
      hat(h) = hat(h) + 2
      Say "A CHEST: A BETTER WEAPON FOR " & HeroName(h) & "!", C_GOLD
    Else
      h = Rnd(4)
      hdf(h) = hdf(h) + 1
      Say "A CHEST: BETTER ARMOUR FOR " & HeroName(h) & "!", C_GOLD
    End If
    Top
    View
  Else
    Say "NOTHING TO OPEN HERE.", C_GREY
  End If
End Sub

Sub Potion1()
  Dim h As Integer, w As Integer
  If potions = 0 Then Say "NO POTIONS LEFT.", C_GREY : Exit Sub
  w = -1
  For h = 0 To 3
    If hhp(h) > 0 And hhp(h) < hmx(h) Then
      If w < 0 Then
        w = h
      ElseIf hhp(h) * 100 \ hmx(h) < hhp(w) * 100 \ hmx(w) Then
        w = h
      End If
    End If
  Next
  If w < 0 Then Say "NOBODY NEEDS ONE.", C_GREY : Exit Sub
  potions = potions - 1
  hhp(w) = hhp(w) + 25
  If hhp(w) > hmx(w) Then hhp(w) = hmx(w)
  Say HeroName(w) & " DRINKS A POTION.", C_RED
  Sfx.Play 0, 200, -4, 12, 15, 0
  Party : Top
End Sub

' Oswin's healing: the most hurt (4 MP)
Sub Heal1()
  Dim h As Integer, w As Integer
  If hhp(2) <= 0 Then Say "OSWIN CAN'T: HE'S FALLEN.", C_GREY : Exit Sub
  If hmp(2) < 4 Then Say "OSWIN HAS NO MAGIC LEFT.", C_GREY : Exit Sub
  w = -1
  For h = 0 To 3
    If hhp(h) > 0 And hhp(h) < hmx(h) Then
      If w < 0 Then
        w = h
      ElseIf hhp(h) * 100 \ hmx(h) < hhp(w) * 100 \ hmx(w) Then
        w = h
      End If
    End If
  Next
  If w < 0 Then Say "NOBODY IS HURT.", C_GREY : Exit Sub
  hmp(2) = hmp(2) - 4
  hhp(w) = hhp(w) + 15 + hlv(2) * 3
  If hhp(w) > hmx(w) Then hhp(w) = hmx(w)
  Say "OSWIN HEALS " & HeroName(w) & ".", C_GREEN
  Sfx.Play 0, 100, -2, 12, 20, 0
  Party
End Sub

' rest: some HP and MP back - but the noise may bring something
Sub Rest1()
  Dim h As Integer, j As Integer
  Say "YOU REST A WHILE...", C_GREY
  WaitF 40
  For h = 0 To 3
    If hhp(h) > 0 Then
      hhp(h) = hhp(h) + hmx(h) \ 5
      If hhp(h) > hmx(h) Then hhp(h) = hmx(h)
      hmp(h) = hmp(h) + hmm(h) \ 4
      If hmp(h) > hmm(h) Then hmp(h) = hmm(h)
    End If
  Next
  Party
  ' woken by a wandering group?
  If Rnd(3) = 0 Then
    For j = 0 To NG - 2
      If gk(j) < 0 Then
        gk(j) = PickKind(lvl) : gc(j) = 1 + Rnd(3) : gw(j) = 1
        For k = 0 To 2
          gh(j * 3 + k) = mhp(gk(j))
        Next
        ' (next to you, where there's room)
        gx(j) = -1
        For k = 0 To 3
          If gx(j) < 0 Then
            If Cell(px + Way(k, 0), py + Way(k, 1)) = 0 And GroupAt(px + Way(k, 0), py + Way(k, 1)) < 0 Then gx(j) = px + Way(k, 0) : gy(j) = py + Way(k, 1)
          End If
        Next
        If gx(j) < 0 Then gk(j) = -1 : Exit Sub
        Say "SOMETHING FOUND YOU!", C_RED
        WaitF 30
        Fight j
        Exit Sub
      End If
    Next
  End If
End Sub

' ---------------------------------------------------------------- the monsters move
Sub Monsters()
  Dim j As Integer, dx As Integer, dy As Integer, nx As Integer, ny As Integer, c As Integer
  For j = 0 To NG - 1
    If gk(j) >= 0 And over = 0 Then
      dx = px - gx(j) : dy = py - gy(j)
      ' close enough to notice you
      If Abs(dx) + Abs(dy) <= 5 Then gw(j) = 1
      If gw(j) And gk(j) <> 18 Then
        If Abs(dx) + Abs(dy) = 1 Then
          If gc(j) > 1 Then Say "THE " & MonName(gk(j)) & "S ATTACK!", C_RED Else Say "THE " & MonName(gk(j)) & " ATTACKS!", C_RED
          Fight j
        Else
          ' a step towards you: across or down, whichever's free
          nx = gx(j) : ny = gy(j)
          If Abs(dx) >= Abs(dy) Then nx = nx + Sgn(dx) Else ny = ny + Sgn(dy)
          c = Cell(nx, ny)
          If (c <> 0 And c <> 4) Or GroupAt(nx, ny) >= 0 Or (nx = px And ny = py) Then
            nx = gx(j) : ny = gy(j)
            If Abs(dx) >= Abs(dy) Then ny = ny + Sgn(dy) Else nx = nx + Sgn(dx)
            c = Cell(nx, ny)
            If (c <> 0 And c <> 4) Or GroupAt(nx, ny) >= 0 Or (nx = px And ny = py) Then nx = gx(j) : ny = gy(j)
          End If
          gx(j) = nx : gy(j) = ny
        End If
      ElseIf gk(j) = 18 And Abs(dx) + Abs(dy) = 1 Then
        Say "THE DRAGON WAKES!", C_RED
        Fight j
      End If
    End If
  Next
  If over = 0 Then View
End Sub

Function Plural(ByVal j As Integer) As String
  If gc(j) > 1 Then Plural = "S" Else Plural = ""
End Function

' ---------------------------------------------------------------- the view
' cell d ahead, c to the right (- left)
Function Ahead(ByVal d As Integer, ByVal c As Integer) As Integer
  Dim x As Integer, y As Integer
  x = px + Way(pd, 0) * d - Way(pd, 1) * c
  y = py + Way(pd, 1) * d + Way(pd, 0) * c
  Ahead = Cell(x, y)
  If d <= 3 And c >= -1 And c <= 1 Then
    If x >= 0 And x < 32 And y >= 0 And y < 32 Then seen(y * 32 + x) = 1
  End If
End Function

Function AheadG(ByVal d As Integer) As Integer
  AheadG = GroupAt(px + Way(pd, 0) * d, py + Way(pd, 1) * d)
End Function

' the colours for depth d: walls lighter near; c: the wall's colour family (0 stone, 1 a door)
Function WallCol(ByVal d As Integer, ByVal side As Integer) As Integer
  Dim v As Integer
  v = 4 - d
  If side Then v = v - 1
  If v < 0 Then v = 0
  Select Case v
    Case 0
      WallCol = &H24
    Case 1
      WallCol = &H49
    Case 2
      WallCol = &H6D
    Case 3
      WallCol = &H92
    Case Else
      WallCol = &HB6
  End Select
  ' a hint of each level's stone colour
  If lvl > 3 And lvl <= 6 Then WallCol = WallCol And &HFC Or 1
  If lvl > 6 Then WallCol = (WallCol And &HE3) Or &H00
End Function

Sub View()
  Dim d As Integer, c As Integer, g As Integer
  seen(py * 32 + px) = 1
  Spr.HideRange SL_MON, 12
  Spr.Hide SL_THING
  L2.Back
  ' the ceiling and the floor, darker away from you
  For d = 0 To 4
    L2.Rect 0, CY - hh(d), 256, hh(d) - hh(d + 1), Shade(d, 0)
    L2.Rect 0, CY + hh(d + 1), 256, hh(d) - hh(d + 1), Shade(d, 1)
  Next
  L2.Rect 0, CY - hh(5), 256, hh(5) * 2, 0
  ' far to near: the faces of the walls one further on, then this depth's side walls
  For d = 4 To 0 Step -1
    For c = -2 To 2
      If c <> 0 Then
        If IsWall(Ahead(d + 1, c)) Then Front d + 1, c, Ahead(d + 1, c)
      End If
    Next
    If IsWall(Ahead(d + 1, 0)) Then Front d + 1, 0, Ahead(d + 1, 0)
    If IsWall(Ahead(d, -1)) Then Side d, -1, Ahead(d, -1)
    If IsWall(Ahead(d, 1)) Then Side d, 1, Ahead(d, 1)
    ' on the floor in front: the stairs, a chest
    If d >= 1 And d <= 3 Then
      If Ahead(d, 0) = 4 Then Stairs d
    End If
  Next
  L2.Flip
  ' a chest or monsters straight ahead (the nearest)
  For d = 3 To 1 Step -1
    If Ahead(d, 0) = 6 And Blocked(d) = 0 Then Thing d
  Next
  For d = 3 To 1 Step -1
    g = AheadG(d)
    If g >= 0 And Blocked(d) = 0 Then ShowGroup g, d
  Next
End Sub

' is something in the way before depth d (a wall or a closed door, straight ahead)
Function Blocked(ByVal d As Integer) As Integer
  Dim j As Integer
  Blocked = 0
  For j = 1 To d - 1
    If IsWall(Ahead(j, 0)) Then Blocked = 1
  Next
End Function

Function IsWall(ByVal c As Integer) As Integer
  IsWall = (c = 1 Or c = 2)
End Function

Function Shade(ByVal d As Integer, ByVal fl As Integer) As Integer
  If fl Then
    Shade = Val(Mid$("073072036036000", d * 3 + 1, 3))
  Else
    Shade = Val(Mid$("037036001000000", d * 3 + 1, 3))
  End If
End Function

' the face of the wall d cells ahead, c across (its near side, at edge d)
Sub Front(ByVal d As Integer, ByVal c As Integer, ByVal kind As Integer)
  Dim x0 As Integer, x1 As Integer, y0 As Integer, y1 As Integer, col As Integer, j As Integer, y As Integer
  If d > 5 Then Exit Sub
  x0 = CX + (2 * c - 1) * hw(d) : x1 = CX + (2 * c + 1) * hw(d)
  y0 = CY - hh(d) : y1 = CY + hh(d)
  If x1 <= 0 Or x0 >= 256 Then Exit Sub
  If x0 < 0 Then x0 = 0
  If x1 > 256 Then x1 = 256
  col = WallCol(d, 0)
  L2.Rect x0, y0, x1 - x0, y1 - y0, col
  ' the mortar: 4 courses of blocks
  For j = 1 To 3
    y = y0 + (y1 - y0) * j \ 4
    L2.Span x0, y, x1 - x0, col - &H24 * (col > &H24) * -1
  Next
  If kind = 2 Then
    ' a door: wood in a stone frame, a ring
    j = (x1 - x0) \ 6
    L2.Rect x0 + j, y0 + (y1 - y0) \ 8, x1 - x0 - j * 2, y1 - y0 - (y1 - y0) \ 8, &H88 - &H24 * (d > 2) * -1
    For y = x0 + j * 2 To x1 - j * 2 Step j
      L2.Rect y, y0 + (y1 - y0) \ 8, 1, y1 - y0 - (y1 - y0) \ 8, &H44
    Next
    L2.Rect x1 - j * 2, CY, (x1 - x0) \ 16 + 1, (x1 - x0) \ 16 + 1, &HF8
  End If
End Sub

' the side wall of the cell d ahead (side -1 left, 1 right): from edge d to edge d+1
Sub Side(ByVal d As Integer, ByVal sd As Integer, ByVal kind As Integer)
  Dim xa As Integer, xb As Integer, x As Integer, w As Integer, y As Integer, top As Integer, col As Integer, cm As Integer
  ' columns from the near edge (xa) to the far one (xb), drawn as rows: each row y spans the
  ' columns whose wall reaches it
  col = WallCol(d, 1)
  cm = col - &H24 * (col > &H24) * -1
  If kind = 2 Then col = &H88 : cm = &H44
  If sd < 0 Then
    xa = CX - hw(d) : xb = CX - hw(d + 1)
  Else
    xa = CX + hw(d) : xb = CX + hw(d + 1)
  End If
  w = Abs(xb - xa)
  ' the middle band (full width): between the far edge's top and bottom
  For y = CY - hh(d) To CY + hh(d) - 1
    ' how far in from the near edge this row reaches (0 .. w): the slant at top and bottom
    If y < CY - hh(d + 1) Then
      x = (CLng(y - (CY - hh(d))) * w) \ (hh(d) - hh(d + 1))
    ElseIf y >= CY + hh(d + 1) Then
      x = (CLng((CY + hh(d)) - 1 - y) * w) \ (hh(d) - hh(d + 1))
    Else
      x = w
    End If
    If x > 0 Then
      top = y
      If sd < 0 Then
        If xa < 0 Then
          If xa + x > 0 Then L2.Span 0, y, xa + x, RowCol(y, d, col, cm)
        Else
          L2.Span xa, y, x, RowCol(y, d, col, cm)
        End If
      Else
        If xa > 256 Then
          If xa - x < 256 Then L2.Span xa - x, y, 256 - (xa - x), RowCol(y, d, col, cm)
        Else
          L2.Span xa - x, y, x, RowCol(y, d, col, cm)
        End If
      End If
    End If
  Next
End Sub

' a side wall's row colour: mortar lines where the courses meet
Function RowCol(ByVal y As Integer, ByVal d As Integer, ByVal col As Integer, ByVal cm As Integer) As Integer
  Dim f As Integer
  f = ((y - (CY - hh(d))) * 8) \ (hh(d) * 2)
  If ((y - (CY - hh(d))) * 4) Mod (hh(d) * 2) < 4 And y > CY - hh(d) + 1 Then RowCol = cm Else RowCol = col
End Function

' the stairs down on the floor of the cell d ahead
Sub Stairs(ByVal d As Integer)
  Dim y As Integer, y0 As Integer, y1 As Integer, x As Integer, s As Integer
  y0 = CY + hh(d + 1) : y1 = CY + hh(d)
  For y = y0 To y1 - 1
    x = hw(d + 1) + (CLng(y - y0) * (hw(d) - hw(d + 1))) \ (y1 - y0)
    x = x * 2 \ 3
    s = ((y - y0) * 4) \ (y1 - y0 + 1)
    If s Mod 2 Then L2.Span CX - x, y, x * 2, &H24 Else L2.Span CX - x, y, x * 2, &H00
  Next
End Sub

' a chest on the floor of the cell d ahead
Sub Thing(ByVal d As Integer)
  Dim z As Integer, fl As Integer, y As Integer
  z = 4 \ d
  If z = 3 Then z = 2
  fl = 0
  If z = 2 Then fl = Spr.Scale2
  If z = 4 Then fl = Spr.Scale4
  y = CY + (hh(d) + hh(d + 1)) \ 2
  Spr.Put SL_THING, CX - 8 * z + 32, y - 16 * z + 32 + 4 * z, GfxData.S_THING, fl
End Sub

' group g in the cell d ahead: its monsters side by side, bigger nearer
Sub ShowGroup(ByVal g As Integer, ByVal d As Integer)
  Dim z As Integer, j As Integer, n1 As Integer, x As Integer, y As Integer, fl As Integer, w As Integer
  n1 = 0
  For j = 0 To 2
    If j < gc(g) Then
      If gh(g * 3 + j) > 0 Then n1 = n1 + 1
    End If
  Next
  If d = 1 Then
    z = 2
    If n1 = 1 Then z = 4
  ElseIf d = 2 Then
    z = 2
    If n1 > 1 Then z = 1
  Else
    z = 1
  End If
  w = 32 * z
  y = CY + (hh(d) + hh(d + 1)) \ 2 - w + 32
  x = CX - (n1 * w + (n1 - 1) * 4) \ 2 + 32
  n1 = 0
  For j = 0 To 2
    If j < gc(g) Then
      If gh(g * 3 + j) > 0 Then
        MonPic j, gk(g), x + n1 * (w + 4), y, z, 0
        n1 = n1 + 1
      Else
        Spr.HideRange SL_MON + j * 4, 4
      End If
    Else
      Spr.HideRange SL_MON + j * 4, 4
    End If
  Next
End Sub

' monster j of the group (its 4 sprites), kind m, at x, y, z times the size, fl: the flash
Sub MonPic(ByVal j As Integer, ByVal m As Integer, ByVal x As Integer, ByVal y As Integer, ByVal z As Integer, ByVal fl As Integer)
  Dim p As Integer, f As Integer, q1 As Integer
  If y < 32 Then y = 32                     ' (a big one close up: not over the top line)
  p = GfxData.S_MON + ms(m) * 4
  f = Spr.Pal * mrow(m)
  If fl Then f = Spr.Pal * 10
  If z = 2 Then f = f + Spr.Scale2
  If z = 4 Then f = f + Spr.Scale4
  q1 = 16 * z
  Spr.Put SL_MON + j * 4, x, y, p, f : Spr.Put SL_MON + j * 4 + 1, x + q1, y, p + 1, f
  Spr.Put SL_MON + j * 4 + 2, x, y + q1, p + 2, f : Spr.Put SL_MON + j * 4 + 3, x + q1, y + q1, p + 3, f
End Sub

' ---------------------------------------------------------------- the map
Sub Map()
  Dim x As Integer, y As Integer, c As Integer, t1 As Integer, ox As Integer
  Spr.HideRange 0, 40
  ' 32 x 32 cells as tiles would be too tall: the map is the 32 x 16 rows around you
  ox = py - 8
  If ox < 0 Then ox = 0
  If ox > 16 Then ox = 16
  Board.Rect 4, 4, 32, 16, GfxData.T_MDARK, 0
  For y = 0 To 15
    For x = 0 To 31
      c = (ox + y) * 32 + x
      If seen(c) Then
        Select Case mp(c)
          Case 1
            t1 = GfxData.T_MWALL
          Case 2
            t1 = GfxData.T_MDOOR
          Case 4
            t1 = GfxData.T_MSTAIRS
          Case 6
            t1 = GfxData.T_MCHEST
          Case Else
            t1 = GfxData.T_MFLOOR
        End Select
        If GroupAt(x, ox + y) >= 0 Then t1 = GfxData.T_MMON
        If x = px And ox + y = py Then t1 = GfxData.T_MYOU + pd
        Board.Put 4 + x, 4 + y, t1, 0
      End If
    Next
  Next
  Say "THE MAP. ANY KEY TO GO BACK.", C_GREY
  Do
    Tick
  Loop Until Key()
  Board.Rect 4, 4, 32, 16, 0, 0
  Party
End Sub

' ---------------------------------------------------------------- a fight
Function Alive(ByVal g As Integer) As Integer
  Dim j As Integer, n1 As Integer
  n1 = 0
  For j = 0 To gc(g) - 1
    If gh(g * 3 + j) > 0 Then n1 = n1 + 1
  Next
  Alive = n1
End Function

Function PartyUp() As Integer
  Dim h As Integer, n1 As Integer
  n1 = 0
  For h = 0 To 3
    If hhp(h) > 0 Then n1 = n1 + 1
  Next
  PartyUp = n1
End Function

' where monster j of group g is on the screen now (for the effects and the pointer)
Function MonX(ByVal g As Integer, ByVal j As Integer) As Integer
  Dim n1 As Integer, k1 As Integer, z As Integer, w As Integer, a As Integer
  n1 = Alive(g)
  z = 2
  If n1 = 1 Then z = 4
  w = 32 * z
  a = 0
  For k1 = 0 To j - 1
    If gh(g * 3 + k1) > 0 Then a = a + 1
  Next
  MonX = CX - (n1 * w + (n1 - 1) * 4) \ 2 + 32 + a * (w + 4) + w \ 2
End Function

Sub Fight(ByVal g As Integer)
  Dim h As Integer, act As Integer, tg As Integer, d As Integer, j As Integer, ran As Integer, xp As Integer, round1 As Integer
  ' face them
  For d = 0 To 3
    If px + Way(d, 0) = gx(g) And py + Way(d, 1) = gy(g) Then pd = d
  Next
  Top
  View
  ShowGroup g, 1
  ClearLog
  If Alive(g) > 1 Then Say CStr(Alive(g)) & " " & MonName(gk(g)) & "S!", C_RED Else Say "A " & MonName(gk(g)) & "!", C_RED
  Sfx.Play 1, 400, -10, 14, 30, 0
  WaitF 30
  ran = 0 : round1 = 0
  For h = 0 To 3
    hgd(h) = 0
  Next
  Do
    round1 = round1 + 1
    ' the heroes, one by one
    For h = 0 To 3
      If hhp(h) > 0 And Alive(g) > 0 And ran = 0 Then
        hgd(h) = 0
        act = Choose1(h)
        Select Case act
          Case 0
            tg = Target(g)
            Hit h, g, tg
          Case 1
            Spell h, g
          Case 2
            hgd(h) = 1
            Say HeroName(h) & " GUARDS.", C_GREY
          Case 3
            Potion1
          Case 4
            If Rnd(100) < 55 Then
              Say "YOU GET AWAY!", C_WHITE
              ran = 1
            Else
              Say "YOU CAN'T GET AWAY!", C_RED
              Exit For
            End If
        End Select
        WaitF 20
      End If
    Next
    ' the monsters
    If Alive(g) > 0 And ran = 0 Then
      For j = 0 To gc(g) - 1
        If gh(g * 3 + j) > 0 And PartyUp() > 0 Then MonsterTurn g, j, round1
      Next
    End If
    Party
  Loop Until Alive(g) = 0 Or PartyUp() = 0 Or ran
  Spr.Hide SL_PTR
  If PartyUp() = 0 Then
    over = 1
    Exit Sub
  End If
  If ran Then
    ' they stay where they were, and they're awake
    View
    Exit Sub
  End If
  ' won: xp and gold
  xp = mxp(gk(g)) * gc(g)
  n = Rnd(10 * lvl) + 5 * gc(g)
  gold = gold + n
  Say "VICTORY! " & CStr(xp) & " XP, " & CStr(n) & " GOLD.", C_GOLD
  Sfx.Play 0, 100, -2, 14, 40, 0
  If gk(g) = 18 Then won = 1
  gk(g) = -1
  For h = 0 To 3
    If hhp(h) > 0 Then Gain h, xp
  Next
  Party : Top
  WaitF 40
  If won = 0 Then View
End Sub

' hero h's xp: up a level now and then
Sub Gain(ByVal h As Integer, ByVal xp As Integer)
  hxp(h) = hxp(h) + xp
  Do While hxp(h) >= 20 * hlv(h) * hlv(h)
    hlv(h) = hlv(h) + 1
    hmx(h) = hmx(h) + Val(Mid$("8654", h + 1, 1)) + Rnd(3)
    hmm(h) = hmm(h) + Val(Mid$("0034", h + 1, 1))
    hat(h) = hat(h) + 1 + Rnd(2) * (h < 2) * -1
    hdf(h) = hdf(h) + Rnd(2)
    hhp(h) = hmx(h) : hmp(h) = hmm(h)
    Say HeroName(h) & " IS NOW LEVEL" & Str$(hlv(h)) & "!", C_GOLD
    Party
    Sfx.Play 2, 80, -2, 13, 30, 0
    WaitF 30
  Loop
End Sub

' hero h's choice: 0 fight, 1 a spell, 2 guard, 3 a potion, 4 run
Function Choose1(ByVal h As Integer) As Integer
  Dim sel As Integer, v As Integer, j As Integer, c As Integer
  Face h, 0
  Board.Rect 1, 26, 38, 5, GfxData.T_PANEL, 0
  logY = 0
  Board.Text 2, 26, HeroName(h) & ":", C_GOLD
  sel = 0
  Do
    For j = 0 To 4
      c = C_WHITE
      If j = 1 And hmm(h) = 0 Then c = C_GREY
      If j = 3 And potions = 0 Then c = C_GREY
      If j = sel Then c = C_HI
      Board.Text 9 + (j Mod 3) * 10, 26 + (j \ 3) * 2, Mid$("FIGHT    SPELL    GUARD    POTION   RUN      ", j * 9 + 1, 9), c
    Next
    Spr.Put SL_PTR, (1 + h * 10) * 8 + 34, 21 * 8 + 4 + (frames \ 8) Mod 2 * 2, GfxData.S_POINT, Spr.MirrorX
    Do
      Tick
      v = Key()
    Loop Until v
    If v = 3 And sel > 0 Then sel = sel - 1
    If v = 4 And sel < 4 Then sel = sel + 1
    If v = 1 And sel >= 3 Then sel = sel - 3
    If v = 2 And sel < 2 Then sel = sel + 3
    If v = 5 Then
      If sel = 1 And hmm(h) = 0 Then v = 0
      If sel = 3 And potions = 0 Then v = 0
    End If
  Loop Until v = 5
  Spr.Hide SL_PTR
  Board.Rect 1, 26, 38, 5, GfxData.T_PANEL, 0
  logY = 0
  Choose1 = sel
End Function

' which monster: O P along, Space (one left: that one)
Function Target(ByVal g As Integer) As Integer
  Dim t1 As Integer, v As Integer, j As Integer
  t1 = -1
  For j = 0 To gc(g) - 1
    If gh(g * 3 + j) > 0 And t1 < 0 Then t1 = j
  Next
  If Alive(g) = 1 Then Target = t1 : Exit Function
  Say "WHICH ONE? O P, SPACE", C_GREY
  Do
    Spr.Put SL_PTR, MonX(g, t1) - 8, 36 + (frames \ 8) Mod 2 * 2, GfxData.S_POINT, Spr.Rotate
    Do
      Tick
      v = Key()
    Loop Until v
    If v = 3 Then
      For j = t1 - 1 To 0 Step -1
        If gh(g * 3 + j) > 0 Then t1 = j : Exit For
      Next
    End If
    If v = 4 Then
      For j = t1 + 1 To gc(g) - 1
        If gh(g * 3 + j) > 0 Then t1 = j : Exit For
      Next
    End If
  Loop Until v = 5
  Spr.Hide SL_PTR
  Target = t1
End Function

' an effect sprite over monster j of group g for a moment (e: 0 slash, 1 fire, 2 heal, 3 lightning)
Sub Effect(ByVal g As Integer, ByVal j As Integer, ByVal e As Integer)
  Dim w As Integer
  Spr.Put SL_FX, MonX(g, j) - 16, 72, GfxData.S_FX + e, Spr.Scale2
  For w = 1 To 12
    If w Mod 4 < 2 Then FlashMon g, j, 1 Else FlashMon g, j, 0
    Tick
  Next
  FlashMon g, j, 0
  Spr.Hide SL_FX
End Sub

Sub FlashMon(ByVal g As Integer, ByVal j As Integer, ByVal on1 As Integer)
  Dim z As Integer, w As Integer, n1 As Integer
  n1 = Alive(g)
  z = 2
  If n1 = 1 Then z = 4
  w = 32 * z
  MonPic j, gk(g), MonX(g, j) - w \ 2, CY + (hh(1) + hh(2)) \ 2 - w + 32, z, on1
End Sub

' hero h hits monster j of group g
Sub Hit(ByVal h As Integer, ByVal g As Integer, ByVal j As Integer)
  Dim dmg As Integer, m As Integer
  m = gk(g)
  dmg = hat(h) + Rnd(hat(h) \ 2 + 2) - mdf(m)
  ' ghosts and wraiths: blades pass through them, often
  If (m = 9 Or m = 13) And Rnd(2) = 0 Then
    Say HeroName(h) & "'S BLADE PASSES THROUGH IT!", C_GREY
    Sfx.Play 0, 300, 10, 10, 10, 0
    Exit Sub
  End If
  ' Kira: a deadly strike, now and then
  If h = 1 And Rnd(5) = 0 Then dmg = dmg * 2 : Say "KIRA STRIKES A WEAK SPOT!", C_GOLD
  If dmg < 1 Then dmg = 1
  Effect g, j, 0
  Damage g, j, dmg
  Say HeroName(h) & " HITS FOR" & Str$(dmg) & ".", C_WHITE
  Sfx.Play 2, 30, 3, 13, 8, 1
End Sub

Sub Damage(ByVal g As Integer, ByVal j As Integer, ByVal dmg As Integer)
  gh(g * 3 + j) = gh(g * 3 + j) - dmg
  If gh(g * 3 + j) <= 0 Then
    gh(g * 3 + j) = 0
    Say "THE " & MonName(gk(g)) & " FALLS!", C_GOLD
    Sfx.Play 1, 200, 10, 13, 20, 0
    ShowGroup g, 1
  End If
End Sub

' a spell: Oswin heals (or heals everyone at level 3 and up), Maeve's fireball (everyone) or lightning
Sub Spell(ByVal h As Integer, ByVal g As Integer)
  Dim j As Integer, w As Integer, dmg As Integer, a As Integer
  If h = 2 Then
    If hlv(2) >= 3 And hmp(2) >= 8 And Hurt2() >= 2 Then
      hmp(2) = hmp(2) - 8
      For j = 0 To 3
        If hhp(j) > 0 Then hhp(j) = hhp(j) + 10 + hlv(2) * 2 : If hhp(j) > hmx(j) Then hhp(j) = hmx(j)
      Next
      Say "OSWIN HEALS EVERYONE.", C_GREEN
    ElseIf hmp(2) >= 4 Then
      Heal1
    Else
      Say "OSWIN HAS NO MAGIC LEFT.", C_GREY
    End If
    Sfx.Play 0, 100, -2, 12, 20, 0
    Party
  ElseIf h = 3 Then
    If hmp(3) >= 5 And Alive(g) > 1 Then
      hmp(3) = hmp(3) - 5
      Say "MAEVE CASTS A FIREBALL!", C_RED
      Sfx.Play 2, 20, 2, 15, 30, 1
      For j = 0 To gc(g) - 1
        If gh(g * 3 + j) > 0 Then
          Effect g, j, 1
          dmg = 10 + hlv(3) * 3 + Rnd(6)
          Damage g, j, dmg
        End If
      Next
    ElseIf hmp(3) >= 3 Then
      hmp(3) = hmp(3) - 3
      a = Target(g)
      Say "MAEVE CALLS DOWN LIGHTNING!", C_BLUE
      Sfx.Play 2, 10, 0, 15, 20, 1
      Effect g, a, 3
      dmg = 16 + hlv(3) * 4 + Rnd(8)
      Damage g, a, dmg
      Say "IT HITS FOR" & Str$(dmg) & ".", C_WHITE
    Else
      Say "MAEVE HAS NO MAGIC LEFT.", C_GREY
    End If
    Party
  Else
    Say HeroName(h) & " KNOWS NO SPELLS.", C_GREY
  End If
End Sub

Function Hurt2() As Integer
  Dim j As Integer, n1 As Integer
  n1 = 0
  For j = 0 To 3
    If hhp(j) > 0 And hhp(j) < hmx(j) * 2 \ 3 Then n1 = n1 + 1
  Next
  Hurt2 = n1
End Function

' monster j of group g has its go
Sub MonsterTurn(ByVal g As Integer, ByVal j As Integer, ByVal r As Integer)
  Dim m As Integer, h As Integer, dmg As Integer, tries As Integer
  m = gk(g)
  ' the fire breathers: every third round, at everyone
  If (m = 14 Or m = 16 Or m = 18 Or m = 19) And r Mod 3 = 0 Then
    If m = 16 Then Say "THE LICH CASTS FIRE!", C_RED Else Say "THE " & MonName(m) & " BREATHES FIRE!", C_RED
    Sfx.Play 2, 20, 2, 15, 30, 1
    For h = 0 To 3
      If hhp(h) > 0 Then
        dmg = mat(m) \ 2 + Rnd(mat(m) \ 3 + 1) - hdf(h) \ 2
        If hgd(h) Then dmg = dmg \ 2
        If dmg < 1 Then dmg = 1
        HurtHero h, dmg
      End If
    Next
    Exit Sub
  End If
  ' someone to bite: the front two more often
  For tries = 1 To 10
    h = Rnd(6)
    If h > 3 Then h = h - 4
    If hhp(h) > 0 Then Exit For
  Next
  If hhp(h) <= 0 Then Exit Sub
  dmg = mat(m) + Rnd(mat(m) \ 2 + 1) - hdf(h)
  If hgd(h) Then dmg = dmg \ 2
  If dmg < 1 Then dmg = 1
  ' a miss now and then
  If Rnd(8) = 0 Then
    Say "THE " & MonName(m) & " MISSES " & HeroName(h) & ".", C_GREY
    Exit Sub
  End If
  Say "THE " & MonName(m) & " HITS " & HeroName(h) & " FOR" & Str$(dmg) & ".", C_RED
  HurtHero h, dmg
  WaitF 10
End Sub

Sub HurtHero(ByVal h As Integer, ByVal dmg As Integer)
  Dim w As Integer
  hhp(h) = hhp(h) - dmg
  Sfx.Play 2, 60, 6, 14, 10, 1
  For w = 1 To 10
    Face h, w Mod 4 < 2
    Tick
  Next
  If hhp(h) <= 0 Then
    hhp(h) = 0
    Say HeroName(h) & " FALLS!", C_RED
    Sfx.Play 1, 400, 20, 15, 40, 0
  End If
  Face h, 0
  Party
End Sub
