' RVDU: a remote VDU console for CyborgOS - a screen on a VDU server (tools/vdu: vdu.php) shown on
' this slot's console, live, its keys going back to the screen's writer as events; or the CPC
' writing to a screen (a browser, a 3DS, another CPC watching). Over the network: NET M4 first.
' Build for cpm with cmds/Http.cls and cmds/CybSys.cls; a .CYB.
'   RVDU SERVER url       the server (vdu.php's address: http://host/vdu/vdu.php) - kept in RVDU.CFG
'   RVDU id               the screen, live: its text where its LOCATEs put it (a text display -
'                         graphics and colours left out); a key goes to its writer (KEY n); ESC quits
'   RVDU id ROLL          the screen as a rolling log: its PRINTs a line each, at the bottom
'   RVDU id REPLAY        the screen from its start (line 0), then live
'   RVDU NEW [title]      a new screen: its id and key (the key writes to it)
'   RVDU LIST             the public screens
'   RVDU PUT id key text  a command line to the screen (PRINT Hello, LOCATE 5 5 ...)
'   RVDU TEST id key [n]  the CPC writes a test to the screen - a clock and a count in place, three
'                         touch zones - and shows the events coming back (a tap on QUIT, ESC or n
'                         seconds end it)
' The screen's pointer: the next line wanted. -1 joins it live (from its last MODE), 0 replays it;
' a screen wiped starts again from 0. Lines past the pointer are asked for again at once while
' there are more (drained), else once a second.
Option Explicit
Option Terminal VT52
Const BUF = &H9000                         ' 4K: an answer
Const BMAX = 4096
Dim sv As String Max 120                   ' the server: vdu.php's address
Dim a As String Max 72, w As String Max 12, id As String Max 8
Dim ln As String Max 255, q As String Max 255
Dim g(1999) As Byte                        ' the screen's characters: cols x 25
Dim cols As Integer, cc As Integer, cr As Integer, roll As Integer, part As Integer
Dim wl(7) As Integer, wr(7) As Integer, wt(7) As Integer, wb(7) As Integer
Dim cx(7) As Integer, cy(7) As Integer, sn As Integer
Dim ptr As Long, total As Long, asked As Long, nxt As Long
Dim n As Integer, lp As Integer, i As Integer, k As Integer, r As Integer, t0 As Integer

cc = Peek(&HF687) : cr = Peek(&HF688)       ' (this slot's console: its columns and rows)
If cc < 20 Then cc = 80
If cr < 10 Then cr = 24
a = Trim$(CybSys.Tail())
w = UCase$(Word(a, 0))
sv = ""
n = FileSystem.Load("RVDU.CFG", BUF, 200)
If n > 0 Then
  sv = ""
  For i = 0 To n - 1
    k = Peek(BUF + i)
    If k < 32 Then Exit For
    sv = sv + Chr$(k)
  Next
End If
If w = "SERVER" Then
  q = Word(a, 1)
  If q = "" Then
    If sv = "" Then Print "No server yet: RVDU SERVER http://host/vdu/vdu.php" Else Print "Server: "; sv
  Else
    If UCase$(Left$(q, 7)) <> "HTTP://" Then q = "http://" + q
    For i = 1 To Len(q)
      Poke BUF + i - 1, Asc(Mid$(q, i, 1))
    Next
    Poke BUF + Len(q), 13 : Poke BUF + Len(q) + 1, 10
    r = FileSystem.Save("RVDU.CFG", BUF, Len(q) + 2)
    If r = 0 Then Print "Server: "; q; " (RVDU.CFG)" Else Print "Can't write RVDU.CFG"
  End If
ElseIf w = "" Or w = "HELP" Or w = "?" Then
  Usage
ElseIf sv = "" Then
  Print "No server: RVDU SERVER http://host/vdu/vdu.php first"
