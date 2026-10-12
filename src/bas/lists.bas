' Lists: a high score table kept in a linked list (the List class). The nodes live in the
' Memory class's heap - RAM pages on a CPC with expansion RAM, the free main RAM otherwise -
' so the program itself only keeps the list's handle.
Option Explicit
#If NTC_CPC Then
Option Reserve &H4000, &H4000
#End If
#If NTC_CPCMIN Then
Option Reserve &H4000, &H4000
#End If
#If NTC_CPCFW Then
Option Reserve &H4000, &H4000
#End If
Const ID = 0, SCORE = 2           ' the fields: 2 words a node
Dim h As Long, n As Long, nxt As Long, i As Integer, r As Integer, seed As Integer

Print "Lists on "; System.Platform
h = List.Create(4)
seed = 12345
For i = 1 To 500
  n = List.Append(h)
  If n = 0 Then Print "No room after"; i - 1 : Exit For
  seed = (seed * 75 + 74) And &H7FFF       ' a small random number generator
  List.SetWord n, ID, i
  List.SetWord n, SCORE, seed Mod 10000
Next
Print List.Count(h); " players"

r = List.Sort(h, SCORE)
Print "Top 5:"
n = List.Last(h)
For i = 1 To 5
  Print "  player "; List.GetWord(n, ID); ": "; List.GetWord(n, SCORE)
  n = List.PrevOf(n)
Next

' drop everyone under 5000
n = List.First(h)
Do While n <> 0
  nxt = List.NextOf(n)
  If List.GetWord(n, SCORE) < 5000 Then r = List.Delete(h, n)
  n = nxt
Loop
Print List.Count(h); " players with 5000 or more"
n = List.Search(h, ID, 250)
If n <> 0 Then Print "Player 250 scored "; List.GetWord(n, SCORE) Else Print "Player 250 is gone"
r = List.Destroy(h)

Print "Press a key";
Do While Inkey <> 0 : Loop
Do : Frame : Loop Until Inkey <> 0
Print
End
