' Rom - reading the ROMs (they live in INTRO.DAT's data blocks, 128KB = 8 blocks each), loading the demo files, and the ZOSCII /
' UNSIGNAL layer decoder: the same steps as gen_decode in tools/zlib.js.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

' W (the file being worked on, what the attacker holds) and O (the output of a decode step) are 2304 bytes each, kept in data block
' Data.WOB (W from byte 0, O from byte 4096) and read and written with Wg, Wp, Og, Op, which put the window back as it was.
Private Const OOFF = 4096
Public Sn As Integer, Have As Integer    ' its length, and whether there is one
Public MY(15) As Byte                    ' its manifest row
Public HB(3) As Byte                     ' the rolling hash bytes
Public Wn As Integer                     ' bytes in W
Private sps As Integer
Private pl(63) As Byte, pm(63) As Byte, ph(63) As Byte, pv(63) As Byte, ov(63) As Byte
Private patched As Integer
Private Mm(1023) As Byte                 ' the micro ROMs of Have a Play: 4 of 256 nibbles (0-2 the layers' ROMs, 3 the small one)
Private ep As Integer, ebad As Integer, erb As Integer, ewin As Integer, emic As Integer, emi As Integer, epm As Integer
Private dp As Integer, dmic As Integer, dmi As Integer, drb As Integer


Public Function Wg(ByVal i As Integer) As Integer
  Dim c As Integer
  c = Vid.Cur
  Vid.SelBlock Data.WOB
  Wg = Peek(&H4000 + i)
  Vid.SelBlock c
End Function

Public Sub Wp(ByVal i As Integer, ByVal v As Integer)
  Dim c As Integer
  c = Vid.Cur
  Vid.SelBlock Data.WOB
  Poke &H4000 + i, v And 255
  Vid.SelBlock c
End Sub

Public Function Og(ByVal i As Integer) As Integer
  Dim c As Integer
  c = Vid.Cur
  Vid.SelBlock Data.WOB
  Og = Peek(&H4000 + OOFF + i)
  Vid.SelBlock c
End Function

Public Sub Op(ByVal i As Integer, ByVal v As Integer)
  Dim c As Integer
  c = Vid.Cur
  Vid.SelBlock Data.WOB
  Poke &H4000 + OOFF + i, v And 255
  Vid.SelBlock c
End Sub

' B(rb, olo, ohi, alo, ahi): the byte at ROM index (offset + address): offset and address are 16 bit values, each as its two bytes;
' rb is the ROM's first data block. The index can pass 64K (a ROM is 128KB), so the sum is done in the Z80 with the carry kept.
Public Function B(ByVal rb As Integer, ByVal olo As Integer, ByVal ohi As Integer, ByVal alo As Integer, ByVal ahi As Integer) As Integer
  Dim r As Integer
#asm
            ld ({sps}), sp
            ld sp, (ntc_csp)
            ld a, ({ohi})
            ld h, a
            ld a, ({olo})
            ld l, a
            ld a, ({ahi})
            ld d, a
            ld a, ({alo})
            ld e, a
            add hl, de
            ld a, 0
            rla
            add a, a
            add a, a
            ld c, a
            ld a, h
            rlca
            rlca
            and 3
            add a, c
            ld c, a
            ld a, ({rb})
            add a, c
            ld c, a
            ld a, h
            and 63
            or #40
            ld h, a
            push hl
            ld l, c
            ld h, 0
            ld de, ntc_nexdata + 1
            add hl, de
            ld l, (hl)
            ld h, 0
            call zxn_sel
            pop hl
            ld a, (hl)
            ld l, a
            ld h, 0
            ld ({r}), hl
            push af
            push bc
            ld bc, (ntc_rampt)
            call nxt_win
            ld a, #FF
            ld (zxn_selb), a
            pop bc
            pop af
            ld sp, ({sps})
#endasm
  B = r
End Function

