' CYBORGOS: a hypervisor for the CPC in NTC BASIC (docs/cyborgos.md, cyborgos-userguide.md).
' Up to 8 slots, each its own 64K bank: a command line, or a CP/M program (.CYB: a cpm build
' with an AMSDOS header) running in the whole bank from #0100. The programs run in turn (the
' one in front gets half the time); each BDOS call is a far call into this program (console,
' keys, version, exit) and characters out are collected in the bank and sent a line at a time;
' an interrupt stops a program and hands the CPU back here. Every slot has its own 80 x 25 text
' page; the slot in front is on the screen.
'   Control + 1-8   that slot to the front (opened as a command line the first time)
'   Control + ESC   the TOP screen (Control + ESC again, or Control + a slot: back)
'   commands        RUN name [slot]  FG slot  PS  TOP  KILL slot  WAIT  CLS  MEM  HELP  QUIT
' Slots: half the extra 64K banks (1 on a 6128, 8 with 1MB or more), taken first.
' cpcfw (the firmware runs; files through AMSDOS). Not yet: CP/M files for the programs, the
' shared drivers.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option NoTurbo                    ' normal mode only (interrupt classes, the clock): one copy of each keyword
Option RomEnable 7                ' AMSDOS, for the programs' files
Option Reserve &H4000, &H4000     ' the window the slots' banks are reached through (built round)
Option Buffer &H8000             ' the library's 2K buffer (files, Memory.Copy)
Const BUF = &HF700                ' a slot's text page in its bank (80 x 25)
Dim ns As Integer, i As Integer, k As Integer, hk As Integer
Dim front As Integer, back As Integer, cur As Integer, quit As Integer, wt As Integer, runs As Integer, pk As Integer
Dim fr As Integer, td As Integer, tt As Integer               ' front's turn next; TOP: last second's start
Dim bk(8) As Integer, sg(8) As Integer, st(8) As Integer       ' bank, RAM setting, state (0 closed, 1 command line, 2 running)
Dim kq(8) As Integer, wp(8) As Integer                         ' key handed to it; the RAM setting with its page 3 in the window
'| Dim cx(8) As Integer, cy(8) As Integer, es(8) As Integer, ey(8) As Integer   (the console state: now in each bank, #F682)
Dim ra(8) As Integer, wk(8) As Integer                         ' the BDOS answer; waiting for a key since (Ticks, -1 not)
Dim tn(8) As Integer, nb(8) As Integer, nc(8) As Integer       ' TOP: turns, BDOS calls, characters this second
Dim lt(8) As Integer, lb(8) As Integer, lc(8) As Integer, ld As Integer   ' ... and in the last whole second (ld ticks)
'| Dim pt(8) As Integer                                        (the page ring's top row: now in the bank, #F684)
'| Dim tp(8) As Long                                           (the text page as a far pointer: Hyp.Con reaches it through wp)
Dim nm(8) As String Max 12, ln(8) As String Max 72
Dim ob As String Max 130
Dim txn As Integer, txs As Integer                             ' TOP: lines written, the slot they go to (0: the screen)
'| Dim blank As String Max 80, row As String Max 80               (Hyp.Con clears and draws rows itself)

Mode 2
Hyp.FontInit
k = Memory.Banks()
ns = k \ 2
If ns < 1 Then ns = k
If ns > 8 Then ns = 8
If ns = 0 Then Print "CyborgOS needs a 6128 or more RAM" : End
For i = 1 To ns
  bk(i) = Memory.AllocBank()
  Memory.SelectPage Memory.BankPage(bk(i), 0)
  sg(i) = Hyp.Setting()
  wp(i) = (sg(i) And &HFFF8) Or 7                ' its page 3 (#C000-#FFFF: OBUF, the console) in the window
'|   tp(i) = Hyp.FarPtr(Memory.BankPage(bk(i), 3), BUF)
  wk(i) = -1
Next
'| blank = Space$(80)
'| row = Space$(80)
ob = Space$(128)
front = 1
OpenSlot 1
Do
  hk = Hot.Take()
  If hk = 9 Then
    If front = 0 Then ToFront back Else ShowTop      ' Control + ESC: TOP, and again: back
  ElseIf hk > 0 And hk <= ns Then
    ToFront hk
  End If
  If pk <> 0 Then
    k = pk : pk = 0
    KeyIn k
  ElseIf wt = 0 Then
    ' a key for the front slot (left in the keyboard buffer while its program has one waiting)
    If front = 0 Or st(front) <> 2 Or kq(front) = 0 Then
      k = Inkey
      If k <> 0 And Hot.Control() = 0 Then KeyIn k
    End If
  ElseIf Running() = 0 Then
    Prompt wt : wt = 0          ' WAIT: nothing runs any more
  End If
  If Ticks - td >= 300 Then Roll
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