ElseIf w = "NEW" Then
  q = Rest(a, 1)
  If q = "" Then q = "CPC screen"
  If Ask("a=new&t=" + Enc(q)) Then
    ln = LineAt()
    Print "Screen "; Word(ln, 1); ", key "; Word(ln, 2); " (the key writes to it: keep it)"
    Print "Watch it: RVDU "; Word(ln, 1); " - or a browser: view.html?s="; Word(ln, 1)
  End If
ElseIf w = "LIST" Then
  If Ask("a=list") Then
    ln = LineAt()
    If Word(ln, 1) = "0" Then Print "No public screens"
    Do While lp < n
      ln = LineAt()
      If ln <> "" Then Print Word(ln, 0); "  "; Left$(Word(ln, 1) + "      ", 7); Rest(ln, 3)
    Loop
  End If
ElseIf w = "PUT" Then
  If Ask("a=put&s=" + Word(a, 1) + "&k=" + Word(a, 2) + "&c=" + Enc(Rest(a, 3))) Then Print LineAt()
ElseIf w = "TEST" Then
  Test Word(a, 1), Word(a, 2), Val(Word(a, 3))
Else
  id = LCase$(Word(a, 0))
  q = UCase$(Word(a, 1))
  View id, (q = "ROLL"), (q = "REPLAY")
End If
End

Sub Usage()
  Print "RVDU - a remote VDU console (a screen on a VDU server; NET M4 first)"
  Print "RVDU SERVER url       the server: vdu.php's address (kept in RVDU.CFG)"
  Print "RVDU id [ROLL|REPLAY] the screen, live (keys go back to it; ESC quits)"
  Print "RVDU NEW [title]      a new screen: its id and key"
  Print "RVDU LIST             the public screens"
  Print "RVDU PUT id key text  a command to it (PRINT Hello ...)"
  Print "RVDU TEST id key [n]  the CPC writes a test to it, the events come back"
  If sv <> "" Then Print "Server: "; sv
End Sub

' word n (0 on) of s ("" none)
Function Word(ByVal s As String, ByVal n As Integer) As String
  Dim k As Integer
  s = Trim$(s)
  Do While n > 0 And s <> ""
    k = InStr(s, " ")
    If k = 0 Then s = "" Else s = Trim$(Mid$(s, k + 1))
    n = n - 1
  Loop
  k = InStr(s, " ")
  If k > 0 Then s = Left$(s, k - 1)
  Word = s
End Function

' s from word n on
Function Rest(ByVal s As String, ByVal n As Integer) As String
  Dim k As Integer
  s = Trim$(s)
  Do While n > 0 And s <> ""
    k = InStr(s, " ")
    If k = 0 Then s = "" Else s = Trim$(Mid$(s, k + 1))
    n = n - 1
  Loop
  Rest = s
End Function

' text for a URL: letters, digits and - _ . kept, the rest %XX
Function Enc(ByVal s As String) As String Max 255
  Dim k As Integer, c As Integer, t As String Max 255
  t = ""
  For k = 1 To Len(s)
    c = Asc(Mid$(s, k, 1))
    If (c >= 48 And c <= 57) Or (c >= 65 And c <= 90) Or (c >= 97 And c <= 122) Or c = 45 Or c = 95 Or c = 46 Then
      t = t + Chr$(c)
    Else
      t = t + "%" + Right$("0" + Hex$(c), 2)
    End If
  Next
  Enc = t
End Function

' the server asked (vdu.php?q): True when it answered "ok ..." (the answer at BUF, n bytes; lp
' its first line) - else why it didn't, printed
Function Ask(ByVal s As String) As Integer
  Ask = 0
  lp = 0
  n = Http.Get(sv + "?" + s, BUF, BMAX)
  If n < 0 Then Print "Network: "; Http.Message() : Exit Function
  If Http.Code() <> 200 Then Print "Server: HTTP"; Http.Code() : Exit Function
  If Peek(BUF) <> 111 Or Peek(BUF + 1) <> 107 Then          ' ("ok")
    ln = LineAt()
    Print "Server: "; ln
    lp = 0
    Exit Function
  End If
  Ask = -1
