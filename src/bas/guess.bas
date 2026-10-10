Randomize 1234
again:
t = Rnd(100) + 1 : tries = 0
Print "I picked 1 to 100"
Do
  Input "Guess"; g
  tries = tries + 1
  If g < t Then
    Print "Higher"
  ElseIf g > t Then
    Print "Lower"
  End If
Loop Until g = t
Print "Got it in "; tries
Input "Again (y/n)"; a$
If a$ = "y" Then GoTo again
End
