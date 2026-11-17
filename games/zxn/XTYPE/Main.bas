' ============================================================================
' X-TYPE - a horizontal shoot-'em-up for the ZX Spectrum Next
' (c) 2026 Cyborg Unicorn Pty Ltd
' ============================================================================
' NTC BASIC. An original game: new ship, new orb, new enemies, new stages, new sound. The tilemap
' scrolls the terrain (the hardware scrolls it a pixel a frame; a new column of tiles is written
' every 8 pixels, under the clip window's edge), the 128 hardware sprites are everything else.
'   Q A O P  move      SPACE  tap: shoot - hold: charge, let go: the wave beam
'   Z  the orb: send it out, call it back (or swap sides when it is behind you)
' (Joystick 1 works too: fire shoots and charges; the second button is the orb.)
' Pick-ups: S speed, P power (single, double, spread), O the orb. Two stages, then it all again, harder.
Option Explicit
Option Turbo
#Const SplashNoPlain     ' (the plain Cyborg Unicorn screen isn't used here)

' ---------------------------------------------------------------- sprite slots (128)
Const SL_SHIP = 0         ' 2
Const SL_FLAME = 2
Const SL_ORB = 3
Const SL_GLOW = 4
Const SL_WAVE = 5         ' 5
Const SL_SHOT = 10        ' 16
Const SL_EBUL = 26        ' 8
Const SL_PICK = 34        ' 3
Const SL_ENM = 37         ' 16 x 2
Const SL_BOSS = 69        ' 12
Const SL_BOOM = 81        ' 10
Const SL_SCORE = 91       ' 8
Const SL_LIFE = 99        ' 3
Const SL_GAUGE = 102      ' 8

Const NEN = 15             ' enemies 0 - 15
Const NSH = 15             ' shots 0 - 15
Const NBU = 7              ' enemy bullets 0 - 7
Const NEXP = 9              ' explosions 0 - 9

' enemy types
Const E_DRONE = 1, E_DART = 2, E_SWOOP = 3, E_CRAWL = 4, E_TURRET = 5, E_SNAKE = 6, E_CARRIER = 7, E_MINE = 8, E_ORBIT = 9
Const E_MID = 10, E_BOSS = 11, E_SEG = 12

' the orb's states
Const O_NONE = 0, O_FRONT = 1, O_OUT = 2, O_FREE = 3, O_BACK = 4, O_REAR = 5

Dim g_intFrame As Integer, g_intA4 As Integer, g_intScr As Integer, g_intScx As Integer
Dim g_intWc As Integer, g_intWcell As Integer, g_intLen As Integer, g_intEvp As Integer
Dim g_intStage As Integer, g_intLoop As Integer, g_intLives As Integer, g_intJoy As Integer
Dim g_intLo As Integer, g_intHi As Integer, g_intHsLo As Integer, g_intHsHi As Integer, g_intScoreDirty As Integer
Dim g_intPx As Integer, g_intPy As Integer, g_intSpd As Integer, g_intPow As Integer, g_intTilt As Integer
Dim g_intOrb As Integer, g_intOx As Integer, g_intOy As Integer, g_intOdir As Integer
Dim g_intHeld As Integer, g_intCharge As Integer, g_intGauge As Integer, g_intZwas As Integer, g_intCool As Integer
Dim g_intDead As Integer, g_intInv As Integer, g_intWon As Integer, g_intTerrOn As Integer
Dim g_intWv As Integer, g_intWx As Integer, g_intWy As Integer, g_intWl As Integer, g_intWh As Integer
Dim g_intKeyWas As Integer, g_intSc As Integer
Dim g_arrCe(1023) As Byte, g_arrFl(1023) As Byte
Dim g_arrSK(15) As Integer, g_arrSX(15) As Integer, g_arrSY(15) As Integer, g_arrSVx(15) As Integer, g_arrSVy(15) As Integer
Dim g_arrEt(15) As Integer, g_arrEx(15) As Integer, g_arrEy(15) As Integer, g_arrEa(15) As Integer, g_arrEb(15) As Integer
Dim g_arrEc(15) As Integer, g_arrEh(15) As Integer, g_arrEw(15) As Integer, g_arrEg(15) As Integer, g_arrEp(15) As Integer
Dim g_arrEd(15) As Integer
Dim g_arrBk(7) As Integer, g_arrBx(7) As Integer, g_arrBy(7) As Integer, g_arrBvx(7) As Integer, g_arrBvy(7) As Integer
Dim g_arrPk(2) As Integer, g_arrPx(2) As Integer, g_arrPy(2) As Integer, g_arrPd(2) As Integer, g_arrPa(2) As Integer
Dim g_arrXk(9) As Integer, g_arrXx(9) As Integer, g_arrXy(9) As Integer, g_arrXf(9) As Integer, g_arrXc(9) As Integer, g_arrXs(9) As Integer
Dim g_arrTx(63) As Integer, g_arrTy(63) As Integer
Dim g_intTr As Integer, g_intSnake As Integer
Dim g_intBk As Integer, g_intBx As Integer, g_intBy As Integer, g_intBhp As Integer, g_intBt As Integer, g_intBd As Integer
Dim g_intBw As Integer, g_intBh As Integer, g_intBm As Integer, g_intBhit As Integer

Splash.Show 1                  ' Cyborg Unicorn, then DEVELOPED USING NTC BASIC
Splash.Show 2
Setup
Do
    Title
    Game
Loop

' ---------------------------------------------------------------- set up
Sub Setup()
    Tiles.Init
    Spr.Init
    GfxData.Load
    Sfx.Init
    Pals.Set 0
    Nx.Reg &H1B, 0 : Nx.Reg &H1B, 155 : Nx.Reg &H1B, 0 : Nx.Reg &H1B, 255   ' the tilemap's clip: 312 pixels across
    Nx.Seed 2026
    g_intHsLo = 0 : g_intHsHi = 0
End Sub

Sub Vsync()
    Frame
    Spr.Show
    Sfx.Update
    g_intFrame = g_intFrame + 1
    If (g_intFrame And 3) = 0 Then g_intA4 = g_intA4 + 1
    g_intJoy = Keys.Joystick(0)
End Sub

' a key press (not held): 1 the key was just pressed
Function Pressed(k As Integer) As Integer
    Dim intR As Integer
    intR = 0
    If Keys.Down(k) Then
        If g_intKeyWas = 0 Then intR = -1
        g_intKeyWas = k + 1
    ElseIf g_intKeyWas = k + 1 Then
        g_intKeyWas = 0
    End If
    Pressed = intR
End Function

' ---------------------------------------------------------------- the terrain
' the stage's heights into the two arrays, in pixels (ceiling's bottom, floor's top as a height)
Sub LoadStage(n As Integer)
    Dim intI As Integer, intB As Integer
    If n = 1 Then
        g_intLen = Stages.LEN1 : intB = Stages.TERR1 : g_intEvp = Stages.EV1
    Else
        g_intLen = Stages.LEN2 : intB = Stages.TERR2 : g_intEvp = Stages.EV2
    End If
    For intI = 0 To g_intLen - 1
        g_arrCe(intI) = Stages.B(intB + intI) * 8
        g_arrFl(intI) = Stages.B(intB + g_intLen + intI) * 8
    Next
    Pals.Set n - 1
End Sub

