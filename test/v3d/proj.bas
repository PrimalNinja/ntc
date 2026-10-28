' Vector3D (bas/cube3d): known turns project to known pixels - regress.sh
Dim i As Integer, r As Integer
r = Vector3D.AddPoint(128, 0, 0) : r = Vector3D.AddPoint(0, 128, 0) : r = Vector3D.AddPoint(0, 0, 128) : r = Vector3D.AddPoint(-128, -128, 0)
Vector3D.View 160, 100, 400, 768
Vector3D.Turn 0, 0, 0
For i = 0 To 3 : Print Vector3D.ScreenX(i); ","; Vector3D.ScreenY(i); " "; : Next
Print
Vector3D.Turn 64, 0, 0
For i = 0 To 3 : Print Vector3D.ScreenX(i); ","; Vector3D.ScreenY(i); " "; : Next
Print
Vector3D.Turn 0, 0, 64
For i = 0 To 3 : Print Vector3D.ScreenX(i); ","; Vector3D.ScreenY(i); " "; : Next
