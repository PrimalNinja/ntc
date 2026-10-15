' CybDir - a volume's FILES.DIR for CyborgOS's commands (COPY, ERA, TYPE, PREP, RENAME): build them for
' cpm, with this class. The entries (64 bytes, see Ent.cls) are read into memory, changed there
' and written back whole. Names: "NAME.EXT"; a name with no "." is also looked for as NAME.COM.
' A volume is "" (the slot's drive) or "B:".
Option Explicit
Public Const MAXBYTES = 4096            ' 64 entries
Private d(4095) As Byte                 ' the entries
Private e(63) As Byte                   ' one entry (Take, PutAs)
Private m As Integer                    ' bytes of entries in d()

' Load(vol): vol's FILES.DIR read in - True when it is there (it may have no entries)
Public Function Load(ByVal vol As String) As Integer
  Dim h As Integer, r As Integer
  m = 0
  Load = False
  h = FileSystem.Open(vol + "FILES.DIR", FileSystem.ForReadRaw)
  If h < 0 Then Exit Function
  m = FileSystem.Read(h, VarPtr(d), MAXBYTES)
  r = FileSystem.Close(h)
  If m < 0 Then m = 0
  m = m And &HFFC0
  Do While m > 0                        ' the last record's padding (#1A, or an unused entry) dropped
    If d(m - 64) = 1 Or d(m - 64) = 2 Then Exit Do
    m = m - 64
  Loop
  Load = True
End Function

' Save(vol): the entries written back as vol's FILES.DIR (to a whole 128 byte record: an unused
' entry after an odd one). OK (0) or a FileSystem status
Public Function Save(ByVal vol As String) As Integer
  Dim i As Integer, n As Integer
  n = m
  If (n And 127) <> 0 Then
    For i = n To n + 63
      d(i) = 0
    Next
    n = n + 64
  End If
  If n = 0 Then                      ' no entries left: one empty 128 byte record, never a 0 byte
    For i = 0 To 127                  ' file (a disc ROM can't store that, so FILES.DIR would vanish)
      d(i) = 0
    Next
    n = 128
  End If
  Save = FileSystem.Save(vol + "FILES.DIR", VarPtr(d), n)
End Function

' Count(): how many entries
Public Function Count() As Integer
  Count = m \ 64
End Function

' Find(name): the offset of name's entry (its disc name, else its long name), or -1
Public Function Find(ByVal name As String) As Integer
  Dim o As Integer
  Find = -1
  For o = 0 To m - 64 Step 64
    If d(o) = 1 And Sum(o) Then
      If DiscName(o) = name Or (InStr(name, ".") = 0 And DiscName(o) = name + ".COM") Or LongName(o) = name Then
        Find = o
        Exit Function
      End If
    End If
  Next
End Function

' Has(a): the entry (in use) whose disc name is the 11 bytes at a (8 + 3, spaces after: a CP/M
' directory entry's from its byte 1), or -1 - bytes compared, no strings (DIR: each file the
' directory search gives)
Public Function Has(ByVal a As Integer) As Integer
  Dim o As Integer, i As Integer
  Has = -1
  For o = 0 To m - 64 Step 64
    If d(o) = 1 Then
      For i = 1 To 11
        If (d(o + i) And 127) <> (Peek(a + i - 1) And 127) Then Exit For
      Next
      If i > 11 Then Has = o : Exit Function
    End If
  Next
End Function

' DiscName(o): the entry at o's name on the disc, "NAME.EXT"
Public Function DiscName(ByVal o As Integer) As String
  Dim i As Integer, s As String Max 12
  s = ""
  For i = 1 To 8
    If d(o + i) > 32 Then s = s + Chr$(d(o + i))
  Next
  If d(o + 9) > 32 Then
    s = s + "."
    For i = 9 To 11
      If d(o + i) > 32 Then s = s + Chr$(d(o + i))
    Next
  End If
  DiscName = s
End Function

' LongName(o): the entry at o's long name ("" none)
Public Function LongName(ByVal o As Integer) As String
  Dim i As Integer, s As String Max 38
  s = ""
  For i = 24 To 61
    If d(o + i) = 0 Then Exit For
    s = s + Chr$(d(o + i))
  Next
  LongName = s
End Function

' Length(o): the entry at o's length in bytes
Public Function Length(ByVal o As Integer) As Long
  Length = CLng(d(o + 14)) + CLng(d(o + 15)) * 256
End Function

' Remove(o): the entry at o taken out (the ones after it move down)
Public Sub Remove(ByVal o As Integer)
  Dim i As Integer
  For i = o To m - 65
    d(i) = d(i + 64)
  Next
  m = m - 64
End Sub

' Take(o): the entry at o kept aside (for PutAs - after loading another FILES.DIR)
Public Sub Take(ByVal o As Integer)
  Dim i As Integer
  For i = 0 To 63
    e(i) = d(o + i)
  Next
End Sub

' Keep(o, a): the entry at o copied to a (64 bytes: a program's own list of entries); Back(a): the
' entry at a kept, as Take does (for PutAs)
Public Sub Keep(ByVal o As Integer, ByVal a As Integer)
  Dim i As Integer
  For i = 0 To 63
    Poke a + i, d(o + i)
  Next
