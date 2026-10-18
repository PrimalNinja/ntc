' File test in steps: each step says what it is about to do, then waits for a key, so a
' crash shows where it happened. Without Option RomEnable: after RUN" the firmware has no AMSDOS (tape).
Option PressAnyKeyOnEnd "Press a key to end"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
Dim a(9) As Integer, b(9) As Integer
Dim i As Integer, r As Integer

Print "1 started"
Wait
Print "2 Capability LOAD"; FileSystem.Capability("LOAD"); " SAVE"; FileSystem.Capability("SAVE")
Wait
Print "3 Devices: "; FileSystem.Devices()
Wait
Print "4 CurrentDevice: "; FileSystem.CurrentDevice(); "  Volume: "; FileSystem.CurrentVolume()
Wait
For i = 0 To 9 : a(i) = 1000 - i * 50 : Next
Print "5 Save STEP.DAT..."
Wait
r = FileSystem.Save("STEP.DAT", VarPtr(a), 20)
Print "  Save gave"; r
Wait
Print "6 Load STEP.DAT..."
Wait
r = FileSystem.Load("STEP.DAT", VarPtr(b), 20)
Print "  Load gave"; r; ", "; b(0); " ... "; b(9)
Print "7 done"
End

Sub Wait()
  Print "  (press a key)"
  Do While Inkey <> 0 : Loop
  Do : Frame : Loop Until Inkey <> 0
End Sub
