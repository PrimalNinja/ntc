' Option Place Low: this class's code stays below #4000 (Option HighCode)
Public Function Where() As Integer
#asm
            pop hl
            ld de, fn_low_where
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
