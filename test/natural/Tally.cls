' Tally - a class with a natural part inside a Sub (the file stays a class).
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Private sums(3) As Integer

Public Sub Bump(ByVal id As Integer, ByVal n As Integer)
    Dim was As Integer
    was = sums(id)
    #natural
    add n to was
    if was is above 10 set was to 10 end
    #endnatural
    sums(id) = was
End Sub

Public Function Value(ByVal id As Integer) As Integer
    Value = sums(id)
End Function