' one column of the world into a cell column of the map
Sub PutCol(w As Integer, cell As Integer)
    Dim intC As Integer, intF As Integer, intR As Integer, intY As Integer, intT As Integer, intH As Integer, intW As Integer
    intW = w
    If intW >= g_intLen Then intW = g_intLen - 1
    intC = g_arrCe(intW) : intF = 256 - g_arrFl(intW)
    intY = 0
    For intR = 0 To 31
        intT = 0
        If intY + 8 <= intC Then
            intH = (w * 3 + intR * 7) And 3
            If g_intStage = 1 Then
                intT = GfxData.T_ROCKA
                If intH = 0 Then intT = GfxData.T_ROCKB
                If intY + 8 = intC Then intT = GfxData.T_EDGEC
            Else
                intT = GfxData.T_PLATEB
                If intH = 0 Then intT = GfxData.T_PLATEA
                If intH = 1 And (w And 1) = 0 Then intT = GfxData.T_PLATEC
                If intY + 8 = intC Then intT = GfxData.T_FLIPC
            End If
        ElseIf intY >= intF Then
            intH = (w * 3 + intR * 7) And 3
            If g_intStage = 1 Then
                intT = GfxData.T_ROCKA
                If intH = 0 Then intT = GfxData.T_ROCKB
                If intY = intF Then intT = GfxData.T_EDGEF
            Else
                intT = GfxData.T_PLATEB
                If intH = 0 Then intT = GfxData.T_PLATEA
                If intH = 1 And (w And 1) = 0 Then intT = GfxData.T_PLATEC
                If intY = intF Then intT = GfxData.T_FLIPF
            End If
        Else
            intH = (w * 7 + intR * 13) And 127
            If intH = 0 Then intT = GfxData.T_STARA
            If intH = 1 Then intT = GfxData.T_STARB
            If intH = 2 Then intT = GfxData.T_STARC
        End If
        Tiles.Put cell, intR, intT
        intY = intY + 8
    Next
End Sub

' the whole screen from world column c0 on (the scroll set to match)
Sub BuildAll(c0 As Integer)
    Dim intI As Integer
    For intI = 0 To 39
        PutCol c0 + intI, intI
    Next
    g_intWc = c0 + 40 : g_intWcell = 0
    g_intScr = c0 * 8 : g_intScx = 0
    Tiles.Scroll 0, 0
End Sub

' a pixel-a-frame scroll: every 8 pixels the next column goes in, in the cell just left of the screen
Sub ScrollStep()
    g_intScr = g_intScr + 1
    g_intScx = g_intScx + 1
    If g_intScx >= 320 Then g_intScx = 0
    If (g_intScr And 7) = 0 Then
        PutCol g_intWc, g_intWcell
        g_intWc = g_intWc + 1
        g_intWcell = g_intWcell + 1
        If g_intWcell >= 40 Then g_intWcell = 0
    End If
    Tiles.Scroll g_intScx, 0
End Sub

' is a box (centre cx, cy, half sizes hw, hh) in the rock?
Function TerrHit(cx As Integer, cy As Integer, hw As Integer, hh As Integer) As Integer
    Dim intA As Integer, intB As Integer, intC As Integer, intK As Integer, intR As Integer
    intR = 0
    intA = g_intScr + cx - hw
    If intA < 0 Then intA = 0
    intB = g_intScr + cx + hw
    If intB < 0 Then intB = 0
    For intC = Fx.Shr3(intA) To Fx.Shr3(intB)
        intK = intC
        If intK >= g_intLen Then intK = g_intLen - 1
        If g_arrCe(intK) > cy - hh Then intR = -1
        If 256 - g_arrFl(intK) < cy + hh Then intR = -1
    Next
    TerrHit = intR
End Function

' ---------------------------------------------------------------- score
Sub AddScore(p As Integer)
    g_intLo = g_intLo + p
    If g_intLo >= 10000 Then
        g_intLo = g_intLo - 10000
        g_intHi = g_intHi + 1
    End If
    g_intScoreDirty = 1
End Sub

Sub ShowScore()
    Dim intV As Integer, intD As Integer, intK As Integer, intX As Integer
    ' 8 digits: hi (4) then lo (4); the last digit is always 0 (the points are tens): g_intLo * 10
    intX = 8
    For intK = 0 To 7
        Spr.Put SL_SCORE + intK, intX + intK * 9, 3, GfxData.S_DIGIT, GfxData.P_DIGIT
    Next
    DigitsAt g_intHi, 0
    DigitsAt g_intLo, 4
    Spr.Put SL_SCORE + 7, 8 + 7 * 9, 3, GfxData.S_DIGIT, GfxData.P_DIGIT
    g_intScoreDirty = 0
End Sub

Sub DigitsAt(v As Integer, first As Integer)
    Dim intV As Integer, intD As Integer, intK As Integer
    intV = v
    For intK = 0 To 3
        intD = 0
        If intK = 0 Then
            Do While intV >= 1000
                intV = intV - 1000 : intD = intD + 1
            Loop
        ElseIf intK = 1 Then
            Do While intV >= 100
                intV = intV - 100 : intD = intD + 1
            Loop
        ElseIf intK = 2 Then
            Do While intV >= 10
                intV = intV - 10 : intD = intD + 1
            Loop
        Else
            intD = intV
        End If
        Spr.Put SL_SCORE + first + intK, 8 + (first + intK) * 9, 3, GfxData.S_DIGIT + intD, GfxData.P_DIGIT
    Next
End Sub

Sub ShowLives()
    Dim intK As Integer
    For intK = 0 To 2
        If intK < g_intLives - 1 Then
            Spr.Put SL_LIFE + intK, 100 + intK * 18, 2, GfxData.S_LIFE, GfxData.P_LIFE
        Else
            Spr.Hide SL_LIFE + intK
        End If
    Next
End Sub

Sub ShowGauge()
    Dim intK As Integer, intF As Integer
    For intK = 0 To 7
        intF = 0
        If g_intCharge >= (intK + 1) * 6 Then intF = 1
        If g_intCharge >= 48 Then intF = 2
        Spr.Put SL_GAUGE + intK, 200 + intK * 12, 239, GfxData.S_GAUGE + intF, GfxData.P_GAUGE
    Next
    g_intGauge = g_intCharge
End Sub

' ---------------------------------------------------------------- the title
Sub Title()
    Dim intT As Integer, intK As Integer, intGo As Integer
    Spr.HideRange 0, 128
    Pals.Set 0
    Tiles.Scroll 0, 0
    Tiles.Fill 0
    For intK = 0 To 5
        Spr.Put intK, 40 + intK * 40, 36, GfxData.S_LOGO + intK, GfxData.P_LOGO + Spr.Scale2
    Next
    Tiles.Text 8, 12, "AN ORIGINAL SHOOT-'EM-UP"
    Tiles.Text 8, 15, "Q A O P    MOVE"
    Tiles.Text 8, 16, "SPACE      FIRE - HOLD: BEAM"
    Tiles.Text 8, 17, "Z          ORB OUT - ORB BACK"
    Tiles.Text 8, 19, "S SPEED   P POWER   O ORB"
    Tiles.Text 4, 29, "(C) 2026 CYBORG UNICORN PTY LTD"
    Tiles.Text 12, 22, "HI"
    PutNum 15, 22, g_intHsHi
    PutNum 19, 22, g_intHsLo
    Do While Keys.Down(Keys.KeySpace)
        Vsync
    Loop
    intGo = 0 : intT = 0
    Do While intGo = 0
        Vsync
        intT = intT + 1
        If (intT And 32) Then
            Tiles.Text 10, 25, "PRESS SPACE TO START"
        Else
            Tiles.Text 10, 25, "                    "
        End If
        If Keys.Down(Keys.KeySpace) Or Keys.Down(Keys.KeyEnter) Or (g_intJoy And Keys.JoyFire1) Then intGo = 1
    Loop
