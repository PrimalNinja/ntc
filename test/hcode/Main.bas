' Option HighCode (cpcfw): code that doesn't fit below #4000 goes to #C000-#FFFF (in the file at
' #4000-#7FFF, copied up at the start; the screen moves to #4000); Option Place keeps a class's code
' below #4000. Big1 (12000 bytes) fills most of the low part, so Big2 (6000) goes to #C000; Low's
' #asm is placed first, low. The variables and arrays from #8000.
Option Reserve &H4000, &H4000
Option HighCode
Option Place Low
Dim a(10) As Integer
Print "start"
Big1
Big2
a(3) = 7
Print "a3 "; a(3); " b1 "; Hex$(W1()); " b2 "; Hex$(W2()); " low "; Hex$(Low.Where()); " arr "; Hex$(VarPtr(a(0)))
Sub Big1()
#asm
            jp b1_e
            ds 12000
b1_e:
#endasm
End Sub
Sub Big2()
#asm
            jp b2_e
            ds 6000
b2_e:
#endasm
End Sub
Function W1() As Integer
#asm
            pop hl
            ld de, fn_big1
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
Function W2() As Integer
#asm
            pop hl
            ld de, fn_big2
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
