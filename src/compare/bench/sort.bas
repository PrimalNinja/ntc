' Shell sort of 2001 numbers (0..1023, from x = (x * 13 + 7) And 1023)
Option Explicit
Const N = 2000
Dim a(N) As Integer
Fill
Print "go"
Turbo On
Bench
Turbo Off
Print "turbo "; a(0); " "; a(1000); " "; a(N)
Fill
Print "go"
Bench
Print "normal "; a(0); " "; a(1000); " "; a(N)
End
Sub Fill()
  Dim i As Integer, x As Integer
  x = 1
  For i = 0 To N
    x = (x * 13 + 7) And 1023
    a(i) = x
  Next
End Sub
Sub Bench()
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
