' Attack - the attacker: what someone holding only the file can work out. Integer maths only (the JS attacker's tail probability is
' replaced by pairs against the expected count). (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

' the tables live in the scratch block (window #4000): nx chains (Integer) at 4096, the address bytes lo at 8192 and hi at 10240, heads (Integer) at 12288
Public cb(15) As Byte
Public Mw(15) As Byte
Public Mwn As Integer
Private f As Integer, atk As Integer, crib As Integer
Private nrd As Integer

Private Sub Head()
  Dim y As Integer
  Vid.Page Data.TX_A1T, Data.TX_KEYS_ATT
  Vid.Txt 8, 28, Data.TX_A_FILE, 3
  Vid.Txt 44, 28, Rom.Man(f, 14) + Rom.Man(f, 15) * 256, 1
  Vid.Txt 8, 38, Data.TX_A_ATK, 3
  Select Case atk
    Case 0
      Vid.Txt 50, 38, Data.TX_A_ATK1, 8
    Case 1
      Vid.Txt 50, 38, Data.TX_A_ATK2, 8
    Case Else
      Vid.Txt 50, 38, Data.TX_A_ATK3, 8
  End Select
  Vid.Txt 8, 48, Data.TX_A_HOLDS, 3
End Sub

' the readings table
Private Sub Readings()
  Dim rd As Integer, n As Integer, p As Integer, y As Integer, e10 As Integer, win As Integer, any As Integer
  Dim x As Long, w As Long, yy As Long
  Rom.Load f
  Vid.Txt 8, 62, Data.TX_A_READING, 3
  Vid.Txt 110, 62, Data.TX_A_ADDRS, 3
  Vid.Txt 160, 62, Data.TX_A_PAIRS, 3
  Vid.Txt 210, 62, Data.TX_A_CHANCE, 3
  Fill8
  win = Rom.Man(f, 8) + Rom.Man(f, 9) * 256
  any = 0
  y = 74
  For rd = 0 To 1
    If rd >= 0 Then
      n = AtkW.Build(rd)
      p = AtkW.Pairs(n)
      x = n : x = x * (n - 1) * 5
      If win = 0 Then
        w = 65536
      Else
        w = win
      End If
      e10 = CInt(x \ w)
      If (rd And 1) <> 0 Then
        Vid.Txt 8, y, Data.TX_A_ODD, 2
      Else
        Vid.Txt 8, y, Data.TX_A_EVEN, 2
      End If
      Vid.Num 110, y, n, 4, 1
      Vid.Num 160, y, p, 4, 1
      Vid.Num 210, y, e10 \ 10, 3, 3
      Vid.Glyph 228, y, 46, 3
      Vid.Num 234, y, e10 Mod 10, 1, 3
      If p >= 3 And p * 10 > e10 * 4 Then
        Vid.Txt 256, y, Data.TX_A_STANDS, 12
        any = 1
      End If
      y = y + 12
    End If
  Next
  Vid.Txt 8, 130, Data.TX_A_R1, 2
  If any = 0 Then
    Vid.Txt 8, 190, Data.TX_A_R_NONE, 9
  Else
    Vid.Txt 8, 190, Data.TX_A_R_SOME, 10
  End If
End Sub

Private Sub Fill8()
  Vid.Fill 8, 71, 304, 1, 4
End Sub

