' Turtle - the Natural flavour's drawing example: a turtle on a 38 x 18 sheet of characters.
' It has no ids (with turtle ...): clear, pen up, pen down, move to x y, forward n, turn right,
' turn left, ink "#", show. (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const W = 38
Const H = 18
Private cells(683) As Byte          ' W * H characters
Private x As Integer, y As Integer
Private dx As Integer, dy As Integer
Private blnDown As Integer
Private mark As Integer

Public Sub Clear()
    Dim i As Integer
    For i = 0 To W * H - 1
        cells(i) = 32
    Next i
    x = 0 : y = 0 : dx = 1 : dy = 0 : blnDown = 0 : mark = 42
End Sub

Public Sub PenUp()
    blnDown = 0
End Sub

Public Sub PenDown()
    blnDown = 1
    Dot
End Sub

Public Sub Ink(ByVal c As String)
    mark = Asc(c)
End Sub

Public Sub MoveTo(ByVal nx As Integer, ByVal ny As Integer)
    x = nx : y = ny
    If blnDown <> 0 Then Dot
End Sub

Public Sub Forward(ByVal n As Integer)
    Dim i As Integer
    For i = 1 To n
        x = x + dx : y = y + dy
        If blnDown <> 0 Then Dot
    Next i
End Sub

Public Sub TurnRight()
    Dim t As Integer
    t = dx : dx = -dy : dy = t
End Sub

Public Sub TurnLeft()
    Dim t As Integer
    t = dx : dx = dy : dy = -t
End Sub

Public Sub Show()
    Dim r As Integer, c As Integer, s As String
    For r = 0 To H - 1
        s = ""
        For c = 0 To W - 1
            s = s & Chr$(cells(r * W + c))
        Next c
        Print RTrim$(s)
    Next r
End Sub

Private Sub Dot()
    If x >= 0 And x < W And y >= 0 And y < H Then cells(y * W + x) = mark
End Sub
