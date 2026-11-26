' Blocks.bas - #natural ... #endnatural parts in a plain NTC BASIC file and in a class
' (test/regress.sh). (c) 2026 Cyborg Unicorn Pty Ltd - MIT License
Option Explicit
Dim total As Integer, i As Integer

Sub Twice(ByVal v As Integer)
    #natural
    multiply v by 2
    say "twice" v
    #endnatural
End Sub

For i = 1 To 3
    #natural
    add i to total : if total is above 3 say "big" total end
    #endnatural
Next i
#natural
twice 21
with tally 2 bump 5 bump 6
say "tally" ( Tally.Value(2) )
count k from 1 to 2 say "k" k end
#endnatural
Print "#natural in a string, and total"; total