' Man(f, k): byte k of file f's manifest row (tools/assets.js): 0 layers, 1+2n protocol, 2+2n rom (n = layer 0-2), 7 spare,
' 8-9 window, 10-11 offset in the files block, 12-13 length, 14-15 name
Public Function Man(ByVal f As Integer, ByVal k As Integer) As Integer
  If f = 4 Then
    Man = MY(k)
    Exit Function
  End If
  Man = Vid.TabB(Data.T_MAN + f * 16 + k)
End Function

' RomBlock(id): the first data block of ROM id (0-2 the 128KB ones, 3 the small one)
Public Function RomBlock(ByVal id As Integer) As Integer
  Select Case id
    Case 0
      RomBlock = Data.ROMB0
    Case 1
      RomBlock = Data.ROMB1
    Case 2
      RomBlock = Data.ROMB2
    Case Else
      RomBlock = Data.ROMBS
  End Select
End Function

' Load f: file f of the manifest becomes W (Wn bytes)
Public Sub Load(ByVal f As Integer)
  Dim i As Integer, off As Integer
  If f = 4 Then
    Wn = Sn
    Vid.SelBlock Data.SCRB
    For i = 0 To Sn - 1
      Wp i, Peek(&H4000 + i)
    Next
    Vid.SelBlock -1
    Exit Sub
  End If
  Wn = Man(f, 12) + Man(f, 13) * 256
  off = Man(f, 10) + Man(f, 11) * 256
  Vid.SelBlock Data.FILEB
  For i = 0 To Wn - 1
    Wp i, Peek(&H4000 + off + i)
  Next
  Vid.SelBlock -1
End Sub

' Take n: W = the first n bytes of O
Public Sub Take(ByVal n As Integer)
  Dim i As Integer
  For i = 0 To n - 1
    Wp i, Og(i)
  Next
  Wn = n
End Sub

' Layer rb, proto: decodes W with the ROM starting at block rb into O; proto 0 ZOSCII (16 bit addresses from byte 0, the window is the
' ROM's start), 1 UNSIGNAL (4 header addresses read through the ROM: offset low, offset high, prefix length, suffix length).
' Returns the number of bytes decoded.
Public Function Layer(ByVal rb As Integer, ByVal proto As Integer) As Integer
  Dim p As Integer, e As Integer, n As Integer, olo As Integer, ohi As Integer, pf As Integer, sf As Integer
  If proto >= 2 Then
    Layer = LayerX(rb, proto)
    Exit Function
  End If
  olo = 0 : ohi = 0
  p = 0 : e = Wn
  If proto = 1 Then
    olo = B(rb, 0, 0, Wg(0), Wg(1))
    ohi = B(rb, 0, 0, Wg(2), Wg(3))
    pf = B(rb, 0, 0, Wg(4), Wg(5))
    sf = B(rb, 0, 0, Wg(6), Wg(7))
    p = 8 + pf
    e = Wn - sf
  End If
  n = 0
  Do While p + 1 < e
    Op n, B(rb, olo, ohi, Wg(p), Wg(p + 1))
    n = n + 1
    p = p + 2
  Loop
  Layer = n
End Function

' Pick v: a blind pick: a random place in the first 64K of ROM 1, then the next place from there (wrapping) that holds v.
' The address is PickLo / PickHi (two bytes). Returns 0 if v isn't in the window.
Public PickLo As Integer, PickHi As Integer
Public Function Pick(ByVal rb As Integer, ByVal v As Integer) As Integer
  Dim b0 As Integer, o0 As Integer, pass As Integer, blk As Integer, lo As Integer, hi As Integer, i As Integer
  b0 = Rng.Pick(4)
  o0 = Rng.Pick(16384)
  Pick = 0
  For pass = 0 To 4
    blk = (b0 + pass) And 3
    lo = 0 : hi = 16383
    If pass = 0 Then lo = o0
    If pass = 4 Then hi = o0 - 1
    If lo <= hi Then
      Vid.SelBlock rb + blk
      For i = lo To hi
        If Peek(&H4000 + i) = v Then
          PickLo = i And 255
          PickHi = blk * 64 + i \ 256
          Pick = 1
          Exit For
        End If
      Next
      Vid.SelBlock -1
      If Pick = 1 Then Exit For
    End If
  Next
