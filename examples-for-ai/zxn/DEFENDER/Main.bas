' ============================================================================
' DEFENDER - ZX Spectrum Next Edition (Layer 2 + 16x16 256-Colour Sprites)
' ============================================================================
' NTC BASIC. Built on the original (original_Main.bas): its world, its sprite hardware code,
' its landers, mutants, humans and scanner, with better graphics, sound and play:
'   - 16 sprite patterns (two frames for the ship, landers, mutants and humans, an enemy shot,
'     an explosion, the baiter) in SprData.cls (or DEFENDER.SPR where files work)
'   - stars behind, scrolling slower than the ground (the copper: Scroll.cls), a longer and
'     less regular landscape, the scanner showing where the screen is
'   - sounds for everything on the AY (Sfx.cls): laser, explosions, abductions, catches, the
'     smart bomb, hyperspace, the thrust
'   - losing a ship doesn't start the wave again; a moment's safety after; the ship turns round
'     smoothly; humans walk, fall (from high up they die), get caught and set down (500 each);
'     the baiter comes if a wave drags on; an extra ship and smart bomb every 10,000; the
'     humans and the planet come back every fifth wave
' The words are on the tilemap (Board.cls), the drawing on Layer 2 (L2.cls).
Option Explicit
Option Turbo

' ZX Spectrum Next Hardware Ports
Const PORT_NEXTREG_SEL As Integer = &H243B
Const PORT_NEXTREG_DAT As Integer = &H253B
Const PORT_SPRITE_SLOT As Integer = &H303B
Const PORT_SPRITE_ATTR As Integer = &H57
Const PORT_SPRITE_PAT  As Integer = &H5B

' World & Layer 2 Screen Constants (Layer 2 = 256x192, Sprites offset +32,+32; y counts up)
Const WORLD_W As Integer = 1024
Const WORLD_MASK As Integer = 1023
Const SPR_X_OFF As Integer = 32
Const SPR_Y_OFF As Integer = 32
Const PLAY_TOP As Integer = 30
Const PLAY_BOT As Integer = 146

' Sprite Pattern Indices (SprData.cls / DEFENDER.SPR)
Const PAT_PLAYER As Integer = 0
Const PAT_LANDER As Integer = 1
Const PAT_MUTANT As Integer = 2
Const PAT_HUMAN  As Integer = 3
Const PAT_BOLT   As Integer = 4
Const PAT_FRAME2 As Integer = 4      ' + this: the second frame of 0-3 (ship, lander, mutant, human)
Const PAT_SHOT   As Integer = 9
Const PAT_BOOM   As Integer = 10     ' 10-13
Const PAT_BAITER As Integer = 14     ' 14-15

' Hardware Sprite Slot Allocations
Const SLOT_PLAYER As Integer = 0
Const SLOT_LASER0 As Integer = 1
Const SLOT_HUMAN0 As Integer = 5
Const SLOT_ENEMY0 As Integer = 13
Const SLOT_SHOT0  As Integer = 23
Const SLOT_BOOM0  As Integer = 29

' Entity Counts
Const MAX_LASERS As Integer = 4
Const MAX_HUMANS As Integer = 8
Const MAX_ENEMIES As Integer = 10
Const MAX_SHOTS As Integer = 6
Const MAX_BOOMS As Integer = 4

' Enemy States
Const ST_DEAD As Integer = 0
Const ST_WANDER As Integer = 1
Const ST_DESCEND As Integer = 2
Const ST_ABDUCT As Integer = 3
Const ST_MUTANT As Integer = 4
Const ST_BAITER As Integer = 5

Const H_DEAD As Integer = 0
Const H_GROUND As Integer = 1
Const H_GRABBED As Integer = 2
Const H_FALLING As Integer = 3
Const H_CARRIED As Integer = 4

' Layer 2 colours (RRRGGGBB)
Const COL_TERRAIN As Integer = &HC8
Const COL_SCANNER As Integer = &H0B
Const COL_DIVIDER As Integer = &H8B

' Player State
Dim px As Integer, py As Integer
Dim pvx As Integer, pvy As Integer
Dim pdir As Integer, psx As Integer, cam_x As Integer
Dim old_prx As Integer, old_pry As Integer
Dim thrust As Integer, safeT As Integer

Dim score As Long, nextBonus As Long
Dim lives As Integer
Dim bombs As Integer
Dim wave As Integer
Dim game_over As Boolean
Dim planet_dead As Boolean
Dim fire_cd As Integer
Dim bomb_cd As Integer
Dim hyper_cd As Integer
Dim flash_bg As Integer
Dim frames As Integer, waveT As Integer, baiterT As Integer, hudDirty As Integer

' Lasers
Dim lx(MAX_LASERS) As Integer
Dim ly(MAX_LASERS) As Integer
Dim lvx(MAX_LASERS) As Integer
Dim lscr(MAX_LASERS) As Integer, lasersOn As Integer
Dim llife(MAX_LASERS) As Integer

' Humanoids
Dim hx(MAX_HUMANS) As Integer
Dim hy(MAX_HUMANS) As Integer
Dim hstate(MAX_HUMANS) As Integer
Dim hcarrier(MAX_HUMANS) As Integer
Dim hdir(MAX_HUMANS) As Integer
Dim hfall(MAX_HUMANS) As Integer, hvy(MAX_HUMANS) As Integer
Dim old_hrx(MAX_HUMANS) As Integer, old_hry(MAX_HUMANS) As Integer
Dim humans_alive As Integer

' Enemies
Dim ex(MAX_ENEMIES) As Integer
Dim ey(MAX_ENEMIES) As Integer
Dim evx(MAX_ENEMIES) As Integer
Dim evy(MAX_ENEMIES) As Integer
Dim estate(MAX_ENEMIES) As Integer
Dim etarget(MAX_ENEMIES) As Integer
Dim old_erx(MAX_ENEMIES) As Integer
Dim old_ery(MAX_ENEMIES) As Integer
Dim enemies_alive As Integer
Dim spawn_timer As Integer
Dim enemies_to_spawn As Integer

' Enemy Projectiles
Dim sx(MAX_SHOTS) As Integer
Dim sy(MAX_SHOTS) As Integer
Dim svx(MAX_SHOTS) As Integer
Dim svy(MAX_SHOTS) As Integer
Dim slife(MAX_SHOTS) As Integer

