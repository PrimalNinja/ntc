' AMSDOS on the CPC with minimal firmware (platform cpcmin): NTC draws its own text and reads
' the keyboard itself; each FileSystem call hands the machine back to the firmware (AMSDOS)
' for its length, then NTC takes it again. Also runs on cpcfw (all through the firmware). RUN"AMSDOS: Option RomEnable 7 starts
' AMSDOS again (RUN" drops it). Checks: Load / Save, an AMSDOS message on NTC's screen, the
' mode kept across a file call, NTC's ticks still counting, drive B (if you choose).
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Option Explicit
#If NTC_CPCMIN Then
Option RomEnable 7
#End If
#If NTC_CPCFW Then
Option RomEnable 7
#End If
Dim a(9) As Integer, b(9) As Integer
Dim i As Integer, r As Integer, k As Integer, t As Integer

Mode 1
Print "AMSDOS test on "; System.Platform
Print "Devices "; FileSystem.Devices(); " - using "; FileSystem.CurrentDevice()
Print "Volumes "; FileSystem.Volumes(); " - using "; FileSystem.CurrentVolume()
Wait

For i = 0 To 9 : a(i) = 1000 - i * 50 : Next
r = FileSystem.Save("AMS1.DAT", VarPtr(a), 20)
Print "Save AMS1.DAT:"; r
r = FileSystem.Load("AMS1.DAT", VarPtr(b), 20)
Print "Load AMS1.DAT:"; r; " -"; b(0); " ..."; b(9)
t = Ticks
Frame : Frame
Print "Ticks still counting:"; IIf(Ticks <> t Or System.TicksPerSecond = 0, " yes", " NO")
Print "A file that isn't there"
Print "(AMSDOS may print its message):"
r = FileSystem.Load("NOFILE.DAT", VarPtr(b), 20)
Print "Load NOFILE.DAT:"; r; " (NotFound is -2)"
Wait

Mode 2
Print "Mode 2 (80 columns): saving again..."
r = FileSystem.Save("AMS2.DAT", VarPtr(a), 20)
Print "Save AMS2.DAT:"; r; " - this line should still be 80 columns, under the one above"
Wait

Mode 1
Print "B = try drive B, any other key = skip"
Do While Inkey <> 0 : Loop
Do : k = Inkey : Frame : Loop Until k <> 0
If k = 66 Or k = 98 Then
  Print "SelectVolume B:"; FileSystem.SelectVolume("B")
  r = FileSystem.Save("AMS3.DAT", VarPtr(a), 20)
  Print "Save B:AMS3.DAT:"; r
  r = FileSystem.Load("AMS3.DAT", VarPtr(b), 20)
  Print "Load:"; r; " -"; b(0)
  r = FileSystem.SelectVolume("A")
  Print "Volumes now "; FileSystem.Volumes()
End If
Print "done"
End

Sub Wait()
  Print "Press a key"
  Do While Inkey <> 0 : Loop
  Do : Frame : Loop Until Inkey <> 0
End Sub
