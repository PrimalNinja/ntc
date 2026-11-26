' Stage2: lot Second.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Private mVisits As Integer
Private mName As String
Private mTrail As String

Public Sub Play()
  mVisits = mVisits + 1
  mName = "the tower"
  mTrail = mTrail + "*"
  Print
  Game.Say 14, "stage 2: " + mName
  Game.Add 5
  Print "  visit"; mVisits; " trail "; mTrail; " score"; Game.Score()
  Game.Pause
End Sub
