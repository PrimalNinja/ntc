' RATBOX: a box of pet rats - a swarm on one model (CyborgOS). Each rat is a LUN of RATBOX.MDL (its
' own copy of the weights: its own habits), and RAT decides for each - hungry, tired or bored
' wins, else what it likes: eat, sleep, play, the TV, wander, groom a friend, mate, fight a rival,
' nurse its babies. Rats like or dislike each other (playing and grooming together, mating: more;
' fighting: less). Healthy adults of the two sexes mate; two males after the same female fight it
' out in the boxing ring (bottom middle) - the loser hurt, the winner mates. Babies are born in the
' pen (the right side) and live on their mother's nursing until they are weaned (3 days); each is
' bred from its parents' LUNs (MODEL's B: each weight one parent's, a little changed). The dead go
' to the graveyard (the left side). A crowded box makes more mess, eats more, gets ill, fights and
' breeds less. A litter: 1-3, three days after mating; then three days before she mates again.
'   RUN 2 MODEL RATBOX : RUN 3 RAT : RATBOX [males females] [n]
'   (RATBOX alone: the box as it was saved - RATBOX.SAV -, else it asks how many; males females:
'    a new box; n: n tenths of a second, then saved and ended - RATBOX n: the saved box - for tests)
' How many rats at most: the model's LUNs (RAT's "LUNS RATBOX"), 100 at most.
' Keys: F fill the bowl, T the TV, C clean, M medicine (the ill ones), . and , the next / last rat
' (the one chosen: @, its state below), N the chosen one to the naughty bed (top middle: a while
' there, and less of what it was doing), + praise (more of what it is doing), - scold, Q quit (saved)
Option Explicit
Option Terminal VT52
Const MAXR = 100                              ' rats at most
Const DAY = 300                               ' ticks a day
Const CAP = 20                                ' more rats than this: crowded
Dim rx(99) As Integer, ry(99) As Integer, ox(99) As Integer, oy(99) As Integer
Dim tx(99) As Integer, ty(99) As Integer, st(99) As Integer, g(99) As Integer, dt(99) As Integer
Dim fd(99) As Integer, en(99) As Integer, fn(99) As Integer, hp(99) As Integer, sk(99) As Byte
Dim age(99) As Integer, sx(99) As Byte, pg(99) As Integer, mt(99) As Integer, mo(99) As Integer
Dim la(99) As String Max 8, rp2(99) As Byte, fa(99) As Integer, fv(99) As Integer   ' (fa: the father of her litter; fv: the female a fight is for)
Dim lk(9999) As Byte                          ' how much rat i likes rat j: lk(i * MAXR + j), 0-100
Dim cx(7) As Integer, cy(7) As Integer, cn(7) As String Max 8
Dim gx(29) As Integer, gy(29) As Integer, ng As Integer          ' the graves
Dim px(39) As Integer, py(39) As Integer, np As Integer          ' the mess
Dim W As Integer, H As Integer, MY As Integer, cr As Integer, nr As Integer, topr As Integer
Dim bowl As Integer, tvon As Integer, clean As Integer, sel As Integer, tk As Long, mx As Long
Dim ms As String Max 70, a As String Max 255, rp As String Max 128, gn As String Max 8
Dim ch As Integer, i As Integer, j As Integer, k As Integer, r As Integer, t0 As Integer, nd As Integer
Dim nm As Integer, nf As Integer, born As Integer, died As Integer

Randomize CybSys.Clock()
cr = Peek(&HF688) : If cr < 20 Then cr = 24
W = 78 : H = cr - 3 : MY = (4 + H) \ 2       ' (the room: columns 1-W, rows 3-H; MY its middle row)
cn(0) = "BED" : cx(0) = 3 : cy(0) = 4
cn(1) = "FOOD" : cx(1) = W - 8 : cy(1) = 4
cn(2) = "PLAY" : cx(2) = 3 : cy(2) = H - 1
cn(3) = "TV" : cx(3) = W - 5 : cy(3) = H - 1
cn(4) = "NAUGHTY" : cx(4) = W \ 2 - 3 : cy(4) = 4
cn(5) = "[RING]" : cx(5) = W \ 2 - 3 : cy(5) = H - 1
cn(6) = "GRAVES" : cx(6) = 3 : cy(6) = MY - 2
cn(7) = "PEN" : cx(7) = W - 9 : cy(7) = MY - 2
For k = 1 To 30                               ' (RAT and the model may be starting still: 9 seconds)
  rp = CybSys.PortCall("RAT", "LUNS RATBOX")
  If CybSys.PortStatus() = 0 And Val(rp) >= 2 Then Exit For
  t0 = CybSys.Clock()
  Do While CybSys.Clock() - t0 < 90
  Loop
Next
If CybSys.PortStatus() <> 0 Or Val(rp) < 2 Then Print "No RAT or no RATBOX model (RUN 2 MODEL RATBOX, RUN 3 RAT)" : End
topr = Val(rp) - 1                            ' (LUN 0 is the model's own: rat i is LUN i + 1)
If topr > MAXR Then topr = MAXR
a = Trim$(CybSys.Tail())
nm = -1 : nf = -1
If a <> "" Then
  k = InStr(a, " ")
  If k = 0 Then
    mx = Val(a)                               ' (RATBOX n: the box as saved, n tenths)
  Else
    nm = Val(a)
    a = Trim$(Mid$(a, k + 1)) : nf = Val(a)
    k = InStr(a, " ")
    If k > 0 Then mx = Val(Mid$(a, k + 1))
  End If