End Function

' Count rb, v: how many places in the first 64K of the ROM hold v (0-65535 fits an Integer only as a count of a byte value: it is
' returned as a count up to 32767; a ROM with more than that of one value would need a Long)
Public Function Count(ByVal rb As Integer, ByVal v As Integer) As Integer
  Dim blk As Integer, i As Integer, n As Integer
  n = 0
  For blk = 0 To 3
    Vid.SelBlock rb + blk
    For i = 0 To 16383
      If Peek(&H4000 + i) = v Then n = n + 1
    Next
  Next
  Vid.SelBlock -1
  Count = n
End Function

' LoadPatch: the cells of the alternative ROM (alt_b.bin) into the arrays; Patch on: ROM 1 gets those cells, Patch off: it gets its own back
Public Sub LoadPatch()
  Dim i As Integer, off As Integer
  off = Data.PATCHOFF
  Vid.SelBlock Data.FILEB
  For i = 0 To Data.PATCHN - 1
    pl(i) = Peek(&H4000 + off + i * 4)
    pm(i) = Peek(&H4000 + off + i * 4 + 1)
    ph(i) = Peek(&H4000 + off + i * 4 + 2)
    pv(i) = Peek(&H4000 + off + i * 4 + 3)
  Next
  Vid.SelBlock -1
  patched = 0
End Sub

Public Sub Patch(ByVal sw As Integer)
  Dim i As Integer, blk As Integer, a As Integer
  If sw = patched Then Exit Sub
  For i = 0 To Data.PATCHN - 1
    blk = Data.ROMB0 + ph(i) * 4 + pm(i) \ 64
    a = &H4000 + (pm(i) And 63) * 256 + pl(i)
    Vid.SelBlock blk
    If sw <> 0 Then
      ov(i) = Peek(a)
      Poke a, pv(i)
    Else
      Poke a, ov(i)
    End If
  Next
  Vid.SelBlock -1
  patched = sw
End Sub

' Scan rb, v, lo, hi: the first ROM index from lo to hi (17 bit, as Long) whose byte is v, or -1
Private Function Scan(ByVal rb As Integer, ByVal v As Integer, ByVal lo As Long, ByVal hi As Long) As Long
  Dim cur As Long, base As Long, lim As Long, blk As Integer, w As Integer, e As Integer, i As Integer
  Scan = -1
  cur = lo
  Do While cur <= hi
    blk = CInt(cur \ 16384)
    base = blk
    base = base * 16384
    w = CInt(cur - base)
    lim = base + 16383
    If lim > hi Then lim = hi
    e = CInt(lim - base)
    Vid.SelBlock rb + blk
    For i = w To e
      If Peek(&H4000 + i) = v Then
        Scan = base + i
        Exit For
      End If
    Next
    Vid.SelBlock -1
    If Scan >= 0 Then Exit Function
    cur = base + 16384
  Loop
End Function

' PickIdx rb, v, olo, ohi, win: a blind pick inside the window that starts at offset (olo, ohi) and is win bytes long (0 = 64K):
' a random place in it, then the next place from there (wrapping) that holds v. The ADDRESS (the place minus the offset)
' is PickLo / PickHi. Returns 0 if v is not in the window.
Public Function PickIdx(ByVal rb As Integer, ByVal v As Integer, ByVal olo As Integer, ByVal ohi As Integer, ByVal win As Integer) As Integer
  Dim off As Long, a0 As Long, wn As Long, r As Long, ad As Long, t As Long
  off = ohi
  off = off * 256 + olo
  If win = 0 Then
    wn = 65536
  Else
    wn = win
  End If
  a0 = Rng.Pick(256)
  a0 = a0 * 256 + Rng.Pick(256)
  If a0 >= wn Then a0 = a0 - (a0 \ wn) * wn
  PickIdx = 0
  r = Scan(rb, v, off + a0, off + wn - 1)
  If r < 0 And a0 > 0 Then r = Scan(rb, v, off, off + a0 - 1)
  If r < 0 Then Exit Function
  ad = r - off
  t = ad \ 256
  PickHi = CInt(t)
  PickLo = CInt(ad - t * 256)
  PickIdx = 1
