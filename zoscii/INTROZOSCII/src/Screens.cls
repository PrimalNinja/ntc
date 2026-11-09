' Screens - the static text screens of the contents (a page class). (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

' Timeline: dots for the history pages, the one at p lit
Private Sub Line5(ByVal p As Integer)
  Dim i As Integer, c As Integer
  Vid.Fill 30, 214, 260, 1, 4
  For i = 0 To 4
    c = 4
    If i = p Then c = 10
    Vid.Fill 36 + i * 62, 211, 7, 7, c
    Select Case i
      Case 0
        Vid.Num 29 + i * 62, 222, 1917, 4, c
      Case 1
        Vid.Num 29 + i * 62, 222, 1948, 4, c
      Case 2
        Vid.Num 29 + i * 62, 222, 1949, 4, c
      Case 3
        Vid.Num 29 + i * 62, 222, 1994, 4, c
      Case Else
        Vid.Num 29 + i * 62, 222, 2025, 4, c
    End Select
  Next
End Sub

' KeyTx p, n: the bottom row for page p of n: only keys that do something there
Private Function KeyTx(ByVal p As Integer, ByVal n As Integer) As Integer
  If n < 2 Then
    KeyTx = Data.TX_K_ONE
  ElseIf p = 0 Then
    KeyTx = Data.TX_K_FIRST
  ElseIf p >= n - 1 Then
    KeyTx = Data.TX_K_LAST
  Else
    KeyTx = Data.TX_K_MID
  End If
End Function

Private Sub HPage(ByVal p As Integer)
  Select Case p
    Case 0
      Vid.Page Data.TX_H1T, KeyTx(p, 5)
      Vid.Txt 8, 34, Data.TX_H1, 1
    Case 1
      Vid.Page Data.TX_H2T, KeyTx(p, 5)
      Vid.Txt 8, 34, Data.TX_H2, 1
    Case 2
      Vid.Page Data.TX_H3T, KeyTx(p, 5)
      Vid.Txt 8, 34, Data.TX_H3, 1
    Case 3
      Vid.Page Data.TX_H4T, KeyTx(p, 5)
      Vid.Txt 8, 34, Data.TX_H4, 1
    Case Else
      Vid.Page Data.TX_H5T, KeyTx(p, 5)
      Vid.Txt 8, 34, Data.TX_H5, 1
  End Select
  Line5 p
  Vid.PageNo p + 1, 5
End Sub

' A paged section: n pages, drawn by the caller's Select through Pg
Public Sub Story()
  Dim p As Integer, k As Integer
  p = 0
  HPage p
  Do
    Vid.Sync
    k = Vid.Edge()
    If (k And 32) <> 0 Then Exit Sub
    If (k And 8) <> 0 Then
      p = p + 1
      If p > 4 Then Exit Sub
      HPage p
    End If
    If (k And 4) <> 0 And p > 0 Then
      p = p - 1
      HPage p
    End If
  Loop
End Sub

Private Sub Hello(ByVal first As Integer)
  Dim i As Integer, c As Integer, x As Integer, lo As Integer, hi As Integer
  Vid.Fill 0, 100, 320, 134, 5
  Vid.Txt 8, 104, Data.TX_N_PLAIN, 8
  Vid.Txt 8, 122, Data.TX_N_ADDR, 3
  Vid.Txt 8, 136, Data.TX_N_READS, 3
  For i = 0 To 4
    c = Vid.TabB(Data.T_FONT + 0) 
    Select Case i
      Case 0
        c = 72
      Case 1
        c = 101
      Case 2
        c = 108
      Case 3
        c = 108
      Case Else
        c = 111
    End Select
    x = 100 + i * 42
    Vid.Hex4 x, 122, 0, c, 1
    Vid.Big x + 6, 134, c, 10, 2
  Next
  Vid.Txt 8, 160, Data.TX_N_ROM, 8
  Vid.Txt 8, 178, Data.TX_N_ADDR, 3
  Vid.Txt 8, 192, Data.TX_N_READS, 3
  For i = 0 To 4
    Select Case i
      Case 0
        c = 72
      Case 1
        c = 101
      Case 2
        c = 108
      Case 3
        c = 108
      Case Else
        c = 111
    End Select
    x = 100 + i * 42
    If Rom.Pick(Data.ROMB0, c) = 1 Then
      Vid.Hex4 x, 178, Rom.PickHi, Rom.PickLo, 11
      Vid.Big x + 6, 190, Rom.B(Data.ROMB0, 0, 0, Rom.PickLo, Rom.PickHi), 10, 2
    End If
  Next
  Vid.Txt 8, 220, Data.TX_N_SPACE, 3
