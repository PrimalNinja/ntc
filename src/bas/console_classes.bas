' StdIO and System platform classes (the same program on every platform)
Option PressAnyKeyOnEnd "Press a key"     ' at the end: a message and a key (a RUN" program resets when it ends)
Dim s As String, k As Integer
StdIO.PutStr "cols "
StdIO.PutInt StdIO.Cols()
StdIO.NewLine
StdIO.PutChar 65
StdIO.PutChar 66
StdIO.NewLine
If StdIO.CanPosition Then Print "can position" Else Print "stream"
Print System.Platform; " ticks/s "; System.TicksPerSecond
StdIO.PutStr "name? "
StdIO.GetLine s
StdIO.PutStr "hi " & s
StdIO.NewLine
k = StdIO.GetChar()
Print "key "; k; " col "; StdIO.Column()
