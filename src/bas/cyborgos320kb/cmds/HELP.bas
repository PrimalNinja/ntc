' HELP: CyborgOS's help, in CyborgOS (build for cpm) - text files, shown as TYPE shows one
'   HELP                             HELP.HLP: the commands
'   HELP name                        NAME.HLP (HELP DIR, HELP CD ...; a name with a "." as it is)
' Looked for on this slot's drive, then in the HELP folder of drive A or B (where the installer
' puts them: CYBORGOS/HELP - UniDOS, through a free drive letter whose path it is for a moment),
' then on A and Z. The .HLP files are plain text (CR LF lines, ^Z at the end): any can be edited,
' and a program can have one of its own
Option Explicit
Dim a As String Max 40, v As String Max 2, s As String Max 8
Dim h As Integer, r As Integer, i As Integer, j As Integer, hsp As Integer
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
    Print FileSystem.ReadLine(h)
  Loop
  r = FileSystem.Close(h)
  NoPath
  End
End Sub

Sub Show2()
  Print "No help for "; a; " (HELP: the commands)"
  End
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
