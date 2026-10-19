' ROMDISC (volume R): read-only files in ROMs - regress.sh builds the disc from rd/
Dim i As Integer, n As Integer, r As Integer, h As Integer, s As String, b(15) As Integer
Dim big(10000) As Integer, sum As Long
Print "cap"; FileSystem.Capability("ROMDISC")
r = FileSystem.SelectVolume("R")
Print "select R "; r; " volume "; FileSystem.CurrentVolume()
n = 0
Do
  n = n + 1
  s = FileSystem.DirEntry(n)
  If s <> "" Then Print n; " "; s; " "; FileSystem.Size(s)
Loop Until s = ""
Print "exists "; FileSystem.Exists("HELLO.TXT"); FileSystem.Exists("NOPE.TXT"); FileSystem.Exists("R:small.dat")
r = FileSystem.Load("SMALL.DAT", VarPtr(b), 32)
Print "load "; r; " "; b(0) And 255; " "; b(4) \ 256
r = FileSystem.Load("BIG.BIN", VarPtr(big), 100)
Print "too big "; r
r = FileSystem.Load("BIG.BIN", VarPtr(big), 20002)
Print "big "; r
sum = 0
For i = 0 To 9999 : sum = sum + (big(i) And 255) + (((big(i) And &HFF00) \ 256) And 255) : Next
Print "sum "; sum
h = FileSystem.Open("HELLO.TXT", FileSystem.ForRead)
Print "open "; h
Do While Not FileSystem.Eof(h)
  Print "> "; FileSystem.ReadLine(h)
Loop
Print "at end "; FileSystem.ReadByte(h)
r = FileSystem.Close(h)
Print "close "; r; " again "; FileSystem.Close(h)
h = FileSystem.Open("BIG.BIN", FileSystem.ForRead)
r = FileSystem.Read(h, VarPtr(big), 16380)
i = FileSystem.ReadByte(h)
n = FileSystem.Read(h, VarPtr(big), 10000)
Print "read "; r; " "; i; " "; n; " "; FileSystem.Eof(h)
r = FileSystem.Close(h)
Print "write "; FileSystem.Open("NEW.TXT", FileSystem.ForWrite); " missing "; FileSystem.Open("NOPE.TXT", FileSystem.ForRead); " bad "; FileSystem.Open("TOOLONGNAME.TXT", FileSystem.ForRead)
Print "done"