End Function

' Enc rb, proto, win: encodes W (Wn bytes) into O with the ROM at block rb. proto 0 ZOSCII (16 bit addresses, window at 0), 1 UNSIGNAL
' (the same steps as gen_encode in tools/zlib.js, sliding window; prefix and suffix 10 to pmax bytes). Returns the number of bytes, -1 if a value isn't in the ROM, -2 if too big.
Public Function Enc(ByVal rb As Integer, ByVal proto As Integer, ByVal win As Integer, ByVal pmax As Integer) As Integer
  Dim i As Integer, n As Integer, olo As Integer, ohi As Integer, pf As Integer, sf As Integer, k As Integer, hv As Integer
  If proto >= 2 Then
    Enc = EncX(rb, proto, win, pmax)
    Exit Function
  End If
  n = 0
  If proto = 0 Then
    If Wn * 2 > 2304 Then
      Enc = -2
      Exit Function
    End If
    For i = 0 To Wn - 1
      If PickIdx(rb, Wg(i), 0, 0, win) = 0 Then
        Enc = -1
        Exit Function
      End If
      Op n, PickLo
      Op n + 1, PickHi
      n = n + 2
    Next
    Enc = n
    Exit Function
  End If
  olo = Rng.Pick(256)
  ohi = Rng.Pick(256)
  pf = 10 + Rng.Pick(pmax - 9)
  sf = 10 + Rng.Pick(pmax - 9)
  If 8 + pf + Wn * 2 + sf > 2304 Then
    Enc = -2
    Exit Function
  End If
  For k = 0 To 3
    Select Case k
      Case 0
        hv = olo
      Case 1
        hv = ohi
      Case 2
        hv = pf
      Case Else
        hv = sf
    End Select
    If PickIdx(rb, hv, 0, 0, 0) = 0 Then
      Enc = -1
      Exit Function
    End If
    Op k * 2, PickLo
    Op k * 2 + 1, PickHi
  Next
  n = 8
  For i = 1 To pf
    Op n, Rng.Pick(256)
    n = n + 1
  Next
  For i = 0 To Wn - 1
    If PickIdx(rb, Wg(i), olo, ohi, 0) = 0 Then
      Enc = -1
      Exit Function
    End If
    Op n, PickLo
    Op n + 1, PickHi
    n = n + 2
  Next
  For i = 1 To sf
    Op n, Rng.Pick(256)
    n = n + 1
  Next
  Enc = n
End Function

' ---- BRICS (2) and the micro protocols (3 microZOSCII, 4 microUNSIGNAL, 5 microBRICS): the steps of Proto.Enc, with the ROM of the layer.
' A micro ROM is 256 nibbles, an address is one byte, a message byte is two addresses (high nibble, low nibble), and the offset is olo + 16 ohi,
' wrapping inside the 256. Header values are addresses read with no offset.

' MakeMic: new micro ROMs, each nibble 16 times, shuffled
Public Sub MakeMic()
  Dim r As Integer, i As Integer, j As Integer, t As Integer, b As Integer
  For r = 0 To 3
    b = r * 256
    For i = 0 To 255
      Mm(b + i) = i \ 16
    Next
    For i = 255 To 1 Step -1
      j = Rng.Pick(i + 1)
      t = Mm(b + i)
      Mm(b + i) = Mm(b + j)
      Mm(b + j) = t
    Next
  Next
End Sub

