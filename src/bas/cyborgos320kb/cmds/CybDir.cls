' CybDir - a drive's own directory, read, for CyborgOS's commands (COPY, ERA, DIR): build them for
' cpm, with this class. No list of CyborgOS's own (FILES.DIR is gone): the files are the ones
' that are there -
'   with UniDOS (a drive letter with a path, A, B): the folder as UniDOS lists it (BDOS 30, #C5 -
'   CyborgOS's UniDOS call), each file's exact length
'   a RAM disc (Z, RAMDISC's): its own directory (BDOS 17, 18), each file's length from its
'   records (BDOS 35)
' A floppy AMSDOS runs (not UniDOS's) has none to read here: FLOPPY reads one.
' An entry: 16 bytes - the name (8 + 3, CP/M style), then its length (4 bytes, at 12). Names:
' "NAME.EXT"; a volume is "" (the slot's drive) or "B:"
Option Explicit
Public Const MAXN = 256                 ' entries at most
Private d(4095) As Byte                 ' the entries
Private m As Integer                    ' how many
Private ub(71) As Byte                  ' BDOS 30's block: CyborgOS's UniDOS call
Private f(35) As Byte, dm(127) As Byte  ' (a RAM disc) the search's FCB, its DMA
Private hsp As Integer
Private flt As Integer                  ' Into's drive letter (its path the folder), 0 none

' LoadAll(vol): vol's files read in (folders left out) - True when its directory could be read
' (UniDOS's listing, or a RAM disc's), False when there is none to read (AMSDOS's drives)
Public Function LoadAll(ByVal vol As String) As Integer
  Dim i As Integer, j As Integer, r As Integer, lt As Integer
  m = 0
  If vol = "" Then lt = Asc(FileSystem.CurrentVolume()) Else lt = Asc(vol)
  r = 255
  If IsRam(lt) = 0 Then                  ' (a RAM disc: its own directory, below)
    ub(0) = &HC5 : ub(1) = lt : ub(2) = 0 : ub(3) = 0
    r = Call30(VarPtr(ub))
  End If
  If r = 0 Or r = 1 Then                 ' UniDOS's listing
    i = 0
    Do While r = 0 And m < MAXN
      If (ub(4) And 16) = 0 Then         ' (a file, not a folder)
        For j = 0 To 10
          d(m * 16 + j) = ub(16 + j) And 127
        Next
        For j = 0 To 3
          d(m * 16 + 12 + j) = ub(5 + j)
        Next
        m = m + 1
      End If
      i = i + 1
      ub(0) = &HC5 : ub(1) = lt : ub(2) = i And 255 : ub(3) = i \ 256
      r = Call30(VarPtr(ub))
    Loop
    LoadAll = True
    Exit Function
  End If
  f(0) = lt - 64                         ' its own directory: ????????.??? (BDOS 17, 18), then
  For j = 1 To 11                        ' each file's records (BDOS 35)
    f(j) = 63
  Next
  For j = 12 To 35
    f(j) = 0
  Next
  r = Bdos(26, VarPtr(dm))
  r = Bdos(17, VarPtr(f))
  Do While r <> 255 And m < MAXN
    For j = 0 To 10
      d(m * 16 + j) = dm((r And 3) * 32 + 1 + j) And 127
    Next
    m = m + 1
    r = Bdos(18, VarPtr(f))
  Loop
  For i = 0 To m - 1
    f(0) = lt - 64
    For j = 0 To 10
      f(1 + j) = d(i * 16 + j)
    Next
    For j = 12 To 35
      f(j) = 0
    Next
    r = Bdos(35, VarPtr(f))
    d(i * 16 + 12) = (f(33) And 1) * 128 ' (records x 128)
    d(i * 16 + 13) = (f(33) \ 2) + (f(34) And 1) * 128
    d(i * 16 + 14) = (f(34) \ 2) + (f(35) And 1) * 128
    d(i * 16 + 15) = f(35) \ 2
  Next
  LoadAll = (m > 0)
  If m = 0 Then LoadAll = IsRam(lt)
End Function

' Count(): how many files
Public Function Count() As Integer
  Count = m
End Function

' Find(name): the number of name's entry (a name with no "." finds NAME.COM too), or -1
Public Function Find(ByVal name As String) As Integer
  Dim i As Integer
  Find = -1
  For i = 0 To m - 1
    If DiscName(i) = name Or (InStr(name, ".") = 0 And DiscName(i) = name + ".COM") Then Find = i : Exit Function
  Next
