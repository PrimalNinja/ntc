' MODEL file: a decision model, served on a port (CyborgOS) - RAT (the decision service) asks it
' for the weights of the tags it is given, and tells it which one was picked. The model is fixed
' but for its weights: L (likes) grow a point each time their tag is picked (to 100) - a habit -,
' and are saved back to the file every 10 changes and when the model ends (Q).
'   RUN 2 MODEL RATMODEL        (RATMODEL.MDL: the port is RATMODEL - the file's name; RATMODEL.TXT
'                                tells how a model is made)
' The file: a line a branch, its depth the spaces before it; the top lines the categories -
'   N  necessities: live or die (the caller passes their level: food:15 - below the N weight,
'      the threshold, it wins over all)
'   R  requirements: what we want of it (a game character's role)
'   L  likes, D  dislikes: its own preferences
' then branches to any depth, each a name and a weight 0-100 (none: 50); a tag names a branch
' (food) or a path to one (food.apple); ' starts a comment line
'   N                     L
'    food 25               food 40
'    bed 25                 apple 60
'   R                       lemon 10
'    play 30               tv 50
' "V [cat\]tag\tag\...\x" - that branch's weight set to x, from outside (a sensor, a game: cat N R
' L or D, none L; "?" no such branch).
' The port's messages (from RAT): "W [@path] tag tag ..." - each tag's weights, "n,r,l,d" (-1: not in
' that category), a space between tags (@path: the tags are under that branch); "C path" - the
' branches under it, in any category (RAT goes down the tree with it, as deep as it is); "P tag [n]" - picked (or praised): its L weight up a point (n
' points); "X tag [n]" - scolded: down a point (n); "D n" - line n ("L 1 FOOD 40": its category,
' depth, name, weight; "end" past the last - PROBE shows a model with it); "S" - saved; "Q" -
' saved, the model ends
Option Explicit
Const MAXN = 400
Dim nd(MAXN) As Byte                          ' a branch's depth (0: a category line: N, R, L, D)
Dim nw(MAXN) As Integer                       ' its weight
Dim nm(MAXN) As String Max 15                 ' its name (a category: its letter)
Dim nn As Integer, fl As String Max 16, tf As String Max 16, pn As String Max 8
Dim h As Integer, h2 As Integer, r As Integer, k As Integer, i As Integer, ch As Integer, dirty As Integer, nq As Integer
Dim ln As String Max 120, msg As String Max 128, rp As String Max 128, w As String Max 40
Dim kd As Integer, kdep As Integer, kname As String Max 15, kw As Integer, kcat As Integer   ' (Parse's)
Dim kraw As String Max 15                    ' (the name as written: Save keeps it)

fl = UCase$(Trim$(CybSys.Tail()))
If fl = "" Then Print "MODEL file[.MDL]: a model for RAT, served on a port named after the file" : End
k = InStr(fl, " ")
If k > 0 Then fl = Left$(fl, k - 1)
If InStr(fl, ".") = 0 Then fl = fl + ".MDL"
pn = Left$(Left$(fl, InStr(fl, ".") - 1), 8)
h = FileSystem.Open(fl, FileSystem.ForRead)
If h < 0 Then Print "No such model: "; fl : End
kcat = 0
Do While FileSystem.Eof(h) = 0
  ln = FileSystem.ReadLine(h)
  Parse ln
  If kd > 0 And nn <= MAXN Then
    nd(nn) = kdep : nw(nn) = kw : nm(nn) = kname : nn = nn + 1
  End If
Loop
r = FileSystem.Close(h)
If nn > MAXN Then Print fl; ": more than"; MAXN + 1; "branches - the rest left out" : nn = MAXN + 1
r = CybSys.PortOpen(pn)
If r <> 0 Then Print "The port "; pn; " is taken (another MODEL "; pn; "?)" : End
Print "MODEL "; fl; ": port "; pn; ","; nn; " lines (Q saves and ends)"
Do
  r = CybSys.PortGet(pn)
  If r = 0 Then
    msg = CybSys.PortMessage()
    rp = Answer(msg)
    r = CybSys.PortReply(pn, rp)
    nq = nq + 1
    If rp = "end" Then Exit Do
  Else
    ch = Inkey
    If ch = 81 Or ch = 113 Then Exit Do
  End If
