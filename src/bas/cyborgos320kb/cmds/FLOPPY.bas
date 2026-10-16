' FLOPPY: CPC floppy discs read and written track by track, in CyborgOS (build for cpm, with
' CybDir.cls) - FLOPPY from to, as COPY:
'   FLOPPY A                          its files listed (A, DFA or FDA: the first drive; B, DFB,
'                                     FDB: the second; a ":" after it or not)
'   FLOPPY A GAMES                    each file copied into the folder GAMES (in this drive's
'                                     folder: made if it isn't there - UniDOS)
'   FLOPPY A IDE:GAMES/X              anywhere (a device or a drive, then the folders)
'   FLOPPY A C:                       into drive C as it is (a RAM disc ...)
'   FLOPPY A GAME.DSK                 the whole disc as a .DSK image (extended: each track's own
'   FLOPPY A IDE:IMGS/GAME.DSK        sectors, as read) - in this drive's folder, a folder, a
'                                     drive (C:GAME.DSK)
'   FLOPPY GAMES A                    the other way: each file in the folder (or drive: C:) onto
'                                     the disc - added to what it has (one of the same name
'                                     replaced), its AMSDOS header with it (UniDOS's)
'   FLOPPY GAME.DSK A                 the image onto the disc: each track formatted as the image
'                                     has it (its sector numbers and sizes), its sectors written
' The disc controller (the uPD765) is driven here, not through AMSDOS or UniDOS (UniDOS turns
' AMSDOS's sector calls off): data format (sectors C1-C9), system format (41-49: 2 tracks kept
' for the system) and IBM (01-08: 1 track). A file is copied as CP/M sees it, record by
' record, with its AMSDOS header (a BASIC or binary file's), so the copy loads as the
' original did. Nothing else should use the floppy drives while it runs
Option Explicit
Dim tb(4607) As Byte                             ' a track (up to 9 sectors of 512)
Dim dr(2047) As Byte                             ' the directory (64 entries of 32)
Dim rs(15) As Byte                               ' the controller's last result (ST0, ST1, ST2 ...)
Dim b(71) As Byte, q(49) As Byte                 ' (UniDOS calls: BDOS 30; RAM discs: BDOS 130)
Dim fn(63) As String Max 12, fu(63) As Integer, fx(63) As Integer, fr(63) As Long
Dim a As String Max 60, dv As String Max 8, tg As String Max 60, p As String Max 60, v As String Max 2
Dim fm As String Max 8, s As String Max 12, tn As String Max 60
Dim hsp As Integer, rp As Integer, drv As Integer, base As Integer, spt As Integer, off As Integer
Dim ct As Integer, nf As Integer, i As Integer, j As Integer, k As Integer, r As Integer
Dim e As Integer, x As Integer, ho As Integer, nd As Integer, uni As Integer, w As Integer, pf As Integer
Dim tot As Long, n As Long
Dim id(3359) As Byte, ns(41) As Integer, hb(255) As Byte  ' (DSK: each track's sector IDs - C H R N, 20 at most)
Dim dk As String Max 12, nt As Integer, t As Integer
Dim fh As Integer, fgap As Integer, ffill As Integer   ' (the controller: a sector's H; a format's gap, filler)
Dim wr As Integer, w1 As String Max 60, w2 As String Max 60, d1 As Integer, d2 As Integer
Dim ub(255) As Byte, bl(255) As Byte, dsm As Integer   ' (onto a disc: its blocks in use, a file's blocks)

rp = VarPtr(rs)
a = UCase$(Trim$(System.CommandLine()))
i = InStr(a, " ")
If i = 0 Then w1 = a : w2 = "" Else w1 = Left$(a, i - 1) : w2 = Trim$(Mid$(a, i + 1))
d1 = FlopNo(w1) : d2 = FlopNo(w2)
tg = "" : dk = "" : wr = 0 : drv = -1
If d1 >= 0 And w2 = "" Then
  drv = d1 : dv = w1                             ' FLOPPY A: its files
ElseIf d1 >= 0 And d2 < 0 And InStr(w2, " ") = 0 Then
  drv = d1 : dv = w1 : tg = w2                   ' FLOPPY A to
ElseIf d1 < 0 And d2 >= 0 Then
  drv = d2 : dv = w2 : tg = w1 : wr = 1          ' FLOPPY from A
End If
If drv < 0 Then
  Print "FLOPPY A|B             the disc's files"
  Print "FLOPPY A|B folder      its files copied into the folder (or a drive: C:)"
  Print "FLOPPY A|B NAME.DSK    the disc as a .DSK image (IDE:IMGS/NAME.DSK ...)"
  Print "FLOPPY folder A|B      the folder's files onto the disc"
  Print "FLOPPY NAME.DSK A|B    the image onto the disc"
  End
