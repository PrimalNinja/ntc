' PREP: FILES.DIR on a volume, in CyborgOS (build for cpm, with CybDir.cls). Makes one so CD can
' go there and COPY can put files there, and keeps it up to date (it replaces the old CYBADD):
'   PREP v                            an empty FILES.DIR ("B" or "B:"); left alone if it has one
'   PREP [v:]pattern ADD              each disc file that fits, not already listed, added (its
'                                     size from the disc, long name = the name before the ".")
'   PREP [v:]pattern REMOVE           each listed file that fits, dropped
' A pattern: * any characters, ? any one (*.CYB, T*, * all). The new FILES.DIR is one 128 byte
' record of unused entries (not an empty file: a disc ROM may not open a file with nothing in it)
Option Explicit
Dim z(127) As Byte
Dim f(35) As Byte, d(127) As Byte, hsp As Integer
Dim a As String Max 40, v As String Max 2, op As String Max 8, pat As String Max 14, s As String Max 12, ln As String Max 12
Dim r As Integer, x As Integer, j As Integer, n As Integer, o As Integer, p As Integer
Dim sz As Long

a = UCase$(Trim$(System.CommandLine()))
p = InStr(a, " ")
If p > 0 Then                              ' the last word: ADD or REMOVE
  op = Trim$(Mid$(a, p + 1))
  a = Left$(a, p - 1)
End If

If op = "" Then                            ' PREP v: an empty FILES.DIR
  If Len(a) = 2 And Right$(a, 1) = ":" Then a = Left$(a, 1)
  If Len(a) <> 1 Then Usage
  v = a + ":"
  If FileSystem.Exists(v + "FILES.DIR") Then Print v; " has a FILES.DIR already" : End
  r = FileSystem.Save(v + "FILES.DIR", VarPtr(z), 128)
  x = FileSystem.Exists(v + "FILES.DIR")
  If x And CybDir.Load(v) Then
    Print v; "FILES.DIR made (no entries)"
  ElseIf r <> 0 Then
    Print v; "FILES.DIR could not be written ("; r; ")"
  Else
    Print v; "FILES.DIR not made"
  End If
  End
End If

If op <> "ADD" And op <> "REMOVE" Then Usage
If Mid$(a, 2, 1) = ":" Then
  v = Left$(a, 2) : pat = Mid$(a, 3)
Else
  v = FileSystem.CurrentVolume() + ":" : pat = a
End If
If pat = "" Then pat = "*"
If pat = "*.*" Then pat = "*"
If CybDir.Load(v) = False Then Print v; " has no FILES.DIR (PREP "; Left$(v, 1); " makes one)" : End
n = 0

If op = "REMOVE" Then
  For o = CybDir.Count() * 64 - 64 To 0 Step -64      ' back to front: Remove shifts the rest down
    If CybDir.Fits(CybDir.DiscName(o), pat) Then
      CybDir.Remove o
      n = n + 1
    End If
  Next
  If n > 0 Then r = CybDir.Save(v)
  Print Trim$(Str$(n)); " removed from "; v; "FILES.DIR"
  End
End If

' ADD: the volume's directory searched (????????.???, BDOS 17 / 18), each file that fits and
' isn't FILES.DIR or already listed added - its size the directory's record count x 128
f(0) = Asc(v) - 64
For j = 1 To 11
  f(j) = 63
Next
r = Bdos(26, VarPtr(d))
r = Bdos(17, VarPtr(f))
Do While r <> 255
  s = ""
  For j = 1 To 11
    If j = 9 And d(9) > 32 Then s = s + "."
    If d(j) > 32 Then s = s + Chr$(d(j) And 127)
  Next
  If s <> "FILES.DIR" And CybDir.Fits(s, pat) And CybDir.Find(s) < 0 Then
    sz = CLng(d(15)) * 128
    p = InStr(s, ".")
    If p > 0 Then ln = Left$(s, p - 1) Else ln = s
    x = 0
    If Right$(s, 4) = ".COM" Then x = 1            ' a raw .COM (no AMSDOS header)
    If CybDir.AddFile(s, sz, ln, x) Then
      n = n + 1
    Else
      Print v; "FILES.DIR is full" : Exit Do
    End If
  End If
  r = Bdos(18, VarPtr(f))
Loop
If n > 0 Then r = CybDir.Save(v)
Print Trim$(Str$(n)); " added to "; v; "FILES.DIR"
End

Sub Usage()
  Print "PREP v                 an empty FILES.DIR (a volume: A, B ...)"
  Print "PREP [v:]pattern ADD   disc files added (*.CYB, T*, * all)"
  Print "PREP [v:]pattern REMOVE"
  End
End Sub

' BDOS function fn, DE = dd: A
Function Bdos(ByVal fn As Integer, ByVal dd As Integer) As Integer
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld a, ({fn})
            ld c, a
            ld de, ({dd})
            ei
            call 5
            di
            ld l, a
            ld h, 0
            ld ({result}), hl
            ld sp, ({hsp})
#endasm
End Function
