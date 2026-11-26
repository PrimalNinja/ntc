' timings on the C64 with an REU, in frames (50 a second)
Dim i As Integer, j As Integer, k As Integer, t As Integer
Dim a(100) As Integer
Dim s As String

Sub Small()
  k = k + 1
End Sub

t = Ticks
For i = 1 To 10000 : Next
Print "empty loop x 10000: "; Ticks - t
t = Ticks
For i = 1 To 10000 : k = k + i : Next
Print "add x 10000: "; Ticks - t
t = Ticks
For i = 1 To 2000 : k = i * 7 : Next
Print "multiply x 2000: "; Ticks - t
t = Ticks
For i = 1 To 2000 : k = i \ 7 : Next
Print "divide x 2000: "; Ticks - t
t = Ticks
For j = 1 To 50 : For i = 0 To 100 : a(i) = i : Next : Next
Print "array set x 5050: "; Ticks - t
t = Ticks
For i = 1 To 2000 : Small : Next
Print "call x 2000: "; Ticks - t
t = Ticks
For i = 1 To 500 : s = "abc" + "def" : Next
Print "string x 500: "; Ticks - t
t = Ticks
For i = 1 To 2000
  If i And 1 Then k = k + 1 Else k = k - 1
Next
Print "if x 2000: "; Ticks - t
t = Ticks
For i = 1 To 40 : Print "scrolling a line of text on the c64" : Next
Print "print x 40: "; Ticks - t
End
