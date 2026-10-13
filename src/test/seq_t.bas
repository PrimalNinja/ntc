' sequential files on the CPC (cpcfw, cpcmin): one open file, CAS IN / OUT CHAR
Option RomEnable 7
Dim h As Integer, h2 As Integer, r As Integer, i As Integer, n As Integer, s As String
Dim buf(9) As Integer, back(9) As Integer
h = FileSystem.Open("DATA.TXT", FileSystem.ForWrite)
Print "open "; h
h2 = FileSystem.Open("OTHER.TXT", FileSystem.ForRead)
Print "second "; h2
r = FileSystem.Load("DATA.TXT", VarPtr(back), 20)
Print "load while open "; r
For i = 65 To 70 : r = FileSystem.WriteByte(h, i) : Next
r = FileSystem.WriteByte(h, 13) : r = FileSystem.WriteByte(h, 10)
r = FileSystem.WriteLine(h, "second line")
For i = 0 To 9 : buf(i) = 48 + i + 256 * 32 : Next
r = FileSystem.Write(h, VarPtr(buf), 20)
Print "write "; r
r = FileSystem.ReadByte(h)
Print "read on write "; r
r = FileSystem.Close(h)
Print "close "; r; " again "; FileSystem.Close(h)
Print "update "; FileSystem.Open("DATA.TXT", FileSystem.ForUpdate); " mode 9 "; FileSystem.Open("DATA.TXT", 9)
Print "missing "; FileSystem.Open("NOPE.TXT", FileSystem.ForRead)
h = FileSystem.Open("DATA.TXT", FileSystem.ForRead)
Print "["; FileSystem.ReadLine(h); "] ["; FileSystem.ReadLine(h); "]"
r = FileSystem.Read(h, VarPtr(back), 6)
Print "read "; r; " "; Chr$(back(0) And 255); Chr$(back(2) And 255); Chr$(back(2) \ 256)
s = ""
Do While Not FileSystem.Eof(h)
  n = FileSystem.ReadByte(h)
  If n <> 32 Then s = s + Chr$(n)
Loop
Print "rest "; s
Print "at end "; FileSystem.ReadByte(h); " line ["; FileSystem.ReadLine(h); "] write "; FileSystem.WriteLine(h, "x")
Print "bad handle "; FileSystem.ReadByte(2); " eof "; FileSystem.Eof(2)
r = FileSystem.Close(h)
r = FileSystem.Save("BIN.DAT", VarPtr(buf), 4)
h = FileSystem.Open("BIN.DAT", FileSystem.ForRead)
s = ""
Do While Not FileSystem.Eof(h)
  s = s + Str$(FileSystem.ReadByte(h))
Loop
r = FileSystem.Close(h)
Print "binary"; s
Print "done"