' Explosions (world x, y, frames to go)
Dim bx(MAX_BOOMS) As Integer, by(MAX_BOOMS) As Integer, bt(MAX_BOOMS) As Integer

' The landscape: a height for each 4 pixels of the world (256 of them)
Dim land(255) As Integer, yh(1023) As Byte
' Layer 2's terrain columns, the scanner's view marks
Dim ycol(255) As Integer, tcam As Integer, terOn As Integer, terDead As Boolean, mark0 As Integer

' The CPC-style statements the original used (Plot / Draw with a pen, bottom-up y), on the Next
Dim gx As Integer, gy As Integer, penc(15) As Integer, txtPen As Integer, atx As Integer, aty As Integer
Dim sprbuf(4607) As Byte
Dim i As Integer, j As Integer, k As Integer, rs As Long

' ============================================================================
' ZX SPECTRUM NEXT HARDWARE REGISTER & SPRITE HELPERS
' ============================================================================

Sub WriteNextReg(ByVal reg As Integer, ByVal val As Integer)
    Out PORT_NEXTREG_SEL, reg
    Out PORT_NEXTREG_DAT, val
End Sub

' Loads DEFENDER.SPR (512B 9-bit palette + 16x 256B 16x16 8-bit sprites), else the built-in set
Sub LoadSpriteTilemap(ByVal filename As String)
    ' Sprites visible, over the border; SUL (the words on the tilemap over Layer 2)
    WriteNextReg(&H15, &H0B)
    ' Sprite transparency index = 0
    WriteNextReg(&H4B, &H00)
    If FileSystem.Load(filename, VarPtr(sprbuf), 4608) = 4608 Then
        WriteNextReg(&H43, &H20)
        WriteNextReg(&H40, 0)
        For i = 0 To 255
            WriteNextReg(&H44, sprbuf(i * 2))
            WriteNextReg(&H44, sprbuf(i * 2 + 1))
        Next i
        Out PORT_SPRITE_SLOT, 0
        For i = 512 To 4607
            Out PORT_SPRITE_PAT, sprbuf(i)
        Next i
    Else
        SprData.Upload
    End If
End Sub

' Updates a hardware sprite slot (px_scr in 0..255 Layer 2 coords, py_scr in 0..191, y up)
Sub SetHardwareSprite(ByVal slot As Integer, ByVal px_scr As Integer, ByVal py_scr As Integer, ByVal pat As Integer, ByVal hflip As Boolean, ByVal visible As Boolean)
    Dim sx1 As Integer, sy1 As Integer, attr2 As Integer
    Out PORT_SPRITE_SLOT, slot
    If Not visible Then
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Exit Sub
    End If
    sx1 = px_scr + SPR_X_OFF - 8
    sy1 = (191 - py_scr) + SPR_Y_OFF - 8
    attr2 = (sx1 \ 256) And 1
    If hflip Then attr2 = attr2 Or 8
    Out PORT_SPRITE_ATTR, sx1 And 255
    Out PORT_SPRITE_ATTR, sy1 And 255
    Out PORT_SPRITE_ATTR, attr2
    Out PORT_SPRITE_ATTR, 192 Or (pat And 63)
    Out PORT_SPRITE_ATTR, 0
End Sub

Sub HideSprite(ByVal slot As Integer)
    SetHardwareSprite(slot, 0, 0, 0, False, False)
End Sub

Sub HideAllSprites()
    Dim s As Integer
    Out PORT_SPRITE_SLOT, 0
    For s = 0 To 63
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
    Next s
End Sub

' ============================================================================
' COORDINATE & TERRAIN HELPERS
' ============================================================================

' the landscape, made once: hills and mountains wandering up and down (no more than 4 pixels
' each 4 across, so the line has no gaps)
Sub MakeLand()
    Dim h As Integer, t As Integer
    rs = 12345 : h = 14 : t = 14
    For k = 0 To 255
        If k Mod 16 = 0 Then t = 8 + Rand(23)
        If h < t Then h = h + 1 + Rand(3)
        If h > t Then h = h - 1 - Rand(3)
        If h < 8 Then h = 8
        If h > 32 Then h = 32
        land(k) = h
    Next k
    ' the last few lead back to the first, so it joins all the way round
    For k = 248 To 255
        land(k) = land(247) + (land(0) - land(247)) * (k - 247) \ 9
    Next k
End Sub

Function Rand(ByVal n As Integer) As Integer
    rs = (rs * 1103515245 + 12345) And &H7FFFFFFF
    Rand = CInt((rs \ 65536) Mod n)
End Function

Function GetTerrainY(ByVal wx As Integer) As Integer
    If planet_dead Then GetTerrainY = 6 Else GetTerrainY = land((wx \ 4) And 255)
End Function

Function WorldToScreenX(ByVal wx As Integer, ByVal cx As Integer) As Integer
    Dim d As Integer
    d = (wx - cx) And WORLD_MASK
    If d >= 512 Then d = d - 1024
    WorldToScreenX = d
End Function

Function WorldToRadarX(ByVal wx As Integer) As Integer
    Dim rel As Integer
    rel = (wx - px + 512) And WORLD_MASK
    WorldToRadarX = 64 + (rel \ 8)
End Function

Sub UpdateHUD()
    Pen 15
    At 1, 1
    PrintS Right$("000000" & Mid$(Str$(score), 2), 7)
    Pen 14
    At 10, 1
    PrintS "SHIPS" & Str$(lives) & " "
    Pen 12
    At 19, 1
    PrintS "BOMBS" & Str$(bombs) & " "
    Pen 11
    At 27, 1
    PrintS "WAVE" & Str$(wave) & " "
    hudDirty = 0
End Sub

Sub DrawStaticFrame()
    ClsAll
    ' Scanner divider and radar box (x = 62..193, y = 152..183 in bottom-up Layer 2 coords)
    L2.Rect 0, 43, 256, 1, COL_DIVIDER
    Plot 62, 152, 12
    Draw 193, 152, 12
    Draw 193, 182, 12
    Draw 62, 182, 12
    Draw 62, 152, 12
    Stars
    mark0 = -1
    UpdateHUD()
End Sub

