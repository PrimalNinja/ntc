' Shell sort - the user picks turbo or normal mode at run time
' Turbo On / Turbo Off switch modes. ShellSort is called from both
' modes, so it is built twice (p_shellsort and p_shellsort_n).
Option Explicit
Const N = 300
Dim a(N) As Integer
Dim i As Integer, k As String

Randomize 7
For i = 0 To N
  a(i) = Rnd(1000)
Next
Input "Turbo (y/n)"; k
If k = "y" Then
  Turbo On
  ShellSort
  Turbo Off
Else
  ShellSort
End If
For i = 0 To 9
  Print a(i); " ";
Next
Print
Print "sorted"

Sub ShellSort()
  Dim gap As Integer, i As Integer, j As Integer, t As Integer
  gap = N \ 2
  Do While gap > 0
    For i = gap To N
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
