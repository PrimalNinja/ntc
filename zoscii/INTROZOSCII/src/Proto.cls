' Proto - the protocols of the demo, as baselines. 0 ZOSCII, 1 UNSIGNAL, 2 BRICS (a 128 KB ROM, 16 bit addresses) and 3 microZOSCII, 4 microUNSIGNAL,
' 5 microBRICS (a 256 nibble ROM Mr, 8 bit addresses, a message byte is two nibbles). Each rule that a user may want to replace is a small routine
' of its own: BlkSize, Pad, Offs. The encoding is built in Blk.Buf from byte 64 (Enc), and Pos finds the ROM position each message
' letter was read from. Every ROM and every file decodes to something: no check anywhere. (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Public Mr(255) As Byte
Public Pg(51) As Integer, Po(51) As Integer
Private n As Integer, mic As Integer
Private bs(7) As Integer, bol(7) As Integer, boh(7) As Integer, bh(7) As Integer

' MakeRom: the micro ROM, 256 nibbles, each value 16 times, shuffled
Public Sub MakeRom()
  Dim i As Integer, j As Integer, t As Integer
  For i = 0 To 255
    Mr(i) = i \ 16
  Next
  For i = 255 To 1 Step -1
    j = Rng.Pick(i + 1)
    t = Mr(i)
    Mr(i) = Mr(j)
    Mr(j) = t
  Next
End Sub

' the rules: block size in elements, padding length, the offset value
Private Function BlkSize() As Integer
  BlkSize = 8 + Rng.Pick(17)
End Function

Private Function Pad() As Integer
  If mic = 1 Then
    Pad = 10 + Rng.Pick(6)
  Else
    Pad = 10 + Rng.Pick(246)
  End If
End Function

Private Function Offs() As Integer
  Offs = Rng.Pick(256)
End Function

Private Sub Put(ByVal v As Integer)
  Blk.Buf(64 + n) = v
  n = n + 1
End Sub

' Adr v, olo, ohi: one address of a place holding v, read with the offset (olo, ohi); micro: the offset is olo + 16 ohi, the space wraps
Private Sub Adr(ByVal v As Integer, ByVal olo As Integer, ByVal ohi As Integer)
  Dim a As Integer, k As Integer
  If mic = 1 Then
    a = Rng.Pick(256)
    k = 0
    Do While Mr((a + olo + ohi * 16) And 255) <> v And k < 256
      a = (a + 1) And 255
      k = k + 1
    Loop
    Put a
  Else
    If Rom.PickIdx(Data.GENB, v, olo, ohi, 0) = 0 Then
      Put 0
      Put 0
    Else
      Put Rom.PickLo
      Put Rom.PickHi
    End If
  End If
End Sub

' Sym c, olo, ohi: a message byte: one address, or two (high nibble, low nibble) in micro
Private Sub Sym(ByVal c As Integer, ByVal olo As Integer, ByVal ohi As Integer)
  If mic = 1 Then
    Adr c \ 16, olo, ohi
    Adr c And 15, olo, ohi
  Else
    Adr c, olo, ohi
  End If
End Sub

' Hv v: a header value (a byte, or a nibble in micro) as an address with no offset
Private Sub Hv(ByVal v As Integer)
  Adr v, 0, 0
End Sub

' HvW v: a header value of 8 or 16 bits: two addresses, low part first
Private Sub HvW(ByVal v As Integer)
  If mic = 1 Then
    Hv v And 15
    Hv v \ 16
  Else
    Hv v And 255
    Hv v \ 256
  End If
End Sub

' HvO l, h: a block offset (low, high bytes; micro: l is the 8 bit offset) as header addresses
Private Sub HvO(ByVal l As Integer, ByVal h As Integer)
  If mic = 1 Then
    Hv l And 15
    Hv l \ 16
  Else
    Hv l
    Hv h
  End If
End Sub

