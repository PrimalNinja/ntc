' RAT: the decision service (CyborgOS) - a port named RAT; a call "model tag tag:level ..." gets
' one decision back: "path value". The model (a MODEL server, by its port's name) holds the
' weights; RAT decides, the same rules for every model, at every level of it:
'   1  N (necessities: live or die) - a tag the model has under N whose level (tag:level, from the
'      caller: 0-100, how much of it there is) is below its N weight (the model's: where it takes
'      over - a brave one's flee 10, a fearful one's flee 60): the lowest, as part of its weight
'      (those within 5 of it), wins over everything; value 100 - that part
'   2  R (requirements: what we want of it - a game character's role) - the tags the model has
'      under R: the highest weights; value its weight
'   3  L, D (its own likes and dislikes) - among those left (all the tags when none is under R):
'      the highest L - D; value that
' Multilevel: the model is a tree as deep as its maker made it (2 levels or 50). When the tag
' chosen has branches under it (in any category), RAT chooses among them the same way (2, 3:
' the caller's levels are for the top), and on down to a branch with none; the answer is its
' path (food.fruit.apple) and the top level's value - why it acted. A caller may pass paths too
' (food.fruit.apple food.fruit.lemon: the choice starts below food.fruit).
' Weights within 5 of the best are as good: the one this model picked last time stays picked while
' it is among them (a deadband - near-equal choices don't flip back and forth, as a drone's
' would fight over itself), else one of them at random. Each level's pick is told to the model
' ("P path"): its L weight grows - a habit. "?" back: no such model, or no tags.
' "?model tag ..." gives the plan too (how it chose, a level a part: "food.fruit.apple 34 |N
' food=66 |LD fruit=50 +2 |LD apple=60 orange=55 +3 rnd/2" - each level's stage (N necessity: the
' level as a part of its threshold; R the R weights; LD L - D), its contenders (within 5 of the
' best; +n others not), kept (the deadband) or rnd/n (one of n at random); |dry at the end for a
' dry call); "~model ..." is dry: decided, nothing learnt or kept (PROBE: both)
' LUNs: "model:n tag ..." decides for LUN n of the model (a copy of its weights - one creature of
' a swarm: MODEL's "#n" messages); each LUN its own deadband. "LUNS model" - how many LUNs the
' model has (MODEL's U: "luns lines"); "!model message" - the message to the model as it is
' ("!PET #4 R": LUN 4 a new creature; "!PET #9 B 3 4": LUN 9 bred from 3 and 4)
'   RUN 2 MODEL RATMODEL : RUN 3 RAT : RATS        (the four corners: apps/rat/RATS.bas)
Option Explicit
Const TOL = 5                                 ' weights within this of the best: as good
Const DEEP = 64                               ' levels at most
Dim tg(15) As String Max 15, lv(15) As Integer, nt As Integer
Dim wn(15) As Integer, wr(15) As Integer, wl(15) As Integer, wd(15) As Integer
Dim cand(15) As Integer, nc As Integer, sc(15) As Integer, cv As Integer
Dim fx As Integer, fd As Integer, kp As Integer, pl As String Max 128, bs As String Max 110
Const NLAST = 128                             ' the last picks kept (a model's LUN each)
Dim lm(127) As String Max 12, lt(127) As String Max 110, nlm As Integer, cm As Integer   ' each model's (LUN's) last pick (the deadband)
Dim msg As String Max 128, rp As String Max 128, md As String Max 12, wrest As String Max 128
Dim lu As String Max 6                        ' the LUN asked for ("#n " before the model's messages; "" LUN 0)
Dim r As Integer, ch As Integer, nq As Integer

r = CybSys.PortOpen("RAT")
If r <> 0 Then Print "The port RAT is taken (RAT is running already?)" : End
Randomize CybSys.Clock()                      ' (a different sequence each time)
Print "RAT: the decision service, port RAT (Q ends it)"
Do
  r = CybSys.PortGet("RAT")
  If r = 0 Then
    msg = CybSys.PortMessage()
    rp = Decide(msg)
    r = CybSys.PortReply("RAT", rp)
    nq = nq + 1
    Print nq; ": "; msg; " -> "; rp
  Else
    ch = Inkey
    If ch = 81 Or ch = 113 Then Exit Do
  End If
Loop
r = CybSys.PortClose("RAT")
Print "RAT:"; nq; " decisions"
End

