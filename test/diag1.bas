Dim x As Integer
x = 3
Debug.Assert x = 3
Print "past assert"
If x > 2 Then Error "x too big: " & x
Print "not here"