End If
If Right$(dv, 1) = ":" Then dv = Left$(dv, Len(dv) - 1)
If Right$(tg, 4) = ".DSK" Then                   ' a .DSK image: its folder (or drive), its name
  k = 0
  For i = 1 To Len(tg)
    If Mid$(tg, i, 1) = "/" Or Mid$(tg, i, 1) = ":" Then k = i
  Next
  dk = Mid$(tg, k + 1) : tg = Left$(tg, k)
  If Right$(tg, 1) = "/" Then tg = Left$(tg, Len(tg) - 1)
  If tg = "" Then tg = FileSystem.CurrentVolume() + ":"
  i = InStr(dk, ".")
  If i < 2 Or i > 9 Then Print dk; ": not a disc name (NAME.DSK)" : End
End If

' the folder (or drive) first: to, made if it isn't there; from, there (nothing read or written
' on the disc if it can't be reached)
b(0) = &HC0 : uni = (Bdos(30, VarPtr(b)) = 0)
If tg <> "" Then
  If Len(tg) = 2 And Right$(tg, 1) = ":" Then
    v = tg                                       ' a drive as it is
    tn = v
  Else
    If Not uni Then Print "Folders need UniDOS (a drive will do: C:)" : End
    p = tg
    If InStr(tg, ":") = 0 Then                   ' in this drive's folder
      v = FileSystem.CurrentVolume()
      p = PathOf(v)
      If p = "" Then p = v + ":"
      p = p + tg
    End If
    If Right$(p, 1) <> "/" And Right$(p, 1) <> ":" Then p = p + "/"
    If Len(p) > 31 Then Print "A path is 31 characters at most" : End
    b(0) = &HC5 : b(1) = 0 : b(2) = 0 : b(3) = 0     ' there? (its first entry asked for)
    SetStr 28, p
    r = Bdos(30, VarPtr(b))
    If r <> 0 And r <> 1 Then
      If wr Then Print p; ": not there" : End
      b(0) = &HC6                                ' no: made
      SetStr 2, p
      r = Bdos(30, VarPtr(b))
      If r <> 0 Then Print p; ": can't be made (UniDOS: "; Trim$(Str$(r)); ")" : End
      Print p; " made"
    End If
    v = FreeLetter()
    If v = "" Then Print "No drive letter free (C-P) to reach it through" : End
    b(0) = &HC2 : b(1) = Asc(v)                  ' the letter's path: the folder, while copying
    SetStr 2, p
    r = Bdos(30, VarPtr(b))
    If r <> 0 Then Print p; ": not a folder (UniDOS: "; Trim$(Str$(r)); ")" : End
    pf = 1 : tn = p
    v = v + ":"
  End If
End If

' the disc: the motor on, track 0, its format from a sector's number
r = Fdc(0, drv, 0, 1, 0)
r = Fdc(2, drv, 0, 0, 0)
If r <> 0 Then r = Fdc(2, drv, 0, 0, 0)          ' (an 80 track drive can need two)
If r <> 0 Then Bad "no drive " + dv + " (the controller: " + Trim$(Str$(r)) + ")"
If wr And dk <> "" Then DskWrite                 ' (a disc not formatted yet will do)
r = Fdc(4, drv, 0, 0, 0)
If r <> 0 Then r = Fdc(4, drv, 0, 0, 0)
If r <> 0 Then Bad "no disc in " + dv + "? (its sectors can't be found)"
If dk <> "" Then DskImage
x = rs(5)
If (x And &HF0) = &HC0 Then
  base = &HC1 : spt = 9 : off = 0 : fm = "data"
ElseIf (x And &HF0) = &H40 Then
  base = &H41 : spt = 9 : off = 2 : fm = "system"
ElseIf (x And &HF0) = 0 Then
  base = 1 : spt = 8 : off = 1 : fm = "IBM"
Else
  Bad "a format not known (sector &" + Hex$(x) + ")"
End If
ct = -1
For i = 0 To 3                                   ' the directory: its first 4 sectors (2K)
  k = Sector(i)
  For j = 0 To 511
    dr(i * 512 + j) = tb(k + j)
  Next
Next
If wr Then FilesWrite

' its files: each name (and user) once, its length from its extents (16K each: EX + 32 * S2)
nf = 0
For e = 0 To 63
  x = e * 32
  If dr(x) <= 15 Then
    s = ""
    For j = 1 To 8
      If (dr(x + j) And 127) > 32 Then s = s + Chr$(dr(x + j) And 127)
    Next
    If (dr(x + 9) And 127) > 32 Then
      s = s + "."
      For j = 9 To 11
        If (dr(x + j) And 127) > 32 Then s = s + Chr$(dr(x + j) And 127)
      Next
    End If
    k = -1
    For j = 0 To nf - 1
      If fn(j) = s And fu(j) = dr(x) Then k = j
    Next
    If k < 0 And nf < 64 Then k = nf : fn(k) = s : fu(k) = dr(x) : fr(k) = 0 : fx(k) = 0 : nf = nf + 1
    If k >= 0 Then
      n = CLng((dr(x + 12) And 31) + 32 * dr(x + 14)) * 128 + dr(x + 15)
      If n > fr(k) Then fr(k) = n
      If (dr(x + 12) And 31) + 32 * dr(x + 14) > fx(k) Then fx(k) = (dr(x + 12) And 31) + 32 * dr(x + 14)
    End If
  End If
