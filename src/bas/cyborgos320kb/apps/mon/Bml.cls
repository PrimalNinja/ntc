' Bml - an 8BML (8-bit Markup Language v1) renderer. A page is commands separated by ":", each a
' letter and comma separated "parameters" (\" a quote in one); Render lays it out into lines of
' Init's width - text word wrapped, headings centred and underlined, links, toolbars, tables, form
' fields shown (not yet filled in) - and keeps a table of its links: their place in the lines
' and their URL (in the page, which must stay where it is) - 120 of them. MON builds its pages with it; a web
' browser will too. Drawing the lines (a window, a cursor) is the program's.
'
' The lines are 128 bytes each, kept in CyborgOS's store for the slot (BDOS 131 ops 12-14: its
' own 16K pages), 16 to a 2K block, through the program's buffers (Init: up to 4 blocks of 2K, the
' ones used last kept) - so a page can be thousands of lines long. Without a store: the lines the
' buffers hold.
'
' Commands (8BML v1): - start ("version","title"), . end, < back, > a toolbar of links ("url",
' "text" ...), b bold, d download link, h line, i image (shown as its text), l link ("url",
' "text","flags": r right), m music (not played), n new line, p page heading, s sub heading, t
' text, v table ("columns", then each column's "", "heading", then each row's "url", "text"
' cells), w select, x form button, y text field, z text area. And r ("text"): a line as it is -
' not wrapped, spaces kept (CyborgOS's: hex dumps, lists)
Option Explicit
Private w As Integer, nl As Integer, ml As Integer, hb As Integer
Private cb As Integer, nb As Integer, cs As Integer, sto As Integer, tick As Integer, wr As Integer
Private cbk(3) As Integer, cdy(3) As Integer, clu(3) As Integer
Private pe As Integer, cp As Integer, ps As Integer, pn As Integer, us As Integer, un As Integer
Private nk As Integer, pl As Integer
Private kl(119) As Integer, kc(119) As Integer, kn(119) As Integer, ku(119) As Integer, kv(119) As Integer
Private tt As String Max 80, ln As String Max 80

' Init(buf, n, cols): n (1-4) 2K buffers from buf (all in one 16K page of the slot) and the lines'
' width (80 at most: its strings are 80 long). The store asked for (256K, less when there isn't that much): its size in
' K, 0 none
Public Function Init(ByVal buf As Integer, ByVal n As Integer, ByVal cols As Integer) As Integer
  Dim k As Integer
  cb = buf : w = cols : hb = 0 : nl = 0 : nk = 0
  nb = n
  If nb < 1 Then nb = 1
  If nb > 4 Then nb = 4
  For k = 0 To 3
    cbk(k) = -1 : cdy(k) = 0 : clu(k) = 0
  Next
  If w > 80 Then w = 80
  k = 256
  Do While k >= 16
    CybSys.SetWord 2, k
    If CybSys.Ask(12, 0) = 0 Then Exit Do
    k = k \ 2
  Loop
  If k < 16 Then k = 0
  sto = (k > 0)
  ml = k * 8
  If ml = 0 Then ml = 16 * nb
  Init = k
End Function

' Render(a, n): the page at a (n bytes) laid out: how many lines
Public Function Render(ByVal a As Integer, ByVal n As Integer) As Integer
  Dim c As Integer
  nl = 0 : nk = 0 : tt = "" : cp = a : pe = a + n
  wr = -1                                        ' (writing: a block isn't fetched to be written)
  Do While cp < pe
    c = Peek(cp)
    cp = cp + 1
    If c = 46 Then Exit Do                       ' . the end
    If c > 32 And c <> 58 Then
      Cmd c
      Do While NextP()                           ' (what is left of it)
      Loop
    End If
  Loop
  For c = 0 To nb - 1                            ' what was written to the store
    If cdy(c) Then Blk cbk(c), 13, c : cdy(c) = 0
    If cbk(c) >= hb Then hb = cbk(c) + 1
  Next
  wr = 0
  Render = nl
End Function

