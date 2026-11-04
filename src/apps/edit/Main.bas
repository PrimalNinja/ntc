' EDIT - a plain text editor for the CPC (NTC BASIC, cpcfw: a native program, or a CyborgOS slot).
' Mode 2, 80 columns, up to 100 lines of 78 (an 8K file). Files by any path the disc system knows: with
' UniDOS and Streamer, STORE:NAME.BAS (and GRAPHICS:, MUSIC: ...) is the Pi - so this edits on
' the Pi from the CPC. Keys: arrows; typing inserts; DEL deletes left, CLR at the cursor; Return
' splits a line; Control + S save (the name asked), Control + L load, Control + N new,
' Control + Q quit; Control + E end of line, Control + A its start; Copy = Page down, Tab = Page
' up (the firmware's codes: arrows 240-243, DEL 127, CLR 16, Copy 224, Tab 9).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Const MAXL = 100
Const WIDE = 78
Const ROWS = 23
Dim ln(MAXL) As String Max 80
Dim n As Integer                      ' lines in use
Dim cx As Integer, cy As Integer      ' the cursor: column (0 based), line
Dim top As Integer                    ' the first line shown
Dim k As Integer, i As Integer, r As Integer
Dim name As String Max 40
Dim msg As String Max 60
Dim buf(8191) As Byte                 ' a file's bytes for load / save (8K)
Dim dirty As Integer

Sub Status(ByVal s As String Max 60)
  StdIO.Locate 1, 25
  Print Left$(s + Space$(78), 78);
End Sub

Sub ShowLine(ByVal i As Integer)
  StdIO.Locate 1, i - top + 1
  If i < n Then Print Left$(ln(i) + Space$(WIDE), WIDE); Else Print Space$(WIDE);
End Sub

Sub ShowAll()
  Dim i As Integer
  For i = top To top + ROWS - 1
    ShowLine i
  Next
End Sub

Sub PutCursor()
  If cy < top Then top = cy : ShowAll
  If cy >= top + ROWS Then top = cy - ROWS + 1 : ShowAll
  StdIO.Locate cx + 1, cy - top + 1
End Sub

' AskName: the status line asks; Return keeps, Esc cancels (an empty name)
Function AskName(ByVal prompt As String Max 20) As String Max 40
  Dim s As String Max 40, k As Integer
  s = name
  Do
    Status prompt + s + "_"
    k = StdIO.GetKey()
    If k = 13 Then Exit Do
    If k = 252 Or k = 27 Then s = "" : Exit Do
    If k = 127 Then
      If Len(s) > 0 Then s = Left$(s, Len(s) - 1)
    ElseIf k >= 32 And k < 127 And Len(s) < 40 Then
      s = s + Chr$(k)
    End If
  Loop
  AskName = s
End Function

' SaveFile: the lines as CR LF text into buf, then the file
Sub SaveFile()
  Dim s As String Max 40, i As Integer, j As Integer, p As Integer
  s = AskName("Save as: ")
  If s = "" Then Status "Not saved" : Exit Sub
  p = 0
  For i = 0 To n - 1
    For j = 1 To Len(ln(i))
      If p < 8190 Then buf(p) = Asc(Mid$(ln(i), j, 1)) : p = p + 1
    Next
    If p < 8190 Then buf(p) = 13 : buf(p + 1) = 10 : p = p + 2
  Next
  r = FileSystem.Save(s, VarPtr(buf(0)), p)
  If r = FileSystem.OK Then name = s : dirty = 0 : Status "Saved " + s + " (" + Str$(p) + " bytes)" Else Status "Save failed (" + Str$(r) + ")"
End Sub

