' Counter - a class for the 68000 self test: a total, a count, a property
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Private mTotal As Integer, mCount As Integer, mLimit As Integer

Public Sub Reset()
  mTotal = 0
  mCount = 0
End Sub

Public Sub Add(ByVal v As Integer)
  mTotal = mTotal + v
  mCount = mCount + 1
End Sub

Public Function Total() As Integer
  Total = mTotal
End Function

Public Function Count() As Integer
  Count = mCount
End Function

Public Property Get Limit() As Integer
  Limit = mLimit
End Property

Public Property Let Limit(ByVal v As Integer)
  mLimit = v
End Property
