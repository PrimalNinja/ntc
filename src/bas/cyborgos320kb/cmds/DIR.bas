' DIR: a drive's files, in CyborgOS (build for cpm, with CybDir.cls)
'   DIR [v:][pattern] [FULL]         no drive: this slot's; B alone: drive B; pattern: * any
'                                    characters, ? any one (*.CYB, T*)
' The names only, across the screen as wide as the console is (BDOS 49), a name never split. FULL:
' a line each - FILES.DIR's entries (disc name, length, long name), then any other file the
' drive's directory has (a RAM disc's: a file a program made; a disc's directory is FILES.DIR
' until CyborgOS reads the disc's own) with its size from its records, and how many
Option Explicit
Dim a As String Max 40, v As String Max 2, pt As String Max 14, t As String Max 20
Dim n As Integer, k As Integer, o As Integer, r As Integer, full As Integer, w As Integer, x As Integer
Dim f(35) As Byte, d(127) As Byte, pb(3) As Byte, hsp As Integer, s As String Max 12, j As Integer
a = UCase$(Trim$(System.CommandLine()))
full = 0 : pt = "*" : v = ""
Do While a <> ""                                 ' the words: FULL, v:pattern, B alone, a pattern
  j = InStr(a + " ", " ")
  t = Left$(a, j - 1) : a = Trim$(Mid$(a, j))
  If t = "FULL" Then
    full = -1
  ElseIf Len(t) = 1 Then
    v = t + ":"
  ElseIf Mid$(t, 2, 1) = ":" Then
    v = Left$(t, 2)
    If Len(t) > 2 Then pt = Mid$(t, 3)
  Else
    pt = t
  End If
Loop
If v = "" Then v = FileSystem.CurrentVolume() + ":"
If pt = "*.*" Then pt = "*"
pb(0) = &H1A : w = Bdos(49, VarPtr(pb)) + 1     ' (the console's width: CP/M 3's #1A, the width - 1)
If w < 13 Or w > 200 Then w = 80
x = 0
n = 0
If CybDir.Load(v) = False Then
  If full Then Print "no FILES.DIR"
Else
  For o = 0 To CybDir.Count() * 64 - 64 Step 64
    If CybDir.Match(o, pt) Then
      s = CybDir.DiscName(o)
      If full Then
        Print Left$(s + Space$(12), 12); Right$(Space$(6) + Trim$(Str$(CybDir.Length(o))), 6); "  "; CybDir.LongName(o)
      Else
        Wide s
      End If
      n = n + 1
    End If
  Next
  If full Then Print Trim$(Str$(n)); " in FILES.DIR"
End If
' the directory: search ????????.??? (BDOS 17, 18) into d at the DMA
f(0) = Asc(v) - 64
For j = 1 To 11
  f(j) = 63
Next
r = Bdos(26, VarPtr(d))
k = 0
r = Bdos(17, VarPtr(f))
Do While r <> 255
  If CybDir.Has(VarPtr(d) + 1) < 0 Then          ' (not in FILES.DIR: bytes compared, no strings)
    s = ""
    For j = 1 To 11
      If j = 9 And d(9) > 32 Then s = s + "."
      If d(j) > 32 Then s = s + Chr$(d(j) And 127)
    Next
    If s <> "FILES.DIR" And (pt = "*" Or CybDir.Fits(s, pt)) Then
      If full Then Print Left$(s + Space$(12), 12); Right$(Space$(6) + Trim$(Str$(CLng(d(15)) * 128)), 6) Else Wide s
      k = k + 1
    End If
  End If
  r = Bdos(18, VarPtr(f))
Loop
If full And k > 0 Then Print Trim$(Str$(k)); " more (not in FILES.DIR)"
If x > 0 Then Print
End

' a name in the block: 13 columns each (12 and a space), a new line before one that won't fit
Sub Wide(ByVal s As String)
  If x + 12 > w - 1 Then Print : x = 0
  Print Left$(s + Space$(13), 13);
  x = x + 13
End Sub

' BDOS function f, DE = d: A
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
