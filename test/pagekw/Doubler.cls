' Doubler: a self-contained page class. Its public method Twice calls its own private
' asm keyword DblKw with a bare dw (same bank, no page switch); Show uses an inline #asm
' block. The keyword body AND the inline block must live in this class's bank, not main.
Public Function Twice(ByVal n As Integer) As Integer
  Twice = DblKw(n)
End Function
Private Function DblKw(ByVal n As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            sla e
            rl d
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
Public Sub Show()
  Dim x As Integer
#asm
            ld hl, 7
            ld ({x}), hl
#endasm
  Print "DRV"; x
End Sub
