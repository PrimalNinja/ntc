' PET: a virtual pet in the spirit of the Tamagotchi (CyborgOS). It lives in a room with four
' corners - BED, FOOD (its bowl), PLAY, TV - and decides for itself what to do next: RAT asks its
' model (PET.MDL) - hungry, tired or bored wins (necessities), else what it likes. You keep it:
'   F  fill the bowl (it can only eat when there is food in it)
'   T  the TV on / off (it only watches when it is on)
'   C  clean up its mess (left after eating - mess makes it ill)
'   M  medicine (when it is ill; when it isn't, it does it harm)
'   +  praise what it is doing - it likes that more (its model's L weight up 3)
'   -  scold it - it stops, and likes that less (down 3)
'   Q  quit: saved to PET.SAV, the pet as you left it next time
' Doing the same thing three times running bores it (that like down 2): habits form, but it
' keeps some variety. It grows (a day a minute): baby o, child r, adult R, old &. It falls ill when the room is dirty
' or it starves; its health goes when it is starving, worn out or ill - at 0 it dies.
'   RUN 2 MODEL PET : RUN 3 RAT : PET [name]       (PET NEW name: a new pet; PET name n: n tenths of
'                                                   a second, then saved and ended - for tests)
Option Explicit
Option Terminal VT52
Const W = 60                                  ' the room: columns 1-W, rows 3-H
Const H = 18
Const DAY = 600                               ' ticks (a tenth of a second) a day
Dim cx(3) As Integer, cy(3) As Integer, cn(3) As String Max 5
Dim nm As String Max 12, age As Integer, ad As Integer
Dim food As Integer, energy As Integer, fun As Integer, clean As Integer, health As Integer
Dim bowl As Integer, tvon As Integer, sick As Integer, np As Integer, ppx(7) As Integer, ppy(7) As Integer
Dim st As Integer, g As Integer, gn As String Max 8, dt As Integer, tk As Integer, mx As Integer
Dim rx As Integer, ry As Integer, tx As Integer, ty As Integer, ox As Integer, oy As Integer, pt As Integer
Dim rep As Integer
Dim last As String Max 8, ms As String Max 58, rp As String Max 128, a As String Max 72
Dim ch As Integer, i As Integer, j As Integer, k As Integer, r As Integer, t0 As Integer, dead As Integer

cn(0) = "BED" : cx(0) = 2 : cy(0) = 4
cn(1) = "FOOD" : cx(1) = W - 7 : cy(1) = 4
cn(2) = "PLAY" : cx(2) = 2 : cy(2) = H - 1
cn(3) = "TV" : cx(3) = W - 7 : cy(3) = H - 1
Randomize CybSys.Clock()
a = Trim$(CybSys.Tail())
j = 0
If UCase$(Left$(a, 4)) = "NEW " Then a = Trim$(Mid$(a, 5)) : j = 1
k = InStr(a, " ")
If k > 0 Then mx = Val(Mid$(a, k + 1)) : a = Left$(a, k - 1)
If k = 0 And Val(a) > 0 Then mx = Val(a) : a = ""           ' (PET n: the pet as saved, n tenths)
If j = 1 Or Load() = 0 Then
  nm = a : If nm = "" Then nm = "Pet"
  age = 0 : ad = 0 : food = 70 : energy = 80 : fun = 60 : clean = 100 : health = 100
  bowl = 3 : tvon = 0 : sick = 0 : np = 0
  ms = nm + " is born!"
Else
  ms = nm + " is back."
End If
rx = W \ 2 : ry = (H + 3) \ 2 : st = 0 : pt = -1
Room
Do
  t0 = CybSys.Clock()
  tk = tk + 1
  Live
  If dead Then Exit Do
  If st = 0 Then Decide
  If st < 0 Then Exit Do
  Act
  Show
  Do                                          ' a tenth of a second, the keys looked at
    ch = Inkey
    If ch <> 0 Then Keys
  Loop While CybSys.Clock() - t0 < 30 And ch <> 81 And ch <> 113
  If ch = 81 Or ch = 113 Then Exit Do
  If mx > 0 And tk >= mx Then Exit Do