Private Sub Cmd(ByVal c As Integer)
  Dim k As Integer, j As Integer, cw As Integer, s As String Max 80, a As Integer, g As Integer
  Select Case c
    Case 116, 98                                 ' t, b: text (no bold here)
      If NextP() Then Flow "", 0, 0, 0
    Case 112                                     ' p: page heading, = under it
      If NextP() Then Flow "", 1, 0, 61
    Case 115                                     ' s: sub heading, - under it
      If NextP() Then Flow "", 1, 0, 45
    Case 110                                     ' n
      ln = "" : Emit 0
    Case 104                                     ' h
      ln = String$(w, "-") : Emit 0
    Case 114                                     ' r: as it is
      If NextP() Then ln = Left$(PT(), w) : Emit 0
    Case 45                                      ' - "version","title"
      If NextP() Then
        If NextP() Then tt = Left$(PT(), 80)
      End If
    Case 108, 100                                ' l, d: a link ("url","text"[,"flags"])
      If NextP() Then
        us = ps : un = pn
        If NextP() Then
          k = ps : j = pn
          If c = 100 Then
            s = "^ "
            cw = 0
          Else
            s = "-> "
            cw = 0
            If NextP() Then
              If InStr(PT(), "r") > 0 Then cw = 2
            End If
            ps = k : pn = j
          End If
          Flow s, cw, -1, 0
        End If
      End If
    Case 105                                     ' i: "format","text","url",w,h - its text
      If NextP() Then
        If NextP() Then Flow ":) ", 0, 0, 0
      End If
    Case 60                                      ' <: back
      ln = "<- Back"
      us = 0 : un = 0
      AddLink nl, 3, 4
      Emit 0
    Case 62                                      ' >: a toolbar
      ln = ""
      Do While NextP()
        us = ps : un = pn
        If NextP() = 0 Then Exit Do
        s = PT()
        If Len(ln) + Len(s) + 3 > w And Len(ln) > 0 Then Emit 0 : ln = ""
        If Len(ln) > 0 Then ln = ln + " "
        AddLink nl, Len(ln) + 1, Len(s)
        ln = ln + "[" + s + "]"
      Loop
      If Len(ln) > 0 Then Emit 0
    Case 118                                     ' v: a table (its cells straight into the lines)
      If NextP() Then
        k = Val(PT())
        If k < 1 Then k = 1
        cw = w \ k
        a = NewLine()
        For j = 1 To k                           ' the headings: "", "text"
          If NextP() Then
            If NextP() Then
              If a <> 0 Then Put a + (j - 1) * cw, cw - 1
            End If
          End If
        Next
        If a <> 0 Then nl = nl + 1
        ln = String$(w, "-") : Emit 0
        Do
          a = NewLine() : g = 0
          For j = 0 To k - 1                     ' a row: "url", "text" each cell
            If NextP() = 0 Then Exit For
            us = ps : un = pn
            If NextP() = 0 Then Exit For
            g = -1 : pl = 0
            If a <> 0 Then Put a + j * cw, cw - 1
            If un > 0 Then AddLink nl, j * cw, pl
          Next
          If g = 0 Then Exit Do
          If a <> 0 Then nl = nl + 1
        Loop While j >= k
      End If
    Case 120                                     ' x: a form button "url","text"
      If NextP() Then
        us = ps : un = pn
        If NextP() Then
          s = PT()
          ln = "[ " + s + " ]"
          AddLink nl, 2, Len(s)
          Emit 0
        End If
      End If
    Case 121                                     ' y: a text field "name","length","flags","value"
      If NextP() Then
        If NextP() Then
          k = Val(PT())
          If k > w - 2 Then k = w - 2
          If NextP() Then
            s = ""
            If NextP() Then s = PT()
            ln = "|" + Left$(s + String$(k, "_"), k) + "|" : Emit 0
          End If
        End If
      End If
    Case 122                                     ' z: a text area "name","cols","rows","flags","value"
      If NextP() Then
        If NextP() Then
          k = Val(PT())
          If k > w - 2 Then k = w - 2
          If NextP() Then
            j = Val(PT())
            For c = 1 To j
              ln = "|" + String$(k, "_") + "|" : Emit 0
            Next
          End If
        End If
      End If
    Case 119                                     ' w: a select "name","value","flags", then "code","text"
      If NextP() Then
        If NextP() Then
          s = PT()
          If NextP() Then
            ln = ""
            Do While NextP()
              k = (PT() = s)
              If NextP() = 0 Then Exit Do
              If k Or ln = "" Then ln = "[ " + PT() + " v]"
            Loop
            Emit 0
          End If
        End If
      End If
  End Select
