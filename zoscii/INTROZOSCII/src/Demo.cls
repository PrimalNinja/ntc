' Demo - a ROM made now by Rng from the Next's own memory, then messages encoded with it: examples, a challenge, the answer and a proof.
'   See it (mode 0): 3 examples, the 10 plain texts, the 10 encodings (shuffled against the texts), the answer, then the proof.
'   Try to work it out (mode 1): the same, with a page between the encodings and the answer where YOU pair each encoding with a text.
'   Plain ZOSCII: every message is 52 characters (padded with spaces) so every encoding is 104 bytes, which is what makes the pairing fair.
' The ROM is blocks Data.GENB to GENB + 7 (128KB, ZOSCII uses its first 64K); the words are Data.DICTB (8 bytes a word).
' Block Data.DEMOB holds 13 slots of 256 bytes: the text at 0 (52 characters), the encoding's byte count at 60 (2 bytes), the encoding
' (addresses, low byte first) at 64. Slots 0-9 are the challenge, 10-12 the examples (10 and 11 the same text encoded twice).
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Private pm(9) As Integer, gs(9) As Integer
Private dp(51) As Byte
Private ro(699) As Byte, cb(14) As Byte, mc As Integer
Private md As Integer, en As Integer, np As Integer, pr As Integer
' The encodings are shown in full: ne pages of them (page 5 on), each page the entries pgF(page) to pgF(page + 1) - 1: encoding entE,
' from row entR, entN rows. pa is the attacker's page.
Private ne As Integer, pa As Integer
Private pgF(24) As Byte, entE(32) As Byte, entR(32) As Byte, entN(32) As Byte

' Sentence: random words (no grammar) cut at the last space within 52 characters and padded with spaces to exactly 52, into W
Private Sub Sentence()
  Dim n As Integer, idx As Integer, j As Integer, c As Integer
  n = 0
  Do While n < 60
    idx = Rng.Pick(Data.NWORDS)
    j = 0
    c = Vid.Pe(Data.DICTB + idx \ 2048, (idx And 2047) * 8)
    Do While j < 8 And c <> 0
      Rom.Wp n, c
      n = n + 1
      j = j + 1
      c = Vid.Pe(Data.DICTB + idx \ 2048, (idx And 2047) * 8 + j)
    Loop
    Rom.Wp n, 32
    n = n + 1
  Loop
  c = 52
  Do While Rom.Wg(c) <> 32
    c = c - 1
  Loop
  For j = c To 51
    Rom.Wp j, 32
  Next
  Rom.Wn = 52
End Sub

' Slot s, d: slot s of DEMOB, d 1 saves W and the encoding Enc just made into it, d 0 loads them back into W and O (en bytes)
' The slot is 1024 bytes: the text at 0 (52), the byte count at 60, the encoding at 64. One bulk copy each way through Blk.Buf.
Private Sub Slot(ByVal s As Integer, ByVal d As Integer)
  If d = 1 Then
    If pr < 2 Then
      en = Rom.Enc(Data.GENB, pr, 0, 255)
      If en < 0 Then en = 0
      Blk.Get Data.WOB, 4096, 64, en
    Else
      en = Proto.Enc(pr)
    End If
    Blk.Get Data.WOB, 0, 0, 52
    Blk.Buf(60) = en And 255
    Blk.Buf(61) = en \ 256
    Blk.Put Data.DEMOB, s * 1024, 0, 64 + en
  Else
    Blk.Get Data.DEMOB, s * 1024, 0, 64 + 700
    en = Blk.Buf(60) + Blk.Buf(61) * 256
    Blk.Put Data.WOB, 0, 0, 52
    Blk.Put Data.WOB, 4096, 64, en
    Rom.Wn = 52
  End If
End Sub

' DrawText y, c: W (52 characters) in colour c
Private Sub DrawText(ByVal y As Integer, ByVal c As Integer)
  Dim x As Integer
  For x = 0 To 51
    Vid.Ch 8 + x * 6, y, Rom.Wg(x), c
  Next
End Sub

' DrawEnc y: O as addresses (micro: bytes), at most 55 groups, 11 to a row
Private Sub DrawEnc(ByVal y As Integer)
  Dim k As Integer
  If pr >= 3 Then
    For k = 0 To 109
      If k < en Then Vid.Hex2 8 + (k Mod 22) * 14, y + (k \ 22) * 9, Rom.Og(k), 9
    Next
    If en > 110 Then Dots y + 45
  Else
    For k = 0 To 54
      If k < en \ 2 Then Vid.Hex4 8 + (k Mod 11) * 27, y + (k \ 11) * 9, Rom.Og(k * 2 + 1), Rom.Og(k * 2), 9
    Next
    If en \ 2 > 55 Then Dots y + 45
  End If