Loop
If dirty > 0 Then Save
r = CybSys.PortClose(pn)
Print "MODEL "; pn; ":"; nq; " messages"
End

' a message from the port: its answer
Function Answer(ByVal m As String) As String
  Dim c As String Max 1, t As String Max 120, j As Integer, n As Integer, b As String Max 110
  c = UCase$(Left$(m, 1))
  m = Trim$(Mid$(m, 2))
  Answer = "?"
  If c = "W" Then
    Answer = "" : b = ""
    Do While m <> ""
      j = InStr(m, " ")
      If j = 0 Then t = m : m = "" Else t = Left$(m, j - 1) : m = Trim$(Mid$(m, j + 1))
      If Left$(t, 1) = "@" Then               ' (@path: the tags after it are under that branch)
        b = Mid$(t, 2) + "."
      Else
        t = b + t
        If Answer <> "" Then Answer = Answer + " "
        Answer = Answer + Wt(t, "N") + "," + Wt(t, "R") + "," + Wt(t, "L") + "," + Wt(t, "D")
      End If
    Loop
  ElseIf c = "C" Then                         ' (C path: the branches under it, in any category)
    Answer = ""
    For n = 0 To 3
      j = Find(m, Mid$("NRLD", n + 1, 1))
      If j >= 0 Then
        k = j + 1
        Do While k < nn
          If nd(k) <= nd(j) Then Exit Do
          If nd(k) = nd(j) + 1 Then
            If InStr(" " + Answer + " ", " " + LCase$(nm(k)) + " ") = 0 And Len(Answer) + Len(nm(k)) < 127 Then
              If Answer <> "" Then Answer = Answer + " "
              Answer = Answer + LCase$(nm(k))
            End If
          End If
          k = k + 1
        Loop
      End If
    Next
  ElseIf c = "P" Or c = "X" Then
    n = 1                                     ' (P tag n, X tag n: n points)
    j = InStr(m, " ")
    If j > 0 Then n = Val(Mid$(m, j + 1)) : m = Left$(m, j - 1)
    If n < 1 Then n = 1
    j = Find(m, "L")
    If j >= 0 Then
      If c = "P" Then nw(j) = nw(j) + n Else nw(j) = nw(j) - n
      If nw(j) > 100 Then nw(j) = 100
      If nw(j) < 0 Then nw(j) = 0
      dirty = dirty + 1
      If dirty >= 10 Then Save
    End If
    Answer = "ok"
  ElseIf c = "V" Then                         ' (V [cat\]tag\tag\...\x: that branch's weight set to x -
    m = Trim$(m)                              ' from outside: a sensor, a game; cat N R L D, none L)
    j = Dots2(m)
    Answer = "?"
    If j > 0 Then
      n = Val(Mid$(m, j + 1)) : m = Left$(m, j - 1)
      t = "L"
      If Len(m) > 2 And Mid$(m, 2, 1) = "\" And InStr("NRLDnrld", Left$(m, 1)) > 0 Then t = UCase$(Left$(m, 1)) : m = Mid$(m, 3)
      For k = 1 To Len(m)                     ' (\ or . between the names)
        If Mid$(m, k, 1) = "\" Then m = Left$(m, k - 1) + "." + Mid$(m, k + 1)
      Next
      j = Find(m, t)
      If j >= 0 Then
        If n < 0 Then n = 0
        If n > 100 Then n = 100
        nw(j) = n : dirty = dirty + 1 : Answer = "ok"
        If dirty >= 10 Then Save
      End If
    End If
  ElseIf c = "D" Then                         ' (D n: line n - "cat depth name weight", "end" past the last)
    j = Val(m)
    Answer = "end"
    If j >= 0 And j < nn Then
      If nd(j) = 0 Then
        Answer = nm(j)
      Else
        n = j
        Do While nd(n) > 0
          n = n - 1
        Loop
        Answer = nm(n) + Str$(nd(j)) + " " + nm(j) + Str$(nw(j))
      End If
    End If
  ElseIf c = "S" Then
    Save
    Answer = "ok"
  ElseIf c = "Q" Then
    Answer = "end"
  End If
End Function

