' Keys: Down(n) and Joystick(n) - the harness holds key {n} for a few scans
Dim i As Integer, s As String, n As Integer, j As Integer
Print "space "; Keys.Down(Keys.KeySpace); " bad "; Keys.Down(80); Keys.Down(-1)
s = ""
n = 0
Do
  If Keys.Down(Keys.KeySpace) Then s = s + "S" : Do While Keys.Down(Keys.KeySpace) : Loop : n = n + 1
  If Keys.Down(Keys.KeyA) Then s = s + "A" : Do While Keys.Down(Keys.KeyA) : Loop : n = n + 1
  j = Keys.Joystick(0)
  If j Then s = s + "J" + Str$(j) : Do While Keys.Joystick(0) : Loop : n = n + 1
  j = Keys.Joystick(1)
  If j Then s = s + "K" + Str$(j) : Do While Keys.Joystick(1) : Loop : n = n + 1
Loop Until n = 5
Print s
Print "done"
