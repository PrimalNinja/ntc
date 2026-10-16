' NET: the network, in CyborgOS (build for cpm, with Http.cls and CybSys.cls) - an M4 board's
' wifi, used by CyborgOS (its sockets: Http.cls's HTTP GETs - YING, YANG ...)
'   NET              whether it is on, and how
'   NET M4           on, through the M4 (its ROM found by name: M4 BOARD) - claimed (M4 0) by
'                    CyborgOS until NET OFF
'   NET OFF          off (any sockets still open closed)
'   NET GET url      the page fetched: its status, length and text
'   NET TEST url [n] n GETs in a row (5 if not given): each one's time, then the average and
'                    the bytes a second
Option Explicit
Const BUF = &H8000                       ' 16K for a page (NET GET, NET TEST)
Dim a As String Max 200, w As String Max 200, u As String Max 200, t(15) As Byte
Dim i As Integer, j As Integer, r As Integer, n As Integer, k As Integer, c As Integer
Dim t0 As Integer, ms As Long, tot As Long, by As Long

a = CybSys.Tail()                         ' (as typed: an address's small letters kept)
i = InStr(a, " ")
If i = 0 Then w = UCase$(a) : u = "" Else w = UCase$(Left$(a, i - 1)) : u = Trim$(Mid$(a, i + 1))
If w = "" Then
  r = Rom()
  If r = 255 Then Print "No network (NET M4 turns it on through an M4 board)" Else Print "Network: M4 (ROM "; Trim$(Str$(r)); ")"
ElseIf w = "M4" Then
  If Rom() <> 255 Then Print "The network is on already (M4, ROM "; Trim$(Str$(Rom())); ")" : End
  r = CybSys.Held("M4", 0)
  If r > 0 And r < 254 Then Print "The M4 is in use: slot "; Trim$(Str$(r)); " has claimed it (CLAIMS)" : End
  k = -1
  For i = 0 To 127                       ' the ROMs: one named M4 BOARD
    If Peek8(i, &HC000) Then
      If Name(i) = "M4 BOARD" Then k = i : Exit For
    End If
  Next
  If k < 0 Then Print "No M4 board (no ROM named M4 BOARD)" : End
  CybSys.SetWord 2, k
  r = CybSys.Ask(20, 1)
  If r <> 0 Then Print "Not CyborgOS, or it has no network" : End
  Print "Network on: M4 (ROM "; Trim$(Str$(k)); ")"
ElseIf w = "OFF" Then
  r = CybSys.Ask(20, 2)
  Print "Network off"
ElseIf w = "GET" And u <> "" Then
  If Left$(UCase$(u), 7) <> "HTTP://" Then u = "http://" + u
  n = Http.Get(u, BUF, 16384)
  If n < 0 Then Print "Failed: "; Http.Message() : End
  Print "HTTP "; Trim$(Str$(Http.Code())); ", "; Trim$(Str$(n)); " bytes";
  If Http.Url() <> u Then Print " (moved to "; Http.Url(); ")" Else Print
  k = n : If k > 2000 Then k = 2000
  For i = 0 To k - 1
    c = Peek(BUF + i)
    If c = 10 Or c = 13 Or (c >= 32 And c < 127) Then Print Chr$(c); Else Print ".";
  Next
  Print
  If n > k Then Print "("; Trim$(Str$(n - k)); " more bytes)"
ElseIf w = "TEST" And u <> "" Then
  i = InStr(u, " ")
  n = 5
  If i > 0 Then n = Val(Mid$(u, i + 1)) : u = Left$(u, i - 1)
  If n < 1 Then n = 1
  If Left$(UCase$(u), 7) <> "HTTP://" Then u = "http://" + u
  tot = 0 : by = 0
  For j = 1 To n
    t0 = Http.Time()
    k = Http.Get(u, BUF, 16384)
    ms = CLng(Http.Time() - t0) * 10 \ 3
    If k < 0 Then Print Trim$(Str$(j)); ": failed - "; Http.Message() : End
    Print Trim$(Str$(j)); ": HTTP "; Trim$(Str$(Http.Code())); ", "; Trim$(Str$(k)); " bytes, "; Trim$(Str$(ms)); " ms"
    tot = tot + ms : by = by + k
  Next
  If tot < 1 Then tot = 1
  Print "Average "; Trim$(Str$(tot \ n)); " ms a GET, "; Trim$(Str$(by * 1000 \ tot)); " bytes a second"
Else
  Print "NET                the network: on or off"
  Print "NET M4             on, through an M4 board"
  Print "NET OFF            off"
  Print "NET GET url        a page fetched: its status, length, text"
  Print "NET TEST url [n]   n GETs timed (5 if not given)"
End If

' the M4's ROM number (255: the network is off)
Function Rom() As Integer
  Rom = CybSys.Ask(20, 0)
End Function

' 16 bytes of ROM r at address ad into t: True when it is there (a background ROM: type 0-2)
Function Peek8(ByVal r As Integer, ByVal ad As Integer) As Integer
  CybSys.SetWord 2, r
  CybSys.SetWord 4, ad
  CybSys.SetWord 6, VarPtr(t)
  CybSys.SetWord 8, 16
  Peek8 = 0
  If CybSys.Ask(10, 1) <> 0 Then Exit Function
  Peek8 = (t(0) <= 2)
End Function

' ROM r's name (its first command's: the last character + #80)
Function Name(ByVal r As Integer) As String Max 16
  Dim s As String Max 16, q As Integer
  Name = ""
  q = t(4) + t(5) * 256
  If (q And &HC000) <> &HC000 Then Exit Function
  q = Peek8(r, q)
  s = ""
  For q = 0 To 15
    If t(q) = 0 Then Exit For
    s = s + Chr$(t(q) And 127)
    If t(q) >= 128 Then Exit For
  Next
  Name = s
End Function
