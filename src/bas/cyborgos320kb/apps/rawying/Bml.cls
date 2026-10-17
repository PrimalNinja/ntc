' Bml (RAWYING's and RAWYANG's) - a raw page reader with Bml.cls's interface (apps/mon/Bml.cls:
' YING's and YANG's 8BML renderer). The page comes from the server laid out already, for this
' width (asked for with raw=width - Web.cls): its rows as they are shown, its links and form
' fields as records that go straight into the tables. Nothing to parse but the records, nothing
' to wrap: the rows are copied into the lines (Z80), the numbers read (Z80). tools/rawpage has the
' format (RAW.TXT) and 8bml2raw.py, the reference layout - the same as Bml.cls's.
'   T<title>   L<row>   K<row> <col> <len><TAB><url>   E (the end)
'   F<kind> <row> <col> <width> <rows> <max> <flags> <form><TAB><name><TAB><value>
'   O<code><TAB><text> (a select's choices, after its F)
'   B<row> <col> <len> <form><TAB><url><TAB><action>
' The lines: 128 bytes each in CyborgOS's store for the slot, through the program's buffers, as
' Bml.cls has them. Links and fields as Bml.cls's (LinkKind, Value, SetValue, Query ...); a
' field's line shown again after its value changes: |value___| (* for a password), [ choice v]
Option Explicit
Private w As Integer, nl As Integer, ml As Integer, hb As Integer
Private cb As Integer, nb As Integer, cs As Integer, sto As Integer, tick As Integer, wr As Integer
Private cbk(3) As Integer, cdy(3) As Integer, clu(3) As Integer
Private nk As Integer, us As Integer, un As Integer, rp As Integer, pe As Integer
Private kl(119) As Integer, kc(119) As Integer, kn(119) As Integer, ku(119) As Integer, kv(119) As Integer
Private kt(119) As Integer                       ' a link's field + 1 (0: a link)
Private tt As String Max 80
Private fk(31) As Integer, fp(31) As Integer, fn(31) As Integer, fm(31) As Integer, ff(31) As Integer
Private fo(31) As Integer, fy(31) As Integer, fw(31) As Integer, fr(31) As Integer, fg(31) As Integer
Private fx(31) As Integer
Private nf As Integer, vb As Integer, fmx As Integer
Private qq As String Max 255                     ' (Query's)
Private pgb As Integer, pgn As Integer, pgm As Integer, pgr As Integer   ' (Pg's page: buffer, length, room, rows)
Const VSZ = 128                                  ' a value's room: its length, 126 characters, a 0

' Raw(): True - this is the raw reader (Web.cls asks for raw=width, its own pages are raw)
Public Function Raw() As Integer
  Raw = -1
End Function

