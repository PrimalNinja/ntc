' CYBORGOS (320K): a hypervisor for the CPC in NTC BASIC (docs/cyborgos.md, cyborgos-userguide.md).
' Up to 20 slots, each its own 64K bank: a command line, or a CP/M program (.CYB: a cpm build
' with an AMSDOS header) running in the whole bank from #0100. The programs run in turn (the
' one in front gets half the time); each BDOS call is a far call into this program (console,
' keys, files, exit) and characters out are collected in the bank and sent a line at a time;
' an interrupt stops a program and hands the CPU back here. Every slot has its own 80 x 25 text
' page; the slot in front is on the screen.
'   Control + 1-9, 0  that slot to the front (opened as a command line the first time); with
'                     more than 10 slots, the same number twice quickly (Control held) is 11-20
'   Control + ESC     the TOP screen (Control + ESC again, or Control + a slot: back)
'   commands          RUN, FG, PS, TOP, KILL, RESET, WAIT, CLS, MEM, DIR, CD, QUIT; any other
'                     name runs that program (HELP, COPY, ERA, TYPE, PREP, RENAME are on the disc)
' Needs 320K or more (a 256K expansion): the first expansion bank's pages are the hypervisor's
' (C4 first: the disc buffers), main RAM's own #4000-#7FFF is kept (a second screen).
' Slots: half the extra 64K banks (2 with 256K, 4 with 512K, 8 with 1MB, 16 with 2MB, 20 with
' 3MB or more), taken after the hypervisor's page. cpcfw (the firmware runs; files through the
' disc ROM).
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option NoTurbo                    ' normal mode only (interrupt classes, the clock): one copy of each keyword
Option RomEnable All              ' every background ROM (the disc ROM in 7 - AMSDOS, UniDOS ... - and any
                                  ' others: an IDE / SD interface's, the M4's), for files
Option Reserve &H4000, &H4000     ' the window the slots' banks are reached through (built round)
Option Buffer Size 128            ' Memory.Copy's buffer: 128 bytes a go (PRIMAL's copy buffer) - FileSystem,
                                  ' which needs 2K, isn't used (Hyp.FileCall)
#If NTC_LIBRARY_ROM Then
Option Memory CPCExpansion 33     ' 8 banks (32 pages + main RAM) at most: the page tables (3 bytes a
                                  ' page) must fit between the program and the ROM's RAM (#8800) - 4 slots
#Else
Option Memory CPCExpansion 257    ' 64 banks (256 pages + main RAM): all of a 4MB expansion - the page
                                  ' tables (3 bytes a page) between the program and the firmware
#End If
Const BUF = &HF700                ' a slot's text page in its bank (80 x 25)
Const TURNS = 3                   ' a slot's turn: up to 3 of Hyp.Run's slices (6 interrupts each: 1/50 s), unless it calls the BDOS
Dim ns As Integer, i As Integer, k As Integer, hk As Integer, hp As Integer   ' hp: the hypervisor's page
Dim fs As Long                    ' a far address kept (Far: one result for all its calls)
#If NTC_LIBRARY_ROM Then
#Else
Dim dp As Integer                 ' the RAM discs' driver's page (RAMDISC.CYB's; 0: none yet)
Dim bd As Integer                 ' the boot drive (A, or "CYB d" at #BE80): the slots' first drive, CYBORGOS.Z
#End If
Dim front As Integer, back As Integer, cur As Integer, quit As Integer, wt As Integer, runs As Integer, pk As Integer
Dim fr As Integer, td As Integer, tt As Integer               ' front's turn next; TOP: last second's start
#If NTC_LIBRARY_ROM Then
Const MAXS = 4                    ' the most slots (Library: ROM: 8 banks of tables - 4 slots)
#Else
Const MAXS = 20                   ' the most slots (Control + 1-9, 0; twice: 11-20)
#End If
Dim bk(MAXS) As Integer, sg(MAXS) As Integer, st(MAXS) As Integer       ' bank, RAM setting, state (0 closed, 1 command line, 2 running)
Dim kq(MAXS) As Integer, wp(MAXS) As Integer                         ' key handed to it; the RAM setting with its page 3 in the window
Dim dm(MAXS) As Integer                                           ' its DMA address (CP/M's record buffer, BDOS 26)
#If NTC_LIBRARY_ROM Then
#Else
Dim dv(MAXS) As Integer                                           ' its drive (CD: the letter's code; 0: A)
#End If
'| Dim cx(16) As Integer, cy(8) As Integer, es(8) As Integer, ey(8) As Integer   (the console state: now in each bank, #F682)
Dim ra(MAXS) As Integer, wk(MAXS) As Integer                         ' the BDOS answer; waiting for a key since (Ticks, -1 not)
Dim tn(MAXS) As Integer, nb(MAXS) As Integer, nc(MAXS) As Integer       ' TOP: turns, BDOS calls, characters this second
Dim lt(MAXS) As Integer, lb(MAXS) As Integer, lc(MAXS) As Integer, ld As Integer   ' ... and in the last whole second (ld ticks)
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
Const STORE = &HFF00              ' in a slot's bank: its store's page numbers (32, 0: none)
Dim ob As String Max 82           ' the command line; the longest string here sets every string parameter,
                                  ' function result and temp's size: 82 is a screen line + CR LF
