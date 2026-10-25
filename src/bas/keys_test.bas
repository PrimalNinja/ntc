' Keys class: held keys and the joysticks, shown each frame (a key held down shows -1)
Dim i As Integer
Cls
For i = 1 To 400
  Locate 1, 1
  Print "W"; Keys.Down(Keys.KeyW); " Left"; Keys.Down(Keys.KeyLeft); " Space"; Keys.Down(Keys.KeySpace); "  "
  Print "Joy0"; Keys.Joystick(0); " Joy1"; Keys.Joystick(1); "  "
  Frame
Next