' Pg(k, s, b, n, mx): Web.cls's own pages (it can't fetch one ...) made in this reader's format -
' raw here: into b (n bytes there already, mx at most), the length after. k 0 the page's start,
' its heading s (T, the heading centred, underlined); 1 a line of text s (its rows, cut at the
' width, a row after); 2 a status page's end (a back link, E); 3 a file's end, 4 a fetched
' page's end: nothing (a raw page has its own E)
Public Function Pg(ByVal k As Integer, ByVal s As String Max 160, ByVal b As Integer, ByVal n As Integer, ByVal mx As Integer) As Integer
  pgb = b : pgn = n : pgm = mx
  Select Case k
    Case 0
      pgr = 0
      PgOut "T" + s
      PgOut "L" + Space$((w - Len(s)) \ 2) + s
      PgOut "L" + Space$((w - Len(s)) \ 2) + String$(Len(s), "=")
      PgOut "L"
    Case 1
      Do
        PgOut "L" + Left$(s, w)
        s = Mid$(s, w + 1)
      Loop While s <> ""
      PgOut "L"
    Case 2
      PgOut "L<- Back"
      PgOut "K" + Trim$(Str$(pgr - 1)) + " 3 4" + Chr$(9) + "<"
      PgOut "E"
  End Select
  Pg = pgn
End Function

' a raw record, CR LF after it (pgr: the rows so far)
Private Sub PgOut(ByVal s As String Max 162)
  Dim j As Integer
  If Left$(s, 1) = "L" Then pgr = pgr + 1
  s = s + Chr$(13) + Chr$(10)
  For j = 1 To Len(s)
    If pgn < pgm Then Poke pgb + pgn, Asc(Mid$(s, j, 1)) : pgn = pgn + 1
  Next
End Sub

' Render(a, n): the raw page at a (n bytes): its rows into the lines, its records into the tables
' (the page must stay where it is: the links' addresses, the fields' names are read from it):
' how many lines
Public Function Render(ByVal a As Integer, ByVal n As Integer) As Integer
  Dim c As Integer, k As Integer, f As Integer, t As Integer, l As Integer, cc As Integer
  Dim ln2 As Integer, wd As Integer, rw As Integer, mx As Integer, fl As Integer, g As Integer
  Dim re As Integer, lf As Integer
  nl = 0 : nk = 0 : nf = 0 : tt = "" : rp = a : pe = a + n : lf = -1
  wr = -1                                        ' (writing: a block isn't fetched to be written)
  Do While rp < pe
    Do While Peek(rp) = 76 And nl < ml And rp < pe   ' L: rows - the rest of this line block's at
      k = 16 - (nl And 15)                       ' once (Z80: Rows)
      If k > ml - nl Then k = ml - nl
      nl = nl + Rows(Sel(nl), k)
    Loop
    If rp >= pe Then Exit Do
    re = Ends(rp, pe, 0)
    c = Peek(rp) : rp = rp + 1
    Select Case c
      Case 76                                    ' (an L past the lines there is room for)
      Case 75                                    ' K: a link
        l = Num() : cc = Num() : ln2 = Num()
        us = rp + 1 : un = re - rp - 1
        AddLink l, cc, ln2
      Case 70                                    ' F: a field
        k = Num() : l = Num() : cc = Num() : wd = Num() : rw = Num() : mx = Num() : fl = Num() : g = Num()
        t = Ends(rp + 1, re, 1)                  ' (its name: to the TAB)
        If vb <> 0 And nf < fmx And k >= 1 And k <= 3 Then
          f = nf : nf = nf + 1 : lf = f
          fk(f) = k : fp(f) = rp + 1 : fn(f) = t - rp - 1 : fy(f) = l : fx(f) = cc : fw(f) = wd
          fr(f) = rw : fm(f) = mx : ff(f) = fl : fg(f) = g : fo(f) = 0
          If fm(f) > 126 Or fm(f) < 1 Then fm(f) = 126
          If t < re Then Store f, Txt(t + 1, re - t - 1) Else Store f, ""
          us = 0 : un = 0
          If k = 3 Then AddLink l, cc + 2, wd Else AddLink l, cc + 1, wd
          If nk > 0 Then kt(nk - 1) = f + 1
        End If
      Case 79                                    ' O: a select's choice
        If lf >= 0 Then
          If fo(lf) = 0 Then fo(lf) = rp - 1
        End If
      Case 66                                    ' B: a form's button
        l = Num() : cc = Num() : ln2 = Num() : g = Num()
        t = Ends(rp + 1, re, 1)
        us = rp + 1 : un = t - rp - 1
        If vb <> 0 And nf < fmx Then
          f = nf : nf = nf + 1
          fk(f) = 4 : fg(f) = g : fy(f) = l : fx(f) = cc : fo(f) = 0 : ff(f) = 0
          If t < re Then fp(f) = t + 1 : fn(f) = re - t - 1 Else fp(f) = t : fn(f) = 0
          AddLink l, cc + 2, ln2
          If nk > 0 Then kt(nk - 1) = f + 1
        Else
          AddLink l, cc + 2, ln2
        End If
      Case 84                                    ' T: the title
        tt = Txt(rp, re - rp)
      Case 69                                    ' E: the end
        Exit Do
    End Select
    rp = Nxt(re, pe)
  Loop
  For c = 0 To nb - 1                            ' what was written to the store
    If cdy(c) Then Blk cbk(c), 13, c : cdy(c) = 0
    If cbk(c) >= hb Then hb = cbk(c) + 1
  Next
  wr = 0
  Render = nl
