' PROBE: a model's test drive (CyborgOS) - its own command line for the decision services: a
' decision from any model (through RAT) with its plan - how RAT got there, as a database's query
' plan -, a model's weights, the services running, and any port asked anything (NEURAL's too).
'   PROBE                an interactive command line (probe> ...)
'   PROBE command        that one command, then it ends
' Commands (HELP lists them):
'   model tag tag:level ...   RAT's decision (as deep as the model goes: food.fruit.apple) - and,
'                             PLAN ON, its plan: a line a level - the stage (N necessity, R
'                             requirement, LD taste), the contenders and their weights (+n others),
'                             kept by the deadband or rnd/n; DRY ON (as it starts): nothing learnt
'   TRY model tag ...         a dry run this once - the weights not touched
'   RUN model tag ...         a real run this once - the habit learnt, the deadband kept
'   PORTS                     the services running: their ports and slots
'   SHOW model [tag ...]      the model's lines (every line), or those tags' N R L D weights
'   LIKE / DISLIKE model tag [n]   a like up / down n (1)
'   SET model [cat\]tag\tag\x  a branch's weight set to x (N R L D first; none: L) - as an outside
'                             sensor or game would set it (MODEL's V)
'   SAVE model                its weights saved
'   ASK port message          any port asked, its answer as it comes (NEURAL: ASK DUNGEON Q ...)
'   PLAN ON|OFF, DRY ON|OFF, HELP, QUIT
Option Explicit
Dim ln As String Max 128, c As String Max 12, a As String Max 128, w As String Max 128
Dim plan As Integer, dry As Integer, one As Integer, j As Integer, i As Integer, n As Integer

plan = 1 : dry = 1
ln = Trim$(CybSys.Tail())
If ln <> "" Then
  one = 1
  Run ln
  End
End If
Print "PROBE: the decision services' test drive (HELP; DRY ON - models not changed)"
Do
  ln = ""
  Input "probe> ", ln
  ln = Trim$(ln)
  If ln <> "" Then
    c = UCase$(Word(ln, 0))
    If c = "QUIT" Or c = "Q" Or c = "EXIT" Then Exit Do
    Run ln
  End If
Loop
End

' word n (0 on) of s ("" none)
Function Word(ByVal s As String, ByVal n As Integer) As String
  Dim k As Integer
  s = Trim$(s)
  Do While n > 0 And s <> ""
    k = InStr(s, " ")
    If k = 0 Then s = "" Else s = Trim$(Mid$(s, k + 1))
    n = n - 1
  Loop
  k = InStr(s, " ")
  If k > 0 Then s = Left$(s, k - 1)
  Word = s
End Function

' s from word n on
Function Rest(ByVal s As String, ByVal n As Integer) As String
  Dim k As Integer
  s = Trim$(s)
  Do While n > 0 And s <> ""
    k = InStr(s, " ")
    If k = 0 Then s = "" Else s = Trim$(Mid$(s, k + 1))
    n = n - 1
  Loop
  Rest = s
End Function

' a port called: its answer ("" and a message when there is no such port)
Function PCall(ByVal p As String, ByVal m As String) As String
  PCall = CybSys.PortCall(UCase$(p), m)
  If CybSys.PortStatus() <> 0 Then Print "No port "; UCase$(p); " (PORTS: the services running)" : PCall = ""
End Function