End Sub

Private Sub NtcPage(ByVal p As Integer)
  If p = 0 Then
    Vid.Page Data.TX_N1T, KeyTx(p, 2)
    Vid.Txt 8, 34, Data.TX_N1, 1
  Else
    Vid.Page Data.TX_N1T, Data.TX_K_NTC2
    Vid.Txt 8, 34, Data.TX_N2, 1
    Hello 0
  End If
  Vid.PageNo p + 1, 2
End Sub

Public Sub Ntc()
  Dim p As Integer, k As Integer
  p = 0
  NtcPage p
  Do
    Vid.Sync
    k = Vid.Edge()
    If (k And 32) <> 0 Then Exit Sub
    If (k And 8) <> 0 Then
      If p = 1 Then Exit Sub
      p = 1
      NtcPage p
    End If
    If (k And 4) <> 0 And p = 1 Then
      p = 0
      NtcPage p
    End If
    If (k And 16) <> 0 And p = 1 Then
      Hello 0
      Snd.Beep 2
    End If
  Loop
End Sub

Private Sub Hide(ByVal ch As Integer, ByVal fresh As Integer)
  Dim i As Integer, x As Integer, lo As Integer, hi As Integer, n As Integer
  Vid.Fill 0, 24, 320, 214, 5
  Vid.Txt 8, 30, Data.TX_L1, 1
  Vid.Txt 8, 76, Data.TX_L_LETTER, 3
  Vid.Big 70, 70, ch, 10, 3
  Vid.Txt 110, 76, Data.TX_L_COUNT, 3
  n = Rom.Count(Data.ROMB0, ch)
  Vid.Num 270, 76, n, 5, 9
  Vid.Txt 8, 96, Data.TX_L_PICKS, 8
  For i = 0 To 5
    If Rom.Pick(Data.ROMB0, ch) = 1 Then
      Vid.Hex4 8 + i * 50, 108, Rom.PickHi, Rom.PickLo, 11
      If i = 0 Then
        lo = Rom.PickLo
        hi = Rom.PickHi
      End If
    End If
  Next
  Vid.Txt 8, 124, Data.TX_L_SAME, 8
  Vid.Hex4 8, 140, hi, lo, 11
  Vid.Txt 70, 140, Data.TX_L_R1, 3
  Vid.Big 160, 136, Rom.B(Data.ROMB0, 0, 0, lo, hi), 10, 2
  Vid.Txt 70, 156, Data.TX_L_R2, 3
  Vid.Big 160, 152, Rom.B(Data.ROMB1, 0, 0, lo, hi), 12, 2
  Vid.Txt 70, 172, Data.TX_L_R3, 3
  Vid.Big 160, 168, Rom.B(Data.ROMB2, 0, 0, lo, hi), 12, 2
  Vid.Txt 8, 190, Data.TX_L2, 1
  Vid.Txt 8, 226, Data.TX_L_SPACE, 3
End Sub

Public Sub Letter()
  Dim ch As Integer, k As Integer
  ch = 72
  Vid.Page Data.TX_L1T, Data.TX_K_LET
  Hide ch, 1
  Do
    Vid.Sync
    k = Vid.Edge()
    If (k And 32) <> 0 Then Exit Sub
    If (k And 16) <> 0 Then
      Hide ch, 0
      Snd.Beep 2
    End If
    If (k And 4) <> 0 And ch > 65 Then
      ch = ch - 1
      Hide ch, 1
    End If
    If (k And 8) <> 0 Then
      If ch < 90 Then
        ch = ch + 1
        Hide ch, 1
      End If
    End If
  Loop
End Sub