Dim rb(127) As Byte               ' a record (Hyp.FileCall's buf, the RAM disc driver's copies; FILES.DIR entries)
Dim en As String Max 60           ' ... the name looked for; a disc name (Ent.DiscName); a DIR line
Dim dn As String Max 16           ' ... the file opened (Hyp.FileCall 100)
Dim a As String Max 72, b As String Max 72   ' a command's first word after the command, the rest of the line
                                  ' (RUN and a program run by its name: the program's command tail)
Dim bare As Integer               ' True: a program run by its name alone (not found: "? NAME (HELP)")
Dim txn As Integer, txs As Integer                             ' TOP: lines written, the slot they go to (0: the screen)
'| Dim blank As String Max 80, row As String Max 80               (Hyp.Con clears and draws rows itself)

Mode 2
Hyp.Vdu 0                         ' the firmware's text off (TXT VDU DISABLE): AMSDOS says "NAME.CYB not
                                  ' found" when RUN looks for files, on top of the console (Con draws it).
                                  ' Jumpblock calls only - no ROM's own RAM (AMSDOS's message flag at #BE78
                                  ' is where one ROM keeps it, not every model's)
k = Memory.Banks()
If k < 4 Then Hyp.Vdu 1 : Print "CyborgOS needs 320K (a 256K expansion) or more" : End
ns = k \ 2                                      ' half the banks are slots (the first bank never:
If ns > MAXS Then ns = MAXS                     ' its pages are the hypervisor's)
Hot.Slots ns                                    ' (more than 10: Control + a number twice is 11-20)
' the hypervisor's own 16K pages: the first expansion bank's, C4 first (C5 ... as it grows),
' taken before any slot's bank - main RAM's own #4000-#7FFF (page 1) is kept, unused (a second
' screen): taken first, so that nothing else gets it (RAM discs take free pages)
i = Memory.AllocPage(Memory.TypeUser)           ' (page 1)
hp = Memory.AllocPage(Memory.TypeUser)          ' bank 1's page 0 (C4): the disc buffers ...
Memory.SelectPage hp
Hyp.UsePage                                     ' (its RAM setting, for Hyp.FileCall)
Hyp.FontInit                                    ' (the font into it, at #5000)
#If NTC_LIBRARY_ROM Then
#Else
i = Memory.AllocPage(Memory.TypeUser)           ' bank 1's page 1 (C5): the services (Hyp.Svc: BDOS
Memory.SelectPage i                             ' 131 ops 10-15), out of main RAM
Hyp.UseSvc
Hyp.SvcVars VarPtr(st), VarPtr(sg), VarPtr(ns), VarPtr(front), VarPtr(dp)
#End If
i = Hyp.FileCall(99, 0, 0, 0, 0, 0, VarPtr(rb))  ' (the bank image and FileCall's page code into it,
                                                ' from #5300: from main RAM's #4000-#7FFF, where the
                                                ' file put them - free from now on)
#If NTC_LIBRARY_ROM Then
#Else
i = Hyp.Svc(0, 0, 0, VarPtr(rb))                ' (the services' code into the service page: #6000 on)
#End If
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
ob = Space$(82)
front = 1
OpenSlot 1
' CyborgOS's command line at #BE80 (it outlives a reset; CYBORGOS.BAS puts it there): "CYB d" - the
' boot drive -, then words: KEYREP n (the keys' repeat n times slower: WinAPE at 1000% wants 10)
a = ""
If Peek(&HBE80) = 67 And Peek(&HBE81) = 89 And Peek(&HBE82) = 66 And Peek(&HBE83) = 32 Then
  i = &HBE84
  Do While Peek(i) <> 0 And i < &HBEC0
    a = a + Chr$(Peek(i))
    i = i + 1
  Loop
  a = UCase$(a)
End If
i = InStr(a, " KEYREP ")
If i > 0 Then
  k = Val(Mid$(a, i + 8))
  If k > 1 Then Hyp.KeyRep k
End If
#If NTC_LIBRARY_ROM Then
#Else
bd = 65                                         ' the boot drive: "CYB d" (A without it)
If a <> "" Then bd = Asc(a)
If ProbeDiscs() = 0 Then                        ' no RAM discs survived a reset: make Z from the disc
  a = "RAMDISC" : b = "Z SYSTEM " + Chr$(bd)    ' the system drive Z: the files CYBORGOS.Z names copied
  StartTask 1, 1                                ' to a RAM disc; the command line waits for it (WAIT)
  If st(1) = 2 Then wt = 1
