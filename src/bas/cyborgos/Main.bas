' CYBORGOS: a hypervisor for the CPC in NTC BASIC (docs/cyborgos.md, cyborgos-userguide.md).
' Up to 16 slots, each its own 64K bank: a command line, or a CP/M program (.CYB: a cpm build
' with an AMSDOS header) running in the whole bank from #0100. The programs run in turn (the
' one in front gets half the time); each BDOS call is a far call into this program (console,
' keys, version, exit) and characters out are collected in the bank and sent a line at a time;
' an interrupt stops a program and hands the CPU back here. Every slot has its own 80 x 25 text
' page; the slot in front is on the screen.
'   Control + 1-8   that slot to the front (opened as a command line the first time); with more
'                   than 8 slots, the same number twice quickly (Control held) is slots 9-16
'   Control + ESC   the TOP screen (Control + ESC again, or Control + a slot: back)
'   commands        RUN name [slot]  FG slot  PS  TOP  KILL slot  RESET [slot]  WAIT  CLS  MEM
'                   HELP  QUIT
' Slots: half the extra 64K banks (1 on a 6128, 8 with 1MB, 16 with 2MB or more), taken first.
' cpcfw (the firmware runs; files through AMSDOS). Not yet: CP/M files for the programs, the
' shared drivers.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option NoTurbo                    ' normal mode only (interrupt classes, the clock): one copy of each keyword
Option RomEnable 7                ' the disc ROM (AMSDOS, or a replacement such as UniDOS), for files
Option NoRomDisc                  ' no ROMDISC (volume R): its FileSystem code (1.1K) left out
Option Reserve &H4000, &H4000     ' the window the slots' banks are reached through (built round)
Option Buffer &H8000             ' the library's 2K buffer (files, Memory.Copy)
Option Memory CPCExpansion 193    ' 48 banks (192 pages + main RAM) at most: the page tables (3 bytes a
                                  ' page) must fit between the program and the firmware - 16 slots and
                                  ' 32 banks over on 3MB or more (all 64 banks of 4MB no longer fit)
Const BUF = &HF700                ' a slot's text page in its bank (80 x 25)
Dim ns As Integer, i As Integer, k As Integer, hk As Integer
Dim front As Integer, back As Integer, cur As Integer, quit As Integer, wt As Integer, runs As Integer, pk As Integer
Dim fr As Integer, td As Integer, tt As Integer               ' front's turn next; TOP: last second's start
Dim bk(16) As Integer, sg(16) As Integer, st(16) As Integer       ' bank, RAM setting, state (0 closed, 1 command line, 2 running)
Dim kq(16) As Integer, wp(16) As Integer                         ' key handed to it; the RAM setting with its page 3 in the window
#If NTC_LIBRARY_ROM Then
#Else
Dim dv(16) As Integer                                           ' its drive (CD: the letter's code; 0: A)
#End If
'| Dim cx(16) As Integer, cy(8) As Integer, es(8) As Integer, ey(8) As Integer   (the console state: now in each bank, #F682)
Dim ra(16) As Integer, wk(16) As Integer                         ' the BDOS answer; waiting for a key since (Ticks, -1 not)
Dim tn(16) As Integer, nb(16) As Integer, nc(16) As Integer       ' TOP: turns, BDOS calls, characters this second
Dim lt(16) As Integer, lb(16) As Integer, lc(16) As Integer, ld As Integer   ' ... and in the last whole second (ld ticks)
'| Dim pt(8) As Integer                                        (the page ring's top row: now in the bank, #F684)
'| Dim tp(8) As Long                                           (the text page as a far pointer: Hyp.Con reaches it through wp)
'| Dim nm(16) As String Max 12        (each program's name: now in its bank, NMLEN / NMBUF - 221
'|                                   bytes the RAM below AMSDOS's no longer had room for)
'| Dim ln(16) As String Max 72      (each slot's command line: now in its bank, LNLEN / LNBUF - 16 of
'|                                  them were 1.2K, more than the Library: ROM build has room for)
Const LNLEN = &HF68F              ' in a slot's bank: the length of the command line being typed
Const LNBUF = &HF690              ' ... and its characters (70 at most, to #F6D5)
Const NMLEN = &HF6D8              ' in a slot's bank: the length of the name of the program it runs
Const NMBUF = &HF6D9              ' ... and its characters (12 at most)
Dim ob As String Max 130
Dim en As String Max 60           ' ... the name looked for; a disc name (Ent.DiscName); a DIR line
Dim dn As String Max 12           ' ... the file of entries looked in
Dim a As String, b As String      ' a command's first and second words (the rest of the line)
Dim txn As Integer, txs As Integer                             ' TOP: lines written, the slot they go to (0: the screen)
'| Dim blank As String Max 80, row As String Max 80               (Hyp.Con clears and draws rows itself)