' the stars: scattered over the sky (Layer 2 lines 44-158), scrolled slowly by the copper
Sub Stars()
    Dim x As Integer, y As Integer
    rs = 777
    For k = 0 To 59
        x = Rand(256) : y = 46 + Rand(110)
        L2.Plot x, y, Val(Mid$("073146219255", (k Mod 4) * 3 + 1, 3))
    Next k
End Sub

' ============================================================================
' WAVE & ENTITY MANAGEMENT
' ============================================================================

Sub InitWave()
    HideAllSprites()
    DrawStaticFrame()

    px = 512 : py = 96 : pvx = 0 : pvy = 0 : pdir = 1 : psx = 88
    old_prx = 128 : old_pry = 165
    safeT = 50

    For i = 0 To MAX_LASERS - 1
        llife(i) = 0
    Next i
    For i = 0 To MAX_SHOTS - 1
        slife(i) = 0
    Next i
    For i = 0 To MAX_BOOMS - 1
        bt(i) = 0
    Next i

    ' the humans: all of them at the start, and back again every fifth wave
    If wave = 1 Or (wave - 1) Mod 5 = 0 Then
        planet_dead = False
        humans_alive = MAX_HUMANS
        For i = 0 To MAX_HUMANS - 1
            hx(i) = (i * 128 + 48) And WORLD_MASK
            hstate(i) = H_GROUND
        Next i
    End If
    For i = 0 To MAX_HUMANS - 1
        old_hrx(i) = 0
        hcarrier(i) = -1
        If hstate(i) <> H_DEAD Then
            hstate(i) = H_GROUND
            hy(i) = GetTerrainY(hx(i)) + 6
        End If
        If Rand(2) Then hdir(i) = 1 Else hdir(i) = -1
    Next i

    For i = 0 To MAX_ENEMIES - 1
        estate(i) = ST_DEAD
        old_erx(i) = 0
    Next i

    enemies_to_spawn = 10 + wave * 2
    If enemies_to_spawn > 24 Then enemies_to_spawn = 24
    enemies_alive = 0
    spawn_timer = 10
    waveT = 0 : baiterT = 0

    For i = 0 To 4
        SpawnEnemy()
    Next i
    UpdateHUD()
    Message "WAVE" & Str$(wave), 60
End Sub

Sub SpawnEnemy()
    If enemies_to_spawn <= 0 Then Exit Sub
    For i = 0 To MAX_ENEMIES - 1
        If estate(i) = ST_DEAD Then
            ex(i) = (px + 250 + Rnd(500)) And WORLD_MASK
            ey(i) = 110 + Rnd(30)
            If Rnd(2) = 0 Then evx(i) = 1 Else evx(i) = -1
            evy(i) = -1
            If planet_dead Then estate(i) = ST_MUTANT Else estate(i) = ST_WANDER
            etarget(i) = -1
            old_erx(i) = 0
            enemies_alive = enemies_alive + 1
            enemies_to_spawn = enemies_to_spawn - 1
            Exit Sub
        End If
    Next i
End Sub

' the baiter: a fast saucer that comes for you when a wave goes on too long
Sub SpawnBaiter()
    For i = 0 To MAX_ENEMIES - 1
        If estate(i) = ST_DEAD Then
            ex(i) = (px + 300) And WORLD_MASK
            ey(i) = py
            estate(i) = ST_BAITER
            evx(i) = 0 : evy(i) = 0
            etarget(i) = -1 : old_erx(i) = 0
            Sfx.Play 1, 40, 2, 13, 25, 0
            Exit Sub
        End If
    Next i
End Sub

Sub FireLaser()
    For i = 0 To MAX_LASERS - 1
        If llife(i) = 0 Then
            lx(i) = (px + pdir * 12) And WORLD_MASK
            ly(i) = py - 1
            lvx(i) = pdir * 16 + pvx
            llife(i) = 14
            Sfx.Play 0, 24, 5, 12, 9, 0
            Exit Sub
        End If
    Next i
End Sub

Sub Boom(ByVal wx As Integer, ByVal wy As Integer)
    For k = 0 To MAX_BOOMS - 1
        If bt(k) = 0 Then
            bx(k) = wx : by(k) = wy : bt(k) = 16
            Exit Sub
        End If
    Next k
End Sub

Sub KillEnemy(ByVal idx As Integer)
    Dim h As Integer
    HideSprite(SLOT_ENEMY0 + idx)
    If old_erx(idx) > 0 Then
        Plot old_erx(idx), old_ery(idx), 0
        old_erx(idx) = 0
    End If
    Boom ex(idx), ey(idx)

    h = etarget(idx)
    If h >= 0 And h < MAX_HUMANS Then
        If hstate(h) = H_GRABBED And hcarrier(h) = idx Then
            hstate(h) = H_FALLING
            hcarrier(h) = -1
            hfall(h) = hy(h) : hvy(h) = 0
        End If
    End If

    If estate(idx) = ST_BAITER Then
        AddScore 200
    Else
        AddScore 150
        enemies_alive = enemies_alive - 1
    End If
    estate(idx) = ST_DEAD
    Sfx.Play 1, 10, 1, 14, 20, 1
End Sub

Sub AddScore(ByVal n As Integer)
    score = score + n
    If score >= nextBonus Then
        nextBonus = nextBonus + 10000
        lives = lives + 1
        If bombs < 9 Then bombs = bombs + 1
        Sfx.Play 2, 60, -1, 14, 40, 0
    End If
    hudDirty = 1
End Sub

Sub TriggerSmartBomb(ByVal cx As Integer)
    Dim sx_pos As Integer
    If bombs <= 0 Then Exit Sub
    bombs = bombs - 1
    bomb_cd = 25
    Sfx.Play 2, 4, 1, 15, 45, 1
    Border 7
    Nx.PalEntry Nx.PalLayer2, 0, &HFF
    flash_bg = 4

    For i = 0 To MAX_ENEMIES - 1
        If estate(i) <> ST_DEAD Then
            sx_pos = WorldToScreenX(ex(i), cx)
            If sx_pos >= -16 And sx_pos <= 272 Then KillEnemy(i)
        End If
    Next i
    For i = 0 To MAX_SHOTS - 1
        slife(i) = 0
    Next i
    hudDirty = 1
End Sub

