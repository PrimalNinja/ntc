' Option Safe: Bank's code is placed in the safe area #3000-#37FF, the program built round it.
' This uses the deprecated Option Safe Areas form (Option Memory Safe is the current one - see
' MMain.bas); Option Deprecated allows it, so the test still exercises that path.
Option Deprecated
Option Safe Areas = &H3000, &H0800
Option Safe "BANK" = Bank
Dim r As Integer
r = Bank.Add(10, 20)
Print "bank add "; r
Print "done"
End