End Sub
Public Sub Back(ByVal a As Integer)
  Dim i As Integer
  For i = 0 To 63
    e(i) = Peek(a + i)
  Next
End Sub

' Match(o, pattern): True when the entry at o (in use, its sum right) has a disc name or long name
' that fits pattern: * any characters, ? any one ("*.*" is "*": a name with no extension too)
Public Function Match(ByVal o As Integer, ByVal pat As String) As Integer
  Match = False
  If d(o) <> 1 Then Exit Function
  If Sum(o) = 0 Then Exit Function
  If pat = "*.*" Then pat = "*"
  If Fits(DiscName(o), pat) Then Match = True : Exit Function
  If Fits(LongName(o), pat) Then Match = True
End Function

' Fits(t, p): t fits p (* any characters, ? any one; "" never fits) - the usual walk, the last *
' tried again a character on
Public Function Fits(ByVal t As String, ByVal p As String) As Integer
  Dim i As Integer, j As Integer, si As Integer, sj As Integer, c As String Max 1
  i = 1 : j = 1 : si = 0 : sj = 0
  Fits = False
  If t = "" Then Exit Function
  Do While i <= Len(t)
    c = Mid$(p, j, 1)
    If c = "*" Then
      si = i : sj = j : j = j + 1
    ElseIf j <= Len(p) And (c = "?" Or c = Mid$(t, i, 1)) Then
      i = i + 1 : j = j + 1
    ElseIf sj > 0 Then
      si = si + 1 : i = si : j = sj + 1
    Else
      Exit Function
    End If
  Loop
  Do While Mid$(p, j, 1) = "*"
    j = j + 1
  Loop
  Fits = (j > Len(p))
End Function

' PutAs(name): the kept entry, renamed name on the disc, in place of an entry with that name or
' added at the end. False when FILES.DIR is full
Public Function PutAs(ByVal name As String) As Integer
  Dim i As Integer, o As Integer
  Named name
  o = Find(name)
  If o < 0 Then
    If m >= MAXBYTES Then PutAs = False : Exit Function
    o = m
    m = m + 64
  End If
  For i = 0 To 63
    d(o + i) = e(i)
  Next
  PutAs = True
End Function

' AddFile(name, length, longname, what): a fresh entry (kind 1, load / exec #0100, flags 0) for
' name, in place of one with that disc name or added at the end. False when FILES.DIR is full
Public Function AddFile(ByVal name As String, ByVal length As Long, ByVal longname As String, ByVal what As Integer) As Integer
  Dim i As Integer
  For i = 0 To 63
    e(i) = 0
  Next
  e(0) = 1
  e(12) = what
  e(14) = CInt(length And 255) : e(15) = CInt((length \ 256) And 255)
  e(16) = 0 : e(17) = 1 : e(18) = 0 : e(19) = 1      ' load / exec #0100
  For i = 1 To Len(longname)
    If i <= 38 Then e(23 + i) = Asc(Mid$(longname, i, 1))
  Next
  AddFile = PutAs(name)              ' (Named sets the disc name and the checksum, then inserts)
End Function

' RenameAt(o, name): the entry at o's disc name made name (its place and the rest kept)
Public Sub RenameAt(ByVal o As Integer, ByVal name As String)
  Dim i As Integer
  Take o
  Named name
  For i = 0 To 63
    d(o + i) = e(i)
  Next
End Sub

' the kept entry's disc name made name ("NAME.EXT"), its sum again
Private Sub Named(ByVal name As String)
  Dim i As Integer, p As Integer, b As String Max 8, x As String Max 3, s As Long
  p = InStr(name, ".")
  If p = 0 Then
    b = Left$(name, 8) : x = ""
  Else
    b = Left$(name, p - 1) : x = Mid$(name, p + 1, 3)
  End If
  b = Left$(b + Space$(8), 8)
  x = Left$(x + Space$(3), 3)
  For i = 1 To 8
    e(i) = Asc(Mid$(b, i, 1))
  Next
  For i = 1 To 3
    e(8 + i) = Asc(Mid$(x, i, 1))
  Next
  s = 0
  For i = 0 To 61
    s = s + e(i)
  Next
  e(62) = CInt(s And 255)
  e(63) = CInt((s \ 256) And 255)
End Sub

' the entry at o's sum right (a damaged one is left alone)
Private Function Sum(ByVal o As Integer) As Integer
  Dim i As Integer, s As Long
  s = 0
  For i = 0 To 61
    s = s + d(o + i)
  Next
  Sum = (CInt(s And 255) = d(o + 62)) And (CInt((s \ 256) And 255) = d(o + 63))
End Function