' a call: "model tag tag:level ...": the decision, "path value" ("?" none)
Function Decide(ByVal m As String) As String
  Dim j As Integer, t As String Max 110, w As String Max 128, i As Integer, pick As Integer
  Dim v0 As Integer, lev As Integer, path As String Max 110
  Decide = "?"
  m = Trim$(m)
  fx = 0 : fd = 0 : pl = ""                   ' (?: the plan too; ~: dry - nothing learnt or kept)
  Do While Left$(m, 1) = "?" Or Left$(m, 1) = "~"
    If Left$(m, 1) = "?" Then fx = 1 Else fd = 1
    m = Mid$(m, 2)
  Loop
  j = InStr(m, " ")
  If j = 0 Then Exit Function
  md = UCase$(Left$(m, j - 1))
  If md = "LUNS" Then                         ' (LUNS model: its LUNs and lines)
    Decide = CybSys.PortCall(UCase$(Trim$(Mid$(m, j + 1))), "U")
    If CybSys.PortStatus() <> 0 Then Decide = "?"
    Exit Function
  End If
  If Left$(md, 1) = "!" Then                  ' (!model message: passed on as it is)
    Decide = CybSys.PortCall(Mid$(md, 2), Trim$(Mid$(m, j + 1)))
    If CybSys.PortStatus() <> 0 Then Decide = "?"
    Exit Function
  End If
  lu = ""
  i = InStr(md, ":")                          ' (model:n - LUN n)
  If i > 0 Then
    If Val(Mid$(md, i + 1)) > 0 Then lu = "#" + Trim$(Str$(Val(Mid$(md, i + 1)))) + " "
    md = Left$(md, i - 1)
  End If
  cm = -1                                     ' (this model's - LUN's - place in the last picks)
  For i = 0 To nlm - 1
    If lm(i) = md + lu Then cm = i
  Next
  If cm < 0 Then
    If nlm < NLAST Then cm = nlm : nlm = nlm + 1 Else cm = Rnd(NLAST)
    lm(cm) = md + lu : lt(cm) = ""
  End If
  m = Trim$(Mid$(m, j + 1))
  nt = 0 : bs = ""
  Do While m <> "" And nt < 16
    j = InStr(m, " ")
    If j = 0 Then t = m : m = "" Else t = Left$(m, j - 1) : m = Trim$(Mid$(m, j + 1))
    j = InStr(t, ":")
    If j > 0 Then
      lv(nt) = Val(Mid$(t, j + 1)) : t = Left$(t, j - 1)
    Else
      lv(nt) = -1
    End If
    If nt = 0 Then                            ' (paths: the first one's part before its last dot is
      j = Dots(t)                             ' the branch they are all under)
      If j > 0 Then bs = Left$(t, j - 1)
    End If
    If bs <> "" Then
      If UCase$(Left$(t, Len(bs) + 1)) = UCase$(bs + ".") Then t = Mid$(t, Len(bs) + 2)
    End If
    tg(nt) = Left$(t, 15)
    nt = nt + 1
  Loop
  If nt = 0 Then Exit Function
  lev = 0
  Do                                          ' a level at a time, down to a branch with none under it
    If Weights() = 0 Then Exit Function
    pick = Choose(lev)
    If lev = 0 Then v0 = cv
    If bs = "" Then path = tg(pick) Else path = bs + "." + tg(pick)
    If fd = 0 Then w = CybSys.PortCall(md, lu + "P " + path)   ' (the habit: its like grows)
    lev = lev + 1
    If lev >= DEEP Then Exit Do
    w = CybSys.PortCall(md, lu + "C " + path)   ' (its branches: the next level)
    If CybSys.PortStatus() <> 0 Or Trim$(w) = "" Then Exit Do
    bs = path : nt = 0
    Do While w <> "" And nt < 16
      j = InStr(w, " ")
      If j = 0 Then t = w : w = "" Else t = Left$(w, j - 1) : w = Trim$(Mid$(w, j + 1))
      tg(nt) = Left$(t, 15) : lv(nt) = -1 : nt = nt + 1
    Loop
  Loop
  If fd = 0 Then lt(cm) = UCase$(path)
  Decide = path + Str$(v0)
  If fx Then                                  ' the plan: each level's stage, its contenders, how it chose
    If fd Then pl = pl + " |dry"
    Decide = Left$(Decide + " |" + pl, 127)
  End If
End Function

' the last dot's place in t (0 none)
Function Dots(ByVal t As String) As Integer
  Dim i As Integer
  Dots = 0
  For i = 1 To Len(t)
    If Mid$(t, i, 1) = "." Then Dots = i
  Next
End Function

' the model's N R L D weights for this level's tags (bs: the branch they are under) - 6 tags a
' call (an answer is 128 characters at most); 0: no such model
Function Weights() As Integer
  Dim i As Integer, k As Integer, j As Integer, w As String Max 128, t As String Max 20
  Weights = 0
  i = 0
  Do While i < nt
    w = lu + "W"
    If bs <> "" Then w = w + " @" + bs
    k = i
    Do While k < nt And k < i + 6
      w = w + " " + tg(k)
      k = k + 1
    Loop
    wrest = CybSys.PortCall(md, w)
    If CybSys.PortStatus() <> 0 Then Exit Function
    For j = i To k - 1
      t = FirstWord()
      wn(j) = Fld(t, 0) : wr(j) = Fld(t, 1) : wl(j) = Fld(t, 2) : wd(j) = Fld(t, 3)
    Next
    i = k
  Loop
  Weights = 1