End Sub

' line nl cleared (spaces): its place, 0 when there is no room for it
Private Function NewLine() As Integer
  Dim a As Integer, x As Integer
  NewLine = 0
  If nl >= ml Then Exit Function
  a = Sel(nl)
  For x = 0 To w - 1
    Poke a + x, 32
  Next
  NewLine = a
End Function

' the parameter's text (\x as x) at a, n characters at most: pl how many
Private Sub Put(ByVal a As Integer, ByVal n As Integer)
  Dim j As Integer, c As Integer, e As Integer, x As Integer
  j = ps : e = ps + pn : x = 0
  Do While j < e And x < n
    c = Peek(j)
    If c = 92 Then j = j + 1 : c = Peek(j)
    Poke a + x, c
    x = x + 1 : j = j + 1
  Loop
  pl = x
End Sub

' the next parameter of the command (ps, pn: its text in the page, \ escapes still in it); False
' at the command's end (a : outside quotes)
Private Function NextP() As Integer
  Dim c As Integer
  NextP = 0
  Do While cp < pe
    c = Peek(cp)
    If c = 58 Then Exit Function
    cp = cp + 1
    If c = 34 Then Exit Do
  Loop
  If cp >= pe Then Exit Function
  ps = cp
  Do While cp < pe
    c = Peek(cp)
    If c = 34 Then Exit Do
    If c = 92 Then cp = cp + 1
    cp = cp + 1
  Loop
  pn = cp - ps
  cp = cp + 1
  NextP = -1
End Function

' the parameter's text (\x as x), 128 characters at most
Private Function PT() As String
  PT = Txt(ps, pn)
End Function

Private Function Txt(ByVal a As Integer, ByVal n As Integer) As String
  Dim j As Integer, c As Integer, s As String Max 80
  s = ""
  j = a
  Do While j < a + n And Len(s) < 80
    c = Peek(j)
    If c = 92 Then j = j + 1 : c = Peek(j)
    s = s + Chr$(c)
    j = j + 1
  Loop
  Txt = s
End Function

' the parameter's text word wrapped to the width after pre (its next lines indented as far): al 0
' left, 1 centred, 2 right; lk <> 0: each line of it a link (to us, un); ul: a character to
' underline it with (0 none). Straight from the page into the lines (no strings): spaces run
' together, a word too long for a line cut
Private Sub Flow(ByVal pre As String Max 4, ByVal al As Integer, ByVal lk As Integer, ByVal ul As Integer)
  Dim j As Integer, e As Integer, ind As Integer, av As Integer, ls As Integer, le As Integer
  Dim ll As Integer, ws As Integer, wl As Integer, we As Integer, c As Integer, a As Integer, x As Integer
  Dim v As Integer, sp As Integer
  ind = Len(pre)
  If ind >= w Then ind = 0 : pre = ""
  av = w - ind
  j = ps : e = ps + pn
  Do
    Do While j < e                               ' (spaces before the line)
      If Peek(j) > 32 Then Exit Do
      j = j + 1
    Loop
    If j >= e Then Exit Do
    ls = j : le = j : ll = 0
    Do                                           ' the words that fit
      ws = j
      Do While ws < e
        If Peek(ws) > 32 Then Exit Do
        ws = ws + 1
      Loop
      If ws >= e Then Exit Do
      we = ws : wl = 0
      Do While we < e
        v = Peek(we)
        If v <= 32 Then Exit Do
        If v = 92 Then we = we + 1
        we = we + 1 : wl = wl + 1
      Loop
      If ll > 0 Then wl = wl + 1
      If ll + wl > av Then
        If ll = 0 Then                           ' a word longer than the line: as much as fits
          we = ws : wl = 0
          Do While wl < av
            If Peek(we) = 92 Then we = we + 1
            we = we + 1 : wl = wl + 1
          Loop
          ll = wl : le = we : j = we
        End If
        Exit Do
      End If
      ll = ll + wl : le = we : j = we
    Loop
    c = 0
    If al = 1 Then c = (w - ind - ll) \ 2
    If al = 2 Then c = w - ind - ll
    If c < 0 Then c = 0
    If lk Then AddLink nl, c + ind, ll
    If nl < ml Then
      a = Sel(nl)
      For x = 0 To w - 1
        Poke a + x, 32
      Next
      x = a + c
      If ind > 0 Then
        v = VarPtr(pre)
        For sp = 0 To ind - 1
          Poke x + sp, Peek(v + sp)
        Next
      End If
      x = x + ind
      sp = 0
      Do While ls < le                           ' the words, one space between them
        v = Peek(ls)
        If v <= 32 Then
          sp = -1
        Else
          If sp Then Poke x, 32 : x = x + 1 : sp = 0
          If v = 92 Then ls = ls + 1 : v = Peek(ls)
          Poke x, v : x = x + 1
        End If
        ls = ls + 1
      Loop
      nl = nl + 1
    End If
    If ul > 0 Then ln = String$(ll, Chr$(ul)) : Emit c + ind
    pre = Space$(ind)
  Loop
