' Sieve of Eratosthenes, primes below 8000, a Byte flag per number
Option Explicit
Const TOP = 8000
Dim f(TOP) As Byte
Dim cnt As Integer
Print "go"
Turbo On
Bench
Turbo Off
Print "turbo "; cnt
Print "go"
Bench
Print "normal "; cnt
End
Sub Bench()
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