End Function

' this level's choice (the rules 1-3; the necessities at the top only): its tag; cv its value
Function Choose(ByVal lev As Integer) As Integer
  Dim i As Integer, j As Integer, best As Integer, pick As Integer, s As String Max 110
  best = 999
  For i = 0 To nt - 1                         ' 1: a necessity low (its level below its N weight)
    sc(i) = 999
    If lev = 0 And wn(i) > 0 And lv(i) >= 0 And lv(i) < wn(i) Then sc(i) = (lv(i) * 100) \ wn(i)
    If sc(i) < best Then best = sc(i)
  Next
  nc = 0
  If best < 999 Then
    s = "N"
    For i = 0 To nt - 1
      If sc(i) <= best + TOL Then cand(nc) = i : nc = nc + 1 : s = s + " " + tg(i) + "=" + Trim$(Str$(sc(i)))
    Next
    i = Keep(nc)
    pick = cand(i)
    cv = 100 - sc(pick)
  Else
    best = -1                                 ' 2: what we want - the highest R weights
    For i = 0 To nt - 1
      If wr(i) > best Then best = wr(i)
    Next
    s = ""
    For i = 0 To nt - 1
      If best < 0 Or wr(i) >= best - TOL Then cand(nc) = i : nc = nc + 1
    Next
    If best >= 0 Then
      s = "R"
      For i = 0 To nc - 1
        s = s + " " + tg(cand(i)) + "=" + Trim$(Str$(wr(cand(i))))
      Next
      s = s + " |"
    End If
    For i = 0 To nc - 1                       ' 3: its own taste among them - the highest L - D
      j = cand(i)
      sc(i) = 0
      If wl(j) > 0 Then sc(i) = wl(j)
      If wd(j) > 0 Then sc(i) = sc(i) - wd(j)
    Next
    best = -999
    For i = 0 To nc - 1
      If sc(i) > best Then best = sc(i)
    Next
    j = 0
    For i = 0 To nc - 1
      If sc(i) >= best - TOL Then cand(j) = cand(i) : sc(j) = sc(i) : j = j + 1
    Next
    s = s + "LD"                              ' (the plan: the contenders, how many others)
    For i = 0 To j - 1
      s = s + " " + tg(cand(i)) + "=" + Trim$(Str$(sc(i)))
    Next
    If nc > j Then s = s + " +" + Trim$(Str$(nc - j))
    nc = j
    i = Keep(j)
    pick = cand(i)
    If wr(pick) >= 0 Then cv = wr(pick) Else cv = sc(i)
  End If
  If fx Then
    If kp Then
      s = s + " kept"
    ElseIf nc > 1 Then
      s = s + " rnd/" + Trim$(Str$(nc))
    End If
    If pl <> "" Then pl = pl + " |"
    pl = Left$(pl + s, 127)
  End If
  Choose = pick
End Function

' of the n candidates (cand): the one picked last time for this model if it is among them (or
' above it) - the deadband: near-equal choices don't flip back and forth -, else one at random
Function Keep(ByVal n As Integer) As Integer
  Dim i As Integer, p As String Max 110
  Keep = Rnd(n) : kp = 0
  For i = 0 To n - 1
    If bs = "" Then p = UCase$(tg(cand(i))) Else p = UCase$(bs + "." + tg(cand(i)))
    If lt(cm) = p Or Left$(lt(cm), Len(p) + 1) = p + "." Then Keep = i : kp = 1
  Next
End Function

' the first word of wrest, taken off it
Function FirstWord() As String
  Dim j As Integer
  wrest = Trim$(wrest)
  j = InStr(wrest, " ")
  If j = 0 Then
    FirstWord = wrest : wrest = ""
  Else
    FirstWord = Left$(wrest, j - 1) : wrest = Mid$(wrest, j + 1)
  End If
End Function

' field n (0 on) of t ("n,r,l,d"): its number (-1: none)
Function Fld(ByVal t As String, ByVal n As Integer) As Integer
  Dim j As Integer
  Do While n > 0
    j = InStr(t, ",")
    If j = 0 Then Fld = -1 : Exit Function
    t = Mid$(t, j + 1)
    n = n - 1
  Loop
  j = InStr(t, ",")
  If j > 0 Then t = Left$(t, j - 1)
  If t = "" Then Fld = -1 Else Fld = Val(t)
End Function