End Sub

Sub PutNum(x As Integer, y As Integer, v As Integer)
    Dim intV As Integer, intD As Integer
    intV = v : intD = 0
    Do While intV >= 1000
        intV = intV - 1000 : intD = intD + 1
    Loop
    Tiles.Put x, y, 48 + intD
    intD = 0
    Do While intV >= 100
        intV = intV - 100 : intD = intD + 1
    Loop
    Tiles.Put x + 1, y, 48 + intD
    intD = 0
    Do While intV >= 10
        intV = intV - 10 : intD = intD + 1
    Loop
    Tiles.Put x + 2, y, 48 + intD
    Tiles.Put x + 3, y, 48 + intV
End Sub

' text on the scrolled map: a banner at row 13, from the screen's cell 10 on
Sub Banner(s As String)
    Dim intI As Integer, intC As Integer, intCell As Integer
    intC = Fx.Shr3(g_intScx) + 10
    For intI = 1 To Len(s)
        intCell = intC + intI - 1
        If intCell >= 40 Then intCell = intCell - 40
        Tiles.Put intCell, 13, Asc(Mid$(s, intI, 1))
    Next
End Sub

Sub Delay(n As Integer)
    Dim intI As Integer
    For intI = 1 To n
        Vsync
    Next
End Sub

' ---------------------------------------------------------------- the game
Sub Game()
    Dim intR As Integer
    g_intLives = 3 : g_intLo = 0 : g_intHi = 0 : g_intStage = 1 : g_intLoop = 0
    g_intPow = 0 : g_intSpd = 0 : g_intOrb = O_NONE
    intR = 1
    Do While intR = 1
        intR = PlayStage(g_intStage)
        If intR = 1 Then
            g_intStage = g_intStage + 1
            If g_intStage > 2 Then
                g_intStage = 1 : g_intLoop = g_intLoop + 1
            End If
        End If
    Loop
    If g_intHi > g_intHsHi Or (g_intHi = g_intHsHi And g_intLo > g_intHsLo) Then
        g_intHsHi = g_intHi : g_intHsLo = g_intLo
    End If
End Sub

' the stage's checkpoint at or before world column c
Function Checkpoint(n As Integer, c As Integer) As Integer
    Dim intK As Integer, intR As Integer, intV As Integer, intBase As Integer
    If n = 1 Then intBase = Stages.CP1 Else intBase = Stages.CP2
    intR = 0 : intK = 0
    Do
        intV = Stages.W(intBase + intK)
        If intV = 30000 Then Exit Do
        If intV <= c Then intR = intV
        intK = intK + 1
    Loop
    Checkpoint = intR
End Function

Sub ClearAll()
    Dim intI As Integer
    For intI = 0 To NEN : g_arrEt(intI) = 0 : Next
    For intI = 0 To NSH : g_arrSK(intI) = 0 : Next
    For intI = 0 To NBU : g_arrBk(intI) = 0 : Next
    For intI = 0 To 2 : g_arrPk(intI) = 0 : Next
    For intI = 0 To NEXP : g_arrXk(intI) = 0 : Next
    g_intWv = 0 : g_intBk = 0 : g_intBd = 0 : g_intSnake = 0
    Spr.HideRange 0, 128
    g_intScoreDirty = 1
End Sub

' the event pointer to the first event from world column c on
Sub SeekEvents(n As Integer, c As Integer)
    Dim intK As Integer, intBase As Integer
    If n = 1 Then intBase = Stages.EV1 Else intBase = Stages.EV2
    intK = intBase
    Do While Stages.W(intK) < c
        intK = intK + 4
    Loop
    g_intEvp = intK
End Sub

Sub ResetShip()
    g_intPx = 60 : g_intPy = 128 : g_intTilt = 0
    g_intHeld = 0 : g_intCharge = 0 : g_intCool = 0 : g_intDead = 0 : g_intInv = 100
    g_intOrb = O_NONE
End Sub

' play stage n: 1 cleared, 0 game over
Function PlayStage(n As Integer) As Integer
    Dim intCp As Integer, intR As Integer
    g_intStage = n
    LoadStage n
    intCp = 0
    g_intPow = 0 : g_intSpd = 0
    ClearAll
    Tiles.Fill 0
    BuildAll 0
    SeekEvents n, 40
    ResetShip
    g_intTerrOn = 1 : g_intWon = 0
    ShowLives
    ShowScore
    ShowGauge
    Banner "STAGE"
    Delay 60
    BuildAll 0
    intR = -1
    Do While intR < 0
        Vsync
        Tick
        If g_intDead >= 100 Then
            ' the ship has been gone a while: a life lost
            g_intLives = g_intLives - 1
            If g_intLives <= 0 Then
                intR = 0
            Else
                intCp = Checkpoint(n, Fx.Shr3(g_intScr))
                ClearAll
                BuildAll intCp
                SeekEvents n, intCp + 40
                g_intPow = 0 : g_intSpd = 0
                ResetShip
                ShowLives
            End If
        End If
        If g_intWon > 150 Then intR = 1
    Loop
    If intR = 0 Then
        Banner "GAME OVER"
        Delay 150
    Else
        Banner "STAGE CLEAR"
        Delay 120
    End If
    PlayStage = intR
End Function

' one frame of the game
Sub Tick()
    Dim intI As Integer
    g_intSc = 0
    If g_intBk = 0 And g_intWon = 0 Then
        ScrollStep
        g_intSc = 1
    End If
    If g_intWon > 0 Then g_intWon = g_intWon + 1
    Spawns
    If g_intDead = 0 Then
        Ship
    Else
        g_intDead = g_intDead + 1
    End If
    Shots
    Enemies
    If g_intBk > 0 Then Boss
    Bullets
    Pickups
    Booms
    Hud
End Sub