' Enc pr: the encoding of W (Wn bytes) into Blk.Buf from 64; returns its length
Public Function Enc(ByVal pr As Integer) As Integer
  Dim kind As Integer, i As Integer, b As Integer, nb As Integer, rm As Integer, pf As Integer, sf As Integer, ol As Integer, oh As Integer, w As Integer
  mic = 0
  If pr >= 3 Then mic = 1
  kind = pr - mic * 3
  w = 1 + mic
  n = 0
  If kind = 0 Then
    For i = 0 To Rom.Wn - 1
      Sym Rom.Wg(i), 0, 0
    Next
    Enc = n
    Exit Function
  End If
  pf = Pad()
  sf = Pad()
  If kind = 1 Then
    If mic = 1 Then
      ol = Offs()
      oh = ol \ 16
      ol = ol And 15
    Else
      ol = Offs()
      oh = Offs()
    End If
    Hv ol
    Hv oh
    Hv pf
    Hv sf
    For i = 1 To pf
      Put Rng.Pick(256)
    Next
    For i = 0 To Rom.Wn - 1
      Sym Rom.Wg(i), ol, oh
    Next
    For i = 1 To sf
      Put Rng.Pick(256)
    Next
    Enc = n
    Exit Function
  End If
  nb = 0
  rm = Rom.Wn
  Do While rm > 0
    b = BlkSize()
    If b > rm Then b = rm
    bh(nb) = b
    bs(nb) = b * w
    bol(nb) = Offs()
    boh(nb) = Offs()
    rm = rm - b
    nb = nb + 1
  Loop
  HvO bol(0), boh(0)
  HvW bs(0)
  Hv pf
  Hv sf
  For i = 1 To pf
    Put Rng.Pick(256)
  Next
  rm = 0
  For b = 0 To nb - 1
    If b < nb - 1 Then
      HvO bol(b + 1), boh(b + 1)
      HvW bs(b + 1)
    Else
      HvO Offs(), Offs()
      HvW Offs()
    End If
    If mic = 1 Then
      ol = bol(b) And 15
      oh = bol(b) \ 16
    Else
      ol = bol(b)
      oh = boh(b)
    End If
    For i = 1 To bh(b)
      Sym Rom.Wg(rm), ol, oh
      rm = rm + 1
    Next
  Next
  For i = 1 To sf
    Put Rng.Pick(256)
  Next
  Enc = n
End Function

' Pos pr: for protocols 0-2, the ROM position (256 byte page Pg 0-511, byte Po) each of the 52 message letters is read from, by the
' encoding in Blk.Buf from 64
Public Sub Pos(ByVal pr As Integer)
  Dim i As Integer, p As Integer, ro As Integer, rh As Integer, pf As Integer, sz As Integer, nro As Integer, nrh As Integer, nsz As Integer
  Dim q As Integer, lo As Integer, hi As Integer
  p = 0
  ro = 0
  rh = 0
  sz = 52
  If pr = 1 Then
    ro = Rom.B(Data.GENB, 0, 0, Blk.Buf(64), Blk.Buf(65))
    rh = Rom.B(Data.GENB, 0, 0, Blk.Buf(66), Blk.Buf(67))
    p = 8 + Rom.B(Data.GENB, 0, 0, Blk.Buf(68), Blk.Buf(69))
  End If
  If pr = 2 Then
    ro = Rom.B(Data.GENB, 0, 0, Blk.Buf(64), Blk.Buf(65))
    rh = Rom.B(Data.GENB, 0, 0, Blk.Buf(66), Blk.Buf(67))
    sz = Rom.B(Data.GENB, 0, 0, Blk.Buf(68), Blk.Buf(69)) + 256 * Rom.B(Data.GENB, 0, 0, Blk.Buf(70), Blk.Buf(71))
    p = 12 + Rom.B(Data.GENB, 0, 0, Blk.Buf(72), Blk.Buf(73))
  End If
  i = 0
  Do While i < 52
    If pr = 2 Then
      nro = Rom.B(Data.GENB, 0, 0, Blk.Buf(64 + p), Blk.Buf(65 + p))
      nrh = Rom.B(Data.GENB, 0, 0, Blk.Buf(66 + p), Blk.Buf(67 + p))
      nsz = Rom.B(Data.GENB, 0, 0, Blk.Buf(68 + p), Blk.Buf(69 + p)) + 256 * Rom.B(Data.GENB, 0, 0, Blk.Buf(70 + p), Blk.Buf(71 + p))
      p = p + 8
    End If
    For q = 1 To sz
      If i < 52 Then
        lo = Blk.Buf(64 + p) + ro
        hi = Blk.Buf(65 + p) + rh
        If lo > 255 Then
          lo = lo - 256
          hi = hi + 1
        End If
        Pg(i) = hi
        Po(i) = lo
        i = i + 1
      End If
      p = p + 2
    Next
    ro = nro
    rh = nrh
    sz = nsz
    If sz < 1 Then sz = 52
  Loop
End Sub