Private Sub ReadAs(ByVal y As Integer, ByVal lab As Integer, ByVal rb As Integer, ByVal c As Integer)
  Dim n As Integer, i As Integer
  Vid.Fill 0, y, 320, 22, 5
  Vid.Txt 8, y, lab, 8
  Rom.Load Data.ALTFILE
  n = Rom.Layer(rb, 1)
  For i = 0 To 44
    If i < n Then Vid.Ch 8 + i * 6, y + 12, Rom.Og(i), c
  Next
End Sub

Public Sub Plaus()
  Dim i As Integer, k As Integer
  Vid.Page Data.TX_P1T, Data.TX_K_ONE
  Vid.Txt 8, 28, Data.TX_P1, 1
  Rom.Load Data.ALTFILE
  Vid.Txt 8, 58, Data.TX_P_FILE, 3
  For i = 0 To 16
    Vid.Hex2 8 + i * 18, 68, Rom.Wg(i), 4
  Next
  Vid.Txt 8, 80, Data.TX_P_READS, 3
  ReadAs 90, Data.TX_P_ROM1, Data.ROMB0, 10
  Rom.LoadPatch
  Rom.Patch 1
  ReadAs 114, Data.TX_P_ROMA, Data.ROMB0, 10
  Rom.Patch 0
  ReadAs 138, Data.TX_P_ROM2, Data.ROMB1, 12
  ReadAs 162, Data.TX_P_ROM3, Data.ROMB2, 12
  Vid.Txt 8, 192, Data.TX_P2, 1
  Do
    Vid.Sync
    k = Vid.Edge()
  Loop Until (k And 32) <> 0
End Sub

Public Sub Anatomy()
  Dim k As Integer, i As Integer, x As Integer, pf As Integer, sf As Integer, bp As Integer, ms As Integer, mw As Integer
  Dim v(3) As Integer
  Vid.Page Data.TX_U1T, Data.TX_K_ONE
  Vid.Txt 8, 28, Data.TX_U1, 1
  Rom.Load Data.ALTFILE
  Vid.Txt 8, 52, Data.TX_U_H, 3
  For i = 0 To 3
    v(i) = Rom.B(Data.ROMB0, 0, 0, Rom.Wg(i * 2), Rom.Wg(i * 2 + 1))
    Vid.Hex4 8, 64 + i * 12, Rom.Wg(i * 2 + 1), Rom.Wg(i * 2), 11
    Vid.Hex2 100, 64 + i * 12, v(i), 10
  Next
  Vid.Txt 130, 64, Data.TX_U_H1, 2
  Vid.Txt 130, 76, Data.TX_U_H2, 2
  Vid.Txt 130, 88, Data.TX_U_H3, 2
  Vid.Txt 130, 100, Data.TX_U_H4, 2
  pf = v(2) : sf = v(3)
  ms = (Rom.Wn - 8 - pf - sf) \ 2
  Vid.Txt 8, 116, Data.TX_U_LAY, 8
  bp = Rom.Wn \ 300 + 1
  mw = (Rom.Wn - 8 - pf - sf) \ bp
  x = 8
  Vid.Fill x, 128, 8 \ bp + 1, 14, 10
  x = x + 8 \ bp + 1
  Vid.Fill x, 128, pf \ bp, 14, 4
  x = x + pf \ bp
  Vid.Fill x, 128, mw, 14, 9
  x = x + mw
  Vid.Fill x, 128, sf \ bp, 14, 4
  Vid.Txt 8, 148, Data.TX_U_OFF, 3
  Vid.Hex4 130, 148, v(1), v(0), 10
  Vid.Txt 8, 160, Data.TX_U_MSG, 3
  Vid.Num 130, 160, ms, 3, 10
  Vid.Txt 8, 178, Data.TX_U2, 1
  Do
    Vid.Sync
    k = Vid.Edge()
  Loop Until (k And 32) <> 0
End Sub

Private oh(3) As Byte, rhn As Integer

Private Sub RhInit()
  Dim i As Integer
  rhn = 0
  Do While Vid.TabB(Data.TX_RH_MSG + rhn) <> 0
    Rom.Wp rhn, Vid.TabB(Data.TX_RH_MSG + rhn)
    rhn = rhn + 1
  Loop
  Rom.RollHash 0, rhn
  For i = 0 To 3
    oh(i) = Rom.HB(i)
  Next
  For i = 0 To rhn - 1
    Rom.Op i, Rom.Wg(i)
  Next