End If
If nm < 0 Or nf < 0 Then
  If Load() = 0 Then
    Print "RATBOX: up to"; topr; "rats (the model's LUNs)"
    a = "" : Input "How many males"; a : nm = Val(a)
    a = "" : Input "How many females"; a : nf = Val(a)
  End If
End If
If nm >= 0 And nf >= 0 Then NewBox
Room
Do
  t0 = CybSys.Clock()
  tk = tk + 1
  Live
  nd = 0
  For k = 0 To nr - 1                         ' (two decisions a tick at most: each asks RAT)
    i = (k + tk) Mod nr
    If st(i) = 0 And nd < 2 Then Decide i : nd = nd + 1
  Next
  If nd < 0 Then Exit Do
  For i = 0 To nr - 1
    If st(i) > 0 Then Act i
  Next
  Show
  Do
    ch = Inkey
    If ch <> 0 Then Keys
  Loop While CybSys.Clock() - t0 < 30 And ch <> 81 And ch <> 113
  If ch = 81 Or ch = 113 Then Exit Do
  If mx > 0 And tk >= mx Then Exit Do
  If Alive() = 0 Then ms = "All the rats have died." : Show : Exit Do
Loop
Save
Locate 1, cr
Print "RATBOX: saved (RATBOX.SAV) - "; Trim$(Str$(Alive())); " rats, "; Trim$(Str$(born)); " born, "; Trim$(Str$(died)); " died"
End

' a new box: nm males, nf females (young adults), each LUN as the model's
Sub NewBox()
  nr = nm + nf
  If nr > topr Then nr = topr
  For i = 0 To nr - 1
    NewRat i, 3 + Rnd(10), 4 + Rnd(H - 6)
    age(i) = 5 + Rnd(3) : st(i) = 0
    If i < nm Then sx(i) = 0 Else sx(i) = 1
    rp = CybSys.PortCall("RAT", "!RATBOX #" + Trim$(Str$(i + 1)) + " R")
  Next
  For i = 0 To nr - 1
    For j = 0 To nr - 1
      lk(i * MAXR + j) = 40 + Rnd(30)
    Next
  Next
  bowl = 5 + nr : tvon = 0 : clean = 100 : np = 0 : ng = 0 : sel = 0
  ms = "A new box:" + Str$(nm) + " males," + Str$(nf) + " females."
End Sub

Sub NewRat(ByVal i As Integer, ByVal x As Integer, ByVal y As Integer)
  rx(i) = x : ry(i) = y : ox(i) = x : oy(i) = y : tx(i) = x : ty(i) = y
  fd(i) = 70 : en(i) = 80 : fn(i) = 60 : hp(i) = 100 : sk(i) = 0 : pg(i) = 0 : mt(i) = -1 : mo(i) = -1 : fa(i) = -1 : fv(i) = -1
  la(i) = "" : rp2(i) = 0 : g(i) = 0 : dt(i) = 0
End Sub

Function Alive() As Integer
  Dim n As Integer, q As Integer
  n = 0
  For q = 0 To nr - 1
    If st(q) >= 0 Then n = n + 1
  Next
  Alive = n
End Function

Function Lim(ByVal v As Integer) As Integer
  If v < 0 Then v = 0
  If v > 100 Then v = 100
  Lim = v
End Function