End Function

' Rows(a, n): up to n L records from rp, each into a line from a on (128 bytes apart): its text,
' w characters at most, spaces after it; rp past them - how many
Private Function Rows(ByVal a As Integer, ByVal n As Integer) As Integer
#asm
            ld hl, 0
            ld ({result}), hl
            ld hl, ({rp})
rw_rec:
            ld a, ({n})
            or a
            jp z, rw_done
            ld de, ({pe})           ; another record, an L?
            or a
            sbc hl, de
            add hl, de
            jp nc, rw_done
            ld a, (hl)
            cp 76
            jp nz, rw_done
            inc hl
            ld de, ({a})            ; the line: its text (to the CR / LF, w at most), then spaces
            ld a, ({w})
            ld b, a
rw_ch:
            ld a, (hl)
            cp 13
            jr z, rw_sp
            cp 10
            jr z, rw_sp
            ld (de), a
            inc de
            inc hl
            djnz rw_ch
            ld de, ({pe})
rw_skip:                            ; (longer than w: the rest left out)
            or a
            sbc hl, de
            add hl, de
            jr nc, rw_next
            ld a, (hl)
            cp 13
            jr z, rw_eol
            cp 10
            jr z, rw_eol
            inc hl
            jr rw_skip
rw_sp:
            ld a, 32
rw_sp1:
            ld (de), a
            inc de
            djnz rw_sp1
            ld de, ({pe})
rw_eol:                             ; past its CR LF
            or a
            sbc hl, de
            add hl, de
            jr nc, rw_next
            ld a, (hl)
            cp 13
            jr z, rw_e1
            cp 10
            jr nz, rw_next
rw_e1:
            inc hl
            jr rw_eol
rw_next:
            ex de, hl               ; the next line
            ld hl, ({a})
            ld bc, 128
            add hl, bc
            ld ({a}), hl
            ex de, hl
            ld a, ({n})
            dec a
            ld ({n}), a
            ld de, ({result})
            inc de
            ld ({result}), de
            jp rw_rec
rw_done:
            ld ({rp}), hl
#endasm
End Function

' Ends(p, e, t): where the record from p ends - its CR or LF (else e); t 1: a text part - a TAB
' ends it too
Private Function Ends(ByVal p As Integer, ByVal e As Integer, ByVal t As Integer) As Integer
#asm
            ld hl, ({p})
            ld de, ({e})
            ld a, ({t})
            or a
            ld c, 10                ; (C: the TAB looked for, or LF again)
            jr z, en_lp
            ld c, 9
en_lp:
            or a
            sbc hl, de
            add hl, de
            jr nc, en_done
            ld a, (hl)
            cp 13
            jr z, en_done
            cp 10
            jr z, en_done
            cp c
            jr z, en_done
            inc hl
            jr en_lp
en_done:
            ld ({result}), hl
#endasm
End Function

' Nxt(p, e): past the CR / LF at p: the next record's start
Private Function Nxt(ByVal p As Integer, ByVal e As Integer) As Integer
#asm
            ld hl, ({p})
            ld de, ({e})
nx_lp:
            or a
            sbc hl, de
            add hl, de
            jr nc, nx_done
            ld a, (hl)
            cp 13
            jr z, nx_on
            cp 10
            jr nz, nx_done
nx_on:
            inc hl
            jr nx_lp
nx_done:
            ld ({result}), hl
#endasm
End Function

' Num(): the number at rp (spaces before it skipped), rp past it
Private Function Num() As Integer
#asm
            ld hl, ({rp})
nm_sp:
            ld a, (hl)
            cp 32
            jr nz, nm_go
            inc hl
            jr nm_sp
nm_go:
            ld de, 0
nm_lp:
            ld a, (hl)
            sub 48
            jr c, nm_done
            cp 10
            jr nc, nm_done
            inc hl
            ld b, h                 ; (BC: where it is)
            ld c, l
            ld h, d                 ; DE * 10 + the digit
            ld l, e
            add hl, hl
            add hl, hl
            add hl, de
            add hl, hl
            ld e, a
            ld d, 0
            add hl, de
            ex de, hl
            ld h, b
            ld l, c
            jr nm_lp