' a slot that can have the CPU: running, and not waiting for a key it hasn't got (a program that
' found no key waits until the clock moves on or a key comes)
Function Ready(ByVal t As Integer) As Integer
  Ready = 0
  If t < 1 Then Exit Function
  If st(t) <> 2 Then Exit Function
  If wk(t) = Ticks And kq(t) = 0 Then Exit Function
  Ready = -1
End Function

' the CPU to the next slot: the front one every other turn (half the time), the others in turn
Sub RunNext()
  Dim n As Integer, t As Integer, r As Integer, c As Integer
  fr = Not fr
  If fr Then
    If Ready(front) Then t = front
  End If
  If t = 0 Then
    For n = 1 To ns
      cur = cur + 1
      If cur > ns Then cur = 1
      If cur <> front Then
        If Ready(cur) Then t = cur : Exit For
      End If
    Next
  End If
  If t = 0 Then
    If Ready(front) Then t = front
  End If
  If t = 0 Then
    If Running() = 0 Then Frame     ' nothing to run: wait a frame (a program waiting for a
    Exit Sub                        ' key looks again when the clock moves on)
  End If
  Hyp.Reply ra(t), ra(t)
  r = Hyp.Run(sg(t))
  tn(t) = tn(t) + 1
  If kq(t) <> 0 Then
    If Memory.ReadByte(Far(t, Hyp.KEY)) = 0 Then kq(t) = 0     ' the program took its key
  End If
  c = Hyp.Count()
  If c > 0 Then Collected t, c
  If r = 1 Then Bdos t
End Sub

' a slot's BDOS call: Hyp.Fn() = C, Hyp.Arg() = DE; the answer in ra(t)
Sub Bdos(ByVal t As Integer)
  Dim f As Integer, e As Integer, a As Integer
  f = Hyp.Fn() : e = Hyp.Arg() And 255 : a = 0
  nb(t) = nb(t) + 1
  wk(t) = -1
  Select Case f
    Case 0
      EndTask t
      Exit Sub
    Case 1
      a = kq(t) : kq(t) = 0
      If a <> 0 Then PutC t, a Else wk(t) = Ticks
    Case 2
      PutC t, e
    Case 6
      If e = 255 Then
        a = kq(t) : kq(t) = 0
        If a = 0 Then wk(t) = Ticks
      ElseIf e = 254 Then
        If kq(t) <> 0 Then a = 255 Else wk(t) = Ticks
      Else
        PutC t, e
      End If
    Case 9
      PutMem t, Hyp.Arg()
    Case 11
      If kq(t) <> 0 Then a = 255 Else wk(t) = Ticks
    Case 12
      a = &H22                    ' CP/M 2.2
    Case 25
      a = 0
    Case 128
      ' only the characters (already shown)
    Case Else
      a = 255                     ' not here yet (files)
  End Select
  ra(t) = a
End Sub

' ---- the slots' consoles: each slot's 80 x 25 page is in its bank (#F700, a ring of 25 rows),
' with its column, row, top row and escape state (#F682); the slot in front is on the screen
' too. All of it is Hyp.Con, in Z80 - see the BASIC it replaced, kept below for comparison.

' the n characters slot t collected at OBUF in its bank
Sub Collected(ByVal t As Integer, ByVal n As Integer)
  nc(t) = nc(t) + n
  Hyp.Con wp(t), 0, n, IIf(t = front, 1, 0)       ' straight from the bank: no copy to main RAM
End Sub

' a string to slot t's console (the command line, messages)
Sub PutS(ByVal t As Integer, ByVal s As String)
  ob = Left$(s, 128)
  Hyp.Con wp(t), VarPtr(ob), Len(ob), IIf(t = front, 1, 0)
End Sub

Sub PutLn(ByVal t As Integer, ByVal s As String)
  PutS t, s + Chr$(13) + Chr$(10)
End Sub

' one character (or control code) to slot t's console
Sub PutC(ByVal t As Integer, ByVal c As Integer)
  Hyp.Con wp(t), VarPtr(c), 1, IIf(t = front, 1, 0)   ' (the Integer's low byte is the character)
End Sub

