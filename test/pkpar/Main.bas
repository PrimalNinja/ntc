' Number parameters of a class in a page: in the page, filled in one LDIR (regress.sh): cpcmin / cpcfw
Option Memory Paged 1, &H4000, &H4000
Option Memory Safe &H0040, &H3F40
Option Page "PK.001" = Calc
Option Page "PK.002" = Other
Dim a As Integer, b As Integer, r As Integer
Dim l As Long
Dim s As String
a = 3
b = 4
l = 100000
s = "HEY"
Print "add"; Calc.Add(a, b)
Print "mix"; Calc.Mix(a, s, b + 1, l, r)
Print "r"; r
Print "one"; Calc.One(7)
Print "chain"; Calc.Chain(5, 6)
Print "oth"; Other.Twice(21)
Print "none"; Calc.None()
Print "up"; Calc.Up(10)
Print "pv"; Calc.Pv()
Print "loc"; Calc.Loc(4)
Print "opt"; Calc.Opt(1); Calc.Opt(1, 5)
Print "lng"; Calc.Lng(l + 1, 70000)
Dim q As Byte
q = 200
Print "byt"; Calc.Byt(q, 55)
Print "nest"; Calc.Add(Calc.Add(1, 2), Other.Twice(Calc.Add(3, 4)))