' a tick of life for them all
Sub Live()
  Dim n As Integer, crowd As Integer, q As Integer
  n = Alive()
  crowd = 0 : If n > CAP Then crowd = 1
  If tk Mod 100 = 0 Then clean = Lim(clean - np * 2 - crowd * 3)
  For i = 0 To nr - 1
    If st(i) >= 0 Then
      If tk Mod DAY = i Mod DAY Then
        age(i) = age(i) + 1
        If st(i) = 6 And age(i) >= 3 Then st(i) = 0 : rx(i) = cx(7) - 2 : ms = Who(i) + " is weaned and leaves the pen."
      End If
      q = 60 - crowd * 20
      If st(i) = 3 Then q = q * 2
      If tk Mod q = i Mod q Then fd(i) = fd(i) - 1
      If st(i) <> 3 And tk Mod 80 = i Mod 80 Then en(i) = en(i) - 1
      If st(i) <> 6 And tk Mod 50 = i Mod 50 Then fn(i) = fn(i) - 1
      If tk Mod 50 = i Mod 50 And sk(i) = 0 And (clean < 40 Or fd(i) = 0) Then
        If Rnd(4 - crowd) = 0 Then sk(i) = 1 : ms = Who(i) + " is ill! (M: medicine)"
      End If
      If sk(i) And tk Mod 20 = i Mod 20 Then hp(i) = hp(i) - 1
      If (fd(i) = 0 Or en(i) = 0) And tk Mod 30 = i Mod 30 Then hp(i) = hp(i) - 1
      If sk(i) = 0 And fd(i) > 50 And en(i) > 50 And fn(i) > 40 And tk Mod 60 = i Mod 60 Then hp(i) = hp(i) + 1
      If age(i) >= 40 And tk Mod 100 = i Mod 100 Then hp(i) = hp(i) - 1    ' (old age)
      If crowd And tk Mod 200 = i Mod 200 Then                          ' (crowded: tempers fray)
        q = Rnd(nr)
        If q <> i Then lk(i * MAXR + q) = Lim(lk(i * MAXR + q) - 3)
      End If
      If pg(i) > 0 Then                       ' (expecting: pg ticks to go; after a litter, pg < 0: resting)
        pg(i) = pg(i) - 1
        If pg(i) = 0 Then Birth i
      ElseIf pg(i) < 0 Then
        pg(i) = pg(i) + 1
      End If
      fd(i) = Lim(fd(i)) : en(i) = Lim(en(i)) : fn(i) = Lim(fn(i)) : hp(i) = Lim(hp(i))
      If en(i) = 0 And st(i) > 0 And st(i) < 3 Then st(i) = 3 : g(i) = 0
      If hp(i) = 0 Then Dies i
    End If
  Next
End Sub

Function Who(ByVal i As Integer) As String
  If sx(i) = 0 Then Who = "#" + Trim$(Str$(i + 1)) + " (M)" Else Who = "#" + Trim$(Str$(i + 1)) + " (F)"
End Function

' rat i dies: a grave (the left side); its LUN free for a baby
Sub Dies(ByVal i As Integer)
  st(i) = -1 : died = died + 1
  Locate rx(i), ry(i) : Print " ";
  If ng < 30 Then gx(ng) = 3 + (ng Mod 6) : gy(ng) = MY - 1 + ng \ 6 : ng = ng + 1
  ms = Who(i) + " has died, aged" + Str$(age(i)) + " days."
  If sel = i Then NextSel 1
End Sub

' mother i gives birth: 1-4 babies in the pen, each bred from its parents' LUNs
Sub Birth(ByVal i As Integer)
  Dim n As Integer, q As Integer, b As Integer, f2 As Integer
  f2 = fa(i)
  If f2 < 0 Or f2 >= nr Then f2 = i
  n = 1 + Rnd(3)
  b = 0
  For q = 1 To n
    k = Free()
    If k >= 0 Then
      NewRat k, cx(7) + Rnd(7), MY - 1 + Rnd(3)
      st(k) = 6 : age(k) = 0 : sx(k) = Rnd(2) : mo(k) = i : fd(k) = 60
      rp = CybSys.PortCall("RAT", "!RATBOX #" + Trim$(Str$(k + 1)) + " B " + Trim$(Str$(i + 1)) + " " + Trim$(Str$(f2 + 1)))
      For j = 0 To nr - 1
        lk(k * MAXR + j) = 50 : lk(j * MAXR + k) = 50
      Next
      lk(k * MAXR + i) = 90 : lk(i * MAXR + k) = 90
      b = b + 1 : born = born + 1
    End If
  Next
  fa(i) = -1 : pg(i) = -DAY * 3               ' (three days before she mates again)
  If b = 0 Then ms = Who(i) + " lost her litter: the box is full." Else ms = Who(i) + " gave birth to" + Str$(b) + " in the pen."
End Sub

' a free place for a rat (a dead one's, or a new one): -1 none
Function Free() As Integer
  Dim q As Integer
  Free = -1
  For q = 0 To nr - 1
    If st(q) < 0 Then Free = q : Exit Function
  Next
  If nr < topr Then Free = nr : nr = nr + 1
End Function

