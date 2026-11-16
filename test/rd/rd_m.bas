' the ROM disc beside AMSDOS (cpcmin, cpcfw): FileSystem is the disc (drive A), ROMDiscFS the ROM disc -
' a disc file and a ROM file open at once
Option ROM Enable 7
Dim b(3) As Integer, r As Integer, h1 As Integer, h2 As Integer
b(0) = 1234 : b(1) = 5678
r = FileSystem.Save("NOTE.BIN", VarPtr(b), 4)
Print "save "; r; " volumes "; FileSystem.Volumes()
r = ROMDiscFS.SelectVolume("R")
Print "R "; r; " volumes "; ROMDiscFS.Volumes(); " disc still "; FileSystem.CurrentVolume()
b(0) = 0
Print "on R "; ROMDiscFS.Load("NOTE.BIN", VarPtr(b), 4); " on A "; FileSystem.Load("NOTE.BIN", VarPtr(b), 4); " "; b(0)
h1 = FileSystem.Open("COPY.TXT", FileSystem.ForWrite)
h2 = ROMDiscFS.Open("HELLO.TXT", ROMDiscFS.ForRead)
Print "handles "; h1; h2
Do While Not ROMDiscFS.Eof(h2)
  r = FileSystem.WriteLine(h1, "copied: " + ROMDiscFS.ReadLine(h2))
Loop
r = ROMDiscFS.Close(h2)
r = FileSystem.Close(h1)
Print "R size "; ROMDiscFS.Size("BIG.BIN"); " A size "; FileSystem.Size("COPY.TXT")
h1 = FileSystem.Open("COPY.TXT", FileSystem.ForRead)
Do While Not FileSystem.Eof(h1)
  Print FileSystem.ReadLine(h1)
Loop
r = FileSystem.Close(h1)
Print "done"
