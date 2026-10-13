' Spin: the demo - builds the shapes, turns them and draws them with Vector3D.
' On cpcmin and cpcfw it is an overlay class: its code is in CUBE3D.001 (page SPIN), loaded into a RAM
' page by the first call, and it calls Vector3D and Graphics in main memory from there. On
' cpc (no files) it is part of the program.
#If NTC_CPCMIN Then
Option Class Overlay Spin
#End If
#If NTC_CPCFW Then
Option Class Overlay Spin
#End If
Private ax As Integer, ay As Integer, az As Integer
Private fx As Integer, fy As Integer, fz As Integer ' the angles in 256ths (8.8, wrapping: the high byte is the angle)
Private size As Integer, shape As Integer, frames As Integer, mode As Integer
Private dbl As Integer, fast As Integer, paused As Integer, fps As Integer

Public Sub Run()
  Dim k As String, t As Integer
  size = 280 : shape = 1 : mode = 1
#If NTC_CPM Then
  mode = 2                        ' CP/M: the console's mode, one screen
#End If
  Screen
  MakeShape
  t = Ticks
  Do
    If fast Then
      Turbo On
      Frame1
      Turbo Off
    Else
      Frame1
    End If
    frames = frames + 1
    If frames = 25 Then
      fps = 25 * System.TicksPerSecond \ (Ticks - t + 1)
      frames = 0 : t = Ticks
      Status
    End If
    k = UCase$(Inkey$)
    If k = "1" Or k = "2" Or k = "3" Or k = "4" Then shape = Val(k) : MakeShape
    If k = "+" Or k = "=" Then size = size + 20 : Vector3D.View 160, 112, size, 768
    If k = "-" And size > 60 Then size = size - 20 : Vector3D.View 160, 112, size, 768
    If k = "P" Then paused = Not paused
#If NTC_CPM Then
    If k = "A" Or k = "B" Or k = "C" Or k = "D" Then k = ""
#End If
    If k = "A" Or k = "B" Or k = "C" Then mode = Asc(k) - 65 : Screen
    If k = "D" Then
      Vector3D.Hide
      dbl = Not dbl
      Graphics.DoubleBuffer dbl
      Status
    End If
    If k = "T" Then fast = Not fast : Status
  Loop Until k = "X"
  Vector3D.Hide
  Graphics.DoubleBuffer 0
End Sub

' one frame: turn, wait for the flyback (one screen) or not (two: Show flips), draw. The angles
' move a fixed step each frame (X 2, Y 3, Z 1 in 256ths of a turn; 8.8: the high byte is the
' angle), so the turn is smooth whatever the mode; a faster frame is a faster turn
Private Sub Frame1()
  Vector3D.Turn ax, ay, az
  If dbl = 0 Then Frame
  Vector3D.Show
  If paused = 0 Then
    fx = fx + 512 : fy = fy + 768 : fz = fz + 256
    ax = Peek(VarPtr(fx) + 1) : ay = Peek(VarPtr(fy) + 1) : az = Peek(VarPtr(fz) + 1)
  End If
End Sub

' a new screen mode: the shape off both screens, the mode set, the text again
Private Sub Screen()
  Vector3D.Hide
  Graphics.DoubleBuffer 0
#If NTC_CPM Then
  Cls                             ' (Option Terminal VT52; Mode does nothing on CP/M)
#Else
  Mode mode
#End If
  Vector3D.Forget
  Print "1-4 shape A-C mode"
  Print "D double T turbo +-PX"
  Status
  If dbl Then Graphics.DoubleBuffer 1
End Sub

' the state line (row 3), on both screens when double buffering
Private Sub Status()
  Locate 1, 3
  Print "M"; mode; IIf(dbl, " dbl", " one"); IIf(fast, " turbo ", " normal "); fps; "fps  ";
  If dbl Then Graphics.CopyText 3
End Sub

' the chosen shape (or all three, small) into Vector3D
Private Sub MakeShape()
  Vector3D.Hide
  Vector3D.Clear
  Vector3D.View 160, 112, size, 768
  Select Case shape
    Case 1: Cube 0, 0, 128
    Case 2: Pyramid 0, 0, 128
    Case 3: Cobra
    Case 4: Cube -170, 0, 64 : Pyramid 170, 0, 64 : Cube 0, 0, 40
  End Select
End Sub

' a cube of half side h, centred at (x, y, 0) (8.8)
Private Sub Cube(ByVal x As Integer, ByVal y As Integer, ByVal h As Integer)
  Dim p As Integer, i As Integer
  p = Vector3D.Points()
  For i = 0 To 7
    If Vector3D.AddPoint(x + IIf(i And 1, h, -h), y + IIf(i And 2, h, -h), IIf(i And 4, h, -h)) < 0 Then Exit Sub
  Next
  ' the 12 edges: points that differ in one corner bit
  For i = 0 To 7
    If (i And 1) = 0 Then Vector3D.AddEdge p + i, p + i + 1
    If (i And 2) = 0 Then Vector3D.AddEdge p + i, p + i + 2
    If (i And 4) = 0 Then Vector3D.AddEdge p + i, p + i + 4
  Next
End Sub

' a pyramid: a square base of half side h, the top above its middle
Private Sub Pyramid(ByVal x As Integer, ByVal y As Integer, ByVal h As Integer)
  Dim p As Integer, r As Integer, i As Integer
  p = Vector3D.Points()
  r = Vector3D.AddPoint(x - h, y - h, -h)
  r = Vector3D.AddPoint(x + h, y - h, -h)
  r = Vector3D.AddPoint(x + h, y + h, -h)
  r = Vector3D.AddPoint(x - h, y + h, -h)
  r = Vector3D.AddPoint(x, y, h)
  For i = 0 To 3
    Vector3D.AddEdge p + i, p + ((i + 1) And 3)
    Vector3D.AddEdge p + i, p + 4
  Next
End Sub

' the Cobra Mk III from Elite (the points from the TEC demo's line list)
Private Sub Cobra()
  Dim r As Integer
  r = Vector3D.AddPoint(0, 213, 0) : r = Vector3D.AddPoint(0, 128, 0)
  r = Vector3D.AddPoint(-85, 128, 0) : r = Vector3D.AddPoint(85, 128, 0)
  r = Vector3D.AddPoint(-238, -128, 0) : r = Vector3D.AddPoint(-256, -213, 0)
  r = Vector3D.AddPoint(-85, -213, -34) : r = Vector3D.AddPoint(85, -213, -34)
  r = Vector3D.AddPoint(256, -213, 0) : r = Vector3D.AddPoint(238, -128, 0)
  r = Vector3D.AddPoint(0, 42, 85) : r = Vector3D.AddPoint(-170, -213, 59)
  r = Vector3D.AddPoint(0, -213, 85) : r = Vector3D.AddPoint(170, -213, 59)
  Edge 0, 1 : Edge 2, 3 : Edge 2, 4 : Edge 4, 5 : Edge 5, 6 : Edge 6, 7
  Edge 7, 8 : Edge 8, 9 : Edge 9, 3 : Edge 2, 6 : Edge 3, 7 : Edge 2, 10
  Edge 10, 3 : Edge 10, 11 : Edge 10, 12 : Edge 10, 13 : Edge 2, 11 : Edge 3, 13
  Edge 5, 11 : Edge 11, 12 : Edge 12, 13 : Edge 13, 8 : Edge 13, 9 : Edge 11, 4
End Sub

Private Sub Edge(ByVal a As Integer, ByVal b As Integer)
  Vector3D.AddEdge a, b
End Sub
