' CP/M StdIO.SetTerminal: the terminal chosen while the program runs (no Option Terminal: it starts
' as a stream). VT52 codes, then ANSI codes, then none again.
Print "junk"
Cls
Print "stream"
StdIO.SetTerminal StdIO.TerminalVT52
Cls
Print "top"
Locate 10, 3 : Print "vt52 at 10,3"
StdIO.SetTerminal 2
Locate 20, 5 : Print "ansi at 20,5"
StdIO.SetTerminal 0
Locate 1, 1 : Print "none"
Print StdIO.CanPosition; StdIO.Rows
