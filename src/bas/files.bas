' Files: what this platform can do, then try it. The same program builds for every
' platform - FileSystem.Capability says what works, so nothing is tried that can't be done.
' CP/M: everything. CPC firmware: Load and Save (disc, or tape without AMSDOS).
' CPC hardware / test platform: no files.
Option Explicit
#If NTC_CPCFW Then
' RUN"FILES resets the firmware and drops AMSDOS: start it again (ROM 7) so files go to disc.
' Without this, files go to disc only when the program is loaded from BASIC and CALLed.
Option RomEnable 7
#End If
#If NTC_CPCMIN Then
' RUN"FILES resets the firmware and drops AMSDOS: start it again (ROM 7) so files go to disc.
' Without this, files go to disc only when the program is loaded from BASIC and CALLed.
Option RomEnable 7
#End If
Dim hs(9) As Integer, back(9) As Integer
Dim i As Integer, r As Integer, h As Integer

Print "Files on "; System.Platform
Print "LOAD "; FileSystem.Capability("LOAD"); "  SAVE "; FileSystem.Capability("SAVE")
Print "SEQUENTIAL "; FileSystem.Capability("SEQUENTIAL"); "  RANDOMACCESS "; FileSystem.Capability("RANDOMACCESS")
Print "MAXOPEN "; FileSystem.Capability("MAXOPEN")
If FileSystem.Capability("DEVICES") Then Print "Devices "; FileSystem.Devices(); " - using "; FileSystem.CurrentDevice()
If FileSystem.Capability("VOLUMES") Then Print "Volumes known "; FileSystem.Volumes(); " - using "; FileSystem.CurrentVolume()
Print

If FileSystem.Capability("SAVE") Then
  For i = 0 To 9 : hs(i) = 1000 - i * 50 : Next
  r = FileSystem.Save("HISCORE.DAT", VarPtr(hs), 20)
  Print "Save HISCORE.DAT: "; r
  If FileSystem.Capability("LOAD") Then
    r = FileSystem.Load("HISCORE.DAT", VarPtr(back), 20)
    Print "Load: "; r; " bytes, "; back(0); " ... "; back(9)
  End If
Else
  Print "No saving on this platform"
End If

If FileSystem.Capability("SEQUENTIAL") Then
  h = FileSystem.Open("NOTES.TXT", FileSystem.ForWrite)
  r = FileSystem.WriteLine(h, "Written by NTC BASIC")
  r = FileSystem.WriteLine(h, "Line two")
  r = FileSystem.Close(h)
  Print "NOTES.TXT:"
  h = FileSystem.Open("NOTES.TXT", FileSystem.ForRead)
  Do While Not FileSystem.Eof(h)
    Print "> "; FileSystem.ReadLine(h)
  Loop
  r = FileSystem.Close(h)
End If

Print "Press a key";
Do While Inkey <> 0 : Loop          ' no key left waiting from before
Do : Frame : Loop Until Inkey <> 0
Print
End