' LoadFile: the file into buf, split at CR / LF into the lines
Sub LoadFile()
  Dim s As String Max 40, i As Integer, p As Integer, t As String Max 80, c As Integer
  s = AskName("Load: ")
  If s = "" Then Status "Not loaded" : Exit Sub
  r = FileSystem.Load(s, VarPtr(buf(0)), 8191)
  If r < 0 Then Status "Load failed (" + Str$(r) + ")" : Exit Sub
  n = 0 : t = ""
  For p = 0 To r - 1
    c = buf(p)
    If c = 10 Or c = 13 Then
      If c = 10 Or (p + 1 < r And buf(p + 1) <> 10) Or p + 1 >= r Then
        If n < MAXL Then ln(n) = t : n = n + 1
        t = ""
      End If
    ElseIf c = 26 Then
      Exit For
    ElseIf Len(t) < WIDE Then
      t = t + Chr$(c)
    End If
  Next
  If Len(t) > 0 And n < MAXL Then ln(n) = t : n = n + 1
  If n = 0 Then n = 1 : ln(0) = ""
  name = s : cx = 0 : cy = 0 : top = 0 : dirty = 0
  StdIO.Cls
  ShowAll
  Status "Loaded " + s + " (" + Str$(n) + " lines)"
End Sub

Sub NewFile()
  n = 1 : ln(0) = "" : cx = 0 : cy = 0 : top = 0 : dirty = 0 : name = ""
  StdIO.Cls
  ShowAll
  Status "New"
End Sub

' ---- start
StdIO.Mode 2
NewFile
Status "EDIT - ^S save  ^L load  ^N new  ^Q quit   (a path: STORE:NAME.TXT is the Pi)"
Do
  PutCursor
  k = StdIO.GetKey()
  If k = 17 Then
    If dirty Then
      Status "Changed - Control + Q again to quit, any other key to stay"
      If StdIO.GetKey() = 17 Then Exit Do
    Else
      Exit Do
    End If
  ElseIf k = 19 Then
    SaveFile
  ElseIf k = 12 Then
    LoadFile
  ElseIf k = 14 Then
    NewFile
  ElseIf k = 240 Then
    If cy > 0 Then cy = cy - 1 : If cx > Len(ln(cy)) Then cx = Len(ln(cy))
  ElseIf k = 241 Then
    If cy < n - 1 Then cy = cy + 1 : If cx > Len(ln(cy)) Then cx = Len(ln(cy))
  ElseIf k = 242 Then
    If cx > 0 Then cx = cx - 1
  ElseIf k = 243 Then
    If cx < Len(ln(cy)) Then cx = cx + 1
  ElseIf k = 1 Then
    cx = 0
  ElseIf k = 5 Then
    cx = Len(ln(cy))
  ElseIf k = 224 Then
    cy = cy + ROWS : If cy >= n Then cy = n - 1
    If cx > Len(ln(cy)) Then cx = Len(ln(cy))
  ElseIf k = 9 Then
    cy = cy - ROWS : If cy < 0 Then cy = 0
    If cx > Len(ln(cy)) Then cx = Len(ln(cy))
  ElseIf k = 13 Then
    If n < MAXL Then
      For i = n To cy + 2 Step -1
        ln(i) = ln(i - 1)
      Next
      ln(cy + 1) = Mid$(ln(cy), cx + 1)
      ln(cy) = Left$(ln(cy), cx)
      n = n + 1 : cy = cy + 1 : cx = 0 : dirty = 1
      ShowAll
    End If
  ElseIf k = 127 Then
    If cx > 0 Then
      ln(cy) = Left$(ln(cy), cx - 1) + Mid$(ln(cy), cx + 1) : cx = cx - 1 : dirty = 1
      ShowLine cy
    ElseIf cy > 0 Then
      If Len(ln(cy - 1)) + Len(ln(cy)) <= WIDE Then
        cx = Len(ln(cy - 1))
        ln(cy - 1) = ln(cy - 1) + ln(cy)
        For i = cy To n - 2
          ln(i) = ln(i + 1)
        Next
        n = n - 1 : cy = cy - 1 : dirty = 1
        ShowAll
      End If
    End If
  ElseIf k = 16 Then
    If cx < Len(ln(cy)) Then
      ln(cy) = Left$(ln(cy), cx) + Mid$(ln(cy), cx + 2) : dirty = 1
      ShowLine cy
    End If
  ElseIf k >= 32 And k < 127 Then
    If Len(ln(cy)) < WIDE Then
      ln(cy) = Left$(ln(cy), cx) + Chr$(k) + Mid$(ln(cy), cx + 1) : cx = cx + 1 : dirty = 1
      ShowLine cy
    End If
  End If
Loop
StdIO.Mode 2
Print "EDIT done."