' the ship's hit: it blows up, the others clear off a little, a moment's safety, and on
Sub LoseLife()
    Dim f As Integer
    Sfx.Play 2, 6, 1, 15, 70, 1
    Sfx.Play 0, 150, 6, 14, 60, 0
    For i = 0 To MAX_HUMANS - 1
        If hstate(i) = H_CARRIED Then
            hstate(i) = H_FALLING : hfall(i) = hy(i) : hvy(i) = 0
        End If
    Next i
    For f = 0 To 59
        SetHardwareSprite(SLOT_PLAYER, psx, py, PAT_BOOM + (f \ 4) Mod 4, False, (f < 40))
        If f Mod 8 < 4 Then Border 2 Else Border 0
        Vsync
    Next f
    Border 0
    lives = lives - 1
    If lives <= 0 Then
        HideAllSprites()
        game_over = True
        Exit Sub
    End If
    ' the enemies near the ship are moved away, the shots gone
    For i = 0 To MAX_ENEMIES - 1
        If estate(i) <> ST_DEAD Then
            If Abs(WorldToScreenX(ex(i), px)) < 200 Then ex(i) = (ex(i) + 400) And WORLD_MASK
            If estate(i) = ST_BAITER Then
                estate(i) = ST_DEAD : HideSprite(SLOT_ENEMY0 + i)
            End If
        End If
    Next i
    For i = 0 To MAX_SHOTS - 1
        slife(i) = 0
    Next i
    py = 96 : pvx = 0 : safeT = 100 : baiterT = 0
    hudDirty = 1
End Sub

' a message in the middle of the play area for a while
Dim msgT As Integer
Sub Message(ByVal m As String, ByVal t As Integer)
    Pen 14
    At 17 - Len(m) \ 2, 11
    PrintS m
    msgT = t
End Sub

' ============================================================================
' THE PARTS OF A FRAME
' ============================================================================

Sub Controls()
    j = Joy(0)
    ' Up: Q (3) or Joy Up (8) | Down: A (2) or Joy Down (4)
    If Key(3) Or (j And 8) <> 0 Then
        If pvy < 3 Then pvy = pvy + 1
    ElseIf Key(2) Or (j And 4) <> 0 Then
        If pvy > -3 Then pvy = pvy - 1
    Else
        pvy = 0
    End If

    ' Left: O (33) or Joy Left (2) | Right: P (32) or Joy Right (1)
    thrust = 0
    If Key(33) Or (j And 2) <> 0 Then
        pdir = -1 : thrust = 1
        If pvx > -10 Then pvx = pvx - 1
    ElseIf Key(32) Or (j And 1) <> 0 Then
        pdir = 1 : thrust = 1
        If pvx < 10 Then pvx = pvx + 1
    ElseIf frames Mod 3 = 0 Then
        If pvx > 0 Then pvx = pvx - 1
        If pvx < 0 Then pvx = pvx + 1
    End If
    If thrust And Sfx.Busy(2) = 0 Then Sfx.Play 2, 28, 0, 5, 3, 1

    px = (px + pvx) And WORLD_MASK
    py = py + pvy
    If py < PLAY_TOP Then py = PLAY_TOP
    If py > PLAY_BOT Then py = PLAY_BOT

    ' the ship sits to one side, leaving room ahead: turning round, it slides across
    If pdir > 0 And psx > 88 Then psx = psx - 4
    If pdir < 0 And psx < 168 Then psx = psx + 4
    cam_x = (px - psx) And WORLD_MASK

    ' Fire Laser: Space (40), Z (9), or Joy Fire 1 (16)
    If fire_cd > 0 Then fire_cd = fire_cd - 1
    If (Key(40) Or Key(9) Or (j And 16) <> 0) And fire_cd = 0 Then
        FireLaser()
        fire_cd = 5
    End If

    ' Smart Bomb: B (36), M (34), or Joy Fire 2 (32)
    If bomb_cd > 0 Then bomb_cd = bomb_cd - 1
    If (Key(36) Or Key(34) Or (j And 32) <> 0) And bomb_cd = 0 Then TriggerSmartBomb(cam_x)

    ' Hyperspace: H (38): somewhere else, at random
    If hyper_cd > 0 Then hyper_cd = hyper_cd - 1
    If Key(38) And hyper_cd = 0 Then
        Plot old_prx, old_pry, 0
        px = Rnd(WORLD_W)
        py = 50 + Rnd(85)
        pvx = 0
        hyper_cd = 50 : safeT = 25
        Sfx.Play 0, 500, -24, 14, 20, 0
    End If
End Sub

Sub DrawPlayer()
    Dim f As Integer
    f = PAT_PLAYER
    If thrust And (frames And 2) Then f = PAT_PLAYER + PAT_FRAME2
    SetHardwareSprite(SLOT_PLAYER, psx, py, f, (pdir < 0), (safeT = 0 Or (safeT And 4) = 0))
    If safeT > 0 Then safeT = safeT - 1

    Plot old_prx, old_pry, 0
    old_prx = 128
    old_pry = 154 + (py \ 7)
    Plot old_prx, old_pry, 15
End Sub

Sub Lasers()
    Dim lsx As Integer
    lasersOn = 0
    For i = 0 To MAX_LASERS - 1
        If llife(i) > 0 Then
            lx(i) = (lx(i) + lvx(i)) And WORLD_MASK
            llife(i) = llife(i) - 1
            lsx = WorldToScreenX(lx(i), cam_x)
            If llife(i) > 0 And lsx >= 0 And lsx <= 255 Then
                SetHardwareSprite(SLOT_LASER0 + i, lsx, ly(i), PAT_BOLT, (lvx(i) < 0), True)
                lscr(i) = lsx : lasersOn = 1
            Else
                llife(i) = 0
                HideSprite(SLOT_LASER0 + i)
            End If
        Else
            HideSprite(SLOT_LASER0 + i)
        End If
    Next i
End Sub