' MicIdx(rb): which micro ROM goes with the data block rb (the ROM of that layer)
Private Function MicIdx(ByVal rb As Integer) As Integer
  If rb = Data.ROMB0 Then
    MicIdx = 0
  ElseIf rb = Data.ROMB1 Then
    MicIdx = 1
  ElseIf rb = Data.ROMB2 Then
    MicIdx = 2
  Else
    MicIdx = 3
  End If
End Function

Private Sub EPut(ByVal v As Integer)
  If ebad <> 0 Then Exit Sub
  If ep >= 2304 Then
    ebad = -2
    Exit Sub
  End If
  Op ep, v
  ep = ep + 1
End Sub

' EAdr v, olo, ohi: one address of a place holding v, read with the offset: out as one byte (micro) or two
Private Sub EAdr(ByVal v As Integer, ByVal olo As Integer, ByVal ohi As Integer)
  Dim a As Integer, k As Integer
  If ebad <> 0 Then Exit Sub
  If emic = 1 Then
    a = Rng.Pick(256)
    k = 0
    Do While Mm(emi * 256 + ((a + olo + ohi * 16) And 255)) <> v And k < 256
      a = (a + 1) And 255
      k = k + 1
    Loop
    If k >= 256 Then
      ebad = -1
      Exit Sub
    End If
    EPut a
  Else
    If PickIdx(erb, v, olo, ohi, ewin) = 0 Then
      ebad = -1
      Exit Sub
    End If
    EPut PickLo
    EPut PickHi
  End If
End Sub

Private Sub ESym(ByVal c As Integer, ByVal olo As Integer, ByVal ohi As Integer)
  If emic = 1 Then
    EAdr c \ 16, olo, ohi
    EAdr c And 15, olo, ohi
  Else
    EAdr c, olo, ohi
  End If
End Sub

Private Sub EHv(ByVal v As Integer)
  EAdr v, 0, 0
End Sub

Private Sub EHvW(ByVal v As Integer)
  If emic = 1 Then
    EHv v And 15
    EHv v \ 16
  Else
    EHv v And 255
    EHv v \ 256
  End If
End Sub

Private Sub EHvO(ByVal l As Integer, ByVal h As Integer)
  If emic = 1 Then
    EHv l And 15
    EHv l \ 16
  Else
    EHv l
    EHv h
  End If
End Sub

Private Function EPad() As Integer
  If emic = 1 Then
    EPad = 10 + Rng.Pick(6)
  Else
    EPad = 10 + Rng.Pick(epm - 9)
  End If
End Function