' ---------------------------------------------------------------- the ship
Sub Ship()
    Dim intS As Integer, intFire As Integer, intZ As Integer, intTop As Integer
    intS = 2 + g_intSpd
    g_intTilt = 0
    If Keys.Down(Keys.KeyQ) Or (g_intJoy And Keys.JoyUp) Then g_intPy = g_intPy - intS : g_intTilt = 1
    If Keys.Down(Keys.KeyA) Or (g_intJoy And Keys.JoyDown) Then g_intPy = g_intPy + intS : g_intTilt = 2
    If Keys.Down(Keys.KeyO) Or (g_intJoy And Keys.JoyLeft) Then g_intPx = g_intPx - intS
    If Keys.Down(Keys.KeyP) Or (g_intJoy And Keys.JoyRight) Then g_intPx = g_intPx + intS
    If g_intPx < 24 Then g_intPx = 24
    If g_intPx > 292 Then g_intPx = 292
    If g_intPy < 20 Then g_intPy = 20
    If g_intPy > 236 Then g_intPy = 236
    If g_intInv > 0 Then g_intInv = g_intInv - 1
    If g_intCool > 0 Then g_intCool = g_intCool - 1
    ' fire / charge
    intFire = 0
    If Keys.Down(Keys.KeySpace) Or (g_intJoy And Keys.JoyFire1) Then intFire = 1
    If intFire = 1 Then
        g_intHeld = g_intHeld + 1
        If g_intHeld = 1 Then FireShots
        If g_intHeld > 14 And g_intCharge < 48 Then
            g_intCharge = g_intCharge + 1
            If g_intCharge = 10 Or g_intCharge = 20 Or g_intCharge = 30 Or g_intCharge = 40 Then Sfx.Play 1, 240 - g_intCharge * 3, -2, 8, 6, 0
        End If
    Else
        If g_intCharge >= 10 And g_intWv = 0 Then FireWave
        g_intHeld = 0 : g_intCharge = 0
    End If
    ' the orb
    intZ = 0
    If Keys.Down(Keys.KeyZ) Or (g_intJoy And Keys.JoyFire2) Then intZ = 1
    If intZ = 1 And g_intZwas = 0 Then OrbButton
    g_intZwas = intZ
    OrbMove
    ' terrain and being hurt
    If g_intInv = 0 Then
        If TerrHit(g_intPx, g_intPy, 12, 5) Then Kill
    End If
    If g_intDead > 0 Then Exit Sub
    ' the sprites
    Spr.Put SL_SHIP, g_intPx - 16, g_intPy - 8, GfxData.S_SHIP + g_intTilt * 2, GfxData.P_SHIP
    Spr.Put SL_SHIP + 1, g_intPx, g_intPy - 8, GfxData.S_SHIP + g_intTilt * 2 + 1, GfxData.P_SHIP
    Spr.Put SL_FLAME, g_intPx - 26, g_intPy - 8, GfxData.S_FLAME + (g_intA4 And 1), GfxData.P_FLAME
    If g_intInv > 0 And (g_intFrame And 2) Then
        Spr.Hide SL_SHIP : Spr.Hide SL_SHIP + 1
    End If
    If g_intCharge > 3 Then
        intTop = 0
        If g_intCharge >= 10 Then intTop = 1
        If g_intCharge >= 20 Then intTop = 2
        If g_intCharge >= 30 Then intTop = 3
        Spr.Put SL_GLOW, g_intPx + 14, g_intPy - 8, GfxData.S_GLOW + intTop, GfxData.P_GLOW
    Else
        Spr.Hide SL_GLOW
    End If
    If g_intCharge <> g_intGauge Then ShowGauge
End Sub

Sub NewShot(x As Integer, y As Integer, vx As Integer, vy As Integer, k As Integer)
    Dim intI As Integer
    For intI = 0 To NSH
        If g_arrSK(intI) = 0 Then
            g_arrSK(intI) = k : g_arrSX(intI) = x : g_arrSY(intI) = y : g_arrSVx(intI) = vx : g_arrSVy(intI) = vy
            Exit For
        End If
    Next
End Sub

Sub FireShots()
    Sfx.Play 0, 40, 4, 9, 6, 0
    If g_intPow = 0 Then
        NewShot g_intPx + 20, g_intPy, 8, 0, 1
    ElseIf g_intPow = 1 Then
        NewShot g_intPx + 20, g_intPy - 4, 8, 0, 1
        NewShot g_intPx + 20, g_intPy + 4, 8, 0, 1
    Else
        NewShot g_intPx + 20, g_intPy, 8, 0, 1
        NewShot g_intPx + 16, g_intPy - 4, 6, -3, 2
        NewShot g_intPx + 16, g_intPy + 4, 6, 3, 3
    End If
    If g_intOrb = O_FRONT Or g_intOrb = O_FREE Then NewShot g_intOx + 8, g_intOy, 8, 0, 4
    If g_intOrb = O_REAR Then NewShot g_intOx - 8, g_intOy, -8, 0, 5
End Sub

Sub FireWave()
    Dim intL As Integer
    intL = 1
    If g_intCharge >= 20 Then intL = 2
    If g_intCharge >= 30 Then intL = 3
    If g_intCharge >= 40 Then intL = 4
    g_intWv = 1 : g_intWx = g_intPx + 16 : g_intWy = g_intPy : g_intWl = intL + 1
    g_intWh = 8
    If intL >= 3 Then g_intWh = 16
    Sfx.Play 1, 400, -12, 15, 24, 0
End Sub

Sub OrbButton()
    If g_intOrb = O_FRONT Then
        g_intOrb = O_OUT
        Sfx.Play 1, 100, 6, 10, 10, 0
    ElseIf g_intOrb = O_OUT Or g_intOrb = O_FREE Then
        g_intOrb = O_BACK
        Sfx.Play 1, 180, -5, 10, 10, 0
    ElseIf g_intOrb = O_REAR Then
        g_intOrb = O_FRONT
    End If
End Sub

Sub OrbMove()
    Dim intDx As Integer, intDy As Integer
    If g_intOrb = O_NONE Then
        Spr.Hide SL_ORB
        Exit Sub
    End If
    If g_intOrb = O_FRONT Then
        g_intOx = g_intPx + 26 : g_intOy = g_intPy
    ElseIf g_intOrb = O_REAR Then
        g_intOx = g_intPx - 26 : g_intOy = g_intPy
    ElseIf g_intOrb = O_OUT Then
        g_intOx = g_intOx + 6
        If g_intOx > 296 Or TerrHit(g_intOx, g_intOy, 6, 6) Then g_intOrb = O_FREE
    ElseIf g_intOrb = O_BACK Then
        intDx = g_intPx - g_intOx : intDy = g_intPy - g_intOy
        If intDx > 5 Then g_intOx = g_intOx + 5 Else If intDx < -5 Then g_intOx = g_intOx - 5 Else g_intOx = g_intPx
        If intDy > 4 Then g_intOy = g_intOy + 4 Else If intDy < -4 Then g_intOy = g_intOy - 4 Else g_intOy = g_intPy
        If Abs(intDx) < 28 And Abs(intDy) < 6 Then
            If g_intOx >= g_intPx Then g_intOrb = O_FRONT Else g_intOrb = O_REAR
        End If
    End If
    Spr.Put SL_ORB, g_intOx - 8, g_intOy - 8, GfxData.S_ORB + (g_intA4 And 3), GfxData.P_ORB
End Sub

' the ship is hit
Sub Kill()
    If g_intDead > 0 Then Exit Sub
    g_intDead = 1
    Boom g_intPx, g_intPy, 1
    Sfx.Play 2, 1200, 25, 15, 50, 1
    Spr.Hide SL_SHIP : Spr.Hide SL_SHIP + 1 : Spr.Hide SL_FLAME : Spr.Hide SL_GLOW : Spr.Hide SL_ORB
    g_intOrb = O_NONE : g_intCharge = 0 : g_intHeld = 0
End Sub