' the rat rat i likes best of those that can (kind: 0 a partner - the other sex, adult, free; 1 a
' friend - grown, awake; 2 a rival - an adult male it dislikes): -1 none
Function Best(ByVal i As Integer, ByVal kind As Integer) As Integer
  Dim q As Integer, b As Integer, v As Integer
  Best = -1 : b = -1
  For q = 0 To nr - 1
    If q <> i And st(q) >= 0 And st(q) <> 6 And st(q) <> 4 And st(q) <> 5 And age(q) >= 3 Then
      v = lk(i * MAXR + q)
      If kind = 0 And sx(q) <> sx(i) And age(q) >= 5 And pg(q) = 0 And pg(i) = 0 And hp(q) > 50 And v >= 40 And st(q) <> 3 Then
        If v > b Then b = v : Best = q
      ElseIf kind = 1 And v >= 60 And st(q) <> 3 Then
        If v > b Then b = v : Best = q
      ElseIf kind = 2 And sx(q) = 0 And age(q) >= 5 And v < 30 Then
        If 100 - v > b Then b = 100 - v : Best = q
      End If
    End If
  Next
End Function

' rat i's mother has babies in the pen still: how many
Function Babies(ByVal i As Integer) As Integer
  Dim q As Integer, n As Integer
  n = 0
  For q = 0 To nr - 1
    If st(q) = 6 And mo(q) = i Then n = n + 1
  Next
  Babies = n
End Function

' what next for rat i: RAT asks its LUN - from what it can do now
Sub Decide(ByVal i As Integer)
  Dim q As Integer
  a = "RATBOX:" + Trim$(Str$(i + 1)) + " bed:" + Trim$(Str$(en(i))) + " play:" + Trim$(Str$(fn(i))) + " wander"
  If bowl > 0 Then a = a + " food:" + Trim$(Str$(fd(i)))
  If tvon Then a = a + " tv"
  If age(i) >= 5 And hp(i) > 50 And fd(i) > 30 And pg(i) = 0 And (Alive() <= CAP Or Rnd(3) = 0) Then
    If Best(i, 0) >= 0 Then a = a + " mate"  ' (crowded: less in the mood)
  End If
  If Best(i, 1) >= 0 Then a = a + " groom"
  If sx(i) = 0 And age(i) >= 5 Then
    If Best(i, 2) >= 0 Then a = a + " fight"
  End If
  If sx(i) = 1 And hp(i) > 40 And fd(i) > 40 Then
    If Babies(i) > 0 Then a = a + " nurse"
  End If
  rp = CybSys.PortCall("RAT", a)
  If CybSys.PortStatus() <> 0 Then
    ms = "No RAT service (RUN 2 MODEL RATBOX, RUN 3 RAT)" : nd = -99
    Exit Sub
  End If
  j = InStr(rp, " ")
  If j > 0 Then gn = LCase$(Left$(rp, j - 1)) Else gn = LCase$(rp)
  If gn = la(i) Then rp2(i) = rp2(i) + 1 Else rp2(i) = 0
  la(i) = gn
  If rp2(i) >= 2 Then rp = CybSys.PortCall("RAT", "!RATBOX #" + Trim$(Str$(i + 1)) + " X " + gn + " 2")   ' (bored of it)
  g(i) = -1 : mt(i) = -1
  If gn = "bed" Then
    g(i) = 0
  ElseIf gn = "food" Then
    g(i) = 1
  ElseIf gn = "play" Then
    g(i) = 2
  ElseIf gn = "tv" Then
    g(i) = 3
  ElseIf gn = "nurse" Then
    g(i) = 7
  ElseIf gn = "wander" Then
    g(i) = 8 : tx(i) = 12 + Rnd(W - 24) : ty(i) = 5 + Rnd(H - 7)
  ElseIf gn = "mate" Then
    q = Best(i, 0)
    If q >= 0 Then Court i, q
    Exit Sub
  ElseIf gn = "groom" Then
    q = Best(i, 1)
    If q >= 0 Then g(i) = 9 : mt(i) = q : tx(i) = rx(q) : ty(i) = ry(q)
  ElseIf gn = "fight" Then
    q = Best(i, 2)
    If q >= 0 Then Fight i, q, -1
    Exit Sub
  End If
  If g(i) < 0 Then Exit Sub                   ' ("?": asked again)
  If g(i) <= 7 Then                           ' (beside the place's name: below it at the top, above it at the bottom)
    tx(i) = cx(g(i)) + Rnd(3)
    If cy(g(i)) > MY Then ty(i) = cy(g(i)) - 1 Else ty(i) = cy(g(i)) + 1
  End If
  If g(i) = 7 Then tx(i) = cx(7) - 2 : ty(i) = MY - 1 + Rnd(3)
  st(i) = 1
End Sub

