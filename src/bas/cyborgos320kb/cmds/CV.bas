' CV: change volume - this slot's drive, and (UniDOS) a drive letter's device and path, in
' CyborgOS (build for cpm, with CybVol.cls). CD changes folders.
'   CV                               this slot's drive (and its path); with UniDOS also the drives
'                                    with paths and the devices there
'   CV B  CV B:  (or B: alone)       drive B. Not Z: the system drive is CyborgOS's own
' With UniDOS (a drive letter can be a path - any device's folder):
'   CV IDE:  CV IDE  (or IDE: alone) a device: this drive's path is its top. On A or B (UniDOS's
'                                    own two, the boot drive one of them) or a RAM disc the first
'                                    drive from C with no path (not a RAM disc) gets it instead,
'                                    and is this slot's. A RAM disc's letter never has a path
'   CV SD:GAMES/ACTION               a device's folder
'   CV C: IDE:WORK                   drive C's path set, C this slot's drive
'   CV C: -                          drive C's path dropped (C on its own again)
Option Explicit
Dim a As String Max 60, w As String Max 40, v As String Max 2, p As String Max 40
Dim r As Integer, i As Integer, uni As Integer
a = UCase$(Trim$(System.CommandLine()))
uni = CybVol.Uni()
If a = "" Then CybVol.Show True : End
i = InStr(a + " ", " ")
w = Left$(a, i - 1) : a = Trim$(Mid$(a, i))
If Len(w) = 2 And Right$(w, 1) = ":" Then w = Left$(w, 1)
If Len(w) = 1 Then                                 ' a drive letter
  If w < "A" Or w > "P" Then Print w; ": no such drive" : End
  If a <> "" Then
    If uni = 0 Then Print "Paths need UniDOS" : End
    If a = "-" Then
      If CybVol.SetPath(w, "") Then Print w; ": its path dropped"
      End
    End If
    If CybVol.SetPath(w, a) Then r = FileSystem.SelectVolume(w) : Print "drive "; w; ": --> "; CybVol.PathOf(w)
    End
  End If
  r = 254
  If CybVol.IsRam(w) Then
    r = 0                                          ' (a RAM disc)
  ElseIf uni Then
    If CybVol.PathOf(w) <> "" Then r = 0 Else r = CybVol.Usable(w + ":")
  End If
  If r = 254 Then                                  ' (no UniDOS, or a floppy it can't examine:
    If w > "B" Then Print w; ": no such drive" : End   ' A and B are there)
  ElseIf r > 1 Then
    Print w; ": no such drive" : End
  End If
  r = FileSystem.SelectVolume(w)
  Print "drive "; w; ":"; IIf(CybVol.PathOf(w) <> "", " --> " + CybVol.PathOf(w), "")
  End
End If
If uni = 0 Then Print w; ": no such drive (devices need UniDOS)" : End
If Right$(w, 1) <> ":" And InStr(w, ":") = 0 Then
  If Not CybVol.IsDevice(w) Then Print w; ": no such device (CD "; w; ": a folder)" : End
  w = w + ":"                                      ' (CV IDE as CV IDE:)
End If
CybVol.SelectPath CybVol.Here(), w
End
