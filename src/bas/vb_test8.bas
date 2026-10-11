' VB self test 8 - AddressOf / CallAddr (a driver table), Error / Assert diagnostics compile
Option Explicit

Dim t As Integer, bad As Integer
Dim i As Integer, total As Integer
Dim table(2) As Integer
Dim p As Integer

Cls
Print "VB self test 8"

' ---- a table of procedures, called through it
table(0) = AddressOf AddOne
table(1) = AddressOf AddTen
table(2) = AddressOf AddArg
total = 0
CallAddr table(0)
CallAddr table(1)
Chk total, 11
p = table(2)
CallAddr p, 100
Chk total, 111
For i = 0 To 1
  CallAddr table(i)
Next
Chk total, 122
i = 5
CallAddr table(2), i * 2
Chk total, 132
Register AddressOf AddTen
Chk total, 142

Print
Print t; " tests, "; bad; " failed"
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

Sub AddOne()
  total = total + 1
End Sub

Sub AddTen()
  total = total + 10
End Sub

Sub AddArg(ByVal n As Integer)
  total = total + n
End Sub

' an address passed as a parameter, then called
Sub Register(ByVal entry As Integer)
  CallAddr entry
End Sub
