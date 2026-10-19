' ============================================================================
' DEFENDER - ZX Spectrum Next Edition (Layer 2 + 16x16 256-Colour Sprites)
' ============================================================================
Option Explicit

' ZX Spectrum Next Hardware Ports
Const PORT_NEXTREG_SEL As Integer = &H243B
Const PORT_NEXTREG_DAT As Integer = &H253B
Const PORT_SPRITE_SLOT As Integer = &H303B
Const PORT_SPRITE_ATTR As Integer = &H57
Const PORT_SPRITE_PAT  As Integer = &H5B

' World & Layer 2 Screen Constants (Layer 2 = 256x192, Sprites offset +32,+32)
Const WORLD_W As Integer = 1024
Const WORLD_MASK As Integer = 1023
Const SCR_W As Integer = 256
Const SCR_H As Integer = 192
Const SPR_X_OFF As Integer = 32
Const SPR_Y_OFF As Integer = 32
Const PLAY_TOP As Integer = 40
Const PLAY_BOT As Integer = 172

' Sprite Pattern Indices in DEFENDER.SPR
Const PAT_PLAYER As Integer = 0
Const PAT_LANDER As Integer = 1
Const PAT_MUTANT As Integer = 2
Const PAT_HUMAN  As Integer = 3
Const PAT_BOLT   As Integer = 4

' Hardware Sprite Slot Allocations
' Slot 0: Player
' Slots 1..4: Player Lasers
' Slots 5..12: Humanoids (8)
' Slots 13..22: Enemies (10)
' Slots 23..28: Enemy Shots (6)
Const SLOT_PLAYER As Integer = 0
Const SLOT_LASER0 As Integer = 1
Const SLOT_HUMAN0 As Integer = 5
Const SLOT_ENEMY0 As Integer = 13
Const SLOT_SHOT0  As Integer = 23

' Entity Counts
Const MAX_LASERS As Integer = 4
Const MAX_HUMANS As Integer = 8
Const MAX_ENEMIES As Integer = 10
Const MAX_SHOTS As Integer = 6

' States
Const ST_DEAD As Integer = 0
Const ST_WANDER As Integer = 1
Const ST_DESCEND As Integer = 2
Const ST_ABDUCT As Integer = 3
Const ST_MUTANT As Integer = 4

Const H_DEAD As Integer = 0
Const H_GROUND As Integer = 1
Const H_GRABBED As Integer = 2
Const H_FALLING As Integer = 3
Const H_CARRIED As Integer = 4

' Player State
Dim px As Integer, py As Integer
Dim pvx As Integer, pvy As Integer
Dim pdir As Integer
Dim old_prx As Integer, old_pry As Integer

Dim score As Integer
Dim lives As Integer
Dim bombs As Integer
Dim wave As Integer
Dim game_over As Boolean
Dim planet_dead As Boolean
Dim fire_cd As Integer
Dim bomb_cd As Integer
Dim hyper_cd As Integer
Dim flash_bg As Integer

' Lasers
Dim lx(MAX_LASERS) As Integer
Dim ly(MAX_LASERS) As Integer
Dim lvx(MAX_LASERS) As Integer
Dim llife(MAX_LASERS) As Integer

' Humanoids
Dim hx(MAX_HUMANS) As Integer
Dim hy(MAX_HUMANS) As Integer
Dim hstate(MAX_HUMANS) As Integer
Dim hcarrier(MAX_HUMANS) As Integer
Dim old_hrx(MAX_HUMANS) As Integer
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

' Terrain Streaming State (8 slices across 256px screen)
Dim ter_step As Integer
Dim old_ty0(8) As Integer
Dim old_ty1(8) As Integer

' ============================================================================
' ZX SPECTRUM NEXT HARDWARE REGISTER & SPRITE HELPERS
' ============================================================================

Sub WriteNextReg(reg As Integer, val As Integer)
    Out PORT_NEXTREG_SEL, reg
    Out PORT_NEXTREG_DAT, val
End Sub

