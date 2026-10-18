' FileSystem on CP/M: whole files, text lines, random access, the statuses
Option Explicit
Dim a(9) As Integer, b(9) As Integer
Dim i As Integer, r As Integer, h As Integer, h2 As Integer, h3 As Integer, n As Integer
Dim s As String
Dim p As Long
For i = 0 To 9 : a(i) = i * 11 : Next
Print "cap"; FileSystem.Capability("save"); FileSystem.Capability("MAXOPEN"); FileSystem.Capability("nothing")
r = FileSystem.Save("TEST.DAT", VarPtr(a), 20)
Print "save"; r
n = FileSystem.Load("TEST.DAT", VarPtr(b), 20)
Print "load"; n; b(0); b(9)
Print "toobig"; FileSystem.Load("TEST.DAT", VarPtr(b), 0)
Print "size"; FileSystem.Size("TEST.DAT"); FileSystem.Size("NONE.DAT")
Print "exists"; FileSystem.Exists("test.dat"); FileSystem.Exists("NONE.DAT")
Print "missing"; FileSystem.Load("NONE.DAT", VarPtr(b), 20)
Print "badname"; FileSystem.Save("A*.DAT", VarPtr(a), 2); FileSystem.Save("TOOLONGNAME.DAT", VarPtr(a), 2); FileSystem.Save(".DAT", VarPtr(a), 2)
h = FileSystem.Open("T.TXT", FileSystem.ForWrite)
r = FileSystem.WriteLine(h, "hello")
r = FileSystem.WriteLine(h, "world 2")
r = FileSystem.Close(h)
h = FileSystem.Open("T.TXT", FileSystem.ForRead)
Do While Not FileSystem.Eof(h)
  s = FileSystem.ReadLine(h)
  Print "["; s; "]"
Loop
r = FileSystem.Close(h)
h = FileSystem.Open("R.DAT", FileSystem.ForUpdate)
For i = 0 To 299 : r = FileSystem.WriteByte(h, i And 255) : Next
p = 200
r = FileSystem.Seek(h, p)
Print "seek"; FileSystem.ReadByte(h); FileSystem.ReadByte(h)
p = 5
r = FileSystem.Seek(h, p)
r = FileSystem.WriteByte(h, 99)
p = 4
r = FileSystem.Seek(h, p)
Print "update"; FileSystem.ReadByte(h); FileSystem.ReadByte(h); FileSystem.ReadByte(h)
r = FileSystem.Close(h)
h = FileSystem.Open("R.DAT", FileSystem.ForRead)
n = FileSystem.Read(h, VarPtr(b), 20)
Print "read"; n; b(0); b(2)
Print "readonly"; FileSystem.WriteByte(h, 1)
p = 299
r = FileSystem.Seek(h, p)
Print "last"; FileSystem.ReadByte(h)
r = FileSystem.Close(h)
Print "badhandle"; FileSystem.Close(h); FileSystem.ReadByte(9)
h = FileSystem.Open("T.TXT", FileSystem.ForRead)
h2 = FileSystem.Open("T.TXT", FileSystem.ForRead)
h3 = FileSystem.Open("T.TXT", FileSystem.ForRead)
Print "handles"; h; h2; h3
r = FileSystem.Close(h)
r = FileSystem.Close(h2)
Print "badmode"; FileSystem.Open("T.TXT", 7)
Print "rename"; FileSystem.Rename("R.DAT", "S.DAT"); FileSystem.Exists("S.DAT"); FileSystem.Exists("R.DAT")
Print "taken"; FileSystem.Rename("S.DAT", "T.TXT")
Print "delete"; FileSystem.Delete("S.DAT"); FileSystem.Delete("S.DAT")
Print "devices "; FileSystem.Devices(); " now "; FileSystem.CurrentDevice(); FileSystem.SelectDevice("disc"); FileSystem.SelectDevice("TAPE")
Print "cpm"; FileSystem.Capability("CPMVERSION"); FileSystem.Capability("VOLUMES")
Print "volumes "; FileSystem.Volumes(); " now "; FileSystem.CurrentVolume()
Print "vol b"; FileSystem.SelectVolume("B"); " now "; FileSystem.CurrentVolume(); " volumes "; FileSystem.Volumes(); " save"; FileSystem.Save("ONB.DAT", VarPtr(a), 4)
Print "on a"; FileSystem.Exists("A:TEST.DAT"); FileSystem.Exists("TEST.DAT")
Print "vol q"; FileSystem.SelectVolume("Q"); FileSystem.SelectVolume("A")
Print "command"; System.Command("DISC")
Print "end"
