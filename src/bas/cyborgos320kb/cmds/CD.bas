' CD: this slot's drive, in CyborgOS (build for cpm)
'   CD                               this slot's drive (and its path); with UniDOS also the drives
'                                    with paths and the devices there
'   CD B  (or B:)                    drive B. (B: alone on the command line is CD B.) Not Z: the
'                                    system drive is CyborgOS's own
' With UniDOS (a drive letter can be a path - any device's folder):
'   CD IDE:   CD SD:GAMES/ACTION     a device's folder: this drive's path. On A or B (UniDOS's own
'                                    two, the boot drive one of them) or a RAM disc the first drive
'                                    from C with no path (not a RAM disc) gets it instead, and is
'                                    this slot's. A RAM disc's letter never has a path (RAMDISC
'                                    drops one it had)
'   CD IDE                           a device's name alone: as CD IDE: (a folder named as a device: CD SD/)
'   CD GAMES                         a folder in this drive's (A, B: as above)
'   CD ..                            the folder this drive's is in
'   CD C: IDE:WORK                   drive C's path set, C this slot's drive
'   CD C: -                          drive C's path dropped (C on its own again)
' A path is for every slot (a drive letter's); 31 characters at most
Option Explicit
Dim a As String Max 60, w As String Max 40, v As String Max 2, p As String Max 40, s As String Max 40
Dim r As Integer, i As Integer, k As Integer, uni As Integer, hsp As Integer
Dim b(71) As Byte, q(49) As Byte
a = UCase$(Trim$(System.CommandLine()))
b(0) = &HC0 : uni = (Bdos(30, VarPtr(b)) = 0)   ' (BDOS 30, #C0: CyborgOS's UniDOS calls - 0: UniDOS)
v = FileSystem.CurrentVolume()
If a = "" Then Show : End
i = InStr(a + " ", " ")
w = Left$(a, i - 1) : a = Trim$(Mid$(a, i))
If Len(w) = 2 And Right$(w, 1) = ":" Then w = Left$(w, 1)
If Len(w) = 1 Then
  If w < "A" Or w > "P" Then Print w; ": no such drive" : End
  If a <> "" Then
    If uni = 0 Then Print "Paths need UniDOS" : End
    If a = "-" Then
      If SetPath(w, "") Then Print w; ": its path dropped"
      End
    End If
    If SetPath(w, a) Then r = FileSystem.SelectVolume(w) : Print "drive "; w; ": --> "; PathOf(w)
    End
  End If
  r = 254
  If IsRam(w) Then
    r = 0                                          ' (a RAM disc)
  ElseIf uni Then
    If PathOf(w) <> "" Then r = 0 Else r = Usable(w + ":")
  End If
  If r = 254 Then                                  ' (no UniDOS, or a floppy it can't examine:
    If w > "B" Then Print w; ": no such drive" : End   ' A and B are there)
  ElseIf r > 1 Then
    Print w; ": no such drive" : End
  End If
  r = FileSystem.SelectVolume(w)
  Print "drive "; w; ":"; IIf(PathOf(w) <> "", " --> " + PathOf(w), "")
  End
End If
If uni = 0 Then Print w; ": no such drive (paths need UniDOS)" : End
p = PathOf(v)
If p = "" Then p = v + ":"
If InStr(w, ":") > 0 Then
  p = w                                            ' a device's (or A's, B's) folder
ElseIf w = ".." Then
  s = Left$(p, Len(p) - 1)                         ' (its last "/" or ":" off)
  k = 0
  For i = 1 To Len(s)
    If Mid$(s, i, 1) = "/" Or Mid$(s, i, 1) = ":" Then k = i
  Next
  If k = 0 Or Right$(p, 1) = ":" Then Print p; " is the top" : End
  p = Left$(s, k)
ElseIf IsDevice(w) Then
  p = w + ":"                                      ' a device's name with no ":" (CD IDE as CD IDE:)
Else
  p = p + w                                        ' a folder in this one (one named as a device: GAMES/)
End If
If Len(p) > 31 Then Print "A path is 31 characters at most" : End
If v = "A" Or v = "B" Or IsRam(v) Then          ' (UniDOS's own two, a RAM disc: another letter)
  v = FreeLetter()
  If v = "" Then Print "No drive letter free (C-P)" : End
End If
If SetPath(v, p) Then
  r = FileSystem.SelectVolume(v)
  Print "drive "; v; ": --> "; PathOf(v)