' EncX rb, proto, win: protocols 2 to 5, W into O. The bytes, -1 a value isn't in the ROM, -2 too big
Private Function EncX(ByVal rb As Integer, ByVal proto As Integer, ByVal win As Integer, ByVal pmax As Integer) As Integer
  Dim kind As Integer, i As Integer, b As Integer, rm As Integer, cb As Integer, nb As Integer, pf As Integer, sf As Integer
  Dim ol As Integer, oh As Integer, bo As Integer, bh As Integer, nl As Integer, nh As Integer, w As Integer, pos As Integer
  emic = 0
  If proto >= 3 Then emic = 1
  kind = proto - emic * 3
  w = 1 + emic
  erb = rb
  ewin = win
  epm = pmax
  emi = MicIdx(rb)
  ep = 0
  ebad = 0
  If kind = 0 Then
    For i = 0 To Wn - 1
      ESym Wg(i), 0, 0
    Next
    EncX = ep
    If ebad <> 0 Then EncX = ebad
    Exit Function
  End If
  pf = EPad()
  sf = EPad()
  If kind = 1 Then
    If emic = 1 Then
      ol = Rng.Pick(256)
      oh = ol \ 16
      ol = ol And 15
    Else
      ol = Rng.Pick(256)
      oh = Rng.Pick(256)
    End If
    EHv ol
    EHv oh
    EHv pf
    EHv sf
    For i = 1 To pf
      EPut Rng.Pick(256)
    Next
    For i = 0 To Wn - 1
      ESym Wg(i), ol, oh
    Next
    For i = 1 To sf
      EPut Rng.Pick(256)
    Next
    EncX = ep
    If ebad <> 0 Then EncX = ebad
    Exit Function
  End If
  ' BRICS: the first block, then the header
  rm = Wn
  cb = 8 + Rng.Pick(17)
  If cb > rm Then cb = rm
  bo = Rng.Pick(256)
  If emic = 1 Then
    ol = bo And 15
    oh = bo \ 16
  Else
    ol = bo
    oh = Rng.Pick(256)
  End If
  EHvO ol + oh * 16 * emic, oh
  EHvW cb * w
  EHv pf
  EHv sf
  For i = 1 To pf
    EPut Rng.Pick(256)
  Next
  pos = 0
  Do While rm > 0 And ebad = 0
    rm = rm - cb
    If rm > 0 Then
      nb = 8 + Rng.Pick(17)
      If nb > rm Then nb = rm
      nl = Rng.Pick(256)
      If emic = 1 Then
        nh = nl \ 16
        nl = nl And 15
      Else
        nh = Rng.Pick(256)
      End If
      EHvO nl + nh * 16 * emic, nh
      EHvW nb * w
    Else
      nb = 0
      nl = 0
      nh = 0
      EHvO Rng.Pick(256), Rng.Pick(256)
      EHvW Rng.Pick(256)
    End If
    For i = 1 To cb
      ESym Wg(pos), ol, oh
      pos = pos + 1
    Next
    ol = nl
    oh = nh
    cb = nb
  Loop
  For i = 1 To sf
    EPut Rng.Pick(256)
  Next
  EncX = ep
  If ebad <> 0 Then EncX = ebad
End Function

' RdV p, olo, ohi: the value the address at W(p) reads (micro one byte, else two)
Private Function RdV(ByVal p As Integer, ByVal olo As Integer, ByVal ohi As Integer) As Integer
  If dmic = 1 Then
    RdV = Mm(dmi * 256 + ((Wg(p) + olo + ohi * 16) And 255))
  Else
    RdV = B(drb, olo, ohi, Wg(p), Wg(p + 1))
  End If
End Function

' LayerX rb, proto: decodes W into O for the protocols 2 to 5; the number of bytes
Private Function LayerX(ByVal rb As Integer, ByVal proto As Integer) As Integer
  Dim kind As Integer, aw As Integer, p As Integer, e As Integer, n As Integer, pf As Integer, sf As Integer
  Dim olo As Integer, ohi As Integer, cb As Integer, nlo As Integer, nhi As Integer, ncb As Integer, i As Integer, v As Integer, hp As Integer
  dmic = 0
  If proto >= 3 Then dmic = 1
  kind = proto - dmic * 3
  aw = 2 - dmic
  drb = rb
  dmi = MicIdx(rb)
  n = 0
  p = 0
  e = Wn
  olo = 0
  ohi = 0
  If kind = 1 Then
    If Wn < 4 * aw Then
      LayerX = 0
      Exit Function
    End If
    olo = RdV(0, 0, 0)
    ohi = RdV(aw, 0, 0)
    pf = RdV(2 * aw, 0, 0)
    sf = RdV(3 * aw, 0, 0)
    p = 4 * aw + pf
    e = Wn - sf
  End If
  If kind = 2 Then
    If Wn < 6 * aw Then
      LayerX = 0
      Exit Function
    End If
    olo = RdV(0, 0, 0)
    ohi = RdV(aw, 0, 0)
    If dmic = 1 Then
      cb = RdV(2 * aw, 0, 0) + 16 * RdV(3 * aw, 0, 0)
    Else
      cb = RdV(2 * aw, 0, 0) + 256 * RdV(3 * aw, 0, 0)
    End If
    pf = RdV(4 * aw, 0, 0)
    sf = RdV(5 * aw, 0, 0)
    p = 6 * aw + pf
    e = Wn - sf
  End If
  If 0 > p Or p > Wn Or e < p Then
    LayerX = 0
    Exit Function
  End If
  If kind < 2 Then
    Do While p + 1 < e And n < 2300
      If dmic = 1 Then
        Op n, RdV(p, olo, ohi) * 16 + RdV(p + 1, olo, ohi)
        p = p + 2
      Else
        Op n, RdV(p, olo, ohi)
        p = p + 2
      End If
      n = n + 1
    Loop
  Else
    Do While p < e
      If p + 4 * aw > e Then Exit Do
      nlo = RdV(p, 0, 0)
      nhi = RdV(p + aw, 0, 0)
      If dmic = 1 Then
        ncb = RdV(p + 2 * aw, 0, 0) + 16 * RdV(p + 3 * aw, 0, 0)
      Else
        ncb = RdV(p + 2 * aw, 0, 0) + 256 * RdV(p + 3 * aw, 0, 0)
      End If
      p = p + 4 * aw
      hp = cb
      If dmic = 1 Then hp = cb \ 2
      For i = 1 To hp
        If p + 1 < e And n < 2300 Then
          If dmic = 1 Then
            Op n, RdV(p, olo, ohi) * 16 + RdV(p + 1, olo, ohi)
          Else
            Op n, RdV(p, olo, ohi)
          End If
          n = n + 1
          p = p + 2
        End If
      Next
      olo = nlo
      ohi = nhi
      cb = ncb
    Loop
  End If
  LayerX = n