nm_done:
            ld ({rp}), hl
            ld ({result}), de
#endasm
End Function

' n characters at a, as text (nothing escaped in a raw page)
Private Function Txt(ByVal a As Integer, ByVal n As Integer) As String Max 255
  Dim j As Integer
  Txt = ""
  If n > 255 Then n = 255
  For j = 0 To n - 1
    Txt = Txt + Chr$(Peek(a + j))
  Next
End Function

' a link at line i, column c, n characters long: to us, un
Private Sub AddLink(ByVal i As Integer, ByVal c As Integer, ByVal n As Integer)
  If nk > 119 Or n < 1 Then Exit Sub
  kl(nk) = i : kc(nk) = c : kn(nk) = n : ku(nk) = us : kv(nk) = un : kt(nk) = 0
  nk = nk + 1
End Sub

Public Function LinkUrl(ByVal i As Integer) As String Max 255
  LinkUrl = Txt(ku(i), kv(i))
End Function

Public Function FieldName(ByVal f As Integer) As String Max 80
  FieldName = Txt(fp(f), fn(f))
End Function

' field f on its line(s) again: |value___| (a password's as *), an area's rows, [ choice v]
Private Sub Show(ByVal f As Integer)
  Dim v As String Max 126, j As Integer, t As String Max 80
  v = Value(f)
  If ff(f) And 2 Then v = String$(Len(v), "*")
  If fk(f) = 3 Then
    Patch fy(f), fx(f), "[ " + Left$(Choice(f) + Space$(fw(f)), fw(f)) + " v]"
  Else
    For j = 0 To fr(f) - 1
      t = Mid$(v, j * fw(f) + 1, fw(f))
      Patch fy(f) + j, fx(f), "|" + t + String$(fw(f) - Len(t), "_") + "|"
    Next
  End If
End Sub

' line i from column c: s (as long as it is) - in the lines kept (marked written)
Private Sub Patch(ByVal i As Integer, ByVal c As Integer, ByVal s As String Max 80)
  Dim a As Integer, j As Integer, o As Integer
  If i >= nl Then Exit Sub
  a = Sel(i)                                     ' (its block here)
  o = wr : wr = -1
  a = Sel(i)                                     ' (... and marked written)
  wr = o
  For j = 0 To Len(s) - 1
    If c + j < w Then Poke a + c + j, Asc(Mid$(s, j + 1, 1))
  Next
End Sub

' a select's choices (its O records): how many; choice j's code and text
Public Function Options(ByVal f As Integer) As Integer
  Dim p As Integer
  Options = 0
  If fk(f) <> 3 Or fo(f) = 0 Then Exit Function
  p = fo(f)
  Do While p < pe
    If Peek(p) <> 79 Then Exit Do
    Options = Options + 1
    p = Nxt(Ends(p, pe, 0), pe)
  Loop
End Function
Public Function OptionCode(ByVal f As Integer, ByVal j As Integer) As String Max 80
  OptionCode = Opt(f, j, 0)
End Function
Public Function OptionText(ByVal f As Integer, ByVal j As Integer) As String Max 80
  OptionText = Opt(f, j, 1)
End Function
Private Function Opt(ByVal f As Integer, ByVal j As Integer, ByVal which As Integer) As String Max 80
  Dim p As Integer, t As Integer, e As Integer, k As Integer
  Opt = ""
  If fo(f) = 0 Then Exit Function
  p = fo(f)
  For k = 0 To j
    If p >= pe Then Exit Function
    If Peek(p) <> 79 Then Exit Function
    t = Ends(p + 1, pe, 1)                       ' (its code: to the TAB)
    e = Ends(p, pe, 0)
    If k = j Then
      If which = 0 Then Opt = Txt(p + 1, t - p - 1) Else Opt = Txt(t + 1, e - t - 1)
      Exit Function
    End If
    p = Nxt(e, pe)
  Next