Next

If tg = "" Then                                  ' a list
  tot = 0
  For k = 0 To nf - 1
    Print Left$(fn(k) + "            ", 13); fr(k) * 128;
    If fu(k) <> 0 Then Print "  (user "; Trim$(Str$(fu(k))); ")" Else Print
    tot = tot + fr(k)
  Next
  Print nf; " files, "; (tot + 7) \ 8; "K on "; dv; " ("; fm; " format)"
  Done
End If

' each file to v
nd = 0
For k = 0 To nf - 1
  s = fn(k)
  For j = 0 To k - 1                             ' (the same name in another user area: once)
    If fn(j) = s Then s = ""
  Next
  If s = "" Then
    Print fn(k); " (user "; fu(k); "): skipped, a file of that name is copied"
  Else
    ho = FileSystem.Open(v + s, FileSystem.ForWrite)
    If ho < 0 Then
      Print v; s; ": can't be made ("; ho; ")"
    Else
      n = fr(k) * 128                            ' bytes still to copy
      tot = 0
      For x = 0 To fx(k)                         ' its extents in order
        For e = 0 To 63
          If dr(e * 32) = fu(k) And Named(e) = fn(k) And (dr(e * 32 + 12) And 31) + 32 * dr(e * 32 + 14) = x Then
            For j = 16 To 31                     ' its blocks (1K: 2 sectors each)
              If dr(e * 32 + j) <> 0 And n > 0 Then
                For i = 0 To 1
                  If n > 0 Then
                    r = Sector(dr(e * 32 + j) * 2 + i)
                    If n > 512 Then w = 512 Else w = CInt(n)
                    If FileSystem.Write(ho, VarPtr(tb) + r, w) <> w Then Print v; s; ": the disc is full, or a write failed" : n = 0 : nd = nd - 1
                    n = n - w : tot = tot + w
                  End If
                Next
              End If
            Next
          End If
        Next
      Next
      r = FileSystem.Close(ho)
      Print fn(k); " to "; tn; s; ": "; tot; " bytes"
      nd = nd + 1
    End If
  End If
Next
Print nd; " of "; nf; " files copied"
Done

' the motor off, a drive letter's path gone (into a folder), the end
Sub Done()
  r = Fdc(1, drv, 0, 0, 0)
  If pf <> 0 Then
    b(0) = &HC2 : b(1) = Asc(v) : b(2) = 0
    r = Bdos(30, VarPtr(b))
  End If
  End
End Sub

Sub Bad(ByVal m As String)
  Print m
  Done
End Sub

' s2 a floppy drive's name (A, DFA, FDA; B, DFB, FDB; a ":" after it or not): 0, 1, else -1
Function FlopNo(ByVal s2 As String) As Integer
  If Right$(s2, 1) = ":" Then s2 = Left$(s2, Len(s2) - 1)
  FlopNo = -1
  If s2 = "A" Or s2 = "DFA" Or s2 = "FDA" Then FlopNo = 0
  If s2 = "B" Or s2 = "DFB" Or s2 = "FDB" Then FlopNo = 1
End Function

' the image dk (on v) onto the disc: each track formatted as the image has it (its sectors' IDs,
' their size, its gap and filler), then its sectors written (each tried 3 times; one that can't
' be written counted). Side 0, 42 tracks at most; a track the image has none for left as it is
Sub DskWrite()
  Dim hi As Integer, ext As Integer, c As Integer, m As Integer, o As Integer, z As Integer
  Dim tr As Integer, nbad As Integer, sz As Integer, q1 As Integer
  hi = FileSystem.Open(v + dk, FileSystem.ForReadRaw)
  If hi < 0 Then Bad tn + dk + ": not found"
  If FileSystem.Read(hi, VarPtr(hb), 256) <> 256 Then Bad dk + ": not a .DSK image"
  ext = (hb(0) = 69)                                 ' "EXTENDED CPC DSK File", else "MV - CPC"
  If ext = 0 And (hb(0) <> 77 Or hb(1) <> 86) Then Bad dk + ": not a .DSK image"
  If hb(49) > 1 Then Bad dk + ": two sides (one only, for now)"
  nt = hb(48)
  If nt > 42 Then Bad dk + ":" + Str$(nt) + " tracks (42 at most)"
  For t = 0 To nt - 1                                ' each track's size, in 256s
    If ext Then ns(t) = hb(52 + t) Else ns(t) = (hb(50) + hb(51) * 256) \ 256
  Next
  nbad = 0
  For t = 0 To nt - 1
    If ns(t) > 0 Then
      sz = ns(t) * 256 - 256
      If FileSystem.Read(hi, VarPtr(hb), 256) <> 256 Then Bad dk + ": shorter than it says"
      If sz > 4608 Then Bad "track " + Trim$(Str$(t)) + ": more than 4608 bytes of sectors (FLOPPY's most)"
      If sz > 0 Then
        If FileSystem.Read(hi, VarPtr(tb), sz) <> sz Then Bad dk + ": shorter than it says"
      End If
      c = hb(21)
      If c > 20 Then Bad "track " + Trim$(Str$(t)) + ":" + Str$(c) + " sectors (20 at most)"
      For m = 0 To c * 4 - 1                         ' the IDs, C H R N each
        id(m) = hb(24 + (m \ 4) * 8 + (m And 3))
      Next
      fgap = hb(22) : If fgap = 0 Then fgap = &H52
      ffill = hb(23)
      q1 = Fdc(3, drv, t, 0, 0)
      If q1 = 0 Then q1 = Fdc(7, drv, t, c + 256 * hb(20), VarPtr(id))
      If q1 <> 0 Then
        If rs(1) And 2 Then Bad dv + ": the disc is write protected"
        Bad "track " + Trim$(Str$(t)) + ": can't be formatted (ST0-2 &" + Hex$(rs(0)) + " &" + Hex$(rs(1)) + " &" + Hex$(rs(2)) + ")"
      End If
      o = 0
      For m = 0 To c - 1
        x = 24 + m * 8
        If ext Then z = hb(x + 6) + hb(x + 7) * 256 Else z = SecLen(hb(20))
        fh = hb(x + 1)
        w = 1
        For tr = 1 To 3
          If w <> 0 Then
            w = Fdc(3, drv, t, 0, 0)
            If w = 0 Then w = Fdc(6, drv, hb(x), hb(x + 2) + 256 * hb(x + 3), VarPtr(tb) + o)
          End If
        Next
        If w <> 0 Then nbad = nbad + 1
        o = o + z
      Next
      fh = 0
    End If
  Next
  r = FileSystem.Close(hi)
  Print tn; dk; " to "; dv; ": "; nt; " tracks";
  If nbad > 0 Then Print ", "; nbad; " sectors not written cleanly" Else Print
  Done