Loop
Locate 1, H + 4
If dead Then
  Print nm; " has died, aged "; age; " days. Rest in peace."
  r = FileSystem.Delete("PET.SAV")
ElseIf st >= 0 Then
  Save
  Print nm; " is saved (PET.SAV), aged "; age; " days."
End If
End

' a tick of life: things run down, it grows, falls ill, gets better or worse
Sub Live()
  ad = ad + 1
  If ad >= DAY Then ad = 0 : age = age + 1 : ms = nm + " is" + Str$(age) + " days old."
  If st = 3 Then                              ' asleep: slower
    If tk Mod 120 = 0 Then food = food - 1
    If tk Mod 150 = 0 Then fun = fun - 1
  Else
    If tk Mod 60 = 0 Then food = food - 1
    If tk Mod 80 = 0 Then energy = energy - 1
    If tk Mod 50 = 0 Then fun = fun - 1
  End If
  If tk Mod 100 = 0 Then clean = clean - np * 3
  If tk Mod 50 = 0 And sick = 0 And (clean < 40 Or food = 0) Then
    If Rnd(4) = 0 Then sick = 1 : ms = nm + " is ill! (M: medicine)"
  End If
  If sick And tk Mod 20 = 0 Then health = health - 1
  If (food = 0 Or energy = 0) And tk Mod 30 = 0 Then health = health - 1
  If sick = 0 And food > 50 And energy > 50 And fun > 50 And tk Mod 60 = 0 Then health = health + 1
  If age >= 30 And tk Mod 100 = 0 Then health = health - 1   ' (old age)
  If pt > 0 Then                              ' after eating: a mess
    pt = pt - 1
    If pt = 0 And np < 8 Then
      ppx(np) = 3 + Rnd(W - 6) : ppy(np) = 6 + Rnd(H - 9) : np = np + 1
      Locate ppx(np - 1), ppy(np - 1) : Print "%";
      ms = nm + " made a mess. (C: clean)"
    End If
  End If
  food = Lim(food) : energy = Lim(energy) : fun = Lim(fun) : clean = Lim(clean) : health = Lim(health)
  If energy = 0 And st <> 3 Then st = 3 : g = 0 : ms = nm + " fell asleep where it was."
  If health = 0 Then dead = 1
End Sub

Function Lim(ByVal v As Integer) As Integer
  If v < 0 Then v = 0
  If v > 100 Then v = 100
  Lim = v
End Function

' what next: RAT asks the model - from what it can do now
Sub Decide()
  a = "PET bed:" + Trim$(Str$(energy)) + " play:" + Trim$(Str$(fun)) + " wander"
  If bowl > 0 Then a = a + " food:" + Trim$(Str$(food))
  If tvon Then a = a + " tv"
  rp = CybSys.PortCall("RAT", a)
  If CybSys.PortStatus() <> 0 Then
    Locate 1, H + 4
    Print "No RAT service (RUN 2 MODEL PET, RUN 3 RAT)"
    st = -1
    Exit Sub
  End If
  j = InStr(rp, " ")
  If j > 0 Then gn = Left$(rp, j - 1) Else gn = rp
  gn = LCase$(gn)
  If gn = last Then rep = rep + 1 Else rep = 0
  last = gn
  If rep >= 2 Then rp = CybSys.PortCall("PET", "X " + gn + " 2")   ' (the same again: bored of it)
  g = -1
  For i = 0 To 3
    If gn = LCase$(cn(i)) Then g = i
  Next
  If gn = "wander" Then
    tx = 4 + Rnd(W - 8) : ty = 6 + Rnd(H - 9) : g = 4
  ElseIf g >= 0 Then
    tx = cx(g) + 1 : ty = cy(g) + 1
  Else
    Exit Sub                                  ' ("?": the model is not there - asked again)
  End If
  st = 1
  If food < 30 And bowl = 0 Then ms = nm + " is hungry and the bowl is empty! (F)"
