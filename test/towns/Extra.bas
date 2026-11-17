' The library keywords the self tests do not reach. The same program prints the same text on
' the X68000 and the FM Towns: townsregress.sh and x68regress.sh check for the same lines.
Dim a As Integer, b As Integer, i As Integer, s As String, u As String
Dim n As Long, g(1, 2) As String, lim As Integer, ad As Integer, q As Integer
a = -7 : b = 3 : lim = 9
Print Abs(a); Sgn(a); Sgn(0); Sgn(b); 20 \ b; 20 Mod b; a Mod 4; (Not a); (a Or 8); (a Xor 5); (a Or b); (a Xor b)
Print Str$(5); Str$(-5); Chr$(65); Chr$(b + 64); "|"; Format$(1234, "#,##0"); "|"; Format$(7, "000"); "|"
n = 1234567 : Print Format$(n, "#,##0"); "|"; n
Randomize 77
For i = 1 To 5 : Print Rnd(100); " "; : Next
q = 50 : Print Rnd(q); " "; : Randomize b : Print Rnd(1000)
For i = 1 To lim Step 4 : Print i; : Next : Print "|";
For i = lim To 1 Step -4 : Print i; : Next : Print "|";
For i = 1 To 9 Step 4 : Print i; : Next : Print "|";
For i = 9 To 1 Step -4 : Print i; : Next : Print
If a < b Then Print "lt ";
If a <= b Then Print "le ";
If b > a Then Print "gt ";
If b >= a Then Print "ge ";
If a <> b Then Print "ne ";
If a < 0 Then Print "ltl ";
If b <= 3 Then Print "lel ";
If b > 2 Then Print "gtl ";
If b >= 3 Then Print "gel"
If "b" >= "a" Then Print "sge ";
If "b" <> "a" Then Print "sne"
i = 0
again:
i = i + 1
If i < 3 Then GoTo again
GoSub show
GoSub show
g(1, 2) = "two-d" : Print g(1, 2)
ad = VarPtr(q)
Doke ad, 258 : Print q; Deek(ad);
q = 7 : Poke ad, q : Print Peek(ad);
i = 513 : Doke ad, i : Print q
Print "zone", "two", "three"
Locate 3, a + 20 : Print "at"
Print "end"
End
show:
Print "sub"; i;
Return
