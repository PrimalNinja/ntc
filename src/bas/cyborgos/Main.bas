' CYBORGOS: a hypervisor for the CPC in NTC BASIC (docs/cyborgos.md). Up to 8 slots, each its
' own 64K bank: a command line, or a CP/M program (.COM, built for the cpm platform) running in
' the whole bank from #0100. The programs run in turn; each BDOS call is a far call into this
' program (console, keys, version, exit), and an interrupt stops a program and hands the CPU
' back here. Every slot has its own 80 x 25 text page; the slot in front is on the screen.
'   Control + 1-8   that slot to the front (opened as a command line the first time)
'   commands        RUN name [slot]  FG slot  PS  KILL slot  WAIT  CLS  MEM  HELP  QUIT
' Slots: half the extra 64K banks (1 on a 6128, 8 with 1MB or more), taken first.
' cpcfw (the firmware runs; files through AMSDOS). Not yet: CP/M files for the programs, the
' interrupt classes as the scheduler, the shared drivers.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option RomEnable 7                ' AMSDOS, for the programs' files
Option Reserve &H4000, &H4000     ' the window the slots' banks are reached through
Option Buffer &H8000             ' the library's 2K buffer (files, Memory.Copy) out of the program
Const BUF = &HF700                ' a slot's text page in its bank (80 x 25)
Dim ns As Integer, i As Integer, k As Integer, r As Integer, hk As Integer, held As Integer
Dim front As Integer, cur As Integer, quit As Integer, wt As Integer, runs As Integer, pk As Integer
Dim bk(8) As Integer, sg(8) As Integer, st(8) As Integer       ' bank, RAM setting, state (0 closed, 1 command line, 2 running)
Dim cx(8) As Integer, cy(8) As Integer, es(8) As Integer, ey(8) As Integer, kq(8) As Integer
Dim ra(8) As Integer
Dim tp(8) As Long                                              ' the text page (a far pointer)
Dim nm(8) As String Max 12, ln(8) As String Max 72
Dim blank As String Max 80, row As String Max 80

Mode 2
k = Memory.Banks()
ns = k \ 2
If ns < 1 Then ns = k
If ns > 8 Then ns = 8
If ns = 0 Then Print "CyborgOS needs a 6128 or more RAM" : End
For i = 1 To ns
  bk(i) = Memory.AllocBank()
  Memory.SelectPage Memory.BankPage(bk(i), 0)
  sg(i) = Hyp.Setting()
  tp(i) = Hyp.FarPtr(Memory.BankPage(bk(i), 3), BUF)
Next
blank = Space$(80)
row = Space$(80)
front = 1
OpenSlot 1
Do
  hk = HotKey()
  If hk <> 0 And hk <> held Then ToFront hk
  held = hk
  If pk <> 0 Then
    k = pk : pk = 0
    KeyIn k
  ElseIf wt = 0 Then
    ' a key for the front slot (left in the keyboard buffer while its program has one waiting)
    If st(front) <> 2 Or kq(front) = 0 Then
      k = Inkey
      If k <> 0 And hk = 0 Then KeyIn k
    End If
  ElseIf Running() = 0 Then
    Prompt wt : wt = 0          ' WAIT: nothing runs any more
  End If
  RunNext
Loop Until quit
Mode 1
Print "CyborgOS ended, "; runs; " programs ran"
End

' how many slots run a program
Function Running() As Integer
  Dim j As Integer
  For j = 1 To ns
    If st(j) = 2 Then Running = Running + 1
  Next
End Function

' Control + 1-8: 1-8, else 0
Function HotKey() As Integer
  HotKey = 0
  If Keys.Down(Keys.KeyControl) = 0 Then Exit Function
  If Keys.Down(64) Then HotKey = 1
  If Keys.Down(65) Then HotKey = 2
  If Keys.Down(57) Then HotKey = 3
  If Keys.Down(56) Then HotKey = 4
  If Keys.Down(49) Then HotKey = 5
  If Keys.Down(48) Then HotKey = 6
  If Keys.Down(41) Then HotKey = 7
  If Keys.Down(40) Then HotKey = 8
  If HotKey > ns Then HotKey = 0
End Function

' the next running slot gets the CPU until its next BDOS call or interrupt
Sub RunNext()
  Dim n As Integer
  For n = 1 To ns
    cur = cur + 1
    If cur > ns Then cur = 1
    If st(cur) = 2 Then
      Hyp.Reply ra(cur), ra(cur)
      If Hyp.Run(sg(cur)) = 1 Then Bdos cur
      Exit Sub
    End If
  Next
  Frame                           ' nothing running: wait a frame
End Sub

