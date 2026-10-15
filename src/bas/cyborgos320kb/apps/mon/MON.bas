' MON: a monitor of the CPC and CyborgOS, in the spirit of SCOUT on the Amiga - for CyborgOS 320K
' (build for cpm with Bml.cls, Mouse.cls and cmds/CybSys.cls; a .CYB). What it shows comes from a
' map: a text file (SYSTEM.MAP, made and tweaked by hand - its first lines say how it goes) of
' nodes: where the data is (a CyborgOS table, a 16K page, an upper ROM, main RAM, a slot's memory,
' a drive's files), how its records are laid out, how it is shown (a list, hex, text, names) and
' where each row leads. MON makes only the page asked for, 8BML (Bml lays it out), a window of
' rows at a time. It reads through CyborgOS (BDOS 131: op 15 a table, op 10 memory, raw, into its
' 2K buffer at #E000); the laid-out lines go to its store (Bml: 2K blocks, 3 kept at #C800).
'   MON                 SYSTEM.MAP (this drive, else A:, else Z:)
'   MON map [slot]      that map ({s} in it: the slot, else 1)
'
' The screen: MODE F (84 x 24, all of it MON's), its own put back at the end. A window of - | +:
' the toolbar (the map's tools), the page (19 lines of 78), a status line; the 4 columns on the
' right are the current line's < and a scroll bar. Keys: Tab / right next link, left the one
' before, up / down the line (the page scrolls), Shift + up / down a page, Control + up / down the
' top / end, Enter or Copy the link, 1-8 or a tool's capital letter the toolbar, B or DEL back,
' R again (fresh), Q or ESC quits. The mouse: the pointer (an XOR checkerboard, drawn by CyborgOS)
' follows it, gone when it stops a while; left button: a link, the toolbar, the scroll bar (^ v
' at its ends, above / below the bar a page)
Option Explicit
Option Terminal VT52              ' (CyborgOS's console: Locate and Cls as ESC Y, ESC E)
Const MBUF = &HE000               ' 2K near the top of MON's bank (the TPA ends at #EF00): what CyborgOS gives (ops 10, 15: raw)
Const SBUF = &HA000               ' 8K: the page's 8BML (Bml's links point into it)
Const MAPB = &HC000               ' 4K: the map's text
Const LBUF = &HD000               ' 4K: Bml's lines on their way to and from the store (2 blocks)
Const VR = 19                     ' the page's rows on the screen (3-21)
Const VW = 78                     ' and its columns (1-78)
Const MD = 3                      ' the mouse: its counts a character cell
Const RP = 48                     ' a list's rows a page (more >> for the next)
Const MPN = 4095                  ' the map's text: its bytes - 1
Dim sn As Integer                            ' the page's 8BML: its length (at SBUF)
Dim hs(15) As String Max 40, hn As Integer   ' the pages before (B goes back)
Dim cu As String Max 40                      ' this page's URL
Dim tp As Integer, cl As Integer, sl As Integer   ' the first line shown, the current line, the link chosen (-1 none)
Dim ol As Integer, os As Integer             ' ... as they were last drawn
Dim px As Integer, py As Integer, fx As Integer, fy As Integer, pv As Integer, pb As Integer, idle As Integer
Dim ms As Integer, qt As Integer, m0 As Integer, k As Integer, r As Integer, i As Integer
Dim bb(63) As Byte                           ' BDOS 17 / 18's FCB
Dim dd(127) As Byte                          ' ... and the DMA
Dim tb(7) As String Max 12, tbn(7) As String Max 12, tbc(7) As Integer, tbk(7) As Integer, ntb As Integer
Dim st As String Max 80, s As String Max 80
Dim hsp As Integer
' the map: its lines (comments left out) at mp, a 10 after each; its nodes and cats
Dim mn As Integer, mq As Integer, mf As String Max 20
Dim nid(47) As String Max 12, npo(47) As Integer, npc(47) As Integer, nlp(47) As Integer, nca(47) As Integer, nn As Integer
Dim cat(11) As String Max 40, nc As Integer, pre As Integer
Dim tk As String Max 80, tq As Integer, gs As String Max 4
' the page being made: its node's parameters (ag), its offset (ao: records, hex / text 1K)
Dim ag(3) As String Max 12, ao As Integer, pt As String Max 80
' ... its source: kind (0 none, 1 os, 2 page, 3 rom, 4 main, 5 slot, 6 dir), page / ROM / slot / table
' / drive, address, length (bytes, 32767 at most), MBUF holding its start (hv)
Dim sk As Integer, sp1 As Integer, sad As Integer, slb As Integer, hv As Integer
' ... its records: size, first, the first's number, count (cty: 0 none, 1 byte, 2 word, 3 n), walk,
' skip, dup
Dim rsz As Integer, rfi As Integer, rba As Integer, cty As Integer, cv As Integer
Dim wko As Integer, wmx As Integer, skt As Integer, sko As Integer, skv As Integer, dpn As Integer
Dim wv(63) As Integer                        ' a walk's records' addresses (this window's)
Dim wi0 As Integer, wen As Integer           ' the window's first record; the list ended
' ... its columns: heading, type, offset, length / length's offset, times, unit, enum, mask
Dim fh(7) As String Max 16, ft(7) As Integer, fo(7) As Integer, fl(7) As Integer, fx2(7) As Integer
Dim fu(7) As String Max 6, fm(7) As Integer, nf As Integer
Dim fes(7) As Integer, fec(7) As Integer, ev(47) As Integer, en(47) As String Max 20, nen As Integer   ' enums: values, names
' ... its rows' link: node, args
Dim gid As String Max 12, ga(3) As String Max 16, ng As Integer

m0 = CybSys.Ask(9, 255)
If m0 > 5 Then Print "MON needs CyborgOS 320K" : End
s = UCase$(Trim$(System.CommandLine()))
gs = "1"
i = InStr(s, " ")
If i > 0 Then gs = Trim$(Mid$(s, i + 1)) : s = Left$(s, i - 1)
If s = "" Then
  If MapLoad("SYSTEM.MAP") = 0 Then
    If MapLoad("A:SYSTEM.MAP") = 0 Then r = MapLoad("Z:SYSTEM.MAP")
  End If
Else
  r = MapLoad(s)
End If
If mn = 0 Then Print "MON: no map ("; s; ")" : End
MapIndex
r = CybSys.Ask(9, 5)                         ' MODE F
k = Bml.Init(LBUF, 2, VW)
ms = Mouse.Present()
px = 40 : py = 12
st = ""
Go "m:home", 0
Do
  k = Inkey
  If ms Then MousePoll
  If k <> 0 Then KeyIn k
Loop Until qt
PtrOff
r = CybSys.Ask(9, m0)                        ' the mode MON found (its console cleared)
End

' ---- the screen

' the cursor to row y, column x (0 based)
Sub At(ByVal y As Integer, ByVal x As Integer)
  Locate x + 1, y + 1
End Sub

' everything: the frame, the toolbar, the page, the status line
Sub DrawAll()
  Dim j As Integer, t As String Max 80
  PtrOff
  Cls
  t = Bml.Title()
  If t = "" Then t = "MON"
  At 0, 0 : Print "+- "; Left$(t, 70); " "; String$(75 - Len(Left$(t, 70)), "-"); "+---+";
  At 1, 0 : Print "|";
  s = ""
  For j = 0 To ntb - 1
    tbc(j) = Len(s) + 1
    s = s + Chr$(49 + j) + ":" + tbn(j) + " "
  Next
  Print Left$(s + Space$(VW), VW); "|   |";
  At 2, 0 : Print "+"; String$(VW, "-"); "+---+";
  For j = 3 To 21
    At j, 0 : Print "|";
    At j, 79 : Print "|   |";
  Next
  At 22, 0 : Print "+"; String$(VW, "-"); "+---+";
  At 23, 0 : Print "|";
  At 23, 79 : Print "|";
  DrawPage
  DrawStatus
  PtrOn
End Sub


' the page's lines from tp, the < at the current line, the scroll bar, the chosen link marked
Sub DrawPage()
  Dim j As Integer, n As Integer, a As Integer, c As Integer, y As Integer, b0 As Integer, b1 As Integer
  n = Bml.Lines()
  b0 = 0 : b1 = VR - 3                           ' the scroll bar's thumb: rows 1 to VR - 2
  If n > VR Then
    b0 = (tp * (VR - 2)) \ n
    b1 = ((tp + VR) * (VR - 2)) \ n
    If b1 > VR - 3 Then b1 = VR - 3
  End If
  For j = 0 To VR - 1
    At 3 + j, 1
    If tp + j < n Then
      PutMem Bml.LineAddr(tp + j), VW
    Else
      Print Space$(VW);
    End If
    At 3 + j, 80
    If tp + j = cl Then Print "<"; Else Print " ";
    Print " ";
    If j = 0 Then
      Print "^";
    ElseIf j = VR - 1 Then
      Print "v";
    ElseIf j - 1 >= b0 And j - 1 <= b1 Then
      Print "#";
    Else
      Print ":";
    End If
  Next
  LinkMark
  ol = cl : os = sl
End Sub

' the status line: st, else the chosen link's URL, then the line number and lines
Sub DrawStatus()
  Dim t As String Max 80
  t = st
  If t = "" And sl >= 0 Then t = Bml.LinkUrl(sl)
  If t = "" Then t = cu
  t = Left$(t, 58)
  At 23, 1
  t = Left$(" " + t + Space$(VW), 64)
  Print t;
  t = "line" + Str$(cl + 1)
  t = t + " /" + Str$(Bml.Lines())
  Print Right$(Space$(14) + t, 14);
  st = ""
End Sub

' n characters at a to the console (BDOS 6, each). Z80: the one place MON needs it - in BASIC a
' character a keyword loop, 2.5 s a screen
Sub PutMem(ByVal a As Integer, ByVal n As Integer)
#asm
            ld ({hsp}), sp
            ld sp, (ntc_csp)
            ld hl, ({a})
            ld bc, ({n})
pm_lp:
            ld a, b
            or c
            jr z, pm_done
            push hl
            push bc
            ld e, (hl)
            ld c, 6
            ei                      ; (CP/M's BDOS: interrupts on)
            call 5
            di                      ; (off before SP is the thread again)
            pop bc
            pop hl
            inc hl
            dec bc
            jr pm_lp
pm_done:
            ld sp, ({hsp})
#endasm
End Sub

' ---- the mouse pointer: drawn by CyborgOS (BDOS 131 op 11), taken off before MON draws

Sub PtrOff()
  If pv Then r = CybSys.Ask(11, 0) : pv = 0
End Sub

Sub PtrOn()
  If ms And idle < 4000 Then
    CybSys.SetWord 2, px + py * 256
    r = CybSys.Ask(11, 1)
    pv = -1
  End If
End Sub

Sub MousePoll()
  Dim b As Integer, mv As Integer
  Mouse.Poll
  fx = fx + Mouse.MoveX() : fy = fy + Mouse.MoveY()
  mv = 0
  Do While fx >= MD
    fx = fx - MD : px = px + 1 : mv = -1
  Loop
  Do While fx <= -MD
    fx = fx + MD : px = px - 1 : mv = -1
  Loop
  Do While fy >= MD
    fy = fy - MD : py = py + 1 : mv = -1
  Loop
  Do While fy <= -MD
    fy = fy + MD : py = py - 1 : mv = -1
  Loop
  If px < 0 Then px = 0
  If px > 83 Then px = 83
  If py < 0 Then py = 0
  If py > 23 Then py = 23
  b = Mouse.Buttons()
  If mv Then
    idle = 0
    PtrOff
    PtrOn
  Else
    idle = idle + 1
    If idle = 4000 Then PtrOff
  End If
  If (b And 1) <> 0 And (pb And 1) = 0 Then Click
  pb = b
End Sub

' the left button: the toolbar, a link, a line, the scroll bar
Sub Click()
  Dim j As Integer, y As Integer
  idle = 0
  If py = 1 Then
    For j = ntb - 1 To 0 Step -1
      If px >= tbc(j) Then Go tb(j), 1 : Exit Sub
    Next
  ElseIf py >= 3 And py <= 21 And px = 82 Then
    y = py - 3
    If y = 0 Then
      Scroll -1
    ElseIf y = VR - 1 Then
      Scroll 1
    ElseIf (y - 1) * Bml.Lines() \ (VR - 2) < tp Then
      Scroll -VR
    Else
      Scroll VR
    End If
  ElseIf py >= 3 And py <= 21 And px >= 1 And px <= VW Then
    y = tp + py - 3
    For j = 0 To Bml.Links() - 1
      If Bml.LinkLine(j) = y And px - 1 >= Bml.LinkCol(j) And px - 1 < Bml.LinkCol(j) + Bml.LinkLen(j) Then
        sl = j : cl = y
        OpenLink
        Exit Sub
      End If
    Next
    If y < Bml.Lines() Then cl = y : Redraw
  End If
End Sub

' ---- keys

Sub KeyIn(ByVal k As Integer)
  Dim j As Integer
  If k >= 97 And k <= 122 Then k = k - 32
  Select Case k
    Case 81, 252                                 ' Q, ESC
      qt = -1
    Case 9, 243                                  ' Tab, right: the next link
      NextLink 1
    Case 242                                     ' left: the one before
      NextLink -1
    Case 240                                     ' up
      If cl > 0 Then cl = cl - 1
      Follow
    Case 241                                     ' down
      If cl < Bml.Lines() - 1 Then cl = cl + 1
      Follow
    Case 244                                     ' Shift + up / down: a page
      Scroll -VR
    Case 245
      Scroll VR
    Case 248                                     ' Control + up / down: the top, the end
      tp = 0 : cl = 0 : Redraw
    Case 249
      cl = Bml.Lines() - 1 : tp = cl - VR + 1
      If tp < 0 Then tp = 0
      Redraw
    Case 13, 224                                 ' Enter, Copy
      OpenLink
    Case 66, 127, 8                              ' B, DEL: back
      Back
    Case 82                                      ' R: again
      Go cu, 0
    Case 49 To 56                                ' 1-8: the toolbar
      If k - 49 < ntb Then Go tb(k - 49), 1
    Case Else                                    ' a tool's letter
      For j = 0 To ntb - 1
        If tbk(j) = k Then Go tb(j), 1 : Exit For
      Next
  End Select
End Sub

' the next (d 1) or the one before (d -1) link: chosen, its line current and on the screen
Sub NextLink(ByVal d As Integer)
  Dim n As Integer
  n = Bml.Links()
  If n = 0 Then Exit Sub
  sl = sl + d
  If sl >= n Then sl = 0
  If sl < 0 Then sl = n - 1
  cl = Bml.LinkLine(sl)
  Follow
End Sub

' the current line on the screen (the page scrolled to it): drawn again - or, when the page
' didn't move, only the markers (the < column, the chosen link's > <) and the status line
Sub Follow()
  Dim t0 As Integer
  t0 = tp
  If cl < tp Then tp = cl
  If cl >= tp + VR Then tp = cl - VR + 1
  If tp <> t0 Then Redraw : Exit Sub
  PtrOff
  Marks
  DrawStatus
  PtrOn
End Sub

' the markers again: the old ones off (the lines they were on drawn again), the new ones on
Sub Marks()
  Dim y As Integer
  If ol >= tp And ol < tp + VR And ol <> cl Then At 3 + ol - tp, 80 : Print " ";
  At 3 + cl - tp, 80 : Print "<";
  If os >= 0 And os <> sl Then
    y = Bml.LinkLine(os) - tp
    If y >= 0 And y < VR Then At 3 + y, 1 : PutMem Bml.LineAddr(tp + y), VW
  End If
  LinkMark
  ol = cl : os = sl
End Sub

' the chosen link's > < (on the line's characters next to it)
Sub LinkMark()
  Dim y As Integer, c As Integer
  If sl < 0 Then Exit Sub
  y = Bml.LinkLine(sl) - tp
  If y < 0 Or y >= VR Then Exit Sub
  c = Bml.LinkCol(sl)
  If c > 0 Then At 3 + y, c : Print ">";
  c = c + Bml.LinkLen(sl)
  If c < VW Then At 3 + y, c + 1 : Print "<";
End Sub

Sub Scroll(ByVal d As Integer)
  Dim n As Integer
  n = Bml.Lines()
  tp = tp + d
  If tp > n - VR Then tp = n - VR
  If tp < 0 Then tp = 0
  If cl < tp Then cl = tp
  If cl >= tp + VR Then cl = tp + VR - 1
  Redraw
End Sub

Sub Redraw()
  PtrOff
  DrawPage
  DrawStatus
  PtrOn
End Sub

' the chosen link followed: "<" back, m: one of MON's pages, else not here (yet)
Sub OpenLink()
  Dim u As String Max 80
  If sl < 0 Then Exit Sub
  u = Bml.LinkUrl(sl)
  If u = "<" Then
    Back
  ElseIf Left$(u, 2) = "m:" Then
    Go u, 1
  Else
    st = "not here yet: " + u
    DrawStatus
  End If
End Sub

Sub Back()
  If hn = 0 Then Exit Sub
  hn = hn - 1
  Go hs(hn), 0
End Sub

' page u made, laid out and drawn; push: the one before kept for B
Sub Go(ByVal u As String Max 40, ByVal push As Integer)
  If push And cu <> "" Then
    If hn > 15 Then
      For i = 0 To 14
        hs(i) = hs(i + 1)
      Next
      hn = 15
    End If
    hs(hn) = cu : hn = hn + 1
  End If
  cu = u
  sn = 0
  Make u
  r = Bml.Render(SBUF, sn)
  tp = 0 : cl = 0 : sl = -1
  If Bml.Links() > 0 Then sl = 0
  DrawAll
End Sub

' ---- the pages, as 8BML into sb

' E, EQ, HexRows, TextRows, H2, H4, NmU: Z80 (asm keywords; the BASIC they were is kept below
' each as '| comments). They write straight into SBUF at sn, stopping at 8190 as the BASIC did
Sub E(ByVal t As String)
#asm
            pop de                  ; DE = t
            ld hl, 8190
            ld bc, ({sn})
            or a
            sbc hl, bc
            ld b, h
            ld c, l                 ; BC = room left
            ld hl, ({sn})
            ld a, {SBUF} & 255
            add a, l
            ld l, a
            ld a, {SBUF} >> 8
            adc a, h
            ld h, a                 ; HL = SBUF + sn
e_lp:
            ld a, b
            or c
            jr z, e_done
            ld a, (de)
            or a
            jr z, e_done
            ld (hl), a
            inc hl
            inc de
            dec bc
            jr e_lp
e_done:
            ld bc, -{SBUF}
            add hl, bc
            ld ({sn}), hl
#endasm
End Sub
'| Sub E(ByVal t As String)
'|   Dim j As Integer, p As Integer, n As Integer
'|   p = VarPtr(t) : n = Len(t)
'|   If sn + n > 8190 Then n = 8190 - sn
'|   For j = 0 To n - 1
'|     Poke SBUF + sn + j, Peek(p + j)
'|   Next
'|   sn = sn + n
'| End Sub

' t quoted (\" \\)
' t into sb quoted (\" \\), straight - no string built
Sub EQ(ByVal t As String)
#asm
            pop de                  ; DE = t
            ld (q_sp), sp
            ld sp, (ntc_csp)        ; (the real stack: q_put is called)
            call q_at               ; HL = SBUF + sn, BC = room
            ld a, 34
            call q_put
q_lp:
            ld a, (de)
            or a
            jr z, q_end
            call q_putq
            inc de
            jr q_lp
q_end:
            ld a, 34
            call q_put
            ld bc, -{SBUF}
            add hl, bc
            ld ({sn}), hl
            ld sp, (q_sp)
            ret
q_at:                               ; HL = SBUF + sn, BC = 8190 - sn
            ld hl, 8190
            ld bc, ({sn})
            or a
            sbc hl, bc
            ld b, h
            ld c, l
            ld hl, ({sn})
            push bc
            ld bc, {SBUF}
            add hl, bc
            pop bc
            ret
q_putq:                             ; A, after a \ when it is " or \
            cp 34
            jr z, q_esc
            cp 92
            jr nz, q_put
q_esc:
            push af
            ld a, 92
            call q_put
            pop af
q_put:                              ; A into the page when there is room
            push af
            ld a, b
            or c
            jr z, q_full
            pop af
            ld (hl), a
            inc hl
            dec bc
            ret
q_full:
            pop af
            ret
q_sp:       dw 0
#endasm
End Sub
'| Sub EQ(ByVal t As String)
'|   Dim j As Integer, p As Integer, v As Integer
'|   p = VarPtr(t)
'|   If sn < 8190 Then Poke SBUF + sn, 34 : sn = sn + 1
'|   For j = 0 To Len(t) - 1
'|     v = Peek(p + j)
'|     If (v = 34 Or v = 92) And sn < 8190 Then Poke SBUF + sn, 92 : sn = sn + 1
'|     If sn < 8190 Then Poke SBUF + sn, v : sn = sn + 1
'|   Next
'|   If sn < 8190 Then Poke SBUF + sn, 34 : sn = sn + 1
'| End Sub

' command k with one parameter, two
Sub C1(ByVal k As String Max 1, ByVal a As String)
  E k : EQ a : E ":"
End Sub
Sub C2(ByVal k As String Max 1, ByVal a As String, ByVal b As String)
  E k : EQ a : E "," : EQ b : E ":"
End Sub
' a parameter more (after the first)
Sub P1(ByVal a As String)
  E "," : EQ a
End Sub

Function H2(ByVal v As Integer) As String Max 2
#asm
            pop hl
            ld a, (hl)              ; v's low byte
            pop hl                  ; the result
            ld c, a
            rrca
            rrca
            rrca
            rrca
            and 15
            add a, #90
            daa
            adc a, #40
            daa
            ld (hl), a
            inc hl
            ld a, c
            and 15
            add a, #90
            daa
            adc a, #40
            daa
            ld (hl), a
            inc hl
            ld (hl), 0
#endasm
End Function
'| Function H2(ByVal v As Integer) As String Max 2
'|   H2 = Mid$("0123456789ABCDEF", ((v \ 16) And 15) + 1, 1) + Mid$("0123456789ABCDEF", (v And 15) + 1, 1)
'| End Function
Function H4(ByVal v As Integer) As String Max 4
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; DE = v
            pop hl                  ; the result
            ld b, 4
h4_lp:
            ld a, d
            rrca
            rrca
            rrca
            rrca
            and 15
            add a, #90
            daa
            adc a, #40
            daa
            ld (hl), a
            inc hl
            ex de, hl               ; DE = DE * 16 (the next digit on top)
            add hl, hl
            add hl, hl
            add hl, hl
            add hl, hl
            ex de, hl
            djnz h4_lp
            ld (hl), 0
#endasm
End Function
'| Function H4(ByVal v As Integer) As String Max 4
'|   Dim t As String Max 2
'|   t = H2(((v And &HFF00) \ 256) And 255)
'|   H4 = t + H2(v And 255)
'| End Function

' ---- the map

' the map file ([d:]name.ext) read through CP/M's BDOS (15, 20: 128 bytes a go) into MAPB: its
' lines, a 10 after each - empty lines, ; comments and the spaces before a line left out, a ^Z
' its end. 0: no such file
Function MapLoad(ByVal f As String Max 20) As Integer
  Dim j As Integer, c As Integer, ss As Integer, x As Integer
  MapLoad = 0
  For j = 0 To 35
    bb(j) = 0
  Next
  For j = 1 To 11
    bb(j) = 32
  Next
  If Mid$(f, 2, 1) = ":" Then bb(0) = Asc(f) - 64 : f = Mid$(f, 3)
  x = 1
  For j = 1 To Len(f)
    c = Asc(Mid$(f, j, 1))
    If c = 46 Then
      x = 9
    ElseIf x <= 11 Then
      bb(x) = c : x = x + 1
    End If
  Next
  r = CybSys.Bdos(26, VarPtr(dd))
  If CybSys.Bdos(15, VarPtr(bb)) = 255 Then Exit Function
  mf = f : mn = 0 : ss = 0                       ' (ss: 0 a line's start, 1 in it, 2 in a comment)
  Do While CybSys.Bdos(20, VarPtr(bb)) = 0
    For j = 0 To 127
      c = dd(j)
      If ss = 1 Then
        If c >= 32 Then
          If mn < MPN Then Poke MAPB + mn, c : mn = mn + 1
        ElseIf c = 10 Then
          If mn < MPN Then Poke MAPB + mn, 10 : mn = mn + 1
          ss = 0
        ElseIf c = 26 Then
          Exit Do
        End If
      ElseIf c = 10 Then
        ss = 0
      ElseIf c = 26 Then
        Exit Do
      ElseIf ss = 0 Then
        If c = 59 Then
          ss = 2
        ElseIf c > 32 Then
          ss = 1
          If mn < MPN Then Poke MAPB + mn, c : mn = mn + 1
        End If
      End If
    Next
  Loop
  If ss = 1 And mn < MPN Then Poke MAPB + mn, 10 : mn = mn + 1
  r = CybSys.Bdos(16, VarPtr(bb))                ' closed: CyborgOS reads one file at a time, for every
  MapLoad = -1                                   ' slot - left open, no other slot could open a file
End Function

' node n's description ("what it is": its line's text in quotes)
Function NodeDesc(ByVal n As Integer) As String Max 60
  Dim q As Integer
  q = mq : mq = nlp(n)
  NodeDesc = nid(n)
  Do While Tok()
    If tq Then NodeDesc = tk
  Loop
  mq = q
End Function

' the map's nodes (name, parameters, what it is, cat; their lines' place), cats and tools
Sub MapIndex()
  Dim c As Integer, j As Integer
  mq = 0 : nn = 0 : nc = 0 : ntb = 0 : pre = -1 : c = -1
  Do While mq < mn
    j = mq
    If Tok() Then
      If tk = "node" And nn < 48 Then
        If pre < 0 Then pre = j
        r = Tok() : nid(nn) = tk : npc(nn) = 0 : nca(nn) = c : nlp(nn) = mq
        Do While Tok()
          If tq = 0 Then npc(nn) = npc(nn) + 1
        Loop
        SkipLine
        npo(nn) = mq
        nn = nn + 1
      ElseIf tk = "cat" And nc < 12 Then
        If pre < 0 Then pre = j
        r = Tok() : cat(nc) = Left$(tk, 40) : c = nc : nc = nc + 1
      ElseIf tk = "tool" And ntb < 8 Then
        r = Tok() : tb(ntb) = "m:" + tk
        r = Tok() : tbn(ntb) = Left$(tk, 12)
        ntb = ntb + 1
      End If
    End If
    SkipLine
  Loop
  If pre < 0 Then pre = mn
  If ntb = 0 Then tb(0) = "m:home" : tbn(0) = "Home" : ntb = 1
  For j = 0 To ntb - 1                           ' each tool's key: its first capital letter
    tbk(j) = 0
    For c = 1 To Len(tbn(j))
      i = Asc(Mid$(tbn(j), c, 1))
      If i >= 65 And i <= 90 Then tbk(j) = i : Exit For
    Next
  Next
End Sub

' the next word of the line at mq into tk ("text": tq True, \x as x); False at the line's end
Function Tok() As Integer
  Dim c As Integer, p As Integer, n As Integer
  Tok = 0 : tk = "" : tq = 0
  Do While mq < mn
    c = Peek(MAPB + mq)
    If c <> 32 And c <> 9 Then Exit Do
    mq = mq + 1
  Loop
  If mq >= mn Then Exit Function
  If Peek(MAPB + mq) = 10 Then Exit Function
  p = VarPtr(tk) : n = 0
  If Peek(MAPB + mq) = 34 Then
    tq = -1 : mq = mq + 1
    Do While mq < mn
      c = Peek(MAPB + mq)
      If c = 34 Or c = 10 Then Exit Do
      If c = 92 Then mq = mq + 1 : c = Peek(MAPB + mq)
      If n < 80 Then Poke p + n, c : n = n + 1
      mq = mq + 1
    Loop
    If c = 34 Then mq = mq + 1
  Else
    Do While mq < mn
      c = Peek(MAPB + mq)
      If c <= 32 Then Exit Do
      If n < 80 Then Poke p + n, c : n = n + 1
      mq = mq + 1
    Loop
  End If
  Poke p + n, 0
  Tok = -1
End Function

Sub SkipLine()
  Do While mq < mn
    mq = mq + 1
    If Peek(MAPB + mq - 1) = 10 Then Exit Do
  Loop
End Sub

' a number: decimal, #hex, nK (K: 1024s)
Function Num(ByVal t As String Max 12) As Integer
  Dim j As Integer, v As Integer
  If Left$(t, 1) = "#" Then
    v = 0
    For j = 2 To Len(t)
      v = v * 16 + InStr("0123456789ABCDEF", UCase$(Mid$(t, j, 1))) - 1
    Next
    Num = v
  ElseIf UCase$(Right$(t, 1)) = "K" Then
    Num = Val(Left$(t, Len(t) - 1)) * 1024
  Else
    Num = Val(t)
  End If
End Function

' {1} {2} {3} (the node's parameters) and {s} (the slot) in t
Function Expand(ByVal t As String) As String
  Dim o As String Max 80, j As Integer, e As Integer, q As String Max 12
  If InStr(t, "{") = 0 Then Expand = t : Exit Function
  o = ""
  j = 1
  Do While j <= Len(t)
    e = 0
    If Mid$(t, j, 1) = "{" Then e = InStr(j, t, "}")
    If e > j Then
      q = Mid$(t, j + 1, e - j - 1)
      If q = "1" Or q = "2" Or q = "3" Then
        o = o + ag(Val(q) - 1)
      ElseIf q = "s" Then
        o = o + gs
      End If
      j = e + 1
    Else
      o = o + Mid$(t, j, 1)
      j = j + 1
    End If
  Loop
  Expand = o
End Function

' the source's start in MBUF (a table, a drive's files, 256 bytes of memory)
Sub Have()
  If hv Then Exit Sub
  hv = -1
  If sk = 1 Then
    CybSys.SetWord 2, MBUF                       ' (op 15: the raw table into MBUF)
    r = CybSys.Ask(15, sp1)
  ElseIf sk = 6 Then
    r = DirList()
  ElseIf sk > 1 Then
    r = Fetch(sad, 256)
  End If
End Sub

' a number 0-65535 (a word, negative from #8000) as text
Function NmU(ByVal v As Integer) As String Max 6
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)              ; DE = v (0-65535)
            pop hl                  ; the result
            ld ix, nu_pw
            ld c, 0                 ; C <> 0: a digit written (no 0s in front)
nu_pow:
            ld a, (ix + 0)
            or (ix + 1)
            jr z, nu_one
            ld b, '0' - 1
nu_sub:
            inc b                   ; DE - the power, as many times as it goes
            ld a, e
            sub (ix + 0)
            ld e, a
            ld a, d
            sbc a, (ix + 1)
            ld d, a
            jr nc, nu_sub
            ld a, e                 ; (one too many: back)
            add a, (ix + 0)
            ld e, a
            ld a, d
            adc a, (ix + 1)
            ld d, a
            ld a, b
            cp '0'
            jr nz, nu_dig
            inc c
            dec c
            jr z, nu_next           ; (a 0 in front: left out)
nu_dig:
            ld (hl), a
            inc hl
            ld c, 1
nu_next:
            inc ix
            inc ix
            jr nu_pow
nu_one:
            ld a, e
            add a, '0'
            ld (hl), a
            inc hl
            ld (hl), 0
            ret
nu_pw:      dw 10000, 1000, 100, 10, 0
#endasm
End Function
'| Function NmU(ByVal v As Integer) As String Max 6
'|   Dim q As Integer, d As Integer
'|   If v >= 0 Then NmU = Trim$(Str$(v)) : Exit Function
'|   q = (v And &H7FFF) \ 10 + 3276                 ' (32768 = 3276 x 10 + 8)
'|   d = (v And &H7FFF) Mod 10 + 8
'|   If d >= 10 Then q = q + 1 : d = d - 10
'|   NmU = Trim$(Str$(q)) + Chr$(48 + d)
'| End Function

' the page u (m:node/arg/arg~offset) as 8BML into sb
Sub Make(ByVal u As String Max 40)
  Dim p As String Max 40, j As Integer, n As Integer, a As Integer
  p = Mid$(u, 3)
  ao = 0
  j = InStr(p, "~")
  If j > 0 Then ao = Val(Mid$(p, j + 1)) : p = Left$(p, j - 1)
  For j = 0 To 3
    ag(j) = ""
  Next
  j = InStr(p, "/")
  n = 0
  If j > 0 Then
    s = Mid$(p, j + 1) : p = Left$(p, j - 1)
    Do While n < 4
      a = InStr(s, "/")
      If a = 0 Then ag(n) = Left$(s, 12) : n = n + 1 : Exit Do
      ag(n) = Left$(s, a - 1) : n = n + 1
      s = Mid$(s, a + 1)
    Loop
  End If
  n = -1
  For j = 0 To nn - 1
    If nid(j) = p Then n = j : Exit For
  Next
  sk = 0 : hv = 0 : nf = 0 : rsz = 0 : rfi = 0 : rba = 0 : cty = 0 : wko = -1 : wmx = 1000
  skt = 0 : dpn = 0 : gid = "" : ng = 0 : slb = 0 : nen = 0
  If n < 0 And p = "home" Then
    MkHome
  ElseIf n < 0 Then
    C2 "-", "1", "MON"
    C1 "t", "No such page in " + mf + ": " + u
  Else
    pt = Expand(NodeDesc(n))
    RunLines npo(n), mn, 1
    C2 "-", "1", pt
    C1 "p", pt
    E "n:"
    RunLines npo(n), mn, 2
  End If
  E "."
End Sub

' the home page: the map's lines before its first node or cat, then its nodes (those with no
' parameters) by cat
Sub MkHome()
  Dim j As Integer, c As Integer
  pt = "MON"
  RunLines 0, pre, 1
  C2 "-", "1", pt
  C1 "p", pt
  E "n:"
  RunLines 0, pre, 2
  c = -2
  For j = 0 To nn - 1
    If npc(j) = 0 Then
      If nca(j) <> c Then
        c = nca(j)
        E "n:"
        If c >= 0 Then C1 "s", cat(c) : E "n:"
      End If
      pt = NodeDesc(j)
      C2 "l", "m:" + nid(j), pt
    End If
  Next
End Sub

' the map's lines from p to e (or the next node / cat): pass 1 only the title, pass 2 the rest
Sub RunLines(ByVal p As Integer, ByVal pe As Integer, ByVal pass As Integer)
  Dim kw As String Max 8, t As String Max 80, j As Integer
  If pass = 2 Then sk = 0 : hv = 0 : nf = 0 : nen = 0
  mq = p
  Do While mq < pe
    If Tok() Then
      kw = Left$(tk, 8)
      If kw = "node" Or kw = "cat" Then Exit Do
      If pass = 1 Then
        If kw = "title" Then
          r = Tok() : pt = Left$(Expand(tk), 80)
        End If
      ElseIf kw = "text" Or kw = "sub" Or kw = "line" Then
        r = Tok()
        t = Expand(tk)
        If kw = "text" Then C1 "t", t
        If kw = "sub" Then C1 "s", t
        If kw = "line" Then C1 "r", t
      ElseIf kw = "gap" Then
        E "n:"
      ElseIf kw = "link" Then
        r = Tok()
        s = "m:" + tk
        Do While Tok()
          If tq Then Exit Do
          s = s + "/" + Expand(tk)
        Loop
        t = tk
        C2 "l", s, Expand(t)
      ElseIf kw = "src" Then
        DoSrc
      ElseIf kw = "deref" Then
        DoDeref
      ElseIf kw = "rec" Then
        r = Tok() : rsz = Num(tk)
        Do While Tok()
          If tk = "base" Then
            r = Tok() : rba = Num(tk)
          Else
            rfi = Num(tk)
          End If
        Loop
      ElseIf kw = "count" Then
        r = Tok()
        If tk = "b" Then
          cty = 1 : r = Tok() : cv = Num(tk)
        ElseIf tk = "w" Then
          cty = 2 : r = Tok() : cv = Num(tk)
        Else
          cty = 3 : cv = Num(tk)
        End If
      ElseIf kw = "walk" Then
        r = Tok() : r = Tok() : wko = Num(tk)
        If Tok() Then
          If tk = "max" Then r = Tok() : wmx = Num(tk)
        End If
      ElseIf kw = "skip" Then
        r = Tok() : skt = 1 - (tk = "w")
        r = Tok() : sko = Num(tk)
        r = Tok() : skv = Num(tk)
      ElseIf kw = "dup" Then
        r = Tok() : dpn = Num(tk)
      ElseIf kw = "f" Then
        DoField
      ElseIf kw = "go" Then
        r = Tok() : gid = Left$(tk, 12) : ng = 0
        Do While Tok()
          If ng < 4 Then ga(ng) = Left$(tk, 16) : ng = ng + 1
        Loop
      ElseIf kw = "view" Then
        r = Tok() : t = tk
        j = mq
        If t = "list" Then
          VList
        ElseIf t = "hex" Then
          VHex
        ElseIf t = "text" Then
          VText
        ElseIf t = "data" Then
          VData
        ElseIf t = "dis" Then                    ' (instructions: later - hex now)
          VHex
        ElseIf t = "words" Then
          VWords
        End If
        mq = j                                   ' (the layout used: the next view has its own)
        nf = 0 : nen = 0 : rsz = 0 : rfi = 0 : rba = 0 : cty = 0 : wko = -1 : skt = 0 : dpn = 0 : gid = ""
      End If
    End If
    SkipLine
  Loop
End Sub

' src kind ...: the source
Sub DoSrc()
  Dim t As String Max 8
  r = Tok() : t = Expand(tk)
  hv = 0 : sp1 = 0 : sad = 0
  sk = InStr("os  pagerom mainslotdir ", Left$(t + "    ", 4))
  If sk > 0 And ((sk - 1) And 3) = 0 Then sk = (sk - 1) \ 4 + 1 Else sk = 0
  If sk = 1 Then
    r = Tok() : sp1 = Num(Expand(tk))
  ElseIf sk = 6 Then
    r = Tok() : sp1 = Asc(UCase$(Expand(tk)))
  ElseIf sk > 1 Then
    r = Tok() : sp1 = Num(Expand(tk))
    r = Tok() : sad = Num(Expand(tk))
    slb = 32767
    If Tok() Then slb = Num(Expand(tk))
    If slb <= 0 Then slb = 32767                  ' (32K or more)
    If sk = 2 Then sad = sad And &H3FFF
    If sk = 3 Then sad = sad Or &HC000
  End If
End Sub

' deref w off [len]: the source's address the word at off in it
Sub DoDeref()
  Dim o As Integer, v As Integer
  r = Tok() : r = Tok() : o = Num(tk)
  If sk < 2 Or sk > 5 Then Exit Sub
  v = 0
  If Fetch(sad + o, 2) = 0 Then v = Peek(MBUF) + Peek(MBUF + 1) * 256
  sad = v : hv = 0
  If Tok() Then slb = Num(tk)
  If slb <= 0 Then slb = 32767
  If v = 0 Then sk = 0
  If sk = 3 And (v And &HC000) <> &HC000 Then sk = 0
End Sub

' f "heading" type off ...: a column
Sub DoField()
  Dim t As String Max 8
  If nf > 7 Then Exit Sub
  r = Tok() : fh(nf) = Left$(tk, 16)
  r = Tok() : t = tk
  ft(nf) = InStr(" b   w   hb  hw  a   #   s   sl  n7  fn  ver c  ", " " + Left$(t + "   ", 3))
  ft(nf) = (ft(nf) + 3) \ 4                       ' (b 1, w 2, hb 3 ... c 12; 0 none)
  fo(nf) = 0 : fl(nf) = 0 : fx2(nf) = 1 : fu(nf) = "" : fm(nf) = 0 : fes(nf) = nen : fec(nf) = 0
  If ft(nf) <> 5 And ft(nf) <> 6 Then
    r = Tok() : fo(nf) = Num(tk)
    If ft(nf) = 7 Or ft(nf) = 8 Then r = Tok() : fl(nf) = Num(tk)
  End If
  Do While Tok()
    If tq Then
      fu(nf) = Left$(tk, 6)
    ElseIf tk = "enum" Then
      r = Tok() : EnumSet tk
    ElseIf tk = "mask" Then
      r = Tok() : fm(nf) = Num(tk)
    ElseIf Left$(tk, 1) = "x" Then
      fx2(nf) = Val(Mid$(tk, 2))
    End If
  Loop
  nf = nf + 1
End Sub

' ---- the data: through CyborgOS into MBUF

' n bytes (2K at most) at a of the source (a page, ROM, main RAM, a slot's memory): 0 done
Function Fetch(ByVal a As Integer, ByVal n As Integer) As Integer
  Dim kd As Integer
  kd = sk - 2
  If kd < 0 Or kd > 3 Then Fetch = 255 : Exit Function
  If kd = 0 Then a = (a And &H3FFF) Or &H4000
  Fetch = RdTo(kd, sp1, a, n, MBUF)
End Function

' n bytes (2K at most) of memory to d: kind 0 a 16K page, 1 an upper ROM, 2 main RAM, 3 a slot's
Function RdTo(ByVal kind As Integer, ByVal pg As Integer, ByVal a As Integer, ByVal n As Integer, ByVal d As Integer) As Integer
  CybSys.SetWord 2, pg
  CybSys.SetWord 4, a
  CybSys.SetWord 6, d
  CybSys.SetWord 8, n
  RdTo = CybSys.Ask(10, kind)
End Function

' drive sp1's files (BDOS 17, 18: ????????.???) into MBUF, 16 bytes each (the directory entry's
' first 16: the name at 1, its records at 15): how many (128 at most)
Function DirList() As Integer
  Dim j As Integer, n As Integer
  bb(0) = sp1 - 64
  For j = 1 To 11
    bb(j) = 63
  Next
  For j = 12 To 35
    bb(j) = 0
  Next
  r = CybSys.Bdos(26, VarPtr(dd))
  n = 0
  r = CybSys.Bdos(17, VarPtr(bb))
  Do While r <> 255 And n < 128
    For j = 0 To 15
      Poke MBUF + n * 16 + j, dd((r And 3) * 32 + j)
    Next
    n = n + 1
    r = CybSys.Bdos(18, VarPtr(bb))
  Loop
  DirList = n
End Function

' ---- the views

' the records as a table: a window of RP rows from record ao, each a link (go) when there is one
Sub VList()
  Dim n As Integer, i0 As Integer, i1 As Integer, j As Integer, a As Integer, x As Integer, w As Integer
  Dim u As String Max 60, ok As Integer
  If sk = 0 Or rsz < 1 Or nf = 0 Then C1 "t", "Nothing there" : Exit Sub
  ' how many
  n = 0
  If sk = 6 Then
    n = DirList() : hv = -1
  ElseIf sk = 1 Then
    Have
  End If
  If cty = 3 Then
    n = cv
  ElseIf cty > 0 Then
    If sk = 1 Or sk = 6 Then
      a = MBUF + cv
    Else
      If Fetch(sad + cv, 2) <> 0 Then C1 "t", "Not there" : Exit Sub
      a = MBUF
    End If
    n = Peek(a)
    If cty = 2 Then n = n + Peek(a + 1) * 256
  ElseIf sk <> 6 Then
    If sk = 1 Then n = (2048 - rfi) \ rsz Else n = (slb - rfi) \ rsz
  End If
  If wko >= 0 Then n = wmx
  If ao < 0 Then ao = 0
  i0 = ao
  If i0 >= n Then i0 = 0
  i1 = i0 + RP - 1
  wi0 = i0 : wen = 0
  If i1 > n - 1 Then i1 = n - 1
  ' the window's records into MBUF
  If wko >= 0 Then
    i1 = Walk(i0, i1)
  ElseIf sk > 1 And sk < 6 Then
    j = (i1 - i0 + 1)
    If j * rsz > 2048 Then j = 2048 \ rsz : i1 = i0 + j - 1
    If Fetch(sad + rfi + i0 * rsz, j * rsz) <> 0 Then C1 "t", "Not there" : Exit Sub
  End If
  hv = 0
  ' the table
  E "v" : EQ NmU(nf)
  For j = 0 To nf - 1
    P1 "" : P1 fh(j)
  Next
  w = 0
  For i = i0 To i1
    a = RecAt(i, i0)
    ok = -1
    If skt = 1 Then
      If Peek(a + sko) = skv Then ok = 0
    ElseIf skt = 2 Then
      If Peek(a + sko) + Peek(a + sko + 1) * 256 = skv Then ok = 0
    End If
    If ok And dpn > 0 And i > 0 And (sk = 1 Or sk = 6 Or i0 = 0) Then
      x = RecAt(0, i0)
      ok = 0
      For j = 0 To dpn - 1
        If Peek(a + j) <> Peek(x + j) Then ok = -1 : Exit For
      Next
    End If
    If ok Then
      u = ""
      If gid <> "" Then u = RowUrl(a, i)
      P1 u : P1 FV(0, a, i)
      For j = 1 To nf - 1
        P1 "" : P1 FV(j, a, i)
      Next
      w = w + 1
    End If
  Next
  E ":"
  If w = 0 Then C1 "t", "(none)"
  If i1 < n - 1 And i1 >= i0 And wen = 0 Then
    u = Here(i1 + 1)
    C2 "l", u, "more >>"
  End If
End Sub

' this page again from record (or 1K) o
Function Here(ByVal o As Integer) As String Max 40
  Dim t As String Max 60
  t = cu
  If InStr(t, "~") > 0 Then t = Left$(t, InStr(t, "~") - 1)
  Here = t + "~" + NmU(o)
End Function

' record i's place in MBUF (the window from i0)
Function RecAt(ByVal i As Integer, ByVal i0 As Integer) As Integer
  If sk = 1 Or sk = 6 Then
    RecAt = MBUF + rfi + i * rsz
  Else
    RecAt = MBUF + (i - i0) * rsz
  End If
End Function

' record i's address in the source
Function RecAddr(ByVal i As Integer) As Integer
  If wko >= 0 Then
    RecAddr = wv(i - wi0)
  Else
    RecAddr = sad + rfi + i * rsz
  End If
End Function

' a linked list's records i0 to i1 into MBUF (each rsz bytes, the next's address at wko): the last
' one there (wen True: the list ended - a 0, an address seen again, not there)
Function Walk(ByVal i0 As Integer, ByVal i1 As Integer) As Integer
  Dim a As Integer, j As Integer, x As Integer, t As Integer
  a = sad + rfi
  For j = 1 To i0                                ' (to the window: the pointers only)
    If Fetch(a + wko, 2) <> 0 Then a = 0 Else a = Peek(MBUF) + Peek(MBUF + 1) * 256
    If a = 0 Or a = sad + rfi Then wen = -1 : Walk = i0 - 1 : Exit Function
  Next
  t = 0
  For j = i0 To i1
    If a = 0 Or t * rsz + rsz > 2048 Or t > 63 Then Exit For
    For x = 0 To t - 1
      If wv(x) = a Then a = 0
    Next
    If a = 0 Then Exit For
    If RdTo(sk - 2, sp1, a, rsz, MBUF + t * rsz) <> 0 Then a = 0 : Exit For
    wv(t) = a
    a = Peek(MBUF + t * rsz + wko) + Peek(MBUF + t * rsz + wko + 1) * 256
    t = t + 1
  Next
  If a = 0 Then wen = -1
  Walk = i0 + t - 1
End Function

' a row's link: go's node and args ({#} {@} {heading} {1} {2} {3} {s})
Function RowUrl(ByVal a As Integer, ByVal i As Integer) As String Max 60
  Dim u As String Max 60, q As String Max 16, j As Integer, x As Integer
  u = "m:" + gid
  For j = 0 To ng - 1
    q = ga(j)
    If Left$(q, 1) = "{" And Right$(q, 1) = "}" Then
      q = Mid$(q, 2, Len(q) - 2)
      If q = "#" Then
        q = NmU(i + rba)
      ElseIf q = "@" Then
        q = "#" + H4(RecAddr(i))
      ElseIf q = "1" Or q = "2" Or q = "3" Then
        q = ag(Val(q) - 1)
      ElseIf q = "s" Then
        q = gs
      Else
        For x = 0 To nf - 1
          If fh(x) = q Then Exit For
        Next
        If x < nf Then q = FRaw(x, a, i) Else q = ""
      End If
    End If
    u = u + "/" + q
  Next
  RowUrl = u
End Function

' column j of the record at a (number i): as it is shown, as it goes in a link
Function FV(ByVal j As Integer, ByVal a As Integer, ByVal i As Integer) As String Max 40
  Dim v As Integer, t As String Max 40, y As Integer
  y = ft(j)
  If y = 1 Or y = 2 Then
    v = Peek(a + fo(j))
    If y = 2 Then v = v + Peek(a + fo(j) + 1) * 256
    t = ""
    If fec(j) > 0 Then
      t = EnumOf(j, v)
      If t = "" And fm(j) <> 0 Then t = EnumOf(j, v And fm(j))
    End If
    If t = "" Then t = NmU(v * fx2(j))
  Else
    t = FRaw(j, a, i)
  End If
  FV = t + fu(j)
End Function

Function FRaw(ByVal j As Integer, ByVal a As Integer, ByVal i As Integer) As String Max 40
  Dim v As Integer, t As String Max 40, x As Integer, p As Integer, n As Integer
  p = a + fo(j)
  t = ""
  Select Case ft(j)
    Case 1
      t = NmU(Peek(p))
    Case 2
      t = NmU(Peek(p) + Peek(p + 1) * 256)
    Case 3
      t = "#" + H2(Peek(p))
    Case 4
      t = "#" + H4(Peek(p) + Peek(p + 1) * 256)
    Case 5
      t = "#" + H4(RecAddr(i))
    Case 6
      t = NmU(i + rba)
    Case 7, 8, 9
      n = fl(j)
      If ft(j) = 8 Then n = Peek(a + n)
      If ft(j) = 9 Then n = 16
      If n > 40 Then n = 40
      For x = 0 To n - 1
        v = Peek(p + x)
        If v = 0 Then Exit For
        If (v And 127) >= 32 Then t = t + Chr$(v And 127)
        If ft(j) = 9 And v >= 128 Then Exit For
      Next
    Case 10
      For x = 0 To 10
        v = Peek(p + x) And 127
        If x = 8 And v > 32 Then t = t + "."
        If v > 32 Then t = t + Chr$(v)
      Next
    Case 11
      t = NmU(Peek(p)) + "."
      t = t + NmU(Peek(p + 1))
      t = t + NmU(Peek(p + 2))
    Case 12
      t = Chr$(Peek(p))
  End Select
  FRaw = t
End Function

' column nf's enum e ("a,b,c": by place; "0=a,5=b": by value) into ev, en
Sub EnumSet(ByVal e As String)
  Dim j As Integer, c As Integer, q As String Max 40, x As Integer, k As Integer
  j = 1 : k = 0
  Do While j <= Len(e) And nen < 48
    c = InStr(j, e + ",", ",")
    q = Mid$(e, j, c - j)
    x = InStr(q, "=")
    If x > 0 Then
      ev(nen) = Num(Left$(q, x - 1)) : en(nen) = Left$(Mid$(q, x + 1), 20)
    Else
      ev(nen) = k : en(nen) = Left$(q, 20)
    End If
    nen = nen + 1 : fec(nf) = fec(nf) + 1 : k = k + 1
    j = c + 1
  Loop
End Sub

' column j's name for v; "" none
Function EnumOf(ByVal j As Integer, ByVal v As Integer) As String Max 20
  Dim x As Integer
  EnumOf = ""
  For x = fes(j) To fes(j) + fec(j) - 1
    If ev(x) = v Then EnumOf = en(x) : Exit Function
  Next
End Function

' one record (the source's start, or record ao): each column a line, heading: value
Sub VData()
  Dim j As Integer, a As Integer
  If sk = 0 Or nf = 0 Then C1 "t", "Nothing there" : Exit Sub
  If rsz < 1 Then rsz = 256
  If sk = 1 Or sk = 6 Then
    Have
  ElseIf Fetch(sad + rfi + ao * rsz, rsz) <> 0 Then
    C1 "t", "Not there" : Exit Sub
  End If
  wi0 = ao : hv = 0
  a = RecAt(ao, ao)
  For j = 0 To nf - 1
    C1 "r", Left$(fh(j) + ":" + Space$(18), 18) + FV(j, a, ao)
  Next
End Sub

' the << 1K / 1K >> links, then 1K at a into MBUF: True when it isn't there
Function Nav(ByVal a As Integer) As Integer
  Dim t As String Max 40
  E ">"
  t = Here(ao - 1)
  EQ t : P1 "<< 1K"
  t = Here(ao + 1)
  P1 t : P1 "1K >>"
  E ":"
  Nav = (Fetch(a, 1024) <> 0)
  If Nav Then C1 "t", "Not there"
End Function

' 1K of the source from its address + ao K, in hex: 64 lines of 16
Sub VHex()
  Dim a As Integer
  If sk < 2 Or sk > 5 Then C1 "t", "Nothing there" : Exit Sub
  a = (sad And &HFC00) + ao * 1024
  If sk = 2 Then a = a And &H3FFF
  If sk = 3 Then a = a Or &HC000
  If Nav(a) Then Exit Sub
  HexRows a
End Sub
'| Sub VHex()
'|   Dim j As Integer, x As Integer, v As Integer, h As String Max 60, t As String Max 30, a As Integer
'|   If sk < 2 Or sk > 5 Then C1 "t", "Nothing there" : Exit Sub
'|   a = (sad And &HFC00) + ao * 1024
'|   If sk = 2 Then a = a And &H3FFF
'|   If sk = 3 Then a = a Or &HC000
'|   If Nav(a) Then Exit Sub
'|   For j = 0 To 63
'|     h = H4(a + j * 16) + "  "
'|     t = ""
'|     For x = 0 To 15
'|       v = Peek(MBUF + j * 16 + x)
'|       h = h + H2(v)
'|       h = h + " "
'|       If v >= 32 And v < 127 Then t = t + Chr$(v) Else t = t + "."
'|     Next
'|     C1 "r", h + " " + t
'|   Next
'| End Sub

' HexRows(a): MBUF's 1K as 64 r lines - r"AAAA  hh hh .. hh  text": (AAAA from a, 16 a line; text:
' 32-126 as they are, the rest ".", " and \ after a \)
Sub HexRows(ByVal a As Integer)
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            ld (hx_adr), de         ; the address shown
            ld (hx_sp), sp
            ld sp, (ntc_csp)        ; (the real stack: hx_put is called)
            ld hl, 8190
            ld bc, ({sn})
            or a
            sbc hl, bc
            ld b, h
            ld c, l                 ; BC = room left
            ld hl, ({sn})
            ld de, {SBUF}
            add hl, de              ; HL = SBUF + sn
            ld ix, {MBUF}
            ld a, 64
hx_row:
            push af
            ld a, 'r'
            call hx_put
            ld a, 34
            call hx_put
            ld a, (hx_adr + 1)
            call hx_hex
            ld a, (hx_adr)
            call hx_hex
            ld a, ' '
            call hx_put
            call hx_put
            ld e, 16
hx_byte:
            ld a, (ix + 0)
            call hx_hex
            ld a, ' '
            call hx_put
            inc ix
            dec e
            jr nz, hx_byte
            call hx_put             ; (A: a space)
            ld de, -16
            add ix, de
            ld e, 16
hx_text:
            ld a, (ix + 0)
            cp 32
            jr c, hx_dot
            cp 127
            jr c, hx_ch
hx_dot:
            ld a, '.'
hx_ch:
            cp 34
            jr z, hx_esc
            cp 92
            jr nz, hx_one
hx_esc:
            push af
            ld a, 92
            call hx_put
            pop af
hx_one:
            call hx_put
            inc ix
            dec e
            jr nz, hx_text
            ld a, 34
            call hx_put
            ld a, ':'
            call hx_put
            push hl
            ld hl, (hx_adr)
            ld de, 16
            add hl, de
            ld (hx_adr), hl
            pop hl
            pop af
            dec a
            jr nz, hx_row
            ld bc, -{SBUF}
            add hl, bc
            ld ({sn}), hl
            ld sp, (hx_sp)
            ret
hx_hex:                             ; A as 2 hex digits
            push af
            rrca
            rrca
            rrca
            rrca
            call hx_dig
            pop af
hx_dig:
            and 15
            add a, #90
            daa
            adc a, #40
            daa
hx_put:                             ; A into the page when there is room
            push af
            ld a, b
            or c
            jr z, hx_full
            pop af
            ld (hl), a
            inc hl
            dec bc
            ret
hx_full:
            pop af
            ret
hx_sp:      dw 0
hx_adr:     dw 0
#endasm
End Sub

' 1K of the source from its address + ao K as text (lines at CR / LF, cut at the width)
Sub VText()
  Dim a As Integer
  If sk < 2 Or sk > 5 Then C1 "t", "Nothing there" : Exit Sub
  a = sad + ao * 1024
  If Nav(a) Then Exit Sub
  TextRows
End Sub
'| Sub VText()
'|   Dim j As Integer, v As Integer, t As String Max 80, a As Integer
'|   If sk < 2 Or sk > 5 Then C1 "t", "Nothing there" : Exit Sub
'|   a = sad + ao * 1024
'|   If Nav(a) Then Exit Sub
'|   t = ""
'|   For j = 0 To 1023
'|     v = Peek(MBUF + j)
'|     If v = 10 Or v = 13 Then
'|       If v = 10 Or Len(t) > 0 Then C1 "r", t
'|       t = ""
'|     Else
'|       If v >= 32 And v < 127 Then t = t + Chr$(v) Else t = t + "."
'|       If Len(t) >= VW Then C1 "r", t : t = ""
'|     End If
'|   Next
'|   If t <> "" Then C1 "r", t
'| End Sub

' TextRows: MBUF's 1K as r lines - a line at each 10 (13 then 10 one line), and after VW
' characters; 32-126 as they are, the rest "."; " and \ after a \
Sub TextRows()
#asm
            ld (tx_sp), sp
            ld sp, (ntc_csp)        ; (the real stack: tx_put is called)
            ld hl, 8190
            ld bc, ({sn})
            or a
            sbc hl, bc
            ld b, h
            ld c, l                 ; BC = room left
            ld hl, ({sn})
            ld de, {SBUF}
            add hl, de              ; HL = SBUF + sn
            ld ix, {MBUF}
            ld de, 1024
            xor a
            ld (tx_len), a          ; the line's characters (0: none - no r" yet)
            ld (tx_op), a           ; (r" written)
tx_lp:
            ld a, (ix + 0)
            cp 10
            jr z, tx_lf
            cp 13
            jr z, tx_cr
            cp 32
            jr c, tx_dot
            cp 127
            jr c, tx_ch
tx_dot:
            ld a, '.'
tx_ch:
            push af
            call tx_open
            pop af
            cp 34
            jr z, tx_esc
            cp 92
            jr nz, tx_one
tx_esc:
            push af
            ld a, 92
            call tx_put
            pop af
tx_one:
            call tx_put
            ld a, (tx_len)
            inc a
            ld (tx_len), a
            cp {VW}
            call nc, tx_close       ; (VW characters: the line ends)
            jr tx_next
tx_lf:
            call tx_open            ; (an empty line too)
            call tx_close
            jr tx_next
tx_cr:
            ld a, (tx_len)
            or a
            call nz, tx_close
tx_next:
            inc ix
            dec de
            ld a, d
            or e
            jr nz, tx_lp
            ld a, (tx_len)
            or a
            call nz, tx_close
            ld bc, -{SBUF}
            add hl, bc
            ld ({sn}), hl
            ld sp, (tx_sp)
            ret
tx_open:                            ; r" when the line hasn't one yet
            ld a, (tx_len)
            or a
            ret nz
            ld a, (tx_op)
            or a
            ret nz
            ld a, 1
            ld (tx_op), a
            ld a, 'r'
            call tx_put
            ld a, 34
            jr tx_put
tx_close:                           ; ": - the line ends
            xor a
            ld (tx_len), a
            ld (tx_op), a
            ld a, 34
            call tx_put
            ld a, ':'
tx_put:                             ; A into the page when there is room
            push af
            ld a, b
            or c
            jr z, tx_full
            pop af
            ld (hl), a
            inc hl
            dec bc
            ret
tx_full:
            pop af
            ret
tx_sp:      dw 0
tx_len:     db 0
tx_op:      db 0
#endasm
End Sub

' the source's names (letters, the last + #80; a 0 ends them), 16 characters a column
Sub VWords()
  Dim x As Integer, v As Integer, t As String Max 20, n As Integer, o As String Max 80, m As Integer
  If sk < 2 Or sk > 5 Then C1 "t", "None" : Exit Sub
  m = slb
  If m > 2048 Then m = 2048
  If Fetch(sad, m) <> 0 Then C1 "t", "Not there" : Exit Sub
  x = 0 : t = "" : o = "" : n = 0
  Do While x < m
    v = Peek(MBUF + x)
    If v = 0 Then Exit Do
    t = t + Chr$(v And 127)
    If v >= 128 Or Len(t) >= 16 Then
      If Len(o) + 16 > VW Then C1 "r", o : o = ""
      o = o + Left$(t + Space$(16), 16)
      t = "" : n = n + 1
    End If
    x = x + 1
  Loop
  If o <> "" Then C1 "r", o
  E "n:"
  C1 "t", NmU(n) + " names"
End Sub

