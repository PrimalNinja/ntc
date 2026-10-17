' NEURAL file: a small neural net (jNeuralNetwork's way: property-based - the weights are what
' was seen, how often), served on a port named after its training file (CyborgOS). It learns
' records - properties and their values - and, asked with some of them, gives back the record
' that matches best, with the rest of its properties: what goes with what was asked. For
' decisions from inputs - CyborgOS's own numbers, a port's readings, a game's state - the logic
' kept out of each game or tool: trained by example, not written.
'   RUN 2 NEURAL NPC        (NPC.NN: the port is NPC - the file's name)
' The file (text): a record a line, prop=value words (8 at most, no spaces in them); *n at the
' end: seen n times (none: once); ' starts a comment line. Every prop=value seen has a weight:
' how many times it was trained.
'   seen=wolf near=yes action=run
'   seen=wolf near=no action=watch *3
' The port's messages:
'   T prop=value ...     train: the record learnt (again: its count and its values' weights up);
'                        "ok n" back (n records), "full"
'   Q prop=value ...     query: the record matching best - "score prop=value ..." back (score:
'                        0-100, how many of the asked props it has matched, of those it has),
'                        "?" none. prop=val* matches values starting val; prop? asks for that
'                        prop only (Q action? seen=wolf near=yes -> "100 action=run"). Numbers
'                        match by how near they are: 100 less how far apart, out of the range
'                        that prop has been trained with (free=200 is near free=224 of 0-320)
'   S                    saved (the file written again, the counts in it)
'   E                    saved, NEURAL ends (Q at its keyboard too)
' Ties: the matched values' weights (seen more), then the record's whole weight, then the first.
' Saved every 10 trainings and at the end
Option Explicit
Const MAXPV = 399                               ' prop=value pairs (their weights)
Const MAXPN = 63                                ' props
Const MAXRC = 199                               ' records
Const PERREC = 8                                  ' props a record
Dim pv(MAXPV) As String Max 32, pc(MAXPV) As Integer, pp(MAXPV) As Byte, npv As Integer
Dim pn2(MAXPV) As Byte, pnv(MAXPV) As Integer ' (a value that is a number: 1, and the number)
Dim plo(MAXPN) As Integer, phi(MAXPN) As Integer, pnn(MAXPN) As Byte   ' a prop's numbers: the lowest, the highest, any
Dim pn(MAXPN) As String Max 15, npn As Integer
Dim rk(MAXRC) As Byte, ri((MAXRC + 1) * PERREC) As Integer, rc(MAXRC) As Integer, nrc As Integer
Dim qp(PERREC) As Integer, qv(PERREC) As Integer, qw(PERREC) As String Max 32, qa(PERREC) As Byte, nq As Integer
Dim qn(PERREC) As Byte, qnv(PERREC) As Integer ' (an asked value that is a number)
Dim fl As String Max 16, tf As String Max 16, pt As String Max 8, ws As String Max 128
Dim h As Integer, h2 As Integer, r As Integer, k As Integer, ch As Integer, dirty As Integer, nm As Integer
Dim ln As String Max 128, msg As String Max 128, rp As String Max 128
Const FBN = 8191                              ' the file's buffer: 8K
Dim fb(FBN) As Byte, n As Integer
Dim a(PERREC) As Integer                          ' (Learn's: the record's pairs)

fl = UCase$(Trim$(CybSys.Tail()))
If fl = "" Then Print "NEURAL file[.NN]: a neural net for its records, served on a port named after the file" : End
k = InStr(fl, " ")
If k > 0 Then fl = Left$(fl, k - 1)
If InStr(fl, ".") = 0 Then fl = fl + ".NN"
pt = Left$(Left$(fl, InStr(fl, ".") - 1), 8)
r = CybSys.PortOpen(pt)                       ' (the port first: calls wait while it learns)
If r <> 0 Then Print "The port "; pt; " is taken (another NEURAL "; pt; "?)" : End
n = FileSystem.Load(fl, VarPtr(fb), FBN + 1)  ' the file in at once (the disc's read stream is one for
If n > 0 Then                                 ' every slot: held no longer than that), then learnt
  h = 0                                       ' (h: where the line starts)
  For k = 0 To n
    ch = 10
    If k < n Then ch = fb(k)
    If ch = 26 Then ch = 10 : n = k
    If ch = 13 Or ch = 10 Then
      ln = ""                                 ' the line copied into ln (a String: its text, then 0)
      For r = 0 To k - h - 1
        If r < 127 Then Poke VarPtr(ln) + r, fb(h + r)
      Next
      r = k - h : If r > 127 Then r = 127
      Poke VarPtr(ln) + r, 0
      ln = Trim$(ln)
      If ln <> "" And Left$(ln, 1) <> "'" Then r = Learn(ln)
      h = k + 1
    End If
  Next
ElseIf n = FileSystem.TooBig Then             ' (too big for that: a line at a time)
  h = FileSystem.Open(fl, FileSystem.ForRead)
  If h >= 0 Then
    Do While FileSystem.Eof(h) = 0
      ln = Trim$(FileSystem.ReadLine(h))
      If ln <> "" And Left$(ln, 1) <> "'" Then r = Learn(ln)
    Loop
    r = FileSystem.Close(h)
  End If
