' Loader: a file from where the program was run (regress.sh)
Dim b(299) As Byte
Dim r As Integer
r = Loader.Load("DATA.BIN", VarPtr(b(0)), 300)
Print "len"; r; b(0); b(1); b(199)
r = Loader.Load("NOPE.BIN", VarPtr(b(0)), 300)
Print "none"; r
r = Loader.Load("DATA.BIN", VarPtr(b(0)), 100)
Print "big"; r
r = Loader.Load("", VarPtr(b(0)), 100)
Print "bad"; r
r = Loader.Load("data.bin", VarPtr(b(0)), 300)
Print "low"; r; b(5)
