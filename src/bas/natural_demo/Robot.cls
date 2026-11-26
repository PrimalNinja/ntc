' Robot - the Natural flavour's maze example: a robot in a maze of characters. No ids (with
' robot ...): enter maze, forward, turn left, turn right, show; clear ahead, clear right,
' clear left and home are state words; steps is a value. (c) 2026 Cyborg Unicorn Pty Ltd -
' MIT License
Option Explicit

Const W = 15
Const H = 9
Private rows(8) As String
Private x As Integer, y As Integer
Private dx As Integer, dy As Integer
Private moves As Integer

Public Sub EnterMaze()
    rows(0) = "###############"
    rows(1) = "S   #     #   #"
    rows(2) = "### # ### # # #"
    rows(3) = "#   #   #   # #"
    rows(4) = "# ##### ##### #"
    rows(5) = "#     #     # #"
    rows(6) = "# ### ##### # #"
    rows(7) = "#   #         E"
    rows(8) = "###############"
    x = 0 : y = 1 : dx = 1 : dy = 0 : moves = 0
End Sub

Private Function Open(ByVal cx As Integer, ByVal cy As Integer) As Integer
    Open = 0
    If cx >= 0 And cx < W And cy >= 0 And cy < H Then
        If Mid$(rows(cy), cx + 1, 1) <> "#" Then Open = 1
    End If
End Function

Public Function ClearAhead() As Integer
    ClearAhead = Open(x + dx, y + dy)
End Function

Public Function ClearRight() As Integer
    ClearRight = Open(x - dy, y + dx)
End Function

Public Function ClearLeft() As Integer
    ClearLeft = Open(x + dy, y - dx)
End Function

Public Function Home() As Integer
    If Mid$(rows(y), x + 1, 1) = "E" Then Home = 1 Else Home = 0
End Function

Public Function Steps() As Integer
    Steps = moves
End Function

' Forward: one square on, leaving a dot where it was
Public Sub Forward()
    Dim strRow As String
    If Open(x + dx, y + dy) <> 0 Then
        strRow = rows(y)
        If Mid$(strRow, x + 1, 1) = " " Then
            Mid$(strRow, x + 1, 1) = "."
            rows(y) = strRow
        End If
        x = x + dx : y = y + dy
        moves = moves + 1
    End If
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
    Dim r As Integer
    For r = 0 To H - 1
        Print rows(r)
    Next r
End Sub