' Loads DEFENDER.SPR (512B 9-bit palette + 5x 256B 16x16 8-bit sprites)
Sub LoadSpriteTilemap(filename As String)
    Dim i As Integer, b0 As Byte, b1 As Byte
    Dim p As Integer, x As Integer, y As Integer, dx As Integer, dy As Integer

    ' Enable Sprites Visible (bit 0) + Sprites Over Border (bit 1), SLU order
    WriteNextReg(&H15, &H03)
    ' Sprite transparency index = 0
    WriteNextReg(&H4B, &H00)

    ' Select Sprite First Palette for writing (bits 6..4 = 010 -> &H20)
    WriteNextReg(&H43, &H20)
    WriteNextReg(&H40, 0)

    If Exists(filename) Then
        Open filename For Binary As #1
        ' 1. Upload 256-colour 9-bit palette (512 bytes -> NextReg &H44)
        For i = 1 To 256
            Get #1, , b0
            Get #1, , b1
            WriteNextReg(&H44, b0)
            WriteNextReg(&H44, b1)
        Next i

        ' 2. Upload 5 x 16x16 8-bit sprite patterns (1280 bytes -> Port &H5B)
        Out PORT_SPRITE_SLOT, 0
        For i = 1 To 1280
            Get #1, , b0
            Out PORT_SPRITE_PAT, b0
        Next i
        Close #1
    Else
        ' Fallback procedural 9-bit palette + 16x16 patterns if file not attached
        WriteNextReg(&H44, 0) : WriteNextReg(&H44, 0)     ' 0: Transparent
        WriteNextReg(&H44, &HFF) : WriteNextReg(&H44, 1)  ' 1: White
        WriteNextReg(&H44, &HFC) : WriteNextReg(&H44, 0)  ' 2: Yellow
        WriteNextReg(&H44, &HF0) : WriteNextReg(&H44, 0)  ' 3: Orange
        WriteNextReg(&H44, &HE0) : WriteNextReg(&H44, 0)  ' 4: Red
        WriteNextReg(&H44, &HE2) : WriteNextReg(&H44, 1)  ' 5: Magenta
        WriteNextReg(&H44, &H1C) : WriteNextReg(&H44, 0)  ' 6: Green
        WriteNextReg(&H44, &H17) : WriteNextReg(&H44, 1)  ' 7: Cyan
        For i = 8 To 255
            WriteNextReg(&H44, i)
            WriteNextReg(&H44, 0)
        Next i

        Out PORT_SPRITE_SLOT, 0
        For p = 0 To 4
            For y = 0 To 15
                For x = 0 To 15
                    b0 = 0
                    dx = Abs(x - 7) : dy = Abs(y - 7)
                    If p = PAT_PLAYER Then
                        If y >= 5 And y <= 10 And x <= 14 And dy <= (15 - x) \ 2 Then b0 = 7
                        If y = 7 And x >= 10 Then b0 = 1
                        If x < 3 And dy <= 1 Then b0 = 3
                    ElseIf p = PAT_LANDER Then
                        If dx + dy <= 6 Then b0 = 6
                        If dy = 1 And (x = 5 Or x = 10) Then b0 = 1
                    ElseIf p = PAT_MUTANT Then
                        If dx = dy Or (dx <= 4 And dy <= 4) Then b0 = 4
                        If dx <= 2 And dy <= 2 Then b0 = 2
                    ElseIf p = PAT_HUMAN Then
                        If dx <= 1 And y >= 3 And y <= 5 Then b0 = 1
                        If dx <= 2 And y >= 6 And y <= 12 Then b0 = 5
                    ElseIf p = PAT_BOLT Then
                        If y >= 7 And y <= 8 And x >= 2 And x <= 13 Then b0 = 2
                    End If
                    Out PORT_SPRITE_PAT, b0
                Next x
            Next y
        Next p
    End If
End Sub

