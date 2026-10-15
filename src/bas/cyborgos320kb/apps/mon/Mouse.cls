' Mouse - an Amiga mouse on the CPC's mouse interface (the dual Amiga mouse card: X at &F994,
' Y at &F995 - the movement since the last read, a signed byte -, the buttons at &F991: bit 4
' left, 5 right, 6 middle). Poll as often as you like: each read is the movement since the one
' before. A program in a slot reads the ports itself (I/O isn't banked); CyborgOS will later hand
' the mouse to one slot at a time
Option Explicit
Private dx As Integer, dy As Integer, bt As Integer, ok As Integer

' Present(): True when a mouse interface answers (no card: every port reads #FF)
Public Function Present() As Integer
  ok = Not (Inp(&HF991) = 255 And Inp(&HF994) = 255 And Inp(&HF995) = 255)
  Present = ok
End Function

' Poll: the movement since the last poll and the buttons now
Public Sub Poll()
  dx = 0 : dy = 0 : bt = 0
  If ok = 0 Then Exit Sub
  dx = Inp(&HF994)
  dy = Inp(&HF995)
  bt = Inp(&HF991)
  If dx > 127 Then dx = dx - 256
  If dy > 127 Then dy = dy - 256
End Sub

' the movement (right and down are +), the buttons (1 left, 2 right, 4 middle)
Public Function MoveX() As Integer
  MoveX = dx
End Function
Public Function MoveY() As Integer
  MoveY = dy
End Function
Public Function Buttons() As Integer
  Buttons = (bt \ 16) And 7
End Function
