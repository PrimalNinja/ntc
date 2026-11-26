' C64 + REU: a world bigger than the C64's memory. The map is 256 x 256 squares - 64K, a whole
' REU bank - and the screen is a window on it, 40 x 24. Moving the window is 24 rows fetched
' from the REU (Reu.FetchRect): about a sixth of a frame, so it moves every frame.
' Q up, A down, O left, P right - or a joystick in port 2. Space: jump to a far corner.
' (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit

Const MAPBANK = 1
Dim x As Integer, y As Integer, ox As Integer, oy As Integer
Dim i As Integer, j As Integer, r As Integer, k As Integer, n As Integer

' the 24 rows on show, from the REU: map square x, y is at address y * 256 + x
Sub Show()
  Reu.FetchRect MAPBANK, y * 256 + x, 256, &HE000, 40, 40, 24
End Sub

Cls
Print "building the world (64K in the REU)..."
' grass everywhere, then things on it: trees, water, walls, paths
Reu.Fill MAPBANK, 0, 46, 32768
Reu.Fill MAPBANK, &H8000, 46, 32767
Reu.Poke MAPBANK, &HFFFF, 46
For i = 1 To 500
  Reu.Poke MAPBANK, Rnd(32767) * 2 + (i And 1), 42          ' a tree
Next
For i = 1 To 40
  r = Rnd(240)
  k = Rnd(200)
  n = 4 + Rnd(12)
  For j = 0 To 2 + Rnd(6)
    Reu.Fill MAPBANK, (r + j) * 256 + k, 126, n             ' a lake
  Next
Next
For i = 1 To 30
  Reu.Fill MAPBANK, Rnd(255) * 256 + Rnd(200), 35, 6 + Rnd(40)    ' a wall
Next
For i = 0 To 255 Step 16
  Reu.Fill MAPBANK, i * 256, 61, 256                        ' a road every 16 rows
Next
For i = 0 To 255                                            ' the edge of the world
  Reu.Poke MAPBANK, i * 256, 124
  Reu.Poke MAPBANK, i * 256 + 255, 124
Next

StdIO.Pen 5
Cls
x = 100 : y = 100 : ox = -1
Do
  If x <> ox Or y <> oy Then
    Show
    ox = x : oy = y
    StdIO.Pen 7
    Locate 1, 25
    Print "x"; x; " y"; y; "  q a o p / joystick   ";
    StdIO.Pen 5
  End If
  Frame
  k = Joy.Read(2)
  If Keys.Down(Keys.KeyQ) Or (k And Joy.Up) Then y = y - 1
  If Keys.Down(Keys.KeyA) Or (k And Joy.Down) Then y = y + 1
  If Keys.Down(Keys.KeyO) Or (k And Joy.Left) Then x = x - 1
  If Keys.Down(Keys.KeyP) Or (k And Joy.Right) Then x = x + 1
  If Keys.Down(Keys.KeySpace) Then x = Rnd(215) : y = Rnd(231)
  If x < 0 Then x = 0
  If x > 216 Then x = 216
  If y < 0 Then y = 0
  If y > 232 Then y = 232
Loop
