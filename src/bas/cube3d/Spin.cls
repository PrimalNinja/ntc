' Spin: the demo itself - builds the shapes, turns them and draws them with Vector3D.
' On cpcmin it is an overlay class: its code is in SPIN.PAG, loaded into a RAM page by the
' first call, and calls Vector3D in main memory from there. On cpc (no files) it is part of
' the program.
#If NTC_CPCMIN Then
Option Class Overlay "SPIN"
#End If
Private ax As Integer, ay As Integer, az As Integer
Private dax As Integer, day As Integer, daz As Integer
Private size As Integer, shape As Integer, frames As Integer

Public Sub Run()
  Dim k As String, t As Integer, paused As Integer
  Cls
  Print "NTC 3D: 1 cube 2 pyramid 3 Cobra 4 all"
  Print "+ - size, P pause, X exit";
  size = 280
  shape = 1
  MakeShape
  dax = 2 : day = 3 : daz = 1
  t = Ticks
  Do
    Vector3D.Turn ax, ay, az
    Frame
    Vector3D.Show
    If paused = 0 Then
      ax = (ax + dax) And 255 : ay = (ay + day) And 255 : az = (az + daz) And 255
    End If
    frames = frames + 1
    If frames = 50 Then
      Locate 34, 2 : Print 50 * System.TicksPerSecond \ (Ticks - t + 1); "fps ";
      frames = 0 : t = Ticks
    End If
    k = UCase$(Inkey$)
    If k = "1" Or k = "2" Or k = "3" Or k = "4" Then shape = Val(k) : MakeShape
    If k = "+" Or k = "=" Then size = size + 20 : Vector3D.View 160, 112, size, 768
    If k = "-" And size > 60 Then size = size - 20 : Vector3D.View 160, 112, size, 768
    If k = "P" Then paused = Not paused
  Loop Until k = "X"
  Vector3D.Hide
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