End Sub

' each file in the folder (or drive) v onto the disc, added to its directory (one there of the
' same name replaced), into its free blocks: an AMSDOS header (the disc ROM's copy of it, when the
' file has one) first, then the file, the last record padded with ^Z; its entries (an extent each
' 16K) and the directory written after each. Stops at the first that doesn't fit
Sub FilesWrite()
  Dim c As Integer, m As Integer, nb As Integer, ne As Integer, hi As Integer, fb As Integer
  Dim fe As Integer, got As Integer, ps As Integer, y As Integer, o As Integer
  Dim rec As Long, z As Long, nm As String Max 12
  dsm = ((40 - off) * spt) \ 2 - 1               ' the last block (1K)
  If CybDir.LoadAll(v) = False Then Bad tn + ": its files can't be listed"
  nd = 0
  For k = 0 To CybDir.Count() - 1
    nm = CybDir.DiscName(k)
    For e = 0 To 63                              ' one of the same name: gone
      If dr(e * 32) <= 15 Then
        If Named(e) = nm Then dr(e * 32) = &HE5
      End If
    Next
    For c = 0 To 255                             ' the blocks in use (0, 1: the directory)
      ub(c) = 0
    Next
    ub(0) = 1 : ub(1) = 1
    fe = 0
    For e = 0 To 63
      If dr(e * 32) <= 15 Then
        For j = 16 To 31
          If dr(e * 32 + j) <> 0 Then ub(dr(e * 32 + j)) = 1
        Next
      Else
        fe = fe + 1
      End If
    Next
    fb = 0
    For c = 0 To dsm
      If ub(c) = 0 Then fb = fb + 1
    Next
    z = CybDir.Length(k)
    nb = CInt((z + 128 + 1023) \ 1024)
    ne = (nb + 15) \ 16
    If ne = 0 Then ne = 1
    If nb > fb Or ne > fe Then Print nm; ": no room left on the disc (or in its directory)" : Exit For
    hi = FileSystem.Open(v + nm, FileSystem.ForReadRaw)
    If hi < 0 Then
      Print tn; nm; ": can't be read"
    Else
      ps = 0
      b(0) = &HC7                                ' its header (the disc ROM's copy): a real one first
      If Bdos(30, VarPtr(b)) = 0 And (b(68) And 128) = 0 Then
        For c = 0 To 127
          tb(c) = 0
        Next
        For c = 0 To 66
          tb(c) = b(2 + c)
        Next
        tb(19) = 0 : tb(20) = 0
        y = 0
        For c = 0 To 66
          y = y + tb(c)
        Next
        tb(67) = y And 255 : tb(68) = y \ 256
        ps = 128
      End If
      rec = 0 : m = 0 : got = 1
      Do
        Do While ps < 1024 And got > 0           ' a block (1K) of it
          got = FileSystem.Read(hi, VarPtr(tb) + ps, 1024 - ps)
          If got > 0 Then ps = ps + got
        Loop
        If ps = 0 Then Exit Do
        Do While (ps And 127) <> 0               ' (the last record: ^Z after it)
          tb(ps) = 26 : ps = ps + 1
        Loop
        c = 2
        Do While c <= dsm
          If ub(c) = 0 Then Exit Do
          c = c + 1
        Loop
        If c > dsm Then Print nm; ": no room left on the disc" : Exit Do
        ub(c) = 1 : bl(m) = c : m = m + 1
        rec = rec + ps \ 128
        WSector c * 2, VarPtr(tb)
        If ps > 512 Then WSector c * 2 + 1, VarPtr(tb) + 512
        If ps < 1024 Then Exit Do
        ps = 0
      Loop
      r = FileSystem.Close(hi)
      x = 0                                      ' its entries: an extent (16K) each
      Do
        e = 0
        Do While e < 64
          If dr(e * 32) > 15 Then Exit Do
          e = e + 1
        Loop
        If e > 63 Then Exit Do
        o = e * 32
        dr(o) = 0
        For j = 1 To 11
          dr(o + j) = 32
        Next
        j = InStr(nm, ".")
        If j = 0 Then j = Len(nm) + 1
        For c = 1 To j - 1
          dr(o + c) = Asc(Mid$(nm, c, 1))
        Next
        For c = j + 1 To Len(nm)
          dr(o + 8 + c - j) = Asc(Mid$(nm, c, 1))
        Next
        dr(o + 12) = x And 31 : dr(o + 13) = 0 : dr(o + 14) = x \ 32
        If rec - x * 128 > 128 Then dr(o + 15) = 128 Else dr(o + 15) = CInt(rec - x * 128)
        For j = 0 To 15
          If x * 16 + j < m Then dr(o + 16 + j) = bl(x * 16 + j) Else dr(o + 16 + j) = 0
        Next
        x = x + 1
      Loop While x * 128 < rec
      For c = 0 To 3                             ' the directory back
        WSector c, VarPtr(dr) + c * 512
      Next
      Print tn; nm; " to "; dv; ": "; rec * 128; " bytes"
      nd = nd + 1
    End If
  Next
  Print nd; " of "; CybDir.Count(); " files copied"
  Done
