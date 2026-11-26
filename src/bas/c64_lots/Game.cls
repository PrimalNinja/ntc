' Game: in no lot, so it is in memory all the time and any lot may call it, with parameters.
' What the lots share is kept here.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Private mScore As Integer
Private mRound As Integer

Public Sub SetRound(ByVal n As Integer)
  mRound = n
End Sub

Public Function Round() As Integer
  Round = mRound
End Function

Public Sub Add(ByVal points As Integer)
  mScore = mScore + points
End Sub

Public Function Score() As Integer
  Score = mScore
End Function

' a line of text in a colour: the lots' own strings are handed to it while they are in memory
Public Sub Say(ByVal colour As Integer, ByVal text As String)
  StdIO.Pen colour
  Print text
  StdIO.Pen 1
End Sub

' wait for a key (or about two seconds)
Public Sub Pause()
  Dim t As Integer
  t = Ticks
  Do
    Frame
  Loop Until (Inkey <> 0) Or (Ticks - t > 100)
End Sub