' a slot's BDOS call: Hyp.Fn() = C, Hyp.Arg() = DE; the answer in ra(t)
Sub Bdos(ByVal t As Integer)
  Dim f As Integer, e As Integer, a As Integer
  f = Hyp.Fn() : e = Hyp.Arg() : a = 0
  Select Case f
    Case 0
      EndTask t
      Exit Sub
    Case 1
      a = kq(t) : kq(t) = 0
      If a <> 0 Then PutC t, a
    Case 2
      PutC t, e And 255
    Case 6
      If (e And 255) = 255 Then
        a = kq(t) : kq(t) = 0
      ElseIf (e And 255) = 254 Then
        If kq(t) <> 0 Then a = 255
      Else
        PutC t, e And 255
      End If
    Case 9
      PutMem t, e
    Case 11
      If kq(t) <> 0 Then a = 255
    Case 12
      a = &H22                    ' CP/M 2.2
    Case 25
      a = 0
    Case Else
      a = 255                     ' not here yet (files)
  End Select
  ra(t) = a
End Sub

' ---- the text pages: an 80 x 25 page in each slot's bank, the front one on the screen too

' a character to slot t's page (VT52: ESC E clears, ESC Y row col moves; CR, LF, BS)
Sub PutC(ByVal t As Integer, ByVal c As Integer)
  If es(t) = 1 Then
    es(t) = 0
    If c = 69 Then ClsT t
    If c = 89 Then es(t) = 2
    If c = 72 Then cx(t) = 0 : cy(t) = 0
  ElseIf es(t) = 2 Then
    ey(t) = c - 32 : es(t) = 3
  ElseIf es(t) = 3 Then
    es(t) = 0
    cx(t) = c - 32 : cy(t) = ey(t)
    If cx(t) < 0 Or cx(t) > 79 Then cx(t) = 0
    If cy(t) < 0 Or cy(t) > 24 Then cy(t) = 0
  ElseIf c = 27 Then
    es(t) = 1
  ElseIf c = 13 Then
    cx(t) = 0
  ElseIf c = 10 Then
    NewLine t
  ElseIf c = 8 Then
    If cx(t) > 0 Then cx(t) = cx(t) - 1
  ElseIf c >= 32 Then
    Memory.WriteByte tp(t) + cy(t) * 80 + cx(t), c
    If t = front Then
      Locate cx(t) + 1, cy(t) + 1
      Print Chr$(c);
    End If
    cx(t) = cx(t) + 1
    If cx(t) = 80 Then cx(t) = 0 : NewLine t
  End If
End Sub

Sub NewLine(ByVal t As Integer)
  cy(t) = cy(t) + 1
  If cy(t) < 25 Then Exit Sub
  cy(t) = 24
  Memory.Copy tp(t) + 80, tp(t), 1920
  Memory.Copy CLng(VarPtr(blank)), tp(t) + 1920, 80
  If t = front Then
    Locate 1, 25
    Print                         ' the screen scrolls
  End If
End Sub

Sub PutS(ByVal t As Integer, ByVal s As String)
  Dim j As Integer
  For j = 1 To Len(s)
    PutC t, Asc(Mid$(s, j, 1))
  Next
End Sub

Sub PutLn(ByVal t As Integer, ByVal s As String)
  PutS t, s
  PutC t, 13
  PutC t, 10
End Sub

' BDOS 9: the slot's string at address a in its bank, to the "$"
Sub PutMem(ByVal t As Integer, ByVal a As Integer)
  Dim c As Integer, n As Integer
  Do
    c = Memory.ReadByte(Far(t, a))
    If c = 36 Then Exit Sub
    PutC t, c
    a = a + 1
    n = n + 1
  Loop Until n > 2000
End Sub

' a far pointer to address a of slot t's bank
Function Far(ByVal t As Integer, ByVal a As Integer) As Long
  Far = Hyp.FarPtr(Memory.BankPage(bk(t), ((a And &HC000) \ 16384) And 3), a)
End Function

Sub ClsT(ByVal t As Integer)
  Dim j As Integer
  For j = 0 To 24
    Memory.Copy CLng(VarPtr(blank)), tp(t) + j * 80, 80
  Next
  cx(t) = 0 : cy(t) = 0
  If t = front Then Cls
End Sub

' slot t to the front: its page drawn
Sub ToFront(ByVal t As Integer)
  Dim j As Integer
  front = t
  If st(t) = 0 Then OpenSlot t : Exit Sub
  Cls
  For j = 0 To 24
    Memory.Copy tp(t) + j * 80, CLng(VarPtr(row)), 80
    Locate 1, j + 1
    If j < 24 Then Print row; Else Print Left$(row, 79);
  Next
  Locate cx(t) + 1, cy(t) + 1
End Sub

' ---- slots

' the bank image in (page zero, the stubs) - its program and text page are left as they are
Sub Install(ByVal t As Integer)
  Memory.Copy CLng(Hyp.Info(0)), Far(t, 0), Hyp.Info(1)
  Memory.Copy CLng(Hyp.Info(2)), Far(t, Hyp.STUB), Hyp.Info(3)
End Sub

Sub OpenSlot(ByVal t As Integer)
  Install t
  st(t) = 1
  ClsT t
  PutLn t, "CyborgOS slot " + N(t) + " of " + N(ns) + " - Control + 1-" + N(ns) + ", HELP"
  Prompt t