End Sub

Private Sub RhShow()
  Dim i As Integer, c As Integer
  Vid.Fill 0, 92, 320, 100, 5
  Vid.Txt 8, 96, Data.TX_RH_A, 3
  For i = 0 To rhn - 1
    Vid.Glyph 8 + i * 6, 108, Rom.Og(i), 1
  Next
  Vid.Txt 8, 120, Data.TX_RH_HASH, 3
  For i = 0 To 3
    Vid.Hex2 50 + i * 18, 120, oh(i), 10
  Next
  Vid.Txt 8, 138, Data.TX_RH_B, 3
  For i = 0 To rhn - 1
    c = 1
    If Rom.Wg(i) <> Rom.Og(i) Then c = 12
    Vid.Glyph 8 + i * 6, 150, Rom.Wg(i), c
  Next
  Rom.RollHash 0, rhn
  Vid.Txt 8, 162, Data.TX_RH_HASH, 3
  For i = 0 To 3
    c = 10
    If Rom.HB(i) <> oh(i) Then c = 12
    Vid.Hex2 50 + i * 18, 162, Rom.HB(i), c
  Next
  Vid.Txt 8, 178, Data.TX_RH_SPACE, 3
End Sub

Private Sub RhChange()
  Dim r As Integer
  r = Rng.Pick(rhn)
  If Rom.Wg(r) = 32 Then r = (r + 1) Mod rhn
  If Rom.Wg(r) >= 90 Then
    Rom.Wp r, 65
  Else
    Rom.Wp r, Rom.Wg(r) + 1
  End If
  RhShow
End Sub

Private Sub Hist()
  Dim c(15) As Integer, blk As Integer, i As Integer, g As Integer, m As Integer, d As Integer, h As Integer
  For g = 0 To 15
    c(g) = 0
  Next
  For blk = 0 To 3
    For i = 0 To 16383 Step 4
      g = Vid.Pe(Data.ROMB0 + blk, i) \ 16
      c(g) = c(g) + 1
    Next
  Next
  m = 0
  For g = 0 To 15
    If c(g) > m Then m = c(g)
  Next
  d = m \ 60 + 1
  Vid.Txt 8, 134, Data.TX_RA_HIST, 3
  For g = 0 To 15
    h = c(g) \ d
    Vid.Fill 12 + g * 19, 228 - h, 15, h, 8
  Next
  h = 1024 \ d
  Vid.Fill 8, 228 - h, 304, 1, 9
  Vid.Txt 8, 150, Data.TX_RA_FLAT, 9
End Sub

' The text after the title t (the title and its page are neighbours in the text table)
Private Function Body(ByVal t As Integer) As Integer
  Do While Vid.TabB(t) <> 0
    t = t + 1
  Loop
  Body = t + 1
End Function

Private Function PgN(ByVal kind As Integer) As Integer
  Select Case kind
    Case 3
      PgN = 2
    Case 4
      PgN = 5
    Case 5
      PgN = 4
    Case 6
      PgN = 4
    Case Else
      PgN = 3
  End Select
End Function

Private Function PgTx(ByVal kind As Integer, ByVal p As Integer) As Integer
  Select Case kind * 10 + p
    Case 30
      PgTx = Data.TX_ROM1T
    Case 31
      PgTx = Data.TX_ROM2T
    Case 40
      PgTx = Data.TX_SH1T
    Case 41
      PgTx = Data.TX_SH2T
    Case 42
      PgTx = Data.TX_SH3T
    Case 43
      PgTx = Data.TX_SH4T
    Case 44
      PgTx = Data.TX_SH5T
    Case 60
      PgTx = Data.TX_PP1T
    Case 61
      PgTx = Data.TX_PP2T
    Case 62
      PgTx = Data.TX_PP3T
    Case 63
      PgTx = Data.TX_PP4T
    Case 50
      PgTx = Data.TX_FS1T
    Case 51
      PgTx = Data.TX_FS2T
    Case 52
      PgTx = Data.TX_FS3T
    Case Else
      PgTx = Data.TX_FS4T
  End Select