End Function

' the answer's next line (from lp; lp moved past it)
Function LineAt() As String Max 255
  Dim t As String Max 255, c As Integer
  t = ""
  Do While lp < n
    c = Peek(BUF + lp)
    lp = lp + 1
    If c = 10 Then Exit Do
    If c >= 32 And c < 127 And Len(t) < 255 Then t = t + Chr$(c)
  Loop
  LineAt = t
End Function

' ---- the screen shown

' MODE m: the grid cleared, the streams' windows the whole screen
Sub SetMode(ByVal m As Integer)
  Dim k As Integer
  If m = 0 Then cols = 20 Else If m = 2 Then cols = 80 Else cols = 40
  For k = 0 To 1999
    g(k) = 32
  Next
  For k = 0 To 7
    wl(k) = 1 : wr(k) = cols : wt(k) = 1 : wb(k) = 25 : cx(k) = 1 : cy(k) = 1
  Next
  sn = 0
  If roll = 0 Then Cls
End Sub

' row y (1-25) of the screen, columns l-r, from the grid onto the console
Sub ShowRow(ByVal y As Integer, ByVal l As Integer, ByVal r As Integer)
  Dim t As String Max 80, k As Integer
  If y > cr Then Exit Sub
  If r > cc Then r = cc
  If y = cr And r = cc Then r = r - 1      ' (the console's last place: printing there would scroll it)
  t = ""
  For k = l To r
    t = t + Chr$(g((y - 1) * cols + k - 1))
  Next
  If t <> "" Then Locate l, y : Print t;
End Sub

' the stream's window: cleared
Sub ClearWin()
  Dim y As Integer, x As Integer
  For y = wt(sn) To wb(sn)
    For x = wl(sn) To wr(sn)
      g((y - 1) * cols + x - 1) = 32
    Next
    ShowRow y, wl(sn), wr(sn)
  Next
  cx(sn) = 1 : cy(sn) = 1
End Sub

' the cursor to the next line of the stream's window (scrolled at its foot)
Sub NewLine()
  Dim y As Integer, x As Integer
  cx(sn) = 1
  cy(sn) = cy(sn) + 1
  If cy(sn) > wb(sn) - wt(sn) + 1 Then
    cy(sn) = wb(sn) - wt(sn) + 1
    For y = wt(sn) To wb(sn)
      For x = wl(sn) To wr(sn)
        If y < wb(sn) Then g((y - 1) * cols + x - 1) = g(y * cols + x - 1) Else g((y - 1) * cols + x - 1) = 32
      Next
      ShowRow y, wl(sn), wr(sn)
    Next
  End If
End Sub