End Sub

' logical sector ls (512 bytes) of the disc written from ad (each tried 3 times, the head back to
' track 0 between); a read track there forgotten
Sub WSector(ByVal ls As Integer, ByVal ad As Integer)
  Dim c As Integer, q1 As Integer
  ct = -1
  q1 = 1
  For c = 1 To 3
    If q1 <> 0 Then
      q1 = Fdc(3, drv, off + ls \ spt, 0, 0)
      If q1 = 0 Then q1 = Fdc(6, drv, off + ls \ spt, base + (ls Mod spt) + 512, ad)
      If q1 <> 0 And c < 3 Then r = Fdc(2, drv, 0, 0, 0)
    End If
  Next
  If q1 <> 0 Then
    If rs(1) And 2 Then Bad dv + ": the disc is write protected"
    Bad "track " + Trim$(Str$(off + ls \ spt)) + ": can't be written (ST0-2 &" + Hex$(rs(0)) + " &" + Hex$(rs(1)) + " &" + Hex$(rs(2)) + ")"
  End If
End Sub

' the whole disc to dk as an extended .DSK: first each track's sector IDs (read ID round the
' track, in the order they pass), so the header can have the tracks' sizes; then each track read
' sector by sector (each tried 3 times; one that can't be read is kept as it came, with its ST1
' and ST2) and written - its Track-Info, then its sectors. Tracks 0-39, 40 and 41 when formatted
Sub DskImage()
  Dim c As Integer, m As Integer, o As Integer, z As Integer, nbad As Integer, tr As Integer
  nt = 0
  For t = 0 To 41
    ns(t) = 0
    r = Fdc(3, drv, t, 0, 0)
    If r = 0 Then r = Fdc(4, drv, 0, 0, 0)
    If r <> 0 Then r = Fdc(4, drv, 0, 0, 0)
    If r <> 0 And t >= 40 Then Exit For
    If r = 0 Then
      For c = 0 To 3
        id(t * 80 + c) = rs(3 + c)
      Next
      k = 1
      Do While k < 20
        If Fdc(4, drv, 0, 0, 0) <> 0 Then Exit Do
        If rs(3) = id(t * 80) And rs(4) = id(t * 80 + 1) And rs(5) = id(t * 80 + 2) And rs(6) = id(t * 80 + 3) Then Exit Do
        For c = 0 To 3
          id(t * 80 + k * 4 + c) = rs(3 + c)
        Next
        k = k + 1
      Loop
      ns(t) = k
      If TrackLen(t) > 4608 Then Bad "track " + Trim$(Str$(t)) + ": more than 4608 bytes of sectors (FLOPPY's most)"
    End If
    nt = t + 1
  Next
  ho = FileSystem.Open(v + dk, FileSystem.ForWrite)
  If ho < 0 Then Print tn; dk; ": can't be made ("; ho; ")" : Done
  For c = 0 To 255
    hb(c) = 0
  Next
  PutStr 0, "EXTENDED CPC DSK File"
  hb(21) = 13 : hb(22) = 10
  PutStr 23, "Disk-Info"
  hb(32) = 13 : hb(33) = 10
  PutStr 34, "CyborgOS"
  hb(48) = nt : hb(49) = 1
  For t = 0 To nt - 1
    If ns(t) > 0 Then hb(52 + t) = (256 + TrackLen(t) + 255) \ 256
  Next
  If FileSystem.Write(ho, VarPtr(hb), 256) <> 256 Then Bad tn + dk + ": the disc is full, or a write failed"
  tot = 256 : nbad = 0
  For t = 0 To nt - 1
    If ns(t) > 0 Then
      For c = 0 To 4607
        tb(c) = 0
      Next
      For c = 0 To 255
        hb(c) = 0
      Next
      PutStr 0, "Track-Info"
      hb(10) = 13 : hb(11) = 10
      hb(16) = t : hb(20) = id(t * 80 + 3) : hb(21) = ns(t) : hb(22) = &H4E : hb(23) = &HE5
      o = 0
      For c = 0 To ns(t) - 1
        m = t * 80 + c * 4
        z = SecLen(id(m + 3))
        w = 1
        For tr = 1 To 3
          If w <> 0 Then
            w = Fdc(3, drv, t, 0, 0)
            fh = id(m + 1)
            If w = 0 Then w = Fdc(5, drv, id(m), id(m + 2) + 256 * id(m + 3), VarPtr(tb) + o)
            If w <> 0 And tr < 3 Then r = Fdc(2, drv, 0, 0, 0) : r = Fdc(0, drv, 0, 1, 0)
          End If
        Next
        x = 24 + c * 8
        hb(x) = id(m) : hb(x + 1) = id(m + 1) : hb(x + 2) = id(m + 2) : hb(x + 3) = id(m + 3)
        If w <> 0 Then hb(x + 4) = rs(1) : hb(x + 5) = rs(2) : nbad = nbad + 1
        hb(x + 6) = z And 255 : hb(x + 7) = z \ 256
        o = o + z
      Next
      z = ((256 + o + 255) \ 256) * 256 - 256
      If FileSystem.Write(ho, VarPtr(hb), 256) <> 256 Then Bad tn + dk + ": the disc is full, or a write failed"
      If FileSystem.Write(ho, VarPtr(tb), z) <> z Then Bad tn + dk + ": the disc is full, or a write failed"
      tot = tot + 256 + z
    End If
  Next
  r = FileSystem.Close(ho)
  Print dv; " to "; tn; dk; ": "; nt; " tracks, "; tot; " bytes";
  If nbad > 0 Then Print ", "; nbad; " sectors not read cleanly" Else Print
  Done
End Sub

' a sector's bytes from its N (128 << N; 6 and more: 8K, more than a track here can hold)
Function SecLen(ByVal sn As Integer) As Integer
  Dim c As Integer
  SecLen = 8192
  If sn > 5 Then Exit Function
  SecLen = 128
  For c = 1 To sn
    SecLen = SecLen * 2
  Next
End Function

' track t's sectors' bytes
Function TrackLen(ByVal tt As Integer) As Integer
  Dim c As Integer, l As Integer
  l = 0
  For c = 0 To ns(tt) - 1
    l = l + SecLen(id(tt * 80 + c * 4 + 3))
    If l > 4608 Then TrackLen = 9999 : Exit Function
  Next
  TrackLen = l
End Function

' s's characters into hb from o
Sub PutStr(ByVal o As Integer, ByVal st As String)
  Dim c As Integer
  For c = 1 To Len(st)
    hb(o + c - 1) = Asc(Mid$(st, c, 1))
  Next
End Sub

' entry e's name, as the list has it
Function Named(ByVal e As Integer) As String
  Dim t As String Max 12, c As Integer
  t = ""
  For c = 1 To 11
    If c = 9 And (dr(e * 32 + 9) And 127) > 32 Then t = t + "."
    If (dr(e * 32 + c) And 127) > 32 Then t = t + Chr$(dr(e * 32 + c) And 127)
  Next
  Named = t
End Function

' logical sector ls (512 bytes) of the disc: where in tb it is (its whole track read if it isn't
' the one there - each sector tried 4 times, the head back to track 0 between)
Function Sector(ByVal ls As Integer) As Integer
  Dim t As Integer, c As Integer, tr As Integer, w As Integer
  t = off + ls \ spt
  If t <> ct Then
    ct = -1
    For c = 0 To spt - 1
      w = 1
      For tr = 1 To 4
        If w <> 0 Then
          w = Fdc(3, drv, t, 0, 0)
          If w = 0 Then w = Fdc(5, drv, t, base + c + 512, VarPtr(tb) + c * 512)
          If w <> 0 And tr < 4 Then r = Fdc(2, drv, 0, 0, 0) : r = Fdc(0, drv, 0, 1, 0)
        End If
      Next
      If w <> 0 Then Bad "track " + Trim$(Str$(t)) + " sector &" + Hex$(base + c) + ": can't be read (ST0-2 &" + Hex$(rs(0)) + " &" + Hex$(rs(1)) + " &" + Hex$(rs(2)) + ")"
    Next
    ct = t
  End If
  Sector = (ls Mod spt) * 512
End Function

' s into b at i: its length, then its characters
Sub SetStr(ByVal i As Integer, ByVal s As String)
  Dim c As Integer
  b(i) = Len(s)
  For c = 1 To Len(s)
    b(i + c) = Asc(Mid$(s, c, 1))
  Next
End Sub

' the drive letter's path ("" none)
Function PathOf(ByVal d As String) As String
  Dim c As Integer, t As String Max 32
  PathOf = ""
  b(0) = &HC1 : b(1) = Asc(d)
  If Bdos(30, VarPtr(b)) <> 0 Then Exit Function
  t = ""
  For c = 1 To b(2)
    t = t + Chr$(b(c + 2))
  Next
  PathOf = t
End Function

' the first drive letter from C with no path that isn't a RAM disc ("" none)
Function FreeLetter() As String
  Dim c As Integer, m As Integer, rd As String Max 16
  rd = ""
  For m = 0 To 7                                   ' the RAM discs (RAMDISC's list: "F: ...")
    q(0) = 3 : q(1) = m
    If Bdos(130, VarPtr(q)) <> 0 Then Exit For
    rd = rd + Chr$(q(3))
  Next
  FreeLetter = ""
  For c = 67 To 80
    If PathOf(Chr$(c)) = "" And InStr(rd, Chr$(c)) = 0 Then FreeLetter = Chr$(c) : Exit Function
  Next
