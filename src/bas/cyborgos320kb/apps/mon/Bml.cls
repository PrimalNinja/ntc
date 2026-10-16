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
'
' Forms (#Const BML_FORMS = 1, then Forms(buf, n): room for n fields' values, 128 bytes each -
' without them, fields are only shown, as MON has them): each y, z, w is a field (n at most,
' with the x buttons), its value in buf (126 characters at most); each x a button sending the fields before it (back to the button before them) - Query(): its
' URL parameters, name=value&...&action=its text, encoded. The fields and buttons are links too:
' LinkKind(i) 0 a link, 1 a text field, 2 a text area, 3 a select, 4 a button; LinkField(i)
' its field. A field's value: Value(f), SetValue(f, s) (its line on the page shown again);
' FieldName, FieldMax, Masked (a password), Options / OptionText / Pick (a select's choices)
Option Explicit
Private w As Integer, nl As Integer, ml As Integer, hb As Integer
Private cb As Integer, nb As Integer, cs As Integer, sto As Integer, tick As Integer, wr As Integer
Private cbk(3) As Integer, cdy(3) As Integer, clu(3) As Integer
Private pe As Integer, cp As Integer, ps As Integer, pn As Integer, us As Integer, un As Integer
Private nk As Integer, pl As Integer
Private kl(119) As Integer, kc(119) As Integer, kn(119) As Integer, ku(119) As Integer, kv(119) As Integer
Private tt As String Max 80, ln As String Max 80
#If BML_FORMS Then
Private kt(119) As Integer                       ' a link's field + 1 (0: a link)
Private fk(31) As Integer, fp(31) As Integer, fn(31) As Integer, fm(31) As Integer, ff(31) As Integer
Private fo(31) As Integer, fy(31) As Integer, fw(31) As Integer, fr(31) As Integer, fg(31) As Integer
Private nf As Integer, vb As Integer, frm As Integer, fq As Integer   ' fields; values' buffer; form; a button last
Private oq As Integer                            ' a select's choices: where they start in the page
Private fmx As Integer                           ' the most fields (Forms)
Private qq As String Max 255                     ' (Query's)
Const VSZ = 128                                  ' a value's room: its length, 126 characters, a 0
#End If

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
#If BML_FORMS Then
  nf = 0 : frm = 0 : fq = 0
#End If
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
    Case 114                                     ' r: as it is - straight from the page into the line (no string)
      If NextP() Then
        a = NewLine()
        If a <> 0 Then Put a, w : nl = nl + 1
      End If
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
#If BML_FORMS Then
    Case 120                                     ' x: a form button "url","action"
      If NextP() Then
        us = ps : un = pn
        If NextP() Then
          s = PT()
          ln = "[ " + s + " ]"
          k = NewField(4)
          AddLink nl, 2, Len(s)
          If k >= 0 Then kt(nk - 1) = k + 1 : fy(k) = nl : fq = -1
          Emit 0
        End If
      End If
    Case 121                                     ' y: a text field "name","length","flags","value"
      If NextP() Then
        g = ps : a = pn
        If NextP() Then
          k = Val(PT())
          If NextP() Then
            j = Flags()
            s = ""
            If NextP() Then s = PT()
            Field 1, g, a, k, j, s, 1
          End If
        End If
      End If
    Case 122                                     ' z: a text area "name","cols","rows","flags","value"
      If NextP() Then
        g = ps : a = pn
        If NextP() Then
          k = Val(PT())
          If NextP() Then
            cw = Val(PT())
            If NextP() Then
              j = Flags()
              s = ""
              If NextP() Then s = PT()
              Field 2, g, a, k, j, s, cw
            End If
          End If
        End If
      End If
    Case 119                                     ' w: a select "name","value","flags", then "code","text"
      If NextP() Then
        g = ps : a = pn
        If NextP() Then
          s = PT()
          If NextP() Then
            j = Flags()
            oq = cp                              ' (its choices: from here)
            Field 3, g, a, 0, j, s, 0
            Do While NextP()                     ' (past its choices)
            Loop
          End If
        End If
      End If
#Else
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
#End If
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
Private Function PT() As String Max 126
  PT = Txt(ps, pn)
End Function

