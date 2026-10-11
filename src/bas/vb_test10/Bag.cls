Option Explicit
Private mItems(9) As Integer
Public Property Get Item(ByVal i As Integer) As Integer
  Item = mItems(i)
End Property
Public Property Let Item(ByVal i As Integer, ByVal v As Integer)
  mItems(i) = v
End Property