End If
#End If
Do
  hk = Hot.Take()
  If hk = Hot.TOPKEY Then
    If front = 0 Then ToFront back Else ShowTop      ' Control + ESC: TOP, and again: back
  ElseIf hk > 0 And hk <= ns Then
    ToFront hk
  End If
  If pk <> 0 And wt = 0 Then                    ' (a key left by a program: after WAIT's prompt)
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
i = Hyp.Scr(0, 2)                 ' the CRTC as the firmware has it (80 x 25)
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
  Dim n As Integer, t As Integer, r As Integer, c As Integer, q As Integer
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
  n = 0
  Do
    Hyp.Reply ra(t), ra(t)
    r = Hyp.Run(sg(t))
    tn(t) = tn(t) + 1
    If kq(t) <> 0 Then
      If Memory.ReadByte(Far(t, Hyp.KEY)) = 0 Then kq(t) = 0     ' the program took its key
    End If
    c = Hyp.Count()
    If c > 0 Then Collected t, c
    If r = 0 Then
      ' its slice used up (Hyp.Run: 6 interrupts): the same slot on, TURNS slices a turn - the
      ' main loop's BASIC after each slice took a fifth of the CPU (keys: looked at 16 times a
      ' second while a program computes; Hot's keys at 50)
      q = q + 1
      If q >= TURNS Then Exit Do
    ElseIf r <> 1 Then
      Exit Do
    Else
      c = Hyp.Fn()
      Bdos t
      ' a file call (13-35, DMA 26 too): the same slot straight on, up to 32 calls a turn - the
      ' main loop's work (keys, the other slots) between each record made a copy crawl
      n = n + 1
      If c < 13 Or c > 36 Or n >= 32 Or st(t) <> 2 Then Exit Do
    End If
  Loop
End Sub

' a slot's BDOS call: Hyp.Fn() = C, Hyp.Arg() = DE; the answer in ra(t)
Sub Bdos(ByVal t As Integer)
  Dim f As Integer, e As Integer, a As Integer
  f = Hyp.Fn() : e = Hyp.Arg() And 255 : a = 0
  nb(t) = nb(t) + 1
  wk(t) = -1
  If f = 40 Then f = 34           ' write random with zero fill: as 34
  Select Case f
    Case 0
      EndTask t
      Exit Sub
    ' 1, 2, 6, 9, 10, 11: answered in the bank (Hyp's stubs), never here - the BASIC that did
    ' them before (kept for comparison, not compiled; 1, 6, 11 now wait through 129):
    '|   Case 1
    '|     a = kq(t) : kq(t) = 0
    '|     If a <> 0 Then PutC t, a Else wk(t) = Ticks
    '|   Case 2
    '|     PutC t, e
    '|   Case 6
    '|     If e = 255 Then
    '|       a = kq(t) : kq(t) = 0
    '|       If a = 0 Then wk(t) = Ticks
    '|     ElseIf e = 254 Then
    '|       If kq(t) <> 0 Then a = 255 Else wk(t) = Ticks
    '|     Else
    '|       PutC t, e
    '|     End If
    '|   Case 9
    '|     PutMem t, Hyp.Arg()
    '|   Case 11
    '|     If kq(t) <> 0 Then a = 255 Else wk(t) = Ticks
    Case 12
      a = &H22                    ' CP/M 2.2
    Case 13, 32                   ' reset the discs; user number: nothing to do here
      a = 0
    Case 14                       ' select a disc: the slot's drive (as CD)
#If NTC_LIBRARY_ROM Then
#Else
      dv(t) = 65 + e
#End If
    Case 25
#If NTC_LIBRARY_ROM Then
      a = 0
#Else
      If dv(t) = 0 Then a = 0 Else a = dv(t) - 65
#End If
    Case 26                       ' the DMA address (CP/M's record buffer)
      dm(t) = Hyp.Arg()
    Case 24                       ' the login vector: the slot's drive
#If NTC_LIBRARY_ROM Then
      a = 1
#Else
      If dv(t) = 0 Then a = 1 Else a = dv(t) - 64   ' (A 1, B 2)
#End If
    Case 15 To 36                 ' files: Hyp.FileCall
#If NTC_LIBRARY_ROM Then
      a = Hyp.FileCall(f, Hyp.Arg(), t, sg(t), dm(t), 0, VarPtr(rb))
#Else
      a = Hyp.FileCall(f, Hyp.Arg(), t, sg(t), dm(t), dv(t), VarPtr(rb))
#End If
#If NTC_LIBRARY_ROM Then
#Else
    Case 130                      ' RAMDISC.CYB: the RAM discs' driver
      a = RamDisc(t, Hyp.Arg())