End If
End

' this slot's drive; the drives with paths, the devices (UniDOS)
Sub Show()
  Dim n As String Max 12, j As Integer, c As Integer
  Print "drive "; v; ":"; IIf(PathOf(v) <> "", " --> " + PathOf(v), "")
  If uni = 0 Then Exit Sub
  For c = 65 To 80
    s = PathOf(Chr$(c))
    If s <> "" Then Print "  "; Chr$(c); ": --> "; s
  Next
  b(0) = &HC3                                      ' the devices
  If Bdos(30, VarPtr(b)) <> 0 Then Exit Sub
  Print "Devices:";
  j = 2 : n = ""
  Do While j < 66 And b(j) <> 255
    n = n + Chr$(b(j) And 127)
    If b(j) > 127 Then Print " "; n; ":"; : n = ""
    j = j + 1
  Loop
  Print
End Sub

' True when d is one of UniDOS's devices (IDE, SD, DFB, ZERO ...)
Function IsDevice(ByVal d As String) As Integer
  Dim j As Integer, t As String Max 9
  IsDevice = False
  If InStr(d, "/") > 0 Then Exit Function
  b(0) = &HC3
  If Bdos(30, VarPtr(b)) <> 0 Then Exit Function
  t = "" : j = 2
  Do While j < 66 And b(j) <> 255
    t = t + Chr$(b(j) And 127)
    If b(j) > 127 Then
      If t = d Then IsDevice = True : Exit Function
      t = ""
    End If
    j = j + 1
  Loop
End Function

' True when d is a RAM disc's letter (RAMDISC's list: "F: ..."): it has no path - the RAM disc wins
Function IsRam(ByVal d As String) As Integer
  Dim j As Integer
  IsRam = False
  For j = 0 To 7
    q(0) = 3 : q(1) = j
    If Bdos(130, VarPtr(q)) <> 0 Then Exit Function
    If q(3) = Asc(d) Then IsRam = True : Exit Function
  Next
End Function

' the drive letter's path ("" none - a RAM disc's letter none either)
Function PathOf(ByVal d As String) As String
  Dim j As Integer, t As String Max 32
  PathOf = ""
  If uni = 0 Then Exit Function
  If IsRam(d) Then Exit Function
  b(0) = &HC1 : b(1) = Asc(d)
  If Bdos(30, VarPtr(b)) <> 0 Then Exit Function
  t = ""
  For j = 1 To b(2)
    t = t + Chr$(b(j + 2))
  Next
  PathOf = t
End Function

' the drive letter's path set (q: "" dropped): True, else the reason said
Function SetPath(ByVal d As String, ByVal q As String) As Integer
  Dim j As Integer
  SetPath = False
  If d = "Z" Then Print "Z: is CyborgOS's own" : Exit Function
  If IsRam(d) Then Print d; ": is a RAM disc (RAMDISC "; d; " 0 drops it)" : Exit Function
  If Len(q) > 31 Then Print "A path is 31 characters at most" : Exit Function
  b(0) = &HC2 : b(1) = Asc(d) : b(2) = Len(q)
  For j = 1 To Len(q)
    b(j + 2) = Asc(Mid$(q, j, 1))
  Next
  j = Bdos(30, VarPtr(b))
  If j = 0 Then SetPath = True : Exit Function
  If j = 255 Then Print "Paths need UniDOS" Else Print q; ": not a folder (UniDOS: "; Trim$(Str$(j)); ")"
End Function

' a folder UniDOS can list - its first entry asked for: 0 or 1 (none) it can, 254 a drive it
' can't examine (a floppy AMSDOS has), else not
Function Usable(ByVal q As String) As Integer
  Dim j As Integer
  b(0) = &HC5 : b(1) = 0 : b(2) = 0 : b(3) = 0 : b(28) = Len(q)
  For j = 1 To Len(q)
    b(j + 28) = Asc(Mid$(q, j, 1))
  Next
  Usable = Bdos(30, VarPtr(b))
End Function

' the first drive letter from C with no path that isn't a RAM disc ("" none)
Function FreeLetter() As String
  Dim c As Integer, j As Integer, rd As String Max 16
  rd = ""
  For j = 0 To 7                                   ' the RAM discs (RAMDISC's list: "C: ...")
    q(0) = 3 : q(1) = j
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
