Option Class Overlay "OVA"
Private Paged n As Integer
Public Function Twice(ByVal x As Integer) As Integer
  Twice = x * 2
End Function
' A -> B -> A.Twice: back into B, then back into A
Public Function Deep(ByVal x As Integer) As Integer
  Note "A"
  Deep = 1 + B.Mid(x)
  Note "A again"
End Function
' code in the overlay area can't load or unload a class
Public Function TryLoad() As Integer
  TryLoad = B.Load() * 100 + A.Unload()
End Function
Public Function Local() As Integer
  Dim p As Integer, q As Integer
  p = LocalAlloc(100)
  q = LocalAlloc(30000)
  Local = (p >= LocalStart()) + (q = 0) * 10 + LocalFree(p) * 100
End Function
' paged: kept in main memory with one overlay area, so it lasts across swaps
Public Function Count() As Integer
  n = n + 1
  Count = n
End Function