Sub Humans()
    Dim hsx As Integer, hrx As Integer, hry As Integer, t_ground As Integer
    For i = 0 To MAX_HUMANS - 1
        If old_hrx(i) > 0 Then
            Plot old_hrx(i), old_hry(i), 0
            old_hrx(i) = 0
        End If

        If hstate(i) <> H_DEAD Then
            Select Case hstate(i)
            Case H_GROUND
                ' wandering about
                If frames Mod 6 = 0 Then
                    hx(i) = (hx(i) + hdir(i)) And WORLD_MASK
                    If Rnd(60) = 0 Then hdir(i) = -hdir(i)
                End If
                hy(i) = GetTerrainY(hx(i)) + 6
            Case H_CARRIED
                hx(i) = px
                hy(i) = py - 10
                t_ground = GetTerrainY(hx(i)) + 6
                If hy(i) <= t_ground Or py <= PLAY_TOP Then
                    hy(i) = t_ground
                    hstate(i) = H_GROUND
                    AddScore 500
                    Sfx.Play 0, 90, -3, 14, 20, 0
                End If
            Case H_FALLING
                If frames Mod 4 = 0 And hvy(i) < 3 Then hvy(i) = hvy(i) + 1
                hy(i) = hy(i) - hvy(i)
                If Abs(WorldToScreenX(hx(i), cam_x) - psx) < 12 And Abs(hy(i) - py) < 12 Then
                    hstate(i) = H_CARRIED
                    AddScore 500
                    Sfx.Play 0, 140, -6, 14, 14, 0
                Else
                    t_ground = GetTerrainY(hx(i)) + 6
                    If hy(i) <= t_ground Then
                        hy(i) = t_ground
                        If hfall(i) - t_ground > 60 Then
                            ' too far to fall
                            hstate(i) = H_DEAD
                            humans_alive = humans_alive - 1
                            Boom hx(i), hy(i)
                            Sfx.Play 1, 100, 12, 13, 25, 0
                            HumansGone
                        Else
                            hstate(i) = H_GROUND
                            AddScore 250
                        End If
                    End If
                End If
            End Select
        End If

        If hstate(i) <> H_DEAD Then
            hsx = WorldToScreenX(hx(i), cam_x)
            If hsx >= -8 And hsx <= 263 Then
                SetHardwareSprite(SLOT_HUMAN0 + i, hsx, hy(i), PAT_HUMAN + PAT_FRAME2 * ((frames \ 12) And 1) * (hstate(i) = H_GROUND) * -1, (hdir(i) < 0), True)
            Else
                HideSprite(SLOT_HUMAN0 + i)
            End If
            hrx = WorldToRadarX(hx(i))
            hry = 153 + (hy(i) \ 7)
            Plot hrx, hry, 13
            old_hrx(i) = hrx : old_hry(i) = hry
        Else
            HideSprite(SLOT_HUMAN0 + i)
        End If
    Next i
End Sub

' no humans left: the planet goes, and every lander turns mutant
Sub HumansGone()
    If humans_alive <= 0 And Not planet_dead Then
        planet_dead = True
        Border 2
        flash_bg = 10
        Sfx.Play 2, 3, 1, 15, 60, 1
        For k = 0 To MAX_ENEMIES - 1
            If estate(k) = ST_WANDER Or estate(k) = ST_DESCEND Then estate(k) = ST_MUTANT
        Next k
        Message "THE PLANET IS GONE", 100
    End If
End Sub

Sub Enemies()
    Dim esx As Integer, erx As Integer, ery As Integer, epat As Integer, ecol As Integer
    Dim th As Integer, dx_h As Integer, l_idx As Integer, hit As Boolean, lsx As Integer, s As Integer

    If spawn_timer > 0 Then
        spawn_timer = spawn_timer - 1
    ElseIf enemies_to_spawn > 0 And enemies_alive < 7 Then
        SpawnEnemy()
        spawn_timer = 60
    End If
    ' the baiter: after 40 seconds, then every 12
    waveT = waveT + 1
    If waveT > 2000 Then
        baiterT = baiterT + 1
        If baiterT >= 600 Or waveT = 2001 Then
            baiterT = 0
            SpawnBaiter()
        End If
    End If

    For i = 0 To MAX_ENEMIES - 1
        If old_erx(i) > 0 Then
            Plot old_erx(i), old_ery(i), 0
            old_erx(i) = 0
        End If

        If estate(i) <> ST_DEAD Then
            Select Case estate(i)
            Case ST_WANDER
                If frames Mod 2 = 0 Then ex(i) = (ex(i) + evx(i)) And WORLD_MASK
                If frames Mod 3 = 0 Then ey(i) = ey(i) + evy(i)
                If ey(i) < 70 Then evy(i) = 1
                If ey(i) > 140 Then evy(i) = -1
                ' now and then it picks a human below to take
                If Rnd(150) = 0 And humans_alive > 0 Then
                    th = Rnd(MAX_HUMANS)
                    If hstate(th) = H_GROUND Then
                        etarget(i) = th
                        estate(i) = ST_DESCEND
                    End If
                End If
            Case ST_DESCEND
                th = etarget(i)
                If th < 0 Or hstate(th) <> H_GROUND Then
                    estate(i) = ST_WANDER
                Else
                    dx_h = WorldToScreenX(hx(th), ex(i))
                    If dx_h > 1 Then
                        ex(i) = (ex(i) + 1) And WORLD_MASK
                    ElseIf dx_h < -1 Then
                        ex(i) = (ex(i) - 1) And WORLD_MASK
                    ElseIf ey(i) > hy(th) + 10 Then
                        ey(i) = ey(i) - 1
                    Else
                        hstate(th) = H_GRABBED
                        hcarrier(th) = i
                        estate(i) = ST_ABDUCT
                        Sfx.Play 1, 300, -16, 13, 30, 0
                        Message "HUMANOID TAKEN!", 50
                    End If
                End If
            Case ST_ABDUCT
                th = etarget(i)
                If th < 0 Or hstate(th) <> H_GRABBED Then
                    estate(i) = ST_WANDER
                Else
                    If frames Mod 2 = 0 Then ey(i) = ey(i) + 1
                    hx(th) = ex(i)
                    hy(th) = ey(i) - 10
                    If ey(i) >= 140 Then
                        hstate(th) = H_DEAD
                        humans_alive = humans_alive - 1
                        estate(i) = ST_MUTANT
                        Sfx.Play 1, 60, 8, 15, 40, 0
                        HumansGone
                    End If
                End If
            Case ST_MUTANT
                ' straight at the ship, twitching
                dx_h = WorldToScreenX(px, ex(i))
                If dx_h > 0 Then ex(i) = (ex(i) + 2 + Rnd(2)) And WORLD_MASK Else ex(i) = (ex(i) - 2 - Rnd(2)) And WORLD_MASK
                If ey(i) < py - 4 Then
                    ey(i) = ey(i) + 1 + Rnd(2)
                ElseIf ey(i) > py + 4 Then
                    ey(i) = ey(i) - 1 - Rnd(2)
                Else
                    ey(i) = ey(i) + Rnd(5) - 2
                End If
            Case ST_BAITER
                ' fast, close, and mean
                dx_h = WorldToScreenX(px, ex(i))
                If dx_h > 30 And evx(i) < 9 Then evx(i) = evx(i) + 1
                If dx_h < -30 And evx(i) > -9 Then evx(i) = evx(i) - 1
                ex(i) = (ex(i) + evx(i)) And WORLD_MASK
                If ey(i) < py Then ey(i) = ey(i) + 2 Else ey(i) = ey(i) - 2
            End Select
            If ey(i) < PLAY_TOP - 8 Then ey(i) = PLAY_TOP - 8
            If ey(i) > PLAY_BOT Then ey(i) = PLAY_BOT

            ' Laser Collision Check
            hit = False
            esx = (ex(i) - cam_x) And WORLD_MASK
            If esx >= 512 Then esx = esx - 1024
            If lasersOn Then
            For l_idx = 0 To MAX_LASERS - 1
                If llife(l_idx) > 0 Then
                    lsx = lscr(l_idx)
                    If Abs(esx - lsx) < 14 And Abs(ey(i) - ly(l_idx)) < 9 Then
                        llife(l_idx) = 0
                        HideSprite(SLOT_LASER0 + l_idx)
                        KillEnemy(i)
                        hit = True
                        Exit For
                    End If
                End If
            Next l_idx
            End If

            If Not hit Then
                If safeT = 0 And Abs(esx - psx) < 11 And Abs(ey(i) - py) < 9 Then
                    KillEnemy(i)
                    LoseLife()
                    Exit Sub
                End If

                ' Enemy Shoots (aimed), when it's on the screen and not right on top of the ship
                s = 220
                If estate(i) = ST_MUTANT Then s = 140
                If estate(i) = ST_BAITER Then s = 60
                If esx >= 12 And esx <= 244 And Abs(esx - psx) > 24 And Rnd(s) = 0 Then EnemyShot i, esx

                epat = PAT_LANDER : ecol = 12
                If estate(i) = ST_MUTANT Then epat = PAT_MUTANT : ecol = 10
                If (frames \ 8) And 1 Then epat = epat + PAT_FRAME2
                If estate(i) = ST_BAITER Then epat = PAT_BAITER + ((frames \ 4) And 1) : ecol = 14

                If esx >= -8 And esx <= 263 Then
                    SetHardwareSprite(SLOT_ENEMY0 + i, esx, ey(i), epat, False, True)
                Else
                    HideSprite(SLOT_ENEMY0 + i)
                End If

                erx = WorldToRadarX(ex(i))
                ery = 153 + (ey(i) \ 7)
                Plot erx, ery, ecol
                old_erx(i) = erx
                old_ery(i) = ery
            End If
        Else
            HideSprite(SLOT_ENEMY0 + i)
        End If
    Next i
