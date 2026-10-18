' CP/M Option Terminal VT52: Cls and Locate with the terminal's codes
Option Terminal VT52
Print "junk"
Cls
Print "top"
Locate 10, 3 : Print "at 10,3"
Locate 75, 5 : Print "abcdefgh"
Print StdIO.CanPosition; StdIO.Rows; System.HasScreen
