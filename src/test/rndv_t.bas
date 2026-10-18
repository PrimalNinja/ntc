' Rnd and Randomize with variables (regress.sh): kw_rndv, kw_seedv on their own
Dim n As Integer, s As Integer, a As Integer, b As Integer, i As Integer
n = 10 : s = 77
Randomize s
For i = 1 To 20
  a = Rnd(n)
  If a < 0 Or a > 9 Then Print "bad"; a
  b = b + a
Next
Randomize s
a = Rnd(n)
Randomize s
Print "rnd"; a = Rnd(n); b > 0