End Sub

' a shot from enemy n at screen x esx, aimed at the ship
Sub EnemyShot(ByVal n As Integer, ByVal esx As Integer)
    Dim dx As Integer, dy As Integer, m As Integer
    For k = 0 To MAX_SHOTS - 1
        If slife(k) = 0 Then
            dx = psx - esx : dy = py - ey(n)
            m = Abs(dx)
            If Abs(dy) > m Then m = Abs(dy)
            If m < 1 Then m = 1
            sx(k) = ex(n) * 4 : sy(k) = ey(n) * 4
            svx(k) = dx * 12 \ m : svy(k) = dy * 12 \ m
            slife(k) = 60
            Sfx.Play 2, 70, -3, 8, 6, 0
            Exit Sub
        End If
    Next k
End Sub

Sub Shots()
    Dim ssx As Integer, wy As Integer
    For i = 0 To MAX_SHOTS - 1
        If slife(i) > 0 Then
            sx(i) = (sx(i) + svx(i)) And 4095
            sy(i) = sy(i) + svy(i)
            slife(i) = slife(i) - 1
            ssx = WorldToScreenX(sx(i) \ 4, cam_x)
            wy = sy(i) \ 4
            If slife(i) > 0 And ssx >= 0 And ssx <= 255 And wy > 20 And wy < 148 Then
                If safeT = 0 And Abs(ssx - psx) < 7 And Abs(wy - py) < 6 Then
                    slife(i) = 0
                    HideSprite(SLOT_SHOT0 + i)
                    LoseLife()
                    Exit Sub
                End If
                SetHardwareSprite(SLOT_SHOT0 + i, ssx, wy, PAT_SHOT, False, True)
            Else
                slife(i) = 0
                HideSprite(SLOT_SHOT0 + i)
            End If
        Else
            HideSprite(SLOT_SHOT0 + i)
        End If
    Next i
End Sub

Sub Booms()
    Dim bsx As Integer
    For k = 0 To MAX_BOOMS - 1
        If bt(k) > 0 Then
            bt(k) = bt(k) - 1
            bsx = WorldToScreenX(bx(k), cam_x)
            SetHardwareSprite(SLOT_BOOM0 + k, bsx, by(k), PAT_BOOM + (15 - bt(k)) \ 4, False, (bt(k) > 0 And bsx > -8 And bsx < 264))
        Else
            HideSprite(SLOT_BOOM0 + k)
        End If
    Next k
End Sub