' i courts q: a rival - a male who likes her as much, and dislikes i - fights i for her in the ring
Sub Court(ByVal i As Integer, ByVal q As Integer)
  Dim f As Integer, m As Integer, c As Integer
  If sx(i) = 1 Then f = i : m = q Else f = q : m = i
  For c = 0 To nr - 1
    If c <> m And st(c) > 0 And st(c) <> 6 And st(c) <> 4 And st(c) <> 5 And sx(c) = 0 And age(c) >= 5 Then
      If lk(c * MAXR + f) >= lk(m * MAXR + f) And lk(c * MAXR + m) < 50 Then
        ms = Who(c) + " and " + Who(m) + " fight over " + Who(f) + "!"
        Fight m, c, f
        Exit Sub
      End If
    End If
  Next
  Pair m, f
End Sub

' m and f meet (where she is) and mate
Sub Pair(ByVal m As Integer, ByVal f As Integer)
  g(m) = 10 : mt(m) = f : tx(m) = rx(f) : ty(m) = ry(f) : st(m) = 1
  g(f) = 10 : mt(f) = m : tx(f) = rx(f) : ty(f) = ry(f) : st(f) = 1
  ms = Who(m) + " courts " + Who(f) + "."
End Sub

' i and q fight in the ring (for f, a female: the winner then mates her; -1 none)
Sub Fight(ByVal i As Integer, ByVal q As Integer, ByVal f As Integer)
  g(i) = 11 : mt(i) = q : tx(i) = cx(5) + 1 : ty(i) = cy(5) - 1 : st(i) = 1 : fv(i) = f
  g(q) = 11 : mt(q) = i : tx(q) = cx(5) + 4 : ty(q) = cy(5) - 1 : st(q) = 1 : fv(q) = f
  If ms = "" Or Left$(ms, 1) <> "#" Then ms = Who(i) + " picks a fight with " + Who(q) + "."
End Sub

' rat i: walking there, then doing it
Sub Act(ByVal i As Integer)
  Dim q As Integer
  If st(i) = 1 Then
    If tk Mod 2 = i Mod 2 Then
      If rx(i) < tx(i) Then rx(i) = rx(i) + 1
      If rx(i) > tx(i) Then rx(i) = rx(i) - 1
      If ry(i) < ty(i) Then ry(i) = ry(i) + 1
      If ry(i) > ty(i) Then ry(i) = ry(i) - 1
    End If
    If rx(i) = tx(i) And ry(i) = ty(i) Then Arrive i
  ElseIf st(i) = 2 Then
    dt(i) = dt(i) - 1
    If g(i) = 10 Or g(i) = 11 Then            ' (the other gone - the naughty bed, asleep: it's off)
      q = mt(i)
      If q < 0 Then
        dt(i) = 0
      ElseIf st(q) <> 1 And st(q) <> 2 Then
        dt(i) = 0
      End If
    End If
    Select Case g(i)
      Case 1
        If dt(i) Mod 10 = 0 Then
          If bowl > 0 Then
            bowl = bowl - 1 : fd(i) = fd(i) + 25
            If np < 40 And Rnd(2) = 0 Then px(np) = 12 + Rnd(W - 24) : py(np) = 5 + Rnd(H - 7) : np = np + 1
          End If
          If bowl = 0 Or fd(i) >= 95 Then dt(i) = 0
        End If
      Case 2
        fn(i) = fn(i) + 1 : If dt(i) Mod 8 = 0 Then en(i) = en(i) - 1
      Case 3
        If dt(i) Mod 2 = 0 Then fn(i) = fn(i) + 1
        If tvon = 0 Then dt(i) = 0
      Case 7                                  ' (nursing: her babies fed)
        If dt(i) Mod 10 = 0 Then
          For q = 0 To nr - 1
            If st(q) = 6 And mo(q) = i Then fd(q) = Lim(fd(q) + 15)
          Next
          fd(i) = fd(i) - 3 : en(i) = en(i) - 1
        End If
      Case 9                                  ' (grooming a friend: both happier, closer)
        fn(i) = fn(i) + 1
        q = mt(i)
        If q >= 0 And dt(i) Mod 10 = 0 Then
          fn(q) = Lim(fn(q) + 3)
          lk(i * MAXR + q) = Lim(lk(i * MAXR + q) + 2) : lk(q * MAXR + i) = Lim(lk(q * MAXR + i) + 2)
        End If
      Case 10                                 ' (mating)
        q = mt(i)
        If dt(i) = 1 And sx(i) = 1 And q >= 0 Then
          pg(i) = DAY * 3 : fa(i) = q
          lk(i * MAXR + q) = Lim(lk(i * MAXR + q) + 10) : lk(q * MAXR + i) = Lim(lk(q * MAXR + i) + 10)
          ms = Who(i) + " is expecting (" + Who(q) + ")."
        End If
      Case 11                                 ' (the fight)
        If dt(i) Mod 5 = 0 Then en(i) = en(i) - 1
        If dt(i) = 1 Then FightEnd i
    End Select
    fn(i) = Lim(fn(i)) : fd(i) = Lim(fd(i)) : en(i) = Lim(en(i))
    If dt(i) <= 0 Then st(i) = 0 : mt(i) = -1
  ElseIf st(i) = 3 Then
    If tk Mod 2 = i Mod 2 Then en(i) = en(i) + 1
    If en(i) >= 100 Then en(i) = 100 : st(i) = 0
  ElseIf st(i) = 4 Then                       ' (on the naughty bed)
    dt(i) = dt(i) - 1
    If dt(i) <= 0 Then st(i) = 0 : ms = Who(i) + " leaves the naughty bed."
  ElseIf st(i) = 6 Then                       ' (a baby in the pen: it wanders there)
    If tk Mod 20 = i Mod 20 Then
      rx(i) = cx(7) + Rnd(7) : ry(i) = MY - 1 + Rnd(3)
    End If
  End If