#End If
    Case 131                      ' CyborgOS's own commands (PS, KILL, MEM ...)
      a = Sys(t, Hyp.Arg())
    Case 128
      ' only the characters (already shown)
    Case 129                      ' the stub's key wait (BDOS 1, 10, BIOS CONIN): sleep till a key
      If kq(t) = 0 Then wk(t) = Ticks
    Case Else
      a = 255
  End Select
  ra(t) = a
End Sub

#If NTC_LIBRARY_ROM Then
#Else
' BDOS 130 (RAMDISC.CYB): DE = op, letter, the driver's address and length (words) in the
' slot. The driver goes into a page of its own the first time; then it is handed the call (its
' 116: op 0 a RAM disc as drive letter, 2 a free page more for it - taken here -, 1 one of its
' pages back - freed here -, 3 a line for RAMDISC's list). 2: no free page
Function RamDisc(ByVal t As Integer, ByVal p As Integer) As Integer
  Dim g As Integer, o As Integer, f As Long
  o = Memory.ReadByte(Far(t, p))
  If dp = 0 Then
    RamDisc = 255
    If o = 3 Then Exit Function                              ' (the list: none)
    dp = Memory.AllocPage(Memory.TypeUser)
    If dp = 0 Then RamDisc = 2 : Exit Function
    f = Far(t, Memory.ReadWord(Far(t, p + 2)))                 ' (Far's FarPtr: one result for all calls)
    Memory.Copy f, Hyp.FarPtr(dp, 0), Memory.ReadWord(Far(t, p + 4))
    g = Memory.SelectPage(dp)
    Hyp.UseDriver VarPtr(rb)
    g = Hyp.FileCall(110, 0, 0, 0, 0, 0, 0)                    ' (its tables cleared)
  End If
  g = 0
  If o = 2 Then
    g = Memory.AllocPage(Memory.TypeUser)
    RamDisc = 2
    If g = 0 Then Exit Function
    RamDisc = Memory.SelectPage(g)
  End If
  RamDisc = Hyp.FileCall(116, p, t, sg(t), g, Hyp.Setting(), 0)
  If RamDisc < 0 Then RamDisc = Memory.FreePage(RamDisc And &H7FFF) : RamDisc = 0   ' (a page back: + #8000)
  If g <> 0 And RamDisc <> 0 Then RamDisc = Memory.FreePage(g) : RamDisc = 2
End Function
#End If

#If NTC_LIBRARY_ROM Then
#Else
' BDOS 131 op 12: slot t's store - its program's own 16K pages (TypeUser, their numbers in its
' bank at STORE: 32 at most, 0 none), kb K of them (rounded up to whole pages): more taken or
' the extra given back. 0 done, 2 not enough free memory (what it had kept). Gone when the
' program ends (EndTask, RESET: StoreFree); a program starts with none (Install)
Function StoreSize(ByVal t As Integer, ByVal kb As Integer) As Integer
  Dim n As Integer, j As Integer, g As Integer
  n = (kb + 15) \ 16
  If kb < 0 Or n > 32 Then n = 32
  For j = 0 To 31
    g = Memory.ReadByte(Far(t, STORE + j))
    If j < n And g = 0 Then
      g = Memory.AllocPage(Memory.TypeUser)
      If g = 0 Then StoreSize = 2 : Exit Function
      Memory.WriteByte Far(t, STORE + j), g
    ElseIf j >= n And g <> 0 Then
      g = Memory.FreePage(g)
      Memory.WriteByte Far(t, STORE + j), 0
    End If
  Next
End Function

#If NTC_LIBRARY_ROM Then
#Else
' at boot: a RAM disc driver page that outlived a reset (its "CYBD" signature at #7F00, the magic
' word, and the checksum of D_POOL + D_VOL) found among the free pages - that page and the pages
' D_POOL lists are reclaimed, so Z and any other RAM disc are back with no loading. True = found
Function ProbeDiscs() As Integer
  Dim p As Integer, su As Integer, j As Integer, a As Integer, pg As Integer, r As Integer
  ProbeDiscs = 0
  For p = 2 To Memory.Pages()
    If Memory.PageType(p) = Memory.TypeFree Then
      r = Memory.SelectPage(p)
      If Peek(&H7F00) = 67 And Peek(&H7F01) = 89 And Peek(&H7F02) = 66 And Peek(&H7F03) = 68 And Peek(&H7F04) = &H5A And Peek(&H7F05) = &HCB Then
        su = 0
        For j = &H5400 To &H59FF
          su = (su + Peek(j)) And &HFFFF
        Next
        If su = Peek(&H7F06) + Peek(&H7F07) * 256 Then
          dp = Hyp.ClaimPage(p)
          For j = 0 To 255                       ' the pages D_POOL lists (owner <> 0) back too
            a = &H5400 + j * 6
            If Peek(a) <> 0 Then
              pg = Peek(a + 2) + Peek(a + 3) * 256
              r = Hyp.ClaimPage(pg)
            End If
          Next
          r = Memory.SelectPage(dp)
          Hyp.UseDriver VarPtr(rb)
          ProbeDiscs = -1
          Exit Function
        End If
      End If
    End If
  Next