Mode 2
Hyp.FontInit
Hyp.Vdu 0                         ' the firmware's text off (TXT VDU DISABLE): AMSDOS says "NAME.CYB not
                                  ' found" when RUN looks for files, on top of the console (Con draws it).
                                  ' Jumpblock calls only - no ROM's own RAM (AMSDOS's message flag at #BE78
                                  ' is where one ROM keeps it, not every model's)
k = Memory.Banks()
ns = k \ 2
If ns < 1 Then ns = k
If ns > 16 Then ns = 16
Hot.Slots ns                                    ' (more than 8: Control + a number twice is 9-16)
If ns = 0 Then Hyp.Vdu 1 : Print "CyborgOS needs a 6128 or more RAM" : End
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
  If hk = Hot.TOPKEY Then
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
Hyp.Vdu 1
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
  If keys Then TopAdd "Control + ESC: back, " + SK() + ": that slot"
  TopAdd ""
  TopAdd "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (the last second)"
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
    en = ""
    If st(j) = 2 Then GetNm j
    TopAdd " " + Right$(" " + N(j), 2) + IIf(j = mark, "*", " ") + "  " + Left$(s + Space$(15), 15) + Left$(en + Space$(13), 13) + Pad(Rate(lt(j), ld)) + Pad(Rate(lb(j), ld)) + Pad(Rate(lc(j), ld))
  Next
  TopAdd ""                                      ' the memory: 3 rows of 80 pages at most (193 pages
  TopAdd N(Memory.RamSize()) + " KB of total memory - a character a 16K page (B slot, - free):"
  For j = 1 To Memory.Pages() Step 80            ' with 4MB): 25 rows with 16 slots and the keys
    TopAdd Memory.Map(j, 80)
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

' RESET: the slot as before its command line was first opened - its program (if any) stopped,
' nothing kept. The slot in front (the one typing it) opens again at once, as new
Sub ResetSlot(ByVal s As Integer)
  st(s) = 0
#If NTC_LIBRARY_ROM Then
#Else
  dv(s) = 0
#End If
  kq(s) = 0
  wk(s) = -1
  tn(s) = 0 : nb(s) = 0 : nc(s) = 0
  lt(s) = 0 : lb(s) = 0 : lc(s) = 0
  If s = front Then
    Install s
    st(s) = 1
    ClsT s
    PutLn s, "CyborgOS slot " + N(s) + " of " + N(ns) + " - " + SK() + ", Control + ESC: TOP, HELP"
    PutLn s, ""                   ' a blank line under the title
  End If                          ' (the prompt: the command line puts it after the command)
End Sub

Sub OpenSlot(ByVal t As Integer)
  Install t
  st(t) = 1
  ClsT t
  PutLn t, "CyborgOS slot " + N(t) + " of " + N(ns) + " - " + SK() + ", Control + ESC: TOP, HELP"
  PutLn t, ""                     ' a blank line under the title
  Prompt t
End Sub

' the keys for the slots, as the help lines say them
Function SK() As String
  If ns <= 8 Then SK = "Control + 1-" + N(ns) Else SK = "Control + 1-8 (twice: 9-" + N(ns) + ")"
End Function

' a number without the space Str$ puts before it
' en = the name of the program slot t runs (from its bank; a String function's result would
' take 256 bytes)
Sub GetNm(ByVal t As Integer)
  Dim n As Integer
  n = Memory.ReadByte(Far(t, NMLEN))
  en = Space$(12)
  Memory.Copy Far(t, NMBUF), CLng(VarPtr(en)), n
  en = Left$(en, n)
End Sub

Function N(ByVal v As Integer) As String
  N = Trim$(Str$(v))
End Function