End Sub

' rat i is there: doing it (a pair or a fight starts when both are there)
Sub Arrive(ByVal i As Integer)
  Dim q As Integer
  st(i) = 2 : dt(i) = 40
  If g(i) = 0 Then st(i) = 3
  If g(i) = 8 Then dt(i) = 20
  If g(i) = 10 Or g(i) = 11 Then
    q = mt(i)
    If q < 0 Then st(i) = 0 : Exit Sub
    If st(q) = 2 And g(q) = g(i) And mt(q) = i Then
      If g(i) = 11 Then
        dt(q) = 30 : dt(i) = 30
      Else
        dt(i) = 30 : dt(q) = 30
      End If
    ElseIf st(q) = 1 And mt(q) = i Then
      st(i) = 2 : dt(i) = 9999                ' (waiting for the other: its arrival sets both)
    Else
      st(i) = 0                               ' (the other has gone)
    End If
  End If
End Sub

' the fight's end (seen by i): the stronger (health, and luck) wins; the loser is hurt; they like
' each other less; the winner mates the female it was for
Sub FightEnd(ByVal i As Integer)
  Dim q As Integer, w As Integer, l As Integer, f As Integer
  q = mt(i)
  If q < 0 Then Exit Sub
  If st(q) <> 2 Or g(q) <> 11 Then Exit Sub
  If hp(i) + Rnd(40) >= hp(q) + Rnd(40) Then w = i : l = q Else w = q : l = i
  hp(l) = Lim(hp(l) - 25) : hp(w) = Lim(hp(w) - 5)
  lk(i * MAXR + q) = Lim(lk(i * MAXR + q) - 20) : lk(q * MAXR + i) = Lim(lk(q * MAXR + i) - 20)
  st(l) = 0 : st(w) = 0 : mt(l) = -1 : mt(w) = -1 : dt(q) = 0
  ms = Who(w) + " wins the fight with " + Who(l) + "."
  f = fv(i)
  If f >= 0 And f < nr Then
    If st(f) >= 0 And st(f) <> 6 And pg(f) = 0 Then Pair w, f
  End If
End Sub

' a key
Sub Keys()
  Select Case ch
    Case 70, 102                              ' F
      bowl = 5 + Alive() : ms = "You fill the bowl."
    Case 84, 116                              ' T
      tvon = 1 - tvon
      If tvon Then ms = "The TV is on." Else ms = "The TV is off."
    Case 67, 99                               ' C
      For i = 0 To np - 1
        Locate px(i), py(i) : Print " ";
      Next
      np = 0 : clean = 100 : ms = "You clean up."
    Case 77, 109                              ' M
      k = 0
      For i = 0 To nr - 1
        If st(i) >= 0 And sk(i) Then sk(i) = 0 : hp(i) = Lim(hp(i) + 10) : k = k + 1
      Next
      ms = "Medicine:" + Str$(k) + " rats well again."
    Case 46, 9                                ' . or Tab: the next rat
      NextSel 1
    Case 44                                   ' ,
      NextSel -1
    Case 78, 110                              ' N: the naughty bed
      If sel >= 0 And st(sel) >= 0 And st(sel) <> 6 Then
        If la(sel) <> "" Then rp = CybSys.PortCall("RAT", "!RATBOX #" + Trim$(Str$(sel + 1)) + " X " + la(sel) + " 3")
        If mt(sel) >= 0 Then
          If mt(mt(sel)) = sel Then st(mt(sel)) = 0 : mt(mt(sel)) = -1
        End If
        st(sel) = 4 : dt(sel) = 100 : mt(sel) = -1
        rx(sel) = cx(4) + Rnd(7) : ry(sel) = cy(4) + 1
        ms = Who(sel) + " goes to the naughty bed (less " + la(sel) + ")."
      End If
    Case 43, 45                               ' + -
      If sel >= 0 And la(sel) <> "" Then
        If ch = 43 Then a = " P " Else a = " X "
        rp = CybSys.PortCall("RAT", "!RATBOX #" + Trim$(Str$(sel + 1)) + a + la(sel) + " 3")
        If ch = 43 Then ms = Who(sel) + " loves the praise: more " + la(sel) + "." Else ms = Who(sel) + " sulks: less " + la(sel) + "."
      End If
  End Select