End Function
#End If

' the slot's store given back (its program ended)
Sub StoreFree(ByVal t As Integer)
  Dim r As Integer
  r = StoreSize(t, 0)
End Sub

#End If

' BDOS 131: CyborgOS's own commands (PS.CYB, KILL.CYB, MEM.CYB ...: CybSys.cls): DE = a block -
' op, a slot or value, then what comes back. 0 slot's line (state, in front, its program's name),
' 1 kill, 2 reset (slot 0: this one), 3 to the front, 4 wait until no other program runs, 6 TOP's
' table into this slot, 7 the memory (the tables' end, the top, the pages, the totals line), 8 32
' pages of the map from page Word(2), 9 MODE (0-5 set, 255 which), 12 the slot's store (K); 10, 11,
' 13, 14, 15 (memory, the pointer, the store's blocks, tables): Hyp.Svc, in the service page. 0
' done, 1 nothing to do, 255 no such slot / page
Function Sys(ByVal t As Integer, ByVal p As Integer) As Integer
  Dim o As Integer, s As Integer, d As Integer
  o = Memory.ReadByte(Far(t, p)) : s = Memory.ReadByte(Far(t, p + 1))
  If o = 4 Then
    If Running() > 1 Then wt = t
    Exit Function
  ElseIf o = 6 Then
    txs = t
    TopLines front, 0
    Exit Function
  ElseIf o = 9 Then                               ' MODE: s 0-4 this slot's mode (its console
    If s = 255 Then Sys = Memory.ReadByte(Far(t, Hyp.CMODE)) : Exit Function   ' cleared), 255: which
    If s > 5 Then Sys = 255 : Exit Function                                     ' it is
    SetMode t, s
    Exit Function
#If NTC_LIBRARY_ROM Then                         ' (MON's: not in the Library: ROM build - no room)
#Else
  ElseIf o = 10 Or o = 11 Or o = 13 Or o = 14 Or o = 15 Then   ' memory, the pointer, the store's
    Sys = Hyp.Svc(t, p, sg(t), VarPtr(rb))                     ' blocks, tables: in the service page
    Exit Function
  ElseIf o = 12 Then                              ' the slot's store: Word(2) K (16K pages, 512K at most)
    Sys = StoreSize(t, Memory.ReadWord(Far(t, p + 2)))
    Exit Function
#End If
#If NTC_LIBRARY_ROM Then                         ' (MEM: not in the Library: ROM build - no room)
#Else
  ElseIf o = 7 Then
    Memory.WriteWord Far(t, p + 2), Memory.TableEnd()
    Memory.WriteWord Far(t, p + 4), Memory.Top()
    Memory.WriteWord Far(t, p + 6), Memory.Pages()
    Totals
    PutEn t, p + 8
    Exit Function
  ElseIf o = 8 Then
    en = Memory.Map(Memory.ReadWord(Far(t, p + 2)), 32)
    PutEn t, p + 4
    Exit Function
#End If
  End If
  If o = 2 And s = 0 Then s = t
  Sys = 255
  If s < 1 Or s > ns Then Exit Function
  Sys = 0
  If o = 0 Then
    Memory.WriteByte Far(t, p + 2), st(s)
    Memory.WriteByte Far(t, p + 3), IIf(s = front, 1, 0)
    en = ""
    If st(s) = 2 Then GetNm s
    PutEn t, p + 4
  ElseIf o = 1 Then
    If st(s) = 2 Then EndTask s Else Sys = 1
  ElseIf o = 2 Then
    ResetSlot s
    If s = t Then Prompt t                       ' (RESET of its own slot: the program gone)
  ElseIf o = 3 Then
    ToFront s
  End If
End Function

' en into slot t at address a: its length, then its characters
Sub PutEn(ByVal t As Integer, ByVal a As Integer)
  Memory.WriteByte Far(t, a), Len(en)
  Memory.Copy NearP(VarPtr(en)), Far(t, a + 1), Len(en)
End Sub

' the hypervisor's own reading (Hyp.FileCall 100-102): open file dn (True / False), read n
' bytes into rb (how many), close
Function HOpen() As Integer
  HOpen = (Hyp.FileCall(100, VarPtr(dn), 0, 0, Len(dn), 0, 0) = 0)
End Function
Function HRead(ByVal n As Integer) As Integer
  HRead = Hyp.FileCall(101, 0, 0, 0, n, 0, VarPtr(rb))
End Function
Sub HClose()
  Dim r As Integer
  r = Hyp.FileCall(102, 0, 0, 0, 0, 0, 0)
End Sub

' a slot's files closed (its program ended, was killed or reset)
Sub FilesShut(ByVal t As Integer)
  Hyp.FileShut t
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
  Hyp.Con wp(t), VarPtr(s), Len(s), IIf(t = front, 1, 0)
End Sub

Sub PutLn(ByVal t As Integer, ByVal s As String)
  PutS t, s + Chr$(13) + Chr$(10)
End Sub

' one character (or control code) to slot t's console
Sub PutC(ByVal t As Integer, ByVal c As Integer)
  Hyp.Con wp(t), VarPtr(c), 1, IIf(t = front, 1, 0)   ' (the Integer's low byte is the character)
