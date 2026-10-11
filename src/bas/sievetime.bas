' Sieve of Eratosthenes - primes below 8000, timed in turbo or normal mode, as often as you like.
' The same work as compare/smallc/sieve.c (a Byte flag per number), for comparing NTC with Small C.
' Start the stopwatch as you press T or N (the sieve starts straight away), stop it at "Done".
' 5 passes take about 17 s (turbo) / 25 s (normal) on a 4 MHz CPC.
Option Explicit
Const TOP = 8000
Dim f(TOP) As Byte
Dim passes As Integer, cnt As Integer, k As String
Dim t0 As Integer, t1 As Integer

Input "How many passes (Return = 5)"; passes
If passes < 1 Or passes > 100 Then passes = 5
Do
  Print
  Print "T = turbo, N = normal, X = exit"
  Do : k = UCase$(Inkey$) : Frame : Loop Until (k = "T") Or (k = "N") Or (k = "X")
  If k = "X" Then Exit Do
  Print IIf(k = "T", "Turbo", "Normal"); ": "; passes; " passes..."
  t0 = Ticks
  If k = "T" Then
    Turbo On
    RunPasses
    Turbo Off
  Else
    RunPasses
  End If
  t1 = Ticks
  Print "Done - stop the stopwatch"
  Print cnt; " primes below "; TOP
  If (k = "N") And (System.TicksPerSecond > 0) Then
    Print "took "; t1 - t0; " ticks = "; (t1 - t0) \ System.TicksPerSecond; "."; ((t1 - t0) Mod System.TicksPerSecond) * 10 \ System.TicksPerSecond; " s"
  ElseIf k = "T" Then
    Print "(turbo runs with interrupts off, so"
    Print "time it with the stopwatch)"
  End If
Loop
End

Sub RunPasses()
  Dim p As Integer
  For p = 1 To passes
    Sieve
  Next
End Sub

Sub Sieve()
  Dim i As Integer, j As Integer
  For i = 2 To TOP
    f(i) = 1
  Next
  cnt = 0
  For i = 2 To TOP
    If f(i) = 1 Then
      cnt = cnt + 1
      j = i + i
      Do While j <= TOP
        f(j) = 0
        j = j + i
      Loop
    End If
  Next
End Sub
