' sieve of Eratosthenes
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Dim s(1000)
n = 1000
For i = 2 To n : s(i) = 1 : Next
i = 2
While i * i <= n
  If s(i) Then
    For j = i * i To n Step i : s(j) = 0 : Next
  End If
  i = i + 1
Wend
c = 0
For i = 2 To n
  If s(i) Then Print i; " "; : c = c + 1
Next
Print : Print c; " primes"
End