End Sub

Sub NextSel(ByVal d As Integer)
  Dim q As Integer
  For q = 1 To nr
    sel = (sel + d + nr) Mod nr
    If st(sel) >= 0 Then Exit Sub
  Next
End Sub

' the screen: the rats where they are now, the places, the chosen one, the message
Sub Show()
  Dim c As String Max 1, f As Integer, q As Integer
  For i = 0 To nr - 1                         ' (where they were: cleared)
    If st(i) >= 0 And (ox(i) <> rx(i) Or oy(i) <> ry(i)) Then Locate ox(i), oy(i) : Print " ";
  Next
  For q = 0 To 7
    Locate cx(q), cy(q) : Print cn(q);
  Next
  Locate cx(1) + 4, cy(1) : Print Trim$(Str$(bowl)); " ";
  Locate cx(3) + 2, cy(3) : If tvon Then Print "*"; Else Print " ";
  For q = 0 To ng - 1
    Locate gx(q), gy(q) : Print "+";
  Next
  For q = 0 To np - 1
    Locate px(q), py(q) : Print "%";
  Next
  f = 0
  For i = 0 To nr - 1
    If st(i) >= 0 Then
      If age(i) < 3 Then
        c = "o"
      ElseIf age(i) >= 40 Then
        c = "&"
      ElseIf sx(i) = 0 Then
        If age(i) < 5 Then c = "m" Else c = "M"
      Else
        If age(i) < 5 Then c = "f" Else c = "F"
      End If
      If st(i) = 2 And g(i) = 11 Then c = "*"
      If i = sel Then c = "@"
      Locate rx(i), ry(i) : Print c;
      ox(i) = rx(i) : oy(i) = ry(i)
    End If
  Next
  q = Alive()
  Locate 1, 1
  Print "RATBOX "; Trim$(Str$(q)); " rats  day "; Trim$(Str$(tk \ DAY)); "  bowl "; Trim$(Str$(bowl)); "  clean "; Trim$(Str$(clean));
  If q > CAP Then Print "  CROWDED"; Else Print "         ";
  Print "  born "; Trim$(Str$(born)); " died "; Trim$(Str$(died)); "    "
  Locate 1, 2
  If sel >= 0 And sel < nr Then
    If st(sel) >= 0 Then
      a = Who(sel) + " age" + Str$(age(sel)) + " Fd" + Str$(fd(sel)) + " En" + Str$(en(sel)) + " Fn" + Str$(fn(sel)) + " Hp" + Str$(hp(sel))
      If sk(sel) Then a = a + " ill"
      If pg(sel) > 0 Then a = a + " expecting"
      a = a + " - " + Doing(sel)
      Print Left$(a + Space$(78), 78);
    End If
  End If
  Locate 1, H + 1 : Print Left$(ms + Space$(70), 70);
End Sub

Function Doing(ByVal i As Integer) As String
  Dim s As String Max 20
  s = la(i)
  If st(i) = 1 Then s = "going to " + s
  If st(i) = 3 Then s = "asleep"
  If st(i) = 4 Then s = "on the naughty bed"
  If st(i) = 6 Then s = "a baby in the pen"
  If st(i) = 0 Then s = "thinking"
  Doing = s
End Function

' the room
Sub Room()
  Dim y As Integer
  Cls
  Locate 1, 3 : Print "+"; String$(W - 2, "-"); "+"
  For y = 4 To H
    Locate 1, y : Print "|"; : Locate W, y : Print "|";
  Next
  Locate 1, H : Print "+"; String$(W - 2, "-"); "+";
  Locate 1, H + 2 : Print "F food T TV C clean M medicine . , choose N naughty + praise - scold Q quit";
  For y = 0 To nr - 1
    ox(y) = rx(y) : oy(y) = ry(y)
  Next
End Sub