End Function

' Query(i): button i's form as URL parameters - each field's name=value, then action=its text,
' joined by &, encoded - "" when longer than 255
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
' value the button's text, field f's): False when it doesn't fit
Private Function Add(ByVal a As Integer, ByVal n As Integer, ByVal f As Integer) As Integer
  Dim j As Integer
  Add = 0
  If qq <> "" Then qq = qq + "&"
  If a = 0 Then
    qq = qq + "action="
    For j = 0 To fn(f) - 1
      If Enc(Peek(fp(f) + j)) = 0 Then Exit Function
    Next
  Else
    For j = 0 To n - 1
      If Enc(Peek(a + j)) = 0 Then Exit Function
    Next
    qq = qq + "="
    a = vb + f * VSZ
    For j = 1 To Peek(a)
      If Enc(Peek(a + j)) = 0 Then Exit Function
    Next
  End If
  Add = -1
End Function

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

' line i's place in the buffers: its 2K block brought in from the store if it isn't in one (the
' one used longest ago given up - put back first if it was written to); while Render writes,
' marked written (and not fetched: its lines are written whole)
Private Function Sel(ByVal i As Integer) As Integer
  Dim k As Integer, j As Integer, o As Integer
  Sel = SelF(i)                                  ' (its block here already: Z80)
  If Sel <> 0 Then Exit Function
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

' SelF(i): line i's place when its block is in a buffer (marked used - and written while Render
' writes), else 0: Sel's quick way, in Z80
Private Function SelF(ByVal i As Integer) As Integer
#asm
            ld hl, 0
            ld ({result}), hl
            ld hl, ({i})
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            srl h
            rr l
            ex de, hl               ; DE = its block
            ld hl, {cbk}
            ld a, ({nb})
            ld b, a
            ld c, 0
sf_lp:
            ld a, (hl)
            cp e
            jr nz, sf_nx
            inc hl
            ld a, (hl)
            dec hl
            cp d
            jr z, sf_hit
sf_nx:
            inc hl
            inc hl
            inc c
            djnz sf_lp
            jr sf_end
sf_hit:                             ; C = the buffer
            ld hl, ({tick})
            inc hl
            ld ({tick}), hl
            ex de, hl
            ld l, c
            ld h, 0
            add hl, hl
            ld (sf_o2), hl
            ld bc, {clu}
            add hl, bc
            ld (hl), e
            inc hl
            ld (hl), d
            ld a, ({wr})
            or a
            jr z, sf_ad
            ld hl, (sf_o2)
            ld bc, {cdy}
            add hl, bc
            ld (hl), 255
            inc hl
            ld (hl), 255
sf_ad:
            ld hl, (sf_o2)
            ld a, l
            add a, a
            add a, a
            ld h, a
            ld l, 0                 ; the buffer * 2048
            ld a, ({i})
            and 15
            ld e, 0
            srl a
            rr e
            ld d, a                 ; + the line * 128
            add hl, de
            ld de, ({cb})
            add hl, de
            ld ({result}), hl
            jr sf_end
sf_o2:      dw 0
sf_end:
#endasm
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

' line a: w spaces, then n characters from p at column c (n 0 or less: none)
Private Sub Fill(ByVal a As Integer, ByVal c As Integer, ByVal p As Integer, ByVal n As Integer)
#asm
            ld hl, ({a})
            ld a, ({w})
            ld b, a
fi_f:
            ld (hl), 32
            inc hl
            djnz fi_f
            ld bc, ({n})
            bit 7, b
            jr nz, fi_done
            ld a, b
            or c
            jr z, fi_done
            ld hl, ({a})
            ld de, ({c})
            add hl, de
            ex de, hl
            ld hl, ({p})
            ldir
fi_done:
#endasm
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

' Forms(buf, n): the fields' values kept in buf - n of them (32 at most, VSZ bytes each: n * 128
' bytes); buf 0: fields only shown
Public Sub Forms(ByVal buf As Integer, ByVal n As Integer)
  vb = buf : fmx = n
  If fmx > 32 Then fmx = 32
End Sub

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
