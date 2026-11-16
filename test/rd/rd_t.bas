' the ROM disc (the ROMDiscFS class): read-only files in ROMs - regress.sh builds the disc from rd/
Dim i As Integer, n As Integer, r As Integer, h As Integer, s As String, b(15) As Integer
Dim big(10000) As Integer, sum As Long
Print "cap"; ROMDiscFS.Capability("ROMDISC")
r = ROMDiscFS.SelectVolume("R")
Print "select R "; r; " volume "; ROMDiscFS.CurrentVolume()
n = 0
Do
  n = n + 1
  s = ROMDiscFS.DirEntry(n)
  If s <> "" Then Print n; " "; s; " "; ROMDiscFS.Size(s)
Loop Until s = ""
Print "exists "; ROMDiscFS.Exists("HELLO.TXT"); ROMDiscFS.Exists("NOPE.TXT"); ROMDiscFS.Exists("R:small.dat")
r = ROMDiscFS.Load("SMALL.DAT", VarPtr(b), 32)
Print "load "; r; " "; b(0) And 255; " "; b(4) \ 256
r = ROMDiscFS.Load("BIG.BIN", VarPtr(big), 100)
Print "too big "; r
r = ROMDiscFS.Load("BIG.BIN", VarPtr(big), 20002)
Print "big "; r
sum = 0
For i = 0 To 9999 : sum = sum + (big(i) And 255) + (((big(i) And &HFF00) \ 256) And 255) : Next
Print "sum "; sum
h = ROMDiscFS.Open("HELLO.TXT", ROMDiscFS.ForRead)
Print "open "; h
Do While Not ROMDiscFS.Eof(h)
  Print "> "; ROMDiscFS.ReadLine(h)
Loop
Print "at end "; ROMDiscFS.ReadByte(h)
r = ROMDiscFS.Close(h)
Print "close "; r; " again "; ROMDiscFS.Close(h)
h = ROMDiscFS.Open("BIG.BIN", ROMDiscFS.ForRead)
r = ROMDiscFS.Read(h, VarPtr(big), 16380)
i = ROMDiscFS.ReadByte(h)
n = ROMDiscFS.Read(h, VarPtr(big), 10000)
Print "read "; r; " "; i; " "; n; " "; ROMDiscFS.Eof(h)
r = ROMDiscFS.Close(h)
Print "write "; ROMDiscFS.Open("NEW.TXT", ROMDiscFS.ForWrite); " missing "; ROMDiscFS.Open("NOPE.TXT", ROMDiscFS.ForRead); " bad "; ROMDiscFS.Open("TOOLONGNAME.TXT", ROMDiscFS.ForRead)
Print "done"
