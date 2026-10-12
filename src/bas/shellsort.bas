' Shell sort - pick how many numbers, then sort in turbo or normal mode, as often as you like.
' Turbo On / Turbo Off switch modes. ShellSort is called from both
' modes, so it is built twice (p_shellsort and p_shellsort_n).
' 2000 numbers take several seconds - long enough for a stopwatch: start it as you
' press T or N, stop it at "Done".
Option Explicit
Option Turbo Off                  ' starts in normal mode whatever the turbo setting says: T switches
Const MAXN = 2000
Dim a(MAXN) As Integer
Dim n As Integer, i As Integer, k As String
Dim t0 As Integer, t1 As Integer

Input "How many numbers (Return = 2000)"; n
If n < 10 Or n > MAXN Then n = MAXN
Do
  Print
  Print "T = turbo, N = normal, X = exit"
  Do : k = UCase$(Inkey$) : Frame : Loop Until (k = "T") Or (k = "N") Or (k = "X")
  If k = "X" Then Exit Do
  ' the same numbers every time
  Randomize 7
  For i = 0 To n
    a(i) = Rnd(1000)
  Next
  Print IIf(k = "T", "Turbo", "Normal"); ": sorting "; n + 1; " numbers..."
  t0 = Ticks
  If k = "T" Then
    Turbo On
    ShellSort
    Turbo Off
  Else
    ShellSort
  End If
  t1 = Ticks
  Print "Done - stop the stopwatch"
  For i = 0 To 9
    Print a(i); " ";
  Next
  Print
  If (k = "N") And (System.TicksPerSecond > 0) Then
    Print "took "; t1 - t0; " ticks = "; (t1 - t0) \ System.TicksPerSecond; "."; ((t1 - t0) Mod System.TicksPerSecond) * 10 \ System.TicksPerSecond; " s"
  ElseIf k = "T" Then
    Print "(turbo runs with interrupts off, so"
    Print "time it with the stopwatch)"
  End If
Loop
End

Sub ShellSort()
  Dim gap As Integer, i As Integer, j As Integer, t As Integer
  gap = n \ 2
  Do While gap > 0
    For i = gap To n
      t = a(i)
      j = i
      Do While j >= gap
        If a(j - gap) <= t Then Exit Do
        a(j) = a(j - gap)
        j = j - gap
      Loop
      a(j) = t
    Next
    gap = gap \ 2
  Loop
End Sub