End If
Print "NEURAL "; fl; ": port "; pt; ","; nrc; " records,"; npv; " values (Q saves and ends)"
Do
  r = CybSys.PortGet(pt)
  If r = 0 Then
    msg = CybSys.PortMessage()
    rp = Answer(msg)
    r = CybSys.PortReply(pt, rp)
    nm = nm + 1
    If rp = "end" Then Exit Do
  Else
    ch = Inkey
    If ch = 81 Or ch = 113 Then Exit Do
  End If
Loop
If dirty > 0 Then Save
r = CybSys.PortClose(pt)
Print "NEURAL "; pt; ":"; nm; " messages"
End

' a message from the port: its answer
Function Answer(ByVal m As String) As String
  Dim c As String Max 1
  c = UCase$(Left$(m, 1))
  m = Trim$(Mid$(m, 2))
  Answer = "?"
  If c = "T" Then
    If Learn(m) Then
      Answer = "ok" + Str$(nrc)
      dirty = dirty + 1
      If dirty >= 10 Then Save
    Else
      Answer = "full"
    End If
  ElseIf c = "Q" Then
    Answer = Query(m)
  ElseIf c = "S" Then
    Save
    Answer = "ok"
  ElseIf c = "E" Then
    Answer = "end"
  End If
End Function

' the next word of ws, taken off it ("" none)
Function NextTok() As String
  Dim j As Integer
  ws = Trim$(ws)
  j = InStr(ws, " ")
  If j = 0 Then
    NextTok = ws : ws = ""
  Else
    NextTok = Left$(ws, j - 1) : ws = Mid$(ws, j + 1)
  End If
End Function

' prop name p: its number (add: 1 - a new one made; -1 none / no room)
Function Prop(ByVal p As String, ByVal add As Integer) As Integer
  Dim i As Integer
  Prop = -1
  For i = 0 To npn - 1
    If pn(i) = p Then Prop = i : Exit Function
  Next
  If add = 0 Or npn > MAXPN Then Exit Function
  pn(npn) = p : Prop = npn : npn = npn + 1
End Function

' "prop=value": its number in pv (add: 1 - a new one made, its weight 0; -1 none / no room)
Function Pair(ByVal t As String, ByVal add As Integer) As Integer
  Dim i As Integer, j As Integer, p As Integer
  Pair = -1
  For i = 0 To npv - 1
    If pv(i) = t Then Pair = i : Exit Function
  Next
  If add = 0 Or npv > MAXPV Then Exit Function
  j = InStr(t, "=")
  p = Prop(Left$(t, j - 1), 1)
  If p < 0 Then Exit Function
  pv(npv) = t : pc(npv) = 0 : pp(npv) = p : pn2(npv) = 0
  t = Mid$(t, j + 1)
  If IsNum(t) Then                            ' a number: the prop's range wider
    pn2(npv) = 1 : pnv(npv) = Val(t)
    If pnn(p) = 0 Then plo(p) = pnv(npv) : phi(p) = pnv(npv) : pnn(p) = 1
    If pnv(npv) < plo(p) Then plo(p) = pnv(npv)
    If pnv(npv) > phi(p) Then phi(p) = pnv(npv)
  End If
  Pair = npv : npv = npv + 1
End Function

' a record learnt ("prop=value ... [*n]"): its count and its values' weights up n; 0 no room
Function Learn(ByVal s As String) As Integer
  Dim t As String Max 32, n As Integer, na As Integer, i As Integer, j As Integer, r As Integer
  Learn = 0
  ws = s : n = 1 : na = 0
  Do
    t = NextTok()
    If t = "" Then Exit Do
    If Left$(t, 1) = "*" Then
      n = Val(Mid$(t, 2))
      If n < 1 Then n = 1
    ElseIf InStr(t, "=") > 1 And na < PERREC Then
      j = Pair(t, 1)
      If j < 0 Then Exit Function
      a(na) = j : na = na + 1
    End If
  Loop
  If na = 0 Then Exit Function
  For r = 0 To nrc - 1                        ' the same record again?
    If rk(r) = na Then
      j = 0
      For i = 0 To na - 1
        If ri(r * PERREC + i) = a(i) Then j = j + 1
      Next
      If j = na Then Exit For
    End If
  Next
  If r >= nrc Then
    If nrc > MAXRC Then Exit Function
    r = nrc : nrc = nrc + 1
    rk(r) = na : rc(r) = 0
    For i = 0 To na - 1
      ri(r * PERREC + i) = a(i)
    Next
  End If
  rc(r) = rc(r) + n
  For i = 0 To na - 1
    pc(a(i)) = pc(a(i)) + n
  Next
  Learn = 1
End Function