End Sub

' a link at line i, column c, n characters long: to us, un (us 0: back - a page is never at 0)
Private Sub AddLink(ByVal i As Integer, ByVal c As Integer, ByVal n As Integer)
  If nk > 119 Or n < 1 Then Exit Sub
  kl(nk) = i : kc(nk) = c : kn(nk) = n : ku(nk) = us : kv(nk) = un
  nk = nk + 1
End Sub

' ln at column c as the next line (the rest spaces)
Private Sub Emit(ByVal c As Integer)
  Dim a As Integer, j As Integer, n As Integer, p As Integer
  If nl >= ml Then Exit Sub
  a = Sel(nl)
  n = Len(ln)
  If c + n > w Then n = w - c
  For j = 0 To c - 1
    Poke a + j, 32
  Next
  p = VarPtr(ln)
  For j = 0 To n - 1
    Poke a + c + j, Peek(p + j)
  Next
  For j = c + n To w - 1
    Poke a + j, 32
  Next
  nl = nl + 1
End Sub

' line i's place in the buffers: its 2K block brought in from the store if it isn't in one (the
' one used longest ago given up - put back first if it was written to); while Render writes,
' marked written (and not fetched: its lines are written whole)
Private Function Sel(ByVal i As Integer) As Integer
  Dim k As Integer, j As Integer, o As Integer
  k = i \ 16
  o = -1
  For j = 0 To nb - 1
    If cbk(j) = k Then o = j
  Next
  If o < 0 Then
    o = 0
    For j = 1 To nb - 1
      If clu(j) < clu(o) Then o = j
    Next
    If cdy(o) Then
      Blk cbk(o), 13, o
      If cbk(o) >= hb Then hb = cbk(o) + 1
      cdy(o) = 0
    End If
    If k < hb And wr = 0 Then Blk k, 14, o
    cbk(o) = k
  End If
  tick = tick + 1
  clu(o) = tick
  If wr Then cdy(o) = -1
  Sel = cb + o * 2048 + (i And 15) * 128
End Function

' store block k to (o 13) or from (o 14) buffer b
Private Sub Blk(ByVal k As Integer, ByVal o As Integer, ByVal b As Integer)
  Dim r As Integer
  If sto = 0 Then Exit Sub
  CybSys.SetWord 2, k
  CybSys.SetWord 6, cb + b * 2048
  CybSys.SetWord 8, 2048
  r = CybSys.Ask(o, 0)
End Sub

' the page's lines, width, title; line i's characters (Cols of them) at LineAddr(i), until the
' next LineAddr
Public Function Lines() As Integer
  Lines = nl
End Function
Public Function Cols() As Integer
  Cols = w
End Function
Public Function Title() As String
  Title = tt
End Function
Public Function LineAddr(ByVal i As Integer) As Integer
  LineAddr = Sel(i)
End Function

' its links: how many; link i's line, column, length and URL ("<": back)
Public Function Links() As Integer
  Links = nk
End Function
Public Function LinkLine(ByVal i As Integer) As Integer
  LinkLine = kl(i)
End Function
Public Function LinkCol(ByVal i As Integer) As Integer
  LinkCol = kc(i)
End Function
Public Function LinkLen(ByVal i As Integer) As Integer
  LinkLen = kn(i)
End Function
Public Function LinkUrl(ByVal i As Integer) As String Max 60
  If ku(i) = 0 Then
    LinkUrl = "<"
  Else
    LinkUrl = Txt(ku(i), kv(i))
  End If
End Function