' Updates a hardware sprite slot (px_scr in 0..255 Layer 2 coords, py_scr in 0..191)
Sub SetHardwareSprite(slot As Integer, px_scr As Integer, py_scr As Integer, pat As Integer, hflip As Boolean, visible As Boolean)
    Dim sx As Integer, sy As Integer, attr2 As Integer
    Out PORT_SPRITE_SLOT, slot
    If Not visible Then
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Out PORT_SPRITE_ATTR, 0
        Exit Sub
    End If

    ' Convert Layer 2 (256x192, bottom-left Y in NTC) to Next Sprite Coords (+32 border, top-down Y)
    sx = px_scr + SPR_X_OFF - 8
    sy = (191 - py_scr) + SPR_Y_OFF - 8

    attr2 = (sx >> 8) And 1
    If hflip Then attr2 = attr2 Or 8

    Out PORT_SPRITE_ATTR, sx And 255
    Out PORT_SPRITE_ATTR, sy And 255
    Out PORT_SPRITE_ATTR, attr2
    ' Bit 7 = Visible (128), Bit 6 = 5-byte extended attribute (64)
    Out PORT_SPRITE_ATTR, 192 Or (pat And 63)
    ' 5th attribute byte = 0 (8-bit 256-colour pattern, no scaling)
    Out PORT_SPRITE_ATTR, 0
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

Function GetTerrainY(wx As Integer) As Integer
    Dim p As Integer, h As Integer
    p = (wx \ 4) And 63
    If p < 16 Then
        h = 10 + p
    ElseIf p < 32 Then
        h = 26 - (p - 16)
    ElseIf p < 40 Then
        h = 10 + (p - 32) * 2
    ElseIf p < 48 Then
        h = 26 - (p - 40) * 2
    Else
        h = 10
    End If
    If planet_dead Then h = 6
    Return h
End Function

Function WorldToScreenX(wx As Integer, cam_x As Integer) As Integer
    Dim d As Integer
    d = (wx - cam_x) And WORLD_MASK
    If d >= 512 Then d = d - 1024
    Return d
End Function

Function WorldToRadarX(wx As Integer) As Integer
    Dim rel As Integer
    rel = (wx - px + 512) And WORLD_MASK
    Return 64 + (rel \ 8)
End Function

Sub UpdateHUD()
    Pen 15
    Locate 1, 1
    Print "SC:"; score; " ";
    Pen 14
    Locate 12, 1
    Print "L:"; lives; " B:"; bombs;
    Pen 11
    Locate 26, 1
    Print "W:"; wave;
End Sub

Sub DrawStaticFrame()
    Cls
    ' Scanner divider and radar box (x = 62..193, y = 152..183 in bottom-up Layer 2 coords)
    Plot 0, 150, 9
    Draw 255, 150, 9
    Plot 62, 152, 12
    Draw 193, 152, 12
    Draw 193, 182, 12
    Draw 62, 182, 12
    Draw 62, 152, 12
    UpdateHUD()
End Sub

' ============================================================================
' WAVE & ENTITY MANAGEMENT
' ============================================================================

Sub InitWave()
    Dim i As Integer
    HideAllSprites()
    DrawStaticFrame()

    px = 512
    py = 96
    pvx = 0
    pvy = 0
    pdir = 1
    old_prx = 128
    old_pry = 165

    For i = 0 To MAX_LASERS - 1
        llife(i) = 0
    Next i

    For i = 0 To MAX_SHOTS - 1
        slife(i) = 0
    Next i

    If wave = 1 Then
        planet_dead = False
        humans_alive = MAX_HUMANS
        For i = 0 To MAX_HUMANS - 1
            hx(i) = (i * 128 + 48) And WORLD_MASK
            hy(i) = GetTerrainY(hx(i)) + 6
            hstate(i) = H_GROUND
            hcarrier(i) = -1
            old_hrx(i) = 0
        Next i
    Else
        For i = 0 To MAX_HUMANS - 1
            old_hrx(i) = 0
            If hstate(i) <> H_DEAD Then
                hstate(i) = H_GROUND
                hcarrier(i) = -1
                hy(i) = GetTerrainY(hx(i)) + 6
            End If
        Next i
    End If

    For i = 0 To MAX_ENEMIES - 1
        estate(i) = ST_DEAD
        old_erx(i) = 0
    Next i

    enemies_to_spawn = 6 + wave * 2
    If enemies_to_spawn > MAX_ENEMIES Then enemies_to_spawn = MAX_ENEMIES
    enemies_alive = 0
    spawn_timer = 10

    For i = 0 To 4
        SpawnEnemy()
    Next i

    For i = 0 To 7
        old_ty0(i) = -1
    Next i
    ter_step = 0
    UpdateHUD()