End Sub

' Dots y: ... on the line y, when the encoding goes on past what is shown
Private Sub Dots(ByVal y As Integer)
  Vid.Ch 8, y, 46, 9
  Vid.Ch 14, y, 46, 9
  Vid.Ch 20, y, 46, 9
End Sub

' RowsOf: rows the encoding in Buf takes: 11 addresses a row (micro: 22 bytes)
Private Function RowsOf() As Integer
  If pr >= 3 Then
    RowsOf = (en + 21) \ 22
  Else
    RowsOf = (en \ 2 + 10) \ 11
  End If
End Function

' Paginate: lays all 10 encodings out in full over the pages from page 5, an encoding carrying on to the next page when it must
Private Sub Paginate()
  Dim e As Integer, r As Integer, st As Integer, y As Integer, av As Integer, n As Integer, k As Integer, pg As Integer
  pg = 0
  k = 0
  y = 26
  pgF(0) = 0
  For e = 0 To 9
    Slot pm(e), 0
    r = RowsOf()
    st = 0
    Do While r > 0
      av = (226 - y) \ 9
      If av < 1 Then
        pg = pg + 1
        pgF(pg) = k
        y = 26
        av = (226 - y) \ 9
      End If
      n = r
      If n > av Then n = av
      entE(k) = e
      entR(k) = st
      entN(k) = n
      k = k + 1
      y = y + 10 + n * 9 + 4
      st = st + n
      r = r - n
    Loop
  Next
  ne = pg + 1
  pgF(ne) = k
  pa = 5 + ne
  np = pa + 3 + md
End Sub

' DrawRows y, r0, nr: nr rows of the encoding in Buf from row r0, at y
Private Sub DrawRows(ByVal y As Integer, ByVal r0 As Integer, ByVal nr As Integer)
  Dim k As Integer, g As Integer, ix As Integer
  If pr >= 3 Then g = 22 Else g = 11
  For k = 0 To nr * g - 1
    ix = r0 * g + k
    If pr >= 3 Then
      If ix < en Then Vid.Hex2 8 + (k Mod 22) * 14, y + (k \ 22) * 9, Rom.Og(ix), 9
    Else
      If ix < en \ 2 Then Vid.Hex4 8 + (k Mod 11) * 27, y + (k \ 11) * 9, Rom.Og(ix * 2 + 1), Rom.Og(ix * 2), 9
    End If
  Next
End Sub

' SaveFiles: the 10 messages as MSG01.TXT to MSG10.TXT (52 characters, as encoded) and the 10 encodings as ENCA.BIN to ENCJ.BIN, in the
' folder the game runs from. Slot loads each into Blk.Buf: the text at 0, the encoding at 64. Returns the number of files not saved.
Private Function SaveFiles() As Integer
  Dim i As Integer, bad As Integer
  bad = 0
  For i = 0 To 9
    Slot i, 0
    If Esx.Save(0, i + 1, VarPtr(Blk.Buf(0)), 52) <> 0 Then bad = bad + 1
    Slot pm(i), 0
    If Esx.Save(1, i, VarPtr(Blk.Buf(64)), en) <> 0 Then bad = bad + 1
  Next
  SaveFiles = bad
End Function

' Item y, s, lab, k: slot s at y; k 0 its text, k 1 its encoding; lab the number (text) or letter (encoding), 0 none
Private Sub Item(ByVal y As Integer, ByVal s As Integer, ByVal lab As Integer, ByVal k As Integer)
  Slot s, 0
  If k = 1 Then
    If lab > 0 Then Vid.Ch 8, y, 64 + lab, 10
    Vid.Num 32, y, en, 3, 3
    Vid.Txt 56, y, Data.TX_D_BY, 3
    DrawEnc y + 10
  Else
    If lab > 0 Then Vid.Num 8, y, lab, 2, 10
    Vid.Num 38, y, 52, 2, 3
    Vid.Txt 56, y, Data.TX_D_CH, 3
    DrawText y + 10, 1
  End If
End Sub