End Function

' DiscName(i): entry i's name, "NAME.EXT"
Public Function DiscName(ByVal i As Integer) As String
  Dim j As Integer, s As String Max 12
  s = ""
  For j = 0 To 7
    If d(i * 16 + j) > 32 Then s = s + Chr$(d(i * 16 + j))
  Next
  If d(i * 16 + 8) > 32 Then
    s = s + "."
    For j = 8 To 10
      If d(i * 16 + j) > 32 Then s = s + Chr$(d(i * 16 + j))
    Next
  End If
  DiscName = s
End Function

' Length(i): entry i's length in bytes
Public Function Length(ByVal i As Integer) As Long
  Dim o As Integer
  o = i * 16 + 12
  Length = CLng(d(o)) + CLng(d(o + 1)) * 256 + CLng(d(o + 2)) * 65536 + CLng(d(o + 3)) * 16777216
End Function

' Match(i, pattern): entry i's name fits pattern (* any characters, ? any one; "*.*" is "*")
Public Function Match(ByVal i As Integer, ByVal pat As String) As Integer
  If pat = "*.*" Then pat = "*"
  Match = Fits(DiscName(i), pat)
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

' Into(v, name): when name (or name/) is a folder in drive v's folder (UniDOS), a free drive
' letter (C-P, no path, not a RAM disc) given its path, for a copy into it: "L:" - "" when it
' isn't a folder, "!" a folder but no letter free. Release gives the letter its own place back
Public Function Into(ByVal v As String, ByVal nm As String) As String
  Dim p As String Max 40, c As Integer
  Into = ""
  If Right$(nm, 1) = "/" Then nm = Left$(nm, Len(nm) - 1)
  If nm = "" Or InStr(nm, "*") > 0 Or InStr(nm, "?") > 0 Or InStr(nm, "/") > 0 Then Exit Function
  p = PathOf(Asc(v))
  If p = "" Then p = Left$(v, 1) + ":"
  p = p + nm + "/"
  If Len(p) > 31 Then Exit Function
  ub(0) = &HC5 : ub(1) = 0 : ub(2) = 0 : ub(3) = 0     ' a folder: its listing (0 an entry, 1 empty)
  SetS 28, p
  c = Call30(VarPtr(ub))
  If c <> 0 And c <> 1 Then Exit Function
  For c = 67 To 80
    If PathOf(c) = "" And IsRam(c) = 0 Then
      ub(0) = &HC2 : ub(1) = c
      SetS 2, p
      If Call30(VarPtr(ub)) = 0 Then Into = Chr$(c) + ":" : flt = c
      Exit Function
    End If
  Next
  Into = "!"                                     ' a folder, but no letter free
End Function

Public Sub Release()
  Dim r As Integer
  If flt = 0 Then Exit Sub
  ub(0) = &HC2 : ub(1) = flt : ub(2) = 0
  r = Call30(VarPtr(ub))
  flt = 0
End Sub

' drive letter lt's path (UniDOS: CD's), "" none
Private Function PathOf(ByVal lt As Integer) As String
  Dim c As Integer, t As String Max 40
  PathOf = ""
  ub(0) = &HC1 : ub(1) = lt
  If Call30(VarPtr(ub)) <> 0 Then Exit Function
  t = ""
  For c = 1 To ub(2)
    t = t + Chr$(ub(c + 2))
  Next
  PathOf = t
End Function

' s into the block from byte i: its length, then its characters
Private Sub SetS(ByVal i As Integer, ByVal s As String)
  Dim c As Integer
  ub(i) = Len(s)
  For c = 1 To Len(s)
    ub(i + c) = Asc(Mid$(s, c, 1))
  Next
End Sub

' True when the drive letter lt is a RAM disc (RAMDISC's list: "F: ...")
Private Function IsRam(ByVal lt As Integer) As Integer
  Dim i As Integer
  IsRam = False
  For i = 0 To 7
    ub(0) = 3 : ub(1) = i
    If Bdos(130, VarPtr(ub)) <> 0 Then Exit Function
    If ub(3) = lt Then IsRam = True : Exit Function
  Next
End Function

Private Function Call30(ByVal a As Integer) As Integer
  Call30 = Bdos(30, a)
End Function

' BDOS function fn, DE = dd: A
Private Function Bdos(ByVal fn As Integer, ByVal dd As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({fn})
            ld c, a
            ld de, ({dd})
            ei                      ; (CP/M's BDOS: interrupts on)
            call 5
            di
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function
