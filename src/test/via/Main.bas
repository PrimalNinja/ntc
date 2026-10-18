' the console statements go through the project's own StdIO class
Dim n As Integer, s As String
n = 42
Print "hello"; n, "x"
Cls
Locate 3, 4
Input "name"; s
Print s
k$ = Inkey$
Print k$; Inkey
Input "num"; n
Print n + 1
Print "lines "; StdIO.Lines
