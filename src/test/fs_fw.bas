' FileSystem on the CPC firmware: Load / Save (CAS IN / OUT DIRECT), the rest NotSupported
Option Explicit
Dim a(9) As Integer, b(9) As Integer
Dim i As Integer, r As Integer, n As Integer
For i = 0 To 9 : a(i) = i * 11 : Next
Print "cap"; FileSystem.Capability("LOAD"); FileSystem.Capability("save"); FileSystem.Capability("SEQUENTIAL")
r = FileSystem.Save("TEST.BIN", VarPtr(a), 20)
Print "save"; r
n = FileSystem.Load("TEST.BIN", VarPtr(b), 20)
Print "load"; n; b(0); b(9)
Print "toobig"; FileSystem.Load("TEST.BIN", VarPtr(b), 19)
Print "missing"; FileSystem.Load("NONE.BIN", VarPtr(b), 20)
Print "open"; FileSystem.Open("TEST.BIN", FileSystem.ForRead); FileSystem.Delete("TEST.BIN")
Print "end"