Private Sub GameDraw(ByVal e As Integer, ByVal n As Integer)
  Vid.Page Data.TX_D_GT, Data.TX_D_GK
  Item 30, pm(e), e + 1, 1
  Item 112, n, n + 1, 0
  Vid.Txt 8, 190, Data.TX_D_GN, 2
  Vid.PageNo pa + 2, np
End Sub

' Game: pair each encoding with a text. Returns 1 (next page), -1 (back) or 0 (menu)
Private Function Game() As Integer
  Dim e As Integer, n As Integer, k As Integer, r As Integer, c As Integer
  e = 0
  n = 0
  r = 2
  c = 1
  Do While r = 2
    If c = 1 Then GameDraw e, n
    c = 0
    Vid.Sync
    k = Vid.Edge()
    If (k And 1) <> 0 Then
      n = (n + 9) Mod 10
      c = 1
    End If
    If (k And 2) <> 0 Then
      n = (n + 1) Mod 10
      c = 1
    End If
    If (k And 16) <> 0 Then
      gs(e) = n
      e = e + 1
      n = 0
      c = 1
      If e = 10 Then r = 1
    End If
    If (k And 32) <> 0 Then r = 0
  Loop
  Game = r
End Function

' Probe: the attacker. The text typed is slid over each of the 10 encodings (both byte pairings for 16-bit addresses). A position is
' ruled out only where two equal addresses would need two different letters. Returns 1 (next page), -1 (back) or 0 (menu)
Private Function Probe() As Integer
  Dim e As Integer, i As Integer, j As Integer, m As Integer, q As Integer, s As Integer, w As Integer, n As Integer
  Dim p As Integer, d As Integer, tried As Integer, outc As Integer, k As Integer, r As Integer, y As Integer, eq As Integer
  r = 2
  Do While r = 2
    Vid.Page Data.TX_D_AT, Data.TX_D_AK
    Vid.PageNo pa + 1, np
    Vid.Fill 156, 28, 1, 204, 8
    Vid.Txt 8, 30, Data.TX_D_AI, 1
    Vid.Txt 8, 112, Data.TX_D_AY, 3
    Vid.Txt 162, 30, Data.TX_D_AH, 3
    If mc = 0 Then
      Play.mn = 0
      Play.Line 123, 15
      mc = Play.mn
      For i = 0 To mc - 1
        cb(i) = Play.mes(i)
      Next
    Else
      For i = 0 To mc - 1
        Vid.Glyph 8 + i * 6, 123, cb(i), 10
      Next
    End If
    Vid.Fill 156, 28, 1, 204, 8
    Vid.Fill 0, 238, 320, 18, 6
    Vid.Txt 8, 244, Data.TX_D_AK2, 3
    Vid.Txt 8, 142, Data.TX_D_AX, 3
    m = mc
    For e = 0 To 9
      Slot pm(e), 0
      If pr >= 3 Then w = 1 Else w = 2
      tried = 0
      outc = 0
      For s = 0 To w - 1
        n = (en - s) \ w
        q = n - m + 1
        If q > 0 Then
          tried = tried + q
          For i = 0 To q - 1
            ro(i) = 0
          Next
          For i = 0 To n - 2
            For j = i + 1 To i + m - 1
              If j < n Then
                eq = 0
                If Blk.Buf(64 + s + i * w) = Blk.Buf(64 + s + j * w) Then
                  If w = 1 Then
                    eq = 1
                  ElseIf Blk.Buf(65 + s + i * 2) = Blk.Buf(65 + s + j * 2) Then
                    eq = 1
                  End If
                End If
                If eq = 1 Then
                  d = j - m + 1
                  If d < 0 Then d = 0
                  For p = d To i
                    If p < q Then
                      If cb(i - p) <> cb(j - p) Then ro(p) = 1
                    End If
                  Next
                End If
              End If
            Next
          Next
          For i = 0 To q - 1
            outc = outc + ro(i)
          Next
        End If
      Next
      y = 44 + e * 16
      Vid.Ch 162, y, 65 + e, 10
      Vid.Num 186, y, tried, 4, 3
      Vid.Num 222, y, outc, 4, 12
      Vid.Num 258, y, tried - outc, 4, 9
    Next
    Do
      Vid.Sync
      k = Vid.Edge()
    Loop Until (k And 60) <> 0
    If (k And 4) <> 0 Then r = -1
    If (k And 8) <> 0 Then r = 1
    If (k And 16) <> 0 Then mc = 0
    If (k And 32) <> 0 Then r = 0
  Loop
  Probe = r
End Function

