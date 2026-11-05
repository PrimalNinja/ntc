' A "safe" class: its code must stay in safe memory (out of the paging window), placed by
' Option Safe Areas / Option Safe "NAME" = ... . Here it is just arithmetic to prove the
' code runs correctly from the safe area it was placed in.
Public Function Add(ByVal a As Integer, ByVal b As Integer) As Integer
  Add = a + b + 7
End Function
