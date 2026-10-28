' For loops that run to 32767 / -32768 end there (the step would go past the Integers) - regress.sh
Dim i As Integer, n As Integer, e As Integer, s As Integer
n = 0 : For i = 32760 To 32767 : n = n + 1 : Next : Print "a"; n; i
e = 32767 : n = 0 : For i = 32765 To e : n = n + 1 : Next : Print "b"; n
n = 0 : For i = 32000 To 32767 Step 100 : n = n + 1 : Next : Print "c"; n
n = 0 : For i = -32760 To -32768 Step -1 : n = n + 1 : Next : Print "d"; n
n = 0 : For i = -32700 To -32768 Step -50 : n = n + 1 : Next : Print "e"; n
s = 7 : n = 0 : For i = 32750 To e Step s : n = n + 1 : Next : Print "f"; n
n = 0 : For i = 1 To 10 : n = n + i : Next : Print "g"; n
n = 0 : For i = 10 To 1 Step -3 : n = n + i : Next : Print "h"; n