' Proof: encoding A is read with the ROM, then ~60 ROM bytes are changed so the same encoding reads as another text, then put back
' Sw i, v: ROM byte at encoding address i gets v; returns what was there
Private Function Sw(ByVal i As Integer, ByVal v As Integer) As Integer
  Dim pg As Integer, o As Integer
  pg = Data.GENB + Proto.Pg(i) \ 64
  o = (Proto.Pg(i) And 63) * 256 + Proto.Po(i)
  Sw = Vid.Pe(pg, o)
  Vid.Pk pg, o, v
End Function

' Show p: page p (0-2 examples, 3 the messages, 4-7 the encodings, 8 the attacker, 9 your turn [mode 1], then the answer, then the proof)
' DKey p: the bottom row for page p: only keys that do something there
Private Function DKey(ByVal p As Integer) As Integer
  If p = 0 Then
    DKey = Data.TX_K_FIRST
  ElseIf p = 3 Then
    DKey = Data.TX_D_CHK
  ElseIf p >= np - 1 Then
    DKey = Data.TX_K_DLAST
  Else
    DKey = Data.TX_K_MID
  End If
End Function

Private Sub Show(ByVal p As Integer)
  Dim i As Integer, e As Integer, ok As Integer, n As Integer, ch As Integer, a As Integer
  If p = pa Then Exit Sub
  If p < 3 Then
    Vid.Page Data.TX_D_T1, DKey(p)
    Item 28, 10 + p, 0, 0
    Item 60, 10 + p, 0, 1
    Select Case p
      Case 0
        Vid.Txt 8, 150, Data.TX_D_E1, 2
      Case 1
        Vid.Txt 8, 150, Data.TX_D_E2, 2
      Case Else
        Vid.Txt 8, 150, Data.TX_D_E3, 2
    End Select
  ElseIf p = 3 Then
    Vid.Page Data.TX_D_CHT, DKey(p)
    Vid.Txt 8, 34, Data.TX_D_CHB, 1
  ElseIf p = 4 Then
    Vid.Page Data.TX_D_T2, DKey(p)
    For i = 0 To 9
      Item 28 + i * 20, i, i + 1, 0
    Next
  ElseIf p < pa Then
    Vid.Page Data.TX_D_T3, DKey(p)
    a = 26
    For i = pgF(p - 5) To pgF(p - 4) - 1
      e = entE(i)
      Slot pm(e), 0
      Vid.Ch 8, a, 65 + e, 10
      If entR(i) = 0 Then
        Vid.Num 32, a, en, 3, 3
        Vid.Txt 56, a, Data.TX_D_BY, 3
      Else
        Vid.Txt 32, a, Data.TX_D_CONT, 3
      End If
      DrawRows a + 10, entR(i), entN(i)
      a = a + 14 + entN(i) * 9
    Next
  ElseIf p = pa + 1 + md Then
    Vid.Page Data.TX_D_KT, DKey(p)
    For e = 0 To 9
      Vid.Ch 40, 36 + e * 16, 65 + e, 10
      Vid.Num 70, 36 + e * 16, pm(e) + 1, 2, 10
      If md = 1 Then
        If gs(e) = pm(e) Then ok = ok + 1
        Vid.Txt 150, 36 + e * 16, Data.TX_D_YOU, 3
        Vid.Num 232, 36 + e * 16, gs(e) + 1, 2, 10
      End If
    Next
    If md = 1 Then
      Vid.Txt 8, 204, Data.TX_D_RIGHT, 3
      Vid.Num 70, 204, ok, 2, 10
    End If
  Else
    Vid.Page Data.TX_D_PT, DKey(p)
    a = -1
    ok = 1
    If pr < 3 Then
      Do While ok > 0 And a < 9
        a = a + 1
        Slot pm(a), 0
        Proto.Pos pr
        For i = 0 To 51
          dp(i) = 255
          For e = 0 To i - 1
            If Proto.Pg(i) = Proto.Pg(e) And Proto.Po(i) = Proto.Po(e) Then dp(i) = e
          Next
        Next
        e = 0
        Do While ok > 0 And e < 9
          e = e + 1
          Slot pm((a + e) Mod 10), 0
          ok = 0
          For i = 0 To 51
            If dp(i) <> 255 Then
              If Blk.Buf(i) <> Blk.Buf(dp(i)) Then ok = 1
            End If
          Next
        Loop
      Loop
      Blk.Put Data.WOB, 4096 + 1500, 0, 52
      Slot pm(a), 0
      n = 0
      For i = 0 To 51
        ch = Sw(i, Rom.Og(1500 + i))
        Rom.Op 1700 + i, ch
        If ch <> Rom.Og(1500 + i) Then n = n + 1
      Next
      For i = 0 To 51
        Rom.Op 1900 + i, Vid.Pe(Data.GENB + Proto.Pg(i) \ 64, (Proto.Pg(i) And 63) * 256 + Proto.Po(i))
      Next
      For i = 51 To 0 Step -1
        ch = Sw(i, Rom.Og(1700 + i))
      Next
    End If
    If pr >= 3 Then
      Vid.Txt 8, 40, Data.TX_D_NP, 3
    Else
      Slot pm(a), 0
      Vid.Txt 8, 28, Data.TX_D_PR1, 3
      Vid.Ch 62, 28, 65 + a, 10
      DrawText 40, 1
      For i = 0 To 51
        Rom.Wp i, Rom.Og(1900 + i)
      Next
      Vid.Txt 8, 68, Data.TX_D_PR2, 3
      Vid.Num 98, 68, n, 2, 10
      DrawText 90, 10
    End If
  End If
  Vid.PageNo p + 1, np