' BDOS 9: the slot's string at address a in its bank, to the "$": fetched 128 bytes at a time
' with Memory.Copy (through the 2K buffer) and written with Hyp.Con (rare: no Z80 of its own)
Sub PutMem(ByVal t As Integer, ByVal a As Integer)
  Dim la As Long, n As Integer, d As Integer, tot As Integer
  la = a
  If la < 0 Then la = la + 65536
  Do
    n = 128
    If la + n > 65536 Then n = 65536 - la
    If n <= 0 Then Exit Sub
    Memory.Copy Far(t, la), CLng(VarPtr(ob)), n
    d = InStr(Left$(ob, n), "$")
    If d > 0 Then n = d - 1
    nc(t) = nc(t) + n
    Hyp.Con wp(t), VarPtr(ob), n, IIf(t = front, 1, 0)
    If d > 0 Then Exit Sub
    la = la + n
    tot = tot + n
  Loop Until tot > 4000
End Sub

' a far pointer to address a of slot t's bank
Function Far(ByVal t As Integer, ByVal a As Integer) As Long
  Far = Hyp.FarPtr(Memory.BankPage(bk(t), ((a And &HC000) \ 16384) And 3), a)
End Function

' slot t's page cleared (ESC E: Hyp.Con clears the page, its state, and the screen if in front)
Sub ClsT(ByVal t As Integer)
  PutS t, Chr$(27) + "E"
End Sub

' slot t to the front: its page drawn
Sub ToFront(ByVal t As Integer)
  front = t
  If st(t) = 0 Then OpenSlot t : Exit Sub
  Cls
  Hyp.Show wp(t)
End Sub

