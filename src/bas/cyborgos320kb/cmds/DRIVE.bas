' DRIVE: the drive letters and the devices, in CyborgOS (build for cpm)
'   DRIVE                            each drive letter in use: A and B (UniDOS's own two, or
'                                    AMSDOS's), a letter with a path (CD C: IDE:WORK), a RAM disc
'                                    (RAMDISC, Z); then with UniDOS its devices by their own
'                                    names (IDE, SD, UMS, M4, DFA, DFB, TAPE, ZERO ...): what each
'                                    is, its free space, or "not there" (nothing in it now)
Option Explicit
Dim b(71) As Byte, q(49) As Byte, nm(15) As String Max 9
Dim r As Integer, i As Integer, j As Integer, c As Integer, n As Integer, uni As Integer, hsp As Integer
Dim s As String Max 40, rd As String Max 16, t As String Max 72
Dim z As Long
b(0) = &HC0 : uni = (Bdos(30, VarPtr(b)) = 0)   ' (BDOS 30, #C0: CyborgOS's UniDOS calls - 0: UniDOS)
Print "Drives:"
rd = ""
For j = 0 To 7                                   ' the RAM discs (RAMDISC's lines: "C: 256K, ...")
  q(0) = 3 : q(1) = j
  If Bdos(130, VarPtr(q)) <> 0 Then Exit For
  rd = rd + Chr$(q(3))
Next
For c = 65 To 90
  s = ""
  If InStr(rd, Chr$(c)) > 0 Then
    s = "RAM disc"
  ElseIf uni And c <= 80 Then
    b(0) = &HC1 : b(1) = c
    If Bdos(30, VarPtr(b)) = 0 And b(2) > 0 Then
      For j = 1 To b(2)
        s = s + Chr$(b(j + 2))
      Next
    End If
  End If
  If s <> "" Then
    Print "  "; Chr$(c); ": --> "; s
  ElseIf c <= 66 Then
    Print "  "; Chr$(c); ":  "; IIf(uni, "UniDOS's own", "AMSDOS's")
  End If
Next
For j = 0 To 7                                   ' (the RAM discs' own lines)
  q(0) = 3 : q(1) = j
  If Bdos(130, VarPtr(q)) <> 0 Then Exit For
  t = ""
  For i = 1 To q(2)
    t = t + Chr$(q(i + 2))
  Next
  Print "  "; t
Next
If uni = 0 Then Print "(no UniDOS: no devices, no paths)" : End
b(0) = &HC3                                      ' the devices: names, the last character + #80
If Bdos(30, VarPtr(b)) <> 0 Then End
n = 0 : s = "" : j = 2
Do While j < 66 And b(j) <> 255 And n < 16
  s = s + Chr$(b(j) And 127)
  If b(j) > 127 Then nm(n) = s : n = n + 1 : s = ""
  j = j + 1
Loop
Print "Devices:"
For i = 0 To n - 1
  b(0) = &HC4                                    ' its information: status, -, free K (4), all K (4), what it is
  For j = 1 To Len(nm(i))
    b(j + 1) = Asc(Mid$(nm(i), j, 1))
  Next
  b(Len(nm(i)) + 1) = b(Len(nm(i)) + 1) Or 128
  t = Left$(nm(i) + ":" + Space$(9), 9)
  If Bdos(30, VarPtr(b)) <> 0 Then
    Print "  "; t
  Else
    s = ""
    For j = 18 To 49
      s = s + Chr$(b(j) And 127)
      If b(j) > 127 Then Exit For
    Next
    t = t + Left$(s + Space$(33), 33)
    If (b(8) And 1) = 0 Then
      t = t + "not there"
    Else
      z = b(10) + b(11) * 256& + b(12) * 65536& + (b(13) And 127) * 16777216&
      If b(13) = 255 And b(12) = 255 Then
        t = t + "there"
      ElseIf z >= 10240 Then
        t = t + Trim$(Str$(z \ 1024)) + "M free"
      Else
        t = t + Trim$(Str$(z)) + "K free"
      End If
    End If
    Print "  "; t
  End If
Next
End

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
