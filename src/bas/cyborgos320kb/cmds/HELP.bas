' HELP: CyborgOS's help, in CyborgOS (build for cpm) - text files, shown as TYPE shows one
'   HELP                             HELP.HLP: the commands
'   HELP name                        NAME.HLP (HELP DIR, HELP CD ...; a name with a "." as it is)
' Looked for on this slot's drive, then in the HELP folder of drive A or B (where the installer
' puts them: CYBORGOS/HELP - UniDOS, through a free drive letter whose path it is for a moment),
' then on A and Z. The .HLP files are plain text (CR LF lines, ^Z at the end): any can be edited,
' and a program can have one of its own. A line longer than the console is wide is word wrapped;
' a page at a time (-- more --)
Option Explicit
Dim a As String Max 40, v As String Max 2, s As String Max 8
Dim ln As String Max 255                         ' (a line: 255 characters - the library's strings are as long as the longest declared)
Dim h As Integer, r As Integer, i As Integer, j As Integer, hsp As Integer, cw As Integer, pr As Integer, nl As Integer, pb(3) As Byte
Dim b(71) As Byte, q(49) As Byte
a = UCase$(Trim$(System.CommandLine()))
If a = "" Then a = "HELP"
If InStr(a, " ") > 0 Then a = Left$(a, InStr(a, " ") - 1)
If InStr(a, ".") = 0 Then a = a + ".HLP"
If InStr(a, ":") > 0 Then Show "" : Show2
Show ""
b(0) = &HC0
If Bdos(30, VarPtr(b)) = 0 Then                  ' UniDOS: A:HELP/, B:HELP/
  v = FreeLetter()
  If v <> "" Then
    For i = 0 To 1
      b(0) = &HC2 : b(1) = Asc(v) : s = Chr$(65 + i) + ":HELP/" : b(2) = Len(s)
      For j = 1 To Len(s)
        b(j + 2) = Asc(Mid$(s, j, 1))
      Next
      If Bdos(30, VarPtr(b)) = 0 Then Show v + ":"
    Next
    NoPath
  End If
End If
Show "A:"
Show "Z:"
Show2

' a + its text from drive (or letter) d, then the end - when it is there
Sub Show(ByVal d As String)
  h = FileSystem.Open(d + a, FileSystem.ForRead)
  If h < 0 Then Exit Sub
  Do While Not FileSystem.Eof(h)
    ln = FileSystem.ReadLine(h) : Wrap ln
  Loop
  r = FileSystem.Close(h)
  NoPath
  End
End Sub

Sub Show2()
  Print "No help for "; a; " (HELP: the commands)"
  End
End Sub

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

' the free letter's path dropped again
Sub NoPath()
  If v = "" Then Exit Sub
  b(0) = &HC2 : b(1) = Asc(v) : b(2) = 0
  r = Bdos(30, VarPtr(b))
  v = ""
End Sub

' the first drive letter from P down with no path that isn't a RAM disc ("" none)
Function FreeLetter() As String
  Dim c As Integer, n As Integer, rd As String Max 16
  rd = ""
  For n = 0 To 7                                   ' the RAM discs (RAMDISC's list: "F: ...")
    q(0) = 3 : q(1) = n
    If Bdos(130, VarPtr(q)) <> 0 Then Exit For
    rd = rd + Chr$(q(3))
  Next
  FreeLetter = ""
  For c = 80 To 67 Step -1
    b(0) = &HC1 : b(1) = c
    If Bdos(30, VarPtr(b)) = 0 And b(2) = 0 And InStr(rd, Chr$(c)) = 0 Then FreeLetter = Chr$(c) : Exit Function
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
