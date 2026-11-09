' Play - HAVE A PLAY WITH ZOSCII: type a message, choose how it is encoded, then attack it, decode it or tamper with it.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Public mes(39) As Byte, mn As Integer
Private nl As Integer                      ' layers, 1 to 3
Private lp(2) As Integer                  ' protocol of layer n+1, layer 0 the INSIDE (encoded first), the last the OUTSIDE (0 ZOSCII, 1 UNSIGNAL)
Private hs As Integer                     ' rolling hash on the outside layer
Private pool As Integer                   ' 0 128K (recommended), 1 64K, 2 2K
Private row As Integer
Private kn(26) As Byte, kc(26) As Byte, kd(26) As Integer
Private k0 As Integer, ke As Integer
Private tampered As Integer

Private Sub InitKeys()
  kn(0) = Keys.KeyQ : kc(0) = 81
  kn(1) = Keys.KeyW : kc(1) = 87
  kn(2) = Keys.KeyE : kc(2) = 69
  kn(3) = Keys.KeyR : kc(3) = 82
  kn(4) = Keys.KeyT : kc(4) = 84
  kn(5) = Keys.KeyY : kc(5) = 89
  kn(6) = Keys.KeyU : kc(6) = 85
  kn(7) = Keys.KeyI : kc(7) = 73
  kn(8) = Keys.KeyO : kc(8) = 79
  kn(9) = Keys.KeyP : kc(9) = 80
  kn(10) = Keys.KeyA : kc(10) = 65
  kn(11) = Keys.KeyS : kc(11) = 83
  kn(12) = Keys.KeyD : kc(12) = 68
  kn(13) = Keys.KeyF : kc(13) = 70
  kn(14) = Keys.KeyG : kc(14) = 71
  kn(15) = Keys.KeyH : kc(15) = 72
  kn(16) = Keys.KeyJ : kc(16) = 74
  kn(17) = Keys.KeyK : kc(17) = 75
  kn(18) = Keys.KeyL : kc(18) = 76
  kn(19) = Keys.KeyZ : kc(19) = 90
  kn(20) = Keys.KeyX : kc(20) = 88
  kn(21) = Keys.KeyC : kc(21) = 67
  kn(22) = Keys.KeyV : kc(22) = 86
  kn(23) = Keys.KeyB : kc(23) = 66
  kn(24) = Keys.KeyN : kc(24) = 78
  kn(25) = Keys.KeyM : kc(25) = 77
  kn(26) = Keys.KeySpace : kc(26) = 32
End Sub

' Seed: remember which keys are down now, so a key held from before doesn't type
Private Sub Seed()
  Dim i As Integer
  For i = 0 To 26
    kd(i) = Keys.Down(kn(i))
  Next
  k0 = Keys.Down(Keys.Key0)
  ke = Keys.Down(Keys.KeyEnter)
End Sub

' TypeKey: the character newly typed (8 delete, 13 enter), 0 if none
Private Function TypeKey() As Integer
  Dim i As Integer, d As Integer, r As Integer
  r = 0
  For i = 0 To 26
    d = Keys.Down(kn(i))
    If d <> 0 And kd(i) = 0 Then r = kc(i)
    kd(i) = d
  Next
  d = Keys.Down(Keys.Key0)
  If d <> 0 And k0 = 0 Then r = 8
  k0 = d
  d = Keys.Down(Keys.KeyEnter)
  If d <> 0 And ke = 0 Then r = 13
  ke = d
  TypeKey = r
End Function

Private Sub ShowMsg(ByVal y As Integer, ByVal cur As Integer)
  Dim i As Integer
  Vid.Fill 0, y, 320, 10, 5
  For i = 0 To mn - 1
    Vid.Glyph 8 + i * 6, y, mes(i), 10
  Next
  If cur <> 0 Then Vid.Fill 8 + mn * 6, y, 5, 8, 1
End Sub

