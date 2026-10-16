' RMDIR: an empty folder removed, in CyborgOS (build for cpm) - with UniDOS only
'   RMDIR name                       in this drive's folder (its path: CD)
'   RMDIR IDE:GAMES/OLD              anywhere (a device or a drive, then the folders)
' Only an empty one: UniDOS's |ERA on a folder takes all it holds too, so RMDIR looks first. The
' folder goes through a drive letter with no path (C-P, not a RAM disc): its path for a moment the
' folder's parent, then the folder deleted there (BDOS 19), then no path again
Option Explicit
Dim a As String Max 60, p As String Max 60, pa As String Max 60, nm As String Max 12, v As String Max 2
Dim r As Integer, j As Integer, k As Integer, hsp As Integer
Dim b(71) As Byte, q(49) As Byte
a = UCase$(Trim$(System.CommandLine()))
If a = "" Or InStr(a, " ") > 0 Then Print "RMDIR name   RMDIR IDE:GAMES/OLD" : End
b(0) = &HC0
If Bdos(30, VarPtr(b)) <> 0 Then Print "Folders need UniDOS" : End
p = a
If InStr(a, ":") = 0 Then                        ' in this drive's folder
  v = FileSystem.CurrentVolume()
  p = PathOf(v)
  If p = "" Then p = v + ":"
  p = p + a
End If
If Right$(p, 1) = "/" Then p = Left$(p, Len(p) - 1)
k = 0                                            ' the parent (to its last "/" or ":"), the name
For j = 1 To Len(p)
  If Mid$(p, j, 1) = "/" Or Mid$(p, j, 1) = ":" Then k = j
Next
pa = Left$(p, k) : nm = Mid$(p, k + 1)
j = InStr(nm, ".")
If nm = "" Or (j = 0 And Len(nm) > 8) Or j > 9 Or (j > 0 And Len(nm) - j > 3) Then Print p; ": not a folder's name (NAME.EXT)" : End
If Len(pa) > 31 Then Print "A path is 31 characters at most" : End
b(0) = &HC5 : b(1) = 0 : b(2) = 0 : b(3) = 0     ' empty? its first entry asked for
SetStr 28, p + "/"
r = Bdos(30, VarPtr(b))
If r = 0 Then Print p; "/ is not empty" : End
If r <> 1 Then Print p; ": not a folder (UniDOS: "; Trim$(Str$(r)); ")" : End
v = FreeLetter()
If v = "" Then Print "No drive letter free (C-P) to reach it through" : End
b(0) = &HC2 : b(1) = Asc(v)                      ' the letter's path: the parent, for a moment
SetStr 2, pa
r = Bdos(30, VarPtr(b))
If r <> 0 Then Print pa; ": not a folder (UniDOS: "; Trim$(Str$(r)); ")" : End
b(0) = &HC8                                      ' (the delete may take a folder: only RMDIR asks)
r = Bdos(30, VarPtr(b))
r = FileSystem.Delete(v + ":" + nm)
b(0) = &HC2 : b(1) = Asc(v) : b(2) = 0           ' no path again
j = Bdos(30, VarPtr(b))
b(0) = &HC5 : b(1) = 0 : b(2) = 0 : b(3) = 0     ' gone?
SetStr 28, p + "/"
r = Bdos(30, VarPtr(b))
If r = 0 Or r = 1 Then Print p; "/: not removed" Else Print p; "/ removed"
End

' s into b at i: its length, then its characters
Sub SetStr(ByVal i As Integer, ByVal s As String)
  Dim n As Integer
  b(i) = Len(s)
  For n = 1 To Len(s)
    b(i + n) = Asc(Mid$(s, n, 1))
  Next
End Sub

' the drive letter's path ("" none)
Function PathOf(ByVal d As String) As String
  Dim n As Integer, t As String Max 32
  PathOf = ""
  b(0) = &HC1 : b(1) = Asc(d)
  If Bdos(30, VarPtr(b)) <> 0 Then Exit Function
  t = ""
  For n = 1 To b(2)
    t = t + Chr$(b(n + 2))
  Next
  PathOf = t
End Function

' the first drive letter from C with no path that isn't a RAM disc ("" none)
Function FreeLetter() As String
  Dim c As Integer, n As Integer, rd As String Max 16
  rd = ""
  For n = 0 To 7                                   ' the RAM discs (RAMDISC's list: "F: ...")
    q(0) = 3 : q(1) = n
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