End Function

' BDOS function fn, DE = dd: A
Function Bdos(ByVal fn As Integer, ByVal dd As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({fn})
            ld c, a
            ld de, ({dd})
            ei                      ; (CP/M's BDOS: interrupts on)
            call 5
            di                      ; (off before SP is the threaded code again: it comes back with them on)
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function

' the disc controller (uPD765: #FB7E its status, #FB7F its data; #FA7E the motor), interrupts off:
' op 0 the motor on (sc 1: then a second's wait for it to spin up), 1 off, 2 the head to track 0,
' 3 to track tk, 4 a sector's ID read (rs: ST0 ST1 ST2 C H R N), 5 sector sc of track tk read
' (512 bytes) to dst. 0 done, 1 the controller didn't answer (none, or no disc turning), 2 an error
' (rs: its result)
Function Fdc(ByVal op As Integer, ByVal dn As Integer, ByVal tk As Integer, ByVal sc As Integer, ByVal dst As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, i                 ; (interrupts as they were kept: off while here - a byte
            ld a, 0                 ; missed in a sector's 32 us is an overrun)
            jp po, fd_di
            inc a
fd_di:
            di
            ld (fd_ie), a
            ld hl, 0
            ld ({result}), hl
            ld a, ({op})
            or a
            jr z, fd_mon
            dec a
            jr z, fd_moff
            dec a
            jr z, fd_cal
            dec a
            jr z, fd_seek
            dec a
            jp z, fd_rid
            dec a
            jp z, fd_read
            dec a
            jp z, fd_write
            jp fd_fmt
fd_mon:
            ld bc, #FA7E
            ld a, 1
            out (c), a
            ld a, ({sc})
            or a
            jp z, fd_end
            ld de, 1200             ; (about a second: 1200 x 3.3K T)
fd_dly:
            ld b, 0
fd_dl1:
            djnz fd_dl1
            dec de
            ld a, d
            or e
            jr nz, fd_dly
            jp fd_end
fd_moff:
            ld bc, #FA7E
            xor a
            out (c), a
            jp fd_end
fd_cal:
            ld a, 7                 ; recalibrate
            call fd_out
            jp c, fd_to
            ld a, ({dn})
            and 3
            call fd_out
            jp c, fd_to
            jr fd_sk
fd_seek:
            ld a, 15                ; seek
            call fd_out
            jp c, fd_to
            ld a, ({dn})
            and 3
            call fd_out
            jp c, fd_to
            ld a, ({tk})
            call fd_out
            jp c, fd_to
fd_sk:                              ; sense interrupt status until the seek's end
            ld hl, 0
fd_sk1:
            push hl
            ld a, 8
            call fd_out
            call nc, fd_res
            pop hl
            jp c, fd_to
            ld de, ({rp})
            ld a, (de)
            cp #80                  ; (nothing yet)
            jr z, fd_sk2
            bit 5, a
            jr nz, fd_sk3
fd_sk2:
            dec hl
            ld a, h
            or l
            jr nz, fd_sk1
            jp fd_to
fd_sk3:
            and #D0                 ; abnormal, or the head never got there: an error
            jp nz, fd_err
            ld a, ({op})
            cp 2
            jp z, fd_end
            inc de
            ld a, ({tk})
            ex de, hl
            cp (hl)
            jp nz, fd_err
            jp fd_end
fd_rid:
            ld a, #4A               ; read ID (MFM)
            call fd_out
            jp c, fd_to
            ld a, ({dn})
            and 3
            call fd_out
            jp c, fd_to
            call fd_res
            jp c, fd_to
            ld hl, ({rp})
            ld a, (hl)
            and #C0
            jp nz, fd_err
            jp fd_end
fd_write:
            ld a, #45               ; write data (MFM)
            jr fd_rw
fd_read:
            ld a, #46               ; read data (MFM)
fd_rw:
            ld (fd_cmd), a
            ld hl, fd_cmd
            ld a, ({dn})
            and 3
            ld (fd_cmd + 1), a
            ld a, ({tk})
            ld (fd_cmd + 2), a
            ld a, ({fh})
            ld (fd_cmd + 3), a
            ld a, ({sc})
            ld (fd_cmd + 4), a
            ld (fd_cmd + 6), a      ; (the last sector: this one)
            ld a, ({sc} + 1)
            ld (fd_cmd + 5), a      ; (its size: N)
            ld b, 9
fd_rd0:
            ld a, (hl)
            inc hl
            push bc
            push hl
            call fd_out
            pop hl
            pop bc
            jp c, fd_to
            djnz fd_rd0
            ld hl, ({dst})
            ld bc, #FB7E
            ld de, 0
            ld a, (fd_cmd)
            cp #45
            jr z, fd_wr1
fd_rd1:                             ; the first byte (the sector found): waited for, not forever -
            in a, (c)               ; a tight loop too (11 us: a byte seen late overruns the next;
            jp m, fd_rd2            ; 65536 times, about 0.7 s)
            dec e
            jp nz, fd_rd1
            dec d
            jp nz, fd_rd1
            jp fd_to
fd_rd2:
            and #20                 ; the execution phase over: the result
            jr z, fd_rd3
fd_rd4:                             ; then each byte as it comes: a tight loop (a byte every 32 us,
            inc c                   ; 128 T - this is about 76)
            in a, (c)
            ld (hl), a
            inc hl
            dec c
fd_rd5:
            in a, (c)
            jp p, fd_rd5
            and #20
            jp nz, fd_rd4
            jr fd_rd3
fd_wr1:                             ; writing (or formatting): the first byte asked for, waited
            in a, (c)               ; for, not forever (a tight loop, as reading's)
            jp m, fd_wr2
            dec e
            jp nz, fd_wr1
            dec d
            jp nz, fd_wr1
            jp fd_to
fd_wr2:
            and #20
            jr z, fd_rd3
fd_wr4:                             ; then each byte as asked for: a tight loop (about 76 T)
            inc c
            ld a, (hl)
            out (c), a
            inc hl
            dec c
fd_wr5:
            in a, (c)
            jp p, fd_wr5
            and #20
            jp nz, fd_wr4
fd_rd3:
            call fd_res
            jp c, fd_to
            ld hl, ({rp})
            ld a, (hl)
            and #C0
            jp z, fd_end
            cp #40                  ; (ended at the last sector: the CPC's usual end, no error)
            jp nz, fd_err
            inc hl
            ld a, (hl)
            cp #80
            jp nz, fd_err
            inc hl
            ld a, (hl)
            or a
            jp nz, fd_err
            jp fd_end
fd_fmt:
            ld a, #4D               ; format a track (MFM): drive, N, sectors, gap, filler, then
            call fd_out             ; C H R N for each sector from dst
            jp c, fd_to
            ld a, ({dn})
            and 3
            call fd_out
            jp c, fd_to
            ld a, ({sc} + 1)
            call fd_out
            jp c, fd_to
            ld a, ({sc})
            call fd_out
            jp c, fd_to
            ld a, ({fgap})
            call fd_out
            jp c, fd_to
            ld a, ({ffill})
            call fd_out
            jp c, fd_to
            ld hl, ({dst})
            ld bc, #FB7E
            ld de, 0
            jp fd_wr1
; A to the controller: carry set if it never asked for it
fd_out:
            push af
            ld bc, #FB7E
            ld de, 0
fd_o1:
            in a, (c)
            and #C0
            cp #80
            jr z, fd_o2
            dec de
            ld a, d
            or e
            jr nz, fd_o1
            pop af
            scf
            ret
fd_o2:
            pop af
            inc c
            out (c), a
            ex (sp), hl
            ex (sp), hl
            or a
            ret
; the result's bytes to rs: carry set if it never finished
fd_res:
            ld hl, ({rp})
            xor a
            ld (fd_n), a
            ld bc, #FB7E
            ld de, 0
fd_r1:
            in a, (c)
            and #C0
            cp #C0
            jr z, fd_r2
            cp #80
            ret z                   ; (no carry)
            dec de
            ld a, d
            or e
            jr nz, fd_r1
            scf
            ret
fd_r2:
            ld a, (fd_n)            ; (16 at most: more, and it isn't a controller)
            inc a
            cp 17
            ccf
            ret c
            ld (fd_n), a
            inc c
            in a, (c)
            dec c
            ld (hl), a
            inc hl
            ex (sp), hl
            ex (sp), hl
            ld de, 0
            jr fd_r1
fd_cmd:
            db #46, 0, 0, 0, 0, 2, 0, #2A, #FF
fd_n:       db 0
fd_ie:      db 0
fd_to:
            ld hl, 1
            ld ({result}), hl
            jr fd_end
fd_err:
            ld hl, 2
            ld ({result}), hl
fd_end:
            ld a, (fd_ie)
            ld sp, ({hsp})
            or a
            jr z, fd_ei
            ei
fd_ei:
#endasm
End Function
