' Level 2: page LEVEL2, built into OVERLAYS.002. It calls level 1's class too: in RAM pages that switches
' pages; in one overlay area it loads level 1 over level 2, and level 2 again for the return.
Option Class Overlay Level2
Public Function Play(ByVal score As Integer) As Integer
  Banner "Level 2"
  Print "  score so far "; score; ", level 1 loaded "; Level1.Loaded()
  Print "  bonus from level 1 "; Level1.Bonus()
  Play = 250
End Function
