' CybVol - drive letters, their paths and UniDOS's devices, for CyborgOS's CV and CD (build them
' for cpm, with this class): CyborgOS's UniDOS call (BDOS 30, #C0 + the call) and RAMDISC's list
' (BDOS 130). A path is a drive letter's, for every slot; 31 characters at most
Option Explicit
Private b(71) As Byte, q(49) As Byte
Private hsp As Integer

' Uni(): True when UniDOS is there (paths, folders, devices)
Public Function Uni() As Integer
  b(0) = &HC0
  Uni = (Bdos(30, VarPtr(b)) = 0)
End Function

' Here(): this slot's drive letter
Public Function Here() As String
  Here = FileSystem.CurrentVolume()
End Function

' Show(): this slot's drive and its path; with all True also the drives with paths and the devices
Public Sub Show(ByVal all As Integer)
  Dim c As Integer, s As String Max 32, v As String Max 2
  v = Here()
  Print "drive "; v; ":"; IIf(PathOf(v) <> "", " --> " + PathOf(v), "")
  If Not all Or Not Uni() Then Exit Sub
  For c = 65 To 80
    s = PathOf(Chr$(c))
    If s <> "" Then Print "  "; Chr$(c); ": --> "; s
  Next
  Devices
End Sub

' Devices(): UniDOS's devices listed ("Devices: IDE: SD:")
Public Sub Devices()
  Dim n As String Max 12, j As Integer
  b(0) = &HC3
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

' IsDevice(d): True when d is one of UniDOS's devices (IDE, SD, DFB, ZERO ...)
Public Function IsDevice(ByVal d As String) As Integer
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

' IsRam(d): True when d is a RAM disc's letter (RAMDISC's list): it has no path
Public Function IsRam(ByVal d As String) As Integer
  Dim j As Integer
  IsRam = False
  For j = 0 To 7
    q(0) = 3 : q(1) = j
    If Bdos(130, VarPtr(q)) <> 0 Then Exit Function
    If q(3) = Asc(d) Then IsRam = True : Exit Function
  Next
End Function

' PathOf(d): the drive letter's path ("" none - a RAM disc's letter none either)
Public Function PathOf(ByVal d As String) As String
  Dim j As Integer, t As String Max 32
  PathOf = ""
  b(0) = &HC1 : b(1) = Asc(d)
  If IsRam(d) Then Exit Function
  If Bdos(30, VarPtr(b)) <> 0 Then Exit Function
  t = ""
  For j = 1 To b(2)
    t = t + Chr$(b(j + 2))
  Next
  PathOf = t
End Function

' SetPath(d, p): the drive letter's path set (p "": dropped) - True, else the reason said
Public Function SetPath(ByVal d As String, ByVal p As String) As Integer
  Dim j As Integer
  SetPath = False
  If d = "Z" Then Print "Z: is CyborgOS's own" : Exit Function
  If IsRam(d) Then Print d; ": is a RAM disc (RAMDISC "; d; " 0 drops it)" : Exit Function
  If Len(p) > 31 Then Print "A path is 31 characters at most" : Exit Function
  b(0) = &HC2 : b(1) = Asc(d) : b(2) = Len(p)
  For j = 1 To Len(p)
    b(j + 2) = Asc(Mid$(p, j, 1))
  Next
  j = Bdos(30, VarPtr(b))
  If j = 0 Then SetPath = True : Exit Function
  If j = 255 Then Print "Paths need UniDOS" Else Print p; ": not a folder (UniDOS: "; Trim$(Str$(j)); ")"
End Function

' Usable(p): a folder UniDOS can list - its first entry asked for: 0 or 1 (none) it can, 254 a
' drive it can't examine (a floppy AMSDOS has), else not
Public Function Usable(ByVal p As String) As Integer
  Dim j As Integer
  b(0) = &HC5 : b(1) = 0 : b(2) = 0 : b(3) = 0 : b(28) = Len(p)
  For j = 1 To Len(p)
    b(j + 28) = Asc(Mid$(p, j, 1))
  Next
  Usable = Bdos(30, VarPtr(b))
End Function

' FreeLetter(): the first drive letter from C with no path that isn't a RAM disc ("" none)
Public Function FreeLetter() As String
  Dim c As Integer, j As Integer, rd As String Max 16
  rd = ""
  For j = 0 To 7
    q(0) = 3 : q(1) = j
    If Bdos(130, VarPtr(q)) <> 0 Then Exit For
    rd = rd + Chr$(q(3))
  Next
  FreeLetter = ""
  For c = 67 To 80
    If PathOf(Chr$(c)) = "" And InStr(rd, Chr$(c)) = 0 Then FreeLetter = Chr$(c) : Exit Function
  Next
End Function

' Select(d, p): drive letter d gets path p (on A, B - UniDOS's own two, the boot drive one of them
' - or a RAM disc: the first free letter from C instead) and is this slot's drive; a line says so
Public Sub SelectPath(ByVal d As String, ByVal p As String)
  Dim r As Integer
  If Len(p) > 31 Then Print "A path is 31 characters at most" : Exit Sub
  If d = "A" Or d = "B" Or IsRam(d) Then
    d = FreeLetter()
    If d = "" Then Print "No drive letter free (C-P)" : Exit Sub
  End If
  If SetPath(d, p) Then
    r = FileSystem.SelectVolume(d)
    Print "drive "; d; ": --> "; PathOf(d)
  End If
End Sub

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
            di                      ; (off before SP is the threaded code again: it comes back with them on)
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function