End Sub

Sub SpawnEnemy()
    Dim i As Integer
    If enemies_to_spawn <= 0 Then Exit Sub
    For i = 0 To MAX_ENEMIES - 1
        If estate(i) = ST_DEAD Then
            ex(i) = (px + 250 + Rnd(500)) And WORLD_MASK
            ey(i) = 130 + Rnd(15)
            If Rnd(2) = 0 Then evx(i) = 2 Else evx(i) = -2
            evy(i) = -1
            If planet_dead Then
                estate(i) = ST_MUTANT
            Else
                estate(i) = ST_WANDER
            End If
            etarget(i) = -1
            old_erx(i) = 0
            enemies_alive = enemies_alive + 1
            enemies_to_spawn = enemies_to_spawn - 1
            Exit Sub
        End If
    Next i
End Sub

Sub FireLaser()
    Dim i As Integer
    For i = 0 To MAX_LASERS - 1
        If llife(i) = 0 Then
            lx(i) = (px + pdir * 12) And WORLD_MASK
            ly(i) = py
            lvx(i) = pdir * 20 + pvx
            llife(i) = 12
            Sound 1, 110, 4, 12
            Exit Sub
        End If
    Next i
End Sub

Sub KillEnemy(idx As Integer)
    Dim h As Integer
    SetHardwareSprite(SLOT_ENEMY0 + idx, 0, 0, 0, False, False)
    If old_erx(idx) > 0 Then
        Plot old_erx(idx), old_ery(idx), 0
        old_erx(idx) = 0
    End If

    h = etarget(idx)
    If h >= 0 And h < MAX_HUMANS Then
        If hstate(h) = H_GRABBED And hcarrier(h) = idx Then
            hstate(h) = H_FALLING
            hcarrier(h) = -1
        End If
    End If

    estate(idx) = ST_DEAD
    enemies_alive = enemies_alive - 1
    Sound 2, 260, 6, 14
End Sub

Sub TriggerSmartBomb(cam_x As Integer)
    Dim i As Integer, sx_pos As Integer
    If bombs <= 0 Then Exit Sub
    bombs = bombs - 1
    bomb_cd = 20
    Sound 1, 380, 15, 15
    Border 7
    flash_bg = 4

    For i = 0 To MAX_ENEMIES - 1
        If estate(i) <> ST_DEAD Then
            sx_pos = WorldToScreenX(ex(i), cam_x)
            If sx_pos >= -16 And sx_pos <= 272 Then
                KillEnemy(i)
                score = score + 15
            End If
        End If
    Next i
    UpdateHUD()
End Sub

Sub LoseLife()
    Dim i As Integer
    Sound 1, 750, 25, 15
    Border 2
    For i = 1 To 25
        Vsync
    Next i
    Border 0

    lives = lives - 1
    If lives <= 0 Then
        HideAllSprites()
        game_over = True
    Else
        For i = 0 To MAX_HUMANS - 1
            If hstate(i) = H_CARRIED Then
                hstate(i) = H_FALLING
            End If
        Next i
        InitWave()
    End If
End Sub

' ============================================================================
' MAIN PROGRAM ENTRY
' ============================================================================

Border 0
Paper 0
Pen 15
Cls

' Load replaceable 16x16 9-bit palette sprite sheet
LoadSpriteTilemap("DEFENDER.SPR")

