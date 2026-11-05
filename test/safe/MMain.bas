' Same as Main.bas but the safe memory is declared with the unified Option Memory directive.
Option Memory Safe &H3000, &H0800
Option Safe "BANK" = Bank
Dim r As Integer
r = Bank.Add(10, 20)
Print "bank add "; r
Print "done"
End