End Function

Private Sub ShowPg(ByVal kind As Integer, ByVal p As Integer)
  Dim t As Integer
  If kind = 0 Then
    Select Case p
      Case 0
        Vid.Page Data.TX_FA1T, KeyTx(p, 5)
        Vid.Txt 8, 34, Data.TX_FA1, 1
      Case 1
        Vid.Page Data.TX_FA2T, KeyTx(p, 5)
        Vid.Txt 8, 34, Data.TX_FA2, 1
      Case 2
        Vid.Page Data.TX_FA3T, Data.TX_K_RH
        Vid.Txt 8, 34, Data.TX_FA3, 1
        RhInit
        RhShow
        Vid.Txt 8, 196, Data.TX_RH_NOTE, 3
      Case 3
        Vid.Page Data.TX_FA4T, KeyTx(p, 5)
        Vid.Txt 8, 34, Data.TX_FA4, 1
      Case Else
        Vid.Page Data.TX_FA5T, KeyTx(p, 5)
        Vid.Txt 8, 34, Data.TX_FA5, 1
    End Select
    Vid.PageNo p + 1, 5
  End If
  If kind = 1 Then
    Select Case p
      Case 0
        Vid.Page Data.TX_RA1T, KeyTx(p, 4)
        Vid.Txt 8, 34, Data.TX_RA1, 1
      Case 1
        Vid.Page Data.TX_RA2T, KeyTx(p, 4)
        Vid.Txt 8, 34, Data.TX_RA2, 1
      Case 2
        Vid.Page Data.TX_RA3T, KeyTx(p, 4)
        Vid.Txt 8, 34, Data.TX_RA3, 1
        Hist
      Case Else
        Vid.Page Data.TX_RA4T, KeyTx(p, 4)
        Vid.Txt 8, 34, Data.TX_RA4, 1
    End Select
    Vid.PageNo p + 1, 4
  End If
  If kind > 2 Then
    t = PgTx(kind, p)
    Vid.Page t, KeyTx(p, PgN(kind))
    Vid.Txt 8, 34, Body(t), 1
    Vid.PageNo p + 1, PgN(kind)
  End If
  If kind = 2 Then
    If p = 0 Then
      Vid.Page Data.TX_KY1T, KeyTx(p, 2)
      Vid.Txt 8, 34, Data.TX_KY1, 1
    Else
      Vid.Page Data.TX_KY2T, KeyTx(p, 2)
      Vid.Txt 8, 34, Data.TX_KY2, 1
    End If
    Vid.PageNo p + 1, 2
  End If
End Sub

' Pages kind, n: a set of n pages (0 family, 1 randomness, 2 getting the key across)
Public Sub Pages(ByVal kind As Integer, ByVal n As Integer)
  Dim p As Integer, k As Integer
  p = 0
  ShowPg kind, p
  Do
    Vid.Sync
    k = Vid.Edge()
    If (k And 32) <> 0 Then Exit Sub
    If (k And 8) <> 0 Then
      p = p + 1
      If p >= n Then Exit Sub
      ShowPg kind, p
    End If
    If (k And 4) <> 0 And p > 0 Then
      p = p - 1
      ShowPg kind, p
    End If
    If (k And 16) <> 0 And kind = 0 And p = 2 Then RhChange
  Loop
End Sub

Public Sub Fine()
  Dim p As Integer, k As Integer
  p = 0
  Do
    Vid.Page Data.TX_F1T, KeyTx(p, 3)
    Select Case p
      Case 0
        Vid.Txt 8, 34, Data.TX_F1, 1
      Case 1
        Vid.Txt 8, 34, Data.TX_F2, 1
      Case Else
        Vid.Txt 8, 34, Data.TX_F3, 1
    End Select
    Vid.PageNo p + 1, 3
    Do
      Vid.Sync
      k = Vid.Edge()
    Loop Until (k And 60) <> 0
    If (k And 32) <> 0 Then Exit Sub
    If (k And 8) <> 0 Then
      p = p + 1
      If p > 2 Then Exit Sub
    End If
    If (k And 4) <> 0 And p > 0 Then p = p - 1
  Loop
End Sub

