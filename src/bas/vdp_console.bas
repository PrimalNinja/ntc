' Console test for the platforms whose screen is a video chip (msx, msxcard, msx9990,
' sc3000, cpccard, cpc9990): scrolling, a long line wrapping, Mode, Locate, Tab, Ticks
Option PressAnyKeyOnEnd "Press a key"
Dim i As Integer, t As Integer, m As Integer
Print "Console test on "; System.Platform
t = Ticks
For i = 1 To 30
  Print "Line"; i; ": the text scrolls up"
Next
Print "30 lines in"; Ticks - t; " ticks"
Print "A long line goes on to the next row by itself when it reaches the last column"
Input "Mode (0, 1, 2)"; m
Mode m
Print "Mode"; m; ":"; StdIO.Cols; " columns"
For i = 1 To 5
  Print "Row"; i; Tab(20); "Tab 20"
Next
Locate 10, 12 : Print "Locate 10, 12"
Locate 1, 14
End
