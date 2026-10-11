' sieve of Eratosthenes
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
Print "Press a key";
Do : Frame : Loop Until Inkey <> 0
Print
End
