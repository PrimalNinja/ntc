VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Counter"
Option Explicit
Private mCount As Integer
Private mTotal As Integer
Private mLimit As Integer

Public Sub Reset()
  mCount = 0
  mTotal = 0
End Sub

Public Sub Add(ByVal v As Integer)
  mCount = mCount + 1
  mTotal = mTotal + v
End Sub

Public Property Get Count() As Integer
  Count = mCount
End Property

Public Property Get Total() As Integer
  Total = mTotal
End Property

Public Property Let Limit(ByVal v As Integer)
  mLimit = v
End Property

Public Property Get Limit() As Integer
  Limit = mLimit
End Property

Public Function Describe(ByVal s As String) As String
  Describe = s & "=" & mTotal
End Function