End Sub

' (BDOS 9 is answered in the bank now - kept for comparison, not compiled)
'| ' BDOS 9: the slot's string at address a in its bank, to the "$": fetched 128 bytes at a time
'| ' (Memory.Copy) and written with Hyp.Con (rare: no Z80 of its own)
'| Sub PutMem(ByVal t As Integer, ByVal a As Integer)
'|   Dim n As Integer, d As Integer
'|   Do
'|     Memory.Copy Far(t, a), CLng(VarPtr(ob)), 128
'|     n = 128
'|     d = InStr(Left$(ob, 128), "$")
'|     If d > 0 Then n = d - 1
'|     nc(t) = nc(t) + n
'|     Hyp.Con wp(t), VarPtr(ob), n, IIf(t = front, 1, 0)
'|     If d > 0 Then Exit Sub
'|     a = a + 128
'|   Loop
'| End Sub

' a far pointer to address p of main RAM (page 0): CLng(p) of an address from #8000 up is
' negative - not page 0
Function NearP(ByVal p As Integer) As Long
  NearP = CLng(p)
  If p < 0 Then NearP = NearP + 65536
End Function

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
  Dim r As Integer
  front = t
  If st(t) = 0 Then OpenSlot t : Exit Sub
  r = Hyp.Scr(Memory.ReadByte(Far(t, Hyp.CMODE)), 2)   ' the screen in its mode (cleared)
  Hyp.Show wp(t)
End Sub

' slot t's MODE m (Hyp.Scr: 0 2, 1 S, 2 W, 3 UW, 4 P): its console's columns and rows in its bank
' (Hyp.Con and the bank's BDOS 49 go by them), the status strip's text ([slot]), the screen if
' it is in front; its page cleared
Sub SetMode(ByVal t As Integer, ByVal m As Integer)
  Dim r As Integer
  Memory.WriteByte Far(t, Hyp.CCOLS), Hyp.Scr(m, 0)
  Memory.WriteByte Far(t, Hyp.CROWS), Hyp.Scr(m, 1)
  Memory.WriteByte Far(t, Hyp.CMODE), m
  en = Left$("[" + N(t) + "]   ", 4)
  Memory.Copy NearP(VarPtr(en)), Far(t, Hyp.CSTRIP), 4
  If t = front Then r = Hyp.Scr(m, 2)
  ClsT t
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
  j = Hyp.Scr(0, 2)               ' TOP in MODE 2 (80 x 25), the screen cleared
  txs = 0
  TopLines back, 1
End Sub

' the TOP lines, to the screen (txs = 0) or slot txs's console: the slot marked with * is mark;
' keys <> 0: the line with the keys
Sub TopLines(ByVal mark As Integer, ByVal keys As Integer)
  Dim j As Integer, s As String Max 14
  txn = 0
  TopAdd "CyborgOS TOP"
  If keys Then TopAdd "Control + ESC: back, " + SK() + ": that slot" Else TopAdd ""   ' (25 rows: 20 slots)
  TopAdd "SLOT  STATE          PROGRAM         TURNS/S   BDOS/S  CHARS/S   (last second)"
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
  TopAdd ""
  Totals
  TopAdd en
End Sub

' en = "Total memory: n KB   Free memory: n KB" (free: the 16K pages no slot or anything has)
Sub Totals()
  en = "Total memory: " + N(Memory.RamSize()) + " KB   Free memory: " + N(Memory.FreePages() * 16) + " KB"
End Sub

' MEM: main RAM as a table (address range, what is there), the banks' pages - a character a
' 16K page (B a slot's, U the hypervisor's, - free), 32 pages (8 banks) a group, two groups a line - and the totals