End Sub

' walking there, then doing it
Sub Act()
  If st = 1 Then
    If tk Mod 2 = 0 Then
      If rx < tx Then rx = rx + 1
      If rx > tx Then rx = rx - 1
      If ry < ty Then ry = ry + 1
      If ry > ty Then ry = ry - 1
    End If
    If rx = tx And ry = ty Then
      st = 2 : dt = 40
      If g = 0 Then st = 3 : ms = nm + " goes to bed."
      If g = 1 Then ms = nm + " eats."
      If g = 2 Then ms = nm + " plays."
      If g = 3 Then ms = nm + " watches TV."
      If g = 4 Then dt = 20                   ' (wandering: it looks around a while)
    End If
  ElseIf st = 2 Then
    dt = dt - 1
    If g = 1 And dt Mod 10 = 0 Then
      If bowl > 0 Then bowl = bowl - 1 : food = food + 25 : pt = 100
      If bowl = 0 Or food >= 95 Then dt = 0
    End If
    If g = 2 Then fun = fun + 1 : If dt Mod 8 = 0 Then energy = energy - 1
    If g = 3 Then
      If dt Mod 2 = 0 Then fun = fun + 1
      If tvon = 0 Then dt = 0
    End If
    fun = Lim(fun) : food = Lim(food) : energy = Lim(energy)
    If dt <= 0 Then st = 0
  ElseIf st = 3 Then
    If tk Mod 2 = 0 Then energy = energy + 1
    If energy >= 100 Then energy = 100 : st = 0 : ms = nm + " wakes up."
  End If
End Sub

' a key
Sub Keys()
  Select Case ch
    Case 70, 102                              ' F
      bowl = 5 : ms = "You fill the bowl."
    Case 84, 116                              ' T
      tvon = 1 - tvon
      If tvon Then ms = "The TV is on." Else ms = "The TV is off."
    Case 67, 99                               ' C
      For i = 0 To np - 1
        Locate ppx(i), ppy(i) : Print " ";
      Next
      np = 0 : clean = 100 : ms = "You clean up."
    Case 77, 109                              ' M
      If sick Then
        sick = 0 : health = Lim(health + 10) : ms = nm + " is well again."
      Else
        health = Lim(health - 5) : ms = nm + " didn't need medicine."
      End If
    Case 43                                   ' +
      If last <> "" Then
        rp = CybSys.PortCall("PET", "P " + last + " 3")
        ms = nm + " loves the praise: more " + last + "."
      End If
    Case 45                                   ' -
      If last <> "" Then
        rp = CybSys.PortCall("PET", "X " + last + " 3")
        ms = nm + " sulks: less " + last + "."
        If st = 1 Or st = 2 Then st = 0
      End If
  End Select
End Sub

' the screen: the pet where it is now, the bars, the message
Sub Show()
  Dim f As String Max 7
  If ox <> rx Or oy <> ry Then
    Locate ox, oy : Print " ";
    For i = 0 To np - 1                       ' (a mess it walked over)
      If ppx(i) = ox And ppy(i) = oy Then Locate ox, oy : Print "%";
    Next
  End If
  Locate ox + 1, oy : If st = 3 Or ox <> rx Or oy <> ry Then Print " ";
  Locate cx(0), cy(0) : Print "BED";          ' (the corners again: it may have walked over them)
  Locate cx(1), cy(1) : Print "FOOD"; Trim$(Str$(bowl));
  Locate cx(2), cy(2) : Print "PLAY";
  Locate cx(3), cy(3) : If tvon Then Print "TV*"; Else Print "TV ";
  Locate rx, ry
  If age < 2 Then Print "o"; Else If age < 5 Then Print "r"; Else If age < 30 Then Print "R"; Else Print "&";
  If st = 3 Then Print "z";
  ox = rx : oy = ry
  f = "(^.^)"
  If fun < 30 Then f = "(-_-)"
  If food < 30 Then f = "(o.O)"
  If st = 3 Then f = "(-.-)"
  If sick Then f = "(x.x)"
  Locate 1, 1
  Print nm; "  "; f; "  day "; age; "   bowl "; bowl; "  TV "; : If tvon Then Print "on "; Else Print "off";
  Print "    "
  Locate 1, 2
  Print "Fd "; Bar(food); "  En "; Bar(energy); "  Fn "; Bar(fun); "  Cl "; Bar(clean); "  Hp "; Bar(health)
  Locate 1, H + 2 : Print Left$(ms + Space$(58), 58);
