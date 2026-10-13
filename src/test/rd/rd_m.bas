' ROMDISC beside AMSDOS (cpcmin, cpcfw): volume R and drive A, a disc file and a ROM file open at once
Option RomEnable 7
Dim b(3) As Integer, r As Integer, h1 As Integer, h2 As Integer
b(0) = 1234 : b(1) = 5678
r = FileSystem.Save("NOTE.BIN", VarPtr(b), 4)
Print "save "; r; " volumes "; FileSystem.Volumes()
r = FileSystem.SelectVolume("R")
Print "R "; r; " volumes "; FileSystem.Volumes(); " now "; FileSystem.CurrentVolume()
b(0) = 0
Print "on R "; FileSystem.Load("NOTE.BIN", VarPtr(b), 4); " on A "; FileSystem.Load("A:NOTE.BIN", VarPtr(b), 4); " "; b(0)
h1 = FileSystem.Open("A:COPY.TXT", FileSystem.ForWrite)
h2 = FileSystem.Open("HELLO.TXT", FileSystem.ForRead)
Print "handles "; h1; h2
Do While Not FileSystem.Eof(h2)
  r = FileSystem.WriteLine(h1, "copied: " + FileSystem.ReadLine(h2))
Loop
r = FileSystem.Close(h2)
r = FileSystem.Close(h1)
r = FileSystem.SelectVolume("A")
Print "A "; r; " now "; FileSystem.CurrentVolume(); " R size "; FileSystem.Size("R:BIG.BIN"); " A size "; FileSystem.Size("COPY.TXT")
h1 = FileSystem.Open("COPY.TXT", FileSystem.ForRead)
Do While Not FileSystem.Eof(h1)
  Print FileSystem.ReadLine(h1)
Loop
r = FileSystem.Close(h1)
Print "done"