End Function

' RollHash st, n: the ZOSCII rolling hash of W(st .. st+n-1) into HB (4 strides, each seeded from its last byte)
Public Sub RollHash(ByVal st As Integer, ByVal n As Integer)
  Dim ps As Integer, last As Integer, i As Integer, s As Integer
  For ps = 0 To 3
    HB(ps) = 0
    last = n - 1
    Do While last >= 0 And (last Mod 4) <> ps
      last = last - 1
    Loop
    If last >= 0 Then
      s = Wg(st + last)
      i = last - 4
      Do While i >= 0
        s = s Xor Wg(st + i)
        i = i - 4
      Loop
      s = s Xor Wg(st + last)
      HB(ps) = s
    End If
  Next
End Sub

' SxSave: the file made in Have a Play (W, Wn bytes) goes into the scratch block, from byte 0
Public Sub SxSave()
  Dim i As Integer
  Vid.SelBlock Data.SCRB
  For i = 0 To Wn - 1
    Poke &H4000 + i, Wg(i)
  Next
  Vid.SelBlock -1
  Sn = Wn
End Sub

Public Function SxGet(ByVal i As Integer) As Integer
  Vid.SelBlock Data.SCRB
  SxGet = Peek(&H4000 + i)
  Vid.SelBlock -1
End Function

Public Sub SxPut(ByVal i As Integer, ByVal v As Integer)
  Vid.SelBlock Data.SCRB
  Poke &H4000 + i, v
  Vid.SelBlock -1
End Sub

' Strip4: W loses its first 4 bytes (the rolling hash, once it has been checked)
Public Sub Strip4()
  Dim i As Integer
  For i = 0 To Wn - 5
    Wp i, Wg(i + 4)
  Next
  Wn = Wn - 4
End Sub

' Gen: a ROM of 128KB (data blocks Data.GENB to GENB + 7) from the Rng, 16 bytes at a time (the Rng changes the window, so they wait in gb); the bar shows it
Private gb(15) As Byte
Public Sub Gen()
  Dim b As Integer, p As Integer, i As Integer
  For b = 0 To 7
    For p = 0 To 1023
      For i = 0 To 15
        gb(i) = Rng.Rb()
      Next
      Vid.SelBlock Data.GENB + b
      For i = 0 To 15
        Poke &H4000 + p * 16 + i, gb(i)
      Next
      Vid.SelBlock -1
    Next
    Vid.Fill 20, 120, b * 35 + 35, 8, 10
  Next
End Sub