Sub TopAdd(ByVal s As String)
  If txs = 0 Then
    Hyp.Say VarPtr(s), Len(s), 0, txn          ' straight into screen memory (Print took ~0.7 s)
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
  Dim p As Integer, n As Integer
  p = Hyp.Info(0) : n = Hyp.Info(1)             ' (one Info result each: it is one variable)
  Memory.Copy Hyp.FarPtr(hp, p), Far(t, 0), n   ' (from the hypervisor's page)
  p = Hyp.Info(2) : n = Hyp.Info(3)
  Memory.Copy Hyp.FarPtr(hp, p), Far(t, Hyp.STUB), n
  Memory.Copy Hyp.FarPtr(hp, Hyp.HFONT), Far(t, Hyp.FONT), 768   ' the font (Con draws from it)
  Memory.WriteByte Far(t, Hyp.OBUF + 128), 0      ' no characters collected
  Memory.WriteByte Far(t, Hyp.KEY), 0             ' no key waiting
  kq(t) = 0
#If NTC_LIBRARY_ROM Then
#Else
  For n = 0 To 31                                 ' no store yet
    Memory.WriteByte Far(t, STORE + n), 0
  Next
#End If
End Sub

' RESET: the slot as before its command line was first opened - its program (if any) stopped,
' nothing kept. The slot in front (the one typing it) opens again at once, as new
Sub ResetSlot(ByVal s As Integer)
  FilesShut s
#If NTC_LIBRARY_ROM Then
#Else
  If st(s) = 2 Then StoreFree s
#End If
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
    SetMode s, 1
    PutLn s, "CyborgOS slot " + N(s) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
    PutLn s, ""                   ' a blank line under the title
  End If                          ' (the prompt: the command line puts it after the command)
End Sub

Sub OpenSlot(ByVal t As Integer)
  Install t
  st(t) = 1
  SetMode t, 1                    ' MODE S: 80 x 24 and the status strip
  PutLn t, "CyborgOS slot " + N(t) + " of " + N(ns) + " - " + SK() + ", Control + ESC TOP, HELP"
  PutLn t, ""                     ' a blank line under the title
  Prompt t
End Sub

' the keys for the slots, as the help lines say them
Function SK() As String
  If ns <= 9 Then
    SK = "Control + 1-" + N(ns)
  ElseIf ns = 10 Then
    SK = "Control + 1-9, 0"
  Else
    SK = "Control + 1-9, 0 (twice 11-" + N(ns) + ")"
  End If
End Function

' a number without the space Str$ puts before it
' en = the name of the program slot t runs (from its bank; a String function's result would
' take 256 bytes)
Sub GetNm(ByVal t As Integer)
  Dim n As Integer
  n = Memory.ReadByte(Far(t, NMLEN))
  en = Space$(12)
  Memory.Copy Far(t, NMBUF), NearP(VarPtr(en)), n
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
  Dim c As String Max 72, p As Integer, s As Integer
  p = Memory.ReadByte(Far(t, LNLEN))              ' the command line, from the slot's bank
  Memory.Copy Far(t, LNBUF), NearP(VarPtr(ob)), p
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
  If Len(c) = 2 And Right$(c, 1) = ":" And a = "" Then   ' B: alone: CD B, as in CP/M (CD.CYB)
    If Asc(c) >= 65 And Asc(c) <= 90 Then a = Left$(c, 1) : c = "CD"
  End If
  Select Case c
    Case ""
    Case "CLS"
      ClsT t
    Case "RUN"                                 ' RUN [slot] name [tail]: the program on the disc even
      s = t                                    ' when a command has its name; with a slot: in that one
      If a <> "" And N(Val(a)) = a Then
        s = Val(a) : a = b : b = ""
        p = InStr(a, " ")
        If p > 0 Then b = Trim$(Mid$(a, p + 1)) : a = Left$(a, p - 1)
      End If
      If s < 1 Or s > ns Then PutLn t, "no slot" + Str$(s) : Exit Sub
      If st(s) = 2 Then PutLn t, "slot" + Str$(s) + " is busy" : Exit Sub
      StartTask t, s
    Case "QUIT"
      quit = -1
    Case Else                                  ' the rest are programs (the system drive Z's, else
      b = Trim$(a + " " + b)                   ' the slot's drive, else A): PS, MEM, CD, DIR ... and
      a = c                                    ' any other, the rest of the line their tail
      bare = -1
      StartTask t, t
      bare = 0
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
  Dim h As Integer, n As Integer, rest As Integer, com As Integer, w As String Max 72, d As Integer
  If a = "" Then PutLn t, "RUN what?" : Exit Sub
  w = a
  d = 0                                          ' the drive looked on: Z (-1, the system drive: the
#If NTC_LIBRARY_ROM Then                         ' commands), the slot's (0), then A
#Else
  d = -1
#End If
  Do
#If NTC_LIBRARY_ROM Then
#Else
    If d = -1 Then
      If Hyp.Drive(90) = 0 Then d = 0            ' (no system drive)
    End If
    If d = 0 Then OwnDrive t
    If d = 1 Then n = Hyp.Drive(bd)