' RATBOX.SAV: the box (1 loaded, 0 none) - the rats' LUNs are kept by MODEL (RATBOX.LUN)
Function Load() As Integer
  Dim h As Integer
  Load = 0
  h = FileSystem.Open("RATBOX.SAV", FileSystem.ForRead)
  If h < 0 Then Exit Function
  nr = Val(FileSystem.ReadLine(h))
  If nr > topr Then nr = topr
  bowl = Val(FileSystem.ReadLine(h)) : tvon = Val(FileSystem.ReadLine(h)) : clean = Val(FileSystem.ReadLine(h))
  tk = Val(FileSystem.ReadLine(h)) : born = Val(FileSystem.ReadLine(h)) : died = Val(FileSystem.ReadLine(h))
  ng = Val(FileSystem.ReadLine(h)) : If ng > 30 Then ng = 30
  For i = 0 To ng - 1
    gx(i) = 3 + (i Mod 6) : gy(i) = MY - 1 + i \ 6
  Next
  For i = 0 To nr - 1
    a = FileSystem.ReadLine(h)
    st(i) = Fld(0) : age(i) = Fld(1) : sx(i) = Fld(2) : fd(i) = Fld(3) : en(i) = Fld(4) : fn(i) = Fld(5)
    hp(i) = Fld(6) : sk(i) = Fld(7) : pg(i) = Fld(8) : mo(i) = Fld(9) : rx(i) = Fld(10) : ry(i) = Fld(11)
    mt(i) = -1 : la(i) = "" : g(i) = 0
    If st(i) > 0 And st(i) <> 6 And st(i) <> 3 Then st(i) = 0
  Next
  For i = 0 To nr - 1                         ' (how they like each other: a line a rat, 2 hex digits each)
    a = FileSystem.ReadLine(h)
    For j = 0 To nr - 1
      lk(i * MAXR + j) = HexV(Mid$(a, j * 2 + 1, 2))
    Next
    If pg(i) > 0 Then fa(i) = HexV(Mid$(a, nr * 2 + 1, 2)) - 1
  Next
  r = FileSystem.Close(h)
  ms = "The box as it was:" + Str$(Alive()) + " rats."
  If nr > 0 Then Load = 1
End Function

' two hex digits' value
Function HexV(ByVal h As String) As Integer
  Dim q As Integer, c As Integer, v As Integer
  v = 0
  For q = 1 To Len(h)
    c = Asc(UCase$(Mid$(h, q, 1)))
    If c >= 65 Then c = c - 55 Else c = c - 48
    v = v * 16 + c
  Next
  HexV = v
End Function

' field n (0 on) of a (comma separated)
Function Fld(ByVal n As Integer) As Integer
  Dim s As String Max 128, j As Integer
  s = a
  Do While n > 0
    j = InStr(s, ",")
    If j = 0 Then Fld = 0 : Exit Function
    s = Mid$(s, j + 1)
    n = n - 1
  Loop
  Fld = Val(s)
End Function

Sub Save()
  Dim h As Integer
  h = FileSystem.Open("RATBOX.SAV", FileSystem.ForWrite)
  If h < 0 Then Exit Sub
  r = FileSystem.WriteLine(h, Str$(nr))
  r = FileSystem.WriteLine(h, Str$(bowl)) : r = FileSystem.WriteLine(h, Str$(tvon)) : r = FileSystem.WriteLine(h, Str$(clean))
  r = FileSystem.WriteLine(h, Str$(tk)) : r = FileSystem.WriteLine(h, Str$(born)) : r = FileSystem.WriteLine(h, Str$(died))
  r = FileSystem.WriteLine(h, Str$(ng))
  For i = 0 To nr - 1
    a = Trim$(Str$(st(i))) + "," + Trim$(Str$(age(i))) + "," + Trim$(Str$(sx(i))) + "," + Trim$(Str$(fd(i))) + "," + Trim$(Str$(en(i)))
    a = a + "," + Trim$(Str$(fn(i))) + "," + Trim$(Str$(hp(i))) + "," + Trim$(Str$(sk(i))) + "," + Trim$(Str$(pg(i))) + "," + Trim$(Str$(mo(i)))
    a = a + "," + Trim$(Str$(rx(i))) + "," + Trim$(Str$(ry(i)))
    r = FileSystem.WriteLine(h, a)
  Next
  For i = 0 To nr - 1
    a = ""
    For j = 0 To nr - 1
      a = a + Right$("0" + Hex$(lk(i * MAXR + j)), 2)
    Next
    a = a + Right$("0" + Hex$(fa(i) + 1), 2)
    r = FileSystem.WriteLine(h, a)
  Next
  r = FileSystem.Close(h)
  rp = CybSys.PortCall("RAT", "!RATBOX S")    ' (the model's weights and LUNs saved too)
End Sub
