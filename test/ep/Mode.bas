' 80 columns on the ep128 platform (test/epregress.sh): Mode 2, a full line, Locate, a scroll
Dim i As Integer
Mode 2
Print "cols"; StdIO.Cols()
Print String$(80, "=");
Print "after the full line"
For i = 1 To 30
    Print "line"; i; Tab(70); "right"
Next i
Locate 78, 3 : Print "X"
Locate 1, 25
Print "end"
End