' Line y, mx: type a line of capitals and spaces into mes at row y, at most mx characters, Enter ends it (8 / 0 delete)
Public Sub Line(ByVal y As Integer, ByVal mx As Integer)
  Dim c As Integer, t As Integer
  InitKeys
  Seed
  t = 0
  ShowMsg y, 1
  Do
    Vid.Sync
    t = t + 1
    c = TypeKey()
    If c = 13 Then Exit Do
    If c = 8 And mn > 0 Then
      mn = mn - 1
      ShowMsg y, 1
    End If
    If c >= 32 And mn < mx Then
      mes(mn) = c
      mn = mn + 1
      ShowMsg y, 1
    End If
    If (t And 15) = 0 Then ShowMsg y, (t \ 16) And 1
  Loop
  ShowMsg y, 0
  If mn = 0 Then
    mes(0) = 65
    mn = 1
  End If
End Sub

Private Sub TypeMsg()
  Vid.Page Data.TX_PL_T, Data.TX_PL_TYPE
  Vid.Txt 8, 34, Data.TX_PL_MSG, 3
  Line 50, 40
End Sub

' RowId(i): the setup rows shown are message, layers, one per layer, rolling hash, pool: ids 0 msg, 1 layers, 2-4 layer protocols, 5 hash, 6 pool
Private Function RowId(ByVal i As Integer) As Integer
  If i < 2 + nl Then
    RowId = i
  Else
    RowId = i + 3 - nl
  End If
End Function

' PName(p): the text of protocol p (0 ZOSCII, 1 UNSIGNAL, 2 BRICS, 3 microZOSCII, 4 microUNSIGNAL, 5 microBRICS)
Private Function PName(ByVal p As Integer) As Integer
  Select Case p
    Case 0
      PName = Data.TX_D_PZ
    Case 1
      PName = Data.TX_D_PU
    Case 2
      PName = Data.TX_D_PB
    Case 3
      PName = Data.TX_D_PMZ
    Case 4
      PName = Data.TX_D_PMU
    Case Else
      PName = Data.TX_D_PMB
  End Select
End Function

Private Sub Setup()
  Dim i As Integer, c As Integer, y As Integer, a As Integer, id As Integer
  Vid.Page Data.TX_PL_T, Data.TX_PL_KEYS
  For i = 0 To 3 + nl
    y = 34 + i * 16
    c = 2
    If i = row Then
      c = 10
      Vid.Fill 4, y - 3, 312, 14, 6
    End If
    id = RowId(i)
    Select Case id
      Case 0
        Vid.Txt 12, y, Data.TX_PL_MSG, c
        For a = 0 To mn - 1
          Vid.Glyph 112 + a * 6, y, mes(a), 1
        Next
      Case 1
        Vid.Txt 12, y, Data.TX_PL_LAYERS, c
        Vid.Num 160, y, nl, 1, 1
      Case 5
        Vid.Txt 12, y, Data.TX_PL_RH, c
        If hs = 0 Then
          Vid.Txt 160, y, Data.TX_PL_OFF, 1
        Else
          Vid.Txt 160, y, Data.TX_PL_ON, 1
        End If
      Case 6
        Vid.Txt 12, y, Data.TX_PL_POOL, c
        Select Case pool
          Case 0
            Vid.Txt 160, y, Data.TX_PL_P128, 1
          Case 1
            Vid.Txt 160, y, Data.TX_PL_P64, 1
          Case Else
            Vid.Txt 160, y, Data.TX_PL_P2, 1
        End Select
      Case Else
        Vid.Txt 12, y, Data.TX_PL_LAYN, c
        Vid.Num 56, y, id - 1, 1, c
        If id - 1 = nl Then Vid.Txt 68, y, Data.TX_PL_OUT, c
        Vid.Txt 160, y, PName(lp(id - 2)), 1
    End Select
  Next
  Vid.Txt 8, 150, Data.TX_PL_NOTE, 3
End Sub

