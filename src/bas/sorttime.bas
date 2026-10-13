' Sort timing: a linked list of 5000 nodes (List class) filled with random keys, then
' List.Sort (a radix sort: two passes over the list), in turbo or normal mode, as often as
' you like. On a 6128 (CPC seconds, measured with test/cpctime.py):
'   turbo   fill 7.8  sort 4.2-4.7  check 6.7
'   normal  fill 8.2  sort 4.2-4.8  check 7.1
' List.Sort is library code, so it runs at the same speed in both modes. The first sort is
' the fastest: the nodes are still in memory order, so it switches RAM pages less. Fill and
' check are BASIC loops around List calls; the calls (about 600 microseconds each) and the
' multiply in the random numbers take most of the time, so turbo saves only about 5%.
' Needs room for the nodes: 5000 take 60K, so a 6128 (pages) - on 64K or CP/M
' (Option Memory Small) it says how many fit and uses those.
' Turbo runs with interrupts off, so Ticks stands still: time turbo with a stopwatch.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option Turbo Off                  ' starts in normal mode whatever the turbo setting says: T switches
#If NTC_CPC Then
Option Reserve &H4000, &H4000
#End If
#If NTC_CPCMIN Then
Option Reserve &H4000, &H4000
#End If
#If NTC_CPCFW Then
Option Reserve &H4000, &H4000
#End If
Dim h As Long, n As Long, want As Long, nodes As Integer, i As Integer, r As Integer, seed As Integer
Dim k As String, t0 As Integer, t1 As Integer, t2 As Integer, t3 As Integer, ok As Integer

' a list holds up to 32767 nodes (its count is an Integer); RAM may hold fewer
Input "Nodes, 2-32767 (Return = 5000)"; want
If want = 0 Then want = 5000
If want < 2 Then want = 2
If want > 32767 Then Print "Most is 32767" : want = 32767
nodes = want
h = List.Create(2)
For i = 1 To nodes
  If List.Append(h) = 0 Then Print "Room for "; i - 1; " nodes" : Exit For
Next
nodes = List.Count(h)
Print "List of "; nodes; " nodes"
seed = 1
Do
  Print
  Print "T = turbo, N = normal, X = exit"
  Do : k = UCase$(Inkey$) : Frame : Loop Until (k = "T") Or (k = "N") Or (k = "X")
  If k = "X" Then Exit Do
  Print IIf(k = "T", "Turbo", "Normal"); ": "; nodes; " nodes..."
  t0 = Ticks
  If k = "T" Then
    Turbo On
    RunSort
    Turbo Off
  Else
    RunSort
  End If
  Print "Done - stop the stopwatch"
  Print IIf(ok, "in order", "NOT IN ORDER")
  If (k = "N") And (System.TicksPerSecond > 0) Then
    Print "fill "; Secs(t1 - t0); "  sort "; Secs(t2 - t1); "  check "; Secs(t3 - t2)
  ElseIf k = "N" Then
    Print "(no Ticks on this machine: use the stopwatch)"
  Else
    Print "(turbo: interrupts are off, use the stopwatch)"
  End If
Loop
r = List.Destroy(h)
End

' new random keys, sort, check the order (the times in t1, t2, t3)
Sub RunSort()
  Dim m As Long, prev As Integer, v As Integer
  m = List.First(h)
  Do While m <> 0
    seed = (seed * 75 + 74) And &H7FFF
    List.SetWord m, 0, seed
    m = List.NextOf(m)
  Loop
  t1 = Ticks
  r = List.Sort(h, 0)
  t2 = Ticks
  ok = -1 : prev = -32768
  m = List.First(h)
  Do While m <> 0
    v = List.GetWord(m, 0)
    If v < prev Then ok = 0
    prev = v
    m = List.NextOf(m)
  Loop
  t3 = Ticks
End Sub

Function Secs(ByVal t As Integer) As String
  Secs = Str$(t \ System.TicksPerSecond) + "." + Mid$(Str$(100 + (t Mod System.TicksPerSecond) * 100 \ System.TicksPerSecond), 3) + "s"
End Function
