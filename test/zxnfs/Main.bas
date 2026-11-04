' zxnfs - the Next's FileSystem on real NextZXOS (ZEsarUX): save a file, its size, read it back,
' seek, Eof, a line, exists, rename, delete, the directory. The results in r(): read by the
' harness from memory (the symbols), so it works with no screen reading.
Option Explicit
Dim r(15) As Integer
Dim b(99) As Byte, c(99) As Byte
Dim i As Integer, h As Integer, n As Integer, s As String Max 80
For i = 0 To 99 : b(i) = i + 32 : Next                  ' printable: no line feeds in the data
b(10) = 13 : b(11) = 10                            ' a line end after 10 bytes
r(0) = 1234
r(1) = FileSystem.Save("NTCFS.TST", VarPtr(b(0)), 100)
r(2) = CInt(FileSystem.Size("NTCFS.TST"))
r(3) = FileSystem.Load("NTCFS.TST", VarPtr(c(0)), 100)
n = 0
For i = 0 To 99 : If c(i) = b(i) Then n = n + 1 : Next
r(4) = n
h = FileSystem.Open("NTCFS.TST", FileSystem.ForRead)
r(5) = h
r(6) = FileSystem.Seek(h, 50)
r(7) = FileSystem.ReadByte(h)                      ' b(50) = 82
r(8) = FileSystem.Eof(h)                           ' 0: not at the end
r(9) = FileSystem.Seek(h, 0)
s = FileSystem.ReadLine(h)
r(10) = Len(s)                                     ' 10
r(11) = FileSystem.Close(h)
r(12) = FileSystem.Exists("NTCFS.TST")
r(13) = FileSystem.Rename("NTCFS.TST", "NTCFS2.TST")
r(14) = FileSystem.Delete("NTCFS2.TST")
r(15) = 0
s = FileSystem.DirEntry(0)                         ' the directory walks (an entry comes back)
If FileSystem.Exists("NTCFS2.TST") = 0 And Len(s) > 0 Then r(15) = 5678 Else r(15) = FileSystem.LastError
Do : Loop
