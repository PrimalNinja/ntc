' MKDIR: a folder made, in CyborgOS (build for cpm) - with UniDOS only
'   MKDIR name                       in this drive's folder (its path: CD)
'   MKDIR IDE:GAMES/NEW              anywhere (a device or a drive, then the folders)
Option Explicit
Dim a As String Max 60, p As String Max 60, v As String Max 2
Dim r As Integer, j As Integer, hsp As Integer
Dim b(71) As Byte
a = UCase$(Trim$(System.CommandLine()))
If a = "" Or InStr(a, " ") > 0 Then Print "MKDIR name   MKDIR IDE:GAMES/NEW" : End
b(0) = &HC0
If Bdos(30, VarPtr(b)) <> 0 Then Print "Folders need UniDOS" : End
p = a
If InStr(a, ":") = 0 Then                        ' in this drive's folder
  v = FileSystem.CurrentVolume()
  b(0) = &HC1 : b(1) = Asc(v)
  p = v + ":"
  If Bdos(30, VarPtr(b)) = 0 And b(2) > 0 Then
    p = ""
    For j = 1 To b(2)
      p = p + Chr$(b(j + 2))
    Next
  End If
  p = p + a
End If
If Right$(p, 1) <> "/" Then p = p + "/"
If Len(p) > 46 Then Print "A path is 46 characters at most" : End
b(0) = &HC6 : b(2) = Len(p)
For j = 1 To Len(p)
  b(j + 2) = Asc(Mid$(p, j, 1))
Next
r = Bdos(30, VarPtr(b))
If r = 0 Then
  Print p; " made"
ElseIf r = 255 Then
  Print p; ": not made (a file is being written)"
Else
  Print p; ": not made (UniDOS: "; Trim$(Str$(r)); ")"
End If
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
