' Pool - a library class: Open gives a handle, every call takes it
Option Explicit

Public Const MAXSLOTS = 4

Private Type Slot
  used As Integer
  total As Integer
  count As Integer
End Type

Private mSlots(MAXSLOTS - 1) As Slot
Private mOpen As Integer

Public Function Open(ByVal start As Integer) As Integer
  Dim h As Integer
  For h = 0 To MAXSLOTS - 1
    If mSlots(h).used = 0 Then
      mSlots(h).used = -1
      mSlots(h).total = start
      mSlots(h).count = 0
      mOpen = mOpen + 1
      Open = h
      Exit Function
    End If
  Next
  Open = -1
End Function

Public Sub Add(ByVal h As Integer, ByVal n As Integer)
  mSlots(h).total = mSlots(h).total + n
  Bump h
End Sub

Public Function Value(ByVal h As Integer) As Integer
  Value = mSlots(h).total
End Function

Public Function Uses(ByVal h As Integer) As Integer
  Uses = mSlots(h).count
End Function

Public Sub Close(ByVal h As Integer)
  mSlots(h).used = 0
  mOpen = mOpen - 1
End Sub

Private Sub Bump(ByVal h As Integer)
  mSlots(h).count = mSlots(h).count + 1
End Sub
