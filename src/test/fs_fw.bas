' FileSystem on the CPC firmware: Load / Save (CAS IN / OUT DIRECT), the rest NotSupported
Option RomEnable 7
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
Print "open"; FileSystem.Open("TEST.BIN", FileSystem.ForRead); FileSystem.Delete("TEST.BIN"); FileSystem.Close(1)
Print "devices "; FileSystem.Devices(); " now "; FileSystem.CurrentDevice(); FileSystem.Capability("DEVICES"); FileSystem.Capability("VOLUMES")
Print "volumes "; FileSystem.Volumes(); " now "; FileSystem.CurrentVolume()
Print "vol b"; FileSystem.SelectVolume("b:"); " now "; FileSystem.CurrentVolume(); " save"; FileSystem.Save("ONB.BIN", VarPtr(a), 4)
Print "vol x"; FileSystem.SelectVolume("X"); FileSystem.SelectVolume("TOOLONGNAME"); " volumes "; FileSystem.Volumes()
Print "save c:"; FileSystem.Save("C:ONC.BIN", VarPtr(a), 4); " volumes "; FileSystem.Volumes()
Print "vol m"; FileSystem.SelectVolume("m"); FileSystem.SelectVolume("B"); " volumes "; FileSystem.Volumes()
Print "tape"; FileSystem.SelectDevice("Tape"); " now "; FileSystem.CurrentDevice(); " save"; FileSystem.Save("ONT.BIN", VarPtr(a), 4)
Print "disc"; FileSystem.SelectDevice("DISC"); " now "; FileSystem.CurrentDevice(); FileSystem.SelectDevice("A")
Print "command"; System.Command("disc"); System.Command("NOSUCH"); System.Command("")
Print "end"
