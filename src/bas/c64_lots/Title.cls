' Title: lot Front. Its code and its variables are in the REU until it is called.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Private mShown As Integer
Private mLine As String

Public Sub Show()
  mShown = mShown + 1
  mLine = "a program in lots"
  Cls
  Game.Say 7, mLine
  Game.Say 15, "title: lot 1.  stages: lots 2 and 3"
  Game.Say 15, "data: lot 4.   the rest of it: the kernel"
  Print
  Print "lots in this reu: "; System.Lots()
  Print "a key to start"
  Game.Pause
End Sub

Public Sub Finish()
  Print
  Game.Say 7, "the end"
  Print "score "; Game.Score(); "  title shown "; mShown; " time"
End Sub