End Sub

Function Bar(ByVal v As Integer) As String
  Bar = String$(v \ 10, "#") + String$(10 - v \ 10, ".")
End Function

' the room and its corners
Sub Room()
  Dim y As Integer
  Cls
  Locate 1, 3 : Print "+"; String$(W - 2, "-"); "+"
  For y = 4 To H
    Locate 1, y : Print "|"; : Locate W, y : Print "|"
  Next
  Locate 1, H + 1 : Print "+"; String$(W - 2, "-"); "+"
  For y = 0 To 3
    Locate cx(y), cy(y) : Print cn(y);
  Next
  For y = 0 To np - 1
    Locate ppx(y), ppy(y) : Print "%";
  Next
  Locate 1, H + 3 : Print "F food  T TV  C clean  M medicine  + praise  - scold  Q quit";
  ox = rx : oy = ry
End Sub

' PET.SAV: a value a line (1 loaded, 0 none)
Function Load() As Integer
  Dim h As Integer
  Load = 0
  h = FileSystem.Open("PET.SAV", FileSystem.ForRead)
  If h < 0 Then Exit Function
  nm = FileSystem.ReadLine(h)
  age = Val(FileSystem.ReadLine(h)) : ad = Val(FileSystem.ReadLine(h))
  food = Val(FileSystem.ReadLine(h)) : energy = Val(FileSystem.ReadLine(h)) : fun = Val(FileSystem.ReadLine(h))
  clean = Val(FileSystem.ReadLine(h)) : health = Val(FileSystem.ReadLine(h))
  bowl = Val(FileSystem.ReadLine(h)) : tvon = Val(FileSystem.ReadLine(h)) : sick = Val(FileSystem.ReadLine(h))
  np = Val(FileSystem.ReadLine(h))
  If np > 8 Then np = 8
  For i = 0 To np - 1
    ppx(i) = Val(FileSystem.ReadLine(h)) : ppy(i) = Val(FileSystem.ReadLine(h))
  Next
  r = FileSystem.Close(h)
  If nm <> "" Then Load = 1
End Function

Sub Save()
  Dim h As Integer
  h = FileSystem.Open("PET.SAV", FileSystem.ForWrite)
  If h < 0 Then Exit Sub
  r = FileSystem.WriteLine(h, nm)
  r = FileSystem.WriteLine(h, Str$(age)) : r = FileSystem.WriteLine(h, Str$(ad))
  r = FileSystem.WriteLine(h, Str$(food)) : r = FileSystem.WriteLine(h, Str$(energy)) : r = FileSystem.WriteLine(h, Str$(fun))
  r = FileSystem.WriteLine(h, Str$(clean)) : r = FileSystem.WriteLine(h, Str$(health))
  r = FileSystem.WriteLine(h, Str$(bowl)) : r = FileSystem.WriteLine(h, Str$(tvon)) : r = FileSystem.WriteLine(h, Str$(sick))
  r = FileSystem.WriteLine(h, Str$(np))
  For i = 0 To np - 1
    r = FileSystem.WriteLine(h, Str$(ppx(i))) : r = FileSystem.WriteLine(h, Str$(ppy(i)))
  Next
  r = FileSystem.Close(h)
End Sub
