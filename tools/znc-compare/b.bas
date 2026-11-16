Option Explicit
Dim flags(8190) As Byte
Dim arr(99) As Integer
Dim count As Integer, s As Integer, r3 As Integer, acc As Integer, cnt7 As Integer
Dim it As Integer, i As Integer, j As Integer, k As Integer, prime As Integer, t As Integer, p As Integer, q As Integer

Function Add3(ByVal a As Integer, ByVal b As Integer, ByVal c As Integer) As Integer
  Add3 = a + b + c
End Function

Out &HFE, 1
' B1 sieve, 3 passes
For it = 0 To 2
  count = 0
  For i = 0 To 8190
    flags(i) = 1
  Next
  For i = 0 To 8190
    If flags(i) Then
      prime = i + i + 3
      k = i + prime
      Do While k <= 8190
        flags(k) = 0
        k = k + prime
      Loop
      count = count + 1
    End If
  Next
Next
Out &HFE, 2
' B2 loop + add
s = 0
For i = 1 To 30000
  s = s + i
Next
Out &HFE, 3
' B3 function calls
r3 = 0
For i = 1 To 10000
  r3 = Add3(r3, i, 1)
Next
Out &HFE, 4
' B4 mul / div / mod
acc = 0
For i = 1 To 5000
  acc = acc + (i * 7) \ 3 + i Mod 5
Next
Out &HFE, 5
' B5 bubble sort, 100 ints
For i = 0 To 99
  arr(i) = 100 - i
Next
For i = 0 To 98
  For j = 0 To 98 - i
    If arr(j) > arr(j + 1) Then
      t = arr(j) : arr(j) = arr(j + 1) : arr(j + 1) = t
    End If
  Next
Next
Out &HFE, 6
' B6 poke fill, 6144 bytes x 4
For p = 0 To 3
  q = &HC000
  For i = 0 To 6143
    Poke q, p
    q = q + 1
  Next
Next
Out &HFE, 7
' B7 nested loops + test
cnt7 = 0
For i = 0 To 99
  For j = 0 To 99
    If (i + j) And 1 Then cnt7 = cnt7 + 1
  Next
Next
Out &HFE, 8
Print count; " "; s; " "; r3; " "; acc; " "; arr(0); " "; cnt7
End
