' Fx - the little asm X-TYPE needs: Shr3(v) = v / 8 for v from 0 (a pixel's cell), with no division loop.
' (c) 2026 Cyborg Unicorn Pty Ltd
Option Explicit

Public Function Shr3(v As Integer) As Integer
#asm
            pop hl
            ld e, (hl)
            inc hl
            ld d, (hl)
            srl d
            rr e
            srl d
            rr e
            srl d
            rr e
            pop hl
            ld (hl), e
            inc hl
            ld (hl), d
#endasm
End Function