' a command
Sub Run(ByVal s As String)
  Dim p As String Max 8
  c = UCase$(Word(s, 0))
  If c = "HELP" Or c = "?" Then
    Print "model tag tag:level ...    a decision (RAT), with its plan (PLAN ON)"
    Print "PORTS                      the services running"
    Print "SHOW model [tag ...]       its lines, or those tags' N R L D"
    Print "LIKE / DISLIKE model tag [n]   a like up / down n"
    Print "SET model [cat\]tag\..\x   a weight set to x (cat N R L D; none L)"
    Print "SAVE model                 its weights saved"
    Print "ASK port message           any port asked (NEURAL: ASK DUNGEON Q ...)"
    Print "TRY model tag ...          a dry run this once (nothing learnt)"
    Print "RUN model tag ...          a real run this once (the habit learnt)"
    Print "PLAN ON|OFF  DRY ON|OFF (nothing learnt)  QUIT"
    Print "(PLAN "; OnOff(plan); ", DRY "; OnOff(dry); ")"
  ElseIf c = "PORTS" Then
    n = 0
    For i = 0 To 7
      p = CybSys.PortName(i)
      If p <> "" Then Print Left$(p + "         ", 9); "slot "; CybSys.PortSlot() : n = n + 1
    Next
    If n = 0 Then Print "No services running"
  ElseIf c = "PLAN" Then
    plan = (UCase$(Word(s, 1)) <> "OFF")
    Print "PLAN "; OnOff(plan)
  ElseIf c = "DRY" Then
    dry = (UCase$(Word(s, 1)) <> "OFF")
    Print "DRY "; OnOff(dry)
  ElseIf c = "SHOW" Then
    Show Word(s, 1), Rest(s, 2)
  ElseIf c = "LIKE" Or c = "DISLIKE" Then
    w = "1"
    If Word(s, 3) <> "" Then w = Word(s, 3)
    If c = "LIKE" Then a = "P " Else a = "X "
    a = PCall(Word(s, 1), a + Word(s, 2) + " " + w)
    If a <> "" Then Show Word(s, 1), Word(s, 2)
  ElseIf c = "SET" Then                       ' (SET model [cat\]tag\tag\x: a weight set, as a sensor would)
    a = PCall(Word(s, 1), "V " + Word(s, 2))
    If a = "ok" Then Print "set" Else If a <> "" Then Print "? (no such branch)"
  ElseIf c = "SAVE" Then
    a = PCall(Word(s, 1), "S")
    If a <> "" Then Print "saved"
  ElseIf c = "ASK" Then
    a = PCall(Word(s, 1), Rest(s, 2))
    If a <> "" Then Print a
  ElseIf Word(s, 1) = "" Then
    Print "? (HELP)"
  Else
    n = dry                                   ' a decision: RAT asked, ? the plan, ~ dry
    If c = "TRY" Then n = 1 : s = Rest(s, 1)  ' (TRY: dry this once; RUN: for real this once)
    If c = "RUN" Then n = 0 : s = Rest(s, 1)
    a = ""
    If plan Then a = "?"
    If n Then a = a + "~"
    a = PCall("RAT", a + s)
    If a = "?" Then
      Print "? (no model "; UCase$(Word(s, 0)); " - PORTS - or no tags)"
    ElseIf a <> "" Then
      j = InStr(a, "|")
      If j = 0 Then
        Print "-> "; a
      Else
        Print "-> "; Trim$(Left$(a, j - 1))
        a = Mid$(a, j + 1)
        Do While a <> ""                      ' the plan, a line a stage
          j = InStr(a, "|")
          If j = 0 Then w = a : a = "" Else w = Left$(a, j - 1) : a = Mid$(a, j + 1)
          If Trim$(w) <> "" Then Print "   "; Trim$(w)
        Loop
      End If
    End If
  End If
End Sub

' a model shown: every line (D n), or the tags' weights (W)
Sub Show(ByVal md As String, ByVal tags As String)
  Dim t As String Max 20
  If md = "" Then Print "SHOW model [tag ...]" : Exit Sub
  If tags = "" Then
    n = 0
    Do
      a = PCall(md, "D" + Str$(n))
      If a = "" Or a = "end" Then Exit Do
      j = InStr(a, " ")
      If j = 0 Then
        Print a                               ' (a category)
      Else
        w = Rest(a, 1)                        ' "depth name weight"
        Print Space$(Val(Word(w, 0)) * 2); Word(w, 1); " "; Word(w, 2)
      End If
      n = n + 1
    Loop
    If a = "end" And n = 0 Then Print "(empty)"
    Exit Sub
  End If
  w = PCall(md, "W " + tags)
  If w = "" Then Exit Sub
  Print "tag                N    R    L    D   (-: not in it)"
  i = 0
  Do
    t = Word(tags, i)
    If t = "" Then Exit Do
    a = Word(w, i)
    Print Left$(t + Space$(15), 15); Num(a, 0); Num(a, 1); Num(a, 2); Num(a, 3)
    i = i + 1
  Loop
End Sub

' field k of "n,r,l,d", 5 wide ("-" for -1)
Function Num(ByVal s As String, ByVal k As Integer) As String
  Dim j As Integer, v As String Max 8
  Do While k > 0
    j = InStr(s, ",")
    If j = 0 Then s = "" Else s = Mid$(s, j + 1)
    k = k - 1
  Loop
  j = InStr(s, ",")
  If j > 0 Then s = Left$(s, j - 1)
  v = s
  If v = "-1" Or v = "" Then v = "-"
  Num = Right$("     " + v, 5)
End Function

Function OnOff(ByVal v As Integer) As String
  If v Then OnOff = "ON" Else OnOff = "OFF"
End Function