Sub Prompt(ByVal t As Integer)
  Memory.WriteByte Far(t, LNLEN), 0                ' an empty command line
  PutS t, N(t) + "> "
End Sub

' a key typed: to the program in front, or its command line (none while TOP shows)
Sub KeyIn(ByVal k As Integer)
  Dim t As Integer, n As Integer
  If front = 0 Then
    Exit Sub                      ' TOP stays until Control + ESC or Control + a slot
  End If
  t = front
  If st(t) = 2 Then
    kq(t) = k                                     ' the key into its bank: its BDOS answers from it
    Memory.WriteByte Far(t, Hyp.KEY), k
    Exit Sub
  End If
  n = Memory.ReadByte(Far(t, LNLEN))             ' the command line so far (in the slot's bank)
  If k = 13 Then
    PutLn t, ""
    Command t
    If st(t) = 1 And wt = 0 And front = t Then Prompt t
  ElseIf k = 127 Or k = 8 Then
    If n > 0 Then
      Memory.WriteByte Far(t, LNLEN), n - 1
      PutC t, 8 : PutC t, 32 : PutC t, 8
    End If
  ElseIf k >= 32 And k < 127 And n < 70 Then
    Memory.WriteByte Far(t, LNBUF + n), k
    Memory.WriteByte Far(t, LNLEN), n + 1
    PutC t, k
  End If
End Sub

Sub Command(ByVal t As Integer)
  Dim c As String, p As Integer, s As Integer
  p = Memory.ReadByte(Far(t, LNLEN))              ' the command line, from the slot's bank
  Memory.Copy Far(t, LNBUF), CLng(VarPtr(ob)), p
  c = UCase$(Trim$(Left$(ob, p)))
  a = "" : b = ""
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
#If NTC_LIBRARY_ROM Then
#Else
  If c = "RUN" Or c = "DIR" Then        ' the slot's own drive (CD), as CP/M has one each
    If dv(t) = 0 Then dv(t) = 65                     ' (A to start with)
    p = Hyp.Drive(dv(t))
  End If
#End If
  Select Case c
    Case ""
    Case "HELP"
      PutLn t, "RUN name [slot]  FG slot  PS  TOP  KILL slot  RESET [slot]  WAIT  CLS  MEM  QUIT"
#If NTC_LIBRARY_ROM Then
#Else
      PutLn t, "DIR: the programs in FILES.DIR   CD [drive]: this slot's drive"
#End If
      PutLn t, SK() + ": a slot to the front   Control + ESC: TOP"
    Case "CLS"
      ClsT t
    Case "RUN"
      s = t
      If b <> "" Then s = Val(b)
      If s < 1 Or s > ns Then PutLn t, "no slot" + Str$(s) : Exit Sub
      If st(s) = 2 Then PutLn t, "slot" + Str$(s) + " is busy" : Exit Sub
      StartTask t, s
    Case "FG"
      s = Val(a)
      If s >= 1 And s <= ns Then ToFront s Else PutLn t, "no slot " + a
    Case "TOP"
      txs = t
      TopLines front, 0                        ' printed into this slot's console, once
    Case "PS"
      For s = 1 To ns
        If st(s) = 0 Then a = "-" Else If st(s) = 1 Then a = "command line" Else GetNm s : a = en
        PutLn t, Right$("  " + N(s), 3) + IIf(s = front, " * ", "   ") + a
      Next
    Case "KILL"
      s = Val(a)
      If s >= 1 And s <= ns And st(s) = 2 Then
        EndTask s
      Else
        PutLn t, "nothing running in slot " + a
      End If
    Case "RESET"
      If a = "" Then s = t Else s = Val(a)
      If s < 1 Or s > ns Then
        PutLn t, "no slot " + a
      Else
        ResetSlot s
        If s <> t Then PutLn t, "slot " + N(s) + " reset"
      End If
    Case "CD"
#If NTC_LIBRARY_ROM Then
      PutLn t, "CD: not in this build (CYBORGOS without Library: ROM has it)"
#Else
      ChDrive t
#End If
    Case "DIR"
#If NTC_LIBRARY_ROM Then
      PutLn t, "DIR: not in this build (CYBORGOS without Library: ROM has it)"
#Else
      DirList t