' Encode: the message becomes a file in the scratch block. Returns 1, or 0 with a message on the screen.
Private Function Encode() As Integer
  Dim i As Integer, l As Integer, c As Integer, win As Integer, rb As Integer, bad As Integer, pm As Integer, n As Integer
  Vid.Fill 0, 200, 320, 36, 5
  Vid.Txt 8, 210, Data.TX_PL_WORK, 10
  For i = 0 To mn - 1
    Rom.Wp i, mes(i)
  Next
  Rom.Wn = mn
  For i = 0 To mn - 1
    Rng.Mix mes(i)
  Next
  Rng.Reseed
  bad = 0
  For l = 0 To nl - 1
    If pool <> 0 And (lp(l) = 1 Or lp(l) = 2) Then bad = -3
  Next
  If pool = 2 And nl > 1 Then bad = -4
  If bad <> 0 Then
    Vid.Fill 0, 200, 320, 36, 5
    If bad = -3 Then Vid.Txt 8, 210, Data.TX_PL_N128, 12 Else Vid.Txt 8, 210, Data.TX_PL_N2K, 12
    Encode = 0
    Exit Function
  End If
  Rom.MakeMic
  For l = 0 To nl - 1
    n = l
    If l = nl - 1 And hs <> 0 Then
      Rom.RollHash 0, Rom.Wn
      For i = Rom.Wn - 1 To 0 Step -1
        Rom.Wp i + 4, Rom.Wg(i)
      Next
      For i = 0 To 3
        Rom.Wp i, Rom.HB(i)
      Next
      Rom.Wn = Rom.Wn + 4
    End If
    rb = Rom.RomBlock(l)
    win = 0
    If pool = 2 Then
      rb = Rom.RomBlock(3)
      win = 2048
    End If
    pm = 255
    If nl > 1 Then pm = 70
    c = Rom.Enc(rb, lp(n), win, pm)
    If c < 0 Then
      bad = c
      Exit For
    End If
    Rom.Take c
  Next
  If bad <> 0 Then
    Vid.Fill 0, 200, 320, 36, 5
    If bad = -1 Then
      Vid.Txt 8, 210, Data.TX_PL_NOTIN, 12
    Else
      Vid.Txt 8, 210, Data.TX_PL_BIGF, 12
    End If
    Encode = 0
    Exit Function
  End If
  Rom.SxSave
  Rom.Have = 1
  tampered = -1
  For i = 0 To 15
    Rom.MY(i) = 0
  Next
  Rom.MY(0) = nl
  For l = 0 To nl - 1
    Rom.MY(1 + l * 2) = lp(nl - 1 - l)
    Rom.MY(2 + l * 2) = nl - 1 - l
  Next
  If pool = 2 Then
    Rom.MY(2) = 3
    Rom.MY(9) = 8
  End If
  Rom.MY(7) = hs
  Rom.MY(12) = Rom.Sn And 255
  Rom.MY(13) = Rom.Sn \ 256
  Rom.MY(14) = Data.TX_YOURS And 255
  Rom.MY(15) = Data.TX_YOURS \ 256
  Attack.Mwn = 0
  For i = 0 To mn - 1
    If mes(i) = 32 Then Exit For
    If Attack.Mwn < 15 Then
      Attack.Mw(Attack.Mwn) = mes(i)
      Attack.Mwn = Attack.Mwn + 1
    End If
  Next
  Encode = 1
End Function

Private Sub Result()
  Dim i As Integer, y As Integer
  Vid.Page Data.TX_PL_RES, Data.TX_PL_KEYS2
  Vid.Txt 8, 34, Data.TX_PL_SIZE, 3
  Vid.Num 140, 34, Rom.Sn, 4, 10
  Vid.Txt 8, 46, Data.TX_PL_MLEN, 3
  Vid.Num 140, 46, mn, 2, 10
  y = 58
  For i = 0 To nl - 1
    Vid.Txt 8, y, Data.TX_PL_LAYN, 3
    Vid.Num 50, y, i + 1, 1, 3
    Vid.Txt 70, y, PName(lp(i)), 1
    Vid.Txt 160, y, Data.TX_PL_ROMN, 3
    Vid.Num 190, y, i + 1, 1, 1
    If i = nl - 1 And hs <> 0 Then Vid.Txt 215, y, Data.TX_RH_HASH, 9
    y = y + 10
  Next
  Vid.Txt 8, 94, Data.TX_PL_FIRST, 8
  For i = 0 To 47
    If i < Rom.Sn Then Vid.Hex2 8 + (i Mod 16) * 18, 106 + (i \ 16) * 12, Rom.SxGet(i), 11
  Next
  If Rom.Sn > 48 Then
    Vid.Ch 8, 142, 46, 11
    Vid.Ch 14, 142, 46, 11
    Vid.Ch 20, 142, 46, 11
  End If
  If tampered >= 0 Then
    Vid.Txt 8, 150, Data.TX_PL_TAMP, 12
    Vid.Num 160, 150, tampered, 4, 12
  End If
