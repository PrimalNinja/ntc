' CITY3D: fly through a wireframe city - Freescape-style lines, no hidden line removal. 64 x 64
' blocks that repeat for ever, about 2000 units seen ahead. City.cls does the work (Z80), the
' Graphics class draws (double buffering: main RAM's #4000 is the second screen).
' Keys (Elite's): < > roll, S X dive / climb, Space faster, ? slower; the cursor keys turn left /
' right and dive / climb; T turbo on / off; Q quits.
' cpcfw: an AMSDOS file (RUN"CITY3D) with the firmware running; the drawing is the class's own.
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Option Reserve &H4000, &H4000     ' main RAM's #4000-#7FFF: the second screen
Option Reserve &H8000, &H1400     ' the city's map and tables (City.cls)
Dim k As Integer, tk As Integer, fast As Integer, spd As Integer
Dim p As Integer, r As Integer, y As Integer, frames As Integer, t As Integer, fps As Integer

Mode 1
Print "CITY3D - fly through the city"
Print
Print "< >       roll"
Print "S X       dive / climb"
Print "cursors   turn, dive / climb"
Print "Space ?   faster / slower"
Print "T         turbo on / off"
Print "Q         quit"
Print
Print "Press a key"
Do : Loop Until Inkey <> 0
City.Init
Cls
Graphics.DoubleBuffer 1
spd = 8
t = Ticks
Do
  p = 0 : r = 0 : y = 0
  If Keys.Down(Keys.KeyS) Or Keys.Down(Keys.KeyUp) Then p = -1      ' dive
  If Keys.Down(Keys.KeyX) Or Keys.Down(Keys.KeyDown) Then p = 1     ' climb
  If Keys.Down(39) Then r = -1                                      ' < (the , key)
  If Keys.Down(31) Then r = 1                                       ' > (the . key)
  If Keys.Down(Keys.KeyLeft) Then y = -1
  If Keys.Down(Keys.KeyRight) Then y = 1
  If Keys.Down(Keys.KeySpace) And spd < 64 Then spd = spd + 1
  If Keys.Down(30) And spd > 0 Then spd = spd - 1                   ' ? (the / key)
  City.Steer p, r, y, spd
  If fast Then
    Turbo On
    City.Render
    Turbo Off
  Else
    City.Render
  End If
  Graphics.Flip
  frames = frames + 1
  If frames = 16 Then
    If fast Then fps = 0 Else fps = 16 * System.TicksPerSecond \ (Ticks - t + 1)
    frames = 0 : t = Ticks
    Locate 1, 1
    Print "SPEED"; spd; " HEIGHT"; City.Altitude(); IIf(fast, " TURBO", ""); "  FPS"; fps; "    ";
    Graphics.CopyText 1
  End If
  k = Keys.Down(51)                                                 ' T: turbo on / off
  If k <> 0 And tk = 0 Then fast = Not fast
  tk = k
Loop Until Keys.Down(Keys.KeyQ)
Graphics.DoubleBuffer 0
Mode 1
Print "Bye"
End
