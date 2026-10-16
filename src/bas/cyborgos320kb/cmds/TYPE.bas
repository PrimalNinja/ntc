' TYPE: a text file shown, in CyborgOS (build for cpm).
'   TYPE [v:]name                     a name with no volume: this slot's drive
' Any file the drive has. The text ends at the end of the file or its first ^Z (#1A); a line
' longer than the console is wide is word wrapped (the next part indented as the line is); a
' page at a time (-- more --: space a page, Enter a line, Q / ESC / Control + C the end).
Option Explicit
Dim a As String Max 40, v As String Max 2, f As String Max 40
Dim ln As String Max 255                         ' (a line: 255 characters - the library's strings are as long as the longest declared)
Dim h As Integer, r As Integer, cw As Integer, pr As Integer, nl As Integer, hsp As Integer, pb(3) As Byte

a = UCase$(Trim$(System.CommandLine()))
If a = "" Or InStr(a, " ") > 0 Then Print "TYPE [v:]name" : End
If Mid$(a, 2, 1) = ":" Then
  v = Left$(a, 2) : f = Mid$(a, 3)
Else
  v = FileSystem.CurrentVolume() + ":" : f = a
End If
h = FileSystem.Open(v + f, FileSystem.ForRead)
If h < 0 Then Print v; f; ": not found" : End
Do While Not FileSystem.Eof(h)
  ln = FileSystem.ReadLine(h) : Wrap ln
Loop
r = FileSystem.Close(h)
End

' t printed word wrapped to the console's width (BDOS 49): a line too long broken at its last space
' that fits, the next part indented as far as the line was (a word longer than a line: cut)
Sub Wrap(ByVal t As String)
  Dim k As Integer, ind As Integer
  If cw = 0 Then
    pb(0) = &H1A : cw = Bdos(49, VarPtr(pb))      ' (CP/M 3's #1A: the width - 1)
    If cw < 12 Or cw > 200 Then cw = 79
  End If
  ind = 0
  Do While ind < Len(t)
    If Mid$(t, ind + 1, 1) <> " " Then Exit Do
    ind = ind + 1
  Loop
  If ind > cw \ 2 Then ind = 0
  Do While Len(t) > cw
    k = cw + 1
    Do While k > ind + 1
      If Mid$(t, k, 1) = " " Then Exit Do
      k = k - 1
    Loop
    If k <= ind + 1 Then
      Out1 Left$(t, cw) : t = Mid$(t, cw + 1)
    Else
      Out1 Left$(t, k - 1) : t = Mid$(t, k + 1)
    End If
    Do While Left$(t, 1) = " "
      t = Mid$(t, 2)
    Loop
    If t = "" Then Exit Sub
    t = Space$(ind) + t
  Loop
  Out1 t
End Sub

' a line out, a page at a time: when the console is full, "-- more --" waits for a key (space: a
' page more, Enter: a line, Q / ESC / Control + C: the end)
Sub Out1(ByVal t As String)
  Dim k As Integer
  If pr = 0 Then
    pb(0) = &H1C : pr = Bdos(49, VarPtr(pb))     ' (CP/M 3's #1C: the page length)
    If pr < 4 Or pr > 100 Then pr = 24
  End If
  If nl >= pr - 1 Then
    Print "-- more (space, Enter, Q) --";
    Do
      k = Bdos(6, &HFF)
    Loop While k = 0
    Print String$(28, 8); Space$(28); String$(28, 8);   ' (the prompt rubbed out: BS, spaces, BS)
    If k = 81 Or k = 113 Or k = 27 Or k = 3 Then End
    If k = 13 Then nl = pr - 2 Else nl = 0
  End If
  Print t
  nl = nl + 1
End Sub

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
