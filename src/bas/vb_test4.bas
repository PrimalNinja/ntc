' VB self test 4 - arrays as parameters, LBound / UBound, Tab
Option Explicit

Dim t As Integer, bad As Integer
Dim i As Integer
Dim nums(5) As Integer
Dim odd(1 To 4) As Integer
Dim words(2) As String
Dim big(3) As Long
Dim grid(2, 3) As Integer

Cls
Print "VB self test 4"

' ---- LBound / UBound of normal arrays
Chk LBound(nums), 0
Chk UBound(nums), 5
Chk LBound(odd), 1
Chk UBound(odd), 4
Chk UBound(grid, 2), 3

' ---- arrays as parameters
For i = 0 To 5
  nums(i) = 10 - i
Next
Chk Total(nums), 45
SortUp nums
Chk nums(0), 5
Chk nums(5), 10
Chk Total(nums), 45
For i = 1 To 4
  odd(i) = i * i
Next
Chk Total(odd), 30
Chk Lo(odd), 1
Chk Hi(odd), 4
Chk Count(nums), 6
words(0) = "pear"
words(1) = "apple"
words(2) = "fig"
ChkS Longest(words), "apple"
Shout words
ChkS words(2), "FIG"
big(0) = 100000
big(3) = 250000
ChkL BigSum(big), 350000

Print
Print "a"; Tab(6); "b"
Print t; " tests, "; bad; " failed"
Print "Press a key";
Do : Frame : Loop Until Inkey <> 0
Print
End

Sub Chk(ByVal got As Integer, ByVal want As Integer)
  t = t + 1
  Print t; ":";
  If got = want Then
    Print "ok ";
  Else
    Print "FAIL("; got; ") ";
    bad = bad + 1
  End If
End Sub

Sub ChkS(ByVal got As String, ByVal want As String)
  t = t + 1
  Print t; ":";
  If got = want Then
    Print "ok ";
  Else
    Print "FAIL["; got; "] ";
    bad = bad + 1
  End If
End Sub

Sub ChkL(ByVal got As Long, ByVal want As Long)
  t = t + 1
  Print t; ":";
  If got = want Then
    Print "ok ";
  Else
    Print "FAIL("; got; ") ";
    bad = bad + 1
  End If
End Sub

Function Total(a() As Integer) As Integer
  Dim k As Integer
  Total = 0
  For k = LBound(a) To UBound(a)
    Total = Total + a(k)
  Next
End Function

' insertion sort, the array is changed in place (arrays are always ByRef)
Sub SortUp(a() As Integer)
  Dim k As Integer, j As Integer, v As Integer
  For k = LBound(a) + 1 To UBound(a)
    v = a(k)
    j = k - 1
    Do While j >= LBound(a)
      If a(j) <= v Then Exit Do
      a(j + 1) = a(j)
      j = j - 1
    Loop
    a(j + 1) = v
  Next
End Sub

Function Lo(a() As Integer) As Integer
  Lo = LBound(a)
End Function

Function Hi(a() As Integer) As Integer
  Hi = UBound(a)
End Function

' passes its array parameter on
Function Count(a() As Integer) As Integer
  Count = Hi(a) - Lo(a) + 1
End Function

Function Longest(s() As String) As String
  Dim k As Integer
  Longest = ""
  For k = 0 To UBound(s)
    If Len(s(k)) > Len(Longest) Then Longest = s(k)
  Next
End Function

Sub Shout(s() As String)
  Dim k As Integer
  For k = 0 To UBound(s)
    s(k) = UCase$(s(k))
  Next
End Sub

Function BigSum(v() As Long) As Long
  Dim k As Integer
  BigSum = 0
  For k = 0 To UBound(v)
    BigSum = BigSum + v(k)
  Next
End Function
