' the Disk class: a file from the disc into the REU and out again
Dim n As Integer, i As Integer, ok As Integer
Dim b(127) As Byte
n = Disk.LoadReu("DATA.BIN", 1, &H2000)
Print "blocks="; n; " last="; Disk.LastBytes()
Reu.Fetch 1, &H2000, VarPtr(b(0)), 128
ok = 0
For i = 0 To 127
  If b(i) = (i * 3 And 255) Then ok = ok + 1
Next
Print "first="; ok
Reu.Fetch 1, &H2000 + 896, VarPtr(b(0)), 104
ok = 0
For i = 0 To 103
  If b(i) = ((896 + i) * 3 And 255) Then ok = ok + 1
Next
Print "tail="; ok
Print "none="; Disk.LoadReu("NOSUCH", 1, 0)
Print "ticks="; Ticks > 0
End