' text at the stream's cursor: a run at a time (up to the window's right edge), wrapping
Sub PrintText(ByVal s As String, ByVal nl As Integer)
  Dim k As Integer, m As Integer, x As Integer, y As Integer, j As Integer
  k = 1
  Do While k <= Len(s)
    If cx(sn) > wr(sn) - wl(sn) + 1 Then NewLine
    m = wr(sn) - wl(sn) + 2 - cx(sn)        ' (room on the line)
    If m > Len(s) - k + 1 Then m = Len(s) - k + 1
    x = wl(sn) + cx(sn) - 1
    y = wt(sn) + cy(sn) - 1
    For j = 0 To m - 1
      g((y - 1) * cols + x - 1 + j) = Asc(Mid$(s, k + j, 1))
    Next
    ShowRow y, x, x + m - 1
    cx(sn) = cx(sn) + m
    k = k + m
  Loop
  If nl Then NewLine
End Sub

Function Clamp(ByVal v As Integer, ByVal lo As Integer, ByVal hi As Integer) As Integer
  If v < lo Then v = lo
  If v > hi Then v = hi
  Clamp = v
End Function

' a command line: MODE CLS PRINT LOCATE WINDOW STREAM (the rest - colours, graphics, zones - left
' out: a text display). Rolling: PRINTs alone, a line each
Sub Apply(ByVal s As String)
  Dim c As String Max 8, t As String Max 255, x As Integer, y As Integer
  c = UCase$(Word(s, 0))
  x = 1
  Do While Mid$(s, x, 1) = " "
    x = x + 1
  Loop
  t = Mid$(s, x + 6)                          ' (PRINT's text as it is: its spaces kept)
  If roll Then
    If c = "PRINT" Then
      If Right$(t, 1) = ";" Then
        Print Left$(t, Len(t) - 1); : part = 1
      Else
        Print t : part = 0
      End If
    ElseIf part And (c = "MODE" Or c = "CLS" Or c = "LOCATE" Or c = "WINDOW" Or c = "STREAM") Then
      Print : part = 0
    End If
    Exit Sub
  End If
  If c = "MODE" Then
    SetMode Val(Word(s, 1))
  ElseIf c = "CLS" Then
    ClearWin
  ElseIf c = "PRINT" Then
    If Right$(t, 1) = ";" Then PrintText Left$(t, Len(t) - 1), 0 Else PrintText t, -1
  ElseIf c = "LOCATE" Then
    cx(sn) = Clamp(Val(Word(s, 1)), 1, wr(sn) - wl(sn) + 1)
    cy(sn) = Clamp(Val(Word(s, 2)), 1, wb(sn) - wt(sn) + 1)
  ElseIf c = "STREAM" Then
    sn = Clamp(Val(Word(s, 1)), 0, 7)
  ElseIf c = "WINDOW" Then
    x = Val(Word(s, 1)) : y = Val(Word(s, 2))
    If x > y Then i = x : x = y : y = i
    wl(sn) = Clamp(x, 1, cols) : wr(sn) = Clamp(y, 1, cols)
    x = Val(Word(s, 3)) : y = Val(Word(s, 4))
    If x > y Then i = x : x = y : y = i
    wt(sn) = Clamp(x, 1, 25) : wb(sn) = Clamp(y, 1, 25)
    cx(sn) = 1 : cy(sn) = 1
  End If
End Sub

' the screen, live (or rolling, or replayed): its lines past the pointer drawn; ESC quits, any other
' key goes to its writer
Sub View(ByVal sid As String, ByVal rl As Integer, ByVal rp As Integer)
  Dim ch As Integer, more As Integer, hd As String Max 60
  roll = rl : part = 0
  SetMode 1
  If roll Then Print "RVDU "; sid; " - rolling (ESC quits)"
  ptr = -1
  If rp Then ptr = 0
  Do
    asked = ptr
    more = 0
    If Ask("a=get&s=" + sid + "&n=" + CStr(ptr) + "&m=60&b=3000") Then
      hd = LineAt()                           ' "ok start next total"
      If Val(Word(hd, 1)) <> asked Then       ' (joined, or wiped: from where the server says)
        If roll = 0 Then SetMode 1
      End If
      Do While lp < n
        ln = LineAt()
        If ln <> "" Then Apply ln
      Loop
      nxt = Val(Word(hd, 2))
      total = Val(Word(hd, 3))
      ptr = nxt
      more = (ptr < total)
    Else
      t0 = CybSys.Clock()
      Do While CybSys.Clock() - t0 < 900 And Inkey <> 27
      Loop
    End If
    If more = 0 Then                          ' (a second, the keys looked at)
      t0 = CybSys.Clock()
      ch = 0
      Do While CybSys.Clock() - t0 < 300 And ch = 0
        ch = Inkey
      Loop
      If ch = 27 Then Exit Do
      If ch <> 0 Then
        r = Ask("a=event&s=" + sid + "&e=KEY%20" + CStr(ch))
      End If
    End If
  Loop
  If roll = 0 Then Locate 1, cr
  Print
  Print "RVDU: line "; CStr(ptr); " of "; CStr(total)
End Sub

' ---- the CPC writing