Do
    HideAllSprites()
    Cls
    Pen 14
    Locate 8, 4
    Print "D E F E N D E R"
    Pen 11
    Locate 4, 6
    Print "ZX SPECTRUM NEXT EDITION"
    Pen 15
    Locate 4, 10
    Print "Q / A or UP/DN : ALTITUDE"
    Locate 4, 12
    Print "O / P or LT/RT : THRUST"
    Locate 4, 14
    Print "SPACE / FIRE 1 : LASER"
    Locate 4, 16
    Print "B / M / FIRE 2 : SMART BOMB"
    Locate 4, 18
    Print "H              : HYPERSPACE"
    Pen 10
    Locate 5, 22
    Print "PRESS SPACE OR FIRE"

    ' Display preview sprites on the title screen
    SetHardwareSprite(0, 70, 52, PAT_PLAYER, False, True)
    SetHardwareSprite(1, 110, 52, PAT_LANDER, False, True)
    SetHardwareSprite(2, 150, 52, PAT_MUTANT, False, True)
    SetHardwareSprite(3, 190, 52, PAT_HUMAN, False, True)

    Do
        Vsync
    Loop Until Key(40) Or (Joy(0) And 16) <> 0

    score = 0
    lives = 3
    bombs = 3
    wave = 1
    game_over = False
    InitWave()

    Do While Not game_over
        Vsync
        If flash_bg > 0 Then
            flash_bg = flash_bg - 1
            If flash_bg = 0 Then Border 0
        End If

        ' --------------------------------------------------------------------
        ' 1. ZX SPECTRUM NEXT INPUT (KEYBOARD + KEMPSTON JOYSTICK)
        ' --------------------------------------------------------------------
        Dim j As Integer
        j = Joy(0)

        ' Up: Q (3) or Joy Up (8) | Down: A (2) or Joy Down (4)
        If Key(3) Or (j And 8) <> 0 Then
            pvy = 3
        ElseIf Key(2) Or (j And 4) <> 0 Then
            pvy = -3
        Else
            pvy = 0
        End If

        ' Left: O (33) or Joy Left (2) | Right: P (32) or Joy Right (1)
        If Key(33) Or (j And 2) <> 0 Then
            pdir = -1
            If pvx > -12 Then pvx = pvx - 1
        ElseIf Key(32) Or (j And 1) <> 0 Then
            pdir = 1
            If pvx < 12 Then pvx = pvx + 1
        Else
            If pvx > 0 Then pvx = pvx - 1
            If pvx < 0 Then pvx = pvx + 1
        End If

        px = (px + pvx) And WORLD_MASK
        py = py + pvy
        If py < PLAY_TOP Then py = PLAY_TOP
        If py > PLAY_BOT - 12 Then py = PLAY_BOT - 12

        Dim cam_x As Integer, psx As Integer
        psx = 128 - pdir * 40
        cam_x = (px - psx) And WORLD_MASK

        ' Fire Laser: Space (40), Z (9), or Joy Fire 1 (16)
        If fire_cd > 0 Then fire_cd = fire_cd - 1
        If (Key(40) Or Key(9) Or (j And 16) <> 0) And fire_cd = 0 Then
            FireLaser()
            fire_cd = 4
        End If

        ' Smart Bomb: B (36), M (34), or Joy Fire 2 (32)
        If bomb_cd > 0 Then bomb_cd = bomb_cd - 1
        If (Key(36) Or Key(34) Or (j And 32) <> 0) And bomb_cd = 0 Then
            TriggerSmartBomb(cam_x)
        End If

        ' Hyperspace: H (38)
        If hyper_cd > 0 Then hyper_cd = hyper_cd - 1
        If Key(38) And hyper_cd = 0 Then
            Plot old_prx, old_pry, 0
            px = Rnd(WORLD_W)
            py = 50 + Rnd(85)
            pvx = 0
            hyper_cd = 30
            Sound 1, 550, 8, 13
        End If

        ' --------------------------------------------------------------------
        ' 2. UPDATE PLAYER HARDWARE SPRITE & RADAR PIP
        ' --------------------------------------------------------------------
        SetHardwareSprite(SLOT_PLAYER, psx, py, PAT_PLAYER, (pdir < 0), True)

        Plot old_prx, old_pry, 0
        old_prx = 128
        old_pry = 154 + (py \ 7)
        Plot old_prx, old_pry, 15

        ' --------------------------------------------------------------------
        ' 3. UPDATE LASER HARDWARE SPRITES
        ' --------------------------------------------------------------------
        Dim i As Integer, lsx As Integer
        For i = 0 To MAX_LASERS - 1
            If llife(i) > 0 Then
                lx(i) = (lx(i) + lvx(i)) And WORLD_MASK
                llife(i) = llife(i) - 1
                lsx = WorldToScreenX(lx(i), cam_x)
                If llife(i) > 0 And lsx >= 0 And lsx <= 255 Then
                    SetHardwareSprite(SLOT_LASER0 + i, lsx, ly(i), PAT_BOLT, (lvx(i) < 0), True)
                Else
                    llife(i) = 0
                    SetHardwareSprite(SLOT_LASER0 + i, 0, 0, 0, False, False)
                End If
            Else
                SetHardwareSprite(SLOT_LASER0 + i, 0, 0, 0, False, False)
            End If
        Next i

        ' --------------------------------------------------------------------
        ' 4. UPDATE HUMANOID HARDWARE SPRITES & RADAR PIPS
        ' --------------------------------------------------------------------
        Dim hsx As Integer, hrx As Integer, t_ground As Integer
        For i = 0 To MAX_HUMANS - 1
            If old_hrx(i) > 0 Then
                Plot old_hrx(i), 154, 0
                old_hrx(i) = 0
            End If

            If hstate(i) <> H_DEAD Then
                If hstate(i) = H_CARRIED Then
                    hx(i) = px
                    hy(i) = py - 10
                    t_ground = GetTerrainY(hx(i)) + 6
                    If hy(i) <= t_ground Then
                        hy(i) = t_ground
                        hstate(i) = H_GROUND
                        score = score + 50
                        Sound 1, 90, 8, 14
                        UpdateHUD()
                    End If
                ElseIf hstate(i) = H_FALLING Then
                    hy(i) = hy(i) - 1
                    If Abs(WorldToScreenX(hx(i), cam_x) - psx) < 12 And Abs(hy(i) - py) < 12 Then
                        hstate(i) = H_CARRIED
                        score = score + 50
                        Sound 1, 110, 6, 14
                        UpdateHUD()
                    Else
                        t_ground = GetTerrainY(hx(i)) + 6
                        If hy(i) <= t_ground Then
                            hy(i) = t_ground
                            hstate(i) = H_GROUND
                            score = score + 25
                            UpdateHUD()
                        End If
                    End If
                End If

                hsx = WorldToScreenX(hx(i), cam_x)
                If hsx >= -8 And hsx <= 263 Then
                    SetHardwareSprite(SLOT_HUMAN0 + i, hsx, hy(i), PAT_HUMAN, False, True)
                Else
                    SetHardwareSprite(SLOT_HUMAN0 + i, 0, 0, 0, False, False)
                End If

                hrx = WorldToRadarX(hx(i))
                Plot hrx, 154, 13
                old_hrx(i) = hrx
            Else
                SetHardwareSprite(SLOT_HUMAN0 + i, 0, 0, 0, False, False)
            End If
        Next i

        ' --------------------------------------------------------------------
        ' 5. UPDATE ENEMY HARDWARE SPRITES & AI
        ' --------------------------------------------------------------------
        If spawn_timer > 0 Then
            spawn_timer = spawn_timer - 1
        ElseIf enemies_to_spawn > 0 And enemies_alive < 7 Then
            SpawnEnemy()
            spawn_timer = 40
        End If

        Dim esx As Integer, erx As Integer, ery As Integer, epat As Integer, ecol As Integer
        Dim th As Integer, dx_h As Integer, l_idx As Integer, hit As Boolean

        For i = 0 To MAX_ENEMIES - 1
            If old_erx(i) > 0 Then
                Plot old_erx(i), old_ery(i), 0
                old_erx(i) = 0
            End If

            If estate(i) <> ST_DEAD Then
                If estate(i) = ST_WANDER Then
                    ex(i) = (ex(i) + evx(i)) And WORLD_MASK
                    ey(i) = ey(i) + evy(i)
                    If ey(i) < 65 Then evy(i) = 1
                    If ey(i) > 138 Then evy(i) = -1

                    If Rnd(20) = 0 And humans_alive > 0 Then
                        th = Rnd(MAX_HUMANS)
                        If hstate(th) = H_GROUND Then
                            etarget(i) = th
                            estate(i) = ST_DESCEND
                        End If
                    End If

                ElseIf estate(i) = ST_DESCEND Then
                    th = etarget(i)
                    If th < 0 Or hstate(th) <> H_GROUND Then
                        estate(i) = ST_WANDER
                    Else
                        dx_h = WorldToScreenX(hx(th), ex(i))
                        If dx_h > 2 Then
                            ex(i) = (ex(i) + 2) And WORLD_MASK
                        ElseIf dx_h < -2 Then
                            ex(i) = (ex(i) - 2) And WORLD_MASK
                        Else
                            If ey(i) > hy(th) + 8 Then
                                ey(i) = ey(i) - 2
                            Else
                                hstate(th) = H_GRABBED
                                hcarrier(th) = i
                                estate(i) = ST_ABDUCT
                                Sound 2, 480, 5, 12
                            End If
                        End If
                    End If

                ElseIf estate(i) = ST_ABDUCT Then
                    th = etarget(i)
                    If th < 0 Or hstate(th) <> H_GRABBED Then
                        estate(i) = ST_WANDER
                    Else
                        ey(i) = ey(i) + 1
                        hx(th) = ex(i)
                        hy(th) = ey(i) - 10
                        If ey(i) >= 142 Then
                            hstate(th) = H_DEAD
                            humans_alive = humans_alive - 1
                            estate(i) = ST_MUTANT
                            Sound 1, 70, 15, 15
                            If humans_alive <= 0 And Not planet_dead Then
                                planet_dead = True
                                Border 2
                                flash_bg = 6
                            End If
                        End If
                    End If

                ElseIf estate(i) = ST_MUTANT Then
                    dx_h = WorldToScreenX(px, ex(i))
                    If dx_h > 0 Then
                        ex(i) = (ex(i) + 3) And WORLD_MASK
                    Else
                        ex(i) = (ex(i) - 3) And WORLD_MASK
                    End If
                    If ey(i) < py Then
                        ey(i) = ey(i) + 2
                    ElseIf ey(i) > py Then
                        ey(i) = ey(i) - 2
                    End If
                End If

                ' Laser Collision Check
                hit = False
                esx = WorldToScreenX(ex(i), cam_x)
                For l_idx = 0 To MAX_LASERS - 1
                    If llife(l_idx) > 0 Then
                        lsx = WorldToScreenX(lx(l_idx), cam_x)
                        If Abs(esx - lsx) < 12 And Abs(ey(i) - ly(l_idx)) < 10 Then
                            llife(l_idx) = 0
                            SetHardwareSprite(SLOT_LASER0 + l_idx, 0, 0, 0, False, False)
                            KillEnemy(i)
                            score = score + 15
                            UpdateHUD()
                            hit = True
                            Exit For
                        End If
                    End If
                Next l_idx

                If Not hit Then
                    If Abs(esx - psx) < 10 And Abs(ey(i) - py) < 10 Then
                        KillEnemy(i)
                        LoseLife()
                        Exit For
                    End If

                    ' Enemy Shoots
                    If esx >= 12 And esx <= 244 And Rnd(35) = 0 Then
                        Dim s_idx As Integer
                        For s_idx = 0 To MAX_SHOTS - 1
                            If slife(s_idx) = 0 Then
                                sx(s_idx) = ex(i)
                                sy(s_idx) = ey(i)
                                If psx > esx Then svx(s_idx) = 5 Else svx(s_idx) = -5
                                If py > ey(i) Then svy(s_idx) = 2 Else svy(s_idx) = -2
                                slife(s_idx) = 24
                                Exit For
                            End If
                        Next s_idx
                    End If

                    If estate(i) = ST_MUTANT Then
                        epat = PAT_MUTANT
                        ecol = 10
                    Else
                        epat = PAT_LANDER
                        ecol = 12
                    End If

                    If esx >= -8 And esx <= 263 Then
                        SetHardwareSprite(SLOT_ENEMY0 + i, esx, ey(i), epat, False, True)
                    Else
                        SetHardwareSprite(SLOT_ENEMY0 + i, 0, 0, 0, False, False)
                    End If

                    erx = WorldToRadarX(ex(i))
                    ery = 154 + (ey(i) \ 7)
                    Plot erx, ery, ecol
                    old_erx(i) = erx
                    old_ery(i) = ery
                End If
            Else
                SetHardwareSprite(SLOT_ENEMY0 + i, 0, 0, 0, False, False)
            End If
        Next i

        ' --------------------------------------------------------------------
        ' 6. UPDATE ENEMY PROJECTILE HARDWARE SPRITES
        ' --------------------------------------------------------------------
        Dim ssx As Integer
        For i = 0 To MAX_SHOTS - 1
            If slife(i) > 0 Then
                sx(i) = (sx(i) + svx(i)) And WORLD_MASK
                sy(i) = sy(i) + svy(i)
                slife(i) = slife(i) - 1
                ssx = WorldToScreenX(sx(i), cam_x)
                If slife(i) > 0 And ssx >= 0 And ssx <= 255 And sy(i) > PLAY_TOP And sy(i) < PLAY_BOT Then
                    If Abs(ssx - psx) < 8 And Abs(sy(i) - py) < 8 Then
                        slife(i) = 0
                        SetHardwareSprite(SLOT_SHOT0 + i, 0, 0, 0, False, False)
                        LoseLife()
                        Exit For
                    End If
                    SetHardwareSprite(SLOT_SHOT0 + i, ssx, sy(i), PAT_BOLT, False, True)
                Else
                    slife(i) = 0
                    SetHardwareSprite(SLOT_SHOT0 + i, 0, 0, 0, False, False)
                End If
            Else
                SetHardwareSprite(SLOT_SHOT0 + i, 0, 0, 0, False, False)
            End If
        Next i

        ' --------------------------------------------------------------------
        ' 7. LAYER 2 TERRAIN STREAMING (8 SLICES ACROSS 256 PIXELS)
        ' --------------------------------------------------------------------
        Dim tx0 As Integer, tx1 As Integer, ty0 As Integer, ty1 As Integer
        tx0 = ter_step * 32
        tx1 = tx0 + 32
        If tx1 > 255 Then tx1 = 255

        If old_ty0(ter_step) >= 0 Then
            Plot tx0, old_ty0(ter_step), 0
            Draw tx1, old_ty1(ter_step), 0
        End If

        ty0 = GetTerrainY((cam_x + tx0) And WORLD_MASK)
        ty1 = GetTerrainY((cam_x + tx1) And WORLD_MASK)
        Plot tx0, ty0, 12
        Draw tx1, ty1, 12
        old_ty0(ter_step) = ty0
        old_ty1(ter_step) = ty1
        ter_step = (ter_step + 1) And 7

        ' --------------------------------------------------------------------
        ' 8. WAVE COMPLETION
        ' --------------------------------------------------------------------
        If enemies_alive <= 0 And enemies_to_spawn <= 0 Then
            wave = wave + 1
            score = score + humans_alive * 50
            If bombs < 5 Then bombs = bombs + 1
            Sound 1, 150, 15, 15
            Sound 2, 100, 15, 15
            InitWave()
        End If
    Loop

    ' Game Over Screen
    HideAllSprites()
    Cls
    Pen 10
    Locate 8, 9
    Print "G A M E   O V E R"
    Pen 15
    Locate 7, 12
    Print "FINAL SCORE: "; score
    Pen 14
    Locate 7, 15
    Print "REACHED WAVE: "; wave
    For i = 1 To 90
        Vsync
    Next i
Loop