' ---------------------------------------------------------------- the ship's shots and the wave
Sub Shots()
    Dim intI As Integer, intP As Integer, intF As Integer, intE As Integer, intK As Integer, intRem As Integer
    For intI = 0 To NSH
        If g_arrSK(intI) > 0 Then
            g_arrSX(intI) = g_arrSX(intI) + g_arrSVx(intI)
            g_arrSY(intI) = g_arrSY(intI) + g_arrSVy(intI)
            intRem = 0
            If g_arrSX(intI) > 316 Or g_arrSX(intI) < 4 Or g_arrSY(intI) < 12 Or g_arrSY(intI) > 244 Then intRem = 1
            If intRem = 0 Then
                If TerrHit(g_arrSX(intI), g_arrSY(intI), 3, 2) Then intRem = 1
            End If
            If intRem = 0 Then
                ' enemies
                For intE = 0 To NEN
                    If g_arrEt(intE) > 0 And intRem = 0 Then
                        If Abs(g_arrEx(intE) - g_arrSX(intI)) < g_arrEw(intE) + 5 And Abs(g_arrEy(intE) - g_arrSY(intI)) < g_arrEh(intE) + 4 Then
                            Hurt intE, 1
                            intRem = 1
                        End If
                    End If
                Next
                If intRem = 0 And g_intBk > 0 Then
                    If Abs(g_intBx - g_arrSX(intI)) < g_intBw + 5 And Abs(g_intBy - g_arrSY(intI)) < g_intBh + 4 Then
                        HurtBoss 1
                        intRem = 1
                    End If
                End If
            End If
            If intRem = 1 Then
                g_arrSK(intI) = 0
                Spr.Hide SL_SHOT + intI
            Else
                intK = g_arrSK(intI)
                If intK = 1 Then
                    Spr.Put SL_SHOT + intI, g_arrSX(intI) - 8, g_arrSY(intI) - 8, GfxData.S_SHOT, GfxData.P_SHOT
                ElseIf intK = 2 Then
                    Spr.Put SL_SHOT + intI, g_arrSX(intI) - 8, g_arrSY(intI) - 8, GfxData.S_SHOTD, GfxData.P_SHOTD + Spr.MirrorY
                ElseIf intK = 3 Then
                    Spr.Put SL_SHOT + intI, g_arrSX(intI) - 8, g_arrSY(intI) - 8, GfxData.S_SHOTD, GfxData.P_SHOTD
                ElseIf intK = 4 Then
                    Spr.Put SL_SHOT + intI, g_arrSX(intI) - 8, g_arrSY(intI) - 8, GfxData.S_SHOTO, GfxData.P_SHOTO
                Else
                    Spr.Put SL_SHOT + intI, g_arrSX(intI) - 8, g_arrSY(intI) - 8, GfxData.S_SHOTO, GfxData.P_SHOTO + Spr.MirrorX
                End If
            End If
        End If
    Next
    If g_intWv > 0 Then
        g_intWx = g_intWx + 6
        If g_intWx > 330 Then
            g_intWv = 0
            For intI = 0 To 4 : Spr.Hide SL_WAVE + intI : Next
        Else
            If (g_intFrame And 3) = 0 Then
                For intE = 0 To NEN
                    If g_arrEt(intE) > 0 Then
                        If Abs(g_arrEy(intE) - g_intWy) < g_arrEh(intE) + g_intWh And g_arrEx(intE) + g_arrEw(intE) > g_intWx - 16 * (g_intWl - 1) And g_arrEx(intE) - g_arrEw(intE) < g_intWx + 16 Then
                            Hurt intE, g_intWl * 2 - 2
                        End If
                    End If
                Next
                If g_intBk > 0 Then
                    If Abs(g_intBy - g_intWy) < g_intBh + g_intWh And g_intBx + g_intBw > g_intWx - 16 * (g_intWl - 1) And g_intBx - g_intBw < g_intWx + 16 Then
                        HurtBoss g_intWl * 2 - 2
                    End If
                End If
            End If
            For intI = 0 To g_intWl - 1
                intF = 0
                If g_intWh > 8 Then intF = Spr.Scale2Y
                intP = GfxData.S_WAVEB
                If intI = 0 Then intP = GfxData.S_WAVEH
                If g_intWx - 16 * intI >= 0 Then
                    Spr.Put SL_WAVE + intI, g_intWx - 16 * intI, g_intWy - g_intWh, intP, GfxData.P_WAVEH + intF
                Else
                    Spr.Hide SL_WAVE + intI
                End If
            Next
        End If
    End If
End Sub

' ---------------------------------------------------------------- explosions, pickups, score
Sub Boom(x As Integer, y As Integer, big As Integer)
    Dim intI As Integer
    For intI = 0 To NEXP
        If g_arrXk(intI) = 0 Then
            g_arrXk(intI) = 1 : g_arrXx(intI) = x : g_arrXy(intI) = y : g_arrXf(intI) = 0 : g_arrXc(intI) = 3 : g_arrXs(intI) = big
            Exit For
        End If
    Next
End Sub

Sub Booms()
    Dim intI As Integer
    For intI = 0 To NEXP
        If g_arrXk(intI) > 0 Then
            g_arrXc(intI) = g_arrXc(intI) - 1
            If g_arrXc(intI) < 0 Then
                g_arrXc(intI) = 3
                g_arrXf(intI) = g_arrXf(intI) + 1
            End If
            If g_arrXf(intI) > 3 Then
                g_arrXk(intI) = 0
                Spr.Hide SL_BOOM + intI
            ElseIf g_arrXs(intI) > 0 Then
                Spr.Put SL_BOOM + intI, g_arrXx(intI) - 16, g_arrXy(intI) - 16, GfxData.S_BOOM + g_arrXf(intI), GfxData.P_BOOM + Spr.Scale2
            Else
                Spr.Put SL_BOOM + intI, g_arrXx(intI) - 8, g_arrXy(intI) - 8, GfxData.S_BOOM + g_arrXf(intI), GfxData.P_BOOM
            End If
        End If
    Next
End Sub

Sub Drop(x As Integer, y As Integer, k As Integer)
    Dim intI As Integer
    For intI = 0 To 2
        If g_arrPk(intI) = 0 Then
            g_arrPk(intI) = k : g_arrPx(intI) = x : g_arrPy(intI) = y : g_arrPd(intI) = 1 : g_arrPa(intI) = 0
            Exit For
        End If
    Next
End Sub

Sub Pickups()
    Dim intI As Integer, intP As Integer, intQ As Integer
    For intI = 0 To 2
        If g_arrPk(intI) > 0 Then
            g_arrPx(intI) = g_arrPx(intI) - 1
            g_arrPa(intI) = g_arrPa(intI) + 1
            If (g_arrPa(intI) And 31) = 0 Then g_arrPd(intI) = -g_arrPd(intI)
            g_arrPy(intI) = g_arrPy(intI) + g_arrPd(intI)
            If g_arrPx(intI) < 4 Then
                g_arrPk(intI) = 0
                Spr.Hide SL_PICK + intI
            ElseIf g_intDead = 0 And Abs(g_arrPx(intI) - g_intPx) < 22 And Abs(g_arrPy(intI) - g_intPy) < 14 Then
                intQ = g_arrPk(intI)
                If intQ = 1 Then
                    If g_intSpd < 3 Then g_intSpd = g_intSpd + 1
                ElseIf intQ = 2 Then
                    If g_intPow < 2 Then g_intPow = g_intPow + 1
                Else
                    If g_intOrb = O_NONE Then
                        g_intOrb = O_FRONT
                    End If
                End If
                AddScore 50
                Sfx.Play 1, 150, -8, 12, 14, 0
                g_arrPk(intI) = 0
                Spr.Hide SL_PICK + intI
            Else
                intP = GfxData.S_PUS
                If g_arrPk(intI) = 2 Then intP = GfxData.S_PUP
                If g_arrPk(intI) = 3 Then intP = GfxData.S_PUO
                Spr.Put SL_PICK + intI, g_arrPx(intI) - 8, g_arrPy(intI) - 8, intP + (g_intA4 And 1), GfxData.P_PUS
            End If
        End If
    Next