' a query: the best record ("score prop=value ...", "?" none)
Function Query(ByVal s As String) As String
  Dim t As String Max 32, j As Integer, i As Integer, r As Integer, x As Integer, nask As Integer
  Dim tot As Integer, mt As Integer, w As Integer, w2 As Integer, sc As Integer, d As Integer
  Dim bs As Integer, bw As Integer, bw2 As Integer, br As Integer
  Query = "?"
  ws = s : nq = 0 : nask = 0
  Do
    t = NextTok()
    If t = "" Or nq > PERREC Then Exit Do
    qa(nq) = 0 : qv(nq) = -1 : qw(nq) = "" : qn(nq) = 0
    If Right$(t, 1) = "?" Then                ' prop?: asked for
      qp(nq) = Prop(Left$(t, Len(t) - 1), 0) : qa(nq) = 1 : nask = nask + 1
      nq = nq + 1
    Else
      j = InStr(t, "=")
      If j > 1 Then
        qp(nq) = Prop(Left$(t, j - 1), 0)
        If Right$(t, 1) = "*" Then
          qw(nq) = Left$(t, Len(t) - 1)       ' (prop=val: the start the value must have)
        Else
          qv(nq) = Pair(t, 0)
          If IsNum(Mid$(t, j + 1)) Then qn(nq) = 1 : qnv(nq) = Val(Mid$(t, j + 1))
        End If
        nq = nq + 1
      End If
    End If
  Loop
  bs = 0 : bw = -1 : bw2 = -1 : br = -1
  For r = 0 To nrc - 1
    tot = 0 : mt = 0 : w = 0 : w2 = 0
    For i = 0 To rk(r) - 1
      x = ri(r * PERREC + i)
      w2 = w2 + pc(x)
      For j = 0 To nq - 1
        If qa(j) = 0 And qp(j) = pp(x) Then
          tot = tot + 1
          d = Near(j, x)
          If d > 0 Then mt = mt + d : w = w + pc(x)       ' (score: the props' nearness, out of 100 each)
        End If
      Next
    Next
    If tot > 0 And mt > 0 Then
      sc = mt \ tot
      If sc > bs Or (sc = bs And (w > bw Or (w = bw And w2 > bw2))) Then
        bs = sc : bw = w : bw2 = w2 : br = r
      End If
    End If
  Next
  If br < 0 Then Exit Function
  Query = Trim$(Str$(bs))
  For i = 0 To rk(br) - 1
    x = ri(br * PERREC + i)
    k = 1                                     ' (asked for some: those only)
    If nask > 0 Then
      k = 0
      For j = 0 To nq - 1
        If qa(j) = 1 And qp(j) = pp(x) Then k = 1
      Next
    End If
    If k = 1 And Len(Query) + Len(pv(x)) < 127 Then Query = Query + " " + pv(x)
  Next
End Function

' how near asked prop j's value is to pair x's (the same prop): 100 the same (or its start, for
' val*), else for numbers 100 less how far apart they are, the prop's range (lowest to highest
' trained) 100 - 0 at that far or more; 0 for text not the same
Function Near(ByVal j As Integer, ByVal x As Integer) As Integer
  Dim d As Integer, g As Integer
  Near = 0
  If qv(j) = x Then Near = 100 : Exit Function
  If qw(j) <> "" Then
    If Left$(pv(x), Len(qw(j))) = qw(j) Then Near = 100
    Exit Function
  End If
  If qn(j) = 0 Or pn2(x) = 0 Then Exit Function
  g = phi(pp(x)) - plo(pp(x))
  If g < 1 Then g = 1
  d = Abs(qnv(j) - pnv(x))
  If d >= g Then Exit Function
  If g > 300 Then Near = 100 - d \ (g \ 100) Else Near = 100 - (d * 100) \ g
  If Near < 0 Then Near = 0
End Function

' s a number? (digits, - first)
Function IsNum(ByVal s As String) As Integer
  Dim i As Integer, c As String Max 1
  IsNum = 0
  If s = "" Or s = "-" Then Exit Function
  For i = 1 To Len(s)
    c = Mid$(s, i, 1)
    If (c < "0" Or c > "9") And Not (c = "-" And i = 1) Then Exit Function
  Next
  IsNum = 1
End Function

' the records back into the file (through NAME.$$$): a line each, *n when seen more than once;
' the file's comment lines first, as they were
Sub Save()
  Dim r As Integer, i As Integer, s As String Max 128
  tf = Left$(fl, InStr(fl, ".")) + "$$$"
  h2 = FileSystem.Open(tf, FileSystem.ForWrite)
  If h2 < 0 Then Exit Sub
  h = FileSystem.Open(fl, FileSystem.ForRead)
  If h >= 0 Then
    Do While FileSystem.Eof(h) = 0
      s = FileSystem.ReadLine(h)
      If Left$(Trim$(s), 1) = "'" Then r = FileSystem.WriteLine(h2, s)
    Loop
    r = FileSystem.Close(h)
  End If
  For r = 0 To nrc - 1
    s = ""
    For i = 0 To rk(r) - 1
      If s <> "" Then s = s + " "
      s = s + pv(ri(r * PERREC + i))
    Next
    If rc(r) > 1 Then s = s + " *" + Trim$(Str$(rc(r)))
    i = FileSystem.WriteLine(h2, s)
  Next
  r = FileSystem.Close(h2)
  r = FileSystem.Delete(fl)
  r = FileSystem.Rename(tf, fl)
  dirty = 0
End Sub