End Sub

' Run m: m 0 see it, 1 try to work it out
Public Sub Run(ByVal m As Integer)
  Dim p As Integer, k As Integer, s As Integer, j As Integer, t As Integer, g As Integer
  md = m
  np = 12 + md
  Vid.Page Data.TX_M11, Data.TX_D_START
  If md = 1 Then
    Vid.Txt 8, 34, Data.TX_D_GUESS, 1
  Else
    Vid.Txt 8, 34, Data.TX_D_INTRO, 1
  End If
  pr = 5
  k = 2
  Do While (k And 48) = 0
    If (k And 3) <> 0 Then
      If (k And 1) <> 0 Then pr = (pr + 5) Mod 6 Else pr = (pr + 1) Mod 6
      Vid.Fill 150, 200, 160, 8, 5
      Vid.Txt 8, 200, Data.TX_D_PRO, 3
      Select Case pr
        Case 0
          Vid.Txt 150, 200, Data.TX_D_PZ, 10
        Case 1
          Vid.Txt 150, 200, Data.TX_D_PU, 10
        Case 2
          Vid.Txt 150, 200, Data.TX_D_PB, 10
        Case 3
          Vid.Txt 150, 200, Data.TX_D_PMZ, 10
        Case 4
          Vid.Txt 150, 200, Data.TX_D_PMU, 10
        Case Else
          Vid.Txt 150, 200, Data.TX_D_PMB, 10
      End Select
    End If
    Vid.Sync
    k = Vid.Edge()
  Loop
  If (k And 32) <> 0 Then Exit Sub
  Rng.Reseed
  Vid.Fill 0, 24, 320, 208, 5
  Vid.Txt 20, 104, Data.TX_D_MAKE, 3
  Vid.Txt 20, 140, Data.TX_D_MAKE2, 9
  If pr < 3 Then Rom.Gen Else Proto.MakeRom
  For s = 0 To 9
    Sentence
    Slot s, 1
    pm(s) = s
  Next
  For s = 9 To 1 Step -1
    j = Rng.Pick(s + 1)
    t = pm(s)
    pm(s) = pm(j)
    pm(j) = t
  Next
  Sentence
  Slot 10, 1
  Slot 11, 1
  Sentence
  Slot 12, 1
  Paginate
  p = 0
  mc = 0
  Show p
  Do
    If p = pa Then
      g = Probe()
      If g = 0 Then Exit Sub
      p = p + g
      Show p
    ElseIf md = 1 And p = pa + 1 Then
      g = Game()
      If g = 0 Then Exit Sub
      p = p + g
      Show p
    Else
      Vid.Sync
      k = Vid.Edge()
      If (k And 16) <> 0 And p = 3 Then
        Vid.Fill 0, 200, 320, 10, 5
        If SaveFiles() = 0 Then
          Vid.Txt 8, 200, Data.TX_D_SVOK, 10
        Else
          Vid.Txt 8, 200, Data.TX_D_SVNO, 12
        End If
      End If
      If (k And 4) <> 0 And p > 0 Then
        p = p - 1
        Show p
      End If
      If (k And 8) <> 0 And p < np - 1 Then
        p = p + 1
        Show p
      End If
    End If
  Loop Until (k And 32) <> 0
End Sub