#End If
    a = w : h = 0 : com = 0
    If InStr(a, ".") = 0 Then
      dn = a + ".CYB"
      h = HOpen()
      If h Then a = dn Else com = -1
    ElseIf Right$(a, 4) = ".COM" Then
      com = -1
    Else
      dn = a
      h = HOpen()
    End If
    rest = &HEE00                                ' #0100 to the stub (#EF00)
    If com Then
      en = a
      n = FindCom()                              ' (the entry in rb)
      If n > 0 Then
        rest = n                                 ' (an Integer used unsigned: up to #EE00)
        en = Space$(12)
        a = Left$(en, Ent.DiscName(VarPtr(rb), VarPtr(en)))
        dn = a
        h = HOpen()                              ' (read raw: a #1A is a byte)
      End If
    End If
    If h Then Exit Do
#If NTC_LIBRARY_ROM Then
    Exit Do
#Else
    If d = 1 Or (d = 0 And dv(t) = bd) Then Exit Do   ' not on Z nor the slot's drive: the boot drive
    d = d + 1
#End If
  Loop
  If h = 0 Then
    a = w
#If NTC_LIBRARY_ROM Then
#Else
    OwnDrive t
#End If
    NotFound t
    Exit Sub
  End If
  If st(s) = 0 Then OpenSlot s
  If s <> t Then PutLn s, "RUN " + a
  Install s
  n = Hyp.FileCall(103, rest, s, sg(s), &H100, 0, VarPtr(rb))  ' at #0100, rest bytes at most
  HClose
#If NTC_LIBRARY_ROM Then
#Else
  If d <> 0 Then OwnDrive t                      ' (loaded from Z or A: the slot's drive again)
#End If
  If com And n <> rest Then PutLn t, a + ": shorter than FILES.DIR says" : Exit Sub
  ' its first stack: ret to the stub's start (the default FCBs from the tail, then #0100), under
  ' it #0000 (a ret from the program ends it). At the top of the stub area (#F240-#F2FF, which
  ' the stubs leave free): BDOS calls and the console run on it, so not next to the text page
  Memory.WriteWord Far(s, &HF2FC), Hyp.Info(4)
  Memory.WriteWord Far(s, &HF2FE), 0
  Memory.WriteWord Far(s, &HFFFE), &HF2FC
  ' the command tail at #0080 as CP/M has it: its length, a space, the text in capitals, a 0
  If b = "" Then
    Memory.WriteByte Far(s, &H80), 0
  Else
    b = " " + b
    Memory.Copy NearP(VarPtr(b)), Far(s, &H81), Len(b)
    Memory.WriteByte Far(s, &H80), Len(b)
    Memory.WriteByte Far(s, &H81 + Len(b)), 0
  End If
  Memory.WriteByte Far(s, NMLEN), Len(a)
  Memory.Copy NearP(VarPtr(a)), Far(s, NMBUF), Len(a)
  kq(s) = 0
  Memory.WriteByte Far(s, &HF685), 0             ' no escape sequence rest half done
  wk(s) = -1
  dm(s) = &H80                                   ' CP/M's record buffer to start with
  st(s) = 2
  If s <> t Then PutLn t, a + " runs in slot" + Str$(s)
End Sub

Sub NotFound(ByVal t As Integer)
  If bare Then PutLn t, "? " + a + " (HELP)" Else PutLn t, a + ": not found"
End Sub

#If NTC_LIBRARY_ROM Then
#Else
' the slot's own drive (CD) selected, as CP/M has one each (A to start with)
Sub OwnDrive(ByVal t As Integer)
  Dim r As Integer
  If dv(t) = 0 Then dv(t) = bd
  r = Hyp.Drive(dv(t))
End Sub
#End If

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


' en's entry (into rb): from NAME.HDR, else FILES.DIR (by its disc name, or its long name):
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

' the entry in file dn for SetName's name (or with the long name en), into rb: its length, or 0
Function FindEnt() As Integer
  Dim r As Integer
  r = 0
  If HOpen() Then
    Do While HRead(64) = 64
      r = Ent.Length(VarPtr(rb), VarPtr(en), Len(en))
      If r <> 0 Then Exit Do
    Loop
    HClose
  End If
  FindEnt = r
End Function


Sub EndTask(ByVal t As Integer)
  Dim c As Integer
  FilesShut t
#If NTC_LIBRARY_ROM Then
#Else
  StoreFree t
#End If
  st(t) = 1
  runs = runs + 1
  PutLn t, ""
  GetNm t
  PutLn t, "[" + en + " ended]"
  If wt <> t Then Prompt t                       ' (WAIT: the prompt when nothing runs)
  c = kq(t) : kq(t) = 0
  If c <> 0 And t = front Then pk = c    ' a key typed for it after its last look: the command line's
End Sub
