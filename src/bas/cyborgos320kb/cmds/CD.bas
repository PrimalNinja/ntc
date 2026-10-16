' CD: change directory - a folder of this slot's drive, in CyborgOS (build for cpm, with
' CybVol.cls). Folders need UniDOS. CV changes drives and devices.
'   CD                               this slot's drive and its folder
'   CD GAMES   CD GAMES/ACTION       a folder in this one (any name: CD C is the folder C)
'   CD ..                            the folder this one is in
'   CD /                             the device's top
' On A or B (UniDOS's own two, the boot drive one of them) or a RAM disc the first drive from C
' with no path (not a RAM disc) gets the folder instead, and is this slot's. A path is 31
' characters at most
Option Explicit
Dim a As String Max 60, w As String Max 40, v As String Max 2, p As String Max 40, s As String Max 40
Dim i As Integer, k As Integer
a = UCase$(Trim$(System.CommandLine()))
v = CybVol.Here()
If a = "" Then CybVol.Show False : End
i = InStr(a + " ", " ")
w = Left$(a, i - 1)
If InStr(w, ":") > 0 Then Print "CD changes folders: CV "; w; " for a drive or a device" : End
If Not CybVol.Uni() Then Print "Folders need UniDOS" : End
p = CybVol.PathOf(v)
If p = "" Then p = v + ":"
If w = ".." Then
  s = Left$(p, Len(p) - 1)                         ' (its last "/" or ":" off)
  k = 0
  For i = 1 To Len(s)
    If Mid$(s, i, 1) = "/" Or Mid$(s, i, 1) = ":" Then k = i
  Next
  If k = 0 Or Right$(p, 1) = ":" Then Print p; " is the top" : End
  p = Left$(s, k)
ElseIf w = "/" Or w = "\" Then
  p = Left$(p, InStr(p, ":"))                      ' the device's top
Else
  If Right$(w, 1) <> "/" Then w = w + "/"
  i = CybVol.Usable(p + w)
  If i <> 0 And i <> 1 Then Print p; w; ": no such folder" : End
  p = p + w
End If
CybVol.SelectPath v, p
End