End Sub

' a number without the space Str$ puts before it
Function N(ByVal v As Integer) As String
  N = Trim$(Str$(v))
End Function

Sub Prompt(ByVal t As Integer)
  ln(t) = ""
  PutS t, N(t) + "> "
End Sub

' a key typed: to the program in front, or its command line
Sub KeyIn(ByVal k As Integer)
  Dim t As Integer
  t = front
  If st(t) = 2 Then kq(t) = k : Exit Sub
  If k = 13 Then
    PutLn t, ""
    Command t
    If st(t) = 1 And wt = 0 Then Prompt t
  ElseIf k = 127 Or k = 8 Then
    If Len(ln(t)) > 0 Then
      ln(t) = Left$(ln(t), Len(ln(t)) - 1)
      PutC t, 8 : PutC t, 32 : PutC t, 8
    End If
  ElseIf k >= 32 And k < 127 And Len(ln(t)) < 70 Then
    ln(t) = ln(t) + Chr$(k)
    PutC t, k
  End If
End Sub

Sub Command(ByVal t As Integer)
  Dim c As String, a As String, b As String, p As Integer, s As Integer
  c = UCase$(Trim$(ln(t)))
  p = InStr(c, " ")
  If p > 0 Then
    a = Trim$(Mid$(c, p + 1))
    c = Left$(c, p - 1)
  End If
  p = InStr(a, " ")
  If p > 0 Then
    b = Trim$(Mid$(a, p + 1))
    a = Left$(a, p - 1)
  End If
  Select Case c
    Case ""
    Case "HELP"
      PutLn t, "RUN name [slot]  FG slot  PS  KILL slot  WAIT  CLS  MEM  QUIT"
    Case "CLS"
      ClsT t
    Case "RUN"
      s = t
      If b <> "" Then s = Val(b)
      If s < 1 Or s > ns Then PutLn t, "no slot" + Str$(s) : Exit Sub
      If st(s) = 2 Then PutLn t, "slot" + Str$(s) + " is busy" : Exit Sub
      StartTask t, s, a
    Case "FG"
      s = Val(a)
      If s >= 1 And s <= ns Then ToFront s Else PutLn t, "no slot " + a
    Case "PS"
      For s = 1 To ns
        If st(s) = 0 Then a = "-" Else If st(s) = 1 Then a = "command line" Else a = nm(s)
        PutLn t, Str$(s) + IIf(s = front, " * ", "   ") + a
      Next
    Case "KILL"
      s = Val(a)
      If s >= 1 And s <= ns And st(s) = 2 Then
        EndTask s
      Else
        PutLn t, "nothing running in slot " + a
      End If
    Case "MEM"
      PutLn t, Str$(Memory.Banks()) + " banks of 64K," + Str$(ns) + " slots," + Str$(Memory.FreePages()) + " pages of 16K free"
    Case "WAIT"
      If Running() > 0 Then wt = t
    Case "QUIT"
      quit = -1
    Case Else
      PutLn t, "? " + c + " (HELP)"
  End Select
End Sub

' RUN: name.COM loaded into slot s's bank at #0100 (from slot t's command line) and started
Sub StartTask(ByVal t As Integer, ByVal s As Integer, ByVal f As String)
  Dim h As Integer, n As Integer, p As Integer, want As Integer
  If f = "" Then PutLn t, "RUN what?" : Exit Sub
  If InStr(f, ".") = 0 Then f = f + ".CYB"
  h = FileSystem.Open(f, FileSystem.ForRead)
  If h < 0 Then PutLn t, f + ": not found" : Exit Sub
  If st(s) = 0 Then OpenSlot s
  If s <> t Then PutLn s, "RUN " + f
  Install s
  p = 0
  Do
    Memory.SelectPage Memory.BankPage(bk(s), p)
    If p = 0 Then
      want = &H3F00
      n = FileSystem.Read(h, &H4100, want)
    Else
      want = &H4000
      If p = 3 Then want = &H3600
      n = FileSystem.Read(h, &H4000, want)
    End If
    p = p + 1
  Loop Until n < want Or p = 4
  FileSystem.Close h
  ' its first stack: ret to #0100, under it #0000 (a ret from the program ends it)
  Memory.WriteWord Far(s, &HFEFC), &H100
  Memory.WriteWord Far(s, &HFEFE), 0
  Memory.WriteWord Far(s, &HFFFE), &HFEFC
  nm(s) = f
  kq(s) = 0
  es(s) = 0
  st(s) = 2
  If s <> t Then PutLn t, f + " runs in slot" + Str$(s)
End Sub

Sub EndTask(ByVal t As Integer)
  Dim c As Integer
  st(t) = 1
  runs = runs + 1
  PutLn t, ""
  PutLn t, "[" + nm(t) + " ended]"
  Prompt t
  c = kq(t) : kq(t) = 0
  If c <> 0 And t = front Then pk = c    ' a key typed for it after its last look: the command line's
End Sub
