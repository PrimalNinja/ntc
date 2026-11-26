' Stage1: lot First. mVisits and mBest are this lot's own: they are still there on the next
' visit, though the lot's workspace has been out to the REU and back in between.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Private mVisits As Integer
Private mBest As Integer
Private mName As String

Public Sub Play()
  Dim i As Integer, points As Integer
  mVisits = mVisits + 1
  mName = "the cellar"
  Print
  Game.Say 13, "stage 1: " + mName
  For i = 1 To Game.Round()
    points = points + Worth(i)
  Next
  If points > mBest Then mBest = points
  Game.Add points
  Print "  visit"; mVisits; " points"; points; " best"; mBest; " score"; Game.Score()
  Print "  from the data lot: "; Chr$(Reu.Peek(Reu.LotBank(4), Reu.LotAddr(4) + mVisits))
  Game.Pause
End Sub

' called only from inside the lot, so it may take parameters and give a result
Private Function Worth(ByVal n As Integer) As Integer
  Worth = n * 10
End Function
