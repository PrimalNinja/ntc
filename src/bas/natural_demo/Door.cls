' Door - the Natural flavour demo's doors: a state for each id. A noun is a class, a verb a
' Public Sub whose first parameter is the id, a state word a Function of the id.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Private shuts(7) As Integer
Private locks(7) As Integer

Public Sub Shut(ByVal id As Integer)
    shuts(id) = 1
End Sub

Public Sub Open(ByVal id As Integer)
    If locks(id) = 0 Then shuts(id) = 0
End Sub

Public Sub Lock(ByVal id As Integer, ByVal code As Integer)
    locks(id) = code
End Sub

Public Sub Unlock(ByVal id As Integer, ByVal code As Integer)
    If locks(id) = code Then locks(id) = 0
End Sub

Public Function Closed(ByVal id As Integer) As Integer
    Closed = shuts(id)
End Function

Public Function Locked(ByVal id As Integer) As Integer
    If locks(id) <> 0 Then Locked = 1 Else Locked = 0
End Function