' lines to the screen (\ between them): as few GETs as keep each address under 250 characters -
' the events' count (-1: it failed)
Function Put(ByVal sid As String, ByVal k As String, ByVal s As String) As Long
  Dim t As String Max 255, e As String Max 255, p As String Max 120, j As Integer
  Put = -1
  p = "a=put&s=" + sid + "&k=" + k + "&c="
  t = ""
  Do
    j = InStr(s, "\")
    If j = 0 Then e = Enc(s) : s = "" Else e = Enc(Left$(s, j - 1)) : s = Mid$(s, j + 1)
    If t <> "" And Len(sv) + Len(p) + Len(t) + Len(e) + 4 > 250 Then
      If Ask(p + t) = 0 Then Exit Function
      t = ""
    End If
    If t = "" Then t = e Else t = t + "%0A" + e
  Loop While s <> ""
  If Ask(p + t) Then
    ln = LineAt()
    Put = Val(Word(ln, 2))
  End If
End Function

' the test: a picture, a clock and a count in place, touch zones; the events shown here
Sub Test(ByVal sid As String, ByVal k As String, ByVal secs As Integer)
  Dim ev As Long, got As Long, cnt As Integer, ch As Integer, quit As Integer, t1 As Integer, el As Integer
  Dim hd As String Max 60
  Print "RVDU TEST "; sid; " - ESC ends it"
  If Put(sid, k, "MODE 1\TITLE CPC test\INK 0 0\INK 1 24\INK 2 20\INK 3 6\BORDER 0\PEN 1\PRINT CyborgOS on an Amstrad CPC,\PRINT writing here through its M4.") < 0 Then Exit Sub
  r = Put(sid, k, "PEN 2\LOCATE 1 4\PRINT Tap a button: the CPC shows it.\GPEN 1\FILL 32 64 160 64\GPEN 2\FILL 240 64 160 64\GPEN 3\FILL 448 64 160 64")
  r = Put(sid, k, "PEN 0\PAPER 1\LOCATE 5 20\PRINT  HELLO \PAPER 2\LOCATE 18 20\PRINT  BEEP \PAPER 3\LOCATE 31 20\PRINT  QUIT \PAPER 0\PEN 1")
  ev = Put(sid, k, "ZONE hello 32 64 160 64\ZONE beep 240 64 160 64\ZONE quit 448 64 160 64")
  got = ev                                    ' (the events from before: not this test's)
  t1 = CybSys.Clock()
  el = 0
  Do
    t0 = CybSys.Clock()
    cnt = cnt + 1
    ev = Put(sid, k, "PEN 3\LOCATE 2 8\PRINT Count: " + CStr(cnt) + "   \LOCATE 2 9\PRINT Seconds: " + CStr(el) + "   ")
    If ev < 0 Then Exit Do
    If ev > got Then                          ' (events: what the viewers did)
      If Ask("a=events&s=" + sid + "&k=" + k + "&n=" + CStr(got)) Then
        hd = LineAt()
        Do While lp < n
          ln = LineAt()
          If ln <> "" Then
            Print "Event: "; ln
            If Word(ln, 0) = "TOUCH" And Word(ln, 1) = "quit" Then quit = 1
            q = ln
          End If
        Loop
        got = Val(Word(hd, 2))
        r = Put(sid, k, "PEN 1\LOCATE 2 11\PRINT The CPC got: " + Left$(q + Space$(24), 24))
      End If
    End If
    ch = 0
    Do While CybSys.Clock() - t0 < 300 And ch = 0
      ch = Inkey
    Loop
    el = (CybSys.Clock() - t1) \ 300
    If ch = 27 Then quit = 1
    If secs > 0 And el >= secs Then quit = 1
  Loop Until quit
  r = Put(sid, k, "ZONE OFF\PEN 1\LOCATE 2 13\PRINT The CPC's test has ended.")
  Print "RVDU TEST: "; CStr(cnt); " updates, "; CStr(got); " events"
End Sub
