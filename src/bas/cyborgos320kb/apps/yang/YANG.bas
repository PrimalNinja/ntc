' YANG: a web browser for CyborgOS 320K - YING (apps/ying) on MON2's whole screen (apps/mon2: the
' toolbar on row 0, the page on rows 1-23, the hardware scroll a line at a time). The same
' browser, the same keys; only the screen differs. Build for cpm with ../ying/Web.cls,
' ../mon/Bml.cls, ../mon/Mouse.cls and cmds/CybSys.cls; a .CYB. Tabs are CyborgOS's slots.
'   YANG                HOME.8BM (this drive, else A:, else Z:)
'   YANG address        that page
' Addresses (Web.cls): http://host[:port]/path?parameters - http only, no https; asked for as
' 8BML (an empty 8bml parameter added to the request, never shown). For now the fetch is a
' stub: a made-up test page. A file - A:NAME.8BM, NAME.8BM, file:NAME.EXT - is read from the
' disc: local pages linked to each other, like AmigaGuide (its links from the page's drive).
'
' The screen: MODE F (84 x 24, all of it YANG's), its own put back at the end. Row 0 the toolbar
' (Back, Reload, Home, Go to, Quit), then the chosen link's address - or the page's - and the
' line; where an address is typed (Go to). Rows 1-23 the page (80 columns), column 81 the
' current line's <, column 83 the scroll bar. Keys: Tab / right next link, left the one before,
' up / down the line (the page scrolls), Shift + up / down a page, Control + up / down the top /
' end, Enter or Copy the link, 1-5 or a tool's capital letter the toolbar (G: an address typed -
' Enter goes, ESC not), B or DEL back, R again, Q or ESC quits. The mouse: the pointer follows
' it; left button: a link, the toolbar, the scroll bar
Option Explicit
Option Terminal VT52              ' (CyborgOS's console: Locate and Cls as ESC Y, ESC E)
Const SBUF = &HA000               ' 8K: the page's 8BML (Bml's links point into it)
Const LBUF = &HD000               ' 4K: Bml's lines on their way to and from the store (2 blocks)
Const VR = 23                     ' the page's rows on the screen (1-23: row 0 is the toolbar's)
Const VW = 80                     ' and its columns (0-79)
Const EY = 0                      ' the address box: row, column, width (the toolbar's row)
Const EX = 0
Const EW = 83
Const MD = 3                      ' the mouse: its counts a character cell
Dim sn As Integer                            ' the page's 8BML: its length (at SBUF)
Dim hs(15) As String Max 80, hn As Integer   ' the pages before (B goes back)
Dim cu As String Max 80                      ' this page's address
Dim hm As String Max 80                      ' the home page's (the command line's, else HOME.8BM)
Dim tp As Integer, cl As Integer, sl As Integer   ' the first line shown, the current line, the link chosen (-1 none)
Dim ol As Integer, os As Integer             ' ... as they were last drawn
Dim px As Integer, py As Integer, fx As Integer, fy As Integer, pv As Integer, pb As Integer, idle As Integer
Dim ms As Integer, qt As Integer, m0 As Integer, k As Integer, r As Integer, i As Integer
Dim tbn(7) As String Max 12, tbc(7) As Integer, tbk(7) As Integer, ntb As Integer   ' the toolbar: names, columns, keys
Dim st As String Max 80, s As String Max 80
Dim hsp As Integer
Dim eb(3) As Byte                            ' ESC Y row col, ESC I, LF: to the console raw (PutMem)

m0 = CybSys.Ask(9, 255)
If m0 > 5 Then Print "YANG needs CyborgOS 320K" : End
hm = Trim$(System.CommandLine())
If hm = "" Then hm = Web.Home()
r = CybSys.Ask(9, 5)                         ' MODE F
k = Bml.Init(LBUF, 2, VW)
ms = Mouse.Present()
px = 40 : py = 12
st = ""
Tools
Go hm, 0
Do
  k = Inkey
  If ms Then MousePoll
  If k <> 0 Then KeyIn k
Loop Until qt
PtrOff
r = CybSys.Ask(9, m0)                        ' the mode YANG found (its console cleared)
End

' ---- the screen

' the cursor to row y, column x (0 based)
' (VT52 ESC Y row col straight to the console, through PutMem: Locate stops at column 80 and
' Print turns ESC into ?; MON2 uses all 84 columns)
Sub At(ByVal y As Integer, ByVal x As Integer)
  eb(0) = 27 : eb(1) = 89 : eb(2) = 32 + y : eb(3) = 32 + x
  PutMem VarPtr(eb), 4
End Sub

' everything: the screen cleared (the hardware scroll back to the start), the page, the toolbar
Sub DrawAll()
  PtrOff
  Cls
  DrawPage
  DrawBar
  PtrOn
End Sub


' the page's lines on rows 1-23 (line tp + row), the < at the current line, the scroll bar, the
' chosen link marked
Sub DrawPage()
  Dim j As Integer
  For j = 1 To VR
    PutLine j
  Next
  LinkMark
  ol = cl : os = sl
End Sub

' row y: its page line (tp + y; spaces past the end), its < and its piece of the scroll bar
Sub PutLine(ByVal y As Integer)
  Dim n As Integer, ln As Integer
  n = Bml.Lines()
  ln = tp + y
  At y, 0
  If ln >= 0 And ln < n Then
    PutMem Bml.LineAddr(ln), VW
  Else
    Print Space$(VW);
  End If
  If ln = cl Then Print " < "; Else Print "   ";
  If y < VR Then Print BarCh(y);
End Sub

' the scroll bar's character on row y (1-22): ^, v, # the lines shown, : the rest
Function BarCh(ByVal y As Integer) As String Max 1
  Dim n As Integer, b0 As Integer, b1 As Integer
  BarCh = ":"
  If y = 1 Then BarCh = "^" : Exit Function
  If y = VR - 1 Then BarCh = "v" : Exit Function
  n = Bml.Lines()
  b0 = 0 : b1 = VR - 4                           ' the thumb: rows 2 to VR - 2 (0 to VR - 4 of it)
  If n > VR Then
    b0 = ((tp + 1) * (VR - 3)) \ n
    b1 = ((tp + 1 + VR) * (VR - 3)) \ n
    If b1 > VR - 4 Then b1 = VR - 4
  End If
  If y - 2 >= b0 And y - 2 <= b1 Then BarCh = "#"
End Function

' the scroll bar again (column 83, rows 1-22)
Sub DrawBarCol()
  Dim j As Integer
  For j = 1 To VR - 1
    At j, 83 : Print BarCh(j);
  Next
End Sub

' the toolbar (row 0): the tools, then st - else the chosen link's URL, else the page's - and the
' line / lines. All 84 columns (row 0: the console's next row after it is row 1, no scroll)
Sub DrawBar()
  Dim j As Integer, t As String Max 80, u As String Max 80
  s = ""
  For j = 0 To ntb - 1
    tbc(j) = Len(s)
    s = s + Chr$(49 + j) + ":" + tbn(j) + " "
  Next
  t = st
  If t = "" And sl >= 0 Then t = LinkAt(sl)
  If t = "" Then t = cu
  u = Str$(cl + 1) + " /" + Str$(Bml.Lines())
  s = Left$(s + "| " + t, 82 - Len(u))
  At 0, 0
  Print s; Space$(83 - Len(s) - Len(u)); u; " ";
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
  If py = 0 Then
    For j = ntb - 1 To 0 Step -1
      If px >= tbc(j) Then Tool j : Exit Sub
    Next
  ElseIf py >= 1 And py <= VR - 1 And px = 83 Then
    If py = 1 Then
      Scroll -1
    ElseIf py = VR - 1 Then
      Scroll 1
    ElseIf (py - 2) * Bml.Lines() \ (VR - 3) < tp + 1 Then
      Scroll -VR
    Else
      Scroll VR
    End If
  ElseIf py >= 1 And px < VW Then
    y = tp + py
    For j = 0 To Bml.Links() - 1
      If Bml.LinkLine(j) = y And px >= Bml.LinkCol(j) And px < Bml.LinkCol(j) + Bml.LinkLen(j) Then
        sl = j : cl = y
        OpenLink
        Exit Sub
      End If
    Next
    If y >= 0 And y < Bml.Lines() Then cl = y : Follow
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
      tp = -1 : cl = 0 : Redraw
    Case 249
      cl = Bml.Lines() - 1 : tp = cl - VR
      If tp < -1 Then tp = -1
      Redraw
    Case 13, 224                                 ' Enter, Copy
      OpenLink
    Case 66, 127, 8                              ' B, DEL: back
      Back
    Case 82                                      ' R: again
      Go cu, 0
    Case 49 To 56                                ' 1-8: the toolbar
      If k - 49 < ntb Then Tool k - 49
    Case Else                                    ' a tool's letter
      For j = 0 To ntb - 1
        If tbk(j) = k Then Tool j : Exit For
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

' the current line on the screen (rows 1-23: lines tp + 1 to tp + VR): a line off either end -
' the hardware scroll, a line; further - drawn again; else only the markers and the toolbar
Sub Follow()
  If cl <= tp Then
    Scroll cl - tp - 1
  ElseIf cl > tp + VR Then
    Scroll cl - tp - VR
  Else
    PtrOff
    Marks
    DrawBar
    PtrOn
  End If
End Sub

' the markers again: the old ones off (the lines they were on drawn again), the new ones on
Sub Marks()
  Dim y As Integer
  If ol > tp And ol <= tp + VR And ol <> cl Then At ol - tp, VW + 1 : Print " ";
  At cl - tp, VW + 1 : Print "<";
  If os >= 0 And os <> sl Then
    y = Bml.LinkLine(os) - tp
    If y >= 1 And y <= VR Then At y, 0 : PutMem Bml.LineAddr(tp + y), VW
  End If
  LinkMark
  ol = cl : os = sl
End Sub

' the chosen link's > < (on the line's characters next to it)
Sub LinkMark()
  Dim y As Integer, c As Integer
  If sl < 0 Then Exit Sub
  y = Bml.LinkLine(sl) - tp
  If y < 1 Or y > VR Then Exit Sub
  c = Bml.LinkCol(sl)
  If c > 0 Then At y, c - 1 : Print ">";
  c = c + Bml.LinkLen(sl)
  If c < VW Then At y, c : Print "<";
End Sub

' the page d lines on (back when d < 0): one line - the console's hardware scroll (a line feed
' on row 23, or ESC I on row 0) and the line it brings in; more - drawn again
Sub Scroll(ByVal d As Integer)
  Dim n As Integer, t0 As Integer
  n = Bml.Lines()
  t0 = tp
  tp = tp + d
  If tp > n - VR - 1 Then tp = n - VR - 1
  If tp < -1 Then tp = -1
  If cl <= tp Then cl = tp + 1
  If cl > tp + VR Then cl = tp + VR
  If tp = t0 Then Follow2 : Exit Sub
  If tp = t0 + 1 Then
    PtrOff
    At VR, 0
    eb(0) = 10 : PutMem VarPtr(eb), 1         ' on (a line feed): row 0 (the toolbar) goes off the top
    PutLine VR
    Marks2
  ElseIf tp = t0 - 1 Then
    PtrOff
    t0 = tp : tp = tp + 1
    PutLine 0                                    ' back: the toolbar is its page line again
    tp = t0                                      ' (row 1 after the scroll)
    At VR - 1, 83 : Print " ";                   ' (row 22's v: on row 23 after it, where it can't be written)
    At 0, 0
    eb(0) = 27 : eb(1) = 73 : PutMem VarPtr(eb), 2   ' ESC I
    Marks2
  Else
    Redraw
  End If
End Sub

' after a hardware scroll: the markers, the scroll bar, the toolbar on row 0 again
Sub Marks2()
  Marks
  DrawBarCol
  DrawBar
  PtrOn
End Sub

' the markers and the toolbar (the page didn't move)
Sub Follow2()
  PtrOff
  Marks
  DrawBar
  PtrOn
End Sub

Sub Redraw()
  PtrOff
  DrawPage
  DrawBar
  PtrOn
End Sub

' the chosen link followed: "<" back, else its address (from this page's)
Sub OpenLink()
  Dim u As String Max 80
  If sl < 0 Then Exit Sub
  u = Bml.LinkUrl(sl)
  If u = "<" Then Back Else Go Web.Resolve(cu, u), 1
End Sub

' link j's address, as it is shown ("<": Back)
Function LinkAt(ByVal j As Integer) As String Max 80
  LinkAt = Bml.LinkUrl(j)
  If LinkAt = "<" Then LinkAt = "Back" Else LinkAt = Web.Resolve(cu, LinkAt)
End Function

Sub Back()
  If hn = 0 Then Exit Sub
  hn = hn - 1
  Go hs(hn), 0
End Sub

' page u fetched (Web: http, or a file), laid out and drawn; push: the one before kept for B
Sub Go(ByVal u As String Max 80, ByVal push As Integer)
  u = Web.Clean(u)
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
  sn = Web.Fetch(u, SBUF, 8190)
  r = Bml.Render(SBUF, sn)
  tp = -1 : cl = 0 : sl = -1
  If Bml.Links() > 0 Then sl = 0
  DrawAll
End Sub

' ---- the toolbar: its tools (1-5, or the capital letter), what they do
Sub Tools()
  tbn(0) = "Back" : tbn(1) = "Reload" : tbn(2) = "Home" : tbn(3) = "Go to" : tbn(4) = "Quit"
  tbk(0) = 66 : tbk(1) = 82 : tbk(2) = 72 : tbk(3) = 71 : tbk(4) = 81
  ntb = 5
End Sub

Sub Tool(ByVal j As Integer)
  Dim u As String Max 80
  Select Case j
    Case 0
      Back
    Case 1
      Go cu, 0
    Case 2
      Go hm, 1
    Case 3                                       ' an address typed (this page's to start with)
      u = Edit("Go to: ", cu)
      If u = "" Then DrawBar Else Go u, 1
    Case 4
      qt = -1
  End Select
End Sub

' a line typed in the address box (EY, EX, EW): p, then v to start with - its end shown when it
' is longer than the box. Enter: it; ESC: "" (DEL rubs out)
Function Edit(ByVal p As String, ByVal v As String) As String Max 80
  Dim e As String Max 80, c As Integer, n As Integer
  e = v
  PtrOff
  n = EW - Len(p)
  Do
    At EY, EX
    If Len(e) > n Then
      Print p; Right$(e, n);
      At EY, EX + EW
    Else
      Print p; e; Space$(n - Len(e));
      At EY, EX + Len(p) + Len(e)
    End If
    Do
      c = Inkey
    Loop Until c <> 0
    If c = 13 Then Exit Do
    If c = 252 Then e = "" : Exit Do
    If c = 127 Or c = 8 Then
      If Len(e) > 0 Then e = Left$(e, Len(e) - 1)
    ElseIf c >= 32 And c < 127 And Len(e) < 80 Then
      e = e + Chr$(c)
    End If
  Loop
  PtrOn
  Edit = Trim$(e)
End Function