' ---- the BASIC Hyp.Con replaced (2026-10-14), kept for comparison - not compiled.
' Why it went to Z80: it ran for every character a program printed. A line of 62 characters
' cost about 200,000 T here (measured, test LINES): about 4 Memory calls a line (Collected's copy
' out of the bank, Out's copy into the page, NewLine's blank row, and Far()'s Memory.BankPage),
' each turning Long far pointers into a page and an address and switching pages in and out;
' Long sums for every page address (RowA, tp(t) + r * 80); the escape state and the column in
' arrays; a keyword per step and a normal-mode safe point at every branch. Hyp.Con switches the
' slot's page in once and reads the characters where the program left them.
'
'| ' the n characters slot t collected at OBUF in its bank: runs of printable ones written to its
'| ' page (and the screen) at once, the others one by one
'| Sub Collected(ByVal t As Integer, ByVal n As Integer)
'|   nc(t) = nc(t) + n
'|   Memory.Copy Far(t, Hyp.OBUF), CLng(VarPtr(ob)), n
'|   Out t, n
'| End Sub
'|
'| ' the first n characters of ob to slot t's page (and the screen if it is in front): each run of
'| ' printable ones with one Memory.Copy and one Print, the others through PutC
'| Sub Out(ByVal t As Integer, ByVal n As Integer)
'|   Dim p As Integer, j As Integer, q As Integer, c As Integer, w As Integer
'|   p = VarPtr(ob)
'|   j = 0
'|   Do While j < n
'|     c = Peek(p + j)
'|     If c >= 32 And es(t) = 0 Then
'|       w = 80 - cx(t)
'|       If w > n - j Then w = n - j
'|       q = j + Hyp.Printable(p + j, w)
'|       Memory.Copy CLng(p + j), RowA(t, cy(t)) + cx(t), q - j
'|       If t = front Then
'|         Hyp.Text p + j, q - j, cx(t), cy(t)
'|       End If
'|       cx(t) = cx(t) + q - j
'|       If cx(t) >= 80 Then cx(t) = 0 : NewLine t
'|       j = q
'|     Else
'|       PutC t, c
'|       j = j + 1
'|     End If
'|   Loop
'| End Sub
'|
'| ' ---- the text pages: an 80 x 25 page in each slot's bank, the front one on the screen too
'|
'| ' a character to slot t's page (VT52: ESC E clears, ESC Y row col moves; CR, LF, BS)
'| Sub PutC(ByVal t As Integer, ByVal c As Integer)
'|   If es(t) = 1 Then
'|     es(t) = 0
'|     If c = 69 Then ClsT t
'|     If c = 89 Then es(t) = 2
'|     If c = 72 Then cx(t) = 0 : cy(t) = 0
'|   ElseIf es(t) = 2 Then
'|     ey(t) = c - 32 : es(t) = 3
'|   ElseIf es(t) = 3 Then
'|     es(t) = 0
'|     cx(t) = c - 32 : cy(t) = ey(t)
'|     If cx(t) < 0 Or cx(t) > 79 Then cx(t) = 0
'|     If cy(t) < 0 Or cy(t) > 24 Then cy(t) = 0
'|   ElseIf c = 27 Then
'|     es(t) = 1
'|   ElseIf c = 13 Then
'|     cx(t) = 0
'|   ElseIf c = 10 Then
'|     NewLine t
'|   ElseIf c = 8 Then
'|     If cx(t) > 0 Then cx(t) = cx(t) - 1
'|   ElseIf c >= 32 Then
'|     Memory.WriteByte RowA(t, cy(t)) + cx(t), c
'|     If t = front Then
'|       Hyp.Char c, cx(t), cy(t)
'|     End If
'|     cx(t) = cx(t) + 1
'|     If cx(t) = 80 Then cx(t) = 0 : NewLine t
'|   End If
'| End Sub
'|
'| Sub NewLine(ByVal t As Integer)
'|   cy(t) = cy(t) + 1
'|   If cy(t) < 25 Then Exit Sub
'|   cy(t) = 24
'|   pt(t) = pt(t) + 1                ' the page scrolls: its top row moves on, the new last row is cleared
'|   If pt(t) = 25 Then pt(t) = 0
'|   Memory.Copy CLng(VarPtr(blank)), RowA(t, 24), 80
'|   If t = front Then
'|     Locate 1, 25                  ' the screen scrolls: the firmware scrolls when a character
'|     Print                         ' goes below the last line (not at the line feed itself)
'|     Print " ";
'|   End If
'| End Sub
'|
'| Sub PutS(ByVal t As Integer, ByVal s As String)
'|   ob = Left$(s, 128)
'|   Out t, Len(ob)
'| End Sub
'|
'| Sub PutLn(ByVal t As Integer, ByVal s As String)
'|   PutS t, s
'|   PutC t, 13
'|   PutC t, 10
'| End Sub
'|
'| ' BDOS 9: the slot's string at address a in its bank, to the "$": fetched 128 bytes at a time
'| ' with Memory.Copy (through the 2K buffer), each piece written with Out
'| Sub PutMem(ByVal t As Integer, ByVal a As Integer)
'|   Dim la As Long, n As Integer, d As Integer, tot As Integer
'|   la = a
'|   If la < 0 Then la = la + 65536
'|   Do
'|     n = 128
'|     If la + n > 65536 Then n = 65536 - la
'|     If n <= 0 Then Exit Sub
'|     Memory.Copy Far(t, la), CLng(VarPtr(ob)), n
'|     d = InStr(Left$(ob, n), "$")
'|     If d > 0 Then n = d - 1
'|     nc(t) = nc(t) + n
'|     Out t, n
'|     If d > 0 Then Exit Sub
'|     la = la + n
'|     tot = tot + n
'|   Loop Until tot > 4000
'| End Sub
'|
'| ' a far pointer to address a of slot t's bank
'| Function Far(ByVal t As Integer, ByVal a As Integer) As Long
'|   Far = Hyp.FarPtr(Memory.BankPage(bk(t), ((a And &HC000) \ 16384) And 3), a)
'| End Function
'|
'| ' row r (0-24) of slot t's text page: the page is a ring of 25 rows starting at pt(t)
'| Function RowA(ByVal t As Integer, ByVal r As Integer) As Long
'|   r = r + pt(t)
'|   If r >= 25 Then r = r - 25
'|   RowA = tp(t) + r * 80
'| End Function
'|
'| Sub ClsT(ByVal t As Integer)
'|   Dim j As Integer
'|   For j = 0 To 24
'|     Memory.Copy CLng(VarPtr(blank)), tp(t) + j * 80, 80
'|   Next
'|   pt(t) = 0
'|   cx(t) = 0 : cy(t) = 0
'|   If t = front Then Cls
'| End Sub
'|
'| ' slot t to the front: its page drawn
'| Sub ToFront(ByVal t As Integer)
'|   Dim j As Integer
'|   front = t
'|   If st(t) = 0 Then OpenSlot t : Exit Sub
'|   Cls
'|   For j = 0 To 24
'|     Memory.Copy RowA(t, j), CLng(VarPtr(row)), 80
'|     Hyp.Text VarPtr(row), 80, 0, j
'|   Next
'| End Sub

' ---- TOP: every slot, its program and what it did in the last second (Control + ESC, TOP)

Sub ShowTop()
  Dim j As Integer
  If front <> 0 Then back = front
  front = 0
  Cls
  txs = 0
  TopLines back, 1
End Sub

