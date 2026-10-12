' Level 2: built into LEVEL2.PAG. It calls level 1's class too (that switches pages).
Option Class Overlay "LEVEL2"
Public Function Play(ByVal score As Integer) As Integer
  Banner "Level 2"
  Print "  score so far "; score; ", level 1 loaded "; Level1.Loaded()
  Play = 250
End Function
