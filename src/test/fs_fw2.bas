' FileSystem on the CPC firmware without Option RomEnable: AMSDOS only if it kept running
' (CALLed from BASIC: disc; RUN": tape)
Option Explicit
Dim a(3) As Integer
Print "now "; FileSystem.CurrentDevice(); " devices "; FileSystem.Devices(); " volume ["; FileSystem.CurrentVolume(); "]"
Print "save"; FileSystem.Save("KEPT.BIN", VarPtr(a), 8)
Print "end"