#If BML_FORMS Then
Private Function Txt(ByVal a As Integer, ByVal n As Integer) As String Max 255
  Dim j As Integer, c As Integer
  Txt = ""
  j = a
  Do While j < a + n And Len(Txt) < 255
    c = Peek(j)
    If c = 92 Then j = j + 1 : c = Peek(j)
    Txt = Txt + Chr$(c)
    j = j + 1
  Loop
End Function
#Else
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
#End If

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
#If BML_FORMS Then
  kt(nk) = 0
#End If
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
Public Function Title() As String Max 80
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
#If BML_FORMS Then
Public Function LinkUrl(ByVal i As Integer) As String Max 255
#Else
Public Function LinkUrl(ByVal i As Integer) As String Max 60
#End If
  If ku(i) = 0 Then
    LinkUrl = "<"
  Else
    LinkUrl = Txt(ku(i), kv(i))
  End If
End Function

#If BML_FORMS Then
' ---- forms (#Const BML_FORMS = 1 in the program: YING, YANG - not MON)

' Forms(buf, n): the fields' values kept in buf - n of them (32 at most, VSZ bytes each: n * 128
' bytes); buf 0: fields only shown
Public Sub Forms(ByVal buf As Integer, ByVal n As Integer)
  vb = buf : fmx = n
  If fmx > 32 Then fmx = 32
End Sub

' a field's flags: 1 mandatory (m), 2 a password (p)
Private Function Flags() As Integer
  Dim t As String Max 8
  t = PT() : Flags = 0
  If InStr(t, "m") > 0 Then Flags = 1
  If InStr(t, "p") > 0 Then Flags = Flags + 2
End Function

' a new field of kind k (1-4) - its form (fields after a button start the next): its number, -1
' none (no buffer, or 32 already)
Private Function NewField(ByVal k As Integer) As Integer
  NewField = -1
  If vb = 0 Or nf >= fmx Then Exit Function
  If fq And k < 4 Then frm = frm + 1 : fq = 0
  fk(nf) = k : fg(nf) = frm : fo(nf) = 0 : fm(nf) = 0 : ff(nf) = 0 : fw(nf) = 0 : fr(nf) = 1
  fp(nf) = ps : fn(nf) = pn
  NewField = nf
  nf = nf + 1
End Function

' a field of kind k (1 text, 2 area, 3 select): its name at (na, nn), its length (text) or columns
' (area), flags, value, rows (area): kept, shown, a link
Private Sub Field(ByVal k As Integer, ByVal na As Integer, ByVal nn As Integer, ByVal mx As Integer, ByVal fl As Integer, ByVal v As String Max 126, ByVal rw As Integer)
  Dim f As Integer, j As Integer, wd As Integer
  ps = na : pn = nn
  f = NewField(k)
  wd = mx
  If wd > w - 2 Then wd = w - 2
  If wd < 1 Then wd = 1
  If rw < 1 Then rw = 1
  If rw > 8 Then rw = 8
  If f < 0 Then                                  ' (no forms: shown only)
    For j = 1 To rw
      If k = 3 Then
        ln = "[ " + v + " v]"
      ElseIf j = 1 Then
        ln = "|" + Left$(v + String$(wd, "_"), wd) + "|"
      Else
        ln = "|" + String$(wd, "_") + "|"
      End If
      Emit 0
    Next
    Exit Sub
  End If
  fm(f) = mx : ff(f) = fl : fy(f) = nl : fw(f) = wd : fr(f) = rw
  If k = 3 Then fo(f) = oq
  If k = 2 Then fm(f) = mx * rw
  If fm(f) > 126 Or fm(f) < 1 Then fm(f) = 126
  If k = 3 Then fm(f) = 126
  Store f, v
  us = 0 : un = 0
  AddLink nl, 1, wd
  If k = 3 Then kn(nk - 1) = 1
  If nk > 0 Then kt(nk - 1) = f + 1
  For j = 1 To rw
    ln = "" : Emit 0
  Next
  Show f
End Sub

' f's value kept (its first fm characters)
Private Sub Store(ByVal f As Integer, ByVal v As String Max 126)
  Dim a As Integer, j As Integer
  a = vb + f * VSZ
  If Len(v) > fm(f) Then v = Left$(v, fm(f))
  Poke a, Len(v)
  For j = 1 To Len(v)
    Poke a + j, Asc(Mid$(v, j, 1))
  Next
End Sub

' field f on its line(s) again: a text field |value___| (a password's as *), an area its rows, a
' select [ its choice's text v]
Private Sub Show(ByVal f As Integer)
  Dim v As String Max 126, j As Integer, t As String Max 80, q As Integer
  v = Value(f)
  If ff(f) And 2 Then v = String$(Len(v), "*")
  If fk(f) = 3 Then
    t = "[ " + Choice(f) + " v]"
    Patch fy(f), 0, t
    For q = 0 To nk - 1                          ' (its link as long as it is)
      If kt(q) = f + 1 Then kn(q) = Len(t) - 1
    Next
  Else
    For j = 0 To fr(f) - 1
      t = Mid$(v, j * fw(f) + 1, fw(f))
      Patch fy(f) + j, 0, "|" + t + String$(fw(f) - Len(t), "_") + "|"
    Next
  End If