#End If
    Case "MEM"
      PutLn t, N(ns) + " slots, " + N(Memory.Banks()) + " banks of 64K, " + N(Memory.FreePages()) + " pages free"
    Case "WAIT"
      If Running() > 0 Then wt = t
    Case "QUIT"
      quit = -1
    Case Else
      PutLn t, "? " + c + " (HELP)"
  End Select
End Sub

' RUN a: a program loaded into slot s's bank at #0100 (from slot t's command line) and started.
'   name.CYB   a cpm build with an AMSDOS header (the header gives its length)
'   name.COM   a CP/M program with no header: AMSDOS reads it as text, to the first #1A, and
'              doesn't know its length - so it runs only when FILES.DIR (or name.HDR) has an
'              entry for it (its length; the entry is also the say-so that it runs here). Read
'              ForReadRaw: a #1A in it is a byte, not the end
'   name       name.CYB, else name.COM, else a FILES.DIR entry whose long name is name
' The entries (FILES.DIR, name.HDR: 64 bytes each) stand in until CyborgOS reads the disc's
' own directory (record counts, random access); see docs/cyborgos.md
Sub StartTask(ByVal t As Integer, ByVal s As Integer)
  Dim h As Integer, n As Integer, p As Integer, want As Integer, rest As Integer, com As Integer
  If a = "" Then PutLn t, "RUN what?" : Exit Sub
  h = -1
  If InStr(a, ".") = 0 Then
    h = FileSystem.Open(a + ".CYB", FileSystem.ForRead)
    If h >= 0 Then a = a + ".CYB" Else com = -1
  ElseIf Right$(a, 4) = ".COM" Then
    com = -1
  Else
    h = FileSystem.Open(a, FileSystem.ForRead)
  End If
  rest = &HF400                                  ' #0100 to the stub (#F500)
  If com Then
    Memory.SelectPage Memory.BankPage(bk(s), 1)  ' the entry read into slot s's #4000 (loaded over later)
    en = a
    n = FindCom()
    If n = 0 Then PutLn t, a + ": not found" : Exit Sub
    rest = n                                     ' (an Integer used unsigned: up to #F400)
    en = Space$(12)
    a = Left$(en, Ent.DiscName(&H4000, VarPtr(en)))
    h = FileSystem.Open(a, FileSystem.ForReadRaw)
  End If
  If h < 0 Then PutLn t, a + ": not found" : Exit Sub
  If st(s) = 0 Then OpenSlot s
  If s <> t Then PutLn s, "RUN " + a
  Install s
  p = 0
  Do
    Memory.SelectPage Memory.BankPage(bk(s), p)
    If p = 0 Then want = &H3F00 Else want = &H4000
    If p = 3 Then want = &H3500
    If rest >= 0 And want > rest Then want = rest   ' (rest unsigned: below 0 is over 32767)
    If p = 0 Then n = FileSystem.Read(h, &H4100, want) Else n = FileSystem.Read(h, &H4000, want)
    rest = rest - n
    p = p + 1
  Loop Until n < want Or rest = 0 Or p = 4
  FileSystem.Close h
  If com And rest > 0 Then PutLn t, a + ": shorter than FILES.DIR says" : Exit Sub
  ' its first stack: ret to #0100, under it #0000 (a ret from the program ends it)
  Memory.WriteWord Far(s, &HFEFC), &H100
  Memory.WriteWord Far(s, &HFEFE), 0
  Memory.WriteWord Far(s, &HFFFE), &HFEFC
  Memory.WriteByte Far(s, NMLEN), Len(a)
  Memory.Copy CLng(VarPtr(a)), Far(s, NMBUF), Len(a)
  kq(s) = 0
  Memory.WriteByte Far(s, &HF685), 0             ' no escape sequence rest half done
  wk(s) = -1
  st(s) = 2
  If s <> t Then PutLn t, a + " runs in slot" + Str$(s)
End Sub

