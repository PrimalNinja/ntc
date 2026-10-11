' FileSystem where there are no files: Capability 0, NotSupported, Eof True, ReadLine ""
Option Explicit
Dim a(9) As Integer
Print "cap"; FileSystem.Capability("LOAD"); FileSystem.Capability("MAXOPEN")
Print "save"; FileSystem.Save("TEST.BIN", VarPtr(a), 20); FileSystem.Load("TEST.BIN", VarPtr(a), 20)
Print "open"; FileSystem.Open("T.TXT", FileSystem.ForRead); FileSystem.Eof(1); "["; FileSystem.ReadLine(1); "]"
Print "end"
