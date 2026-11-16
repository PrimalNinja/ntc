' CP/M Option Terminal ADM3A, then Televideo by StdIO.SetTerminal: ESC = row+31 column+31; clear is
' Ctrl-Z (ADM-3A) / ESC * (Televideo). The codes are shown as numbers (the harness's terminal is VT52 / ANSI).
Option Terminal ADM-3A
Cls
Locate 10, 3 : Print "a"
StdIO.SetTerminal StdIO.TerminalTelevideo
Cls
Locate 2, 1 : Print "t"
StdIO.SetTerminal 9
Locate 5, 5 : Print "n"