' the last \ in s (0 none): where the value starts
Function Dots2(ByVal s As String) As Integer
  Dim i As Integer
  Dots2 = 0
  For i = 1 To Len(s)
    If Mid$(s, i, 1) = "\" Then Dots2 = i
  Next
End Function

' tag t's weight in category c, as text (-1: not there)
Function Wt(ByVal t As String, ByVal c As String) As String
  Dim j As Integer
  j = Find(t, c)
  If j < 0 Then Wt = "-1" Else Wt = Trim$(Str$(nw(j)))
End Function

' the branch tag t names in category c (a name, or a path: food.apple): its line, -1 none
Function Find(ByVal t As String, ByVal c As String) As Integer
  Dim i As Integer, j As Integer, p As Integer, q As Integer, last As String Max 15, up As String Max 110
  Dim part As String Max 15, d As Integer
  Find = -1
  t = UCase$(t)
  p = 0                                       ' the last dot: the branch's own name after it
  For j = 1 To Len(t)
    If Mid$(t, j, 1) = "." Then p = j
  Next
  last = Mid$(t, p + 1)
  If p > 0 Then up = Left$(t, p - 1) Else up = ""
  For i = 0 To nn - 1                         ' the category's line
    If nd(i) = 0 And nm(i) = c Then Exit For
  Next
  If i >= nn Then Exit Function
  For j = i + 1 To nn - 1
    If nd(j) = 0 Then Exit Function           ' (the next category: not in this one)
    If nm(j) = last Then
      q = Len(up)                             ' the path's other names: its branches above, in turn
      d = nd(j)
      p = j
      Do While q > 0
        k = q
        Do While k > 1 And Mid$(up, k - 1, 1) <> "."
          k = k - 1
        Loop
        part = Mid$(up, k, q - k + 1)
        Do                                    ' the branch above
          p = p - 1
        Loop While nd(p) >= d
        If nd(p) = 0 Or nm(p) <> part Then Exit Do
        d = nd(p)
        q = k - 2
      Loop
      If q <= 0 Then Find = j : Exit Function
    End If
  Next
End Function

' a line of the file: kd 0 nothing (blank, a comment, before the first category), 1 a category
' (kname its letter), 2 a branch (kdep its depth, kname, kw its weight)
Sub Parse(ByVal s As String)
  Dim j As Integer, t As String Max 120
  kd = 0
  kdep = 0
  Do While kdep < Len(s) And Mid$(s, kdep + 1, 1) = " "
    kdep = kdep + 1
  Loop
  t = Trim$(s)
  If t = "" Or Left$(t, 1) = "'" Then Exit Sub
  If kdep = 0 Then
    kname = UCase$(Left$(t, 1))
    If InStr("NRLD", kname) = 0 Then Exit Sub
    kd = 1 : kw = 0 : kcat = 1
    Exit Sub
  End If
  If kcat = 0 Then Exit Sub
  j = InStr(t, " ")
  If j = 0 Then
    kraw = t : kw = 50
  Else
    kraw = Left$(t, j - 1) : kw = Val(Mid$(t, j + 1))
  End If
  kname = UCase$(kraw)
  If kw < 0 Then kw = 0
  If kw > 100 Then kw = 100
  kd = 2
End Sub

' the weights back into the file: each branch's line written again with its weight now (the
' comments as they were), through NAME.$$$
Sub Save()
  Dim j As Integer, s As String Max 120
  tf = Left$(fl, InStr(fl, ".")) + "$$$"
  h = FileSystem.Open(fl, FileSystem.ForRead)
  If h < 0 Then Exit Sub
  h2 = FileSystem.Open(tf, FileSystem.ForWrite)
  If h2 < 0 Then r = FileSystem.Close(h) : Exit Sub
  j = 0 : kcat = 0
  Do While FileSystem.Eof(h) = 0
    s = FileSystem.ReadLine(h)
    Parse s
    If kd = 2 And j < nn Then
      s = Space$(kdep) + kraw + " " + Trim$(Str$(nw(j)))
    End If
    If kd > 0 Then j = j + 1
    r = FileSystem.WriteLine(h2, s)
  Loop
  r = FileSystem.Close(h)
  r = FileSystem.Close(h2)
  r = FileSystem.Delete(fl)
  r = FileSystem.Rename(tf, fl)
  dirty = 0
End Sub
