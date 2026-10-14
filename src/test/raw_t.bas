' FileSystem ForReadRaw: a file with no header (AMSDOS calls it ASCII text) read to its real
' end - the #1A bytes in it are data, not the end. RAW.COM: 300 bytes, #1A at 10 and 200 (the
' disc keeps whole 128 byte records: 384 come back). Eof reads a byte ahead (CAS TEST EOF at a
' #1A loses bytes - checked on the real ROMs with realcpc)
Option PressAnyKeyOnEnd "Press a key"
Option RomEnable 7
Dim b(511) As Byte, c(511) As Byte
Dim h As Integer, n As Integer, k As Integer, e As Integer, i As Integer, d As Integer
h = FileSystem.Open("RAW.COM", FileSystem.ForRead)
n = FileSystem.Read(h, VarPtr(b), 512)
e = FileSystem.Close(h)
Print "text"; n
h = FileSystem.Open("RAW.COM", FileSystem.ForReadRaw)
n = FileSystem.Read(h, VarPtr(b), 512)
e = FileSystem.Close(h)
Print "raw"; n; b(10); b(11); b(200); b(299)
h = FileSystem.Open("RAW.COM", FileSystem.ForReadRaw)
k = 0
Do While Not FileSystem.Eof(h)
  c(k) = FileSystem.ReadByte(h)
  k = k + 1
Loop
e = FileSystem.Close(h)
d = -1
For i = 0 To k - 1
  If b(i) <> c(i) Then d = i : Exit For
Next
Print "eof"; k; d