End Sub

' ---------------------------------------------------------------- the HUD
Sub Hud()
    If g_intScoreDirty Then ShowScore
End Sub

' ---------------------------------------------------------------- enemy bullets
Sub NewBullet(x As Integer, y As Integer, vx As Integer, vy As Integer)
    Dim intI As Integer
    For intI = 0 To NBU
        If g_arrBk(intI) = 0 Then
            g_arrBk(intI) = 1 : g_arrBx(intI) = x : g_arrBy(intI) = y : g_arrBvx(intI) = vx : g_arrBvy(intI) = vy
            Exit For
        End If
    Next
End Sub

' a bullet from x, y at the ship (3 speeds over 2 axes)
Sub Aim(x As Integer, y As Integer, spd As Integer)
    Dim intDx As Integer, intDy As Integer, intVx As Integer, intVy As Integer
    If g_intDead > 0 Then Exit Sub
    intDx = g_intPx - x : intDy = g_intPy - y
    intVx = spd : intVy = spd
    If intDx < 0 Then intVx = -spd
    If intDy < 0 Then intVy = -spd
    If Abs(intDy) * 3 < Abs(intDx) Then intVy = 0
    If Abs(intDx) * 3 < Abs(intDy) Then intVx = 0
    NewBullet x, y, intVx, intVy
End Sub

Sub Bullets()
    Dim intI As Integer, intRem As Integer
    For intI = 0 To NBU
        If g_arrBk(intI) > 0 Then
            g_arrBx(intI) = g_arrBx(intI) + g_arrBvx(intI)
            g_arrBy(intI) = g_arrBy(intI) + g_arrBvy(intI)
            intRem = 0
            If g_arrBx(intI) < 4 Or g_arrBx(intI) > 318 Or g_arrBy(intI) < 8 Or g_arrBy(intI) > 250 Then intRem = 1
            If intRem = 0 And g_intOrb > O_NONE Then
                If Abs(g_arrBx(intI) - g_intOx) < 11 And Abs(g_arrBy(intI) - g_intOy) < 11 Then intRem = 1
            End If
            If intRem = 0 And g_intDead = 0 And g_intInv = 0 Then
                If Abs(g_arrBx(intI) - g_intPx) < 12 And Abs(g_arrBy(intI) - g_intPy) < 6 Then
                    intRem = 1
                    Kill
                End If
            End If
            If intRem = 1 Then
                g_arrBk(intI) = 0
                Spr.Hide SL_EBUL + intI
            Else
                Spr.Put SL_EBUL + intI, g_arrBx(intI) - 8, g_arrBy(intI) - 8, GfxData.S_EBUL + (g_intA4 And 1), GfxData.P_EBUL
            End If
        End If
    Next
End Sub

' ---------------------------------------------------------------- enemies
Sub NewEnemy(t As Integer, x As Integer, y As Integer, a As Integer)
    Dim intI As Integer, intE As Integer, intCol As Integer, intN As Integer
    intE = -1
    For intI = 0 To NEN
        If g_arrEt(intI) = 0 And intE < 0 Then intE = intI
    Next
    If intE < 0 Then Exit Sub
    g_arrEt(intE) = t : g_arrEx(intE) = x : g_arrEy(intE) = y : g_arrEa(intE) = 0 : g_arrEb(intE) = y : g_arrEc(intE) = a : g_arrEd(intE) = 0
    g_arrEw(intE) = 7 : g_arrEh(intE) = 6 : g_arrEg(intE) = 2 : g_arrEp(intE) = 10
    If t = E_DRONE Then
        g_arrEg(intE) = 2 + g_intLoop
    ElseIf t = E_DART Then
        g_arrEg(intE) = 1 : g_arrEh(intE) = 5
    ElseIf t = E_SWOOP Then
        g_arrEg(intE) = 2 : g_arrEp(intE) = 20
        If a = 0 Then g_arrEy(intE) = 20 Else g_arrEy(intE) = 236
    ElseIf t = E_CRAWL Or t = E_TURRET Then
        intCol = Fx.Shr3(g_intScr + x)
        If intCol >= g_intLen Then intCol = g_intLen - 1
        If a = 0 Then g_arrEy(intE) = 256 - g_arrFl(intCol) - 8 Else g_arrEy(intE) = g_arrCe(intCol) + 8
        g_arrEg(intE) = 3 + g_intLoop : g_arrEp(intE) = 15
        g_arrEb(intE) = 40 + Rnd(60)
    ElseIf t = E_SNAKE Then
        g_arrEg(intE) = 6 : g_arrEp(intE) = 50 : g_arrEh(intE) = 7
        For intN = 0 To 63
            g_arrTx(intN) = x : g_arrTy(intN) = y
        Next
        g_intTr = 0 : g_intSnake = 1
        For intN = 1 To 5
            NewSeg intE, intN
        Next
    ElseIf t = E_CARRIER Then
        g_arrEw(intE) = 16 : g_arrEg(intE) = 8 : g_arrEp(intE) = 30 : g_arrEh(intE) = 6
    ElseIf t = E_MINE Then
        g_arrEg(intE) = 2 : g_arrEw(intE) = 6
    ElseIf t = E_ORBIT Then
        g_arrEg(intE) = 2 : g_arrEp(intE) = 20 : g_arrEh(intE) = 5
        g_arrEb(intE) = 20
    End If
End Sub

Sub NewSeg(head As Integer, k As Integer)
    Dim intI As Integer, intE As Integer
    intE = -1
    For intI = 0 To NEN
        If g_arrEt(intI) = 0 And intE < 0 Then intE = intI
    Next
    If intE < 0 Then Exit Sub
    g_arrEt(intE) = E_SEG : g_arrEx(intE) = g_arrEx(head) : g_arrEy(intE) = g_arrEy(head) : g_arrEa(intE) = 0
    g_arrEb(intE) = k : g_arrEc(intE) = head : g_arrEw(intE) = 6 : g_arrEh(intE) = 6 : g_arrEg(intE) = 3 : g_arrEp(intE) = 5
End Sub

Sub Hurt(e As Integer, d As Integer)
    Dim intE As Integer
    intE = e
    g_arrEg(intE) = g_arrEg(intE) - d
    If g_arrEg(intE) <= 0 Then
        KillEnemy intE
    Else
        Sfx.Play 2, 300, 10, 6, 4, 1
    End If
End Sub

Sub RemoveEnemy(e As Integer)
    g_arrEt(e) = 0
    Spr.Hide SL_ENM + e * 2
    Spr.Hide SL_ENM + e * 2 + 1
End Sub

Sub KillEnemy(e As Integer)
    Dim intT As Integer, intI As Integer, intE As Integer
    intE = e
    intT = g_arrEt(intE)
    Boom g_arrEx(intE), g_arrEy(intE), 0
    Sfx.Play 2, 500, 12, 12, 14, 1
    AddScore g_arrEp(intE)
    If intT = E_CARRIER Then Drop g_arrEx(intE), g_arrEy(intE), g_arrEc(intE) + 1
    If intT = E_SNAKE Then
        For intI = 0 To NEN
            If g_arrEt(intI) = E_SEG Then
                Boom g_arrEx(intI), g_arrEy(intI), 0
                AddScore 5
                RemoveEnemy intI
            End If
        Next
        g_intSnake = 0
    End If
    RemoveEnemy intE
