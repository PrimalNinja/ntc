' Account - the Natural flavour's bank example: eight accounts, in whole dollars. The class is
' the vocabulary: with account 1 ... deposit 50, withdraw 20, transfer 100 to savings, pay
' interest 2, charge 5; balance is a value, refused and empty are state words.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private money(7) As Long
Private blnRefused As Integer

Public Sub Deposit(ByVal id As Integer, ByVal amount As Integer)
    money(id) = money(id) + amount
    blnRefused = 0
End Sub

' Withdraw: refused when there is not enough
Public Sub Withdraw(ByVal id As Integer, ByVal amount As Integer)
    If money(id) >= amount Then
        money(id) = money(id) - amount
        blnRefused = 0
    Else
        blnRefused = 1
    End If
End Sub

Public Sub Transfer(ByVal id As Integer, ByVal amount As Integer, ByVal other As Integer)
    Withdraw id, amount
    If blnRefused = 0 Then money(other) = money(other) + amount
End Sub

' PayInterest: so many per cent of the balance added
Public Sub PayInterest(ByVal id As Integer, ByVal percent As Integer)
    money(id) = money(id) + (money(id) * percent) \ 100
End Sub

Public Sub Charge(ByVal id As Integer, ByVal fee As Integer)
    money(id) = money(id) - fee
End Sub

Public Function Balance(ByVal id As Integer) As Long
    Balance = money(id)
End Function

Public Function Refused() As Integer
    Refused = blnRefused
End Function

Public Function Empty(ByVal id As Integer) As Integer
    If money(id) <= 0 Then Empty = 1 Else Empty = 0
End Function