' the TOP lines, to the screen (txs = 0) or slot txs's console: the slot marked with * is mark;
' keys <> 0: the line with the keys
Sub TopLines(ByVal mark As Integer, ByVal keys As Integer)
  Dim j As Integer, s As String Max 14
  txn = 0
  TopAdd "CyborgOS TOP - " + N(ns) + " slots, " + N(Memory.Banks()) + " banks of 64K, " + N(Memory.FreePages()) + " pages free"
  If keys Then TopAdd "Control + ESC: back, Control + 1-" + N(ns) + ": that slot"
  TopAdd ""
  TopAdd "In the last whole second:"
  TopAdd "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S"
  For j = 1 To ns
    If st(j) = 0 Then
      s = "-"
    ElseIf st(j) = 1 Then
      s = "command line"
    ElseIf wk(j) >= 0 Then
      s = "waiting (key)"
    Else
      s = "running"
    End If
    TopAdd " " + Right$(" " + N(j), 2) + IIf(j = mark, "*", " ") + "  " + Left$(s + Space$(15), 15) + Left$(IIf(st(j) = 2, nm(j), "") + Space$(13), 13) + Pad(Rate(lt(j), ld)) + Pad(Rate(lb(j), ld)) + Pad(Rate(lc(j), ld))
  Next
End Sub

Sub TopAdd(ByVal s As String)
  If txs = 0 Then
    ob = s
    Hyp.Say VarPtr(ob), Len(ob), 0, txn          ' straight into screen memory (Print took ~0.7 s)
  Else
    PutLn txs, s
  End If
  txn = txn + 1
End Sub

' each second: this second's counts become the last second's (TOP shows those, once)
Sub Roll()
  Dim j As Integer
  ld = Ticks - td
  td = Ticks
  For j = 1 To ns
    lt(j) = tn(j) : lb(j) = nb(j) : lc(j) = nc(j)
    tn(j) = 0 : nb(j) = 0 : nc(j) = 0
  Next
End Sub

' n right aligned in 9 columns
Function Pad(ByVal v As Integer) As String
  Pad = Right$(Space$(9) + N(v), 9)
End Function

' a count over d ticks (300 a second) as a count a second
Function Rate(ByVal n As Integer, ByVal d As Integer) As Integer
  If n > 1000 Then Rate = n \ (d \ 300 + 1) Else Rate = n * 30 \ (d \ 10 + 1)
End Function

' ---- slots

' the bank image in (page zero, the stubs) - its program and text page are left as they are
Sub Install(ByVal t As Integer)
  Memory.Copy CLng(Hyp.Info(0)), Far(t, 0), Hyp.Info(1)
  Memory.Copy CLng(Hyp.Info(2)), Far(t, Hyp.STUB), Hyp.Info(3)
  Memory.WriteByte Far(t, Hyp.OBUF + 128), 0      ' no characters collected
  Memory.WriteByte Far(t, Hyp.KEY), 0             ' no key waiting
  kq(t) = 0
End Sub

Sub OpenSlot(ByVal t As Integer)
  Install t
  st(t) = 1
  ClsT t
  PutLn t, "CyborgOS slot " + N(t) + " of " + N(ns) + " - Control + 1-" + N(ns) + ", Control + ESC: TOP, HELP"
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

' a key typed: to the program in front, or its command line (none while TOP shows)
Sub KeyIn(ByVal k As Integer)
  Dim t As Integer
  If front = 0 Then
    Exit Sub                      ' TOP stays until Control + ESC or Control + a slot
  End If
  t = front
  If st(t) = 2 Then
    kq(t) = k                                     ' the key into its bank: its BDOS answers from it
    Memory.WriteByte Far(t, Hyp.KEY), k
    Exit Sub
  End If
  If k = 13 Then
    PutLn t, ""
    Command t
    If st(t) = 1 And wt = 0 And front = t Then Prompt t
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
      PutLn t, "RUN name [slot]  FG slot  PS  TOP  KILL slot  WAIT  CLS  MEM  QUIT"
      PutLn t, "Control + 1-" + N(ns) + ": a slot to the front   Control + ESC: TOP (again: back)"
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
    Case "TOP"
      txs = t
      TopLines front, 0                        ' printed into this slot's console, once
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
      PutLn t, N(Memory.Banks()) + " banks of 64K, " + N(ns) + " slots, " + N(Memory.FreePages()) + " pages of 16K free"
    Case "WAIT"
      If Running() > 0 Then wt = t
    Case "QUIT"
      quit = -1
    Case Else
      PutLn t, "? " + c + " (HELP)"
  End Select
End Sub

' RUN: name.CYB loaded into slot s's bank at #0100 (from slot t's command line) and started
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
      If p = 3 Then want = &H3500
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
  Memory.WriteByte Far(s, &HF685), 0             ' no escape sequence left half done
  wk(s) = -1
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