End Sub

Sub Spawns()
    Dim intLim As Integer, intC As Integer, intT As Integer
    intLim = Fx.Shr3(g_intScr + 326)
    Do
        intC = Stages.W(g_intEvp)
        If intC > intLim Then Exit Do
        intT = Stages.W(g_intEvp + 1)
        If intT >= E_MID Then
            If g_intBk = 0 Then StartBoss intT, Stages.W(g_intEvp + 3)
        Else
            NewEnemy intT, intC * 8 - g_intScr + 8, Stages.W(g_intEvp + 2), Stages.W(g_intEvp + 3)
        End If
        g_intEvp = g_intEvp + 4
    Loop
End Sub

Sub Enemies()
    Dim intE As Integer, intT As Integer, intX As Integer, intY As Integer, intF As Integer, intA As Integer, intK As Integer, intCol As Integer
    Dim intP As Integer, intFl As Integer
    ' the snake's trail
    If g_intSnake > 0 Then
        g_intTr = g_intTr + 1
    End If
    For intE = 0 To NEN
        intT = g_arrEt(intE)
        If intT > 0 Then
            g_arrEa(intE) = g_arrEa(intE) + 1
            intA = g_arrEa(intE)
            intX = g_arrEx(intE) : intY = g_arrEy(intE)
            intFl = 0
            If intT = E_DRONE Then
                intX = intX - 1 - (intA And 1)
                intY = g_arrEb(intE) + Stages.W(Stages.SINE + (intA And 63))
                If g_intLoop > 0 And intA = 50 Then Aim intX, intY, 2
            ElseIf intT = E_DART Then
                intX = intX - 4
            ElseIf intT = E_SWOOP Then
                intX = intX - 2
                If (intA And 1) = 0 And g_arrEd(intE) < 63 Then g_arrEd(intE) = g_arrEd(intE) + 1
                If g_arrEc(intE) = 0 Then
                    intY = 20 + Stages.W(Stages.DIVE + g_arrEd(intE))
                Else
                    intY = 236 - Stages.W(Stages.DIVE + g_arrEd(intE))
                End If
                If intA = 40 Then Aim intX, intY, 2
            ElseIf intT = E_CRAWL Then
                intX = intX - g_intSc
                If (intA And 1) = 0 Then intX = intX - 1
                intCol = Fx.Shr3(g_intScr + intX)
                If intCol >= g_intLen Then intCol = g_intLen - 1
                If intCol < 0 Then intCol = 0
                If g_arrEc(intE) = 0 Then
                    intY = 256 - g_arrFl(intCol) - 8
                Else
                    intY = g_arrCe(intCol) + 8 : intFl = Spr.MirrorY
                End If
            ElseIf intT = E_TURRET Then
                intX = intX - g_intSc
                If g_arrEc(intE) = 1 Then intFl = Spr.MirrorY
                g_arrEb(intE) = g_arrEb(intE) - 1
                If g_arrEb(intE) <= 0 And intX > 24 And intX < 300 Then
                    Aim intX, intY, 2 + g_intLoop
                    g_arrEb(intE) = 110 - g_intLoop * 25
                    Sfx.Play 0, 200, 5, 8, 6, 0
                End If
                ' the barrel's aim
                intK = 2
                If g_intPx < intX - 24 Then
                    intK = 0
                    If g_arrEc(intE) = 0 And intY - g_intPy > intX - g_intPx Then intK = 1
                    If g_arrEc(intE) = 1 And g_intPy - intY > intX - g_intPx Then intK = 1
                ElseIf g_intPx > intX + 24 Then
                    intK = 4
                    If g_arrEc(intE) = 0 And intY - g_intPy > g_intPx - intX Then intK = 3
                    If g_arrEc(intE) = 1 And g_intPy - intY > g_intPx - intX Then intK = 3
                End If
                g_arrEd(intE) = intK
            ElseIf intT = E_SNAKE Then
                intX = intX - 2
                intY = g_arrEb(intE) + Stages.W(Stages.SINE + (intA And 63))
                g_arrTx(g_intTr And 63) = intX : g_arrTy(g_intTr And 63) = intY
            ElseIf intT = E_SEG Then
                If g_arrEt(g_arrEc(intE)) <> E_SNAKE Then
                    RemoveEnemy intE
                    intT = 0
                Else
                    intK = (g_intTr - g_arrEb(intE) * 5) And 63
                    intX = g_arrTx(intK) : intY = g_arrTy(intK)
                End If
            ElseIf intT = E_CARRIER Then
                intX = intX - 1
                If (intA And 1) = 0 Then g_arrEd(intE) = g_arrEd(intE) + 1
                intY = g_arrEb(intE) + Stages.W(Stages.SINE + (g_arrEd(intE) And 63)) \ 2
            ElseIf intT = E_MINE Then
                intX = intX - 1
                If (intA And 3) = 0 Then
                    If g_intPy > intY Then intY = intY + 1 Else If g_intPy < intY Then intY = intY - 1
                End If
            ElseIf intT = E_ORBIT Then
                intX = intX - 2
                intY = g_arrEb(intE) + 100 + Stages.W(Stages.SINE + ((intA * 2) And 63))
                If (intA And 31) = 0 Then NewBullet intX - 8, intY, -3, 0
            End If
            If intT > 0 Then
                If intX < -20 Or intY < 4 Or intY > 262 Then
                    RemoveEnemy intE
                Else
                    g_arrEx(intE) = intX : g_arrEy(intE) = intY
                    ' being hit by the ship / the orb
                    If g_intDead = 0 And g_intInv = 0 Then
                        If Abs(intX - g_intPx) < g_arrEw(intE) + 12 And Abs(intY - g_intPy) < g_arrEh(intE) + 6 Then Kill
                    End If
                    If g_intOrb > O_NONE And (g_intFrame And 3) = 0 Then
                        If Abs(intX - g_intOx) < g_arrEw(intE) + 8 And Abs(intY - g_intOy) < g_arrEh(intE) + 8 Then Hurt intE, 1
                    End If
                End If
                ' the sprites (the enemy may have just died)
                If g_arrEt(intE) > 0 Then
                    intT = g_arrEt(intE)
                    If intX < 0 Then
                        Spr.Hide SL_ENM + intE * 2 : Spr.Hide SL_ENM + intE * 2 + 1
                    ElseIf intT = E_DRONE Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_DRONE + (g_intA4 And 1), GfxData.P_DRONE
                    ElseIf intT = E_DART Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_DART, GfxData.P_DART
                    ElseIf intT = E_SWOOP Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_SWOOP + (g_intA4 And 1), GfxData.P_SWOOP
                    ElseIf intT = E_CRAWL Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_CRAWL + (g_intA4 And 1), GfxData.P_CRAWL + intFl
                    ElseIf intT = E_TURRET Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_TURRET + g_arrEd(intE), GfxData.P_TURRET + intFl
                    ElseIf intT = E_SNAKE Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_HEAD, GfxData.P_HEAD + Spr.MirrorX
                    ElseIf intT = E_SEG Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_SEG + (g_intA4 And 1), GfxData.P_SEG
                    ElseIf intT = E_CARRIER Then
                        intP = GfxData.S_CARRIER + (g_intA4 And 1) * 2
                        Spr.Put SL_ENM + intE * 2, intX - 16, intY - 8, intP, GfxData.P_CARRIER
                        Spr.Put SL_ENM + intE * 2 + 1, intX, intY - 8, intP + 1, GfxData.P_CARRIER
                    ElseIf intT = E_MINE Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_MINE + (g_intA4 And 1), GfxData.P_MINE
                    ElseIf intT = E_ORBIT Then
                        Spr.Put SL_ENM + intE * 2, intX - 8, intY - 8, GfxData.S_ORBIT + (g_intA4 And 1), GfxData.P_ORBIT
                    End If
                End If
            End If
        End If
    Next
