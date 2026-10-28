' Keys on the ZX Spectrum Next: Down(n) (half row * 8 + bit) - the harness holds key {n} for a
' few scans; Joystick(n) - the harness's Kempston ports read nothing pressed
Dim s As String, n As Integer
Print "space "; Keys.Down(Keys.KeySpace); " bad "; Keys.Down(64); Keys.Down(-1); Keys.Down(5); " joy "; Keys.Joystick(0); Keys.Joystick(1)
s = ""
n = 0
Do
  If Keys.Down(Keys.KeySpace) Then s = s + "S" : Do While Keys.Down(Keys.KeySpace) : Loop : n = n + 1
  If Keys.Down(Keys.KeyA) Then s = s + "A" : Do While Keys.Down(Keys.KeyA) : Loop : n = n + 1
  If Keys.Down(Keys.KeyB) Then s = s + "B" : Do While Keys.Down(Keys.KeyB) : Loop : n = n + 1
  If Keys.Down(Keys.KeyLeft) Then s = s + "<" : Do While Keys.Down(Keys.KeyLeft) : Loop : n = n + 1
Loop Until n = 5
Print s
Print "done"