' ---- FILES.DIR / name.HDR: 64 byte entries (until the disc's own directory is read)
'   0      1 a file (0 unused; 2 a virtual directory - not yet)
'   1-11   its name on the disc, CP/M style: 8 + 3, capitals, spaces after
'   12     what it is: 1 a CP/M .COM, 0 other
'   13     flags (bit 0: it runs here)
'   14-15  its length in bytes
'   16-17  load address, 18-19 exec address (#0100 for a .COM)
'   20     the virtual directory it is in (0: the top; not yet), 21 a directory's own number
'   22-23  (nothing yet)
'   24-61  its long name (38 characters at most, 0 after)
'   62-63  the sum of bytes 0-61 (a damaged entry is not used)
' name.HDR holds the entry for name.COM alone; FILES.DIR any number. Either may be a binary file
' (SAVE "FILES.DIR",B,...) or have no header: they are read ForReadRaw.

#If NTC_LIBRARY_ROM Then
#Else
' CD [letter]: this slot's drive - the disc system's |letter command (AMSDOS's A, B; UniDOS's,
' the M4's ...), kept only when it is there and the drive has a FILES.DIR. RUN and DIR
' then use it, each slot its own, as CP/M has. CD alone: the slot's drive
Sub ChDrive(ByVal t As Integer)
  Dim r As Integer, h As Integer
  If dv(t) = 0 Then dv(t) = 65
  If a <> "" Then
    h = -1
    If Hyp.Drive(Asc(a)) Then h = FileSystem.Open("FILES.DIR", FileSystem.ForReadRaw)
    If h < 0 Then
      PutLn t, Left$(a, 1) + ": no such drive, or no FILES.DIR there"
    Else
      r = FileSystem.Close(h)
      dv(t) = Asc(a)
    End If
    r = Hyp.Drive(dv(t))
  End If
  PutLn t, "drive " + Chr$(dv(t))
End Sub
#End If

#If NTC_LIBRARY_ROM Then
#Else
' DIR: FILES.DIR's entries listed (disc name, length, long name) - until CyborgOS reads the
' disc's own directory. Each entry read into slot t's #4000 (nothing there for a command line);
' the page is put back in the window before each read (PutLn's console moves it). Not in the
' Library: ROM build (as ADD: no room below #4000 for the Memory class's tables with it)
Sub DirList(ByVal t As Integer)
  Dim h As Integer, r As Integer, k As Integer
  h = FileSystem.Open("FILES.DIR", FileSystem.ForReadRaw)
  If h < 0 Then PutLn t, "no FILES.DIR" : Exit Sub
  k = 0
  Do
    Memory.SelectPage Memory.BankPage(bk(t), 1)
    If FileSystem.Read(h, &H4000, 64) < 64 Then Exit Do
    en = Space$(60)
    r = Ent.Show(&H4000, VarPtr(en))
    If r > 0 Then PutLn t, Left$(en, r) : k = k + 1
  Loop
  r = FileSystem.Close(h)
  PutLn t, N(k) + " in FILES.DIR"
End Sub
#End If

' en's entry (read at #4000: a bank's page in the window): from NAME.HDR, else FILES.DIR (by its disc name, or its long name):
' its length, or 0
Function FindCom() As Integer
  Dim r As Integer
  Ent.SetName VarPtr(en), Len(en)
  dn = en
  r = InStr(dn, ".")
  If r > 0 Then dn = Left$(dn, r - 1)
  r = 0
  If Len(dn) <= 8 Then dn = dn + ".HDR" : r = FindEnt()      ' (a longer name: only a long name)
  If r = 0 Then dn = "FILES.DIR" : r = FindEnt()
  FindCom = r
End Function

' the entry in file dn for EntSet's name (or with the long name en), at #4000: its length, or 0
Function FindEnt() As Integer
  Dim h As Integer, r As Integer
  r = 0
  h = FileSystem.Open(dn, FileSystem.ForReadRaw)
  If h >= 0 Then
    Do While FileSystem.Read(h, &H4000, 64) = 64
      r = Ent.Length(&H4000, VarPtr(en), Len(en))
      If r <> 0 Then Exit Do
    Loop
    FileSystem.Close h
  End If
  FindEnt = r
End Function


Sub EndTask(ByVal t As Integer)
  Dim c As Integer
  st(t) = 1
  runs = runs + 1
  PutLn t, ""
  GetNm t
  PutLn t, "[" + en + " ended]"
  Prompt t
  c = kq(t) : kq(t) = 0
  If c <> 0 And t = front Then pk = c    ' a key typed for it after its last look: the command line's
End Sub