End Sub

' line i from column c: s (the rest of the line spaces) - in the lines kept (marked written)
Private Sub Patch(ByVal i As Integer, ByVal c As Integer, ByVal s As String Max 80)
  Dim a As Integer, j As Integer, o As Integer
  If i >= nl Then Exit Sub
  a = Sel(i)                                     ' (its block here)
  o = wr : wr = -1
  a = Sel(i)                                     ' (... and marked written)
  wr = o
  For j = c To w - 1
    If j - c < Len(s) Then Poke a + j, Asc(Mid$(s, j - c + 1, 1)) Else Poke a + j, 32
  Next
End Sub

' the select f's chosen choice's text (its first if none is chosen)
Private Function Choice(ByVal f As Integer) As String Max 80
  Dim j As Integer, n As Integer, v As String Max 126
  v = Value(f) : n = Options(f)
  Choice = ""
  If n = 0 Then Exit Function
  Choice = OptionText(f, 0)
  For j = 0 To n - 1
    If OptionCode(f, j) = v Then Choice = OptionText(f, j) : Exit Function
  Next
End Function

Public Function LinkKind(ByVal i As Integer) As Integer
  LinkKind = 0
  If kt(i) > 0 Then LinkKind = fk(kt(i) - 1)
End Function
Public Function LinkField(ByVal i As Integer) As Integer
  LinkField = kt(i) - 1
End Function
Public Function Fields() As Integer
  Fields = nf
End Function
Public Function FieldName(ByVal f As Integer) As String Max 80
  FieldName = Txt(fp(f), fn(f))
End Function
Public Function FieldMax(ByVal f As Integer) As Integer
  FieldMax = fm(f)
End Function
Public Function Masked(ByVal f As Integer) As Integer
  Masked = ((ff(f) And 2) <> 0)
End Function
Public Function Value(ByVal f As Integer) As String Max 126
  Dim a As Integer, j As Integer, v As String Max 126
  a = vb + f * VSZ
  v = ""
  For j = 1 To Peek(a)
    v = v + Chr$(Peek(a + j))
  Next
  Value = v
End Function
Public Sub SetValue(ByVal f As Integer, ByVal v As String Max 126)
  Store f, v
  Show f
End Sub

' a select's choices: how many; choice j's code and text (from the page)
Public Function Options(ByVal f As Integer) As Integer
  Dim n As Integer, c0 As Integer, p0 As Integer, q0 As Integer
  Options = 0
  If fk(f) <> 3 Or fo(f) = 0 Then Exit Function
  c0 = cp : p0 = ps : q0 = pn                    ' (Render's place kept: this is called while it runs)
  cp = fo(f) : n = 0
  Do While NextP()
    If NextP() = 0 Then Exit Do
    n = n + 1
  Loop
  cp = c0 : ps = p0 : pn = q0
  Options = n
End Function
Public Function OptionCode(ByVal f As Integer, ByVal j As Integer) As String Max 80
  OptionCode = Opt(f, j, 0)
End Function
Public Function OptionText(ByVal f As Integer, ByVal j As Integer) As String Max 80
  OptionText = Opt(f, j, 1)