' the crib drag
Private Sub CribDrag()
  Dim co As Integer, m As Integer, i As Integer, j As Integer, rd As Integer, n As Integer, p As Integer, ok As Integer, k As Integer
  Dim tried As Integer, outc As Integer, best As Integer, d As Integer
  m = 0
  Vid.Txt 8, 58, Data.TX_A_CRIB, 3
  If crib >= Data.NCRIBS Then
    For m = 0 To Mwn - 1
      cb(m) = Mw(m)
      Vid.Glyph 44 + m * 6, 58, Mw(m), 10
    Next
    m = Mwn
  Else
    co = Vid.TabB(Data.T_CRIBS + crib * 2) + Vid.TabB(Data.T_CRIBS + crib * 2 + 1) * 256
    Do While Vid.TabB(co + m) <> 0 And m < 15
      cb(m) = Vid.TabB(co + m)
      m = m + 1
    Loop
    Vid.Txt 44, 58, co, 10
  End If
  Vid.Txt 8, 68, Data.TX_A_WORKING, 4
  Rom.Load f
  tried = 0 : outc = 0 : best = 0
  d = 0
  For i = 1 To m - 1
    If cb(i) <> cb(0) Then d = 1
  Next
  For rd = 0 To 1
    If rd >= 0 Then
      n = AtkW.Build(rd)
      AtkW.Crib m, n
      tried = tried + AtkW.Tried
      outc = outc + AtkW.Outc
      If AtkW.Best > best Then best = AtkW.Best
    End If
  Next
  Vid.Fill 8, 68, 304, 10, 5
  Vid.Txt 8, 72, Data.TX_A_C_SCAN, 3
  Vid.Num 270, 72, tried, 4, 1
  Vid.Txt 8, 84, Data.TX_A_C_OUT, 3
  Vid.Num 270, 84, outc, 4, 12
  Vid.Txt 8, 96, Data.TX_A_C_LEFT, 3
  Vid.Num 270, 96, tried - outc, 4, 9
  Vid.Txt 8, 108, Data.TX_A_C_BEST, 3
  Vid.Num 270, 108, best, 4, 1
  If tried - outc = 0 Then
    Vid.Txt 8, 130, Data.TX_A_C_NO, 12
  Else
    Vid.Txt 8, 130, Data.TX_A_C_MAYBE, 10
  End If
  If d = 0 Then Vid.Txt 8, 160, Data.TX_A_C_DEG, 3
  Vid.Txt 8, 172, Data.TX_A_C_LAYERS, 11
End Sub

' the ROMs held: decoding layer by layer
Private Sub Baseline()
  Dim n As Integer, l As Integer, y As Integer, i As Integer, c As Integer
  Rom.Load f
  Vid.Txt 8, 58, Data.TX_A_B_HDR, 3
  y = 72
  For l = 0 To Rom.Man(f, 0) - 1
    c = Rom.Layer(Rom.RomBlock(Rom.Man(f, 2 + l * 2)), Rom.Man(f, 1 + l * 2))
    Rom.Take c
    If l = 0 And Rom.Man(f, 7) <> 0 Then Rom.Strip4
    Vid.Txt 8, y, Data.TX_A_B_LAYER, 3
    Vid.Num 50, y, l + 1, 1, 1
    Vid.Txt 70, y, Data.TX_A_B_GOT, 3
    Vid.Num 150, y, c, 4, 9
    y = y + 12
  Next
  y = y + 6
  Vid.Txt 8, y, Data.TX_A_B_MSG, 10
  y = y + 12
  For i = 0 To Rom.Wn - 1
    Vid.Ch 8 + (i Mod 50) * 6, y + (i \ 50) * 10, Rom.Wg(i), 1
  Next
  Vid.Txt 8, 200, Data.TX_A_B_NOTE, 3
End Sub

Private Sub Draw()
  Head
  Select Case atk
    Case 0
      Readings
    Case 1
      CribDrag
    Case Else
      Baseline
  End Select
End Sub

Public Sub Screen(ByVal start As Integer)
  Dim k As Integer, run As Integer, nf As Integer, nc As Integer
  nf = Data.NFILES + Rom.Have
  nc = Data.NCRIBS + Rom.Have
  f = start : atk = 0 : crib = 0
  If start = 4 Then crib = Data.NCRIBS
  Head
  run = 1
  Do While run = 1
    Vid.Sync
    k = Vid.Edge()
    If (k And 32) <> 0 Then run = 0
    If (k And 1) <> 0 Then atk = (atk + 2) Mod 3 : Head
    If (k And 2) <> 0 Then atk = (atk + 1) Mod 3 : Head
    If (k And 4) <> 0 Then f = (f + nf - 1) Mod nf : Head
    If (k And 8) <> 0 Then f = (f + 1) Mod nf : Head
    If (k And 64) <> 0 Then crib = (crib + nc - 1) Mod nc : Head
    If (k And 128) <> 0 Then crib = (crib + 1) Mod nc : Head
    If (k And 16) <> 0 Then Draw
  Loop
End Sub
