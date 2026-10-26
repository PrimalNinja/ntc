' Option Reserve builds round the range: a big #asm block (15600 bytes) can't fit below #4000,
' so it and what follows go above #8000; the arrays too. ProgramEnd() above #8000.
Option Reserve &H4000, &H4000
Dim a(10) As Integer
Print "start"
Big
a(3) = 7
Print "a3 "; a(3); " big at "; Hex$(Where()); " end "; Hex$(Memory.ProgramEnd())
Sub Big()
#asm
            jp bg_e
            ds 15600
bg_e:
#endasm
End Sub
Function Where() As Integer
#asm
            pop hl
            ld de, fn_big
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