End Sub

' ---------------------------------------------------------------- the bosses
' kind: E_MID (the guardian), E_BOSS with a = 1 the colossus, 2 the engine
Sub StartBoss(t As Integer, a As Integer)
    g_intBd = 0 : g_intBt = 0 : g_intBhit = 0 : g_intBm = 60
    g_intBx = 360 : g_intBy = 128
    If t = E_MID Then
        g_intBk = 1 : g_intBw = 14 : g_intBh = 14 : g_intBhp = 40 + g_intLoop * 12
    ElseIf a = 1 Then
        g_intBk = 2 : g_intBw = 30 : g_intBh = 22 : g_intBhp = 110 + g_intLoop * 30
    Else
        g_intBk = 3 : g_intBw = 30 : g_intBh = 22 : g_intBhp = 140 + g_intLoop * 30
    End If
    g_intBm = 80
End Sub

Sub HurtBoss(d As Integer)
    Dim intT As Integer
    If g_intBd > 0 Or g_intBx > 272 Then Exit Sub
    g_intBhp = g_intBhp - d
    g_intBhit = 2
    If g_intBhp <= 0 Then
        g_intBd = 1
        Sfx.Play 2, 1000, 20, 15, 40, 1
    Else
        Sfx.Play 2, 250, 8, 6, 4, 1
    End If
    AddScore 1
End Sub

Sub BossGone()
    Dim intI As Integer
    For intI = 0 To 11
        Spr.Hide SL_BOSS + intI
    Next
    If g_intBk = 1 Then
        AddScore 200
    Else
        AddScore 500
        g_intWon = 1
    End If
    g_intBk = 0
End Sub

Sub Boss()
    Dim intW As Integer, intH As Integer, intCx As Integer, intCy As Integer, intP As Integer, intT As Integer, intPal As Integer, intTx As Integer
    Dim intFast As Integer
    g_intBt = g_intBt + 1
    intTx = 262
    If g_intBk = 1 Then intTx = 270
    If g_intBd > 0 Then
        ' dying: blasts all over it
        g_intBd = g_intBd + 1
        If (g_intBd And 3) = 0 Then
            Boom g_intBx - g_intBw + Rnd(g_intBw * 2), g_intBy - g_intBh + Rnd(g_intBh * 2), g_intBd And 8
            Sfx.Play 2, 600 + Rnd(500), 15, 12, 10, 1
        End If
        If g_intBd > 80 Then
            Boom g_intBx, g_intBy, 1
            Sfx.Play 2, 1500, 30, 15, 50, 1
            BossGone
            Exit Sub
        End If
    ElseIf g_intBx > intTx Then
        g_intBx = g_intBx - 1
    Else
        intFast = 0
        If g_intBhp * 2 < 60 Then intFast = 1
        If g_intBk = 1 Then
            g_intBy = 128 + Stages.W(Stages.SINE + (g_intBt And 63))
            g_intBm = g_intBm - 1
            If g_intBm <= 0 Then
                Aim g_intBx - 14, g_intBy, 2 + g_intLoop
                g_intBm = 55 - intFast * 20
                Sfx.Play 0, 200, 5, 8, 6, 0
            End If
        ElseIf g_intBk = 2 Then
            g_intBy = 128 + Stages.W(Stages.SINE + ((g_intBt \ 2) And 63))
            g_intBm = g_intBm - 1
            If g_intBm <= 0 Then
                NewBullet g_intBx - 34, g_intBy, -3, -2
                NewBullet g_intBx - 34, g_intBy, -3, 0
                NewBullet g_intBx - 34, g_intBy, -3, 2
                If intFast Then
                    NewBullet g_intBx - 34, g_intBy, -3, -1
                    NewBullet g_intBx - 34, g_intBy, -3, 1
                End If
                Aim g_intBx - 34, g_intBy, 3
                g_intBm = 70 - intFast * 25
                Sfx.Play 0, 150, 6, 10, 8, 0
            End If
            If (g_intBt Mod 200) = 199 Then NewEnemy E_DART, g_intBx - 20, g_intBy, 0
        Else
            g_intBy = 128 + Stages.W(Stages.SINE + ((g_intBt * 2) And 63))
            g_intBm = g_intBm - 1
            If g_intBm <= 0 Then
                NewBullet g_intBx - 34, g_intBy - 12, -4, 0
                NewBullet g_intBx - 34, g_intBy + 12, -4, 0
                Aim g_intBx - 34, g_intBy, 3
                If intFast Then
                    NewBullet g_intBx - 34, g_intBy, -3, -2
                    NewBullet g_intBx - 34, g_intBy, -3, 2
                End If
                g_intBm = 50 - intFast * 18
                Sfx.Play 0, 120, 6, 10, 8, 0
            End If
            If (g_intBt Mod 160) = 159 Then NewEnemy E_DRONE, g_intBx - 20, g_intBy, 0
        End If
        ' touching it
        If g_intDead = 0 And g_intInv = 0 Then
            If Abs(g_intBx - g_intPx) < g_intBw + 12 And Abs(g_intBy - g_intPy) < g_intBh + 6 Then Kill
        End If
        If g_intOrb > O_NONE And (g_intFrame And 3) = 0 Then
            If Abs(g_intBx - g_intOx) < g_intBw + 8 And Abs(g_intBy - g_intOy) < g_intBh + 8 Then HurtBoss 1
        End If
    End If
    If g_intBk = 0 Then Exit Sub
    If g_intBhit > 0 Then g_intBhit = g_intBhit - 1
    ' draw it
    If g_intBk = 1 Then
        intW = 2 : intH = 2 : intP = GfxData.S_GUARD : intPal = GfxData.P_GUARD
    ElseIf g_intBk = 2 Then
        intW = 4 : intH = 3 : intP = GfxData.S_BOSS1 : intPal = GfxData.P_BOSS1
    Else
        intW = 4 : intH = 3 : intP = GfxData.S_BOSS2 : intPal = GfxData.P_BOSS2
    End If
    If g_intBhit > 0 Then intPal = GfxData.P_BOOM
    For intCy = 0 To intH - 1
        For intCx = 0 To intW - 1
            If g_intBx - intW * 8 + intCx * 16 >= 0 And g_intBx - intW * 8 + intCx * 16 < 320 Then
                Spr.Put SL_BOSS + intCy * intW + intCx, g_intBx - intW * 8 + intCx * 16, g_intBy - intH * 8 + intCy * 16, intP + intCy * intW + intCx, intPal
            Else
                Spr.Hide SL_BOSS + intCy * intW + intCx
            End If
        Next
    Next
End Sub
