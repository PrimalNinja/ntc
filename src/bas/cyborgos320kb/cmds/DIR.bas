' DIR: a drive's files, in CyborgOS (build for cpm, with CybDir.cls)
'   DIR [v:][pattern] [FULL]         no drive: this slot's; B alone: drive B; pattern: * any
'                                    characters, ? any one (*.CYB, T*)
'   DIR IDE:[folder/][pattern]       (UniDOS) a device's folder: SD:GAMES/, IDE:*.BAS ...
'   DIR folder/[pattern]             (UniDOS) a folder in this drive's
' The names only, across the screen as wide as the console is (BDOS 49), a name never split. FULL:
' a line each, its size, and how many. With UniDOS the folder as UniDOS lists it (BDOS 30, #C5):
' its folders too ("NAME/"), hidden ones only with FULL; FULL: sizes, dates. A RAM disc (Z,
' RAMDISC's): its own directory, sizes from the records. An AMSDOS floppy: FLOPPY lists it
Option Explicit
Dim a As String Max 40, v As String Max 2, pt As String Max 14, t As String Max 40, up As String Max 40
Dim n As Integer, k As Integer, o As Integer, r As Integer, full As Integer, w As Integer, x As Integer
Dim pb(3) As Byte, hsp As Integer, s As String Max 14, j As Integer
Dim b(71) As Byte, z As Long, nd As Integer
a = UCase$(Trim$(System.CommandLine()))
full = 0 : pt = "*" : v = "" : up = ""
Do While a <> ""                                 ' the words: FULL, v:pattern, B alone, a path, a pattern
  j = InStr(a + " ", " ")
  t = Left$(a, j - 1) : a = Trim$(Mid$(a, j))
  If t = "FULL" Then
    full = -1
  ElseIf Len(t) = 1 Then
    v = t + ":"
  ElseIf Mid$(t, 2, 1) = ":" Then
    v = Left$(t, 2)
    If Len(t) > 2 Then pt = Mid$(t, 3)
  ElseIf InStr(t, ":") > 0 Or InStr(t, "/") > 0 Then
    k = 0                                        ' a path (UniDOS): to its last "/" or ":", then a pattern
    For j = 1 To Len(t)
      If Mid$(t, j, 1) = "/" Or Mid$(t, j, 1) = ":" Then k = j
    Next
    up = Left$(t, k)
    If k < Len(t) Then pt = Mid$(t, k + 1)
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
If up <> "" And InStr(up, ":") = 0 Then          ' a folder in this drive's: its path first
  b(0) = &HC1 : b(1) = Asc(v)
  If Bdos(30, VarPtr(b)) = 0 Then
    t = ""
    For j = 1 To b(2)
      t = t + Chr$(b(j + 2))
    Next
    If t = "" Then t = v
    up = t + up
  End If
End If
If up = "" And IsRam() Then                      ' a RAM disc: its own directory (not a UniDOS path)
ElseIf UniList() Then
  If x > 0 Then Print
  End
End If
If up <> "" Then Print "Folders need UniDOS" : End
If CybDir.LoadAll(v) = False Then Print v; " its files can't be listed (UniDOS's drives and RAM discs can)" : End
For o = 0 To CybDir.Count() - 1               ' a RAM disc: its own directory (sizes from records)
  If CybDir.Match(o, pt) Then
    s = CybDir.DiscName(o)
    If full Then Print Left$(s + Space$(13), 13); Right$(Space$(9) + Trim$(Str$(CybDir.Length(o))), 9) Else Wide s
    n = n + 1
  End If
Next
If full Then Print Trim$(Str$(n)); " files"
If x > 0 Then Print
End

' UniDOS: the folder (up, else drive v's) as UniDOS lists it - False when it can't (no UniDOS, a
' RAM disc, an AMSDOS floppy)
Function UniList() As Integer
  Dim i As Integer, nf As Integer, hd As String Max 40
  UniList = False
  hd = up
  If up = "" Then                                ' (FULL's heading: the drive and its path)
    b(0) = &HC1 : b(1) = Asc(v) : hd = v
    If Bdos(30, VarPtr(b)) = 0 And b(2) > 0 Then
      hd = hd + " "
      For j = 1 To b(2)
        hd = hd + Chr$(b(j + 2))
      Next
    End If
  End If
  b(0) = &HC5 : b(1) = 0 : b(2) = 0 : b(3) = 0
  If up <> "" Then
    b(28) = Len(up)
    For j = 1 To Len(up)
      b(j + 28) = Asc(Mid$(up, j, 1))
    Next
  Else
    b(1) = Asc(v)
  End If
  r = Bdos(30, VarPtr(b))
  If r = 254 Or r = 255 Then Exit Function
  UniList = True
  If r > 1 Then Print IIf(up <> "", up, v); " not there (UniDOS: "; Trim$(Str$(r)); ")" : Exit Function
  If full Then Print hd
  nf = 0 : nd = 0 : i = 0
  Do While r = 0
    s = ""
    For j = 16 To 26
      If j = 24 And b(24) > 32 Then s = s + "."
      If b(j) > 32 Then s = s + Chr$(b(j) And 127)
    Next
    If (b(4) And 2) = 0 Or full Then
      If CybDir.Fits(s, pt) Or pt = "*" Then
        If b(4) And 16 Then
          nd = nd + 1
          If full Then Print Left$(s + "/" + Space$(13), 13); "  <DIR>  "; UDate() Else Wide s + "/"
        Else
          nf = nf + 1
          If full Then
            z = b(5) + b(6) * 256& + b(7) * 65536& + b(8) * 16777216&
            Print Left$(s + Space$(13), 13); Right$(Space$(9) + Trim$(Str$(z)), 9); " "; UDate()
          Else
            Wide s
          End If
        End If
      End If
    End If
    i = i + 1
    b(0) = &HC5 : b(2) = i And 255 : b(3) = i \ 256
    r = Bdos(30, VarPtr(b))
  Loop
  If full Then Print Trim$(Str$(nf)); " files, "; Trim$(Str$(nd)); " folders"
End Function

' True when drive v is a RAM disc (RAMDISC's list: "F: ...")
Function IsRam() As Integer
  Dim i As Integer
  IsRam = False
  For i = 0 To 7
    b(0) = 3 : b(1) = i
    If Bdos(130, VarPtr(b)) <> 0 Then Exit Function
    If b(3) = Asc(v) Then IsRam = True : Exit Function
  Next
End Function

' the entry's date (UniDOS: b(9-15)) as DD-MM-YY HH:MM ("" none)
Function UDate() As String
  Dim y As Integer
  y = b(9) + b(10) * 256
  If y < 1978 Or b(11) = 0 Then UDate = "" : Exit Function
  UDate = Right$("0" + Trim$(Str$(b(12))), 2) + "-" + Right$("0" + Trim$(Str$(b(11))), 2) + "-" + Right$("0" + Trim$(Str$(y Mod 100)), 2) + " " + Right$("0" + Trim$(Str$(b(13))), 2) + ":" + Right$("0" + Trim$(Str$(b(14))), 2)
End Function

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