End Function
Private Function Opt(ByVal f As Integer, ByVal j As Integer, ByVal which As Integer) As String Max 80
  Dim n As Integer, c0 As Integer, p0 As Integer, q0 As Integer
  Opt = ""
  c0 = cp : p0 = ps : q0 = pn
  cp = fo(f) : n = 0
  Do While NextP()
    If n = j * 2 + which Then Opt = PT() : Exit Do
    n = n + 1
  Loop
  cp = c0 : ps = p0 : pn = q0
End Function
' Pick(f): a select's next choice (after its last, its first)
Public Sub Pick(ByVal f As Integer)
  Dim j As Integer, n As Integer, v As String Max 126
  n = Options(f)
  If n = 0 Then Exit Sub
  v = Value(f)
  For j = 0 To n - 1
    If OptionCode(f, j) = v Then Exit For
  Next
  j = j + 1
  If j >= n Then j = 0
  SetValue f, OptionCode(f, j)
End Sub

' Missing(i): button i's form's first mandatory field left empty (-1 none)
Public Function Missing(ByVal i As Integer) As Integer
  Dim f As Integer, g As Integer
  Missing = -1
  If kt(i) = 0 Then Exit Function
  g = fg(kt(i) - 1)
  For f = 0 To nf - 1
    If fg(f) = g And fk(f) < 4 And (ff(f) And 1) <> 0 Then
      If Peek(vb + f * VSZ) = 0 Then Missing = f : Exit Function
    End If
  Next
End Function

' FieldLink(f): the link that is field f (-1 none)
Public Function FieldLink(ByVal f As Integer) As Integer
  Dim q As Integer
  FieldLink = -1
  For q = 0 To nk - 1
    If kt(q) = f + 1 Then FieldLink = q : Exit Function
  Next
End Function

' Query(i): button i's form as URL parameters - each field's name=value, then action=its text,
' joined by &, encoded (%xx; letters, digits and - _ . ~ as they are) - "" when longer than 255
Public Function Query(ByVal i As Integer) As String Max 255
  Dim f As Integer, g As Integer, ok As Integer
  Query = ""
  If kt(i) = 0 Then Exit Function
  g = fg(kt(i) - 1)
  qq = "" : ok = -1
  For f = 0 To nf - 1
    If fg(f) = g And fk(f) < 4 Then
      If Add(fp(f), fn(f), f) = 0 Then ok = 0
    End If
  Next
  If Add(0, 0, kt(i) - 1) = 0 Then ok = 0
  If ok Then Query = qq
End Function

' name=value added to qq (an & before it), encoded: the name at (a, n) in the page (0: action, the
' value field f's - a button's: its text): False when it doesn't fit
Private Function Add(ByVal a As Integer, ByVal n As Integer, ByVal f As Integer) As Integer
  Dim j As Integer, v As Integer
  Add = 0
  If qq <> "" Then qq = qq + "&"
  If a = 0 Then
    qq = qq + "action="
    a = fp(f) : n = fn(f)
    For j = 0 To n - 1                           ' (the button's text, \ escapes taken off)
      v = Peek(a + j)
      If v = 92 Then j = j + 1 : v = Peek(a + j)
      If Enc(v) = 0 Then Exit Function
    Next
  Else
    For j = 0 To n - 1
      v = Peek(a + j)
      If v = 92 Then j = j + 1 : v = Peek(a + j)
      If Enc(v) = 0 Then Exit Function
    Next
    qq = qq + "="
    a = vb + f * VSZ
    For j = 1 To Peek(a)
      If Enc(Peek(a + j)) = 0 Then Exit Function
    Next
  End If
  Add = -1
End Function

' character c onto qq, encoded (%xx; letters, digits and - _ . ~ as they are): False when qq is full
Private Function Enc(ByVal c As Integer) As Integer
  Enc = 0
  If Len(qq) > 250 Then Exit Function
  If (c >= 48 And c <= 57) Or (c >= 65 And c <= 90) Or (c >= 97 And c <= 122) Or c = 45 Or c = 95 Or c = 46 Or c = 126 Then
    qq = qq + Chr$(c)
  Else
    qq = qq + "%" + Right$("0" + Hex$(c), 2)
  End If
  Enc = -1
End Function
#End If
