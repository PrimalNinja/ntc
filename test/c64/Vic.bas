' the Vic and Sid classes: registers as set
Dim i As Integer
Print "addr="; Hex$(Vic.ShapeAddr(0)); ","; Hex$(Vic.ShapeAddr(15)); ","; Hex$(Vic.ShapeAddr(16)); ","; Hex$(Vic.ShapeAddr(78))
For i = 0 To 62
  Poke Vic.ShapeAddr(3) + i, 255
Next
Vic.Shape 2, 3
Vic.Shape 7, 20
Vic.Colour 2, 7
Vic.Sprite 2, 300, 120
Vic.Sprite 0, 100, 60
Print "spr="; Peek(&HD004); ","; Peek(&HD005); ","; Peek(&HD010); ","; Peek(&HD015); ","; Peek(&HE3FA); ","; Peek(&HE3FF); ","; Peek(&HD029) And 15
Vic.Hide 0
Vic.Expand 2, 1, 0
Vic.Multi 2, 1
Vic.Behind 2, 1
Print "reg="; Peek(&HD015); ","; Peek(&HD01D); ","; Peek(&HD017); ","; Peek(&HD01C); ","; Peek(&HD01B); ","; Vic.Bit(5)
Vic.Multi 2, 0
Print "off="; Peek(&HD01C); " chr="; Hex$(Vic.CharAddr(128)); " ras="; (Vic.Raster() >= 0) And (Vic.Raster() < 312)
Vic.MultiText 1, 11, 12
Vic.Scroll 3, 5
Print "scr="; Peek(&HD016) And 31; ","; Peek(&HD011) And 31; ","; Peek(&HD022) And 15; ","; Peek(&HD023) And 15
Vic.MultiText 0, 0, 0
Vic.ScrollOff
Print "scroff="; Peek(&HD016) And 31; ","; Peek(&HD011) And 127
Sid.Volume 15
Sid.Voice 0, Sid.Saw, 0, 9, 0, 0
Sid.Tone 0, 440
Print "sid ok"
Frame : Frame
End
