' Pages (Option Page) - regress.sh: several classes in one page, a class copied into two
' pages (Shared: no paged variables; Counter: paged variables, each copy its own), calls
' inside a page without a page switch, a class used by a page but in none (Util: main RAM).
Option Page "TITLE"   = Title
Option Page "LEVEL1"  = Level1, Shared, Counter, OnlyOne
Option Page "LEVEL2"  = Level2, Shared, Counter
Option Page "CREDITS" = Credits
#If NTC_CPCMIN Then
Option RomEnable 7
#End If
#If NTC_CPCFW Then
Option RomEnable 7
#End If
Option Reserve &H4000, &H4000
Dim r As Integer
Title.Show
Print "L1 "; Level1.Play(3)
Print "L2 "; Level2.Play(4)
Print "L1 again "; Level1.Play(1)
Print "main sum "; Shared.Sum(10)
Print "main count "; Counter.Bump(); Counter.Bump(); " "; Counter.Marks()
Print "loaded "; Level1.Loaded(); Level2.Loaded(); Credits.Loaded()
Credits.Show
Print "done"
End

' called from LEVEL2's code: Shared's copy in the window (LEVEL2) is used
Function Helper(ByVal n As Integer) As Integer
  Helper = Shared.Odd(n) + 1000
End Function
