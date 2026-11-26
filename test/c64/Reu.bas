' the Reu class: size, blocks out and back, bytes and words, fills
Dim i As Integer, n As Integer
Dim a(9) As Integer, b(9) As Integer
Print "banks="; Reu.Banks(); " k="; Reu.Size()
For i = 0 To 9
  a(i) = i * 111
Next
Reu.Stash 1, &H1000, VarPtr(a(0)), 20
Reu.Fetch 1, &H1000, VarPtr(b(0)), 20
n = 0
For i = 0 To 9
  If b(i) = i * 111 Then n = n + 1
Next
Print "block="; n
Reu.Poke 1, &HC000, 77
Reu.Doke 1, &HC001, 12345
Print "bytes="; Reu.Peek(1, &HC000); ","; Reu.Deek(1, &HC001); ","; Reu.Peek(1, &H1002)
Reu.Fill 1, 0, 65, 40
Reu.Fetch 1, 0, &HE000 + 400, 40
Reu.MemFill &HE000 + 440, 66, 40
Print "fill="; Peek(&HE000 + 400); ","; Peek(&HE000 + 439); ","; Peek(&HE000 + 440); ","; Peek(&HE000 + 479); ","; Peek(&HE000 + 480)
For i = 0 To 9 : b(i) = 0 : Next
Reu.Swap 1, &H1000, VarPtr(b(0)), 20
Print "swap="; b(9); ","; Reu.Deek(1, &H1012)
' rows: a 3 x 4 block out of a 16 wide sheet, and back in somewhere else
For i = 0 To 127 : Reu.Poke 1, &H4000 + i, i : Next
Reu.FetchRect 1, &H4000 + 16 + 5, 16, VarPtr(b(0)), 3, 3, 4
Print "rect="; b(0) And 255; ","; (b(1) \ 256) And 255; ","; b(2) And 255; ","; (b(5) \ 256) And 255
Reu.StashRect 1, &H5000, 8, VarPtr(b(0)), 3, 3, 4
Print "back="; Reu.Peek(1, &H5000); ","; Reu.Peek(1, &H5002); ","; Reu.Peek(1, &H5008); ","; Reu.Peek(1, &H501A)
Print "pieces="; System.Pieces()
End