End Sub

Private Sub Decode()
  Dim l As Integer, c As Integer, i As Integer, n As Integer, ok As Integer
  Vid.Fill 0, 164, 320, 72, 5
  Vid.Txt 8, 164, Data.TX_PL_DEC, 8
  Rom.Load 4
  ok = 1
  For l = 0 To nl - 1
    c = Rom.Layer(Rom.RomBlock(Rom.Man(4, 2 + l * 2)), Rom.Man(4, 1 + l * 2))
    Rom.Take c
    If l = 0 And hs <> 0 Then
      If Rom.Wn >= 4 Then
        For i = 0 To 3
          Rom.HB(i) = Rom.Wg(i)
        Next
        Rom.RollHash 4, Rom.Wn - 4
        For i = 0 To 3
          If Rom.HB(i) <> Rom.Wg(i) Then ok = 0
        Next
        Rom.Strip4
      Else
        ok = 0
      End If
    End If
  Next
  n = Rom.Wn
  For i = 0 To n - 1
    If i < 40 Then Vid.Ch 8 + i * 6, 178, Rom.Wg(i), 1
  Next
  If hs <> 0 Then
    If ok = 1 Then
      Vid.Txt 8, 196, Data.TX_PL_HOK, 9
      If tampered >= 0 Then Vid.Txt 8, 208, Data.TX_PL_NOEFF, 3
    Else
      Vid.Txt 8, 196, Data.TX_PL_HBAD, 12
    End If
  Else
    If tampered >= 0 Then Vid.Txt 8, 196, Data.TX_PL_HOFF, 10
  End If
End Sub

Public Sub Screen()
  Dim k As Integer, run As Integer, st As Integer, p As Integer, r As Integer, id As Integer
  InitKeys
  If mn = 0 Then
    mn = 19
    For p = 0 To 18
      mes(p) = Vid.TabB(Data.TX_PLDEF + p)
    Next
    nl = 1 : hs = 0 : pool = 0
    lp(0) = 1 : lp(1) = 1 : lp(2) = 1
  End If
  row = 0
  st = 0
  Setup
  run = 1
  Do While run = 1
    Vid.Sync
    k = Vid.Edge()
    If st = 0 Then
      If (k And 32) <> 0 Then run = 0
      If (k And 1) <> 0 And row > 0 Then row = row - 1 : Setup
      If (k And 2) <> 0 And row < 3 + nl Then row = row + 1 : Setup
      If (k And 12) <> 0 Then
        r = 1
        If (k And 4) <> 0 Then r = -1
        id = RowId(row)
        Select Case id
          Case 0
            TypeMsg
            k = Vid.Edge()
          Case 1
            nl = nl + r
            If nl < 1 Then nl = 3
            If nl > 3 Then nl = 1
            If row > 3 + nl Then row = 3 + nl
          Case 5
            hs = 1 - hs
          Case 6
            pool = pool + r
            If pool < 0 Then pool = 2
            If pool > 2 Then pool = 0
            If row > 3 + nl Then row = 3 + nl
          Case Else
            lp(id - 2) = lp(id - 2) + r
            If lp(id - 2) < 0 Then lp(id - 2) = 5
            If lp(id - 2) > 5 Then lp(id - 2) = 0
        End Select
        Setup
      End If
      If (k And 64) <> 0 Then
        Attack.Screen 0
        Setup
      End If
      If (k And 16) <> 0 Then
        If Encode() = 1 Then
          st = 1
          Result
        End If
      End If
    Else
      If (k And 32) <> 0 Then
        st = 0
        Setup
      End If
      If (k And 16) <> 0 Then
        Attack.Screen 4
        Result
      End If
      If (k And 64) <> 0 Then Decode
      If (k And 128) <> 0 Then
        p = Rng.Pick(Rom.Sn)
        Rom.SxPut p, Rom.SxGet(p) Xor (1 + Rng.Pick(255))
        tampered = p
        Result
      End If
    End If
  Loop
End Sub