' the scanner's marks showing the part of the world on the screen (just outside the box, above
' and below it)
Sub ViewMarks()
    Dim m As Integer
    m = WorldToRadarX(cam_x)
    If m = mark0 Then Exit Sub
    If mark0 >= 0 Then
        L2.Span mark0, 7, 3, 0 : L2.Span mark0 + 30, 7, 3, 0
        L2.Span mark0, 41, 3, 0 : L2.Span mark0 + 30, 41, 3, 0
    End If
    If m >= 62 And m + 33 <= 194 Then
        L2.Span m, 7, 3, &HFF : L2.Span m + 30, 7, 3, &HFF
        L2.Span m, 41, 3, &HFF : L2.Span m + 30, 41, 3, &HFF
        mark0 = m
    Else
        mark0 = -1
    End If
End Sub

' ============================================================================
' MAIN PROGRAM ENTRY
' ============================================================================

Tiles.Init
Spr.Init
GfxData.Load
Sfx.Init
Board.Init
L2.Init
Nx.Layers Nx.OrderSUL
SetPens
Border 0
Paper 0
Pen 15
ClsAll
MakeLand
Heights

' the sprites: DEFENDER.SPR if it's there, the built-in set if not
LoadSpriteTilemap("DEFENDER.SPR")

Do
    TitleScreen

    score = 0 : nextBonus = 10000
    lives = 3
    bombs = 3
    wave = 1
    game_over = False
    InitWave()

    Do While Not game_over
        Vsync
        frames = frames + 1
        If flash_bg > 0 Then
            flash_bg = flash_bg - 1
            If flash_bg = 0 Then
                Border 0
                Nx.PalEntry Nx.PalLayer2, 0, 0
            End If
        End If
        If msgT > 0 Then
            msgT = msgT - 1
            If msgT = 0 Then At 1, 11 : PrintS Space$(32)
        End If

        Controls
        DrawPlayer
        Lasers
        Humans
        Enemies
        If Not game_over Then Shots
        Booms
        Terrain cam_x
        ViewMarks
        If hudDirty Then UpdateHUD()

        ' wave complete: a bonus for each human left
        If enemies_alive <= 0 And enemies_to_spawn <= 0 And Not game_over Then
            WaveDone
        End If
    Loop

    ' Game Over Screen
    HideAllSprites()
    ClsAll
    Scroll.Show 0, 0
    Pen 10
    At 8, 9
    PrintS "G A M E   O V E R"
    Pen 15
    At 8, 12
    PrintS "FINAL SCORE: " & Mid$(Str$(score), 2)
    Pen 14
    At 8, 15
    PrintS "REACHED WAVE: " & Mid$(Str$(wave), 2)
    For i = 1 To 150
        Vsync
    Next i
Loop

Sub WaveDone()
    Dim b As Integer, f As Integer
    For i = 0 To MAX_ENEMIES - 1
        If estate(i) = ST_BAITER Then estate(i) = ST_DEAD : HideSprite(SLOT_ENEMY0 + i)
    Next i
    b = humans_alive * 100 * wave
    If b > 5000 Then b = 5000
    Pen 14
    At 9, 10 : PrintS "ATTACK WAVE" & Str$(wave)
    At 11, 11 : PrintS "COMPLETED"
    Pen 15
    At 9, 13 : PrintS "BONUS" & Str$(b)
    For f = 0 To 5
        Sfx.Play f Mod 3, 120 - f * 12, 0, 13, 12, 0
        For i = 1 To 10
            Vsync
        Next i
    Next f
    AddScore b
    For i = 1 To 60
        Vsync
    Next i
    wave = wave + 1
    If bombs < 5 Then bombs = bombs + 1
    InitWave()
End Sub

Sub TitleScreen()
    Dim t As Integer, a As Integer
    HideAllSprites()
    ClsAll
    Scroll.Show 0, 0
    Stars
    L2.Big 24, 6, "DEFENDER", 3, &HFC, &HE0
    Pen 11
    At 5, 6
    PrintS "ZX SPECTRUM NEXT EDITION"
    Pen 15
    At 9, 9 : PrintS "LANDER      150"
    At 9, 11 : PrintS "MUTANT      150"
    At 9, 13 : PrintS "BAITER      200"
    At 9, 15 : PrintS "HUMANOID    500"
    Pen 12
    At 3, 17 : PrintS "Q / A or UP/DN : ALTITUDE"
    At 3, 18 : PrintS "O / P or LT/RT : THRUST"
    At 3, 19 : PrintS "SPACE / FIRE 1 : LASER"
    At 3, 20 : PrintS "B / M / FIRE 2 : SMART BOMB"
    At 3, 21 : PrintS "H              : HYPERSPACE"
    t = 0
    Do
        Vsync
        t = t + 1
        a = (t \ 8) And 1
        SetHardwareSprite(1, 56, 195 - 9 * 8, PAT_LANDER + a * PAT_FRAME2, False, True)
        SetHardwareSprite(2, 56, 195 - 11 * 8, PAT_MUTANT + a * PAT_FRAME2, False, True)
        SetHardwareSprite(3, 56, 195 - 13 * 8, PAT_BAITER + a, False, True)
        SetHardwareSprite(4, 56, 195 - 15 * 8, PAT_HUMAN + a * PAT_FRAME2, False, True)
        ' the ship flies across the bottom
        SetHardwareSprite(0, (t * 2) Mod 300 - 20, 6, PAT_PLAYER + a * PAT_FRAME2, False, True)
        Pen 10
        At 7, 23
        If (t \ 25) And 1 Then PrintS "PRESS SPACE OR FIRE" Else PrintS "                   "
        k = Rnd(10)
    Loop Until Key(40) Or (Joy(0) And 16) <> 0
    Do
        Vsync
    Loop While Key(40) Or (Joy(0) And 16) <> 0
    HideAllSprites()
End Sub

' ============================================================================
' THE ORIGINAL'S CPC-STYLE STATEMENTS, ON THE NEXT
' ============================================================================

' the pens: Layer 2 colours (RRRGGGBB) for drawing; the words' palette rows
Sub SetPens()
    For k = 0 To 15
        penc(k) = Val(Mid$("000 003 224 028 031 226 252 255 146 002 224 031 028 226 252 255", k * 4 + 1, 3))
    Next k
    Board.Pal 2, "00FF00000000000000000000000025E3"
    Board.Pal 3, "00FC00000000000000000000000025E3"
    Board.Pal 4, "001F00000000000000000000000025E3"
    Board.Pal 5, "00E000000000000000000000000025E3"
    Board.Pal 6, "001C00000000000000000000000025E3"
    Board.Pal 7, "00E200000000000000000000000025E3"
End Sub

' Pen n: the colour for the words that follow
Sub Pen(ByVal n As Integer)
    Select Case n
        Case 14: txtPen = 3
        Case 11: txtPen = 4
        Case 10: txtPen = 5
        Case 12: txtPen = 6
        Case 13: txtPen = 7
        Case Else: txtPen = 2
    End Select
End Sub

Sub Paper(ByVal n As Integer)
End Sub

Sub Border(ByVal n As Integer)
    Nx.Border n And 7
End Sub

' At x, y: where the words go (1, 1 = the top left of the 32 x 24 picture)
Sub At(ByVal x As Integer, ByVal y As Integer)
    atx = x + 3 : aty = y + 3
End Sub

Sub PrintS(ByVal t As String)
    Board.Text atx, aty, t, txtPen
    atx = atx + Len(t)
End Sub

Sub ClsAll()
    Board.Clear
    L2.Rect 0, 0, 256, 192, 0
    For k = 0 To 255
        ycol(k) = -1
    Next k
    terOn = 0
End Sub

' Plot x, y, c: a point (y counts up from the bottom, as on the CPC), and the start of the next Draw
Sub Plot(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer)
    gx = x : gy = y
    If x >= 0 And x < 256 And y >= 0 And y < 192 Then L2.Plot x, 191 - y, penc(c And 15)
End Sub

' Draw x, y, c: a line from the last point to x, y
Sub Draw(ByVal x As Integer, ByVal y As Integer, ByVal c As Integer)
    Dim dx As Integer, dy As Integer, sx1 As Integer, sy1 As Integer, e As Integer, e2 As Integer, x0 As Integer, y0 As Integer, col As Integer
    col = penc(c And 15)
    x0 = gx : y0 = gy
    dx = Abs(x - x0) : dy = -Abs(y - y0)
    If x0 < x Then sx1 = 1 Else sx1 = -1
    If y0 < y Then sy1 = 1 Else sy1 = -1
    e = dx + dy
    Do
        If x0 >= 0 And x0 < 256 And y0 >= 0 And y0 < 192 Then L2.Plot x0, 191 - y0, col
        If x0 = x And y0 = y Then Exit Do
        e2 = e * 2
        If e2 >= dy Then e = e + dy : x0 = x0 + sx1
        If e2 <= dx Then e = e + dx : y0 = y0 + sy1
    Loop
    gx = x : gy = y
End Sub

' Sound ch, pitch, length, volume: the original's sounds, on the AY (channel 1 = A, 2 = B)
Sub Sound(ByVal ch As Integer, ByVal pitch As Integer, ByVal dur As Integer, ByVal vol As Integer)
    Sfx.Play (ch - 1) Mod 3, pitch, 0, vol, dur * 2 + 1, 0
End Sub

' Vsync: wait for the next frame (and keep the sound and the copper going)
Sub Vsync()
    Frame
    Scroll.Upload
    Sfx.Update
End Sub

' Key(n): the original's key numbers, on the Next's keyboard
Function Key(ByVal n As Integer) As Integer
    Select Case n
        Case 40: Key = Keys.Down(Keys.KeySpace)
        Case 3: Key = Keys.Down(Keys.KeyQ)
        Case 2: Key = Keys.Down(Keys.KeyA)
        Case 33: Key = Keys.Down(Keys.KeyO)
        Case 32: Key = Keys.Down(Keys.KeyP)
        Case 9: Key = Keys.Down(Keys.KeyZ)
        Case 36: Key = Keys.Down(Keys.KeyB)
        Case 34: Key = Keys.Down(Keys.KeyM)
        Case 38: Key = Keys.Down(Keys.KeyH)
        Case Else: Key = 0
    End Select
End Function

' Joy(0): the joystick as the original's bits (1 right, 2 left, 4 down, 8 up, 16 fire, 32 fire 2)
Function Joy(ByVal n As Integer) As Integer
    Dim j0 As Integer, r As Integer
    j0 = Keys.Joystick(n)
    r = 0
    If j0 And Keys.JoyRight Then r = r Or 1
    If j0 And Keys.JoyLeft Then r = r Or 2
    If j0 And Keys.JoyDown Then r = r Or 4
    If j0 And Keys.JoyUp Then r = r Or 8
    If j0 And Keys.JoyFire1 Then r = r Or 16
    If j0 And Keys.JoyFire2 Then r = r Or 32
    Joy = r
End Function

' The terrain. Layer 2's column (wx And 255) holds world x wx; the copper scrolls the bottom of
' the screen (from line 160) by cx And 255 and the sky (lines 44-159, the stars) by a quarter of
' that, so the screen shows world x cx .. cx + 255 there. Only the columns that come into view
' since last time are drawn.
Sub Terrain(ByVal cx As Integer)
    Dim d As Integer
    If terDead <> planet_dead Then Heights
    If terOn = 0 Or terDead <> planet_dead Then
        For k = 0 To 255
            Col (cx + k) And WORLD_MASK
        Next k
    Else
        d = (cx - tcam) And WORLD_MASK
        If d >= 512 Then d = d - 1024
        If d >= 256 Or d <= -256 Then
            For k = 0 To 255
                Col (cx + k) And WORLD_MASK
            Next k
        ElseIf d > 0 Then
            For k = 256 - d To 255
                Col (cx + k) And WORLD_MASK
            Next k
        ElseIf d < 0 Then
            For k = 0 To -d - 1
                Col (cx + k) And WORLD_MASK
            Next k
        End If
    End If
    terOn = 1 : terDead = planet_dead : tcam = cx
    Scroll.Show (cx \ 4) And 255, cx And 255
End Sub

' one column of the terrain: the old pixel off, the new on (its height worked out beforehand: Heights)
Sub Col(ByVal wx As Integer)
    Dim c As Integer
    c = wx And 255
    If ycol(c) >= 0 Then L2.Plot c, ycol(c), 0
    ycol(c) = yh(wx)
    L2.Plot c, ycol(c), COL_TERRAIN
End Sub

' the ground's line for every x of the world (Layer 2 y, top down), sloping between the 4-pixel
' steps of GetTerrainY
Sub Heights()
    Dim wx As Integer, h0 As Integer, h1 As Integer
    For wx = 0 To WORLD_MASK
        h0 = GetTerrainY(wx) : h1 = GetTerrainY((wx + 4) And WORLD_MASK)
        yh(wx) = 191 - (h0 + (h1 - h0) * (wx And 3) \ 4)
    Next wx
End Sub
